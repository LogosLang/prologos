#lang racket/base

;;;
;;; Rel T1 Aspect D, D.2.c — fact-corpus generator validation (Level 3).
;;;
;;; tools/gen-fact-corpus.rkt is the artifact-§8 dataset generator: the only
;;; way to produce >16-row fact relations until `:from`/`:source` bulk import
;;; exists. This gate runs a generated corpus through the FULL process-file
;;; pipeline (WS reader, preparse, defr registration, solve) and checks the
;;; four query shapes return the right answers — so scale benchmarks built on
;;; the generator stand on validated syntax, not on "it looked right once."
;;;

(require rackunit
         racket/list
         racket/string
         racket/path
         racket/file
         "test-support.rkt"
         "../driver.rkt"
         "../errors.rkt"
         "../global-env.rkt"
         "../namespace.rkt"
         "../metavar-store.rkt"
         "../relations.rkt"
         "../trait-resolution.rkt"
         "../parse-reader.rkt"
         "../macros.rkt"
         "../tools/gen-fact-corpus.rkt")

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

;; Run a generated corpus string through the full pipeline (the
;; test-bound-args-01 process-file pattern).
(define (run-corpus content)
  (define tmp (make-temporary-file "fact-corpus-~a.prologos"))
  (call-with-output-file tmp
    (lambda (out) (display content out))
    #:exists 'truncate)
  (define results
    (parameterize ([current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list lib-dir)]
                   [current-relation-store (make-relation-store)]
                   [current-preparse-registry prelude-preparse-registry]
                   [current-trait-registry prelude-trait-registry]
                   [current-impl-registry prelude-impl-registry]
                   [current-param-impl-registry prelude-param-impl-registry]
                   [current-bundle-registry (current-bundle-registry)]
                   [current-defn-param-names (hasheq)])
      (install-module-loader!)
      (process-file (path->string tmp))))
  (delete-file tmp)
  results)

(define (check-no-errors results)
  (for ([r (in-list results)])
    (when (prologos-error? r)
      (fail (format "Unexpected error: ~a" (prologos-error-message r))))))

(test-case "gen-fact-corpus: 12-row corpus runs 0-errors; all 6 query shapes correct"
  (define results (run-corpus (gen-fact-corpus-string #:rows 12 #:edge-rows 6)))
  (check-no-errors results)
  ;; Last six results = the solve queries, in emission order:
  ;; point-last · enumeration · partial-key · member-hit · member-miss · 2-hop join.
  (define solves (take-right results 6))
  (define point-str (format "~a" (first solves)))
  (define enum-str  (format "~a" (second solves)))
  (define partial-str (format "~a" (third solves)))
  (define hit-str   (format "~a" (fourth solves)))
  (define miss-str  (format "~a" (fifth solves)))
  (define join-str  (format "~a" (sixth solves)))
  ;; Membership: hit = one empty binding ('[{}]), miss = nil — they must differ
  ;; (surface outputs pinned by the D.2.c run-file probe).
  (check-false (equal? hit-str miss-str) "member-hit must differ from member-miss")
  ;; Point lookup on key 11 binds s="n11", w=77.
  (check-true (string-contains? point-str "n11") "point-last should bind s=\"n11\"")
  (check-true (string-contains? point-str "77") "point-last should bind w=77")
  ;; Enumeration returns all 12 rows (first and last present).
  (check-true (string-contains? enum-str "n0") "enum should include row 0")
  (check-true (string-contains? enum-str "n11") "enum should include row 11")
  ;; Partial key (2nd col ground at \"n11\") recovers k=11.
  (check-true (string-contains? partial-str "11") "partial-key should bind k=11")
  ;; 2-hop join over the 6-row edge chain yields pairs (0,2)..(4,6).
  (check-true (string-contains? join-str "6") "join should reach node 6")
  (check-false (string-contains? join-str "Unknown") "join should resolve `path`"))

(test-case "gen-fact-corpus: wider arity + more rows still 0-errors (shape contract)"
  ;; 30×5 keeps suite runtime small; the 250/260 threshold-straddle sizes are
  ;; exercised at bench time (benchmarks/comparative/solve-scale.prologos),
  ;; not suite time.
  (define results (run-corpus (gen-fact-corpus-string #:rows 30 #:arity 5 #:edge-rows 4)))
  (check-no-errors results)
  (define enum-str (format "~a" (second (take-right results 6))))
  (check-true (string-contains? enum-str "n29") "enum should include the last of 30 rows"))
