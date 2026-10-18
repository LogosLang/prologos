#lang racket/base

;;;
;;; DEFERRED 160 (SW-27) — a program's registry state is scoped to its compilation unit.
;;;
;;; Registrations update their parameter by assignment and each file's registry cells are
;;; seeded from those parameters, so before SW-27 a `spec` declared by one program reached a
;;; later program in the same process:
;;;   - the LSP re-checking a document after the user deleted `spec f` still applied it
;;;     ("defn f has both a spec and inline type annotations");
;;;   - a `spec ok2` in `ns test` broke a later `defn ok2` in `ns t` (the suite-only
;;;     `test-error-messages` failure: `test-defn-multiarg-patterns` declares that spec).
;;; Fixed by `call-with-file-registry-scope` (driver.rkt) around `process-file` and every
;;; test-support `run-ns-*` call. The driver cases here call `process-file` exactly as the
;;; LSP does (lsp/server.rkt: no registry binding around it); they do NOT go through
;;; test-support, which scopes on its own.
;;;

(require rackunit
         racket/file
         racket/list
         racket/port
         racket/runtime-path
         "test-support.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../macros.rkt"
         (only-in "../namespace.rkt" current-file-module-network-ref)
         (only-in "../metavar-store.rkt" current-persistent-registry-net-box))

(define-runtime-path root "..")

(define dir (make-temporary-file "unit-isolation-~a" 'directory))

;; process-file a source string the way the LSP does: a fresh mnr per check (the LSP's
;; process root has none), no registry binding around the call.
(define (check-file name src #:before-unit-exit [exit-thunk #f])
  (define p (build-path dir name))
  (call-with-output-file p #:exists 'truncate (λ (o) (display src o)))
  (parameterize ([current-file-module-network-ref #f]
                 [current-output-port (open-output-nowhere)]
                 [current-error-port (open-output-nowhere)])
    (process-file p #:evaluate? #f #:before-unit-exit exit-thunk)))

(define (errors-of rs) (map prologos-error-message (filter prologos-error? rs)))
(define (last-result rs) (and (pair? rs) (last rs)))

(define spec-prog "ns test\nspec ok2 Nat -> Nat\ndefn ok2\n  | zero -> 1N\n  | suc _ -> 2N\n")
(define victim    "ns t\ndefn ok2\n  | zero -> 1\n  | suc _ -> 2\n")

(test-case "driver: a spec in one program's namespace does not reach a later program's same-named defn"
  (check-equal? (errors-of (check-file "spec.prologos" spec-prog)) '())
  (define rs (check-file "victim.prologos" victim))
  (check-equal? (errors-of rs) '())
  (check-equal? (last-result rs) "ok2 : Nat -> Int defined."))

(test-case "driver (LSP re-check): a spec deleted from a document no longer applies when it is re-checked"
  (define v1 "ns doc\nspec f Nat -> Nat\ndefn f [x] [suc x]\n")
  (define v2 "ns doc\ndefn f [x : Nat] : Nat [suc x]\n")
  (check-equal? (errors-of (check-file "doc.prologos" v1)) '())
  (define rs (check-file "doc.prologos" v2))
  (check-equal? (errors-of rs) '() "the deleted `spec f` must not survive the edit")
  (check-equal? (last-result rs) "f : Nat -> Nat defined."))

(test-case "driver: the unit's registries are readable inside its scope (#:before-unit-exit) and unchanged outside"
  (define before-regs (save-macros-registry-snapshot))
  (define before-ids  (save-macros-cell-ids))
  (define before-box  (current-persistent-registry-net-box))
  (define seen #f)
  (check-file "seen.prologos" "ns seen\nspec g Nat -> Nat\ndefn g [x] [suc x]\n"
              #:before-unit-exit (λ () (set! seen (hash-has-key? (current-spec-store) 'g))))
  (check-true seen "the LSP reads the document's spec store here")
  (check-false (hash-has-key? (current-spec-store) 'g) "the spec does not escape the unit")
  (check-true (for/and ([a (in-vector before-regs)] [b (in-vector (save-macros-registry-snapshot))]) (eq? a b))
              "no registry parameter changed")
  (check-true (for/and ([a (in-vector before-ids)] [b (in-vector (save-macros-cell-ids))]) (eq? a b))
              "no registry cell id changed")
  (check-eq? (current-persistent-registry-net-box) before-box "the caller's registry box is untouched")
  (when before-box
    (check-eq? (unbox before-box) (unbox (current-persistent-registry-net-box)))))

(test-case "test-support: a spec registered by one run-ns call is invisible to the next (string and file paths)"
  (check-equal? (run-ns-last "(ns test)\n(spec ok2 Nat -> Nat)\n(defn ok2 [v] (match v (zero -> 1N) (n -> 2N)))")
                "ok2 : Nat -> Nat defined.")
  (check-equal? (run-ns-ws-last victim) "ok2 : Nat -> Int defined.")
  (check-equal? (last (run-ns-ws-file-all victim)) "ok2 : Nat -> Int defined."))

;; The class guard: every parameter an `init-…-cell(s)!` function assigns (a cell id) or
;; seeds a cell from must be in the unit scope — a registry added later without joining
;; `macros-registry-params` / `macros-cell-id-params` (or the driver's list) would reopen
;; the leak for that registry. Read from the sources, resolved to the parameter VALUES.
(define INIT-MODULES '("macros.rkt" "warnings.rkt" "global-constraints.rkt" "typing-propagators.rkt"))

(define (init-function-params mod)
  (define src (file->string (build-path root mod)))
  (define bodies
    (for/list ([m (in-list (regexp-match-positions* #rx"\n\\(define \\(init-[a-z-]+-cells?! " src))])
      (define end (or (for/first ([e (in-list (regexp-match-positions* #rx"\n\\(define" src (cdr m)))]) (car e))
                      (string-length src)))
      (substring src (car m) end)))
  (remove-duplicates
   (append*
    (for/list ([b (in-list bodies)])
      (append (map cadr (regexp-match* #px"\\((current-[a-z-]+-cell-id) [a-z]" b #:match-select values))
              (map cadr (regexp-match* #px"net-new-cell [a-z0-9]+ \\((current-[a-z-]+)\\)" b #:match-select values)))))))

(test-case "class guard: every parameter assigned or seeded by an init-*-cell(s)! function is in the unit scope"
  (define scoped (file-unit-scoped-params))
  (define found
    (for*/list ([mod (in-list INIT-MODULES)]
                [name (in-list (init-function-params mod))])
      (list mod name (dynamic-require (build-path root mod) (string->symbol name)))))
  (check-true (>= (length found) 50) (format "the scan found only ~a parameters" (length found)))
  (define missing (for/list ([f (in-list found)] #:unless (memq (third f) scoped)) (format "~a: ~a" (first f) (second f))))
  (check-equal? missing '() "add these to macros-registry-params / macros-cell-id-params or the driver's list"))

(delete-directory/files dir)
