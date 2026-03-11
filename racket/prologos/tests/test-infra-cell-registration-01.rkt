#lang racket/base

;;;
;;; test-infra-cell-registration-01.rkt — Registration protocol + elab-network coexistence
;;;
;;; Phase 0c of the Propagator-First Migration Sprint.
;;; Validates that infrastructure cells and elaboration cells coexist
;;; in the same prop-network.
;;;

(require rackunit
         racket/set
         racket/list
         racket/string
         "../propagator.rkt"
         "../champ.rkt"
         "../infra-cell.rkt"
         "../elaborator-network.rkt"
         "../type-lattice.rkt"
         "../syntax.rkt")

;; ========================================
;; Registration Protocol Pattern
;; ========================================

;; Simulate what modules will do in Phases 1-3: register their own cells.

;; Mock macros.rkt registration: creates registry cells for impl, trait, schema
(define (register-macros-cells net names)
  (define-values (net1 impl-cid) (net-new-registry-cell net))
  (define-values (net2 names1) (net-register-named-cell net1 names 'impl-registry impl-cid))
  (define-values (net3 trait-cid) (net-new-registry-cell net2))
  (define-values (net4 names2) (net-register-named-cell net3 names1 'trait-registry trait-cid))
  (define-values (net5 schema-cid) (net-new-registry-cell net4))
  (define-values (net6 names3) (net-register-named-cell net5 names2 'schema-registry schema-cid))
  (values net6 names3))

;; Mock warnings.rkt registration: creates list cells for warnings
(define (register-warning-cells net names)
  (define-values (net1 coercion-cid) (net-new-list-cell net))
  (define-values (net2 names1) (net-register-named-cell net1 names 'coercion-warnings coercion-cid))
  (define-values (net3 depr-cid) (net-new-list-cell net2))
  (define-values (net4 names2) (net-register-named-cell net3 names1 'deprecation-warnings depr-cid))
  (values net4 names2))

;; Mock metavar-store.rkt registration: constraint store
(define (register-constraint-cells net names)
  (define-values (net1 cstore-cid) (net-new-list-cell net))
  (define-values (net2 names1) (net-register-named-cell net1 names 'constraint-store cstore-cid))
  (values net2 names1))

(test-case "registration protocol: modules register in dependency order"
  (define net0 (make-prop-network))
  (define names0 (hasheq))
  ;; Register in sequence (simulates driver startup)
  (define-values (net1 names1) (register-macros-cells net0 names0))
  (define-values (net2 names2) (register-warning-cells net1 names1))
  (define-values (net3 names3) (register-constraint-cells net2 names2))
  ;; All 6 cells accessible
  (check-true (net-has-named-cell? names3 'impl-registry))
  (check-true (net-has-named-cell? names3 'trait-registry))
  (check-true (net-has-named-cell? names3 'schema-registry))
  (check-true (net-has-named-cell? names3 'coercion-warnings))
  (check-true (net-has-named-cell? names3 'deprecation-warnings))
  (check-true (net-has-named-cell? names3 'constraint-store))
  ;; Write and read through named cells
  (define net4 (net-cell-write net3 (net-named-cell-ref names3 'impl-registry)
                               (hasheq 'Nat-Add 'nat-add-fn)))
  (define net5 (net-cell-write net4 (net-named-cell-ref names3 'coercion-warnings)
                               '("implicit Nat->Int coercion")))
  (check-equal? (hash-ref (net-cell-read net5 (net-named-cell-ref names3 'impl-registry)) 'Nat-Add) 'nat-add-fn)
  (check-equal? (net-cell-read net5 (net-named-cell-ref names3 'coercion-warnings))
                '("implicit Nat->Int coercion")))

(test-case "registration protocol: duplicate name errors"
  (define net0 (make-prop-network))
  (define names0 (hasheq))
  (define-values (net1 names1) (register-macros-cells net0 names0))
  ;; Trying to register macros again should error (duplicate names)
  (check-exn exn:fail?
    (lambda () (register-macros-cells net1 names1))))

;; ========================================
;; Unified Network: Infra-Cells + Elab-Network Coexistence
;; ========================================

(test-case "infra-cells and elab-network share the same prop-network"
  ;; 1. Start with a prop-network, add infra-cells
  (define net0 (make-prop-network))
  (define-values (net1 impl-cid) (net-new-registry-cell net0))
  (define names0 (hasheq))
  (define-values (net2 names1) (net-register-named-cell net1 names0 'impl-registry impl-cid))
  ;; Write to infra-cell
  (define net3 (net-cell-write net2 impl-cid (hasheq 'Nat-Eq 'eq-fn)))
  ;; 2. Create elab-network wrapping the SAME prop-network
  (define enet0 (elab-network net3 champ-empty 0))
  ;; 3. Create a metavariable cell in the elab-network
  (define-values (enet1 meta-cid) (elab-fresh-meta enet0 '() type-top "test-meta"))
  ;; 4. The elab-network's underlying prop-network has BOTH cells
  (define inner-net (elab-network-prop-net enet1))
  ;; Infra-cell still readable
  (check-equal? (hash-ref (net-cell-read inner-net impl-cid) 'Nat-Eq) 'eq-fn)
  ;; Meta cell readable
  (check-equal? (net-cell-read inner-net meta-cid) type-bot)
  ;; 5. Write to meta cell through elab-network
  (define enet2 (elab-cell-write enet1 meta-cid (expr-Nat)))
  ;; 6. Both still accessible
  (define inner-net2 (elab-network-prop-net enet2))
  (check-equal? (hash-ref (net-cell-read inner-net2 impl-cid) 'Nat-Eq) 'eq-fn)
  (check-not-equal? (net-cell-read inner-net2 meta-cid) type-bot))

(test-case "propagator between infra-cell and elab-cell fires correctly"
  ;; Create infra-cell
  (define net0 (make-prop-network))
  (define-values (net1 log-cid) (net-new-list-cell net0))
  ;; Create elab-network on top
  (define enet0 (elab-network net1 champ-empty 0))
  ;; Create meta cell
  (define-values (enet1 meta-cid) (elab-fresh-meta enet0 '() type-top "test"))
  ;; Add propagator: when meta cell changes, log it
  (define inner-net (elab-network-prop-net enet1))
  (define-values (inner-net2 _pid)
    (net-add-propagator inner-net (list meta-cid) (list log-cid)
      (lambda (net)
        (define val (net-cell-read net meta-cid))
        (if (equal? val type-bot)
            net
            (net-cell-write net log-cid (list (format "meta solved to: ~a" val)))))))
  ;; Update elab-network with the new propagator
  (define enet2
    (struct-copy elab-network enet1 [prop-net inner-net2]))
  ;; Write to meta cell — should trigger propagator
  (define enet3 (elab-cell-write enet2 meta-cid (expr-Nat)))
  ;; Run to quiescence
  (define inner-net3 (run-to-quiescence (elab-network-prop-net enet3)))
  ;; Log cell should have an entry
  (define logs (net-cell-read inner-net3 log-cid))
  (check-true (pair? logs)))

;; ========================================
;; Full Registration + Propagation End-to-End
;; ========================================

(test-case "end-to-end: registration, infra write, propagation across cell types"
  ;; 1. Create network with infra-cells
  (define net0 (make-prop-network))
  (define-values (net1 impl-cid) (net-new-registry-cell net0))
  (define-values (net2 notif-cid) (net-new-list-cell net1))
  (define names0 (hasheq))
  (define-values (net3 names1) (net-register-named-cell net2 names0 'impl-registry impl-cid))
  (define-values (net4 names2) (net-register-named-cell net3 names1 'notifications notif-cid))
  ;; 2. Add cross-cell propagator: impl-registry change → notification
  (define-values (net5 _pid)
    (net-add-propagator net4 (list impl-cid) (list notif-cid)
      (lambda (net)
        (define impls (net-cell-read net impl-cid))
        (define count (hash-count impls))
        (if (zero? count)
            net
            (net-cell-write net notif-cid
                            (list (format "~a impls registered" count)))))))
  ;; 3. Create elab-network on top
  (define enet0 (elab-network net5 champ-empty 0))
  ;; 4. Write to infra-cell through the underlying network
  (define enet1
    (struct-copy elab-network enet0
      [prop-net (net-cell-write (elab-network-prop-net enet0)
                                impl-cid
                                (hasheq 'List-Eq 'list-eq-fn))]))
  ;; 5. Run to quiescence
  (define enet2
    (struct-copy elab-network enet1
      [prop-net (run-to-quiescence (elab-network-prop-net enet1))]))
  ;; 6. Read notifications
  (define inner (elab-network-prop-net enet2))
  (define notifs (net-cell-read inner notif-cid))
  (check-true (pair? notifs))
  (check-true (string-contains? (car notifs) "1 impls registered")))

;; ========================================
;; Cell ID Namespace Safety
;; ========================================

(test-case "infra-cells and elab-cells get distinct cell-ids"
  (define net0 (make-prop-network))
  ;; Create 3 infra-cells
  (define-values (net1 cid1) (net-new-registry-cell net0))
  (define-values (net2 cid2) (net-new-list-cell net1))
  (define-values (net3 cid3) (net-new-set-cell net2))
  ;; Create elab-network on top
  (define enet0 (elab-network net3 champ-empty 0))
  ;; Create 2 meta cells
  (define-values (enet1 mcid1) (elab-fresh-meta enet0 '() type-top "m1"))
  (define-values (enet2 mcid2) (elab-fresh-meta enet1 '() type-top "m2"))
  ;; All 5 cell-ids should be distinct
  (define all-ids (list cid1 cid2 cid3 mcid1 mcid2))
  (check-equal? (length (remove-duplicates all-ids)) 5))

