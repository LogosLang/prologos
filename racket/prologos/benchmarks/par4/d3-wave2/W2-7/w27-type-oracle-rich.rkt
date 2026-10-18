#lang racket/base
;; W2-7 Q2: C4's type-merge oracle (d3-wave1/C4/c4-type-oracle.rkt) re-run on a RICHER universe:
;; dependent codomains (bvar 0 under Pi/Sigma), Sigma, type applications (List ?a, Maybe ?a, ?f Nat), applied metas
;; under a binder (Pi(n:Nat). ?f n — a Miller pattern, unify.rkt:555 'flex-app), and nested unions (unions holding
;; Pi/app/Sigma; unions inside Pi and app).
;; ORACLE (as C4): x,y unifiable <=> some ground substitution σ for the metas that occur makes try-unify-pure(xσ, yσ)
;; succeed with NO metas.  The ground range G now also holds type applications, Sigma, a dependent Pi, and closed
;; LAMBDAS (so an applied meta ?f can be solved, as in higher-order pattern unification).
;; Questions: (1) Role B with "try-unify-pure fails => ⊤": erasures?  split by the arm that produces them.
;;            (2) the blocked share: still only unsolved mult-metas and meta-holding unions?
;; POWER rows: the ground universe (oracle and merge must agree), and C4's 83-term universe re-run inside this probe
;; (must reproduce C4's 532 blocked = 212 mult-meta + 320 union, 0 other).
;; Run: racket w27-type-oracle-rich.rkt [rich|c4]
(require racket/list racket/string)
(define root "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos")
(define (p f) (list 'file (string-append root "/" f)))
(define (get f id)
  (with-handlers ([exn:fail? (λ (_) (dynamic-require (p f) #f) (eval id (module->namespace (p f))))])
    (dynamic-require (p f) id)))
(define-syntax-rule (from f id ...) (begin (define id (get f 'id)) ...))
(from "syntax.rkt" expr-Nat expr-Bool expr-Unit expr-Pi expr-union expr-meta expr-meta? expr-meta-id
      expr-Pi? expr-Pi-mult expr-Pi-domain expr-Pi-codomain expr-union? expr-union-left expr-union-right
      expr-Sigma expr-Sigma? expr-Sigma-fst-type expr-Sigma-snd-type expr-app expr-app? expr-app-func expr-app-arg
      expr-Vec expr-Vec? expr-Vec-elem-type expr-Vec-length expr-bvar expr-tycon expr-lam expr-lam? expr-lam-mult
      expr-lam-type expr-lam-body expr-Type)
(from "prelude.rkt" mult-meta mult-meta? mult-meta-id lzero)
(from "type-lattice.rkt" type-unify-or-top type-lattice-merge try-unify-pure current-lattice-meta-solution-fn
      type-top? type-bot? has-unsolved-meta?)
(from "union-types.rkt" build-union-type flatten-union)
(define MODE (let ([a (current-command-line-arguments)]) (if (> (vector-length a) 0) (vector-ref a 0) "rich")))
(define NA 20000)
(define rng (make-pseudo-random-generator))
(parameterize ([current-pseudo-random-generator rng]) (random-seed 4404))

(define pm1 (expr-meta 'pm1 #f)) (define pm2 (expr-meta 'pm2 #f)) (define pm3 (expr-meta 'pm3 #f))
(define mm1 (mult-meta 'mm1))
(define (sol0 id) (and (eq? id 'pm3) (expr-Nat)))
(define (with-sol f thunk) (parameterize ([current-lattice-meta-solution-fn f]) (thunk)))
(define N (expr-Nat)) (define B (expr-Bool)) (define U (expr-Unit)) (define T0 (expr-Type (lzero)))
(define (Pi a b) (expr-Pi 'mw a b)) (define (Sg a b) (expr-Sigma a b)) (define (ap f a) (expr-app f a))
(define List (expr-tycon 'List)) (define Maybe (expr-tycon 'Maybe))
(define b0 (expr-bvar 0)) (define b1 (expr-bvar 1))
(define (U2 a b) (build-union-type (list a b)))
(define (lam body) (expr-lam 'mw N body))

;; ---- universes ----
(define c4-ground-atoms (list N B U))
(define c4-atoms (append c4-ground-atoms (list pm1 pm2 pm3)))
(define c4-universe
  (append (list 'type-bot 'type-top) c4-atoms
          (for*/list ([a c4-atoms] [b c4-atoms]) (Pi a b))
          (for*/list ([a c4-ground-atoms] [b c4-ground-atoms]) (expr-Pi mm1 a b))
          (for*/list ([a c4-atoms] [b c4-atoms] #:unless (equal? a b)) (U2 a b))))
(define c4-ground-universe
  (append (list 'type-bot 'type-top) c4-ground-atoms
          (for*/list ([a c4-ground-atoms] [b c4-ground-atoms]) (Pi a b))
          (for*/list ([a c4-ground-atoms] [b c4-ground-atoms] #:unless (equal? a b)) (U2 a b))))
(define c4-G (filter (λ (t) (not (symbol? t))) c4-ground-universe))

(define rich-universe
  (remove-duplicates
   (append
    (list 'type-bot 'type-top N B U pm1 pm2 pm3 T0)
    ;; non-dependent Pi (reduced grid)
    (for*/list ([a (list N B pm1)] [b (list N B pm2)]) (Pi a b))
    ;; DEPENDENT codomains
    (list (Pi N (expr-Vec B b0)) (Pi N (expr-Vec N b0)) (Pi N (expr-Vec pm1 b0)) (Pi pm1 (expr-Vec B b0))
          (Pi T0 (Pi b0 b1)) (Pi T0 (Pi b0 N)) (Pi T0 (Pi b0 pm1)) (Pi pm2 (Pi b0 b1))
          (Pi N (ap pm1 b0)))                                  ;; applied meta under a binder (Miller pattern)
    ;; SIGMA (incl. dependent second component)
    (list (Sg N B) (Sg B N) (Sg pm1 B) (Sg N pm2) (Sg N (expr-Vec B b0)) (Sg pm1 (expr-Vec B b0)))
    ;; TYPE APPLICATIONS
    (list (ap List N) (ap List B) (ap List pm1) (ap Maybe N) (ap Maybe pm1) (ap pm1 N)
          (ap List (ap List pm2)) (ap List (ap List N)) (ap List (U2 N pm1)) (ap List (U2 N B)))
    ;; NESTED UNIONS
    (list (U2 N B) (U2 N pm1) (U2 pm1 pm2) (U2 (ap List N) B) (U2 (ap List pm1) B) (U2 (Pi N N) B)
          (U2 (Pi pm1 N) B) (build-union-type (list N B U)) (U2 (Sg N B) U) (U2 (ap pm2 N) B))
    ;; unions INSIDE constructors; MULT-METAS (top-level and nested)
    (list (Pi (U2 N B) N) (Pi (U2 pm1 B) N) (expr-Pi mm1 N N) (expr-Pi mm1 B N) (expr-Pi mm1 N (expr-Vec B b0))
          (Pi N (expr-Pi mm1 N N)) (ap List (expr-Pi mm1 N N))))))
(define rich-G   ;; ground solutions available to every meta
  (list N B U T0 (ap List N) (ap List B) (Pi N N) (Pi N B) (Sg N B) (U2 N B) (expr-Vec B (expr-bvar 0))
        List Maybe (lam B) (lam N) (lam (expr-Vec B (expr-bvar 0))) (lam (ap List N))))
;; NOTE (expr-Vec B (bvar 0)) as a closed solution is ill-scoped; it is only useful as the BODY of a lambda, so it
;; is removed from G below and kept inside (lam ...).
(set! rich-G (filter (λ (t) (not (and (expr-Vec? t) (equal? (expr-Vec-length t) (expr-bvar 0))))) rich-G))
(define (has-meta? t)
  (cond [(symbol? t) #f] [(expr-meta? t) #t]
        [(expr-Pi? t) (or (mult-meta? (expr-Pi-mult t)) (has-meta? (expr-Pi-domain t)) (has-meta? (expr-Pi-codomain t)))]
        [(expr-Sigma? t) (or (has-meta? (expr-Sigma-fst-type t)) (has-meta? (expr-Sigma-snd-type t)))]
        [(expr-app? t) (or (has-meta? (expr-app-func t)) (has-meta? (expr-app-arg t)))]
        [(expr-Vec? t) (or (has-meta? (expr-Vec-elem-type t)) (has-meta? (expr-Vec-length t)))]
        [(expr-union? t) (or (has-meta? (expr-union-left t)) (has-meta? (expr-union-right t)))]
        [(expr-lam? t) (or (has-meta? (expr-lam-type t)) (has-meta? (expr-lam-body t)))]
        [else #f]))

;; ---- substitution (metas are closed: no shifting needed) ----
(define (subst t s ms)
  (cond [(symbol? t) t]
        [(expr-meta? t) (or (s (expr-meta-id t)) t)]
        [(expr-Pi? t) (expr-Pi (let ([m (expr-Pi-mult t)]) (if (mult-meta? m) (or (ms (mult-meta-id m)) m) m))
                               (subst (expr-Pi-domain t) s ms) (subst (expr-Pi-codomain t) s ms))]
        [(expr-Sigma? t) (expr-Sigma (subst (expr-Sigma-fst-type t) s ms) (subst (expr-Sigma-snd-type t) s ms))]
        [(expr-app? t) (expr-app (subst (expr-app-func t) s ms) (subst (expr-app-arg t) s ms))]
        [(expr-Vec? t) (expr-Vec (subst (expr-Vec-elem-type t) s ms) (subst (expr-Vec-length t) s ms))]
        [(expr-union? t) (build-union-type (map (λ (c) (subst c s ms)) (flatten-union t)))]
        [(expr-lam? t) (expr-lam (expr-lam-mult t) (subst (expr-lam-type t) s ms) (subst (expr-lam-body t) s ms))]
        [else t]))
(define (zonk t) (subst t sol0 (λ (_) #f)))
(define (eqz a b) (equal? (zonk a) (zonk b)))
(define (occurs? id t)
  (cond [(symbol? t) #f]
        [(expr-meta? t) (eq? (expr-meta-id t) id)]
        [(expr-Pi? t) (or (and (eq? id 'mm1) (mult-meta? (expr-Pi-mult t))) (occurs? id (expr-Pi-domain t)) (occurs? id (expr-Pi-codomain t)))]
        [(expr-Sigma? t) (or (occurs? id (expr-Sigma-fst-type t)) (occurs? id (expr-Sigma-snd-type t)))]
        [(expr-app? t) (or (occurs? id (expr-app-func t)) (occurs? id (expr-app-arg t)))]
        [(expr-Vec? t) (or (occurs? id (expr-Vec-elem-type t)) (occurs? id (expr-Vec-length t)))]
        [(expr-union? t) (or (occurs? id (expr-union-left t)) (occurs? id (expr-union-right t)))]
        [(expr-lam? t) (or (occurs? id (expr-lam-type t)) (occurs? id (expr-lam-body t)))]
        [else #f]))
(define rich-ground-universe (filter (λ (t) (or (symbol? t) (not (has-meta? t)))) rich-universe))
(define-values (universe ground-universe G)
  (if (equal? MODE "c4") (values c4-universe c4-ground-universe c4-G) (values rich-universe rich-ground-universe
                (remove-duplicates
                 (append (filter (λ (t) (not (symbol? t))) rich-ground-universe) rich-G
                         ;; ground instances of the terms whose only meta is the mult-meta mm1
                         (for*/list ([t rich-universe] #:when (and (not (symbol? t)) (occurs? 'mm1 t) (not (occurs? 'pm1 t)) (not (occurs? 'pm2 t))) [mu '(m0 m1 mw)])
                           (subst t (λ (_) #f) (λ (_) mu))))))))

(define (try thunk) (with-handlers ([exn:fail? (λ (e) (list 'RAISED (car (string-split (exn-message e) "\n"))))]) (thunk)))
(define (tup x y) (try (λ () (try-unify-pure x y))))
(define (ok? r) (and r (not (eq? r 'type-top)) (not (and (pair? r) (eq? (car r) 'RAISED)))))
(define G-cache (make-hash)) (define raised 0)
(define (unifiable? x y)
  (hash-ref! G-cache (cons x y)
   (λ ()
    (cond [(or (eq? x 'type-top) (eq? y 'type-top)) #f]
          [(or (eq? x 'type-bot) (eq? y 'type-bot)) #t]
          ;; a bare unsolved meta against t: solvable iff it does not occur in t (σ(a) := any ground instance of t)
          ;; (only the non-occurring case is decided here: with ACI unions an occurring meta can still be solvable,
          ;;  e.g. ?a = (Nat | ?a) by ?a := Nat, so that case is left to the enumeration)
          [(and (expr-meta? x) (not (sol0 (expr-meta-id x))) (not (occurs? (expr-meta-id x) y))) #t]
          [(and (expr-meta? y) (not (sol0 (expr-meta-id y))) (not (occurs? (expr-meta-id y) x))) #t]
          [else
           (define (dom id) (if (or (occurs? id x) (occurs? id y)) (if (eq? id 'mm1) '(m0 m1 mw) G) (list #f)))
           (for*/or ([g1 (dom 'pm1)] [g2 (dom 'pm2)] [mu (dom 'mm1)])
             (define s (λ (id) (case id [(pm1) g1] [(pm2) g2] [(pm3) N] [else #f])))
             (define r (with-sol (λ (_) #f) (λ () (tup (subst x s (λ (_) mu)) (subst y s (λ (_) mu))))))
             (when (and (pair? r) (eq? (car r) 'RAISED)) (set! raised (add1 raised)))
             (ok? r))]))))

;; ---- arms and shapes ----
(define (has-unsolved? t) (with-sol sol0 (λ () (has-unsolved-meta? t))))
(define (arm x y)
  (cond [(or (type-bot? x) (type-bot? y) (type-top? x) (type-top? y) (equal? x y)) 'trivial]
        [(ok? (with-sol sol0 (λ () (tup x y)))) 'unify-success]
        [(or (has-unsolved? x) (has-unsolved? y)) 'fallback]
        [else 'ground-clash]))
(define (deep pred t)   ;; does some subterm satisfy pred?
  (cond [(symbol? t) #f]
        [(pred t) #t]
        [(expr-Pi? t) (or (deep pred (expr-Pi-domain t)) (deep pred (expr-Pi-codomain t)))]
        [(expr-Sigma? t) (or (deep pred (expr-Sigma-fst-type t)) (deep pred (expr-Sigma-snd-type t)))]
        [(expr-app? t) (or (deep pred (expr-app-func t)) (deep pred (expr-app-arg t)))]
        [(expr-Vec? t) (or (deep pred (expr-Vec-elem-type t)) (deep pred (expr-Vec-length t)))]
        [(expr-union? t) (or (deep pred (expr-union-left t)) (deep pred (expr-union-right t)))]
        [(expr-lam? t) (or (deep pred (expr-lam-type t)) (deep pred (expr-lam-body t)))]
        [else #f]))
(define (unsolved-meta? t) (and (expr-meta? t) (not (sol0 (expr-meta-id t)))))
(define (mult-meta-in? t) (deep (λ (s) (and (expr-Pi? s) (mult-meta? (expr-Pi-mult s)))) t))
(define (union-with-meta? t) (deep (λ (s) (and (expr-union? s) (has-unsolved? s))) t))
(define (flex-app? t) (deep (λ (s) (and (expr-app? s) (let loop ([h s]) (if (expr-app? h) (loop (expr-app-func h)) (unsolved-meta? h))))) t))
(define (shape x y)
  (cond [(or (mult-meta-in? x) (mult-meta-in? y)) 'mult-meta]
        [(or (union-with-meta? x) (union-with-meta? y)) 'meta-union]
        [(or (flex-app? x) (flex-app? y)) 'flex-app]
        [else 'other]))
(define (tally l f) (let ([h (make-hash)]) (for ([e l]) (hash-update! h (f e) add1 0)) (sort (hash->list h) > #:key cdr)))
(define (show t) (format "~s" t))
(define (shortest l) (if (null? l) "none" (let ([s (argmin (λ (pr) (string-length (show pr))) l)]) (format "~a  ⊔  ~a" (show (car s)) (show (cdr s))))))

(define (V0 x y) (try (λ () (with-sol sol0 (λ () (type-unify-or-top x y))))))
(define (V2 x y) (if (eq? (arm x y) 'fallback) 'type-top (V0 x y)))   ;; try-unify-pure fails => ⊤
(define (report name merge U)
  (define erased '()) (define false-top '()) (define cv 0) (define infl 0)
  (for* ([x U] [y U])
    (define r (merge x y)) (define u? (unifiable? x y))
    (when (and (not u?) (not (eq? r 'type-top))) (set! erased (cons (cons x y) erased)))
    (when (and u? (eq? r 'type-top)) (set! false-top (cons (cons x y) false-top)))
    (unless (eqz r (merge y x)) (set! cv (add1 cv)))
    (unless (and (eqz (merge r x) r) (eqz (merge r y) r)) (set! infl (add1 infl))))
  (define vec (list->vector U))
  (define av (for/sum ([i NA]) (let ([x (vector-ref vec (random (vector-length vec) rng))] [y (vector-ref vec (random (vector-length vec) rng))]
                                     [z (vector-ref vec (random (vector-length vec) rng))])
                                 (if (eqz (merge (merge x y) z) (merge x (merge y z))) 0 1))))
  (printf "~a  [~a pairs]\n" name (* (length U) (length U)))
  (printf "  erased contradictions: ~a   by arm ~s   by shape ~s\n" (length erased)
          (tally erased (λ (pr) (arm (car pr) (cdr pr)))) (tally erased (λ (pr) (shape (car pr) (cdr pr)))))
  (printf "    shortest erased: ~a\n" (shortest erased))
  (printf "  false contradictions: ~a   by shape ~s\n" (length false-top) (tally false-top (λ (pr) (shape (car pr) (cdr pr)))))
  (printf "  C violations ~a ; non-inflationary ~a ; A violations ~a/~a\n" cv infl av NA))

(printf "W27 type-oracle (~a) — universe ~a terms, ground universe ~a, |G| = ~a\n" MODE (length universe) (length ground-universe) (length G))
(define arm-counts (make-hasheq))
(define fb-blocked '()) (define fb-clash '()) (define succ-clash '())
(for* ([x universe] [y universe])
  (define a (arm x y))
  (hash-update! arm-counts a add1 0)
  (when (eq? a 'fallback) (if (unifiable? x y) (set! fb-blocked (cons (cons x y) fb-blocked)) (set! fb-clash (cons (cons x y) fb-clash))))
  (when (and (eq? a 'unify-success) (not (unifiable? x y))) (set! succ-clash (cons (cons x y) succ-clash))))
(printf "ARM CENSUS (pm1,pm2,mm1 unsolved; pm3 := Nat): ~s\n" (for/list ([k '(trivial unify-success fallback ground-clash)]) (cons k (hash-ref arm-counts k 0))))
(printf "  fallback BLOCKED (oracle unifiable): ~a ; fallback CLASH: ~a ; clash share ~a%\n" (length fb-blocked) (length fb-clash)
        (if (null? (append fb-blocked fb-clash)) 0 (round (* 100. (/ (length fb-clash) (+ (length fb-blocked) (length fb-clash)))))))
(printf "  blocked by shape: ~s\n" (tally fb-blocked (λ (pr) (shape (car pr) (cdr pr)))))
(for ([k '(mult-meta meta-union flex-app other)])
  (printf "    shortest blocked [~a]: ~a\n" k (shortest (filter (λ (pr) (eq? (shape (car pr) (cdr pr)) k)) fb-blocked))))
(printf "  unify-success pairs the oracle says CANNOT unify: ~a   by shape ~s\n" (length succ-clash) (tally succ-clash (λ (pr) (shape (car pr) (cdr pr)))))
(printf "    shortest: ~a\n" (shortest succ-clash))
(printf "  oracle evaluations that raised: ~a\n\n" raised)
(printf "POWER (ground universe):\n")
(report "G0 type-unify-or-top, ground" V0 ground-universe)
(printf "\nRole B variants:\n")
(report "V0 type-unify-or-top today" V0 universe)
(report "V2 try-unify-pure fails => ⊤ (fallback deleted)" V2 universe)

;; ---- DETAIL: the flex-app blocked pairs, V2's C violations, and the success-arm erasures by kind ----
(define (pp t) (cond [(symbol? t) (symbol->string t)]
                     [(expr-meta? t) (format "?~a" (expr-meta-id t))]
                     [(expr-Pi? t) (format "Π~a(~a,~a)" (let ([m (expr-Pi-mult t)]) (if (mult-meta? m) "?mm" (if (eq? m 'mw) "" m))) (pp (expr-Pi-domain t)) (pp (expr-Pi-codomain t)))]
                     [(expr-Sigma? t) (format "Σ(~a,~a)" (pp (expr-Sigma-fst-type t)) (pp (expr-Sigma-snd-type t)))]
                     [(expr-app? t) (format "(~a ~a)" (pp (expr-app-func t)) (pp (expr-app-arg t)))]
                     [(expr-Vec? t) (format "Vec(~a,~a)" (pp (expr-Vec-elem-type t)) (pp (expr-Vec-length t)))]
                     [(expr-union? t) (string-join (map pp (flatten-union t)) "|")]
                     [(expr-lam? t) (format "λ.~a" (pp (expr-lam-body t)))]
                     [else (let ([s (format "~s" t)]) (cond [(regexp-match #rx"expr-([A-Za-z]+)\\)?" s) => (λ (m) (cadr m))] [(regexp-match #rx"bvar ([0-9]+)" s) => (λ (m) (string-append "#" (cadr m)))] [(regexp-match #rx"tycon ([A-Za-z]+)" s) => cadr] [else s]))]))
(when (equal? MODE "rich")
  (printf "\nDETAIL flex-app blocked pairs (~a):\n" (length (filter (λ (pr) (eq? (shape (car pr) (cdr pr)) 'flex-app)) fb-blocked)))
  (for ([pr fb-blocked] #:when (eq? (shape (car pr) (cdr pr)) 'flex-app)) (printf "  ~a ⊔ ~a  -> today ~a\n" (pp (car pr)) (pp (cdr pr)) (let ([r (V0 (car pr) (cdr pr))]) (if (symbol? r) r (pp r)))))
  (printf "DETAIL V2 C violations:\n")
  (for* ([x universe] [y universe] #:unless (eqz (V2 x y) (V2 y x)))
    (printf "  ~a ⊔ ~a = ~a  but  ~a\n" (pp x) (pp y) (let ([r (V2 x y)]) (if (symbol? r) r (pp r))) (let ([r (V2 y x)]) (if (symbol? r) r (pp r)))))
  (define (sub-kind pr)
    (define x (car pr)) (define y (cdr pr))
    (define ids (filter (λ (id) (and (occurs? id x) (occurs? id y))) '(pm1 pm2)))
    (cond [(or (and (expr-meta? x) (occurs? (expr-meta-id x) y)) (and (expr-meta? y) (occurs? (expr-meta-id y) x))) 'occurs-check]
          [(pair? ids) 'shared-meta-both-sides]
          [else 'repeated-meta-one-side]))
  (printf "DETAIL success-arm erasures (oracle: not unifiable; try-unify-pure succeeds) by kind: ~s\n" (tally succ-clash sub-kind))
  (for ([k '(occurs-check shared-meta-both-sides repeated-meta-one-side)])
    (define l (filter (λ (pr) (eq? (sub-kind pr) k)) succ-clash))
    (unless (null? l) (let ([s (argmin (λ (pr) (string-length (show pr))) l)]) (printf "  e.g. [~a] ~a ⊔ ~a -> ~a\n" k (pp (car s)) (pp (cdr s)) (let ([r (V0 (car s) (cdr s))]) (if (symbol? r) r (pp r))))))))
(when (equal? MODE "rich")
  (define (sub-kind pr)
    (define x (car pr)) (define y (cdr pr))
    (define ids (filter (λ (id) (and (occurs? id x) (occurs? id y))) '(pm1 pm2)))
    (cond [(or (and (expr-meta? x) (occurs? (expr-meta-id x) y)) (and (expr-meta? y) (occurs? (expr-meta-id y) x))) 'occurs-check]
          [(pair? ids) 'shared-meta-both-sides]
          [else 'repeated-meta-one-side]))
  (printf "DETAIL the 'repeated-meta-one-side' success-arm erasures (all of them):\n")
  (for ([pr succ-clash] #:when (eq? (sub-kind pr) 'repeated-meta-one-side))
    (printf "  ~a ⊔ ~a -> ~a\n" (pp (car pr)) (pp (cdr pr)) (let ([r (V0 (car pr) (cdr pr))]) (if (symbol? r) r (pp r))))))
