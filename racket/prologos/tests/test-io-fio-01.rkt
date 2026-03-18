#lang racket/base

;;;
;;; test-io-fio-01.rkt -- Linear file handle tests (IO-F1+F2)
;;;
;;; Group 1: Handle type definition (module loads, constructor, match)
;;; Group 2: Handle lifecycle (open, read, write, close)
;;; Group 3: QTT linear enforcement (positive/negative multiplicity checks)
;;; Group 4: Bracket pattern (fio-with-file convenience wrapper)
;;;
;;; Pattern: Shared fixture with process-string, temp files for IO tests.
;;;

(require rackunit
         racket/list
         racket/path
         racket/string
         racket/file
         racket/port
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

;; ========================================
;; Shared Fixture (fio module loaded once)
;; ========================================

(define shared-preamble
  "(ns test-fio)
(imports (prologos::core::fio :refer (Handle mk-handle fio-open fio-read-all fio-write fio-close fio-with-file)))")

(define-values (shared-global-env
                shared-ns-context
                shared-module-reg
                shared-trait-reg
                shared-impl-reg
                shared-param-impl-reg
                shared-ctor-reg
                shared-type-meta)
  (parameterize ([current-prelude-env (hasheq)]
                 [current-module-definitions-content (hasheq)]
                 [current-ns-context #f]
                 [current-module-registry prelude-module-registry]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
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
    (values (current-prelude-env)
            (current-ns-context)
            (current-module-registry)
            (current-trait-registry)
            (current-impl-registry)
            (current-param-impl-registry)
            (current-ctor-registry)
            (current-type-meta))))

(define (run s)
  (parameterize ([current-prelude-env shared-global-env]
                 [current-ns-context shared-ns-context]
                 [current-module-registry shared-module-reg]
                 [current-lib-paths (list prelude-lib-dir)]
                 [current-mult-meta-store (make-hasheq)]
                 [current-preparse-registry (current-preparse-registry)]
                 [current-trait-registry shared-trait-reg]
                 [current-impl-registry shared-impl-reg]
                 [current-param-impl-registry shared-param-impl-reg]
                 [current-ctor-registry shared-ctor-reg]
                 [current-type-meta shared-type-meta])
    (process-string s)))

(define (run-last s) (last (run s)))
(define (run-first s) (first (run s)))

;; ========================================
;; Group 1: Handle type definition
;; ========================================

(test-case "IO-F1: fio module loads without error"
  ;; The shared-preamble loaded fio successfully (if we got here, it worked)
  (check-true #t))

(test-case "IO-F1: mk-handle constructor creates a Handle"
  (define result (run-last "(eval (mk-handle zero))"))
  (check-true (string-contains? result "Handle")
              "result should mention Handle type"))

(test-case "IO-F1: pattern match on Handle extracts Nat"
  (define result
    (run-last
     "(def extract-idx : [-> Handle Nat]
        (fn [h <Handle>]
          (match h (mk-handle idx -> idx))))
      (eval (extract-idx (mk-handle (suc (suc zero)))))"))
  (check-equal? result "2N : Nat"))

;; ========================================
;; Group 2: Handle lifecycle (actual file IO)
;; ========================================

(test-case "IO-F1: fio-open returns a Handle"
  (define tmp (make-temporary-file))
  (define result
    (run-last (format "(eval (fio-open ~s \"read\"))" (path->string tmp))))
  (check-true (string-contains? result "Handle")
              "fio-open should return a Handle")
  (delete-file tmp))

(test-case "IO-F1: fio-read-all reads file contents"
  ;; Single-expression pattern: global defs store expressions (not values),
  ;; so side-effecting FFI calls would re-execute on each reference.
  ;; Use the bracket pattern which chains everything in one reduction.
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "hello fio" out))
    #:exists 'truncate/replace)
  (define result
    (run-last
     (format "(eval (fio-with-file ~s \"read\" (fn [h <Handle>] (fio-read-all h))))"
             (path->string tmp))))
  (check-equal? result "\"hello fio\" : String")
  (delete-file tmp))

(test-case "IO-F1: fio-write writes to file"
  (define tmp (make-temporary-file))
  (run-last
   (format "(def wh <Handle> (fio-open ~s \"write\"))
            (def wh2 <Handle> (fio-write wh \"written by fio\"))
            (eval (fio-close wh2))" (path->string tmp)))
  (check-equal? (file->string (path->string tmp)) "written by fio")
  (delete-file tmp))

(test-case "IO-F1: fio-close closes without error"
  (define tmp (make-temporary-file))
  (define result
    (run-last
     (format "(def ch <Handle> (fio-open ~s \"read\"))
              (eval (fio-close ch))" (path->string tmp))))
  (check-true (string-contains? result "unit")
              "fio-close should return unit")
  (delete-file tmp))

(test-case "IO-F1: full lifecycle open -> read -> close"
  ;; Tests the full open -> read -> close lifecycle via the bracket pattern.
  ;; The bracket ensures: open, body runs (read), close, return result.
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "lifecycle test" out))
    #:exists 'truncate/replace)
  (define result
    (run-last
     (format "(eval (fio-with-file ~s \"read\" (fn [h <Handle>] (fio-read-all h))))"
             (path->string tmp))))
  (check-equal? result "\"lifecycle test\" : String")
  (delete-file tmp))

;; ========================================
;; Group 3: QTT linear enforcement
;; ========================================

(test-case "IO-F1: linear handle used exactly once -- type-checks"
  ;; Positive: function takes :1 Handle, uses it once via fio-close
  (define result
    (run-first
     "(def close-it : [Pi [h :1 <Handle>] Unit] (fn [h :1 <Handle>] (fio-close h)))"))
  (check-true (string-contains? result "defined")
              "linear handle used once should type-check"))

(test-case "IO-F1: linear handle not used -- multiplicity error"
  ;; Negative: function takes :1 Handle but doesn't use it
  (define result
    (run-first
     "(def leak : [Pi [h :1 <Handle>] Unit] (fn [h :1 <Handle>] unit))"))
  (check-true (multiplicity-error? result)
              "unused linear handle should produce multiplicity error"))

(test-case "IO-F1: linear handle used twice -- multiplicity error"
  ;; Negative: function takes :1 Handle but uses it twice
  (define result
    (run-first
     "(def double-use : [Pi [h :1 <Handle>] Unit]
        (fn [h :1 <Handle>]
          (let _ : Unit := (fio-close h)
            (fio-close h))))"))
  (check-true (multiplicity-error? result)
              "double-use of linear handle should produce multiplicity error"))

(test-case "IO-F1: linear handle used in fio-write -- type-checks"
  ;; Positive: function takes :1 Handle, uses it once via fio-write
  ;; (fio-write also takes :1, so usage of h = 1*1 = 1)
  (define result
    (run-first
     "(def write-it : [Pi [h :1 <Handle>] Handle]
        (fn [h :1 <Handle>] (fio-write h \"test\")))"))
  (check-true (string-contains? result "defined")
              "linear handle used once in fio-write should type-check"))

;; ========================================
;; Group 4: Bracket pattern (fio-with-file)
;; ========================================

(test-case "IO-F2: fio-with-file reads file successfully"
  (define tmp (make-temporary-file))
  (call-with-output-file tmp
    (lambda (out) (write-string "bracket read" out))
    #:exists 'truncate/replace)
  (define result
    (run-last
     (format "(eval (fio-with-file ~s \"read\" (fn [h <Handle>] (fio-read-all h))))"
             (path->string tmp))))
  (check-equal? result "\"bracket read\" : String")
  (delete-file tmp))

(test-case "IO-F2: fio-with-file writes file successfully"
  (define tmp (make-temporary-file))
  (run-last
   (format "(eval (fio-with-file ~s \"write\"
              (fn [h <Handle>]
                (let h2 := (fio-write h \"bracket write\")
                  (pair h2 unit)))))"
           (path->string tmp)))
  (check-equal? (file->string (path->string tmp)) "bracket write")
  (delete-file tmp))

(test-case "IO-F2: fio-with-file auto-closes handle"
  ;; After fio-with-file returns, the handle should be closed.
  ;; We verify by reading the file successfully after the bracket closes.
  (define tmp (make-temporary-file))
  (run-last
   (format "(eval (fio-with-file ~s \"write\"
              (fn [h <Handle>]
                (let h2 := (fio-write h \"auto-closed\")
                  (pair h2 unit)))))"
           (path->string tmp)))
  ;; If the handle was properly closed, we can read the file
  (check-equal? (file->string (path->string tmp)) "auto-closed")
  (delete-file tmp))
