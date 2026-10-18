#lang racket/base
;; W2-7 Q1(a): the :usage carrier, settled by EXHAUSTION.
;; For each carrier order on Q = {bot, m0, m1, mw} (bot = an unsolved multiplicity), enumerate EVERY commutative
;; extension of the real semiring ops (prelude.rkt mult-add / mult-mul on {m0,m1,mw}) to bot: 4^4 = 256 per op.
;; Keep those that are (i) SOUND for "bot = some m in {m0,m1,mw}" (f(bot,x) ⊑ f(m,x) for every m, in the carrier's
;; information order), (ii) MONOTONE in both arguments, (iii) ASSOCIATIVE.  Report the BEST (most precise) sound
;; abstraction f#(bot,x) = ⨅_m f(m,x) and whether it survives (ii)+(iii).
;; Carriers: CHAIN bot<m0<m1<mw (C4-6's reading of D.2), FLAT bot<{m0,m1,mw} (mult-lattice.rkt's order),
;; INTERVAL [lo,hi] over m0<m1<mw (C4-6's proposal), unknown=[m0,mw].
;; Arity: fold-order independence at arity 3 and 4, exhaustively.  POWER rows: C4's addW and mulS must be caught.
(require racket/list
         (only-in (file "/Users/avanti/dev/projects/logos/prologos/.claude/worktrees/par4-arena-executors/racket/prologos/prelude.rkt")
                  mult-add mult-mul mult-leq))
(define M '(m0 m1 mw))
(define Q '(bot m0 m1 mw))
(define (rk x) (case x [(bot) 0] [(m0) 1] [(m1) 2] [(mw) 3]))
(define (chain<= a b) (<= (rk a) (rk b)))
(define (flat<= a b) (or (eq? a 'bot) (eq? a b)))
;; sanity: prelude's order on M is the chain
(printf "prelude mult-leq agrees with the chain on M: ~a\n" (for*/and ([a M] [b M]) (eq? (mult-leq a b) (chain<= a b))))

;; an extension = vector of f(bot,bot), f(bot,m0), f(bot,m1), f(bot,mw)
(define (ext base v)
  (λ (a b)
    (cond [(and (eq? a 'bot) (eq? b 'bot)) (vector-ref v 0)]
          [(eq? a 'bot) (vector-ref v (rk b))]
          [(eq? b 'bot) (vector-ref v (rk a))]
          [else (base a b)])))
(define all-exts (for*/list ([a Q] [b Q] [c Q] [d Q]) (vector a b c d)))
(define (assoc? f) (for*/and ([x Q] [y Q] [z Q]) (eq? (f (f x y) z) (f x (f y z)))))
(define (mono? f le) (for*/and ([a Q] [a2 Q] [b Q] [b2 Q] #:when (and (le a a2) (le b b2))) (le (f a b) (f a2 b2))))
;; soundness: bot abstracts every m. f(bot,x) ⊑ f(m,x) ∀m (x ∈ Q, with x=bot meaning ∀m' too)
(define (conc x) (if (eq? x 'bot) M (list x)))
(define (sound? f le) (for*/and ([x Q] [m M] [mx (conc x)]) (le (f 'bot x) (f m mx))))
(define (meet-of le xs)   ;; greatest lower bound of xs in the carrier (chain: min; flat: common value or bot)
  (if (eq? le chain<=) (argmin rk xs) (if (= 1 (length (remove-duplicates xs))) (car xs) 'bot)))
(define (best base le) ;; f#(bot,x) = ⨅ {base(m, mx) | m ∈ M, mx ∈ conc x}
  (for/vector ([x Q]) (meet-of le (for*/list ([m M] [mx (conc x)]) (base m mx)))))
(define (fold-dep f n)  ;; child vectors of length n whose left fold depends on the order
  (for/sum ([xs (in-list (let loop ([k n]) (if (zero? k) '(()) (for*/list ([r (loop (sub1 k))] [q Q]) (cons q r)))))])
    (if (= 1 (length (remove-duplicates (for/list ([pp (in-permutations xs)]) (foldl f (car pp) (cdr pp)))))) 0 1)))
(define (show-v v) (for/list ([x Q] [r v]) (format "bot∘~a=~a" x r)))

(for ([carrier (list (cons "CHAIN bot<m0<m1<mw" chain<=) (cons "FLAT bot<{m0,m1,mw}" flat<=))])
  (define le (cdr carrier))
  (printf "\n== ~a ==\n" (car carrier))
  (for ([op (list (cons "+" mult-add) (cons "·" mult-mul))])
    (define base (cdr op))
    (define fs (for/list ([v all-exts]) (cons v (ext base v))))
    (define S (filter (λ (p) (sound? (cdr p) le)) fs))
    (define SM (filter (λ (p) (mono? (cdr p) le)) S))
    (define SMA (filter (λ (p) (assoc? (cdr p))) SM))
    (define bv (best base le)) (define bf (ext base bv))
    (printf " op ~a: 256 extensions; sound ~a; sound+monotone ~a; sound+monotone+associative ~a\n"
            (car op) (length S) (length SM) (length SMA))
    (printf "   best sound abstraction ~a: monotone ~a, associative ~a, arity-3 order-dep ~a/64, arity-4 ~a/256\n"
            (show-v bv) (mono? bf le) (assoc? bf) (fold-dep bf 3) (fold-dep bf 4))
    (for ([p SMA]) (printf "   survivor ~a  arity-3 dep ~a arity-4 dep ~a; distinct-from-m0? ~a\n" (show-v (car p))
                           (fold-dep (cdr p) 3) (fold-dep (cdr p) 4)
                           ;; is bot observationally distinct from m0 under this op? (some x with f(bot,x) != f(m0,x))
                           (for/or ([x Q]) (not (eq? ((cdr p) 'bot x) ((cdr p) 'm0 x))))))))

;; POWER rows: C4-6's two named extensions must be rejected for the reason C4 gives
(define addW (ext mult-add (vector 'bot 'bot 'bot 'mw)))   ;; ω absorbs bot
(define mulS (ext mult-mul (vector 'bot 'm0 'bot 'bot)))   ;; 0 absorbs bot
(printf "\nPOWER: C4 addW (ω absorbs ⊥): sound(chain) ~a assoc ~a arity-3 dep ~a ; C4 mulS (0 absorbs ⊥): monotone(chain) ~a monotone(flat) ~a\n"
        (sound? addW chain<=) (assoc? addW) (fold-dep addW 3) (mono? mulS chain<=) (mono? mulS flat<=))

;; ---- INTERVAL carrier: [lo,hi], lo<=hi over the chain; info order = reverse inclusion; unknown = [m0,mw] ----
(define IV (for*/list ([lo M] [hi M] #:when (chain<= lo hi)) (cons lo hi)))
(define (iv<= a b) (and (chain<= (car a) (car b)) (chain<= (cdr b) (cdr a))))   ;; b more precise: b ⊆ a
(define (iv-op f) (λ (a b) (cons (f (car a) (car b)) (f (cdr a) (cdr b)))))
(define (gamma a) (filter (λ (m) (and (chain<= (car a) m) (chain<= m (cdr a)))) M))
(define (hull xs) (cons (argmin rk xs) (argmax rk xs)))
(define (iv-exact? f base) (for*/and ([a IV] [b IV]) (equal? (f a b) (hull (for*/list ([x (gamma a)] [y (gamma b)]) (base x y))))))
(define (iv-sound? f base) (for*/and ([a IV] [b IV] [x (gamma a)] [y (gamma b)]) (memq (base x y) (gamma (f a b)))))
(define (iv-mono? f) (for*/and ([a IV] [a2 IV] [b IV] [b2 IV] #:when (and (iv<= a a2) (iv<= b b2))) (iv<= (f a b) (f a2 b2))))
(define (iv-assoc? f) (for*/and ([x IV] [y IV] [z IV]) (equal? (f (f x y) z) (f x (f y z)))))
(define (iv-fold-dep f n)
  (for/sum ([xs (in-list (let loop ([k n]) (if (zero? k) '(()) (for*/list ([r (loop (sub1 k))] [q IV]) (cons q r)))))])
    (if (= 1 (length (remove-duplicates (for/list ([pp (in-permutations xs)]) (foldl f (car pp) (cdr pp)))))) 0 1)))
(printf "\n== INTERVAL [lo,hi] (|IV| = ~a, unknown = [m0,mw]) ==\n" (length IV))
(for ([op (list (cons "+" mult-add) (cons "·" mult-mul))])
  (define f (iv-op (cdr op)))
  (printf " op ~a: sound ~a  exact(=hull of the concrete results) ~a  monotone ~a  associative ~a  arity-3 dep ~a/~a  arity-4 dep ~a/~a\n"
          (car op) (iv-sound? f (cdr op)) (iv-exact? f (cdr op)) (iv-mono? f) (iv-assoc? f)
          (iv-fold-dep f 3) (expt (length IV) 3) (iv-fold-dep f 4) (expt (length IV) 4)))
(define (iv-join a b) (let ([lo (argmax rk (list (car a) (car b)))] [hi (argmin rk (list (cdr a) (cdr b)))])
                        (if (chain<= lo hi) (cons lo hi) 'itop)))
(printf " join (max lo, min hi): C ~a  A ~a  I ~a\n"
        (for*/sum ([a IV] [b IV]) (if (equal? (iv-join a b) (iv-join b a)) 0 1))
        (for*/sum ([a IV] [b IV] [c IV]) (let ([l (let ([ab (iv-join a b)]) (if (eq? ab 'itop) 'itop (iv-join ab c)))]
                                               [r (let ([bc (iv-join b c)]) (if (eq? bc 'itop) 'itop (iv-join a bc)))]) (if (equal? l r) 0 1)))
        (for/sum ([a IV]) (if (equal? (iv-join a a) a) 0 1)))
;; the decisive example of C4-6, and the boundary distinction the chain cannot make
(define U (cons 'm0 'mw)) (define one (cons 'm1 'm1)) (define zero (cons 'm0 'm0))
(printf " x used once, scaled by an unsolved mult: m1·unknown = ~a (open: the boundary knows to default/re-fire)\n" ((iv-op mult-mul) U one))
(printf " the CHAIN's best abstraction gives ⊥·m1 = ~a, the same as an exactly-unused coordinate m0·m1 = ~a: open and closed coincide\n"
        ((ext mult-mul (best mult-mul chain<=)) 'bot 'm1) (mult-mul 'm0 'm1))
