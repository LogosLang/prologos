#lang racket/base

;;;
;;; run-ocapn-test-server.rkt — Phase 58.b-3 (consolidated).
;;;
;;; Long-running Racket TCP server that accepts incoming OCapN
;;; connections from the upstream ocapn-test-suite (Python) and
;;; responds with a valid signed op:start-session.
;;;
;;; CONSOLIDATION: the signed start-session bytes are now produced
;;; by the canonical Prologos implementation
;;; (`prologos::ocapn::handshake` → `mk-handshake-bytes`), not by a
;;; parallel Racket-side fixture. This server is a thin TCP shell:
;;; it loads the Prologos modules once, calls `mk-handshake-bytes`
;;; via `process-string`, and serves the resulting bytes. Crypto
;;; (libsodium FFI) and Syrup encoding both live inside Prologos.
;;;
;;; What this server does:
;;;   1. Load the OCapN Prologos modules at startup.
;;;   2. Call mk-handshake-bytes to build the signed start-session.
;;;   3. Listen on a TCP port.
;;;   4. For each connection: send the start-session bytes (via the
;;;      configurable framing), read peer frames, log, close.
;;;
;;; Limitation: the server does NOT yet dispatch post-handshake
;;; frames through captp-core's connection-step. The full
;;; ocapn-test-suite needs swiss-num-addressed objects + op:deliver
;;; dispatch — that's Phase 59.

(require racket/cmdline
         "../../racket/prologos/ocapn-dial-ffi.rkt"
         racket/tcp
         racket/list
         racket/string
         (only-in racket/format ~a)
         (only-in file/sha1 bytes->hex-string)
         "ocapn-framing.rkt"
         "../../racket/prologos/tests/test-support.rkt"
         "../../racket/prologos/macros.rkt"
         "../../racket/prologos/prelude.rkt"
         "../../racket/prologos/syntax.rkt"
         "../../racket/prologos/source-location.rkt"
         "../../racket/prologos/surface-syntax.rkt"
         "../../racket/prologos/errors.rkt"
         "../../racket/prologos/metavar-store.rkt"
         "../../racket/prologos/parser.rkt"
         "../../racket/prologos/elaborator.rkt"
         "../../racket/prologos/pretty-print.rkt"
         "../../racket/prologos/global-env.rkt"
         "../../racket/prologos/driver.rkt"
         "../../racket/prologos/namespace.rkt"
         "../../racket/prologos/multi-dispatch.rkt")

