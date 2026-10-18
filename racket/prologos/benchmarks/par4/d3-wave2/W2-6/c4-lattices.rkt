#lang racket/base
;; C4 (PAR 4 D.3, SRE lens) — law checks for the lattices D.2 introduces or changes (other than the type merge,
;; which is c4-type-oracle.rkt). Every section has a POWER row: a case the method must flag.
;;   B1  attribute map: is the product E-false through its :type facet alone? (fence granularity, §6.3/§13)
;;   B2  the fence as a monotone map from SRE's 4-valued property lattice (§6.3 "fence is a monotone map")
;;   B3  two-phase worldview (§6.3 row 1): the join, and the derived read live = C ∧ ¬I as a bridge
;;   B4  "fires compute on labelled values" (D2L-1): per-entry lift vs pointwise evaluation on real tagged cells
;;   B5  :usage (§6.3 row 4, D2L-5): chain+⊥ vs flat vs interval, + monotonicity / associativity / fold order
;; Run: ROOT=<racket/prologos> racket c4-lattices.rkt
(require racket/list racket/set racket/string)
(define root (or (getenv "ROOT")
                 "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos"))
(define (p f) (list 'file (string-append root "/" f)))
(define (get f id)
  (with-handlers ([exn:fail? (λ (_) (dynamic-require (p f) #f) (eval id (module->namespace (p f))))])
    (dynamic-require (p f) id)))
(define-syntax-rule (from f id ...) (begin (define id (get f 'id)) ...))
(from "syntax.rkt" expr-Nat expr-Bool expr-Unit expr-Pi expr-meta)
(from "prelude.rkt" mult-add mult-mul mult-meta)
(from "type-lattice.rkt" current-lattice-meta-solution-fn)
(from "typing-propagators.rkt" attribute-map-merge-fn)
(from "classify-inhabit.rkt" classifier-only)
(from "decision-cell.rkt" make-tagged-merge tagged-cell-value tagged-cell-read)
(from "sre-core.rkt" property-value-join prop-unknown prop-confirmed prop-refuted prop-contradicted)

(define (count-pairs U pred) (for*/sum ([x U] [y U]) (if (pred x y) 1 0)))
(define (count-triples U pred) (for*/sum ([x U] [y U] [z U]) (if (pred x y z) 1 0)))
(define (laws name merge U [eqv equal?])
  (printf "  ~a [|U|=~a]: I ~a  C ~a  A ~a  Abs ~a\n" name (length U)
          (for/sum ([x U]) (if (eqv (merge x x) x) 0 1))
          (count-pairs U (λ (x y) (not (eqv (merge x y) (merge y x)))))
          (count-triples U (λ (x y z) (not (eqv (merge (merge x y) z) (merge x (merge y z))))))
          (count-pairs U (λ (x y) (not (eqv (merge x (merge x y)) (merge x y)))))))

;; ===================================================================================================
(printf "B1 attribute-map-merge-fn restricted to the :type facet (one position), exhaustive\n")
(define pm1 (expr-meta 'pm1 #f)) (define pm2 (expr-meta 'pm2 #f))
(define g-atoms (list (expr-Nat) (expr-Bool) (expr-Unit)))
(define m-atoms (append g-atoms (list pm1 pm2)))
(define (types atoms) (append atoms (for*/list ([a atoms] [b atoms]) (expr-Pi 'mw a b))))
(define (attr-maps ts) (cons (hasheq) (for/list ([t ts]) (hasheq 0 (hasheq ':type (classifier-only t))))))
(parameterize ([current-lattice-meta-solution-fn (λ (id) #f)])   ;; production installs a solution fn (driver.rkt:3862)
  (laws "POWER/ground: :type facet, ground classifiers" attribute-map-merge-fn (attr-maps (types g-atoms)))
  (laws "with unsolved metas ?pm1 ?pm2 in classifiers" attribute-map-merge-fn (attr-maps (types m-atoms))))
(newline)

;; ===================================================================================================
(printf "B2 the fence as a map from SRE's property lattice (sre-core.rkt:246-260) to {free < fenced}\n")
(define FOUR (list prop-unknown prop-confirmed prop-refuted prop-contradicted))
(define (leq a b) (eq? (property-value-join a b) b))
(printf "  order (a ⊑ b iff a ⊔ b = b):\n")
(for* ([a FOUR] [b FOUR] #:when (and (leq a b) (not (eq? a b)))) (printf "    ~a ⊑ ~a\n" a b))
(printf "  unknown ⊔ refuted = ~a   (an UNDECLARED merge whose sample fails is refuted, not contradicted)\n"
        (property-value-join prop-unknown prop-refuted))
(define maps (for*/list ([u '(free fenced)] [c '(free fenced)] [r '(free fenced)] [t '(free fenced)])
               (hasheq prop-unknown u prop-confirmed c prop-refuted r prop-contradicted t)))
(define (le2 a b) (or (eq? a b) (and (eq? a 'free) (eq? b 'fenced))))
(define (monotone? f) (for*/and ([a FOUR] [b FOUR] #:when (leq a b)) (le2 (hash-ref f a) (hash-ref f b))))
(define (show-map f) (for/list ([k FOUR]) (list k (hash-ref f k))))
(define mono (filter monotone? maps))
(printf "  monotone maps: ~a of 16\n" (length mono))
(define want (filter (λ (f) (and (eq? (hash-ref f prop-confirmed) 'free) (eq? (hash-ref f prop-contradicted) 'fenced))) mono))
(printf "  monotone with confirmed↦free, contradicted↦fenced: ~a\n" (length want))
(for ([f want]) (printf "    ~s\n" (show-map f)))
(printf "  ... of which fail-closed (unknown↦fenced): ~a\n" (length (filter (λ (f) (eq? (hash-ref f prop-unknown) 'fenced)) want)))
(define d2-literal (hasheq prop-unknown 'free prop-confirmed 'free prop-refuted 'free prop-contradicted 'fenced))
(printf "  D.2 literal \"contradicted ⇒ fenced\": monotone? ~a ; refuted ↦ ~a ; unknown ↦ ~a\n"
        (monotone? d2-literal) (hash-ref d2-literal prop-refuted) (hash-ref d2-literal prop-unknown))
(define fail-closed (hasheq prop-unknown 'fenced prop-confirmed 'free prop-refuted 'fenced prop-contradicted 'fenced))
(printf "  POWER: fail-closed map (fenced unless confirmed) monotone? ~a\n\n" (monotone? fail-closed))

;; ===================================================================================================
(printf "B3 two-phase worldview, 3 assumption bits: x = (C, I), join = (ior, ior)\n")
(define WV (for*/list ([c 8] [i 8]) (cons c i)))
(define (wv-join a b) (cons (bitwise-ior (car a) (car b)) (bitwise-ior (cdr a) (cdr b))))
(define (wv-lww a b) b)
(laws "2P-set join (ior, ior)" wv-join WV)
(laws "POWER: replacement merge on the same carrier" wv-lww WV)
(define (wv-leq a b) (equal? (wv-join a b) b))
(define (live x) (bitwise-and (car x) (bitwise-not (cdr x))))
(define (subset? a b) (= (bitwise-and a b) a))
(printf "  live = C ∧ ¬I: pairs x ⊑ y with live(x) ⊄ live(y) (non-monotone): ~a of ~a ordered pairs\n"
        (count-pairs WV (λ (x y) (and (wv-leq x y) (not (subset? (live x) (live y))))))
        (count-pairs WV (λ (x y) (wv-leq x y))))
(printf "  live(x ⊔ y) ≠ live(x) ∪ live(y) (not join-preserving, so not a Galois left adjoint): ~a of ~a pairs\n"
        (count-pairs WV (λ (x y) (not (= (live (wv-join x y)) (bitwise-ior (live x) (live y))))))
        (* 64 64))
(printf "  POWER: committed-only read C: non-monotone pairs ~a, non-join-preserving ~a\n"
        (count-pairs WV (λ (x y) (and (wv-leq x y) (not (subset? (car x) (car y))))))
        (count-pairs WV (λ (x y) (not (= (car (wv-join x y)) (bitwise-ior (car x) (car y)))))))
;; composed with a REAL tagged-cell read, domain merge = set union (a join)
(define (su a b) (set-union a b))
(define tm (make-tagged-merge su))
(define rng (make-pseudo-random-generator))
(parameterize ([current-pseudo-random-generator rng]) (random-seed 4404))
(define vals (list (seteq) (seteq 'a) (seteq 'b) (seteq 'a 'b)))
(define (rand-tagged)
  (tagged-cell-value (list-ref vals (random 4 rng))
                     (remove-duplicates (for/list ([k (random 4 rng)]) (cons (add1 (random 7 rng)) (list-ref vals (random 4 rng)))))))
(define TS (for/list ([i 300]) (rand-tagged)))
(define (rd t w) (tagged-cell-read t w su))
(define (set->mask s) (+ (if (set-member? s 'a) 1 0) (if (set-member? s 'b) 2 0)))
(define (subset-set? a b) (subset? (set->mask a) (set->mask b)))
(define viol-live
  (for*/sum ([t TS] [x WV] [y WV] #:when (wv-leq x y))
    (if (subset-set? (rd t (live x)) (rd t (live y))) 0 1)))
(define viol-C
  (for*/sum ([t TS] [x WV] [y WV] #:when (wv-leq x y))
    (if (subset-set? (rd t (car x)) (rd t (car y))) 0 1)))
(printf "  REAL tagged-cell-read at W = live(x): monotonicity violations over 300 tagged values × ordered pairs: ~a\n" viol-live)
(printf "  POWER/control: same read at W = C (committed only): ~a\n\n" viol-C)

;; ===================================================================================================
(printf "B4 'fires compute on labelled values' — per-entry lift vs pointwise evaluation (real tagged-cell-read)\n")
;; f monotone on sets: additive (join-preserving) vs non-additive
(define (f-add s) (for/seteq ([x s]) (if (eq? x 'a) 'fa 'fb)))            ;; f(S ∪ T) = f(S) ∪ f(T)
(define (f-both s) (if (and (set-member? s 'a) (set-member? s 'b)) (seteq 'both) (seteq)))   ;; monotone, not additive
(define (lift-entries f t)        ;; label-wise: each entry (b . v) becomes (b . f(v)); base -> f(base)
  (tagged-cell-value (f (tagged-cell-value-base* t)) (for/list ([e (tagged-cell-value-entries* t)]) (cons (car e) (f (cdr e))))))
(from "decision-cell.rkt" tagged-cell-value-base tagged-cell-value-entries)
(define tagged-cell-value-base* tagged-cell-value-base) (define tagged-cell-value-entries* tagged-cell-value-entries)
(define (lift-closure f t)        ;; evaluate f pointwise at every union of entry labels (the ∪-closure)
  (define labels (remove-duplicates (map car (tagged-cell-value-entries t))))
  (define closure (let loop ([acc (list 0)] [ls labels])
                    (if (null? ls) acc (loop (remove-duplicates (append acc (map (λ (w) (bitwise-ior w (car ls))) acc))) (cdr ls)))))
  (tagged-cell-value (f (tagged-cell-value-base t))
                     (for/list ([w closure] #:unless (zero? w)) (cons w (f (rd t w))))))
(define (diff f lift) (for*/sum ([t TS] [w 8]) (if (equal? (rd (lift f t) w) (f (rd t w))) 0 1)))
(printf "  additive f, per-entry lift ≠ pointwise: ~a of ~a (t, W)\n" (diff f-add lift-entries) (* 300 8))
(printf "  non-additive monotone f ('both a and b'), per-entry lift ≠ pointwise: ~a of ~a\n" (diff f-both lift-entries) (* 300 8))
(printf "  non-additive f, lift evaluated on the ∪-closure of labels ≠ pointwise: ~a of ~a\n"
        (diff f-both lift-closure) (* 300 8))
(let ([t (tagged-cell-value (seteq) (list (cons 1 (seteq 'a)) (cons 2 (seteq 'b))))])
  (printf "  witness: entries {1:{a}, 2:{b}}; at W=3 pointwise f = ~s, per-entry lift = ~s\n\n"
          (f-both (rd t 3)) (rd (lift-entries f-both t) 3)))

;; ===================================================================================================
(printf "B5 :usage — candidate orders for one usage coordinate\n")
(define Q '(bot m0 m1 mw))
(define (qrank x) (case x [(bot) 0] [(m0) 1] [(m1) 2] [(mw) 3]))
(define (chain<= a b) (<= (qrank a) (qrank b)))
(define (flat<= a b) (or (eq? a 'bot) (eq? a b)))
(define (addS a b) (if (or (eq? a 'bot) (eq? b 'bot)) 'bot (mult-add a b)))                      ;; ⊥ strict
(define (addW a b) (cond [(or (eq? a 'mw) (eq? b 'mw)) 'mw] [(or (eq? a 'bot) (eq? b 'bot)) 'bot] [else (mult-add a b)])) ;; ω absorbs ⊥
(define (mulS a b) (cond [(or (eq? a 'm0) (eq? b 'm0)) 'm0] [(or (eq? a 'bot) (eq? b 'bot)) 'bot] [else (mult-mul a b)]))
(define (mono2? op le) (for*/and ([a Q] [a2 Q] [b Q] [b2 Q] #:when (and (le a a2) (le b b2))) (le (op a b) (op a2 b2))))
(define (assoc-viol op) (count-triples Q (λ (x y z) (not (eq? (op (op x y) z) (op x (op y z)))))))
(define (comm-viol op) (count-pairs Q (λ (x y) (not (eq? (op x y) (op y x))))))
(for ([row (list (list "addS (⊥ strict)" addS) (list "addW (ω absorbs ⊥)" addW) (list "mulS (0 absorbs ⊥)" mulS))])
  (printf "  ~a: monotone(chain) ~a  monotone(flat) ~a  C ~a  A ~a\n" (car row)
          (mono2? (cadr row) chain<=) (mono2? (cadr row) flat<=) (comm-viol (cadr row)) (assoc-viol (cadr row))))
(printf "    addW witness: (⊥+m1)+m1 = ~a  vs  ⊥+(m1+m1) = ~a\n" (addW (addW 'bot 'm1) 'm1) (addW 'bot (addW 'm1 'm1)))
;; fold order dependence (arity >= 3, typing-propagators.rkt:1796 foldl add-usage)
(define (fold-perm-dep op n)
  (for/sum ([xs (in-list (let loop ([k n]) (if (zero? k) '(()) (for*/list ([r (loop (sub1 k))] [q Q]) (cons q r)))))])
    (if (= 1 (length (remove-duplicates (for/list ([pp (permutations xs)]) (foldl op (car pp) (cdr pp)))))) 0 1)))
(printf "  arity-3 child vectors whose foldl total depends on child order: addS ~a, addW ~a (of 64)\n"
        (fold-perm-dep addS 3) (fold-perm-dep addW 3))
(printf "  max as merge on the chain: ~a\n" (let ([mx (λ (a b) (if (chain<= a b) b a))]) (format "C ~a A ~a" (comm-viol mx) (assoc-viol mx))))
;; interval lattice over the quantity chain m0 < m1 < mw; unknown = [m0, mw]; info order = reverse inclusion
(define M '(m0 m1 mw))
(define (r x) (qrank x))
(define IV (cons 'itop (for*/list ([lo M] [hi M] #:when (<= (r lo) (r hi))) (cons lo hi))))
(define (iv-join a b) (cond [(or (eq? a 'itop) (eq? b 'itop)) 'itop]
                            [else (let ([lo (if (>= (r (car a)) (r (car b))) (car a) (car b))]
                                        [hi (if (<= (r (cdr a)) (r (cdr b))) (cdr a) (cdr b))])
                                    (if (<= (r lo) (r hi)) (cons lo hi) 'itop))]))
(define (iv-leq a b) (equal? (iv-join a b) b))
(define (iv-op op) (λ (a b) (if (or (eq? a 'itop) (eq? b 'itop)) 'itop (cons (op (car a) (car b)) (op (cdr a) (cdr b))))))
(define iadd (iv-op mult-add)) (define imul (iv-op mult-mul))
(laws "interval join (max lo, min hi)" iv-join IV)
(laws "POWER: mult-add as a merge (the semiring +, today's :usage facet-merge)" mult-add M eq?)
(define (iv-mono2? op) (for*/and ([a IV] [a2 IV] [b IV] [b2 IV] #:when (and (iv-leq a a2) (iv-leq b b2))) (iv-leq (op a b) (op a2 b2))))
(printf "  interval add: monotone ~a  C ~a  A ~a ; interval mul: monotone ~a\n" (iv-mono2? iadd)
        (count-pairs IV (λ (x y) (not (equal? (iadd x y) (iadd y x)))))
        (count-triples IV (λ (x y z) (not (equal? (iadd (iadd x y) z) (iadd x (iadd y z))))))
        (iv-mono2? imul))
(define unknown (cons 'm0 'mw))
(printf "  example: usage m1 + unknown·m1  = chain ~a ; interval ~s  (declared m0 can already be rejected: lo = m1)\n"
        (addS 'm1 (mulS 'bot 'm1)) (iadd (cons 'm1 'm1) (imul unknown (cons 'm1 'm1))))
(printf "  today (prelude.rkt:37, typing-propagators.rkt:1699): m1 + mw·m1 = ~a ; mult-add(m1, ?meta) = ~a\n"
        (mult-add 'm1 (mult-mul 'mw 'm1)) (mult-add 'm1 (mult-meta 'q)))
