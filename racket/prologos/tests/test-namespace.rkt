#lang racket/base

;;;
;;; Tests for namespace.rkt — module registry, namespace context, name resolution
;;;

(require rackunit
         racket/set
         "../namespace.rkt"
         "../global-env.rkt"
         "../syntax.rkt"
         "../prelude.rkt"
         "../elaborator.rkt"
         "../surface-syntax.rkt"
         "../source-location.rkt")

;; ========================================
;; Module Info
;; ========================================

(test-case "module-info creation and fields"
  (define mi (module-info 'prologos.core
                          '(id const)
                          (hasheq 'prologos.core/id (cons (expr-Nat) (expr-zero))
                                  'prologos.core/const (cons (expr-Bool) (expr-true)))
                          #f
                          (hasheq)
                          (hasheq)))
  (check-equal? (module-info-namespace mi) 'prologos.core)
  (check-equal? (module-info-exports mi) '(id const))
  (check-equal? (module-info-file-path mi) #f))

;; ========================================
;; Module Registry
;; ========================================

(test-case "register and lookup module"
  (parameterize ([current-module-registry (hasheq)])
    (define mi (module-info 'test.mod '(foo) (hasheq) #f (hasheq) (hasheq)))
    (check-false (module-loaded? 'test.mod))
    (check-false (lookup-module 'test.mod))
    (register-module! 'test.mod mi)
    (check-true (module-loaded? 'test.mod))
    (check-equal? (lookup-module 'test.mod) mi)))

;; ========================================
;; Name Qualification
;; ========================================

(test-case "qualify-name"
  (check-equal? (qualify-name 'add 'prologos.data.nat)
                'prologos.data.nat/add)
  (check-equal? (qualify-name 'id 'prologos.core)
                'prologos.core/id))

(test-case "split-qualified-name"
  (let-values ([(prefix name) (split-qualified-name 'nat/add)])
    (check-equal? prefix 'nat)
    (check-equal? name 'add))
  (let-values ([(prefix name) (split-qualified-name 'prologos.data.nat/add)])
    (check-equal? prefix 'prologos.data.nat)
    (check-equal? name 'add))
  (let-values ([(prefix name) (split-qualified-name 'add)])
    (check-false prefix)
    (check-equal? name 'add)))

;; ========================================
;; Namespace Context
;; ========================================

(test-case "make-empty-ns-context"
  (define ctx (make-empty-ns-context 'my.ns))
  (check-equal? (ns-context-current-ns ctx) 'my.ns)
  (check-equal? (ns-context-alias-map ctx) (hasheq))
  (check-equal? (ns-context-refer-map ctx) (hasheq))
  (check-equal? (ns-context-refer-all-nses ctx) '())
  (check-equal? (ns-context-exports ctx) '()))

(test-case "ns-context-add-alias"
  (define ctx (make-empty-ns-context 'my.ns))
  (define ctx2 (ns-context-add-alias ctx 'nat 'prologos.data.nat))
  (check-equal? (hash-ref (ns-context-alias-map ctx2) 'nat) 'prologos.data.nat))

(test-case "ns-context-add-refer"
  (define ctx (make-empty-ns-context 'my.ns))
  (define ctx2 (ns-context-add-refer ctx 'prologos.data.nat '(add mult)))
  (check-equal? (hash-ref (ns-context-refer-map ctx2) 'add)
                'prologos.data.nat/add)
  (check-equal? (hash-ref (ns-context-refer-map ctx2) 'mult)
                'prologos.data.nat/mult))

(test-case "ns-context-add-refer-all"
  (define ctx (make-empty-ns-context 'my.ns))
  (define ctx2 (ns-context-add-refer-all ctx 'prologos.core))
  (check-equal? (ns-context-refer-all-nses ctx2) '(prologos.core)))

(test-case "ns-context-set-exports"
  (define ctx (make-empty-ns-context 'my.ns))
  (define ctx2 (ns-context-set-exports ctx '(foo bar)))
  (check-equal? (ns-context-exports ctx2) '(foo bar)))

;; ========================================
;; Name Resolution — Legacy Mode
;; ========================================

(test-case "resolve-name in legacy mode (ns-ctx = #f)"
  (check-equal? (resolve-name 'add #f) 'add)
  (check-equal? (resolve-name 'prologos.data.nat/add #f)
                'prologos.data.nat/add))

;; ========================================
;; Name Resolution — With Namespace Context
;; ========================================

(test-case "resolve-name: direct refer"
  (define ctx (ns-context-add-refer
               (make-empty-ns-context 'my.ns)
               'prologos.data.nat '(add)))
  (check-equal? (resolve-name 'add ctx) 'prologos.data.nat/add))

(test-case "resolve-name: alias + qualified"
  (define ctx (ns-context-add-alias
               (make-empty-ns-context 'my.ns)
               'nat 'prologos.data.nat))
  (check-equal? (resolve-name 'nat/add ctx) 'prologos.data.nat/add))

(test-case "resolve-name: refer-all"
  (parameterize ([current-module-registry (hasheq)])
    (define mi (module-info 'prologos.core
                            '(id const)
                            (hasheq)
                            #f (hasheq) (hasheq)))
    (register-module! 'prologos.core mi)
    (define ctx (ns-context-add-refer-all
                 (make-empty-ns-context 'my.ns)
                 'prologos.core))
    (check-equal? (resolve-name 'id ctx) 'prologos.core/id)
    ;; 'unknown' not in exports → falls through to current-ns qualification
    (check-equal? (resolve-name 'unknown ctx) 'my.ns/unknown)))

(test-case "resolve-name: own namespace qualification"
  (define ctx (make-empty-ns-context 'my.ns))
  ;; Unqualified name not in refers → qualifies with current-ns
  (check-equal? (resolve-name 'foo ctx) 'my.ns/foo))

(test-case "resolve-name: already fully-qualified"
  (define ctx (make-empty-ns-context 'my.ns))
  ;; If prefix is not an alias, returned as-is
  (check-equal? (resolve-name 'prologos.data.nat/add ctx)
                'prologos.data.nat/add))

;; ========================================
;; Path Resolution
;; ========================================

(test-case "ns->path-segments"
  (check-equal? (ns->path-segments 'prologos.data.nat)
                '("prologos" "data" "nat"))
  (check-equal? (ns->path-segments 'prologos.core)
                '("prologos" "core")))

;; ========================================
;; Global Env Import
;; ========================================

(test-case "global-env-import-module"
  (define mod-env
    (hasheq 'test.mod/foo (cons (expr-Nat) (expr-zero))
            'test.mod/bar (cons (expr-Bool) (expr-true))))
  (define result
    (global-env-import-module (hasheq)
                              '(foo bar)
                              mod-env
                              qualify-name
                              'test.mod))
  (check-true (hash-has-key? result 'test.mod/foo))
  (check-true (hash-has-key? result 'test.mod/bar))
  (check-equal? (car (hash-ref result 'test.mod/foo)) (expr-Nat))
  (check-equal? (cdr (hash-ref result 'test.mod/foo)) (expr-zero)))

;; ========================================
;; Elaboration with Namespace Context
;; ========================================

(test-case "elaboration resolves via namespace"
  ;; Set up: global env has a fully-qualified name
  (parameterize ([current-global-env
                  (hasheq 'prologos.data.nat/add (cons (expr-Nat) (expr-zero)))]
                 [current-module-registry (hasheq)]
                 [current-ns-context
                  (ns-context-add-refer
                   (make-empty-ns-context 'test.ns)
                   'prologos.data.nat '(add))])
    ;; 'add' should resolve to 'prologos.data.nat/add'
    (define result (elaborate (surf-var 'add srcloc-unknown)))
    (check-equal? result (expr-fvar 'prologos.data.nat/add))))

(test-case "elaboration resolves via alias"
  (parameterize ([current-global-env
                  (hasheq 'prologos.data.nat/add (cons (expr-Nat) (expr-zero)))]
                 [current-module-registry (hasheq)]
                 [current-ns-context
                  (ns-context-add-alias
                   (make-empty-ns-context 'test.ns)
                   'nat 'prologos.data.nat)])
    ;; 'nat/add' should resolve to 'prologos.data.nat/add'
    (define result (elaborate (surf-var 'nat/add srcloc-unknown)))
    (check-equal? result (expr-fvar 'prologos.data.nat/add))))

(test-case "elaboration backward-compatible without ns-context"
  ;; When current-ns-context is #f, old behavior is preserved
  (parameterize ([current-global-env
                  (hasheq 'myname (cons (expr-Nat) (expr-zero)))]
                 [current-ns-context #f])
    (define result (elaborate (surf-var 'myname srcloc-unknown)))
    (check-equal? result (expr-fvar 'myname))))