(define port-arg (make-parameter 22045))
(define version-arg (make-parameter "1.0"))
(define framing-arg (make-parameter 'raw-syrup))

(command-line
 #:program "run-ocapn-test-server"
 #:once-each
 [("--port") p "TCP port to listen on (default: 22045)"
             (port-arg (string->number p))]
 [("--captp-version") v "CapTP version to advertise (default: 1.0)"
                      (version-arg v)]
 [("--framing") f "Wire framing: 'raw-syrup' (default; OCapN spec) or 'newline' (Prologos cross-impl tests)"
                (framing-arg (string->symbol f))])

(unless (framing-strategy? (framing-arg))
  (error 'run-ocapn-test-server "unknown framing: ~v (expected raw-syrup or newline)" (framing-arg)))
(current-framing-strategy (framing-arg))

(file-stream-buffer-mode (current-output-port) 'line)

;; ========================================
;; Load the Prologos OCapN modules once
;; ========================================

;; The captp-core dependency tree must be imported as explicit
;; top-level `imports` in dependency order. Auto-loading a module's
;; deps transitively (just `(imports captp-core)`) mis-elaborates
;; `data` constructor matches into `??__match-fail` holes — a known
;; module-loading-context boundary. This preamble mirrors the proven
;; import list from tests/test-ocapn-bridge.rkt.
(define preamble
  "(ns ocapn-test-server)
(imports (prologos::ocapn::core :refer-all))
(imports (prologos::ocapn::message :refer-all))
(imports (prologos::ocapn::captp-wire :refer-all))
(imports (prologos::ocapn::syrup-wire :refer-all))
(imports (prologos::ocapn::pipelining :refer (promise-queue-length)))
(imports (prologos::ocapn::captp-interop-helpers :refer (framed-concat)))
(imports (prologos::data::list :refer (List nil cons)))
(imports (prologos::data::option :refer (Option some none unwrap-or)))
(imports (prologos::data::string :as str :refer ()))
(imports (prologos::ocapn::handshake :refer-all))
(imports (prologos::ocapn::interop-driver :refer-all))
(imports (prologos::ocapn::captp-core :refer-all))
")

(printf "ocapn-test-server: loading Prologos OCapN modules~n") (flush-output)

(define-values (g-env g-ns g-mods g-traits g-impls g-pimpls g-ctors g-tmeta)
  (parameterize ([current-file-module-network-ref (make-module-network)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry prelude-preparse-registry]
                 [current-ctor-registry (current-ctor-registry)]
                 [current-type-meta (current-type-meta)]
                 [current-trait-registry prelude-trait-registry]
                 [current-impl-registry prelude-impl-registry]
                 [current-param-impl-registry prelude-param-impl-registry]
                 [current-multi-defn-registry (current-multi-defn-registry)]
                 [current-spec-store (hasheq)])
    (install-module-loader!)
    (process-string preamble)
    (values (current-file-module-network-ref)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

(define (run-prologos s)
  (parameterize ([current-file-module-network-ref g-env]
                 [current-ns-context g-ns]
                 [current-module-registry g-mods]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry g-traits]
                 [current-impl-registry g-impls]
                 [current-param-impl-registry g-pimpls]
                 [current-ctor-registry g-ctors]
                 [current-type-meta g-tmeta])
    (process-string s)))

;; ========================================
;; Build the signed start-session via Prologos
;; ========================================
;;
;; mk-handshake-bytes produces a Latin-1 String of wire bytes. The
;; process-string result is pretty-printed as `"...." : String`;
;; `read` recovers the Racket string, which we convert to bytes.

(define (extract-latin1-bytes prologos-result)
  (define m (regexp-match #px"^(\".*\") : String$" prologos-result))
  (unless m
    (error 'extract-latin1-bytes "couldn't extract String from: ~s" prologos-result))
  (string->bytes/latin-1 (read (open-input-string (cadr m)))))

;; ONE keypair for the process, held rather than discarded.
;;
;; `mk-handshake-bytes` generates a keypair inside a `let` and drops the
;; handle, so nothing downstream can sign. A third-party handoff must sign a
;; desc:handoff-receive with the same key the gifter named as the receiver --
;; which is the key we handshake with -- so the handle has to outlive the
;; handshake.
(define keypair-handle
  (let ([r (last (run-prologos "(eval (gen-keypair-raw unit))"))])
    (or (and (string? r)
             (let ([m (regexp-match #px"^([0-9]+)N? : Nat$" r)])
               (and m (string->number (cadr m)))))
        (error 'run-ocapn-test-server "could not read keypair handle from: ~s" r))))

(define start-session-bytes
  (extract-latin1-bytes
   (last
    (run-prologos
     (format "(eval (handshake-bytes-with-key ~s ~aN \"tcp-testing-only\" \"0123456789abcdef0123456789abcdef\" \"127.0.0.1\" ~s))"
             (version-arg)
             keypair-handle
             (number->string (port-arg)))))))

(printf "ocapn-test-server: built signed start-session (~a bytes) via prologos::ocapn::handshake~n"
        (bytes-length start-session-bytes))
(flush-output)

;; ========================================
;; Inbound start-session validation
;; ========================================
;;
;; The decision logic lives in `prologos::ocapn::handshake`
;; (`check-incoming-start-session`). The server hex-encodes the
;; inbound frame, passes it through, and gets back either the empty
;; string (accept) or op:abort wire bytes (reject).

(define validate-sema (make-semaphore 1))

(define (validate-incoming frame-bytes)
  ;; `process-string` shares elaborator state across calls; serialise
  ;; per-connection validation so concurrent connections cannot race.
  (call-with-semaphore
   validate-sema
   (lambda ()
     (extract-latin1-bytes
      (last
       (run-prologos
        (format "(eval (check-incoming-start-session ~s ~s))"
                (version-arg)
                (bytes->hex-string frame-bytes))))))))

;; ========================================
;; Post-handshake CapTP dispatch
;; ========================================
;;
;; Once the handshake is accepted the server drives captp-core's
;; connection-step, one wire frame at a time. Each frame is a separate
;; `process-string` call (fresh reduction-fuel budget); the
;; ConnectionState persists in ocapn-conn-ffi.rkt's table keyed by an
;; integer connection id. `step-connection` returns the concatenated
;; outbound wire bytes (raw-syrup is self-delimiting).

(define conn-id-box (box 0))

(define (next-conn-id!)
  (define id (unbox conn-id-box))
  (set-box! conn-id-box (add1 id))
  id)

(define (drive-init! cid)
  (call-with-semaphore validate-sema
    (lambda ()
      (run-prologos (format "(eval (init-connection ~aN))" cid)))))

;; Returns the outbound wire bytes for one frame, or #"" if the step
;; produced nothing / failed. A step that errors (e.g. an op captp-core
;; cannot yet service) must not take down the connection handler.
(define (drive-step cid frame-bytes)
  (call-with-semaphore validate-sema
    (lambda ()
      (with-handlers ([exn:fail?
                       (lambda (e)
                         (printf "ocapn-test-server: step exn (conn ~a): ~a~n"
                                 cid (exn-message e))
                         #"")])
        (define results
          (run-prologos
           (format "(eval (step-connection ~aN ~s))"
                   cid (bytes->hex-string frame-bytes))))
        (define r (and (pair? results) (last results)))
        (cond
          [(not (string? r))
           (printf "ocapn-test-server: step produced no String (conn ~a)~n" cid)
           #""]
          [(regexp-match #px"^(\".*\") : String$" r)
           => (lambda (m)
                (string->bytes/latin-1 (read (open-input-string (cadr m)))))]
          [else
           (printf "ocapn-test-server: step result unparsable (conn ~a): ~a~n" cid r)
           #""])))))

;; ========================================
;; Connection handler
;; ========================================

;; ========================================
;; Crossed hellos
;; ========================================
;;
;; Two peers can dial each other at the same moment and end up with two
;; sessions where there should be one. CapTP breaks the tie with a rule both
;; sides can evaluate independently and agree on without another round trip:
;; sort the two SIDE-IDS as octet strings, and abort the connection DIALLED BY
;; whichever sorts first.
;;
;; A side-id is SHA-256 applied twice to the gcrypt-encoded public key — and
;; that encoding is byte-for-byte field 1 of the `op:start-session` frame
;; already in hand, so this needs no key parsing and no re-encoding: slice the
;; field out and hash it. (Verified against upstream's own `our_side_id` in
;; utils/captp.py:113-123, which hashes exactly those bytes.)
;;
;; The peer is identified by its LOCATION bytes, not by host:port. Field 0 of a
;; sturdyref and field 2 of an `op:start-session` are the same `<ocapn-peer …>`
;; record and slice to identical bytes, so the two sides of the match are
;; directly comparable. host:port would be wrong: ephemeral ports get reused
;; across tests in a long-running server.

;; Skip one Syrup value beginning at `i`; return the index just past it.
(define (syrup-skip bs i)
  (define b (bytes-ref bs i))
  (cond
    [(or (= b 60) (= b 91) (= b 123))            ; < [ {
     (define close (cond [(= b 60) 62] [(= b 91) 93] [else 125]))
     (let loop ([j (add1 i)])
       (if (= (bytes-ref bs j) close) (add1 j) (loop (syrup-skip bs j))))]
    [(or (= b 110) (= b 116) (= b 102)) (add1 i)] ; n t f
    [else
     (let loop ([j i])
       (define c (bytes-ref bs j))
       (cond
         [(and (>= c 48) (<= c 57)) (loop (add1 j))]
         [(or (= c 43) (= c 45)) (add1 j)]        ; + -
         [else                                    ; " ' :
          (+ j 1 (string->number (bytes->string/latin-1 (subbytes bs i j))))]))]))

;; Field `n` of a record, as raw bytes. `<label f0 f1 …>` — the label is
;; skipped, so n=0 is the first argument.
(define (record-field bs n)
  (let loop ([i (syrup-skip bs 1)] [k 0])        ; 1 = past '<', then the label
    (define j (syrup-skip bs i))
    (if (= k n) (subbytes bs i j) (loop j (add1 k)))))

(define (side-id-of-start-session frame)
  (sha256-bytes (sha256-bytes (record-field frame 1))))

(define (location-of-start-session frame) (record-field frame 2))

;; Outgoing connections whose handshake is still one-sided, by peer location.
(define half-open-dials (make-hash))

(define our-side-id (side-id-of-start-session start-session-bytes))

;; `<op:abort "reason">`. Built directly rather than through captp-wire: this
;; runs on the accept thread before any connection state exists, and the frame
;; is two atoms.
(define (build-abort-bytes reason)
  (define r (string->bytes/latin-1 reason))
  (bytes-append #"<8'op:abort"
                (string->bytes/latin-1 (number->string (bytes-length r)))
                #"\"" r #">"))

;; ========================================
;; Third-party handoff: the GIFTER side
;; ========================================
;;
;; Here BOTH sessions are ones the peer opened to us. The sturdyref names the
;; exporter session's own location and the peer never accepts a socket for it,
;; so the enlivener must REUSE the open connection whose peer location matches
;; rather than dial — a dial completes against an unaccepted listen backlog and
;; then blocks with zero bytes.
;;
;; That means writing to a connection other than the one being serviced, which
;; is the first thing here to do so: the enliven arrives on one session and the
;; `fetch` must go out on another.

;; peer location bytes -> (vector out-port their-gcrypt-pubkey their-side-id)
(define open-conns (make-hash))

(define pubkey-by-port (make-hasheq))

(define (record-open-conn! frame cout)
  (hash-set! open-conns (location-of-start-session frame)
             (vector cout (record-field frame 1) (side-id-of-start-session frame)))
  (hash-set! pubkey-by-port cout (record-field frame 1)))

;; Enliven requests awaiting the exporter's answer, keyed by the resolve-me
;; export we asked it to reply to.
(define pending-enlivens (make-hash))
(define enliven-slot (box 900))
(define (next-enliven-slot!)
  (set-box! enliven-slot (add1 (unbox enliven-slot)))
  (unbox enliven-slot))

(define (syrup-nat n)
  (bytes-append (string->bytes/latin-1 (number->string n)) #"+"))

(define (desc-record tag n)
  (bytes-append #"<" (syrup-symbol tag) (syrup-nat n) #">"))

;; The enliven arrived on `cout`; the exporter is whichever open connection
;; carries the location the sturdyref names.
(define (try-enliven! frame cout)
  (define i (find-subbytes frame #"<15'ocapn-sturdyref"))
  (define rm (find-subbytes frame #"<18'desc:import-object"))
  (when (and i rm)
    (define sr (subbytes frame i (syrup-skip frame i)))
    (define loc (record-field sr 0))
    (define swiss (record-field sr 1))
    (define exporter (hash-ref open-conns loc #f))
    (define rm-pos (record-field (subbytes frame rm (syrup-skip frame rm)) 0))
    (when exporter
      (define slot (next-enliven-slot!))
      (hash-set! pending-enlivens slot (vector cout rm-pos loc exporter))
      (printf "ocapn-test-server: enliven -> fetch on the exporter session (slot ~a)~n" slot)
      (write-frame (vector-ref exporter 0)
                   (bytes-append #"<" (syrup-symbol "op:deliver")
                                 (desc-record "desc:export" 0)
                                 #"[" (syrup-symbol "fetch") swiss #"]"
                                 #"f" (desc-record "desc:import-object" slot) #">")))))

;; The exporter answered our fetch. Deposit a gift naming the object it gave
;; us, then answer the original enliven with a signed handoff-give.
;;
;; Field values are pinned by upstream's own assertions
;; (third_party_handoffs.py:458-462): receiver-key is the ENLIVENING peer's
;; key, while exporter-location / session / gifter-side all belong to the
;; EXPORTER session -- and gifter-side is OUR side-id, because from the
;; exporter's point of view we are the gifter.
(define (try-fetch-answer! frame)
  (define hit
    (for/first ([(slot v) (in-hash pending-enlivens)]
                #:when (find-subbytes frame (bytes-append #"<11'desc:export" (syrup-nat slot))))
      (cons slot v)))
  (when hit
    (define slot (car hit))
    (define v (cdr hit))
    (hash-remove! pending-enlivens slot)
    (define r2g-out (vector-ref v 0))
    (define rm-pos (vector-ref v 1))
    (define loc (vector-ref v 2))
    (define exporter (vector-ref v 3))
    (define obj (let ([i (find-subbytes frame #"<18'desc:import-object")])
                  (and i (record-field (subbytes frame i (syrup-skip frame i)) 0))))
    (when obj
      (define gid #"prologos-gift")
      ;; Deposit at the exporter.
      (write-frame (vector-ref exporter 0)
                   (bytes-append #"<" (syrup-symbol "op:deliver")
                                 (desc-record "desc:export" 0)
                                 #"[" (syrup-symbol "deposit-gift")
                                 (syrup-bytestring gid)
                                 #"<" (syrup-symbol "desc:export") obj #">"
                                 #"]ff>"))
      ;; Answer the enliven with the signed give. The exporter-location is the
      ;; peer's OWN location bytes, copied -- not re-encoded: our encoder writes
      ;; hints as a syrup list where Python writes a dict, and the assertion
      ;; compares encoded forms.
      (define give
        (bytes-append #"<" (syrup-symbol "desc:handoff-give")
                      (hash-ref pubkey-by-port r2g-out #"")      ; receiver-key
                      loc                                        ; exporter-location
                      (syrup-bytestring (session-id-of (vector-ref exporter 2)))
                      (syrup-bytestring our-side-id)             ; gifter-side
                      (syrup-bytestring gid)
                      #">"))
      (define env (bytes-append #"<" (syrup-symbol "desc:sig-envelope")
                                give (gcrypt-sig (sign-with-our-key give)) #">"))
      (printf "ocapn-test-server: answering enliven with a signed handoff-give~n")
      (write-frame r2g-out
                   (bytes-append #"<" (syrup-symbol "op:deliver")
                                 #"<" (syrup-symbol "desc:export") rm-pos #">"
                                 #"[" (syrup-symbol "fulfill") env #"]ff>")))))

;; ========================================
;; Third-party handoff: the RECEIVER side
;; ========================================
;;
;; A gifter hands us `<desc:sig-envelope <desc:handoff-give …> sig>`. We are
;; expected to connect to the exporter the give names and withdraw the gift
;; there, presenting a desc:handoff-receive signed with the key the gifter
;; named as the receiver — which is the key we handshake with, hence the
;; process-wide keypair above.
;;
;; The session id is defined by upstream (utils/captp.py:125-146) as
;;   SHA256(SHA256("prot0" ++ min(sideA,sideB) ++ max(sideA,sideB)))
;; and the receiving-side is our own side-id. Both are computable the moment
;; the exporter's op:start-session arrives; nothing else is needed from it.

(define (session-id-of their-side)
  (define lo (if (bytes<? our-side-id their-side) our-side-id their-side))
  (define hi (if (bytes<? our-side-id their-side) their-side our-side-id))
  (sha256-bytes (sha256-bytes (bytes-append #"prot0" lo hi))))

(define (syrup-bytestring b)
  (bytes-append (string->bytes/latin-1 (number->string (bytes-length b))) #":" b))

(define (syrup-symbol s)
  (define b (string->bytes/latin-1 s))
  (bytes-append (string->bytes/latin-1 (number->string (bytes-length b))) #"'" b))

;; `[sig-val [eddsa [r 32:…] [s 32:…]]]` — the same gcrypt shape we parse when
;; verifying, built here for the signing direction.
(define (gcrypt-sig sig64)
  (bytes-append #"[" (syrup-symbol "sig-val")
                #"[" (syrup-symbol "eddsa")
                #"[" (syrup-symbol "r") (syrup-bytestring (subbytes sig64 0 32)) #"]"
                #"[" (syrup-symbol "s") (syrup-bytestring (subbytes sig64 32 64)) #"]"
                #"]]"))

(define (sign-with-our-key payload)
  (extract-latin1-bytes
   (last (run-prologos (format "(eval (sign-bytes ~aN ~s))"
                               keypair-handle
                               (bytes->string/latin-1 payload))))))

;; <op:deliver <desc:export 0> ['withdraw-gift <sig-envelope receive sig>] f f>
(define (withdraw-gift-frame their-side signed-give)
  (define receive
    (bytes-append #"<" (syrup-symbol "desc:handoff-receive")
                  (syrup-bytestring (session-id-of their-side))
                  (syrup-bytestring our-side-id)
                  #"0+"
                  signed-give
                  #">"))
  (define env
    (bytes-append #"<" (syrup-symbol "desc:sig-envelope")
                  receive (gcrypt-sig (sign-with-our-key receive)) #">"))
  (bytes-append #"<" (syrup-symbol "op:deliver")
                #"<" (syrup-symbol "desc:export") #"0+>"
                #"[" (syrup-symbol "withdraw-gift") env #"]"
                #"ff>"))

;; Gives we have been handed and not yet withdrawn, keyed by the exporter
;; location we must dial to redeem them.
(define pending-gives (make-hash))

;; ========================================
;; Outbound connections
;; ========================================
;;
;; The sturdyref enlivener queues a re-encoded sturdyref; we parse the host and
;; port out of its ocapn-peer hints and dial. This is the ONLY place this
;; process opens a connection rather than accepting one.
;;
;; Parsing is done here, in Racket, rather than in Prologos: the dialler is the
;; thing that needs the host and port, and handing it the peer's own bytes
;; keeps one representation on the wire instead of two.

;; Read a Syrup length-prefixed string that begins at `i` (digits, marker, body).
;; Returns (values body next-index) or (values #f #f).
(define (syrup-lenstr bs i marker)
  (let loop ([j i])
    (cond
      [(>= j (bytes-length bs)) (values #f #f)]
      [(and (>= (bytes-ref bs j) 48) (<= (bytes-ref bs j) 57)) (loop (add1 j))]
      [(= (bytes-ref bs j) marker)
       (define n (string->number (bytes->string/latin-1 (subbytes bs i j))))
       (if (and n (<= (+ j 1 n) (bytes-length bs)))
           (values (subbytes bs (add1 j) (+ j 1 n)) (+ j 1 n))
           (values #f #f))]
      [else (values #f #f)])))

;; The value of key `k` in a Syrup dict of string->string, by scanning for the
;; key's own length-prefixed form. Good enough for `{host …, port …}`, which is
;; all an ocapn-peer's hints carry.
(define (peer-hint bs k)
  (define needle (bytes-append (string->bytes/latin-1 (number->string (bytes-length k)))
                               #"\"" k))
  (define idx (let loop ([i 0])
                (cond [(> (+ i (bytes-length needle)) (bytes-length bs)) #f]
                      [(equal? (subbytes bs i (+ i (bytes-length needle))) needle) i]
                      [else (loop (add1 i))])))
  (and idx
       (let-values ([(v _) (syrup-lenstr bs (+ idx (bytes-length needle)) 34)])
         (and v (bytes->string/latin-1 v)))))

;; Dial the peer a sturdyref names and run the INITIATOR side of the handshake:
;; we send op:start-session first, then read theirs. Everything else in this
;; process has only ever done the reverse.
(define (dial-sturdyref! sr)
  (define bs (string->bytes/latin-1 sr))
  (define host (peer-hint bs #"host"))
  (define port (peer-hint bs #"port"))
  (cond
    [(not (and host port))
     (printf "ocapn-test-server: dial: no host/port in sturdyref~n")]
    [else
     (printf "ocapn-test-server: dialling ~a:~a~n" host port)
     (thread
      (lambda ()
        (with-handlers ([exn:fail?
                         (lambda (e)
                           (printf "ocapn-test-server: dial exn: ~a~n" (exn-message e)))])
          (define-values (din dout) (tcp-connect host (string->number port)))
          (write-frame dout start-session-bytes)
          ;; The peer may dial us back before answering. Keep this connection
          ;; addressable by the location we dialled, so the crossed-hellos rule
          ;; can abort it from the accepting thread.
          (hash-set! half-open-dials (record-field (string->bytes/latin-1 sr) 0)
                     (cons din dout))
          (define cid (next-conn-id!))
          (drive-init! cid)
          (let loop ([n 0])
            (define frame (with-handlers ([exn:fail? (lambda (e) #f)]) (read-frame din)))
            (cond
              [(or (eof-object? frame) (not frame))
               (printf "ocapn-test-server: outbound closed after ~a frames (conn ~a)~n" n cid)]
              [(zero? n)
               ;; Their start-session. If we dialled this peer to redeem a
               ;; handoff-give, everything the receive needs is now available:
               ;; their side-id comes out of this very frame.
               (let ([env (hash-ref pending-gives (location-of-start-session frame) #f)])
                 (when env
                   (hash-remove! pending-gives (location-of-start-session frame))
                   (define w (withdraw-gift-frame (side-id-of-start-session frame) env))
                   (printf "ocapn-test-server: withdrawing gift (~a bytes)~n" (bytes-length w))
                   (write-frame dout w)))
               (loop (add1 n))]
              [else
               (note-handoff-give! frame)
               (define out (drive-step cid frame))
               (when (> (bytes-length out) 0) (write-frame dout out))
               (loop (add1 n))]))
          (close-input-port din)
          (close-output-port dout))))]))

;; A signed handoff-give anywhere in an inbound frame means we are the
;; receiver. Found by scanning for the record marker rather than by walking
;; the message: the give can sit at any depth in the args, and the marker is
;; unambiguous — `desc:handoff-give` appears nowhere else on the wire.
(define give-marker #"<17'desc:sig-envelope<17'desc:handoff-give")

(define (find-subbytes hay needle [from 0])
  (let loop ([i from])
    (cond [(> (+ i (bytes-length needle)) (bytes-length hay)) #f]
          [(equal? (subbytes hay i (+ i (bytes-length needle))) needle) i]
          [else (loop (add1 i))])))

(define (note-handoff-give! frame)
  (define i (find-subbytes frame give-marker))
  (when i
    (define env (subbytes frame i (syrup-skip frame i)))
    ;; field 0 of the envelope is the give; field 1 of the give is the
    ;; exporter location, which is also the key we dial on.
    (define give (record-field env 0))
    (define loc (record-field give 1))
    (printf "ocapn-test-server: handoff-give received; exporter location ~a bytes~n"
            (bytes-length loc))
    (hash-set! pending-gives loc env)
    (ocapn-dial-request (bytes->string/latin-1
                         (bytes-append #"<" (syrup-symbol "ocapn-sturdyref")
                                       loc (syrup-bytestring #"handoff") #">")))))

(define (drain-dials!)
  (for ([sr (in-list (ocapn-dial-drain '()))])
    (dial-sturdyref! sr)))

;; The post-handshake frame loop. Factored out of `handle-connection` so the
;; crossed-hellos winner can enter it too, after aborting the losing socket.
(define (run-frame-loop cin cout cid)
      (let loop ([n 1])
        (define frame (with-handlers ([exn:fail?
                                       (lambda (e)
                                         (printf "ocapn-test-server: read-frame exn after ~a frames: ~a~n"
                                                 n (exn-message e))
                                         #f)])
                        (read-frame cin)))
        (cond
          [(or (eof-object? frame) (not frame))
           (printf "ocapn-test-server: peer closed after ~a frames (conn ~a)~n" n cid)]
          [else
           (when (getenv "OCAPN_FRAME_HEX")
             (printf "ocapn-test-server: FRAME-HEX conn ~a n ~a: ~a~n"
                     cid (+ n 1) (bytes->hex-string frame)))
           (note-handoff-give! frame)
           (try-enliven! frame cout)
           (try-fetch-answer! frame)
           (define out (drive-step cid frame))
           (printf "ocapn-test-server: conn ~a frame ~a (~a in / ~a out bytes)~n"
                   cid (+ n 1) (bytes-length frame) (bytes-length out))
           (when (> (bytes-length out) 0)
             (write-frame cout out))
           ;; A step may have queued an outbound connection (the sturdyref
           ;; enlivener is the only thing that does).
           (drain-dials!)
           (loop (+ n 1))]))
)

(define (handle-connection cin cout)
  (with-handlers ([exn:fail? (lambda (e)
                               (printf "ocapn-test-server: handler exn: ~a~n"
                                       (exn-message e)))])
    (printf "ocapn-test-server: connection accepted, sending start-session (framing=~v)~n"
            (current-framing-strategy))
    (write-frame cout start-session-bytes)
    (printf "ocapn-test-server: sent ~a bytes; reading peer start-session~n"
            (bytes-length start-session-bytes))
    (define first-frame
      (with-handlers ([exn:fail? (lambda (e)
                                   (printf "ocapn-test-server: read-frame exn: ~a~n"
                                           (exn-message e))
                                   #f)])
        (read-frame cin)))
    (cond
      [(or (eof-object? first-frame) (not first-frame))
       (printf "ocapn-test-server: peer closed before sending start-session~n")]
      [else
       (define abort-reply (validate-incoming first-frame))
       (define crossed
         (and (zero? (bytes-length abort-reply))
              (hash-ref half-open-dials (location-of-start-session first-frame) #f)))
       (cond
         ;; Crossed hellos: we already dialled this peer and it has dialled us
         ;; back. Exactly one of the two connections dies, and which one is
         ;; decided by the side-ids alone -- so the peer reaches the same
         ;; verdict without another round trip.
         [crossed
          (define theirs (side-id-of-start-session first-frame))
          (define ours-first? (bytes<? our-side-id theirs))
          (printf "ocapn-test-server: crossed hellos; aborting the ~a connection~n"
                  (if ours-first? "OUTGOING" "incoming"))
          (define abort-bytes (build-abort-bytes "crossed hellos"))
          (cond
            [ours-first?
             ;; Our dial loses: abort the socket WE opened, and let this one live.
             (with-handlers ([exn:fail? void])
               (write-frame (cdr crossed) abort-bytes))
             (hash-remove! half-open-dials (location-of-start-session first-frame))
             (let ([cid (next-conn-id!)])
               (drive-init! cid)
               (run-frame-loop cin cout cid))]
            [else
             ;; Their dial loses: abort the socket THEY opened.
             (write-frame cout abort-bytes)])]
         [(zero? (bytes-length abort-reply))
          (define cid (next-conn-id!))
          (drive-init! cid)
          (printf "ocapn-test-server: inbound start-session accepted (conn ~a); driving captp-core~n"
                  cid)
          (record-open-conn! first-frame cout)
          (run-frame-loop cin cout cid)]
         [else
          (printf "ocapn-test-server: inbound start-session REJECTED (~a bytes); sending op:abort~n"
                  (bytes-length abort-reply))
          (write-frame cout abort-reply)])]))
  (close-input-port cin)
  (close-output-port cout))

;; ========================================
;; Main loop
;; ========================================

(define listener (tcp-listen (port-arg) 4 #t "127.0.0.1"))
(printf "ocapn-test-server: listening on 127.0.0.1:~a~n" (port-arg))
(flush-output)

(let accept-loop ()
  (define-values (cin cout) (tcp-accept listener))
  (thread (lambda () (handle-connection cin cout)))
  (accept-loop))
