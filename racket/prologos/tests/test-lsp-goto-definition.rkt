#lang racket/base

;;; test-lsp-goto-definition.rkt — cross-module go-to-definition (2026-08-04)
;;;
;;; DEFERRED listed this as "only works for symbols defined in current file",
;;; blocked on "cross-module location tracking in module registry". The tracking
;;; was already there: `module-info` carries `definition-locations` (populated by
;;; `register-definition-location!` during elaboration) AND `file-path`. Nothing
;;; consulted them — every branch of `get-definition-location` answered with the
;;; CURRENT document's uri.
;;;
;;; Three traps this file exists to catch, each of which looks like "not
;;; implemented" rather than like a bug:
;;;
;;;   1. `lsp-state-module-registry`'s setter is never called anywhere in
;;;      server.rkt — the field is #f for the process's whole life. Searching it
;;;      finds nothing, silently. The lookup takes its registry from the
;;;      document's REPL session (or the prelude cache) instead.
;;;   2. The handler reads the open-document text FIRST and returns json-null
;;;      when there is none, so a test that never opens the document asserts on
;;;      that early return rather than on the feature.
;;;   3. "Found something" is not the claim. The in-file fallback also returns a
;;;      Location — with the current document's uri. So the assertions check the
;;;      answer names a DIFFERENT file, and the right one.

(require rackunit
         racket/string
         (only-in "../lsp/server.rkt"
                  make-initial-state
                  get-or-create-session!
                  get-definition-location
                  lsp-state-document-contents
                  lsp-state-definition-locations)
         (only-in "../source-location.rkt" srcloc))

;; Shared fixture: ONE lsp-state. The prelude loads once on the first
;; get-or-create-session! (~3s), and its module registry is what gets searched.
(define st (make-initial-state))

(define USER-URI "file:///goto-user.prologos")

;; Uses a prelude name; defines none. `foldr` sits inside line 1 (0-indexed),
;; starting at column 10.
(define USER-TEXT
  (string-append "ns gotouser\n"
                 "def s := [foldr int+ 0 '[1 2 3]]\n"))

(hash-set! (lsp-state-document-contents st) USER-URI USER-TEXT)
(void (get-or-create-session! st USER-URI))

(test-case "goto/cross-module: a prelude name resolves to ITS file, not the current one"
  (define loc (get-definition-location st USER-URI 1 11))
  (check-true (hash? loc)
              (format "nothing found for foldr — the cross-module lookup did not fire: ~v" loc))

  (define found-uri (hash-ref loc 'uri #f))
  (check-true (string? found-uri) (format "no uri in the Location: ~v" loc))

  ;; The point of the feature. If this equals USER-URI, one of the in-file
  ;; branches answered and the test above would have passed proving nothing.
  (check-false (string=? found-uri USER-URI)
               (format "resolved to the CURRENT document — in-file fallback answered: ~a" found-uri))

  ;; …and specifically the module that defines foldr.
  (check-true (string-contains? found-uri "list.prologos")
              (format "expected prologos::data::list's file, got: ~a" found-uri))

  (check-true (hash? (hash-ref loc 'range #f)) (format "no range: ~v" loc)))

(test-case "goto/cross-module: an in-file definition still WINS over a module one"
  ;; Locality must not regress — the cross-module search is a fallback, reached
  ;; only after the in-file lookups miss. Seed the in-file map the way an
  ;; elaboration pass would, using a name the PRELUDE also defines: if the
  ;; ordering ever inverts, `foldr` resolves to list.prologos and this fails.
  ;;
  ;; (Seeding is necessary because that map is populated by elaborating the
  ;; document, which this fixture does not do — the earlier version of this
  ;; test asserted on an un-elaborated document and just measured the regex
  ;; fallback returning nothing.)
  (hash-set! (lsp-state-definition-locations st) USER-URI
             (hasheq 'foldr (srcloc "/goto-user.prologos" 2 4 5)))
  (define loc (get-definition-location st USER-URI 1 11))
  (check-true (hash? loc) (format "no definition for the seeded local `foldr`: ~v" loc))
  (check-equal? (hash-ref loc 'uri #f) USER-URI
                (format "an in-file definition lost to a cross-module one: ~v" loc))
  ;; …and clear it again so the ordering of test-cases in this file cannot
  ;; matter to the cases above.
  (hash-remove! (lsp-state-definition-locations st) USER-URI))

(test-case "goto/cross-module: a name defined nowhere resolves to nothing"
  ;; The control. Without it, a lookup that returned SOME module for every query
  ;; would pass the first case.
  (define uri "file:///goto-absent.prologos")
  (hash-set! (lsp-state-document-contents st) uri "ns gotoabsent\ndef q := zzz_no_such_name_anywhere\n")
  (define loc (get-definition-location st uri 1 12))
  (check-false (hash? loc)
               (format "an undefined name resolved to something: ~v" loc)))
