#lang racket/base

;;;
;;; Tests for extended string operations (prologos::core::string-ops)
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/port
         racket/file
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
         "../reduction.rkt"
         (prefix-in tc: "../typing-core.rkt")
         "../namespace.rkt"
         "../trait-resolution.rkt"
         "../reader.rkt")

;; ========================================
;; Shared Fixture (prelude loaded once)
;; ========================================

(define here (path->string (path-only (syntax-source #'here))))
(define lib-dir (simplify-path (build-path here ".." "lib")))

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-bundle-reg)
  (parameterize ([current-global-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry (hasheq)]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry (current-trait-registry)]
                 [current-impl-registry (current-impl-registry)]
                 [current-param-impl-registry (current-param-impl-registry)]
                 [current-bundle-registry (current-bundle-registry)])
    (install-module-loader!)
    (process-string "(ns test-string-ops)")
    (values (current-global-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-bundle-registry))))

(define (run s)
  (parameterize ([current-global-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-bundle-registry shared-bundle-reg])
    (process-string s)))

(define (run-last s) (last (run s)))

;; ========================================
;; A. FFI search/case operations
;; ========================================

(test-case "str::contains?"
  (check-equal? (run-last "(eval (str::contains? \"hello world\" \"world\"))") "true : Bool"))

(test-case "str::contains? false"
  (check-equal? (run-last "(eval (str::contains? \"hello\" \"xyz\"))") "false : Bool"))

(test-case "str::starts-with?"
  (check-equal? (run-last "(eval (str::starts-with? \"hello\" \"hel\"))") "true : Bool"))

(test-case "str::ends-with?"
  (check-equal? (run-last "(eval (str::ends-with? \"hello\" \"llo\"))") "true : Bool"))

(test-case "str::upper"
  (check-equal? (run-last "(eval (str::upper \"hello\"))") "\"HELLO\" : String"))

(test-case "str::lower"
  (check-equal? (run-last "(eval (str::lower \"HELLO\"))") "\"hello\" : String"))

(test-case "str::capitalize"
  (check-equal? (run-last "(eval (str::capitalize \"hello world\"))") "\"Hello World\" : String"))

;; ========================================
;; B. Pure string ops: predicates
;; ========================================

(test-case "str-ops::empty? true"
  (check-equal? (run-last "(eval (str-ops::empty? \"\"))") "true : Bool"))

(test-case "str-ops::empty? false"
  (check-equal? (run-last "(eval (str-ops::empty? \"a\"))") "false : Bool"))

;; ========================================
;; C. Trimming
;; ========================================

(test-case "str-ops::trim"
  (check-equal? (run-last "(eval (str-ops::trim \"  hello  \"))") "\"hello\" : String"))

(test-case "str-ops::trim-start"
  (check-equal? (run-last "(eval (str-ops::trim-start \"  hello  \"))") "\"hello  \" : String"))

(test-case "str-ops::trim-end"
  (check-equal? (run-last "(eval (str-ops::trim-end \"  hello  \"))") "\"  hello\" : String"))

(test-case "str-ops::strip-prefix some"
  (check-equal? (run-last "(eval (str-ops::strip-prefix \"http://\" \"http://example.com\"))")
                "[prologos::data::option::some String \"example.com\"] : [prologos::data::option::Option String]"))

(test-case "str-ops::strip-prefix none"
  (check-equal? (run-last "(eval (str-ops::strip-prefix \"https://\" \"http://example.com\"))")
                "[prologos::data::option::none String] : [prologos::data::option::Option String]"))

;; ========================================
;; D. Split & Join
;; ========================================

(test-case "str-ops::join"
  (check-equal? (run-last "(eval (str-ops::join \", \" (cons String \"a\" (cons String \"b\" (cons String \"c\" (nil String))))))")
                "\"a, b, c\" : String"))

(test-case "str-ops::join empty"
  (check-equal? (run-last "(eval (str-ops::join \", \" (nil String)))") "\"\" : String"))

(test-case "str-ops::unwords"
  (check-equal? (run-last "(eval (str-ops::unwords (cons String \"hello\" (cons String \"world\" (nil String)))))")
                "\"hello world\" : String"))

;; ========================================
;; E. Replacement
;; ========================================

(test-case "str-ops::replace"
  (check-equal? (run-last "(eval (str-ops::replace \"o\" \"0\" \"hello world\"))")
                "\"hell0 w0rld\" : String"))

;; ========================================
;; F. Transformation
;; ========================================

(test-case "str-ops::str-reverse"
  (check-equal? (run-last "(eval (str-ops::str-reverse \"hello\"))") "\"olleh\" : String"))

(test-case "str-ops::str-repeat"
  (check-equal? (run-last "(eval (str-ops::str-repeat 3 \"ab\"))") "\"ababab\" : String"))

;; ========================================
;; G. Predicates
;; ========================================

(test-case "str-ops::all? alpha"
  (check-equal? (run-last "(eval (str-ops::all? char::alpha? \"hello\"))") "true : Bool"))

(test-case "str-ops::all? alpha fails"
  (check-equal? (run-last "(eval (str-ops::all? char::alpha? \"hello1\"))") "false : Bool"))

(test-case "str-ops::any? numeric"
  (check-equal? (run-last "(eval (str-ops::any? char::numeric? \"hello1\"))") "true : Bool"))

;; ========================================
;; H. Conversion
;; ========================================

(test-case "str-ops::take"
  (check-equal? (run-last "(eval (str-ops::take 3 \"hello\"))") "\"hel\" : String"))

(test-case "str-ops::drop"
  (check-equal? (run-last "(eval (str-ops::drop 3 \"hello\"))") "\"lo\" : String"))

(test-case "str-ops::pad-start"
  (check-equal? (run-last "(eval (str-ops::pad-start 8 #\\0 \"42\"))") "\"00000042\" : String"))

(test-case "str-ops::pad-end"
  (check-equal? (run-last "(eval (str-ops::pad-end 8 #\\. \"hello\"))") "\"hello...\" : String"))
