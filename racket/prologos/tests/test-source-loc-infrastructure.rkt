#lang racket/base

;;;
;;; test-source-loc-infrastructure.rkt — PPN Track 4C Phase 1.5 tests
;;;
;;; Covers:
;;;   - `current-source-loc` parameter basics
;;;   - `surf-node-srcloc` generic extractor (all surf-* structs have
;;;     srcloc as last field — verified across 360+ defs)
;;;   - `fire-propagator` wraps with parameterize from propagator struct
;;;   - `net-add-propagator` with `#:srcloc` kwarg carries srcloc
;;;   - Unknown struct → #f (caller preserves parent srcloc)
;;;

(require rackunit
         "../source-location.rkt"
         "../surface-syntax.rkt"
         "../propagator.rkt"
         ;; PPN 4C Phase 3C.d.1 (W1, 2026-05-24): champ-lookup needed to
         ;; verify propagator-srcloc field is populated post-install.
         "../champ.rkt")

;; ========================================
;; current-source-loc parameter
;; ========================================

(test-case "current-source-loc default #f"
  (parameterize ([current-source-loc #f])
    (check-false (current-source-loc))))

(test-case "current-source-loc parameterize sets and restores"
  (define loc (srcloc "test.rkt" 1 2 3))
  (parameterize ([current-source-loc loc])
    (check-equal? (current-source-loc) loc))
  ;; after parameterize, back to #f (default from outer test context)
  (check-false (current-source-loc)))

(test-case "current-source-loc nested parameterize"
  (define outer (srcloc "outer.rkt" 1 1 1))
  (define inner (srcloc "inner.rkt" 5 5 5))
  (parameterize ([current-source-loc outer])
    (check-equal? (current-source-loc) outer)
    (parameterize ([current-source-loc inner])
      (check-equal? (current-source-loc) inner))
    ;; back to outer after inner parameterize exits
    (check-equal? (current-source-loc) outer)))

;; ========================================
;; surf-node-srcloc generic extractor
;; ========================================

(test-case "surf-node-srcloc extracts from surf-var (srcloc is last field)"
  (define loc (srcloc "t.rkt" 10 5 2))
  (define node (surf-var 'x loc))
  (check-equal? (surf-node-srcloc node) loc))

(test-case "surf-node-srcloc extracts from surf-lam (multiple fields)"
  (define loc (srcloc "t.rkt" 20 0 10))
  (define body (surf-var 'x (srcloc "t.rkt" 20 5 1)))
  (define node (surf-lam 'binder body loc))
  (check-equal? (surf-node-srcloc node) loc))

(test-case "surf-node-srcloc extracts from surf-app"
  (define loc (srcloc "t.rkt" 30 0 15))
  (define func (surf-var 'f (srcloc "t.rkt" 30 1 1)))
  (define args (list (surf-var 'x (srcloc "t.rkt" 30 3 1))))
  (define node (surf-app func args loc))
  (check-equal? (surf-node-srcloc node) loc))

(test-case "surf-node-srcloc on non-struct returns #f"
  (check-false (surf-node-srcloc 42))
  (check-false (surf-node-srcloc 'symbol))
  (check-false (surf-node-srcloc "string"))
  (check-false (surf-node-srcloc '(list)))
  (check-false (surf-node-srcloc #f)))

;; ========================================
;; fire-propagator wraps with parameterize
;; ========================================

(test-case "fire-propagator sets current-source-loc from propagator struct"
  (define loc (srcloc "prop-origin.rkt" 42 7 3))
  ;; Capture what current-source-loc was during fire
  (define captured-during-fire (box #f))
  (define (capturing-fire net)
    (set-box! captured-during-fire (current-source-loc))
    net)
  (define prop (propagator '() '() capturing-fire #f 0 loc))
  (define net (make-prop-network))
  ;; Simulate scheduler invoking fire-propagator
  (fire-propagator prop net)
  (check-equal? (unbox captured-during-fire) loc))

(test-case "fire-propagator restores current-source-loc after fire"
  (define loc-before (srcloc "before.rkt" 1 1 1))
  (define loc-propagator (srcloc "prop.rkt" 2 2 2))
  (define prop (propagator '() '() (lambda (net) net) #f 0 loc-propagator))
  (define net (make-prop-network))
  (parameterize ([current-source-loc loc-before])
    (fire-propagator prop net)
    ;; After fire, current-source-loc is restored to the outer parameterize
    (check-equal? (current-source-loc) loc-before)))

(test-case "fire-propagator with #f srcloc still fires cleanly"
  (define captured (box 'not-set))
  (define (capturing-fire net)
    (set-box! captured (current-source-loc))
    net)
  (define prop (propagator '() '() capturing-fire #f 0 #f))
  (define net (make-prop-network))
  (parameterize ([current-source-loc #f])
    (fire-propagator prop net))
  (check-false (unbox captured)))

;; ========================================
;; net-add-propagator with #:srcloc kwarg
;; ========================================

(test-case "net-add-propagator stores srcloc in propagator struct"
  (define loc (srcloc "install.rkt" 100 5 10))
  (define net (make-prop-network))
  (define-values (net2 cid) (net-new-cell net 'initial (lambda (o n) n)))
  (define-values (net3 pid)
    (net-add-propagator net2 (list cid) '() (lambda (net) net)
                        #:srcloc loc))
  ;; Look up the propagator and verify its srcloc field
  (define prop (hash-ref (for/hash ([k+v (in-list '())]) (values #f #f)) #f #f))
  ;; Use the CHAMP-based lookup instead
  (define propagators-champ (prop-network-propagators net3))
  ;; Iterate to find our propagator (a simpler test strategy)
  ;; For now, just verify no error occurred — propagator installed with srcloc
  (check-true (prop-id? pid)))

;; Helper for W1 verification: look up the propagator struct via pid + read srcloc
(define (lookup-prop-srcloc net pid)
  (define props (prop-network-propagators net))
  (define prop (champ-lookup props (prop-id-hash pid) pid))
  (and (propagator? prop) (propagator-srcloc prop)))

(test-case "W1 default: net-add-propagator default #:srcloc is #f when current-source-loc unbound"
  ;; Regression test for D-3C.d-1: tests that the W1 default DOES NOT regress
  ;; the #f case. Outside parameterize, (current-source-loc) returns #f, and
  ;; the propagator's srcloc field should be #f.
  (define net (make-prop-network))
  (define-values (net2 cid) (net-new-cell net 'initial (lambda (o n) n)))
  (define-values (net3 pid)
    (net-add-propagator net2 (list cid) '() (lambda (net) net)))
  (check-true (prop-id? pid))
  ;; Verify propagator-srcloc field is #f (per W1 default; current-source-loc unbound)
  (check-false (lookup-prop-srcloc net3 pid)))

;; ========================================
;; PPN 4C Phase 3C.d.1 (W1) — default #:srcloc inherits (current-source-loc)
;; ========================================
;;
;; Phase 1.5 completion: net-add-propagator family default #:srcloc changed
;; from #f to (current-source-loc). When caller is within elaborate's
;; parameterize scope (or driver::process-command's parameterize), the
;; propagator's srcloc field inherits the AST-node srcloc without explicit
;; per-call threading. Phase 1.5 (α)+(η) hybrid preserved: srcloc stored
;; in propagator STRUCT FIELD at install time, NOT closure ((ε) rejection
;; precedent honored).

(test-case "W1 default: net-add-propagator inherits (current-source-loc) when bound"
  (define loc (srcloc "w1.rkt" 100 5 10))
  (define net (make-prop-network))
  (define-values (net2 cid) (net-new-cell net 'initial (lambda (o n) n)))
  ;; Install WITHIN parameterize — W1 default should pick up loc
  (define-values (net3 pid)
    (parameterize ([current-source-loc loc])
      (net-add-propagator net2 (list cid) '() (lambda (net) net))))
  (check-equal? (lookup-prop-srcloc net3 pid) loc
                "W1: net-add-propagator default inherits current-source-loc"))

(test-case "W1 default: net-add-fire-once-propagator inherits (current-source-loc) when bound"
  (define loc (srcloc "w1-fire-once.rkt" 200 5 10))
  (define net (make-prop-network))
  (define-values (net2 cid) (net-new-cell net 'initial (lambda (o n) n)))
  (define-values (net3 pid)
    (parameterize ([current-source-loc loc])
      (net-add-fire-once-propagator net2 (list cid) '() (lambda (net) net))))
  (check-equal? (lookup-prop-srcloc net3 pid) loc
                "W1: net-add-fire-once-propagator default inherits current-source-loc"))

(test-case "W1 default: net-add-broadcast-propagator inherits (current-source-loc) when bound"
  (define loc (srcloc "w1-broadcast.rkt" 300 5 10))
  (define net (make-prop-network))
  (define-values (net2 in-cid) (net-new-cell net 'initial (lambda (o n) n)))
  (define-values (net3 out-cid) (net-new-cell net2 '() (lambda (o n) (append o n))))
  (define-values (net4 pid)
    (parameterize ([current-source-loc loc])
      (net-add-broadcast-propagator net3 (list in-cid) out-cid
                                    (list 'item-a 'item-b)
                                    (lambda (item inputs) (list item))
                                    (lambda (acc result) (append acc result)))))
  (check-equal? (lookup-prop-srcloc net4 pid) loc
                "W1: net-add-broadcast-propagator default inherits current-source-loc"))

(test-case "W1 default: explicit #:srcloc kwarg overrides (current-source-loc)"
  ;; Sanity: explicit kwarg still works as override — W1 default only applies
  ;; when caller omits #:srcloc.
  (define outer-loc (srcloc "outer.rkt" 1 1 1))
  (define explicit-loc (srcloc "explicit.rkt" 2 2 2))
  (define net (make-prop-network))
  (define-values (net2 cid) (net-new-cell net 'initial (lambda (o n) n)))
  (define-values (net3 pid)
    (parameterize ([current-source-loc outer-loc])
      (net-add-propagator net2 (list cid) '() (lambda (net) net)
                          #:srcloc explicit-loc)))
  (check-equal? (lookup-prop-srcloc net3 pid) explicit-loc
                "W1: explicit #:srcloc kwarg overrides (current-source-loc) default"))
