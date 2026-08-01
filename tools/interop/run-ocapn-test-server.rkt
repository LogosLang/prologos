#lang racket/base

;;;
;;; run-ocapn-test-server.rkt — the OCapN interop test server.
;;;
;;; Long-running Racket TCP server that speaks OCapN with the upstream
;;; ocapn-test-suite (Python). It accepts incoming connections, runs the
;;; handshake, and drives every post-handshake frame through captp-core.
;;;
;;; Division of labour:
;;;
;;;   Prologos owns the protocol. The signed op:start-session comes from
;;;   `prologos::ocapn::handshake` (`handshake-bytes-with-key`); inbound
;;;   handshake validation from `check-incoming-start-session`; every
;;;   post-handshake op from `prologos::ocapn::interop-driver`
;;;   (`init-connection` / `step-connection`). Crypto (libsodium FFI) and
;;;   the Syrup codec both live inside Prologos.
;;;
;;;   This file owns the sockets, and the two pieces of routing that
;;;   need one: the crossed-hellos tie-break (§ Crossed hellos) and the
;;;   third-party-handoff gifter/receiver plumbing (§ Third-party
;;;   handoff). Both have to write to a connection other than the one
;;;   being serviced, which a pure Prologos behaviour cannot do.
;;;
;;; Per connection:
;;;   1. Send our signed start-session.
;;;   2. Read the peer's; validate it through Prologos; op:abort on reject.
;;;   3. Run the frame loop — parse, route handoff traffic, hand the frame
;;;      to captp-core, write back whatever it produces.
;;;
;;; Known gap (docs/tracking/2026-07-28_OCAPN_IMPLEMENTATION_GAPS.md §1.8):
;;; the handoff routing here runs on the same bytes captp-core is about to
;;; see, and nothing forces the two to agree on what a frame means. The
;;; gates below (structural parse + export-position checks + receiver-key
;;; check) narrow the overlap; moving the routing into Prologos so there is
;;; one implementation is the real fix and needs an exported resolve-me
;;; from the connection's own export table.

