#lang racket/base
;; C4 (PAR 4 D.3, SRE lens) — the type merge split of D.2 §6.3 row 8 / O-12, tested against an ORACLE.
;;
;; Question: D.2 splits F3(b) into (i) clash ("rigid heads differ") => top, and (ii) blocked => a residual
;; element. Which pairs that reach today's fallback arm are genuinely BLOCKED (some solution of the unsolved
;; metas unifies them) and which are CLASHES (no solution does)?  And does each proposed variant become a
;; join / inflationary on samples with power?  (D.2 §9 Obs 2(a) CONJECTURE: "the clash => top half makes
;; type-unify-or-top inflationary".)
;;
;; ORACLE: x, y unifiable  <=>  exists sigma : {pm1,pm2,mm1} -> ground, such that the GROUND terms x.sigma and
;; y.sigma (unions re-canonicalised with build-union-type) unify under try-unify-pure with no metas at all.
;; (M1: ground types are clean on every law, so the ground path is a trustworthy judge.)
;;
;; Free parameters: atoms {Nat,Bool,Unit,?pm1,?pm2,?pm3(:=Nat)}; Pi over atom pairs with mult 'mw, plus Pi with an
;; unsolved MULT-meta ?mm1 over ground atom pairs; union over atom pairs; type-bot/type-top.
;; Ground substitution range G = {Nat, Bool, Unit, Pi(Nat,Nat)} for pm1/pm2 and {m0,m1,mw} for mm1.
;; Exhaustive over all ordered pairs; associativity on NA random triples (env NA, default 20000).
;; Run: ROOT=<racket/prologos> racket c4-type-oracle.rkt
(require racket/list racket/string)
(define root (or (getenv "ROOT")
                 "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos"))
(define (p f) (list 'file (string-append root "/" f)))
(define (get f id)
  (with-handlers ([exn:fail? (λ (_) (dynamic-require (p f) #f) (eval id (module->namespace (p f))))])
    (dynamic-require (p f) id)))
(define-syntax-rule (from f id ...) (begin (define id (get f 'id)) ...))
(from "syntax.rkt" expr-Nat expr-Bool expr-Unit expr-Pi expr-union expr-meta expr-meta? expr-meta-id
      expr-Pi? expr-Pi-mult expr-Pi-domain expr-Pi-codomain expr-union? expr-union-left expr-union-right)
(from "prelude.rkt" mult-meta mult-meta? mult-meta-id)
(from "type-lattice.rkt" type-unify-or-top type-lattice-merge try-unify-pure current-lattice-meta-solution-fn
      type-top? type-bot?)
(from "union-types.rkt" build-union-type flatten-union)

(define NA (string->number (or (getenv "NA") "20000")))
(define rng (make-pseudo-random-generator))
(parameterize ([current-pseudo-random-generator rng]) (random-seed 4404))

(define pm1 (expr-meta 'pm1 #f)) (define pm2 (expr-meta 'pm2 #f)) (define pm3 (expr-meta 'pm3 #f))
(define mm1 (mult-meta 'mm1))
(define (sol0 id) (and (eq? id 'pm3) (expr-Nat)))          ;; the probe environment: pm3 := Nat
(define (with-sol f thunk) (parameterize ([current-lattice-meta-solution-fn f]) (thunk)))

(define ground-atoms (list (expr-Nat) (expr-Bool) (expr-Unit)))
(define atoms (append ground-atoms (list pm1 pm2 pm3)))
(define universe
  (append (list 'type-bot 'type-top) atoms
          (for*/list ([a atoms] [b atoms]) (expr-Pi 'mw a b))
          (for*/list ([a ground-atoms] [b ground-atoms]) (expr-Pi mm1 a b))
          (for*/list ([a atoms] [b atoms] #:unless (equal? a b)) (build-union-type (list a b)))))
(define ground-universe
  (append (list 'type-bot 'type-top) ground-atoms
          (for*/list ([a ground-atoms] [b ground-atoms]) (expr-Pi 'mw a b))
          (for*/list ([a ground-atoms] [b ground-atoms] #:unless (equal? a b)) (build-union-type (list a b)))))

;; ---- substitution / zonk --------------------------------------------------------------------------
(define (subst t s mult-s)
  (cond [(symbol? t) t]
        [(expr-meta? t) (or (s (expr-meta-id t)) t)]
        [(expr-Pi? t) (expr-Pi (let ([m (expr-Pi-mult t)]) (if (mult-meta? m) (or (mult-s (mult-meta-id m)) m) m))
                               (subst (expr-Pi-domain t) s mult-s) (subst (expr-Pi-codomain t) s mult-s))]
        [(expr-union? t) (build-union-type (map (λ (c) (subst c s mult-s)) (flatten-union t)))]
        [else t]))
(define (zonk t) (subst t sol0 (λ (_) #f)))
(define (eqz a b) (equal? (zonk a) (zonk b)))

;; ---- oracle ------------------------------------------------------------------------------------------
;; G = every non-sentinel GROUND term of the ground universe (atoms, Pi over atoms, unions of atoms), so a bare
;; meta can be solved by a union too. Only the metas that occur are enumerated.
(define G-cache (make-hash))
(define (occurs? id t)
  (cond [(symbol? t) #f]
        [(expr-meta? t) (eq? (expr-meta-id t) id)]
        [(expr-Pi? t) (or (and (eq? id 'mm1) (mult-meta? (expr-Pi-mult t))) (occurs? id (expr-Pi-domain t)) (occurs? id (expr-Pi-codomain t)))]
        [(expr-union? t) (or (occurs? id (expr-union-left t)) (occurs? id (expr-union-right t)))]
        [else #f]))
(define (unifiable? x y)
  (hash-ref! G-cache (cons x y)
   (λ ()
    (cond [(or (eq? x 'type-top) (eq? y 'type-top)) #f]
          [(or (eq? x 'type-bot) (eq? y 'type-bot)) #t]
          [else
           (define G* (filter (λ (t) (not (symbol? t))) ground-universe))
           (define (dom id) (if (or (occurs? id x) (occurs? id y)) (if (eq? id 'mm1) '(m0 m1 mw) G*) (list #f)))
           (for*/or ([g1 (dom 'pm1)] [g2 (dom 'pm2)] [mu (dom 'mm1)])
             (define s (λ (id) (case id [(pm1) g1] [(pm2) g2] [(pm3) (expr-Nat)] [else #f])))
             (define xs (subst x s (λ (_) mu))) (define ys (subst y s (λ (_) mu)))
             (define r (with-sol (λ (_) #f) (λ () (try-unify-pure xs ys))))
             (and r (not (eq? r 'type-top))))]))))

;; ---- variants -------------------------------------------------------------------------------------
(define (head t)
  (cond [(symbol? t) t]
        [(and (expr-meta? t) (sol0 (expr-meta-id t))) => head]
        [(expr-meta? t) 'meta]
        [else (vector-ref (struct->vector t) 0)]))
(define (has-unsolved? t)
  (cond [(symbol? t) #f]
        [(expr-meta? t) (not (sol0 (expr-meta-id t)))]
        [(expr-Pi? t) (or (mult-meta? (expr-Pi-mult t)) (has-unsolved? (expr-Pi-domain t)) (has-unsolved? (expr-Pi-codomain t)))]
        [(expr-union? t) (or (has-unsolved? (expr-union-left t)) (has-unsolved? (expr-union-right t)))]
        [else #f]))
;; which arm of type-unify-or-top a pair takes (under sol0)
(define (arm x y)
  (cond [(or (type-bot? x) (type-bot? y) (type-top? x) (type-top? y) (eq? x y) (equal? x y)) 'trivial]
        [(with-sol sol0 (λ () (try-unify-pure x y))) 'unify-success]
        [(or (has-unsolved? x) (has-unsolved? y)) 'fallback]
        [else 'ground-clash]))
(define (V0 x y) (with-sol sol0 (λ () (type-unify-or-top x y))))                 ;; today
(define (V1 x y)                                                                 ;; D.2 literal: heads differ => top
  (if (and (eq? (arm x y) 'fallback)
           (not (memq (head x) '(meta))) (not (memq (head y) '(meta)))
           (not (eq? (head x) (head y))))
      'type-top (V0 x y)))
(define (V2 x y) (if (eq? (arm x y) 'fallback) 'type-top (V0 x y)))             ;; fallback deleted
(define (residual-shape? x y)                                                    ;; mult-meta or union involved
  (or (and (expr-Pi? x) (mult-meta? (expr-Pi-mult x))) (and (expr-Pi? y) (mult-meta? (expr-Pi-mult y)))
      (expr-union? x) (expr-union? y)))
(define (V3 x y) (if (and (eq? (arm x y) 'fallback) (not (residual-shape? x y))) 'type-top (V0 x y)))
(define (union-with-meta? t)
  (cond [(symbol? t) #f]
        [(expr-union? t) (has-unsolved? t)]
        [(expr-Pi? t) (or (union-with-meta? (expr-Pi-domain t)) (union-with-meta? (expr-Pi-codomain t)))]
        [else #f]))
(define (mult-meta-in? t)
  (cond [(symbol? t) #f]
        [(expr-Pi? t) (or (mult-meta? (expr-Pi-mult t)) (mult-meta-in? (expr-Pi-domain t)) (mult-meta-in? (expr-Pi-codomain t)))]
        [(expr-union? t) (or (mult-meta-in? (expr-union-left t)) (mult-meta-in? (expr-union-right t)))]
        [else #f]))
(define (V4 x y)   ;; fallback => top unless the pair can be genuinely blocked: an unsolved mult-meta, or a union holding a meta
  (if (and (eq? (arm x y) 'fallback)
           (not (or (mult-meta-in? x) (mult-meta-in? y) (union-with-meta? x) (union-with-meta? y))))
      'type-top (V0 x y)))
(define (VA0 x y) (with-sol sol0 (λ () (type-lattice-merge x y))))              ;; Role A today
;; V5: (i) an unsolved mult-meta is a wildcard like a type meta (top-level Pi only, which is where the universe
;; has them); (ii) a pair holding a meta-carrying union keeps today's fallback (its residual is a disjunction);
;; (iii) every other fallback hit => top.
(define (mult-wild x y)
  (if (and (expr-Pi? x) (expr-Pi? y))
      (let ([mx (expr-Pi-mult x)] [my (expr-Pi-mult y)])
        (cond [(and (mult-meta? mx) (not (mult-meta? my))) (values (expr-Pi my (expr-Pi-domain x) (expr-Pi-codomain x)) y)]
              [(and (mult-meta? my) (not (mult-meta? mx))) (values x (expr-Pi mx (expr-Pi-domain y) (expr-Pi-codomain y)))]
              [else (values x y)]))
      (values x y)))
(define (V5 x0 y0)
  (define-values (x y) (mult-wild x0 y0))
  (if (and (eq? (arm x y) 'fallback) (not (or (union-with-meta? x) (union-with-meta? y))))
      'type-top (V0 x y)))
(define (VA1 x y)                                                                ;; Role A: blocked => union
  (if (and (eq? (arm x y) 'fallback))
      (with-sol sol0 (λ () (build-union-type (list (zonk x) (zonk y)))))
      (VA0 x y)))

(define (try thunk) (with-handlers ([exn:fail? (λ (e) (list 'RAISED (car (string-split (exn-message e) "\n"))))]) (thunk)))
(define (show-term t) (format "~s" t))

(define (report name merge U)
  (define pairs (for*/list ([x U] [y U]) (cons x y)))
  (define erased '()) (define false-top '()) (define cviol '()) (define inflv '())
  (for ([pr pairs])
    (define x (car pr)) (define y (cdr pr))
    (define r (try (λ () (merge x y))))
    (define u? (unifiable? x y))
    (when (and (not u?) (not (eq? r 'type-top))) (set! erased (cons pr erased)))
    (when (and u? (eq? r 'type-top)) (set! false-top (cons pr false-top)))
    (unless (eqz r (try (λ () (merge y x)))) (set! cviol (cons pr cviol)))
    (unless (and (eqz (try (λ () (merge r x))) r) (eqz (try (λ () (merge r y))) r)) (set! inflv (cons pr inflv))))
  (define vec (list->vector U))
  (define aviol
    (for/sum ([i NA])
      (define x (vector-ref vec (random (vector-length vec) rng)))
      (define y (vector-ref vec (random (vector-length vec) rng)))
      (define z (vector-ref vec (random (vector-length vec) rng)))
      (if (eqz (try (λ () (merge (merge x y) z))) (try (λ () (merge x (merge y z))))) 0 1)))
  (define (eg l) (if (null? l) "" (let ([s (argmin (λ (pr) (string-length (show-term pr))) l)])
                                    (format "  e.g. x=~a y=~a -> ~a" (show-term (car s)) (show-term (cdr s))
                                            (show-term (try (λ () (merge (car s) (cdr s)))))))))
  (printf "~a  [~a pairs]\n" name (length pairs))
  (printf "  erased contradictions (oracle: NOT unifiable, result != top): ~a~a\n" (length erased) (eg erased))
  (printf "  false contradictions  (oracle: unifiable, result = top)      : ~a~a\n" (length false-top) (eg false-top))
  (printf "  C violations: ~a~a\n" (length cviol) (eg cviol))
  (printf "  non-inflationary (r⊔x != r or r⊔y != r): ~a~a\n" (length inflv) (eg inflv))
  (printf "  A violations: ~a/~a random triples\n" aviol NA))

(printf "C4 type-oracle — universe ~a terms, ground universe ~a terms\n\n" (length universe) (length ground-universe))
;; --- arm census on the meta universe -------------------------------------------------------------------
(define arm-counts (make-hasheq))
(define fb-blocked '()) (define fb-clash '()) (define succ-clash '())
(for* ([x universe] [y universe])
  (define a (arm x y))
  (hash-update! arm-counts a add1 0)
  (when (eq? a 'fallback) (if (unifiable? x y) (set! fb-blocked (cons (cons x y) fb-blocked)) (set! fb-clash (cons (cons x y) fb-clash))))
  (when (and (eq? a 'unify-success) (not (unifiable? x y))) (set! succ-clash (cons (cons x y) succ-clash))))
(printf "ARM CENSUS (type-unify-or-top under pm1,pm2,mm1 unsolved; pm3 := Nat)\n")
(for ([k '(trivial unify-success fallback ground-clash)]) (printf "  ~a: ~a\n" k (hash-ref arm-counts k 0)))
(printf "  fallback pairs that are genuinely BLOCKED (oracle unifiable): ~a\n" (length fb-blocked))
(printf "  fallback pairs that are CLASHES (no solution unifies)       : ~a\n" (length fb-clash))
(printf "  unify-success pairs the oracle says CANNOT unify (non-linear metas): ~a\n" (length succ-clash))
(define (shortest l) (if (null? l) "none" (let ([s (argmin (λ (pr) (string-length (show-term pr))) l)]) (format "~a  ⊔  ~a" (show-term (car s)) (show-term (cdr s))))))
(printf "    shortest blocked : ~a\n" (shortest fb-blocked))
(printf "    shortest clash   : ~a\n" (shortest fb-clash))
(printf "    shortest succ-but-clash: ~a  -> ~a\n" (shortest succ-clash)
        (if (null? succ-clash) "" (let ([s (argmin (λ (pr) (string-length (show-term pr))) succ-clash)]) (show-term (V0 (car s) (cdr s))))))
;; blocked pairs by shape
(define (shape pr) (cond [(or (and (expr-Pi? (car pr)) (mult-meta? (expr-Pi-mult (car pr)))) (and (expr-Pi? (cdr pr)) (mult-meta? (expr-Pi-mult (cdr pr))))) 'mult-meta]
                         [(or (expr-union? (car pr)) (expr-union? (cdr pr))) 'union]
                         [else 'other]))
(define shape-counts (make-hasheq))
(for ([pr fb-blocked]) (hash-update! shape-counts (shape pr) add1 0))
(printf "  blocked fallback pairs by shape: ~a\n" (for/list ([k '(mult-meta union other)]) (cons k (hash-ref shape-counts k 0))))
(define other-blocked (filter (λ (pr) (eq? (shape pr) 'other)) fb-blocked))
(printf "    shortest 'other' blocked: ~a\n\n" (shortest other-blocked))

;; --- the deep-clash witness ------------------------------------------------------------------------------
(define w1x (expr-Pi 'mw pm1 (expr-Nat))) (define w1y (expr-Pi 'mw (expr-Bool) (expr-Unit)))
(printf "WITNESS (same head, deep rigid clash Nat vs Unit):\n  Pi(?pm1,Nat) ⊔ Pi(Bool,Unit) = ~s   [oracle unifiable? ~a]\n"
        (V0 w1x w1y) (unifiable? w1x w1y))
(printf "  D.2 literal split (heads differ => top) on it: ~s\n" (V1 w1x w1y))
(define w2x (expr-Pi 'mw pm1 pm1)) (define w2y (expr-Pi 'mw (expr-Bool) (expr-Nat)))
(printf "  Pi(?pm1,?pm1) ⊔ Pi(Bool,Nat) = ~s   [oracle unifiable? ~a]  (try-unify-pure treats each meta occurrence as a fresh wildcard)\n\n"
        (V0 w2x w2y) (unifiable? w2x w2y))
(printf "ROLE A vs ROLE B on ground atoms: type-lattice-merge(Nat,Bool) = ~s ; type-unify-or-top(Nat,Bool) = ~s\n"
        (VA0 (expr-Nat) (expr-Bool)) (V0 (expr-Nat) (expr-Bool)))
;; unions are an ACI operator: unification modulo ACI is finitary, not unitary — count the ground solutions
(let* ([x (build-union-type (list pm1 pm2))] [y (build-union-type (list (expr-Nat) (expr-Bool)))]
       [G* (filter (λ (t) (not (symbol? t))) ground-universe)]
       [sols (for*/list ([g1 G*] [g2 G*]
                         #:when (let* ([s (λ (id) (case id [(pm1) g1] [(pm2) g2] [else #f]))]
                                       [r (with-sol (λ (_) #f) (λ () (try-unify-pure (subst x s (λ (_) #f)) y)))])
                                  (and r (not (eq? r 'type-top)))))
               (list g1 g2))])
  (printf "UNION SHAPE: (?pm1 | ?pm2) = (Nat | Bool) has ~a ground solutions over G: ~s\n" (length sols) sols)
  (printf "  today's merge returns: ~s\n" (V0 x y)))
(printf "  Role A on Bool ⊔ Pi(?pm1,Nat) (a rigid head clash): type-lattice-merge = ~s\n\n" (VA0 (expr-Bool) (expr-Pi 'mw pm1 (expr-Nat))))

;; --- variants ---------------------------------------------------------------------------------------------
(printf "POWER ROW (ground universe; the oracle and today's merge should agree):\n")
(report "G0 type-unify-or-top on GROUND terms" V0 ground-universe)
(newline)
(printf "VARIANTS on the meta universe:\n")
(report "V0 type-unify-or-top today" V0 universe)
(report "V1 D.2 literal split: fallback + top-level heads differ => top" V1 universe)
(report "V2 fallback deleted: try-unify-pure fails => top" V2 universe)
(define (kind pr)
  (define x (car pr)) (define y (cdr pr))
  (cond [(and (expr-meta? x) (expr-meta? y)) 'meta-vs-meta]
        [(or (and (expr-Pi? x) (mult-meta? (expr-Pi-mult x))) (and (expr-Pi? y) (mult-meta? (expr-Pi-mult y)))) 'mult-meta]
        [(or (expr-union? x) (expr-union? y)) 'union]
        [(or (expr-meta? x) (expr-meta? y)) 'bare-meta-vs-term]
        [else 'other]))
(define (by-kind label pred)
  (define h (make-hasheq))
  (for* ([x universe] [y universe] #:when (pred x y)) (hash-update! h (kind (cons x y)) add1 0))
  (printf "  ~a by kind: ~a\n" label (for/list ([k '(meta-vs-meta mult-meta union bare-meta-vs-term other)]) (cons k (hash-ref h k 0)))))
(by-kind "V2 C violations" (λ (x y) (not (eqz (try (λ () (V2 x y))) (try (λ () (V2 y x)))))))
(by-kind "V2 erased contradictions" (λ (x y) (and (not (unifiable? x y)) (not (eq? (V2 x y) 'type-top)))))
(by-kind "V2 false contradictions" (λ (x y) (and (unifiable? x y) (eq? (V2 x y) 'type-top))))
(by-kind "V0 false contradictions" (λ (x y) (and (unifiable? x y) (eq? (V0 x y) 'type-top))))
(report "V3 fallback => top unless a mult-meta or a union is involved (top-level)" V3 universe)
(by-kind "V3 erased contradictions" (λ (x y) (and (not (unifiable? x y)) (not (eq? (V3 x y) 'type-top)))))
(report "V4 fallback => top unless an unsolved mult-meta or a meta-holding union occurs (blocked-capable shapes)" V4 universe)
(by-kind "V4 erased contradictions" (λ (x y) (and (not (unifiable? x y)) (not (eq? (V4 x y) 'type-top)))))
(by-kind "V4 false contradictions" (λ (x y) (and (unifiable? x y) (eq? (V4 x y) 'type-top))))
(report "V5 mult-metas as wildcards; meta-holding unions keep the fallback; every other fallback hit => top" V5 universe)
(by-kind "V5 erased contradictions" (λ (x y) (and (not (unifiable? x y)) (not (eq? (V5 x y) 'type-top)))))
(by-kind "V5 false contradictions" (λ (x y) (and (unifiable? x y) (eq? (V5 x y) 'type-top))))
(by-kind "V5 C violations" (λ (x y) (not (eqz (try (λ () (V5 x y))) (try (λ () (V5 y x)))))))
(newline)
(printf "ROLE A (type-lattice-merge), oracle columns not meaningful (clash => union by design):\n")
(report "GA0 type-lattice-merge on GROUND terms (power row)" VA0 ground-universe)
(report "VA0 type-lattice-merge today" VA0 universe)
(report "VA1 type-lattice-merge, fallback => build-union-type" VA1 universe)
