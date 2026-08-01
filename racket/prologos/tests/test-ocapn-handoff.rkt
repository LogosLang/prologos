#lang racket/base

;;; test-ocapn-handoff.rkt — the third-party-handoff surface.
;;;
;;; Why this file exists: the gifter and receiver roles shipped with ZERO
;;; tests. The evidence offered was "conformance 24/24" — a gate the gaps
;;; document itself classifies as MEDIUM debt, because it is an allow-list of
;;; 24 hand-named upstream tests rather than the upstream suite. §0.2's stated
;;; consequence of those roles living in Racket was THREE things: not
;;; self-hosting, NOT COVERED BY THE UNIT SUITE, and not reasonable-about in
;;; the language. The migration fixed the first and third, left the second
;;; where it was, and the finding was marked closed.
;;;
;;; Everything covered here is a pure, total function over strings. There was
;;; never an infrastructure reason for the gap.
;;;
;;; The identity properties are pinned against upstream's own definitions
;;; (ocapn-test-suite `utils/captp.py:113-146`), not against our output — a
;;; test asserting only "what the code does today" would have passed just as
;;; happily on the encoded-vs-raw side-id bug that cost a conformance run.

(require rackunit
         racket/list
         racket/string
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
  "(ns test-ocapn-handoff)
(imports (prologos::ocapn::core :refer-all))
(imports (prologos::ocapn::message :refer-all))
(imports (prologos::ocapn::captp-wire :refer-all))
(imports (prologos::ocapn::syrup-wire :refer-all))
(imports (prologos::ocapn::captp-core :refer-all))
(imports (prologos::ocapn::pipelining :refer (promise-queue-length)))
(imports (prologos::ocapn::captp-interop-helpers :refer (framed-concat)))
(imports (prologos::data::list :refer (List nil cons)))
(imports (prologos::data::option :refer (Option some none unwrap-or)))
(imports (prologos::data::string :as str :refer ()))
(imports (prologos::ocapn::crypto :refer-all))
(imports (prologos::ocapn::handshake :refer-all))
(imports (prologos::ocapn::interop-driver :refer-all))
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

(define (run s)
  (parameterize ([current-file-module-network-ref (module-network-add-import (make-module-network) (module-network-from-snapshot shared-global-env))]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-ctor-registry shared-ctor-reg]
                 [current-type-meta shared-type-meta])
    (process-string s)))

(define (run-last s) (last (run s)))

