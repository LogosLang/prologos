#lang racket/base

;;; test-ocapn-crossed-hellos.rkt — the crossed-hellos tie-break.
;;;
;;; Two peers can dial each other at the same moment. CapTP breaks the tie
;;; with a rule both sides evaluate independently and must agree on WITHOUT
;;; another round trip: sort the two side-ids as octet strings and abort the
;;; connection dialled by whichever sorts first.
;;;
;;; Until this file existed the rule was an inlined `(bytes<? our-side-id
;;; theirs)` on the interop server's accept thread — a decision two
;;; independent implementations have to reach identically, written in a
;;; language neither peer's implementation is written in, with no test. It is
;;; now `crossed-hellos-abort-ours?` in `prologos::ocapn::handshake` (gaps
;;; document §0.2).
;;;
;;; What is actually worth asserting is ANTISYMMETRY, not any single verdict.
;;; A rule that returned the same answer to both peers would abort both
;;; connections or neither, and both outcomes look like a network flake rather
;;; than a logic error — which is exactly the kind of bug that survives a
;;; conformance suite. So the battery below checks the pair of calls the two
;;; peers actually make, not one call in isolation.

(require rackunit
         racket/list
         racket/string
         (only-in file/sha1 bytes->hex-string)
         "test-support.rkt"
         "../macros.rkt"
         "../prelude.rkt"
         "../syntax.rkt"
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../errors.rkt"
         "../metavar-store.rkt"
         "../parser.rkt"
         "../elaborator.rkt"
         "../pretty-print.rkt"
         "../global-env.rkt"
         "../driver.rkt"
         "../namespace.rkt"
         "../multi-dispatch.rkt")

