#lang racket/base

;;;
;;; PROLOGOS PRETTY PRINTER
;;; Convert core AST (Expr, Session, Process) back to readable surface syntax strings.
;;; Uses a name supply to convert de Bruijn indices to human-readable names.
;;;

(require racket/match
         racket/string
         "prelude.rkt"
         "syntax.rkt"
         "sessions.rkt"
         "metavar-store.rkt")

(provide pp-expr
         pp-session
         pp-mult
         pp-function-signature)

;; ========================================
;; Name supply for de Bruijn -> named variables
;; ========================================

;; Base names to use (cycle through these)
(define base-names '("x" "y" "z" "a" "b" "c" "d" "e" "f" "g" "h"))

;; Generate a fresh name given the current name stack depth
(define (fresh-name depth names-in-scope)
  (define idx depth)
  (define base-idx (modulo idx (length base-names)))
  (define cycle (quotient idx (length base-names)))
  (define base (list-ref base-names base-idx))
  (define candidate
    (if (= cycle 0) base (format "~a~a" base cycle)))
  ;; Avoid collisions with names already in scope
  (if (member candidate names-in-scope)
      (format "~a_~a" base depth)
      candidate))

;; ========================================
;; Pretty-print expressions
;; ========================================

;; pp-expr: convert Expr -> string
;; names is a list of name strings (stack), innermost binding first
(define (pp-expr e [names '()])
  (match e
    ;; Variables
    [(expr-bvar k)
     (if (< k (length names))
         (list-ref names k)
         (format "?bvar~a" k))]
    [(expr-fvar name) (symbol->string name)]

    ;; Atoms
    [(expr-zero) "zero"]
    [(expr-refl) "refl"]
    [(expr-Nat) "Nat"]
    [(expr-Bool) "Bool"]
    [(expr-true) "true"]
    [(expr-false) "false"]
    [(expr-Unit) "Unit"]
    [(expr-unit) "unit"]
    [(expr-hole) "_"]
    [(expr-meta id)
     (let ([sol (meta-solution id)])
       (if sol
           (pp-expr sol names)
           (format "?~a" id)))]
    [(expr-error) "<error>"]

    ;; Universes
    [(expr-Type l) (format "[Type ~a]" (pp-level l))]

    ;; Successor — detect numeric literals
    [(expr-suc _)
     (let ([n (try-as-nat e)])
       (if n
           (number->string n)
           (format "[inc ~a]" (pp-expr (expr-suc-pred e) names))))]

    ;; Lambda
    [(expr-lam m t body)
     (let ([name (fresh-name (length names) names)])
       (format "[fn [~a~a <~a>] ~a]"
               name
               (pp-mult-prefix m)
               (pp-expr t names)
               (pp-expr body (cons name names))))]

    ;; Pi — detect non-dependent arrow chain
    [(expr-Pi m dom cod)
     (if (and (eq? m 'mw) (not (uses-bvar0? cod)))
         ;; Non-dependent: collect arrow chain A B C -> D
         (let loop ([doms '()] [cur-dom dom] [cur-cod cod] [ns names])
           (let ([name (fresh-name (length ns) ns)])
             (define dom-str (pp-expr cur-dom ns))
             ;; Wrap domain in [...] if it's itself a Pi (higher-order function type)
             (define wrapped-dom
               (if (expr-Pi? cur-dom) (format "[~a]" dom-str) dom-str))
             (define new-ns (cons name ns))
             (if (and (expr-Pi? cur-cod)
                      (eq? (expr-Pi-mult cur-cod) 'mw)
                      (not (uses-bvar0? (expr-Pi-codomain cur-cod))))
                 ;; Continue chain
                 (loop (cons wrapped-dom doms)
                       (expr-Pi-domain cur-cod) (expr-Pi-codomain cur-cod) new-ns)
                 ;; End of chain
                 (let* ([all-doms (reverse (cons wrapped-dom doms))]
                        [cod-str (pp-expr cur-cod new-ns)])
                   (format "~a -> ~a"
                           (string-join all-doms " ")
                           cod-str)))))
         ;; Dependent: [Pi [x :m <A>] B]
         (let ([name (fresh-name (length names) names)])
           (format "[Pi [~a~a <~a>] ~a]"
                   name
                   (pp-mult-prefix m)
                   (pp-expr dom names)
                   (pp-expr cod (cons name names)))))]

    ;; Sigma
    [(expr-Sigma t1 t2)
     (if (not (uses-bvar0? t2))
         ;; Non-dependent: [Sigma A B]
         (format "[Sigma ~a ~a]" (pp-expr t1 names) (pp-expr t2 names))
         (let ([name (fresh-name (length names) names)])
           (format "[Sigma [~a <~a>] ~a]"
                   name
                   (pp-expr t1 names)
                   (pp-expr t2 (cons name names)))))]

    ;; Application — check for cons-chain (list literal), then flatten nested apps
    [(expr-app _ _)
     (let ([list-result (try-as-list e)])
       (cond
         [list-result
          (let ([elements (car list-result)]
                [tail (cadr list-result)])
            (let ([elem-strs (map (lambda (x) (pp-expr x names)) elements)])
              (if tail
                  ;; Improper list: '[1 2 | xs]
                  (format "'[~a | ~a]"
                          (string-join elem-strs " ")
                          (pp-expr tail names))
                  ;; Proper list: '[1 2 3]
                  (format "'[~a]" (string-join elem-strs " ")))))]
         [else
          (let-values ([(func args) (flatten-app e)])
            (format "[~a]" (string-join (map (lambda (x) (pp-expr x names))
                                             (cons func args))
                                        " ")))]))]

    ;; Pair
    [(expr-pair e1 e2)
     (format "[pair ~a ~a]" (pp-expr e1 names) (pp-expr e2 names))]

    ;; Projections
    [(expr-fst e1) (format "[first ~a]" (pp-expr e1 names))]
    [(expr-snd e1) (format "[second ~a]" (pp-expr e1 names))]

    ;; Annotation
    [(expr-ann term type)
     (format "[the ~a ~a]" (pp-expr type names) (pp-expr term names))]

    ;; Equality
    [(expr-Eq t e1 e2)
     (format "[Eq ~a ~a ~a]" (pp-expr t names) (pp-expr e1 names) (pp-expr e2 names))]

    ;; Eliminators
    [(expr-boolrec mot tc fc target)
     (format "[boolrec ~a ~a ~a ~a]"
             (pp-expr mot names) (pp-expr tc names)
             (pp-expr fc names) (pp-expr target names))]
    [(expr-natrec mot base step target)
     (format "[natrec ~a ~a ~a ~a]"
             (pp-expr mot names) (pp-expr base names)
             (pp-expr step names) (pp-expr target names))]
    [(expr-J mot base left right proof)
     (format "[J ~a ~a ~a ~a ~a]"
             (pp-expr mot names) (pp-expr base names)
             (pp-expr left names) (pp-expr right names) (pp-expr proof names))]

    ;; Vec/Fin
    [(expr-Vec t n) (format "[Vec ~a ~a]" (pp-expr t names) (pp-expr n names))]
    [(expr-vnil t) (format "[vnil ~a]" (pp-expr t names))]
    [(expr-vcons t n hd tl)
     (format "[vcons ~a ~a ~a ~a]"
             (pp-expr t names) (pp-expr n names) (pp-expr hd names) (pp-expr tl names))]
    [(expr-Fin n) (format "[Fin ~a]" (pp-expr n names))]
    [(expr-fzero n) (format "[fzero ~a]" (pp-expr n names))]
    [(expr-fsuc n i) (format "[fsuc ~a ~a]" (pp-expr n names) (pp-expr i names))]
    [(expr-vhead t n v) (format "[vhead ~a ~a ~a]" (pp-expr t names) (pp-expr n names) (pp-expr v names))]
    [(expr-vtail t n v) (format "[vtail ~a ~a ~a]" (pp-expr t names) (pp-expr n names) (pp-expr v names))]
    [(expr-vindex t n i v) (format "[vindex ~a ~a ~a ~a]" (pp-expr t names) (pp-expr n names) (pp-expr i names) (pp-expr v names))]

    ;; Posit8
    [(expr-Posit8) "Posit8"]
    [(expr-posit8 v) (format "[posit8 ~a]" v)]
    [(expr-p8-add a b) (format "[p8+ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p8-sub a b) (format "[p8- ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p8-mul a b) (format "[p8* ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p8-div a b) (format "[p8/ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p8-neg a) (format "[p8-neg ~a]" (pp-expr a names))]
    [(expr-p8-abs a) (format "[p8-abs ~a]" (pp-expr a names))]
    [(expr-p8-sqrt a) (format "[p8-sqrt ~a]" (pp-expr a names))]
    [(expr-p8-lt a b) (format "[p8-lt ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p8-le a b) (format "[p8-le ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p8-from-nat n) (format "[p8-from-nat ~a]" (pp-expr n names))]
    [(expr-p8-if-nar t nc vc v)
     (format "[p8-if-nar ~a ~a ~a ~a]"
             (pp-expr t names) (pp-expr nc names) (pp-expr vc names) (pp-expr v names))]

    ;; Reduce
    [(expr-reduce scrut arms _)
     (format "[reduce ~a~a]"
             (pp-expr scrut names)
             (apply string-append
                    (map (lambda (arm)
                           (format " | ~a~a -> ~a"
                                   (expr-reduce-arm-ctor-name arm)
                                   (let ([bc (expr-reduce-arm-binding-count arm)])
                                     (if (= bc 0) ""
                                         (apply string-append
                                                (for/list ([i (in-range bc)])
                                                  (let ([n (fresh-name (+ (length names) i) names)])
                                                    (format " ~a" n))))))
                                   (pp-expr (expr-reduce-arm-body arm)
                                            ;; Push fresh names for bindings
                                            (let ([bc (expr-reduce-arm-binding-count arm)])
                                              (for/fold ([ns names])
                                                        ([i (in-range bc)])
                                                (cons (fresh-name (+ (length names) i) names) ns))))))
                         arms)))]

    ;; Fallback
    [_ (format "~a" e)]))

;; ========================================
;; Function signature pretty-printing
;; ========================================

;; Pretty-print a Pi chain as a function signature for arity error messages.
;; Groups explicit params with commas, shows implicits in braces.
;; Pi(m0, Type, Pi(mw, Nat, Pi(mw, Nat, Bool))) → "{Type} -> (Nat, Nat) -> Bool"
(define (pp-function-signature type [names '()])
  (define-values (implicits explicits result) (collect-pi-groups type names))
  (define parts '())
  (when (not (null? explicits))
    (set! parts (cons (format "(~a)" (string-join explicits ", ")) parts)))
  (when (not (null? implicits))
    (set! parts (cons (format "{~a}" (string-join implicits ", ")) parts)))
  (if (null? parts)
      (pp-expr type names)
      (string-join (append (reverse parts) (list (format "~a" result))) " -> ")))

;; Walk a Pi chain, collecting implicit and explicit parameter types as strings,
;; and return the final result type as a string.
(define (collect-pi-groups type names)
  (let loop ([ty type] [ns names] [imps '()] [exps '()])
    (match ty
      [(expr-Pi m dom cod)
       (let ([name (fresh-name (length ns) ns)]
             [dom-str (pp-expr dom ns)])
         (if (eq? m 'm0)
             (loop cod (cons name ns) (cons dom-str imps) exps)
             (loop cod (cons name ns) imps (cons dom-str exps))))]
      [_ (values (reverse imps) (reverse exps) (pp-expr ty ns))])))

;; ========================================
;; Helpers
;; ========================================

;; Try to interpret an expr as a Racket natural number (suc chain ending in zero)
(define (try-as-nat e)
  (match e
    [(expr-zero) 0]
    [(expr-suc inner)
     (let ([n (try-as-nat inner)])
       (and n (+ n 1)))]
    [_ #f]))

;; Try to interpret an expr as a cons-chain (linked list).
;; cons is a user-defined data type represented as (expr-app (expr-app (expr-fvar 'cons) head) tail).
;; nil is (expr-fvar 'nil).
;; Handles both bare names (cons, nil) and qualified names (prologos.data.list::cons, etc.)
;; Returns (list elements tail) where:
;;   - elements is a list of Expr items
;;   - tail is either #f (proper list ending in nil) or an Expr (improper tail)
;; Returns #f if the expression is not a cons-chain.

;; Check if symbol name matches 'cons or ends with '::cons' (qualified)
(define (cons-name? name)
  (or (eq? name 'cons)
      (let ([s (symbol->string name)])
        (let ([len (string-length s)])
          (and (>= len 6)
               (string=? (substring s (- len 6)) "::cons"))))))

;; Check if symbol name matches 'nil or ends with '::nil' (qualified)
(define (nil-name? name)
  (or (eq? name 'nil)
      (let ([s (symbol->string name)])
        (let ([len (string-length s)])
          (and (>= len 5)
               (string=? (substring s (- len 5)) "::nil"))))))

(define (try-as-list e)
  (let loop ([cur e] [elems '()] [depth 0])
    ;; Limit depth to avoid infinite loops on cyclic structures
    (cond
      [(> depth 1000) #f]
      ;; nil — end of proper list (bare nil or (nil A) with type arg)
      [(and (expr-fvar? cur) (nil-name? (expr-fvar-name cur)))
       (if (null? elems)
           #f   ;; bare nil — don't print as '[], just show "nil"
           (list (reverse elems) #f))]
      ;; (nil A) — nil applied to type argument
      [(and (expr-app? cur)
            (let ([func (expr-app-func cur)])
              (and (expr-fvar? func)
                   (nil-name? (expr-fvar-name func)))))
       (if (null? elems)
           #f   ;; bare (nil A) — don't print as '[]
           (list (reverse elems) #f))]
      ;; (cons head tail) — curried binary application to expr-fvar 'cons
      ;; BUT: data constructors may have implicit type params that get applied first
      ;; e.g., (cons Nat 1 (cons Nat 2 (cons Nat 3 (nil Nat))))
      ;; Detect pattern: (expr-app (expr-app (expr-fvar 'cons) type-arg) head) tail
      ;; Actually, fully applied cons is: (((cons A) head) tail) — 3 args curried
      ;; So the pattern is: expr-app(expr-app(expr-app(expr-fvar 'cons, A), head), tail)
      [(and (expr-app? cur)
            (let ([f1 (expr-app-func cur)])  ;; ((cons A) head) applied to tail
              (and (expr-app? f1)
                   (let ([f2 (expr-app-func f1)])  ;; (cons A) applied to head
                     (and (expr-app? f2)
                          (let ([f3 (expr-app-func f2)])  ;; cons applied to A
                            (and (expr-fvar? f3)
                                 (cons-name? (expr-fvar-name f3)))))))))
       ;; (((cons A) head) tail) — skip the type arg
       (define head (expr-app-arg (expr-app-func cur)))  ;; head
       (define tail (expr-app-arg cur))                   ;; tail
       (loop tail (cons head elems) (+ depth 1))]
      ;; Also handle: ((cons head) tail) — 2-arg version (no implicit type param)
      [(and (expr-app? cur)
            (let ([func (expr-app-func cur)])
              (and (expr-app? func)
                   (let ([inner-func (expr-app-func func)])
                     (and (expr-fvar? inner-func)
                          (cons-name? (expr-fvar-name inner-func)))))))
       (define head (expr-app-arg (expr-app-func cur)))
       (define tail (expr-app-arg cur))
       (loop tail (cons head elems) (+ depth 1))]
      ;; Non-nil tail (improper list) — only if we have at least one element
      [(not (null? elems))
       (list (reverse elems) cur)]
      [else #f])))

;; Check if a term uses bvar(0) — used to detect non-dependent Pi/Sigma
(define (uses-bvar0? e)
  (match e
    [(expr-bvar 0) #t]
    [(expr-bvar _) #f]
    [(expr-fvar _) #f]
    [(expr-zero) #f]
    [(expr-refl) #f]
    [(expr-Nat) #f]
    [(expr-Bool) #f]
    [(expr-true) #f]
    [(expr-false) #f]
    [(expr-Type _) #f]
    [(expr-hole) #f]
    [(expr-meta _) #f]
    [(expr-error) #f]
    [(expr-suc e1) (uses-bvar0? e1)]
    [(expr-lam _ t body) (or (uses-bvar0? t) (uses-bvar0? body))]
    [(expr-Pi _ dom cod) (or (uses-bvar0? dom) (uses-bvar0? cod))]
    [(expr-Sigma t1 t2) (or (uses-bvar0? t1) (uses-bvar0? t2))]
    [(expr-app f a) (or (uses-bvar0? f) (uses-bvar0? a))]
    [(expr-pair e1 e2) (or (uses-bvar0? e1) (uses-bvar0? e2))]
    [(expr-fst e1) (uses-bvar0? e1)]
    [(expr-snd e1) (uses-bvar0? e1)]
    [(expr-ann term type) (or (uses-bvar0? term) (uses-bvar0? type))]
    [(expr-Eq t e1 e2) (or (uses-bvar0? t) (uses-bvar0? e1) (uses-bvar0? e2))]
    [(expr-boolrec m tc fc t) (or (uses-bvar0? m) (uses-bvar0? tc) (uses-bvar0? fc) (uses-bvar0? t))]
    [(expr-natrec m b s t) (or (uses-bvar0? m) (uses-bvar0? b) (uses-bvar0? s) (uses-bvar0? t))]
    [(expr-J m b l r p) (or (uses-bvar0? m) (uses-bvar0? b) (uses-bvar0? l) (uses-bvar0? r) (uses-bvar0? p))]
    [(expr-Vec t n) (or (uses-bvar0? t) (uses-bvar0? n))]
    [(expr-vnil t) (uses-bvar0? t)]
    [(expr-vcons t n h tl) (or (uses-bvar0? t) (uses-bvar0? n) (uses-bvar0? h) (uses-bvar0? tl))]
    [(expr-Fin n) (uses-bvar0? n)]
    [(expr-fzero n) (uses-bvar0? n)]
    [(expr-fsuc n i) (or (uses-bvar0? n) (uses-bvar0? i))]
    [(expr-vhead t n v) (or (uses-bvar0? t) (uses-bvar0? n) (uses-bvar0? v))]
    [(expr-vtail t n v) (or (uses-bvar0? t) (uses-bvar0? n) (uses-bvar0? v))]
    [(expr-vindex t n i v) (or (uses-bvar0? t) (uses-bvar0? n) (uses-bvar0? i) (uses-bvar0? v))]
    [(expr-Posit8) #f]
    [(expr-posit8 _) #f]
    [(expr-p8-add a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p8-sub a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p8-mul a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p8-div a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p8-neg a) (uses-bvar0? a)]
    [(expr-p8-abs a) (uses-bvar0? a)]
    [(expr-p8-sqrt a) (uses-bvar0? a)]
    [(expr-p8-lt a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p8-le a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p8-from-nat n) (uses-bvar0? n)]
    [(expr-p8-if-nar t nc vc v) (or (uses-bvar0? t) (uses-bvar0? nc) (uses-bvar0? vc) (uses-bvar0? v))]
    [(expr-reduce scrut arms _)
     (or (uses-bvar0? scrut)
         (ormap (lambda (arm) (uses-bvar0? (expr-reduce-arm-body arm))) arms))]
    [_ #f]))

;; Flatten nested left-associative applications
(define (flatten-app e)
  (match e
    [(expr-app (expr-app _ _) arg)
     (let-values ([(func args) (flatten-app (expr-app-func e))])
       (values func (append args (list arg))))]
    [(expr-app func arg)
     (values func (list arg))]
    [_ (values e '())]))

;; ========================================
;; Pretty-print multiplicity
;; ========================================
(define (pp-mult m)
  (cond
    [(mult-meta? m) "w"]    ;; Sprint 7: unsolved mult-meta displays as unrestricted
    [else (case m
            [(m0) "0"]
            [(m1) "1"]
            [(mw) "w"]
            [else (format "~a" m)])]))

;; Multiplicity annotation for binders (old colon syntax): " : " for mw, " :0 " etc for others
(define (pp-mult-annot m)
  (cond
    [(mult-meta? m) " : "]  ;; Sprint 7: unsolved mult-meta → like mw
    [else (case m
            [(mw) " : "]
            [(m0) " :0 "]
            [(m1) " :1 "]
            [else (format " :~a " m)])]))

;; Multiplicity prefix for new angle bracket syntax: "" for mw, " :0" etc for others
(define (pp-mult-prefix m)
  (cond
    [(mult-meta? m) ""]     ;; Sprint 7: unsolved mult-meta → no prefix (like mw)
    [else (case m
            [(mw) ""]
            [(m0) " :0"]
            [(m1) " :1"]
            [else (format " :~a" m)])]))

;; ========================================
;; Pretty-print levels
;; ========================================
(define (pp-level l)
  (match l
    [(lzero) "0"]
    [(lsuc inner) (number->string (level->nat l))]
    [(level-meta _) "0"]    ;; unsolved level-meta defaults to 0 in output
    [_ (format "~a" l)]))

(define (level->nat l)
  (match l
    [(lzero) 0]
    [(lsuc inner) (+ 1 (level->nat inner))]
    [(level-meta _) 0]   ;; fallback for unsolved level-metas
    [_ 0]))

;; ========================================
;; Pretty-print session types
;; ========================================
(define (pp-session s [names '()])
  (match s
    [(sess-send t cont)
     (format "[!~a . ~a]" (pp-expr t names) (pp-session cont names))]
    [(sess-recv t cont)
     (format "[?~a . ~a]" (pp-expr t names) (pp-session cont names))]
    [(sess-dsend t cont)
     (let ([name (fresh-name (length names) names)])
       (format "[![~a <~a>] . ~a]" name (pp-expr t names) (pp-session cont (cons name names))))]
    [(sess-drecv t cont)
     (let ([name (fresh-name (length names) names)])
       (format "[?[~a <~a>] . ~a]" name (pp-expr t names) (pp-session cont (cons name names))))]
    [(sess-choice branches)
     (format "[+{ ~a }]" (pp-branches branches names))]
    [(sess-offer branches)
     (format "[&{ ~a }]" (pp-branches branches names))]
    [(sess-mu body)
     (format "[mu ~a]" (pp-session body names))]
    [(sess-svar n)
     (format "svar[~a]" n)]
    [(sess-end) "end"]
    [(sess-branch-error) "<branch-error>"]
    [_ (format "~a" s)]))

(define (pp-branches bl names)
  (string-join
   (map (lambda (b) (format "~a: ~a" (car b) (pp-session (cdr b) names)))
        bl)
   ", "))