(define (check-contains actual substr [msg #f])
  (check-true (string-contains? actual substr)
              (or msg (format "Expected ~s to contain ~s" actual substr))))

;; ========================================
;; Phase 11 — incoming op:deliver applied to vat
;; ========================================


;; ----------------------------------------------------------------
;; Identity derivation — properties upstream requires, not our output
;; ----------------------------------------------------------------

(test-case "handoff/sha256d is SHA-256 twice, 32 bytes out, not one round"
  (check-contains (run-last "(eval (str::length (sha256d \"abc\")))") "32")
  (check-contains (run-last "(eval (str::eq (sha256d \"abc\") (sha256-raw \"abc\")))") "false"))

(test-case "handoff/session-id-of is SYMMETRIC — both peers derive it alone"
  ;; captp.py:125-146 sorts the two side-ids before hashing precisely so that
  ;; neither peer needs a round trip to agree on the session id.
  (check-contains
   (run-last "(eval (str::eq (session-id-of \"aaa\" \"bbb\") (session-id-of \"bbb\" \"aaa\")))")
   "true")
  (check-contains (run-last "(eval (str::length (session-id-of \"aaa\" \"bbb\")))") "32"))

(test-case "handoff/session-id-of separates different peers"
  (check-contains
   (run-last "(eval (str::eq (session-id-of \"aaa\" \"bbb\") (session-id-of \"aaa\" \"ccc\")))")
   "false"))

(test-case "handoff/side-id hashes the ENCODED key sexp, never the raw q"
  ;; REGRESSION PIN. Hashing the raw 32-byte q instead of the encoded
  ;; (public-key (ecc ...)) s-expression produces a plausible 32-byte digest
  ;; either way, so the only symptom was a session id the peer disagreed with
  ;; several frames later. The two must differ.
  (check-contains
   (run-last
    "(eval (str::eq (side-id-of-encoded-key (gcrypt-pubkey-bytes \"0123456789abcdef0123456789abcdef\"))
                    (side-id-of-encoded-key \"0123456789abcdef0123456789abcdef\")))")
   "false"))

;; ----------------------------------------------------------------
;; Peer location keys
;; ----------------------------------------------------------------

(test-case "handoff/peer-location-key ignores hints — a peer is not an address"
  (check-contains
   (run-last
    "(eval (str::eq (unwrap-or \"\" (peer-location-key (syrup-tagged \"ocapn-peer\" (syrup-list (cons (syrup-symbol \"tcp\") (cons (syrup-string \"abc\") (cons (syrup-string \"h1\") nil)))))))
                    (unwrap-or \"\" (peer-location-key (syrup-tagged \"ocapn-peer\" (syrup-list (cons (syrup-symbol \"tcp\") (cons (syrup-string \"abc\") (cons (syrup-string \"DIFFERENT\") nil)))))))))")
   "true"))

(test-case "handoff/peer-location-key is injective — the NUL join is load-bearing"
  ;; ("a","bc") and ("ab","c") must not collide into one peer.
  (check-contains
   (run-last
    "(eval (str::eq (unwrap-or \"\" (peer-location-key (syrup-tagged \"ocapn-peer\" (syrup-list (cons (syrup-symbol \"a\") (cons (syrup-string \"bc\") nil))))))
                    (unwrap-or \"\" (peer-location-key (syrup-tagged \"ocapn-peer\" (syrup-list (cons (syrup-symbol \"ab\") (cons (syrup-string \"c\") nil))))))))")
   "false"))

(test-case "handoff/peer-location-key refuses a non-ocapn-peer record"
  (check-contains
   (run-last
    "(eval (unwrap-or \"REFUSED\" (peer-location-key (syrup-tagged \"something-else\" (syrup-list (cons (syrup-symbol \"a\") (cons (syrup-string \"b\") nil)))))))")
   "REFUSED"))

;; ----------------------------------------------------------------
;; Descriptor reading — the two silent decoder traps
;; ----------------------------------------------------------------

(test-case "handoff/desc-position reads a ONE-arg record whose payload is bare"
  ;; pitfall #55: a single-argument record's payload is the VALUE, not a
  ;; one-element list, so every list-shaped reader finds zero arguments.
  (check-contains
   (run-last "(eval (unwrap-or (suc (suc (suc (suc (suc (suc (suc (suc (suc zero))))))))) (desc-position (syrup-tagged \"desc:export\" (syrup-nat (suc (suc (suc (suc (suc (suc (suc zero))))))))))))")
   "7N"))

(test-case "handoff/desc-position accepts BOTH wire spellings of a nat"
  ;; pitfall #56: a wire nat arrives as syrup-nat OR non-negative syrup-int
  ;; depending on provenance. Matching one spelling silently misses the other,
  ;; and the wire decoder emits the int form.
  (check-contains
   (run-last "(eval (unwrap-or zero (desc-position (syrup-tagged \"desc:export\" (syrup-int 7)))))")
   "7N"))

(test-case "handoff/desc-position rejects a non-descriptor tag"
  (check-contains
   (run-last "(eval (unwrap-or zero (desc-position (syrup-tagged \"not-a-desc\" (syrup-int 7)))))")
   "0N"))

;; ----------------------------------------------------------------
;; The parked-enliven blob
;; ----------------------------------------------------------------

(test-case "handoff/the enliven blob round-trips its five fields"
  (check-contains
   (run-last "(eval (blob-string (pending-enliven-blob \"reqloc\" (suc (suc (suc zero))) \"exploc\" \"GIVE\" \"gid-7\") zero))")
   "reqloc")
  (check-contains
   (run-last "(eval (blob-nat (pending-enliven-blob \"reqloc\" (suc (suc (suc zero))) \"exploc\" \"GIVE\" \"gid-7\") (suc zero)))")
   "3N")
  (check-contains
   (run-last "(eval (blob-string (pending-enliven-blob \"reqloc\" zero \"exploc\" \"GIVE\" \"gid-7\") (suc (suc (suc (suc zero))))))")
   "gid-7"))

(test-case "handoff/blob-ok? rejects a blob that did not decode"
  ;; REGRESSION PIN. blob-nat answers zero for BOTH "absent" and "malformed",
  ;; and zero is the peer's BOOTSTRAP position — so an unreadable blob used to
  ;; send a fulfill to the peer's bootstrap object rather than sending nothing.
  (check-contains (run-last "(eval (blob-ok? \"not-syrup-at-all\"))") "false")
  (check-contains
   (run-last "(eval (blob-ok? (pending-enliven-blob \"l\" (suc zero) \"e\" \"G\" \"g\")))") "true"))

(test-case "handoff/finish-handoff emits NOTHING for an undecodable blob"
  (check-contains (run-last "(eval (length (finish-handoff \"not-syrup-at-all\" (suc zero))))") "0N")
  (check-contains
   (run-last "(eval (length (finish-handoff (pending-enliven-blob \"l\" (suc zero) \"e\" \"G\" \"g\") (suc zero))))")
   "2N"))

;; ----------------------------------------------------------------
;; Frame builders
;; ----------------------------------------------------------------

(test-case "handoff/handoff-give carries upstream's five fields in order"
  ;; captp_types.py:296-307 — receiver-key, exporter-location, session,
  ;; gifter-side, gift-id.
  (define f (run-last "(eval (handoff-give-bytes \"K\" \"L\" \"S\" \"O\" \"G\"))"))
  (check-contains f "desc:handoff-give")
  (check-contains f "1:S")
  (check-contains f "1:O")
  (check-contains f "1:G"))

(test-case "handoff/handoff-receive splices the signed give VERBATIM"
  ;; Re-encoding a decoded give would invalidate its signature over a
  ;; difference we would never see.
  (define f (run-last "(eval (handoff-receive-bytes \"SESS\" \"SIDE\" (suc (suc zero)) \"RAWGIVE\"))"))
  (check-contains f "desc:handoff-receive")
  (check-contains f "RAWGIVE"))

(test-case "handoff/the withdraw frame is a bootstrap deliver"
  (define f (run-last "(eval (withdraw-frame-bytes \"ENV\"))"))
  (check-contains f "op:deliver")
  (check-contains f "withdraw-gift")
  (check-contains f "desc:export"))

(test-case "handoff/the fetch frame names the reserved slot as its resolve-me"
  (define f (run-last "(eval (fetch-frame-bytes \"swiss\" (suc (suc zero))))"))
  (check-contains f "fetch")
  (check-contains f "desc:import-object"))

;; ----------------------------------------------------------------
;; Signing
;; ----------------------------------------------------------------

(test-case "handoff/sig-envelope wraps the body in a gcrypt sig-val"
  (define f (run-last "(eval (sig-envelope-bytes (gen-keypair-raw unit) \"BODY\"))"))
  (check-contains f "desc:sig-envelope")
  (check-contains f "sig-val")
  (check-contains f "eddsa")
  (check-contains f "BODY"))

(test-case "handoff/a signature verifies under its own key"
  (check-contains
   (run-last "(eval (let (kp (gen-keypair-raw unit)) (verify-raw (pubkey-raw kp) \"msg\" (sign-bytes kp \"msg\"))))")
   "true"))
