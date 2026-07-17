#lang racket/base
;; ============================================================================
;; CIU T6 F1b.5-s1 (D27) — the Reason validation-failure type + errors-to-list
;; renderer + the Keyword shim. Level-3 (process-file) so the prelude wiring,
;; the foreign keyword shims, and the generic errors-to-list all exercise the
;; real user path.
;; ============================================================================

(require rackunit
         racket/file
         racket/path
         racket/list
         racket/string
         "test-support.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../macros.rkt"
         "../namespace.rkt"
         "../relations.rkt"
         "../global-env.rkt")

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define (run-file-string content)
  (define tmp (make-temporary-file "reason-~a.prologos"))
  (call-with-output-file tmp
    (lambda (out) (display content out)) #:exists 'truncate)
  (define results
    (parameterize ([current-ns-context #f]
                   [current-module-registry (hasheq)]
                   [current-lib-paths (list lib-dir)]
                   [current-relation-store (make-relation-store)]
                   [current-preparse-registry (current-preparse-registry)]
                   [current-schema-registry (hasheq)]
                   [current-selection-registry (hasheq)]
                   [current-defn-param-names (hasheq)])
      (install-module-loader!)
      (process-file (path->string tmp))))
  (delete-file tmp)
  results)

(define (result-str r)
  (cond [(prologos-error? r) (format "ERROR: ~a" (prologos-error-message r))]
        [(string? r) r]
        [else (format "~a" r)]))

(define (ok? r) (not (prologos-error? r)))

;; ---- the prelude wires Reason unqualified ----------------------------------

(test-case "reason/prelude-exposes-api-unqualified"
  (define rs (run-file-string
              "ns rtest1\n
missing-required\n
[check-failed \"(> _ 0)\"]\n
[type-mismatch \"Int\" \"String\"]\n
unexpected-field\n"))
  (for ([r (in-list rs)]) (check-pred ok? r (result-str r)))
  (check-regexp-match #rx"Reason$" (result-str (first rs)))     ; missing-required : … Reason
  (check-regexp-match #rx"check-failed" (result-str (second rs)))
  (check-regexp-match #rx"type-mismatch" (result-str (third rs))))

;; ---- errors-to-list renders in a DETERMINISTIC field-sorted order ----------

(test-case "reason/errors-to-list-sorts-by-field"
  ;; keys inserted port, host, age → output must be age, host, port (sorted),
  ;; regardless of champ trie order (the whole point of the renderer)
  (define rs (run-file-string
              "ns rtest2\n
def errs := [map-assoc [map-assoc [map-assoc {} :port [type-mismatch \"Int\" \"String\"]] :host missing-required] :age [check-failed \"(> _ 0)\"]]\n
[errors-to-list errs]\n"))
  (check-pred ok? (last rs) (result-str (last rs)))
  (define out (result-str (last rs)))
  (define age-pos  (car (regexp-match-positions #rx":age" out)))
  (define host-pos (car (regexp-match-positions #rx":host" out)))
  (define port-pos (car (regexp-match-positions #rx":port" out)))
  (check-true (< (car age-pos) (car host-pos)) "age must sort before host")
  (check-true (< (car host-pos) (car port-pos)) "host must sort before port"))

(test-case "reason/errors-to-list-empty-map"
  (define rs (run-file-string
              "ns rtest3\n
[errors-to-list {}]\n"))
  (check-pred ok? (last rs) (result-str (last rs))))

;; ---- the Keyword shim (via the reason:: alias) -----------------------------

(test-case "reason/keyword-name-shim"
  (define rs (run-file-string
              "ns rtest4\n
[reason::keyword-name :host]\n
[reason::keyword-lte :aaa :bbb]\n
[reason::keyword-lte :bbb :aaa]\n"))
  (check-regexp-match #rx"\"host\" : String" (result-str (first rs)))
  (check-regexp-match #rx"true"  (result-str (second rs)))
  (check-regexp-match #rx"false" (result-str (third rs))))
