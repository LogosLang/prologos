#lang racket/base
;; ============================================================================
;; CIU T6 F1b.5-s1 — schema FIELD-TYPE construction tests (Level 3)
;;
;; The durable versions of the p0 probes that found the field-type class
;; defects: container fields ((List Int), (Option Int)) minted BARE head
;; fvars that never unified with the prelude's qualified types, and angle
;; fields (<Int | String>, <Int -> Int>) stored mangled reader sentinels —
;; EVERY construction against such fields failed pre-s1. These cases pin the
;; flip. Helper cloned from test-schema-seal.rkt (the run-file-string L3
;; template — full process-file pipeline, prelude available).
;; ============================================================================

(require rackunit
         racket/file
         racket/path
         racket/list
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
  (define tmp (make-temporary-file "schema-fieldcons-~a.prologos"))
  (call-with-output-file tmp
    (lambda (out) (display content out))
    #:exists 'truncate)
  (define results
    ;; Seed from the ONCE-per-subprocess prelude snapshot rather than reloading all
    ;; 39 prelude modules per test case. The registry family must be seeded TOGETHER:
    ;; a preloaded module registry means modules are not re-loaded, so seeding only
    ;; `current-module-registry` leaves the trait/impl registries empty.
    (parameterize ([current-ns-context #f]
                   [current-module-registry prelude-module-registry]
                   [current-lib-paths (list lib-dir)]
                   [current-relation-store (make-relation-store)]
                   [current-preparse-registry prelude-preparse-registry]
                   [current-trait-registry prelude-trait-registry]
                   [current-impl-registry prelude-impl-registry]
                   [current-param-impl-registry prelude-param-impl-registry]
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

;; ---- tier-2: container fields construct + project --------------------------

(test-case "fieldcons/list-field-constructs-and-projects"
  (define rs (run-file-string
              "ns fc1\n
def xs3 := '[1 2 3]\n
schema WithList\n  :name String\n  :xs (List Int)\n
def wl : WithList := {:name \"a\" :xs xs3}\n
wl.xs\n"))
  (for ([r (in-list rs)])
    (check-pred ok? r (result-str r)))
  (check-regexp-match #rx"List Int" (result-str (last rs))))

(test-case "fieldcons/option-field-constructs-and-projects"
  (define rs (run-file-string
              "ns fc2\n
schema WithOpt\n  :o (Option Int)\n
def wo : WithOpt := {:o [some 3]}\n
wo.o\n"))
  (for ([r (in-list rs)])
    (check-pred ok? r (result-str r)))
  (check-regexp-match #rx"some" (result-str (last rs))))

(test-case "fieldcons/list-field-wrong-type-rejects"
  (define rs (run-file-string
              "ns fc3\n
schema WithList\n  :xs (List Int)\n
def bad : WithList := {:xs \"nope\"}\n"))
  (check-true (prologos-error? (last rs)) "wrong-typed container field must reject"))

;; ---- tier-3/union: angle fields construct ----------------------------------

(test-case "fieldcons/union-field-both-branches"
  (define rs (run-file-string
              "ns fc4\n
schema WithUnion\n  :v <Int | String>\n
def wi : WithUnion := {:v 3}\n
def ws : WithUnion := {:v \"x\"}\n
wi.v\n"))
  (for ([r (in-list rs)])
    (check-pred ok? r (result-str r))))

(test-case "fieldcons/union-field-rejects-outside-branch"
  (define rs (run-file-string
              "ns fc5\n
schema WithUnion\n  :v <Int | String>\n
def bad : WithUnion := {:v true}\n"))
  (check-true (prologos-error? (last rs)) "Bool outside <Int|String> must reject"))

(test-case "fieldcons/arrow-field-constructs-and-applies"
  (define rs (run-file-string
              "ns fc6\n
schema WithFn\n  :name String\n  :cb <Int -> Int>\n
spec idi Int -> Int\ndefn idi [x] x\n
def wf : WithFn := {:name \"a\" :cb idi}\n
[wf.cb 4]\n"))
  (for ([r (in-list rs)])
    (check-pred ok? r (result-str r)))
  (check-regexp-match #rx"^4" (result-str (last rs))))

(test-case "fieldcons/unsupported-angle-shape-errors-at-declaration"
  ;; a sigma-shaped angle field refuses LOUDLY at declaration. The schema
  ;; convention for malformed declarations is a RAISED exception (matching
  ;; the pre-existing missing-type / bad-keyword raises in parse-schema-fields),
  ;; not a returned prologos-error — honest refusal; richer field types are
  ;; F-carrier / walker-era work.
  (check-exn
   #rx"field type shape"
   (lambda ()
     (run-file-string "ns fc7\n
schema BadShape\n  :p <Int * String>\n"))))
