#lang racket/base

;;;
;;; Prelude integrity canary
;;;
;;; process-ns-declaration (namespace.rkt) wraps EVERY prelude auto-import in
;;;   (with-handlers ([exn:fail? (lambda (e) (void))]) (process-imports req))
;;; so that one bad entry cannot stop the rest from loading. The intent is
;;; sound, but the handler discards the exception, so a partially-loaded
;;; prelude is COMPLETELY SILENT: no error, no warning, exit 0.
;;;
;;; Two things get swallowed:
;;;   1. an entry naming a module that does not exist
;;;   2. an entry naming a :refer name the module does not export
;;;      (process-imports raises 'imports "~a does not export ~a", and that
;;;       raise is caught by the same outer handler)
;;;
;;; Both were reproduced by fault injection while writing this file: two broken
;;; entries added to prelude-imports produced a clean exit-0 run, and only these
;;; assertions noticed. Case 2 additionally leaves the module PRESENT in the
;;; registry, so a module-presence check alone does NOT catch it — hence the
;;; second test.
;;;
;;; WHY NOT ASSERT A COUNT: (hash-count prelude-module-registry) is NOT stable.
;;; Measured: 39 with a cold .pnet cache, 37 warm. The two extra cold entries
;;; are prologos::data::parity and prologos::data::sign — transitive deps that
;;; get registered when modules are elaborated from source but not when they
;;; are served from the .pnet cache. A hardcoded count would be flaky. The
;;; assertions below are cache-independent: they check that everything DECLARED
;;; in prelude-imports actually arrived, which held in both regimes.
;;;
;;; These assertions are also SELF-MAINTAINING — the expectation is derived from
;;; prelude-imports itself, so adding or removing a prelude entry needs no edit
;;; here. There is no magic number to update reflexively.
;;;

(require rackunit
         racket/list
         "test-support.rkt"
         "../namespace.rkt")

;; ========================================
;; Entry decomposition
;; ========================================

;; (imports [MOD :as A :refer [n ...]]) / (imports [MOD :refer-all])
;;   -> (values MOD (listof refer-name) refer-all?)
;; A module may appear in SEVERAL entries (the trait imports are split across
;; up to four), so callers must accumulate rather than assume one entry each.
(define (entry-parts req)
  (define inner (cadr req))
  (let loop ([r (cdr inner)] [names '()] [all? #f])
    (cond
      [(null? r) (values (car inner) names all?)]
      [(eq? (car r) ':refer-all) (loop (cdr r) names #t)]
      [(and (eq? (car r) ':refer) (pair? (cdr r)) (list? (cadr r)))
       (loop (cddr r) (append names (cadr r)) all?)]
      [(and (eq? (car r) ':as) (pair? (cdr r))) (loop (cddr r) names all?)]
      [else (loop (cdr r) names all?)])))

;; ========================================
;; Tests
;; ========================================

(test-case "prelude declares a non-trivial set of imports"
  ;; Guards against the assertions below passing vacuously if prelude-imports
  ;; were ever emptied or failed to export.
  (check-true (list? prelude-imports))
  (check-true (>= (length prelude-imports) 30)
              (format "prelude-imports has only ~a entries — suspiciously few"
                      (length prelude-imports))))

(test-case "every module declared in the prelude actually loaded"
  ;; Catches failure mode 1: an entry naming a nonexistent module is swallowed.
  (define missing
    (for/list ([req (in-list prelude-imports)]
               #:unless (let-values ([(mod _names _all?) (entry-parts req)])
                          (hash-has-key? prelude-module-registry mod)))
      (let-values ([(mod _names _all?) (entry-parts req)]) mod)))
  (check-equal? missing '()
                (format "prelude modules declared but NOT loaded (silently swallowed by process-ns-declaration): ~a"
                        missing)))

(test-case "every :refer name in the prelude is actually exported"
  ;; Catches failure mode 2: a bad :refer name raises inside process-imports
  ;; and is swallowed by the same handler, leaving the module registered but
  ;; the name unbound for every user program.
  (define missing
    (for*/list ([req (in-list prelude-imports)]
                [parts (in-value (call-with-values (lambda () (entry-parts req)) list))]
                [mi (in-value (hash-ref prelude-module-registry (car parts) #f))]
                #:when mi
                [exports (in-value (module-info-exports mi))]
                ;; :all exporters export everything by definition — nothing to check.
                #:unless (and (pair? exports) (eq? (car exports) ':all))
                [name (in-list (cadr parts))]
                #:unless (memq name exports))
      (cons (car parts) name)))
  (check-equal? missing '()
                (format "prelude :refer names NOT exported by their module (silently swallowed): ~a"
                        missing)))
