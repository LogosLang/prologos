#lang racket/base
;; C1 probe (D.3 wave 1): does a merge's property identity survive installation?
;; D.2 §6.3: "Properties attach to the merge installed on the cell ... E is evaluated once per
;; merge function, not per cell"; the fence is "a monotone map from a merge's property cell".
;; Question: for a cell promoted to tagged (the production path, relations.rkt / typing-propagators.rkt),
;; is the installed merge a registered function object, and is it shared across cells?
(define W "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/")
(require racket/set (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/propagator.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/champ.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/infra-cell.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/infra-cell-sre-registrations.rkt")
         (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/merge-fn-registry.rkt"))

(define (installed-merge net cid)
  (champ-lookup (prop-network-merge-fns net) (cell-id-hash cid) cid))

(define net0 (make-prop-network))
(define-values (net1 c1) (net-new-cell net0 (seteq) merge-set-union))
(define-values (net2 c2) (net-new-cell net1 (seteq) merge-set-union))

(printf "registry size at load: ~a\n" (merge-fn-registry-size))
;; power row: the registry must find a registered merge
(printf "POWER lookup-merge-fn-domain merge-set-union = ~a (expect monotone-set)\n"
        (lookup-merge-fn-domain merge-set-union))
(printf "before promotion: installed merge of c1 eq? merge-set-union = ~a ; domain = ~a ; cell-domain = ~a\n"
        (eq? (installed-merge net2 c1) merge-set-union)
        (lookup-merge-fn-domain (installed-merge net2 c1))
        (lookup-cell-domain net2 c1))

(define net3 (promote-cell-to-tagged net2 c1))
(define net4 (promote-cell-to-tagged net3 c2))
(define m1 (installed-merge net4 c1))
(define m2 (installed-merge net4 c2))
(printf "after promotion: installed merge of c1 registered domain = ~a (#f = unknown to the eq?-keyed registry)\n"
        (lookup-merge-fn-domain m1))
(printf "after promotion: cell-domain of c1 (Tier 3 record) = ~a\n" (lookup-cell-domain net4 c1))
(printf "after promotion: c1's merge eq? c2's merge = ~a (two cells, same domain merge)\n" (eq? m1 m2))
(printf "after promotion: c1's merge eq? merge-set-union = ~a\n" (eq? m1 merge-set-union))