(define shared-preamble
  "(ns test-ocapn-crossed-hellos)
(imports (prologos::ocapn::handshake :refer-all))
")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-ctor-reg
                shared-type-meta)
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
    (process-string shared-preamble)
    (values (global-env-snapshot)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

(define (run-last s)
  (last
   (parameterize ([current-file-module-network-ref
                   (module-network-add-import (make-module-network)
                                              (module-network-from-snapshot shared-global-env))]
                  [current-ns-context shared-ns-context]
                  [current-module-registry shared-module-reg]
                  [current-lib-paths (list prelude-lib-dir)]
                  [current-preparse-registry (current-preparse-registry)]
                  [current-trait-registry shared-trait-reg]
                  [current-impl-registry shared-impl-reg]
                  [current-param-impl-registry shared-param-impl-reg]
                  [current-ctor-registry shared-ctor-reg]
                  [current-type-meta shared-type-meta])
     (process-string s))))

(define (bool-result out who)
  (define t (string-trim out))
  (cond
    [(string=? t "true : Bool") #t]
    [(string=? t "false : Bool") #f]
    [else (error who "not a Bool: ~s" out)]))

;; The verdict over hex-encoded side-ids — the entry point the interop server
;; calls (`crossed-hellos-verdict`, run-ocapn-test-server.rkt).
(define (abort-ours-hex? ours-hex theirs-hex)
  (bool-result
   (run-last (format "(eval (crossed-hellos-abort-ours-hex? ~s ~s))" ours-hex theirs-hex))
   'abort-ours-hex?))

;; The verdict over raw side-ids.
(define (abort-ours? ours theirs)
  (abort-ours-hex? (bytes->hex-string ours) (bytes->hex-string theirs)))

;; A side-id is SHA-256 doubled, so 32 bytes. The battery uses real-width ids
;; with the difference at varying offsets, because an implementation that
;; compared only a prefix would pass a battery whose ids differ in byte 0.
(define (id-with-byte-at i v)
  (define b (make-bytes 32 7))
  (bytes-set! b i v)
  b)

(define battery
  (append
   (list (cons (make-bytes 32 0) (make-bytes 32 255))
         (cons (id-with-byte-at 0 1) (id-with-byte-at 0 2))
         (cons (id-with-byte-at 31 1) (id-with-byte-at 31 2))
         (cons (id-with-byte-at 16 200) (id-with-byte-at 16 201))
         ;; High-bit bytes: an implementation comparing SIGNED bytes gets
         ;; these backwards, and every all-ASCII battery misses it.
         (cons (id-with-byte-at 3 127) (id-with-byte-at 3 128))
         (cons (id-with-byte-at 3 128) (id-with-byte-at 3 255)))
   ;; A few pseudo-random pairs, fixed rather than seeded so a failure is
   ;; reproducible.
   (list (cons (make-bytes 32 42) (make-bytes 32 43))
         (cons (id-with-byte-at 9 0) (id-with-byte-at 9 255)))))

(test-case "antisymmetry: the two peers reach opposite verdicts"
  ;; This is the property the protocol rests on. Peer A asks "abort the
  ;; connection I dialled?" with its own id first; peer B asks the same
  ;; question with ITS id first. Exactly one connection must die.
  (for ([p (in-list battery)])
    (define a (car p))
    (define b (cdr p))
    (check-not-equal? (abort-ours? a b) (abort-ours? b a)
                      (format "both peers reached the same verdict for ~a / ~a"
                              (bytes->hex-string a) (bytes->hex-string b)))))

(test-case "the rule is octet ordering"
  ;; The verdict must agree with a plain octet comparison. `bytes<?` here is a
  ;; TEST oracle, not a production fallback — the server has no local copy of
  ;; the rule any more, which is the point of the migration.
  (for ([p (in-list battery)])
    (define a (car p))
    (define b (cdr p))
    (check-equal? (abort-ours? a b) (bytes<? a b)
                  (format "verdict disagrees with octet order for ~a / ~a"
                          (bytes->hex-string a) (bytes->hex-string b)))
    (check-equal? (abort-ours? b a) (bytes<? b a))))

(test-case "equal side-ids reach one verdict, not two"
  ;; Same key on both ends — a peer that dialled itself. Degenerate, but it
  ;; must not be a coin flip: both ends compute the same answer.
  (define id (make-bytes 32 99))
  (check-equal? (abort-ours? id id) #f)
  (check-equal? (abort-ours? id id) (abort-ours? id id)))

(test-case "hex is decoded, not compared"
  ;; Fixed-width LOWERCASE hex is order-preserving, so comparing the hex
  ;; directly would pass every test above. Mixed case is where the two part
  ;; company: 'a' (0x61) > 'B' (0x42), while the bytes they encode run the
  ;; other way. `bytes->hex-string` emits lowercase so production never gets
  ;; here — this pins the claim the wrapper's comment makes.
  (define a (id-with-byte-at 31 10))   ; …0a
  (define b (id-with-byte-at 31 11))   ; …0b
  (check-true (bytes<? a b))
  ;; Lowercase: verdict and hex-order agree.
  (check-true (abort-ours-hex? (bytes->hex-string a) (bytes->hex-string b)))
  ;; Uppercase the SECOND id only. Hex-order now says "0B" < "0a", i.e. the
  ;; opposite; the verdict must be unmoved because it decodes first.
  (define b-upper (string-upcase (bytes->hex-string b)))
  (check-true (string<? b-upper (bytes->hex-string a))
              "the test's own premise: mixed-case hex inverts the order")
  (check-true (abort-ours-hex? (bytes->hex-string a) b-upper)
              "verdict followed hex order instead of octet order"))

;; --- The op:abort the teardown sends ---
;;
;; Losing a crossed hello means sending `<op:abort "crossed hellos">`. Those
;; bytes were assembled by a second encoder in the interop server; it is gone,
;; and `abort-bytes` in `prologos::ocapn::handshake` is the only one left.
;;
;; The retired builder is transcribed below as a TEST ORACLE. That is the
;; difference between retiring a duplicate and keeping one: as an oracle it
;; can only report a divergence, where as a production fallback it would
;; supply an answer that hides one.

(define (retired-server-abort-bytes reason)
  (define r (string->bytes/latin-1 reason))
  (bytes-append #"<8'op:abort"
                (string->bytes/latin-1 (number->string (bytes-length r)))
                #"\"" r #">"))

(define (prologos-abort-bytes reason)
  (define out (run-last (format "(eval (abort-bytes ~s))" reason)))
  (define m (regexp-match #px"^(\".*\") : String$" (string-trim out)))
  (unless m (error 'prologos-abort-bytes "unreadable: ~s" out))
  (string->bytes/latin-1 (read (open-input-string (cadr m)))))

(test-case "op:abort bytes match the retired server encoder"
  (for ([reason (in-list (list "crossed hellos"
                               "start-session validation failed"
                               ""
                               "a"))])
    (check-equal? (prologos-abort-bytes reason)
                  (retired-server-abort-bytes reason)
                  (format "op:abort encoding diverged for ~s" reason))))

(test-case "op:abort is the literal wire shape, not merely self-consistent"
  ;; Both implementations agreeing proves nothing if both are wrong, so pin
  ;; one case against the bytes written out by hand.
  (check-equal? (prologos-abort-bytes "crossed hellos")
                #"<8'op:abort14\"crossed hellos>"))

(test-case "the difference is found wherever it sits"
  ;; A prefix-only comparison passes when ids differ early and fails here.
  (define a (id-with-byte-at 31 1))
  (define b (id-with-byte-at 31 2))
  (check-true (abort-ours? a b))
  (check-false (abort-ours? b a)))