(require racket/cmdline
         "../../racket/prologos/ocapn-dial-ffi.rkt"
         "../../racket/prologos/ocapn-conn-ffi.rkt"
         "../../racket/prologos/ocapn-peer-ffi.rkt"
         "../../racket/prologos/ocapn-identity-ffi.rkt"
         racket/tcp
         racket/list
         racket/string
         (only-in racket/random crypto-random-bytes)
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

;; The address we advertise in our own location, and the only address a
;; peer-named dial is allowed to reach unless the operator widens it.
(define advertised-host "127.0.0.1")

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

;; `process-string` shares elaborator state across calls, so EVERY call
;; into Prologos — validation, init, step, signing — is serialised here.
;; Connection threads and dial threads all reach these entry points.
(define validate-sema (make-semaphore 1))

(define (run-prologos/locked s)
  (call-with-semaphore validate-sema (lambda () (run-prologos s))))

;; `handshake-bytes-with-key` and friends produce a Latin-1 String of wire
;; bytes. The process-string result is pretty-printed as `"...." : String`;
;; `read` recovers the Racket string, which we convert to bytes. The regexp
;; over pretty-printer output IS the load-bearing discriminator here, which
;; is fragile — but it is the only channel `process-string` offers.
(define string-result-rx #px"^(\".*\") : String$")

(define (extract-latin1-bytes prologos-result)
  (define m (and (string? prologos-result) (regexp-match string-result-rx prologos-result)))
  (unless m
    (error 'extract-latin1-bytes "couldn't extract String from: ~s" prologos-result))
  (string->bytes/latin-1 (read (open-input-string (cadr m)))))

(define (last-result results)
  (and (pair? results) (last results)))

;; ========================================
;; Syrup: one complete, bounds-checked reader
;; ========================================
;;
;; Everything on the Racket side of this server that has to look inside a
;; frame goes through this reader. It lives here rather than calling out
;; to `prologos::ocapn::syrup-wire` because every call into Prologos is a
;; `process-string` under `validate-sema` — far too heavy to run per byte
;; slice — and because the crossed-hellos tie-break runs on the accept
;; thread before any connection state exists. It is deliberately the ONLY
;; Syrup reader in this file: the previous `syrup-skip` / `record-field` /
;; `syrup-lenstr` trio covered different subsets of the grammar and had
;; already drifted apart.
;;
;; It covers every form `contrib/syrup.py` emits or accepts, because the
;; peer chooses the bytes:
;;
;;   digits ':' bytes    bytestring     digits '"' bytes   string
;;   digits "'" bytes    symbol         digits '+'         nat
;;   digits '-'          negative int   't' / 'f'          bool
;;   'F' + 4 bytes       single float   'D' + 8 bytes      double
;;   '[' | '(' | 'l' … ']' | ')' | 'e'  list
;;   '{' | 'd'          … '}' | 'e'     dict
;;   '<' … '>'           record         '#' … '$'          set
;;
;; Every index is bounds-checked; a malformed or truncated value raises
;; `exn:fail:syrup`, which `syrup-parse` turns into #f. Nothing here can
;; walk off the end of a peer-supplied buffer.

(struct exn:fail:syrup exn:fail ())

(define (syrup-fail fmt . args)
  (raise (exn:fail:syrup (apply format fmt args) (current-continuation-marks))))

;; A parsed value. `start`/`end` bracket the value's own bytes in the
;; buffer it came from, so a caller that must reproduce the peer's bytes
;; VERBATIM — a location copied into a handoff-give, an envelope carried
;; into a handoff-receive and re-signed — slices instead of re-encoding.
;; Re-encoding is what makes a signature check depend on two encoders
;; agreeing byte for byte.
;;
;;   kind      val
;;   'bytes    payload bytes          'string  payload bytes
;;   'symbol   payload bytes          'int     exact integer
;;   'bool     #t / #f                'float   raw payload bytes
;;   'list     (listof syv)           'set     (listof syv)
;;   'dict     (listof (cons syv syv))
;;   'record   (cons label-syv (listof arg-syv))
(struct syv (kind val start end) #:transparent)

(define (syv-src bs v) (subbytes bs (syv-start v) (syv-end v)))

(define (byte-at bs i)
  (unless (and (>= i 0) (< i (bytes-length bs)))
    (syrup-fail "truncated Syrup value: offset ~a of ~a bytes" i (bytes-length bs)))
  (bytes-ref bs i))

(define (subbytes/checked bs from len)
  (unless (and (>= from 0) (<= (+ from len) (bytes-length bs)))
    (syrup-fail "truncated Syrup payload: ~a bytes at offset ~a of ~a"
                len from (bytes-length bs)))
  (subbytes bs from (+ from len)))

(define (list-close? b) (or (= b 93) (= b 41) (= b 101)))  ; ] ) e
(define (dict-close? b) (or (= b 125) (= b 101)))          ; } e
(define (record-close? b) (= b 62))                        ; >
(define (set-close? b) (= b 36))                           ; $

;; Read one value beginning at `i`. Returns (values syv next-index).
(define (syrup-read bs i)
  (define b (byte-at bs i))
  (cond
    [(or (= b 91) (= b 40) (= b 108))                      ; [ ( l
     (define-values (items j) (syrup-read-seq bs (add1 i) list-close?))
     (values (syv 'list items i j) j)]
    [(or (= b 123) (= b 100))                              ; { d
     (define-values (pairs j) (syrup-read-dict bs (add1 i)))
     (values (syv 'dict pairs i j) j)]
    [(= b 60)                                              ; <
     (define-values (label j0) (syrup-read bs (add1 i)))
     (define-values (args j) (syrup-read-seq bs j0 record-close?))
     (values (syv 'record (cons label args) i j) j)]
    [(= b 35)                                              ; #
     (define-values (items j) (syrup-read-seq bs (add1 i) set-close?))
     (values (syv 'set items i j) j)]
    [(= b 116) (values (syv 'bool #t i (add1 i)) (add1 i))] ; t
    [(= b 102) (values (syv 'bool #f i (add1 i)) (add1 i))] ; f
    [(= b 70)                                              ; F — single float
     (values (syv 'float (subbytes/checked bs (add1 i) 4) i (+ i 5)) (+ i 5))]
    [(= b 68)                                              ; D — double float
     (values (syv 'float (subbytes/checked bs (add1 i) 8) i (+ i 9)) (+ i 9))]
    [(and (>= b 48) (<= b 57)) (syrup-read-prefixed bs i)]
    [else (syrup-fail "unexpected Syrup byte ~a at offset ~a" b i)]))

(define (syrup-read-seq bs i close?)
  (let loop ([i i] [acc '()])
    (define b (byte-at bs i))
    (if (close? b)
        (values (reverse acc) (add1 i))
        (let-values ([(v j) (syrup-read bs i)])
          (loop j (cons v acc))))))

(define (syrup-read-dict bs i)
  (let loop ([i i] [acc '()])
    (define b (byte-at bs i))
    (if (dict-close? b)
        (values (reverse acc) (add1 i))
        (let*-values ([(k j0) (syrup-read bs i)]
                      [(v j) (syrup-read bs j0)])
          (loop j (cons (cons k v) acc))))))

;; digits, then exactly one of `: " ' + -`.
(define (syrup-read-prefixed bs i)
  (let loop ([j i])
    (define b (byte-at bs j))
    (cond
      [(and (>= b 48) (<= b 57)) (loop (add1 j))]
      [else
       (define n (string->number (bytes->string/latin-1 (subbytes bs i j))))
       (unless n (syrup-fail "empty Syrup length prefix at offset ~a" i))
       (cond
         [(= b 43) (values (syv 'int n i (add1 j)) (add1 j))]          ; +
         [(= b 45) (values (syv 'int (- n) i (add1 j)) (add1 j))]      ; -
         [(or (= b 58) (= b 34) (= b 39))                              ; : " '
          (define payload (subbytes/checked bs (add1 j) n))
          (define end (+ j 1 n))
          (values (syv (cond [(= b 58) 'bytes] [(= b 34) 'string] [else 'symbol])
                       payload i end)
                  end)]
         [else (syrup-fail "unexpected Syrup byte ~a after a length prefix at offset ~a"
                           b j)])])))

;; Parse the whole of `bs` as exactly one Syrup value. Returns #f when it
;; is malformed or has trailing bytes. The peer chooses these bytes, so a
;; failure is a logged reject — never an exception escaping into a
;; connection handler.
(define (syrup-parse bs)
  (with-handlers ([exn:fail:syrup? (lambda (e) #f)])
    (define-values (v j) (syrup-read bs 0))
    (and (= j (bytes-length bs)) v)))

;; ----------------------------------------
;; Accessors over a parsed value
;; ----------------------------------------

(define (syv-record? v label)
  (and (syv? v)
       (eq? (syv-kind v) 'record)
       (let ([l (car (syv-val v))])
         (and (eq? (syv-kind l) 'symbol) (equal? (syv-val l) label)))))

(define (syv-args v) (cdr (syv-val v)))

(define (syv-arg v n)
  (and (syv? v)
       (eq? (syv-kind v) 'record)
       (let ([args (syv-args v)])
         (and (> (length args) n) (list-ref args n)))))

(define (syv-symbol? v name)
  (and (syv? v) (eq? (syv-kind v) 'symbol) (equal? (syv-val v) name)))

(define (syv-nat v)
  (and (syv? v) (eq? (syv-kind v) 'int) (>= (syv-val v) 0) (syv-val v)))

(define (syv-text v)
  (and (syv? v) (memq (syv-kind v) '(bytes string symbol)) (syv-val v)))

;; The STRUCTURAL children of a value. Deliberately does NOT descend into
;; a bytestring's payload: the peer controls those bytes and can put
;; anything in them, including the exact byte pattern of a record we act
;; on. Every "is there a X inside this frame" question in this file goes
;; through `syv-find`, so no peer-supplied payload can be mistaken for
;; structure — which is what the raw `find-subbytes` scans this replaced
;; could not distinguish.
(define (syv-children v)
  (case (syv-kind v)
    [(list set) (syv-val v)]
    [(record) (syv-val v)]                                  ; label + args
    [(dict) (append (map car (syv-val v)) (map cdr (syv-val v)))]
    [else '()]))

(define (syv-find v ok?)
  (let loop ([v v])
    (cond [(ok? v) v]
          [else (for/or ([c (in-list (syv-children v))]) (loop c))])))

;; ----------------------------------------
;; The encoding half
;; ----------------------------------------

(define (syrup-nat n)
  (bytes-append (string->bytes/latin-1 (number->string n)) #"+"))

(define (syrup-bytestring b)
  (bytes-append (string->bytes/latin-1 (number->string (bytes-length b))) #":" b))

(define (syrup-symbol s)
  (define b (string->bytes/latin-1 s))
  (bytes-append (string->bytes/latin-1 (number->string (bytes-length b))) #"'" b))

;; `<tag N>` — the shape every desc:* position descriptor has.
(define (desc-record tag n)
  (bytes-append #"<" (syrup-symbol tag) (syrup-nat n) #">"))

;; `[sig-val [eddsa [r 32:…] [s 32:…]]]` — the same gcrypt shape we parse
;; when verifying, built here for the signing direction.
(define (gcrypt-sig sig64)
  (bytes-append #"[" (syrup-symbol "sig-val")
                #"[" (syrup-symbol "eddsa")
                #"[" (syrup-symbol "r") (syrup-bytestring (subbytes sig64 0 32)) #"]"
                #"[" (syrup-symbol "s") (syrup-bytestring (subbytes sig64 32 64)) #"]"
                #"]]"))

;; `<op:abort "reason">`. Built directly rather than through captp-wire:
;; this runs on the accept thread before any connection state exists, and
;; the frame is two atoms.
(define (build-abort-bytes reason)
  (define r (string->bytes/latin-1 reason))
  (bytes-append #"<8'op:abort"
                (string->bytes/latin-1 (number->string (bytes-length r)))
                #"\"" r #">"))

;; ========================================
;; OCapN shapes, read structurally
;; ========================================
;;
;; `<op:start-session VERSION PUBKEY LOCATION SIG>`
;; `<ocapn-sturdyref <ocapn-peer TRANSPORT ADDRESS HINTS> SWISS>`
;; `<op:deliver TO ARGS ANSWER-POS RESOLVE-ME>`
;;
;; (utils/captp_types.py OpStartSession/OpDeliver, utils/ocapn_uris.py.)

;; A peer is identified by its LOCATION, not by host:port — ephemeral
;; ports get reused across tests in a long-running server. But the
;; location's raw BYTES are the wrong key: `half-open-dials` is populated
;; from a sturdyref our own re-encoder produced, and looked up against the
;; peer's verbatim `op:start-session` field, and nothing makes those
;; byte-identical (a hints dict written in a different key order encodes
;; differently and still names the same peer). The key is therefore the
;; pair that identifies a peer independently of encoding: transport and
;; address. Upstream mints ADDRESS as `uuid.uuid4().hex` per netlayer
;; (netlayers/testing_only_tcp.py:49-56), so it is unique per peer.
;;
;; A location we cannot parse falls back to its raw bytes — usable as a
;; key, just encoding-sensitive, which is where we started.
(define (location-key loc-bytes)
  (define v (syrup-parse loc-bytes))
  (or (and v
           (syv-record? v #"ocapn-peer")
           (let ([transport (and (syv-arg v 0) (syv-text (syv-arg v 0)))]
                 [address (and (syv-arg v 1) (syv-text (syv-arg v 1)))])
             (and transport address (bytes-append transport #"\0" address))))
      loc-bytes))

;; The value of hint `k`, as a string. HINTS is a Syrup DICT with STRING
;; keys upstream (`{"host": …, "port": …}`, testing_only_tcp.py:53-55).
;; A LIST OF PAIRS and SYMBOL keys are read too: our own encoder emitted a
;; symbol-keyed list until `handshake.prologos` was corrected, and this
;; reader has to be able to read a sturdyref we produced as readily as one
;; the peer produced. It is a parse of the hints structure, not a scan —
;; scanning for `4"host` anywhere in the sturdyref matched inside a hint
;; VALUE just as happily as at a key position.
(define (hint-key=? k key)
  (equal? (syv-text k) key))

(define (hint-ref hints key)
  (and (syv? hints)
       (case (syv-kind hints)
         [(dict)
          (for/or ([kv (in-list (syv-val hints))])
            (and (hint-key=? (car kv) key) (cdr kv)))]
         [(list)
          (for/or ([item (in-list (syv-val hints))])
            (and (eq? (syv-kind item) 'list)
                 (= (length (syv-val item)) 2)
                 (hint-key=? (car (syv-val item)) key)
                 (cadr (syv-val item))))]
         [else #f])))

(define (hint-string hints key)
  (define v (hint-ref hints key))
  (and v
       (cond [(syv-text v) => bytes->string/latin-1]
             [(eq? (syv-kind v) 'int) (number->string (syv-val v))]
             [else #f])))

(struct sturdyref (loc-bytes loc-key host port swiss) #:transparent)

;; `node` is a parsed `<ocapn-sturdyref …>` inside the buffer `bs`.
(define (sturdyref-of bs node)
  (and (syv-record? node #"ocapn-sturdyref")
       (let ([peer (syv-arg node 0)]
             [swiss (syv-arg node 1)])
         (and peer swiss (syv-record? peer #"ocapn-peer")
              (let ([loc (syv-src bs peer)]
                    [hints (syv-arg peer 2)])
                (sturdyref loc (location-key loc)
                           (hint-string hints #"host")
                           (hint-string hints #"port")
                           (syv-src bs swiss)))))))

(define (read-sturdyref bs)
  (define v (syrup-parse bs))
  (and v (sturdyref-of bs v)))

;; `<op:deliver TO ARGS ANSWER-POS RESOLVE-ME>` — the four fields, or #f.
(define (read-deliver v)
  (and (syv-record? v #"op:deliver")
       (= (length (syv-args v)) 4)
       (syv-args v)))

;; The position inside `<desc:export N>` / `<desc:import-object N>`.
(define (desc-position v label)
  (and (syv-record? v label) (syv-nat (syv-arg v 0))))

;; The position inside a RESOLVE-ME slot. Both descriptors are valid there --
;; `captp-wire.prologos` documents the pair -- and accepting only
;; `desc:import-object` silently dropped an enliven whose resolver was a
;; promise, with nothing logged.
(define (resolve-me-position v)
  (or (desc-position v #"desc:import-object")
      (desc-position v #"desc:import-promise")))

;; The raw 32-byte Ed25519 key inside a gcrypt public-key s-expression
;; `[public-key [ecc [curve Ed25519] [flags eddsa] [q 32:…]]]`. Compared
;; instead of the encoded form: the encoded form is only equal to a peer's
;; re-encoding of it if both encoders agree byte for byte, and that is not
;; something this file can assert about a peer's encoder.
(define (gcrypt-pubkey-raw v)
  (and (syv? v)
       (eq? (syv-kind v) 'list)
       (let ([items (syv-val v)])
         (and (= (length items) 2)
              (syv-symbol? (car items) #"public-key")
              (let ([ecc (cadr items)])
                (and (eq? (syv-kind ecc) 'list)
                     (for/or ([sub (in-list (syv-val ecc))])
                       (and (eq? (syv-kind sub) 'list)
                            (= (length (syv-val sub)) 2)
                            (syv-symbol? (car (syv-val sub)) #"q")
                            (syv-text (cadr (syv-val sub)))))))))))

;; What we keep from a peer's op:start-session.
(struct peer-hello (pubkey-bytes pubkey-raw location-bytes location-key side-id)
  #:transparent)

;; A side-id is SHA-256 applied twice to the gcrypt-encoded public key —
;; and that encoding is byte-for-byte field 1 of the op:start-session
;; already in hand, so this needs no key parsing and no re-encoding.
;; (Verified against upstream's own `our_side_id`, utils/captp.py:113-123,
;; which hashes exactly those bytes.)
(define (read-start-session frame)
  (define v (syrup-parse frame))
  (and v
       (syv-record? v #"op:start-session")
       (= (length (syv-args v)) 4)
       (let ([pk (syv-arg v 1)]
             [loc (syv-arg v 2)])
         (let ([pk-bytes (syv-src frame pk)]
               [loc-bytes (syv-src frame loc)])
           (peer-hello pk-bytes
                       (gcrypt-pubkey-raw pk)
                       loc-bytes
                       (location-key loc-bytes)
                       (sha256-bytes (sha256-bytes pk-bytes)))))))

;; ========================================
;; Our identity
;; ========================================

;; ONE keypair for the process, held rather than discarded. A third-party
;; handoff must sign a desc:handoff-receive with the same key the gifter
;; named as the receiver -- which is the key we handshake with -- so the
;; handle has to outlive the handshake, hence `handshake-bytes-with-key`
;; taking one rather than minting its own.
;;
;; KNOWN DEVIATION (gaps doc §1.8 M2): upstream mints a fresh Ed25519 key
;; per SESSION (utils/captp.py:49-50); we use one per process, so
;; `our-side-id` is a constant and `session-id-of` depends only on the
;; peer's side-id. A peer that reuses a session key across two connections
;; to us therefore gets the same session-id twice, and the handoff replay
;; guard (keyed on session) refuses its legitimate second handoff. Fixing
;; it means a keypair, a start-session and a side-id per connection, plus
;; picking the signing key by the give's receiver-key and taking the
;; crossed-hellos comparison from the dialled connection rather than a
;; process constant.
(define keypair-handle
  (let ([r (last-result (run-prologos "(eval (gen-keypair-raw unit))"))])
    (or (and (string? r)
             (let ([m (regexp-match #px"^([0-9]+)N? : Nat$" r)])
               (and m (string->number (cadr m)))))
        (error 'run-ocapn-test-server "could not read keypair handle from: ~s" r))))

;; Tell the PROLOGOS side which key we are. It signs with the same one: a
;; handoff-give names the gifter's session key, and the peer checks it against
;; the key we presented in our own op:start-session -- two keys would be two
;; identities, and the check would fail on a give we did make.
(ocapn-identity-set! keypair-handle)

;; The peer designator. Upstream uses `uuid.uuid4().hex` per netlayer
;; (testing_only_tcp.py:49-56) precisely so it is unique; a literal meant
;; every instance of this server advertised the same one, and since
;; `open-conns` and `half-open-dials` are both keyed by
;; location, that is one hint collision away from cross-peer confusion.
(define peer-designator (bytes->hex-string (crypto-random-bytes 16)))

(define start-session-bytes
  (extract-latin1-bytes
   (last-result
    (run-prologos
     (format "(eval (handshake-bytes-with-key ~s ~aN \"tcp-testing-only\" ~s ~s ~s))"
             (version-arg)
             keypair-handle
             peer-designator
             advertised-host
             (number->string (port-arg)))))))

;; Read our own identity back out of the frame we just built, and fail at
;; startup if we cannot. Everything downstream that decides "is this
;; addressed to us" leans on these, so an unreadable start-session must be
;; a startup error rather than a gate that silently stops gating.
(define our-hello
  (or (read-start-session start-session-bytes)
      (error 'run-ocapn-test-server
             "could not parse the op:start-session we just built (~a bytes)"
             (bytes-length start-session-bytes))))

(define our-pubkey-raw
  (or (peer-hello-pubkey-raw our-hello)
      (error 'run-ocapn-test-server
             "could not read our own Ed25519 key out of our start-session")))

(define our-side-id (peer-hello-side-id our-hello))

;; The session id is defined by upstream (utils/captp.py:125-146) as
;;   SHA256(SHA256("prot0" ++ min(sideA,sideB) ++ max(sideA,sideB)))
;; and the receiving-side is our own side-id. Both are computable the
;; moment the peer's op:start-session arrives.
(define (session-id-of their-side)
  (define lo (if (bytes<? our-side-id their-side) our-side-id their-side))
  (define hi (if (bytes<? our-side-id their-side) their-side our-side-id))
  (sha256-bytes (sha256-bytes (bytes-append #"prot0" lo hi))))

(printf "ocapn-test-server: built signed start-session (~a bytes, designator ~a) via prologos::ocapn::handshake~n"
        (bytes-length start-session-bytes) peer-designator)
(flush-output)

;; ========================================
;; Calls into Prologos
;; ========================================

;; Validate an inbound op:start-session. Returns the empty byte string to
;; accept, or op:abort wire bytes to send before closing. A failure that
;; is not a clean reject — the checker raising, or a result the pretty
;; printer did not shape the way we expect — comes back as an abort too,
;; loudly, rather than propagating out and closing the socket with no
;; reason on the wire.
(define (validate-incoming frame-bytes)
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (printf "ocapn-test-server: start-session validation FAILED to run: ~a~n"
                             (exn-message e))
                     (build-abort-bytes "start-session validation failed"))])
    (extract-latin1-bytes
     (last-result
      (run-prologos/locked
       (format "(eval (check-incoming-start-session ~s ~s))"
               (version-arg)
               (bytes->hex-string frame-bytes)))))))

;; Seed per-connection captp-core state. `init-connection : Nat -> Bool`,
;; so anything other than `true` means the ConnectionState was never
;; stashed and every later step will run against ocapn-conn-ffi's
;; fallback — worth a line, since the symptom otherwise appears frames
;; later as an unexplained empty reply.
(define (drive-init! cid [start-session-frame #f] [cout #f])
  (define r (with-handlers ([exn:fail? (lambda (e) (exn-message e))])
              (last-result (run-prologos/locked (format "(eval (init-connection ~aN))" cid)))))
  (unless (and (string? r) (regexp-match? #px"^true : Bool$" r))
    (printf "ocapn-test-server: init-connection did NOT land for conn ~a: ~s~n" cid r))
  ;; Hand the peer's op:start-session to captp-core as well.
  ;;
  ;; This frame is consumed here for the handshake -- validated, and sliced
  ;; for the peer's location and side-id -- and it used to stop there, so
  ;; `connection-step` never saw a start-session at all and BridgeState's
  ;; record of WHO this peer is stayed empty. That record is what binds a
  ;; deposited gift to its gifter, so without it every third-party handoff
  ;; fails verification: the exporter has no key to check the give against.
  ;;
  ;; The op:start-session arm is state-only for the SESSION itself, but the
  ;; step is also where a parked third-party give is redeemed: a session
  ;; opening with a peer we hold a give against emits the withdraw right here
  ;; (`withdraw-frames` in interop-driver.prologos). So bytes coming back are
  ;; expected, and they have to be WRITTEN -- discarding them, which is what
  ;; this did while the receiver role lived in Racket, silently drops the
  ;; withdraw and the handoff never completes.
  (when start-session-frame
    (define out (drive-step cid start-session-frame))
    (unless (zero? (bytes-length out))
      (printf "ocapn-test-server: start-session step emitted ~a bytes on conn ~a~n"
              (bytes-length out) cid)
      (cond
        [cout (send-frame cout out)]
        [else
         (printf "ocapn-test-server: NO PORT to write the start-session reply on conn ~a~n"
                 cid)])))
  (void))

;; The outbound wire bytes for one frame, or #"" when captp-core produced
;; nothing. A step that fails must not take down the connection —
;; captp-core can legitimately be handed an op it does not service — but
;; it must not be indistinguishable from "nothing to send" either, so each
;; failure mode logs a distinct line naming the connection and the frame.
;; The peer still gets no bytes: emitting an op:abort here would close
;; sessions the suite expects to keep using.
(define (drive-step cid frame-bytes)
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (printf "ocapn-test-server: STEP RAISED (conn ~a, ~a-byte frame ~a): ~a~n"
                             cid (bytes-length frame-bytes)
                             (bytes->hex-string frame-bytes) (exn-message e))
                     #"")])
    (define r (last-result
               (run-prologos/locked
                (format "(eval (step-connection ~aN ~s))"
                        cid (bytes->hex-string frame-bytes)))))
    (cond
      [(not (string? r))
       (printf "ocapn-test-server: STEP PRODUCED NO STRING (conn ~a, frame ~a)~n"
               cid (bytes->hex-string frame-bytes))
       #""]
      [(regexp-match string-result-rx r)
       => (lambda (m) (string->bytes/latin-1 (read (open-input-string (cadr m)))))]
      [else
       (printf "ocapn-test-server: STEP RESULT UNPARSABLE (conn ~a): ~a~n" cid r)
       #""])))

(define (sign-with-our-key payload)
  (extract-latin1-bytes
   (last-result (run-prologos/locked
                 (format "(eval (sign-bytes ~aN ~s))"
                         keypair-handle
                         (bytes->string/latin-1 payload))))))

;; ========================================
;; Shared mutable state
;; ========================================
;;
;; Every table below is read and written from per-connection accept
;; threads AND from dial threads, so all of it sits behind one lock.
;; `with-state` bodies must stay small and must never call anything that
;; takes `state-sema` again — `call-with-semaphore` is not reentrant.
;; Counters get their own lock so a counter bump can happen inside a
;; state-locked region without deadlocking.

(define state-sema (make-semaphore 1))
(define-syntax-rule (with-state body ...)
  (call-with-semaphore state-sema (lambda () body ...)))

(define counter-sema (make-semaphore 1))
(define (next-counter! bx)
  (call-with-semaphore counter-sema
    (lambda ()
      (define n (unbox bx))
      (set-box! bx (add1 n))
      n)))

(define conn-id-box (box 0))
(define (next-conn-id!) (next-counter! conn-id-box))

;; The export position a fetch replies to, the gift ids, and the per-session
;; handoff counts: ALL MIGRATED. The position now comes from
;; `reserve-export-id` (interop-driver.prologos), which allocates from the
;; vat's own allocator instead of from a counter that started at 900 and was
;; reserved from it by nothing but distance; the ids from
;; `ocapn-gift-id` (ocapn-enliven-ffi.rkt); the counts from
;; `ocapn-handoff-count` (ocapn-give-ffi.rkt).

;; ----------------------------------------
;; Frame writing
;; ----------------------------------------
;;
;; The gifter path writes to a connection other than the one being
;; serviced, so two threads can target one output port. Under 'newline
;; framing `write-frame` is TWO port operations (payload, then 0x0a), so
;; an interleave splits a frame; under 'raw-syrup a large frame can still
;; be interleaved by the port. One semaphore per port serialises them.
(define port-locks (make-weak-hasheq))
(define port-locks-sema (make-semaphore 1))

(define (port-lock port)
  (call-with-semaphore port-locks-sema
    (lambda () (hash-ref! port-locks port (lambda () (make-semaphore 1))))))

(define (send-frame port payload)
  (call-with-semaphore (port-lock port)
    (lambda () (write-frame port payload))))

;; ----------------------------------------
;; Open connections
;; ----------------------------------------
;;
;; Here BOTH handoff sessions can be ones the peer opened to us. The
;; sturdyref names the exporter session's own location and the peer never
;; accepts a socket for it, so the enlivener must REUSE the open
;; connection whose peer location matches rather than dial — a dial
;; completes against an unaccepted listen backlog and then blocks with
;; zero bytes forever.
;;
;; Keyed by location, which names a PEER and not a connection, so the
;; value is a LIST: a peer with two concurrent sessions used to have its
;; first one's routing entry silently overwritten by its second. Entries
;; are removed when their connection closes, so a stale closed port is no
;; longer handed to a write.

;; `cid` is the connection id captp-core knows this peer by. Without it the
;; gifter path could not ask the driver to act in the exporter's namespace --
;; which is why the enliven resolve-me used to be a Racket counter.
(struct conn-entry (out pubkey-bytes side-id cid) #:transparent)

(define open-conns (make-hash))
(define pubkey-by-out (make-hasheq))

;; connection id -> output port. The registry the Prologos side consults maps
;; LOCATION -> cid; this is the other half, and it stays here because a port
;; is the one thing that cannot cross the FFI boundary.
(define out-by-cid (make-hash))

(define (record-open-conn! hello cout cid)
  (define e (conn-entry cout (peer-hello-pubkey-bytes hello) (peer-hello-side-id hello) cid))
  (with-state
    (hash-update! open-conns (peer-hello-location-key hello) (lambda (es) (cons e es)) '())
    (hash-set! pubkey-by-out cout (peer-hello-pubkey-bytes hello))
    (hash-set! out-by-cid cid cout))
  ;; And tell the PROLOGOS side, which resolves a location to a connection
  ;; when a role asks to reach a peer by name. The SIDE-ID goes with it: a
  ;; give redeemed over a session that was already open needs that session's
  ;; id, and the id is derived from the two side-ids, so registering only the
  ;; connection would let a role find it and then be unable to name it.
  (when (getenv "OCAPN_FRAME_HEX")
    (printf "ocapn-test-server: REGISTER conn ~a key-hex ~a~n"
            cid (bytes->hex-string (peer-hello-location-key hello))))
  (ocapn-peer-register (bytes->string/latin-1 (peer-hello-location-key hello))
                       cid
                       (bytes->string/latin-1 (peer-hello-side-id hello)))
  (void))

;; Write everything the Prologos side queued for a connection other than the
;; one being serviced. Entries are "<cid>:<payload>" with the payload as raw
;; Latin-1 wire bytes.
;;
;; Split at the first colon BY INDEX, not by regexp: the payload is arbitrary
;; bytes, and `#px"^([0-9]+):(.*)$"` fails outright on one containing a
;; newline, because `.` does not match one and a frame carrying 0x0a is
;; entirely ordinary.
(define (drain-sends!)
  (for ([entry (in-list (ocapn-send-drain '()))])
    (define i (for/first ([c (in-string entry)] [k (in-naturals)] #:when (char=? c #\:)) k))
    (cond
      [(not i)
       (printf "ocapn-test-server: unparseable queued send (no separator, ~a chars)~n"
               (string-length entry))]
      [else
       (define cid (string->number (substring entry 0 i)))
       (define port (and cid (with-state (hash-ref out-by-cid cid #f))))
       (cond
         [(not port)
          (printf "ocapn-test-server: queued send for connection ~a, which we have no port for~n" cid)]
         [else
          (guarded "queued send"
                   (lambda ()
                     (define payload (string->bytes/latin-1 (substring entry (add1 i))))
                     (printf "ocapn-test-server: queued send -> conn ~a (~a bytes)~n"
                             cid (bytes-length payload))
                     (when (getenv "OCAPN_FRAME_HEX")
                       (printf "ocapn-test-server: QUEUED-HEX conn ~a: ~a~n"
                               cid (bytes->hex-string payload)))
                     (send-frame port payload)))])])))

(define (forget-open-conn! hello cout)
  (when hello
    (with-state
      (define key (peer-hello-location-key hello))
      (define left (filter (lambda (e) (not (eq? (conn-entry-out e) cout)))
                           (hash-ref open-conns key '())))
      (if (null? left) (hash-remove! open-conns key) (hash-set! open-conns key left))
      (hash-remove! pubkey-by-out cout)))
  (void))

;; The newest still-open connection to that peer, or #f.
(define (open-conn-for key)
  (with-state
    (for/first ([e (in-list (hash-ref open-conns key '()))]
                #:when (not (port-closed? (conn-entry-out e))))
      e)))

;; ========================================
;; Crossed hellos
;; ========================================
;;
;; Two peers can dial each other at the same moment and end up with two
;; sessions where there should be one. CapTP breaks the tie with a rule
;; both sides can evaluate independently and agree on without another
;; round trip: sort the two SIDE-IDS as octet strings, and abort the
;; connection DIALLED BY whichever sorts first.
;;
;; An entry lives only for as long as the race can still be running: it is
;; dropped when the dial's own handshake completes (at that point the peer
;; answered us, so it was not dialling us simultaneously), when the dial
;; thread exits, and in any case after `crossed-hellos-window`. It used to
;; be removed on exactly one of the three branches that consume it, so a
;; completed dial left a permanent entry and every later connection from
;; that peer was aborted for the life of the process.

(define crossed-hellos-window 60.0)   ; seconds

;; location key -> (vector din dout deadline)
(define half-open-dials (make-hash))

(define (note-half-open-dial! key din dout)
  (with-state
    (hash-set! half-open-dials key
               (vector din dout (+ (/ (current-inexact-milliseconds) 1000.0)
                                   crossed-hellos-window))))
  (void))

(define (drop-half-open-dial! key)
  (with-state (hash-remove! half-open-dials key))
  (void))

;; The still-live dial to that peer, or #f. Expired entries are dropped on
;; the way past.
(define (half-open-dial-for key)
  (with-state
    (define v (hash-ref half-open-dials key #f))
    (cond
      [(not v) #f]
      [(< (vector-ref v 2) (/ (current-inexact-milliseconds) 1000.0))
       (hash-remove! half-open-dials key)
       #f]
      [else v])))

;; ========================================
;; Third-party handoff — BOTH ROLES MIGRATED
;; ========================================
;;
;; The GIFTER (`pending-enlivens`, `try-enliven!`, `claim-enliven!`,
;; `try-fetch-answer!`, `finish-fetch-answer!`) and the RECEIVER
;; (`pending-gives`, `withdraw-gift-frame`, `note-handoff-give!`,
;; `redeem-gift-if-pending!`, `redeem-gift-for-hello!`) both used to live
;; here: byte-scanners running over every inbound frame with their own Syrup
;; parser, alongside captp-core's, on the same bytes (gaps document §1.7 M8).
;;
;; Both are now `interop-driver.prologos`, working on the DECODED op. They
;; moved once three things existed: a signing key reachable from Prologos
;; (ocapn-identity-ffi.rkt + `sig-envelope-bytes`), a way to name a peer other
;; than the one being serviced (the connection registry), and an export
;; position allocated by the vat's own allocator rather than by a counter
;; starting at 900 (`reserve-export-id`, §1.7 M7).

;; ========================================
;; Outbound connections
;; ========================================
;;
;; The sturdyref enlivener queues a re-encoded sturdyref; we parse the
;; host and port out of its ocapn-peer hints and dial. This is the ONLY
;; place this process opens a connection rather than accepting one.
;;
;; The host comes from a peer, so it is attacker-chosen input. The
;; listener is loopback-only, and every netlayer the upstream suite
;; creates binds to the host out of our own locator
;; (netlayers/testing_only_tcp.py via tools/interop/ocapn-run-tests.py) —
;; which is `advertised-host` — so loopback is the complete legitimate
;; set. OCAPN_DIAL_ALLOW widens it (comma-separated hosts, or `*`).

(define dial-allow-extra
  (let ([v (getenv "OCAPN_DIAL_ALLOW")])
    (if v (map string-trim (string-split v ",")) '())))

(define (dial-allowed? host)
  (and host
       (or (and (member "*" dial-allow-extra) #t)
           (and (member host dial-allow-extra) #t)
           (and (member host (list advertised-host "localhost" "::1" "[::1]")) #t)
           (regexp-match? #px"^127\\.[0-9.]+$" host))))

;; A dial is only worth opening when we have no connection to that peer
;; already and none in flight. Both matter:
;;
;;   * `interop-driver`'s `maybe-dial` queues a dial for EVERY enliven,
;;     including the gifter case where the exporter session is already
;;     open. That dial connects to a listen backlog nobody accepts and
;;     then blocks on a read forever, leaking a thread, a socket, a
;;     conn-id and a half-open-dials entry per enliven.
;;   * A peer that replays a frame carrying a handoff-give must not get
;;     one socket per copy.
(define max-outstanding-dials 8)
(define dials-in-flight (make-hash))

(define (claim-dial! key)
  (with-state
    (cond
      [(hash-ref dials-in-flight key #f) 'in-flight]
      [(for/first ([e (in-list (hash-ref open-conns key '()))]
                   #:when (not (port-closed? (conn-entry-out e))))
         e)
       'reuse]
      [(>= (hash-count dials-in-flight) max-outstanding-dials) 'full]
      [else (hash-set! dials-in-flight key #t) 'go])))

(define (release-dial! key)
  (with-state (hash-remove! dials-in-flight key))
  (void))

;; Dial the peer a sturdyref names and run the INITIATOR side of the
;; handshake: we send op:start-session first, then read theirs. Everything
;; else in this process has only ever done the reverse.
(define (dial-sturdyref! sr-string)
  (define sr (read-sturdyref (string->bytes/latin-1 sr-string)))
  (cond
    [(not sr)
     (printf "ocapn-test-server: dial: not a well-formed ocapn-sturdyref; ignoring~n")]
    [(not (and (sturdyref-host sr) (sturdyref-port sr)
               (string->number (sturdyref-port sr))))
     (printf "ocapn-test-server: dial: no readable host/port hints in the sturdyref; ignoring~n")]
    [(not (dial-allowed? (sturdyref-host sr)))
     (printf "ocapn-test-server: dial REFUSED ~a:~a — not on the dial allow-list (set OCAPN_DIAL_ALLOW to widen)~n"
             (sturdyref-host sr) (sturdyref-port sr))]
    [else
     (case (claim-dial! (sturdyref-loc-key sr))
       [(reuse)
        (printf "ocapn-test-server: dial to ~a:~a skipped — a session to that peer is already open~n"
                (sturdyref-host sr) (sturdyref-port sr))
        ;; A give whose dial we skip still has to be redeemed over the session
        ;; we already have -- and it is, before the dial is ever requested:
        ;; `reach-exporter` (interop-driver.prologos) checks the connection
        ;; registry first and emits the withdraw directly when there is one.
        ;; So by the time a dial reaches here, no give is waiting on it.
        (void)]
       [(in-flight)
        (printf "ocapn-test-server: dial to ~a:~a skipped — one is already in flight~n"
                (sturdyref-host sr) (sturdyref-port sr))]
       [(full)
        (printf "ocapn-test-server: dial to ~a:~a refused — ~a dials already outstanding~n"
                (sturdyref-host sr) (sturdyref-port sr) max-outstanding-dials)]
       [else (thread (lambda () (run-dial sr)))])]))

(define (run-dial sr)
  (define key (sturdyref-loc-key sr))
  (define din #f)
  (define dout #f)
  (define hello #f)
  (define cid #f)
  (dynamic-wind
    void
    (lambda ()
      (with-handlers ([exn:fail?
                       (lambda (e)
                         (printf "ocapn-test-server: dial exn: ~a~n" (exn-message e)))])
        (printf "ocapn-test-server: dialling ~a:~a~n" (sturdyref-host sr) (sturdyref-port sr))
        (let-values ([(i o) (tcp-connect (sturdyref-host sr)
                                         (string->number (sturdyref-port sr)))])
          (set! din i)
          (set! dout o))
        ;; The peer may dial us back before answering. Keep this
        ;; connection addressable by the location we dialled, so the
        ;; crossed-hellos rule can abort it from the accepting thread.
        ;; Registered BEFORE our start-session goes out: the peer can
        ;; already be dialling while we write.
        (note-half-open-dial! key din dout)
        (send-frame dout start-session-bytes)
        (define frame (read-frame din))
        (cond
          [(or (eof-object? frame) (not frame))
           (printf "ocapn-test-server: outbound closed before the peer's start-session~n")]
          [else
           ;; Every peer we ACCEPT is validated; a peer we DIAL was
           ;; validated by nothing at all, and we were about to hand it a
           ;; signed withdraw-gift.
           (define abort-reply (validate-incoming frame))
           (cond
             [(not (zero? (bytes-length abort-reply)))
              (printf "ocapn-test-server: dialled peer's start-session REJECTED (~a bytes); sending op:abort~n"
                      (bytes-length abort-reply))
              (send-frame dout abort-reply)]
             [else
              (set! hello (read-start-session frame))
              (cond
                [(not hello)
                 ;; Prologos accepted the frame and this reader did not:
                 ;; the two Syrup implementations disagree. The session is
                 ;; still usable, but nothing keyed on the peer's identity
                 ;; (handoff routing, crossed hellos) can work for it, so
                 ;; run degraded and say exactly that.
                 (printf "ocapn-test-server: DEGRADED — dialled peer's start-session validated but did not parse here (~a bytes): ~a~n"
                         (bytes-length frame) (bytes->hex-string frame))
                 (drop-half-open-dial! key)
                 (set! cid (next-conn-id!))
                 (drive-init! cid frame dout)
                 (run-frame-loop din dout cid)]
                [else
                 ;; The handshake completed, so this is no longer a
                 ;; candidate for the crossed-hellos tie-break.
                 (drop-half-open-dial! key)
                 (set! cid (next-conn-id!))
                 (drive-init! cid frame dout)
                 (record-open-conn! hello dout cid)
                 (run-frame-loop din dout cid)])])])))
    (lambda ()
      ;; Ports are closed and the tables cleaned up on EVERY exit path.
      ;; These used to sit inside the handler's body, so any raise from a
      ;; write, a step or the withdraw leaked both ports.
      (drop-half-open-dial! key)
      (release-dial! key)
      (when hello (forget-open-conn! hello dout))
      (when cid (ocapn-conn-reset cid))
      (when din (with-handlers ([exn:fail? void]) (close-input-port din)))
      (when dout (with-handlers ([exn:fail? void]) (close-output-port dout))))))

(define (drain-dials!)
  (for ([sr (in-list (ocapn-dial-drain '()))])
    (dial-sturdyref! sr)))

;; ========================================
;; The frame loop
;; ========================================
;;
;; ONE loop, for connections we accepted and connections we dialled
;; alike. There were two, with different hook sets, so a give arriving on
;; a dialled connection queued a dial nothing drained, a gifter enliven on
;; a dialled connection was ignored, and OCAPN_FRAME_HEX was blind on
;; outbound connections.
;;
;; Each hook is guarded on its own. A write to another connection's port
;; from a step or from a queued send must not unwind into the
;; connection handler and tear down the healthy connection that merely
;; carried the enliven.

(define (guarded what thunk)
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (printf "ocapn-test-server: ~a failed: ~a~n" what (exn-message e)))])
    (thunk)))

(define (run-frame-loop cin cout cid)
  (let loop ([n 1])
    (define frame (with-handlers ([exn:fail?
                                   (lambda (e)
                                     (printf "ocapn-test-server: read-frame exn after ~a frames (conn ~a): ~a~n"
                                             n cid (exn-message e))
                                     #f)])
                    (read-frame cin)))
    (cond
      [(or (eof-object? frame) (not frame))
       (printf "ocapn-test-server: peer closed after ~a frames (conn ~a)~n" n cid)]
      [else
       (when (getenv "OCAPN_FRAME_HEX")
         (printf "ocapn-test-server: FRAME-HEX conn ~a n ~a: ~a~n"
                 cid (+ n 1) (bytes->hex-string frame)))
       (define v (syrup-parse frame))
       (cond
         [(not v)
          ;; read-frame accepted these bytes and the reader here did not.
          ;; That is a disagreement between two Syrup implementations, not
          ;; a peer error, and it must be loud.
          (printf "ocapn-test-server: FRAME DID NOT PARSE (conn ~a, ~a bytes): ~a~n"
                  cid (bytes-length frame) (bytes->hex-string frame))]
         [else
          (void)])
       (define out (drive-step cid frame))
       (printf "ocapn-test-server: conn ~a frame ~a (~a in / ~a out bytes)~n"
               cid (+ n 1) (bytes-length frame) (bytes-length out))
       (when (and (getenv "OCAPN_FRAME_HEX") (> (bytes-length out) 0))
         (printf "ocapn-test-server: OUT-HEX conn ~a n ~a: ~a~n"
                 cid (+ n 1) (bytes->hex-string out)))
       (when (> (bytes-length out) 0)
         (guarded "reply write" (lambda () (send-frame cout out))))
       ;; A step may have queued an outbound connection, or bytes for a
       ;; connection other than this one -- the third-party handoff roles do
       ;; both.
       (guarded "dial drain" drain-dials!)
       (guarded "send drain" drain-sends!)
       (loop (+ n 1))])))

;; ========================================
;; Connection handler
;; ========================================

(define (handle-connection cin cout)
  (define hello #f)
  (define cid #f)
  (dynamic-wind
    void
    (lambda ()
      (with-handlers ([exn:fail? (lambda (e)
                                   (printf "ocapn-test-server: handler exn: ~a~n"
                                           (exn-message e)))])
        (printf "ocapn-test-server: connection accepted, sending start-session (framing=~v)~n"
                (current-framing-strategy))
        (send-frame cout start-session-bytes)
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
           (cond
             [(not (zero? (bytes-length abort-reply)))
              (printf "ocapn-test-server: inbound start-session REJECTED (~a bytes); sending op:abort~n"
                      (bytes-length abort-reply))
              (send-frame cout abort-reply)]
             [else
              (set! hello (read-start-session first-frame))
              (cond
                [(not hello)
                 ;; Prologos accepted it and this reader did not: the two
                 ;; Syrup implementations disagree. The session still
                 ;; works, but nothing keyed on the peer's identity
                 ;; (handoff routing, crossed hellos) can work for it, so
                 ;; run degraded and say exactly that rather than either
                 ;; killing the connection or staying quiet.
                 (printf "ocapn-test-server: DEGRADED — start-session validated but did not parse here (~a bytes): ~a~n"
                         (bytes-length first-frame) (bytes->hex-string first-frame))
                 (set! cid (next-conn-id!))
                 (drive-init! cid first-frame cout)
                 (run-frame-loop cin cout cid)]
                [else
                 (define crossed (half-open-dial-for (peer-hello-location-key hello)))
                 (cond
                   ;; Crossed hellos: we already dialled this peer and it
                   ;; has dialled us back. Exactly one of the two
                   ;; connections dies, and which one is decided by the
                   ;; side-ids alone -- so the peer reaches the same
                   ;; verdict without another round trip.
                   [crossed
                    (define theirs (peer-hello-side-id hello))
                    (define ours-first? (bytes<? our-side-id theirs))
                    (printf "ocapn-test-server: crossed hellos; aborting the ~a connection~n"
                            (if ours-first? "OUTGOING" "incoming"))
                    (define abort-bytes (build-abort-bytes "crossed hellos"))
                    (cond
                      [ours-first?
                       ;; Our dial loses: abort the socket WE opened, and
                       ;; let this one live.
                       (drop-half-open-dial! (peer-hello-location-key hello))
                       (guarded "crossed-hellos abort write"
                                (lambda () (send-frame (vector-ref crossed 1) abort-bytes)))
                       ;; Then close the dial's sockets. Its own thread is
                       ;; parked in `read-frame`; closing the input port
                       ;; makes that read raise, which unwinds it through
                       ;; `run-dial`'s cleanup. Leaving it parked leaks the
                       ;; thread AND keeps the peer's key in
                       ;; `dials-in-flight`, blocking every later dial to
                       ;; it.
                       (guarded "crossed-hellos dial teardown"
                                (lambda ()
                                  (close-input-port (vector-ref crossed 0))
                                  (close-output-port (vector-ref crossed 1))))
                       (set! cid (next-conn-id!))
                       (drive-init! cid first-frame cout)
                       ;; The survivor must be registered too, or a later
                       ;; enliven for this peer finds nothing in
                       ;; `open-conns` and the gifter path silently
                       ;; no-ops.
                       (record-open-conn! hello cout cid)
                       (run-frame-loop cin cout cid)]
                      [else
                       ;; Their dial loses: abort the socket THEY opened.
                       (send-frame cout abort-bytes)])]
                   [else
                    (set! cid (next-conn-id!))
                    (drive-init! cid first-frame cout)
                    (printf "ocapn-test-server: inbound start-session accepted (conn ~a); driving captp-core~n"
                            cid)
                    (record-open-conn! hello cout cid)
                    (run-frame-loop cin cout cid)])])])])))
    (lambda ()
      (when hello (forget-open-conn! hello cout))
      ;; Without this the connection's whole vat -- actors, promises, both
      ;; tables -- is retained for the life of the process.
      (when cid (ocapn-conn-reset cid))
      (with-handlers ([exn:fail? void]) (close-input-port cin))
      (with-handlers ([exn:fail? void]) (close-output-port cout)))))

;; ========================================
;; Main loop
;; ========================================

(define listener (tcp-listen (port-arg) 4 #t advertised-host))
(printf "ocapn-test-server: listening on ~a:~a~n" advertised-host (port-arg))
(flush-output)

(let accept-loop ()
  (define-values (cin cout) (tcp-accept listener))
  (thread (lambda () (handle-connection cin cout)))
  (accept-loop))
