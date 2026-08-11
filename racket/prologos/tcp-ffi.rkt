#lang racket/base

;;;
;;; tcp-ffi.rkt — minimal TCP primitives bridge for the OCapN
;;; tcp-testing-only netlayer.
;;;
;;; Mirrors `io-ffi.rkt`'s handle-table approach: Prologos sees only
;;; integer handles; Racket maintains a port-id → port table.
;;;
;;; This is the testing-only netlayer. There is NO crypto and NO
;;; auth here — anyone who can connect to the listen socket is
;;; granted a session. NEVER use over public networks. The transport
;;; name in OCapN locators is "tcp-testing-only" by convention.
;;;
;;; Primitives (handle ID semantics):
;;;
;;;   tcp-listen          : (port -> Nat)
;;;     start a listener; returns a server-handle.
;;;
;;;   tcp-accept          : (Nat -> Nat)
;;;     accept ONE incoming connection on a server-handle; returns
;;;     a connection-handle. Blocks. Use only inside tests.
;;;
;;;   tcp-accept-ready?   : (Nat -> Bool)
;;;     true iff an accept would not block.
;;;
;;;   tcp-connect         : (String -> Nat -> Nat)
;;;     dial host:port; returns a connection-handle.
;;;
;;;   tcp-send-line       : (Nat -> String -> Nat)
;;;     write a string + newline to the connection; returns the
;;;     same handle (for data-flow forcing in lazy reduction).
;;;
;;;   tcp-recv-line-ret   : (Nat -> Nat)
;;;     read one line; cache it under the handle; return the handle.
;;;     (Mirrors io-ffi.rkt's read-then-cache trick.)
;;;
;;;   tcp-recv-cached     : (Nat -> String)
;;;     return the previously-cached line for this handle.
;;;
;;;   tcp-close           : (Nat -> Unit)
;;;     close a connection or server handle and remove it from the
;;;     table.
;;;
;;; Wire format: ONE message = ONE line. Each line is a Syrup-encoded
;;; SyrupValue (we use a textual subset; Endo uses byte-level Syrup
;;; but we approximate by serialising via the pretty-printer's repr
;;; in the netlayer Prologos layer). Lines are terminated by `\n`.
;;; Length-prefix framing is intentionally NOT used — keeping testing-
;;; only simple. See goblin-pitfalls #19.

(require racket/tcp
         racket/string
         "../../tools/interop/ocapn-framing.rkt")

(provide
 tcp-listen
 tcp-accept
 tcp-accept-ready?
 tcp-connect
 tcp-send-line
 tcp-recv-line-ret
 tcp-recv-cached
 tcp-send-frame
 tcp-recv-frame-ret
 tcp-recv-frame-cached
 tcp-recv-frame-eof?
 tcp-frame-send
 tcp-frame-recv
 tcp-frame-payload-at
 tcp-frame-eof-at
 tcp-frame-accept
 tcp-tick-after
 tcp-frame-listen
 tcp-frame-close
 current-framing-strategy
 tcp-close
 tcp-ffi-registry
 ;; Test-only helpers
 tcp-table-size
 tcp-table-clear!)

;; ========================================
;; Handle table
;; ========================================

(define tcp-table       (make-hasheq))   ;; id -> (cons port-or-listener kind)
(define tcp-recv-cache  (make-hasheq))   ;; id -> last-recv'd string
(define tcp-next-id     0)

(define (tcp-fresh-id!)
  (define id tcp-next-id)
  (set! tcp-next-id (add1 id))
  id)

(define (tcp-store! kind v)
  (define id (tcp-fresh-id!))
  (hash-set! tcp-table id (cons v kind))
  id)

(define (tcp-lookup id)
  (define entry (hash-ref tcp-table id
    (lambda () (error 'tcp-ffi "invalid handle: ~a" id))))
  (car entry))

(define (tcp-kind id)
  (define entry (hash-ref tcp-table id
    (lambda () (error 'tcp-ffi "invalid handle: ~a" id))))
  (cdr entry))

;; ========================================
;; Primitives
;; ========================================

(define (tcp-listen port)
  ;; Bind to localhost-only — testing only.
  (define ll (tcp-listen-impl port))
  (tcp-store! 'listener ll))

(define (tcp-listen-impl port)
  (tcp-listen-port port 4 #t "127.0.0.1"))

;; tcp-listen-port: Racket's `tcp-listen` (qualified name to avoid clash
;; with our exported `tcp-listen`).
(define tcp-listen-port
  (dynamic-require 'racket/tcp 'tcp-listen))

(define (tcp-accept server-id)
  (define listener (tcp-lookup server-id))
  (define-values (in out) (tcp-accept-impl listener))
  (tcp-store! 'connection (cons in out)))

(define tcp-accept-impl
  (dynamic-require 'racket/tcp 'tcp-accept))

(define (tcp-accept-ready? server-id)
  (define listener (tcp-lookup server-id))
  ((dynamic-require 'racket/tcp 'tcp-accept-ready?) listener))

(define (tcp-connect host port)
  (define-values (in out) (tcp-connect-impl host port))
  (tcp-store! 'connection (cons in out)))

(define tcp-connect-impl
  (dynamic-require 'racket/tcp 'tcp-connect))

(define (tcp-send-line conn-id line)
  (define entry (tcp-lookup conn-id))
  (define out (cdr entry))   ;; (cons in out)
  ;; If line already ends with \n, don't double-append.
  (define payload
    (if (regexp-match? #rx"\n$" line) line (string-append line "\n")))
  (write-string payload out)
  (flush-output out)
  conn-id)

;; Read ONE line from the connection's input port. Cache it under
;; conn-id and return conn-id (data-flow trick — see io-ffi.rkt).
(define (tcp-recv-line-ret conn-id)
  (define entry (tcp-lookup conn-id))
  (define in (car entry))    ;; (cons in out)
  (define line (read-line in 'linefeed))
  (hash-set! tcp-recv-cache conn-id (if (eof-object? line) "" line))
  conn-id)

(define (tcp-recv-cached conn-id)
  (hash-ref tcp-recv-cache conn-id ""))

;; ========================================
;; Frame IO (SH-1)
;; ========================================
;;
;; The line ops above are LF-delimited, which is fine for the
;; tcp-testing-only netlayer and useless for OCapN: a Syrup frame is
;; arbitrary bytes and 0x0a occurs inside them constantly. These read and
;; write ONE FRAME under `current-framing-strategy` — netstring by default
;; on the OCapN wire.
;;
;; The framing itself is DELIBERATELY not reimplemented here. It is
;; `ocapn-framing.rkt`, the same module the interop server uses, so there is
;; one framing implementation rather than two that agree until they do not.
;; The require reaches into `tools/` from the library, which is backwards;
;; `tests/test-ocapn-syrup-wire.rkt` already does the same. Moving the module
;; into the library proper belongs with the driver migration (step 5), not
;; here — noted rather than silently tolerated.
;;
;; Payloads cross as LATIN-1 STRINGS, 1 char == 1 byte, which is how every
;; other Prologos/Racket wire-byte boundary in this codebase carries frames.

(define tcp-frame-cache (make-hasheq))
(define tcp-frame-eof   (make-hasheq))

;; Write one frame. Returns the handle, so a caller in a lazy reducer can
;; force the effect by depending on the result.
(define (tcp-send-frame conn-id payload)
  (define entry (tcp-lookup conn-id))
  (define out (cdr entry))
  (write-frame out (string->bytes/latin-1 payload))
  (flush-output out)
  conn-id)

;; Read one frame; cache it under the handle; return the handle.
;;
;; EOF is recorded SEPARATELY rather than as an empty payload. An empty
;; frame and a closed socket are different events, and collapsing them is
;; precisely the mistake the gaps document keeps re-learning — "a malformed
;; frame and an absent frame are indistinguishable to everything except the
;; bytes". A loop that cannot tell them apart either spins forever on a dead
;; socket or drops a legitimate zero-length frame.
(define (tcp-recv-frame-ret conn-id)
  (define entry (tcp-lookup conn-id))
  (define in (car entry))
  (define fr (read-frame in))
  (define eof? (or (eof-object? fr) (not fr)))
  (hash-set! tcp-frame-eof conn-id eof?)
  (hash-set! tcp-frame-cache conn-id (if eof? "" (bytes->string/latin-1 fr)))
  conn-id)

(define (tcp-recv-frame-cached conn-id)
  (hash-ref tcp-frame-cache conn-id ""))

;; True iff the last `tcp-recv-frame-ret` on this handle hit EOF. Defaults to
;; #t for a handle never read: "no frame available" is the safe answer, since
;; the unsafe one keeps a loop running on a socket that has nothing to say.
(define (tcp-recv-frame-eof? conn-id)
  (hash-ref tcp-frame-eof conn-id #t))

;; ========================================
;; World-threaded frame IO (SH-2)
;; ========================================
;;
;; The same operations, but each takes a TICK and returns the next one. The
;; tick is the runtime half of `prologos::core::world`; see that module for
;; why a World token exists at all.
;;
;; Why the tick is a real value and not a token the compiler could invent:
;; reduction is lazy in argument position, so an expression with no data
;; dependency on an effect may be evaluated BEFORE it — or, if its result is
;; structurally predictable, not at all. `tcp-frame-payload-at` therefore takes
;; the tick that `tcp-frame-recv` produced. It ignores the value; what it needs
;; is that its argument cannot be computed without the read having happened.
;; The tick is EVIDENCE, and threading it is what puts the ordering in the
;; dataflow rather than in a convention.
;;
;; This is the same reasoning `emit-after-stash` (interop-driver.prologos)
;; spells out for its deliberately-different match arms, made structural
;; instead of idiomatic.

;; ONE global tick. Every effectful op below bumps it; `tcp-tick-after` reads
;; it back. The VALUE is a real monotone clock (useful when reading a trace);
;; its job in the type system is only to be a value that cannot exist before
;; the effect that produced it.
(define tcp-world-tick 0)
(define (tcp-bump!)
  (set! tcp-world-tick (add1 tcp-world-tick))
  tcp-world-tick)

;; Read the current tick. `dep` is deliberately unused — it exists so the
;; caller must already hold something the effect produced. Ops that must
;; return a HANDLE use this to get their new tick, since a foreign call
;; returns one value and the handle is that value.
(define (tcp-tick-after dep)
  (void dep)
  tcp-world-tick)

(define (tcp-frame-send tick conn-id payload)
  (void tick)
  (tcp-send-frame conn-id payload)
  (tcp-bump!))

(define (tcp-frame-recv tick conn-id)
  (void tick)
  (tcp-recv-frame-ret conn-id)
  (tcp-bump!))

;; `tick` is deliberately unused: it exists to be a dependency.
(define (tcp-frame-payload-at tick conn-id)
  (void tick)
  (tcp-recv-frame-cached conn-id))

(define (tcp-frame-eof-at tick conn-id)
  (void tick)
  (tcp-recv-frame-eof? conn-id))

;; Accept and listen return a HANDLE, so their new tick comes from
;; `tcp-tick-after` applied to that handle. Both block.
(define (tcp-frame-accept tick server-id)
  (void tick)
  (begin0 (tcp-accept server-id) (tcp-bump!)))

(define (tcp-frame-listen tick port)
  (void tick)
  (begin0 (tcp-listen port) (tcp-bump!)))

(define (tcp-frame-close tick handle-id)
  (void tick)
  (tcp-close handle-id)
  (tcp-bump!))

(define (tcp-close handle-id)
  (define kind (tcp-kind handle-id))
  (case kind
    [(listener)
     (define ll (tcp-lookup handle-id))
     (tcp-close-listener ll)]
    [(connection)
     (define entry (tcp-lookup handle-id))
     (define in  (car entry))
     (define out (cdr entry))
     (close-input-port in)
     (close-output-port out)])
  (hash-remove! tcp-table handle-id)
  (hash-remove! tcp-recv-cache handle-id)
  (hash-remove! tcp-frame-cache handle-id)
  (hash-remove! tcp-frame-eof handle-id)
  (void))

(define tcp-close-listener
  (dynamic-require 'racket/tcp 'tcp-close))

;; ========================================
;; Test-only helpers
;; ========================================

(define (tcp-table-size) (hash-count tcp-table))

(define (tcp-table-clear!)
  ;; Best-effort cleanup for tests.
  ;;
  ;; Snapshot the keys BEFORE iterating, because tcp-close mutates
  ;; tcp-table via hash-remove!. Iterating in-hash while removing
  ;; entries can raise an iteration/contract error (see Copilot
  ;; review #28#discussion_r3150426813).
  (define ids (hash-keys tcp-table))
  (for ([id (in-list ids)])
    (with-handlers ([exn:fail? (lambda _ (void))])
      (tcp-close id)))
  (hash-clear! tcp-table)
  (hash-clear! tcp-recv-cache)
  (set! tcp-next-id 0))

;; ========================================
;; FFI registry (mirrors io-ffi-registry)
;; ========================================

(define tcp-ffi-registry
  (hasheq
   'tcp-listen         (cons tcp-listen         '(Nat -> Nat))
   'tcp-accept         (cons tcp-accept         '(Nat -> Nat))
   'tcp-accept-ready?  (cons tcp-accept-ready?  '(Nat -> Bool))
   'tcp-connect        (cons tcp-connect        '(String -> Nat -> Nat))
   'tcp-send-line      (cons tcp-send-line      '(Nat -> String -> Nat))
   'tcp-recv-line-ret  (cons tcp-recv-line-ret  '(Nat -> Nat))
   'tcp-recv-cached    (cons tcp-recv-cached    '(Nat -> String))
   'tcp-close          (cons tcp-close          '(Nat -> Unit))))
