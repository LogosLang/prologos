#lang racket/base
;; C4 (PAR 4 D.3, SRE lens) — the tagged-cell READER vs the tagged-cell MERGE order.
;; D.2 §6.3 row 3: "an order-independent read needs an ACI domain merge" (and the merge-laws note §1 states the
;; denotation as  [[t]](W) = base ⊔ ⊔{v | (b,v) ∈ t, b ⊆ W}).  The production reader, tagged-cell-read
;; (decision-cell.rkt:452-477), returns the base ONLY when no entry matches; once an entry matches it returns the
;; join of the matching entries WITHOUT the base. Writes under a worldview store the fire's written value (a delta,
;; e.g. that-write's one-position map, typing-propagators.rkt:580) as the entry (propagator.rkt:2019-2024).
;; Question: is the read monotone in the cell's own order (make-tagged-merge), and in W?
;; Run: ROOT=<racket/prologos> racket c4-tagged-reader.rkt
(require racket/set racket/list)
(define root (or (getenv "ROOT")
                 "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos"))
(define (p f) (list 'file (string-append root "/" f)))
(define (get f id)
  (with-handlers ([exn:fail? (λ (_) (dynamic-require (p f) #f) (eval id (module->namespace (p f))))])
    (dynamic-require (p f) id)))
(define-syntax-rule (from f id ...) (begin (define id (get f 'id)) ...))
(from "propagator.rkt" make-prop-network net-new-cell net-cell-write net-cell-read promote-cell-to-tagged
      current-worldview-bitmask)
(from "decision-cell.rkt" make-tagged-merge tagged-cell-value tagged-cell-read tagged-cell-value-base
      tagged-cell-value-entries scope-cell scope-cell-merge scope-cell-ref)
(from "typing-propagators.rkt" attribute-map-merge-fn that-write that-read)
(from "syntax.rkt" expr-Nat expr-Bool expr-Unit)

;; ---- 1. the attribute map on a real network (union-fork path promotes it: typing-propagators.rkt:1211) -----
(printf "1. attribute map, real network\n")
(define-values (n0 tm) (net-new-cell (make-prop-network) (hasheq) attribute-map-merge-fn))
(define n1 (that-write (that-write n0 tm 0 ':type (expr-Nat)) tm 1 ':type (expr-Bool)))   ;; unconditional
(define n2 (promote-cell-to-tagged n1 tm))
(define (rd-pos n pos w) (parameterize ([current-worldview-bitmask w]) (that-read (net-cell-read n tm) pos ':type)))
(printf "  before any branch write, read at W=1: pos0 :type = ~s, pos1 :type = ~s\n" (rd-pos n2 0 1) (rd-pos n2 1 1))
(define n3 (parameterize ([current-worldview-bitmask 1]) (that-write n2 tm 2 ':type (expr-Unit))))  ;; branch write
(printf "  after a branch write at pos2 under W=1, read at W=1: pos0 :type = ~s, pos1 :type = ~s, pos2 :type = ~s\n"
        (rd-pos n3 0 1) (rd-pos n3 1 1) (rd-pos n3 2 1))
(printf "  same cell read at W=0: pos0 :type = ~s\n" (rd-pos n3 0 0))

;; ---- 2. a scope cell (relations: promoted at NAF/guard/clause sites; logic-var-write writes a one-var delta) ---
(printf "2. scope cell, real network\n")
(define-values (s0 sc) (net-new-cell (make-prop-network) (scope-cell (hasheq)) scope-cell-merge))
(define s1 (net-cell-write s0 sc (scope-cell (hasheq 'X 'a))))
(define s2 (promote-cell-to-tagged s1 sc))
(define s3 (parameterize ([current-worldview-bitmask 1]) (net-cell-write s2 sc (scope-cell (hasheq 'Y 'b)))))
(define (rd-var n v w) (parameterize ([current-worldview-bitmask w]) (scope-cell-ref (net-cell-read n sc) v)))
(printf "  X at W=1 before the branch write: ~s ; after binding Y=b under W=1: X = ~s, Y = ~s\n"
        (rd-var s2 'X 1) (rd-var s3 'X 1) (rd-var s3 'Y 1))

;; ---- 3. counts on a join domain (set union) -----------------------------------------------------------------
(printf "3. domain = set union (a join); 3 assumption bits; 400 random tagged values\n")
(define su set-union)
(define tm-merge (make-tagged-merge su))
(define rng (make-pseudo-random-generator))
(parameterize ([current-pseudo-random-generator rng]) (random-seed 4404))
(define vals (list (seteq) (seteq 'a) (seteq 'b) (seteq 'c) (seteq 'a 'b)))
(define (rand-t)
  (tagged-cell-value (list-ref vals (random 5 rng))
                     (remove-duplicates (for/list ([k (random 3 rng)]) (cons (add1 (random 7 rng)) (list-ref vals (random 5 rng)))))))
(define TS (for/list ([i 400]) (rand-t)))
(define (rd t w) (tagged-cell-read t w su))
(define (rd-fixed t w)  ;; the denotation the note states: base ⊔ ⊔ matching
  (for/fold ([acc (tagged-cell-value-base t)]) ([e (tagged-cell-value-entries t)] #:when (= (bitwise-and (car e) w) (car e)))
    (su acc (cdr e))))
(define (sub? a b) (subset? a b))
(define (den reader t) (for/list ([w 8]) (reader t w)))
(define pairs (for*/list ([i 400] [j 3]) (cons (list-ref TS i) (list-ref TS (random 400 rng)))))
(for ([row (list (list "production tagged-cell-read" rd) (list "base ⊔ matching (the note's denotation)" rd-fixed))])
  (define reader (cadr row))
  (define t-viol (for*/sum ([pr pairs] [w 8])
                   (define t (car pr)) (define u (tm-merge (car pr) (cdr pr)))   ;; t ⊑ u in the merge order
                   (if (sub? (reader t w) (reader u w)) 0 1)))
  (define w-viol (for*/sum ([t TS] [w 8] [w2 8] #:when (= (bitwise-and w w2) w)) (if (sub? (reader t w) (reader t w2)) 0 1)))
  (define c-viol (for/sum ([pr pairs]) (if (equal? (den reader (tm-merge (car pr) (cdr pr))) (den reader (tm-merge (cdr pr) (car pr)))) 0 1)))
  (printf "  ~a: non-monotone in t (t ⊑ t⊔s): ~a/~a ; non-monotone in W: ~a/~a ; outer merge C on denotations: ~a/~a\n"
          (car row) t-viol (* 8 (length pairs)) w-viol (* 400 27) c-viol (length pairs)))
(define t0 (tagged-cell-value (seteq 'a) '()))
(define u0 (tm-merge t0 (tagged-cell-value (seteq) (list (cons 1 (seteq 'b))))))
(printf "  witness: t = {base {a}}, u = t ⊔ {1:{b}}; read at W=1: t -> ~s, u -> ~s\n" (rd t0 1) (rd u0 1))
