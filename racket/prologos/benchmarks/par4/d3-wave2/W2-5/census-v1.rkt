#lang racket/base
;; W2-5 static census (PAR 4 D.3 wave 2, CL-13).
;; S0 fire bodies -> (by module-level name call graph) -> parameter reads / assignments,
;; plus shared-state mutation sites in fire-reachable code.
;;
;; Usage: racket census.rkt <racket/prologos dir> <out-dir>
;; Scope: <root>/*.rkt and <root>/lsp/*.rkt (production). tests/ benchmarks/ tools/ examples/
;;        compiled/ data/ redex/ excluded by construction (not scanned).
;; Method (all syntactic; name-level; over-approximate):
;;  1. read-syntax every module; collect top-level defs (define, define-values,
;;     define-syntax[-rule]) with formals; parameters = defs whose rhs is (make-parameter ...).
;;  2. Fire roots: the fire-fn argument of calls to net-add-propagator (pos 3),
;;     net-add-fire-once-propagator (pos 3), net-add-broadcast-propagator (pos 4, 5),
;;     and of WRAPPERS found by fixpoint (a def whose formal flows into an adder's fire arg,
;;     or is called / passed inside the fire lambda it installs).
;;     A fire expr resolves to: a lambda (its body), a top-level fun def (whole body), a local
;;     binding (its rhs), a factory call (lambdas inside the factory body, else whole body,
;;     plus each argument as a candidate fire).
;;  3. Reach: identifiers in reached code -> top-level defs, module-aware (same module, then
;;     BFS over the require graph, then any module); iterate to fixpoint.
;;  4. In reached code: (p) = read, (p e) = direct assignment, (parameterize ([p e]) ..) =
;;     scoped binding; set-box!/hash-set!/... and set! of module-level variables.
;;  5. Global census of every production parameter's reads/assignments/bindings, classified.
(require racket/list racket/set racket/string racket/path racket/file
         syntax/modread json)

(define-values (ROOT OUT)
  (let ([v (current-command-line-arguments)])
    (values (simplify-path (path->complete-path (vector-ref v 0)))
            (simplify-path (path->complete-path (vector-ref v 1))))))
(make-directory* OUT)

(define (rkt-files dir)
  (sort (for/list ([p (directory-list dir #:build? #t)]
                   #:when (and (file-exists? p)
                               (regexp-match? #rx"[.]rkt$" (path->string p))))
          (path->string (simplify-path p)))
        string<?))
(define FILES (append (rkt-files ROOT) (rkt-files (build-path ROOT "lsp"))))

(define (short f) (let ([r (path->string ROOT)])
                    (if (string-prefix? f r) (substring f (add1 (string-length r))) f)))

;; ---------------------------------------------------------------- reading
(define (read-module f)
  (with-handlers ([exn:fail? (lambda (e) (eprintf "READ FAIL ~a: ~a\n" f (exn-message e)) #f)])
    (call-with-input-file f
      (lambda (in)
        (port-count-lines! in)
        (with-module-reading-parameterization
          (lambda () (read-syntax f in)))))))

(define (sl stx) (and (syntax? stx) (syntax->list stx)))
(define (id? stx) (and (syntax? stx) (symbol? (syntax-e stx))))
(define (sym stx) (and (id? stx) (syntax-e stx)))
(define (head stx) (let ([l (sl stx)]) (and l (pair? l) (sym (car l)))))
(define (line stx) (or (and (syntax? stx) (syntax-line stx)) 0))

(define (module-body stx)
  ;; (module name lang (#%module-begin form ...)) or (module name lang form ...)
  (define l (sl stx))
  (define forms (cdddr l))
  (if (and (= 1 (length forms)) (eq? (head (car forms)) '#%module-begin))
      (cdr (sl (car forms)))
      forms))

;; ---------------------------------------------------------------- defs
(struct def (name mod line kind formals kwformals stx rhs) #:transparent)
;; kind: 'fun 'val 'macro ; formals: list of symbols (positional) ; kwformals: hash kw -> sym
(define DEFS (make-hasheq))          ; sym -> (listof def)
(define MOD-DEFS (make-hash))        ; mod -> hasheq sym -> def
(define MOD-REQS (make-hash))        ; mod -> list of mod paths
(define MOD-TOP-EXPRS (make-hash))   ; mod -> list of stx (module-level non-def exprs)
(define PARAMS (make-hasheq))        ; sym -> list of def (rhs make-parameter)
(define make-param-sites '())        ; all (mod . line) of make-parameter calls (cross-check)

(define (parse-formals fstx)
  ;; returns (values positional-list kw-hash)
  (let loop ([x fstx] [pos '()] [kws (hasheq)])
    (define e (if (syntax? x) (syntax-e x) x))
    (cond
      [(null? e) (values (reverse pos) kws)]
      [(symbol? e) (values (reverse (cons e pos)) kws)] ; rest arg
      [(pair? e)
       (define a (car e))
       (define ae (if (syntax? a) (syntax-e a) a))
       (cond
         [(keyword? ae)
          (define nxt (cadr e))
          (define nm (if (id? nxt) (sym nxt) (let ([l (sl nxt)]) (and l (sym (car l))))))
          (loop (cddr e) pos (hash-set kws ae nm))]
         [(symbol? ae) (loop (cdr e) (cons ae pos) kws)]
         [else (define l (sl a)) (loop (cdr e) (cons (and l (sym (car l))) pos) kws)])]
      [else (values (reverse pos) kws)])))

(define (lambda-form? stx) (memq (head stx) '(lambda λ case-lambda)))

(define (add-def! d)
  (hash-update! DEFS (def-name d) (lambda (l) (cons d l)) '())
  (hash-set! (hash-ref! MOD-DEFS (def-mod d) make-hasheq) (def-name d) d))

(define (contains-head? stx h)
  (cond [(sl stx) => (lambda (l) (or (eq? (head stx) h) (ormap (lambda (x) (contains-head? x h)) l)))]
        [else #f]))

(define (collect-defs! mod forms)
  (for ([f (in-list forms)])
    (define h (head f))
    (define l (sl f))
    (case h
      [(define)
       (define target (cadr l))
       (cond
         [(id? target)
          (define rhs (and (>= (length l) 3) (caddr l)))
          (cond
            [(and rhs (memq (head rhs) '(lambda λ)))
             (define-values (pos kws) (parse-formals (cadr (sl rhs))))
             (add-def! (def (sym target) mod (line f) 'fun pos kws f rhs))]
            [(and rhs (eq? (head rhs) 'case-lambda))
             (add-def! (def (sym target) mod (line f) 'fun '() (hasheq) f rhs))]
            [else
             (define d (def (sym target) mod (line f) 'val '() (hasheq) f rhs))
             (add-def! d)
             (when (and rhs (memq (head rhs) '(make-parameter make-derived-parameter)))
               (hash-update! PARAMS (sym target) (lambda (x) (cons d x)) '()))])]
         [else
          ;; (define (name . formals) body ...) ; curried: innermost head
          (let loop ([t target])
            (define tl (syntax-e t))
            (define hd (car tl))
            (if (id? hd)
                (let-values ([(pos kws) (parse-formals (datum->syntax #f (cdr tl)))])
                  (add-def! (def (sym hd) mod (line f) 'fun pos kws f #f)))
                (loop hd)))])]
      [(define-values)
       (for ([n (in-list (sl (cadr l)))])
         (add-def! (def (sym n) mod (line f) 'val '() (hasheq) f (caddr l))))]
      [(define-syntax-rule)
       (add-def! (def (sym (car (sl (cadr l)))) mod (line f) 'macro '() (hasheq) f #f))]
      [(define-syntax)
       (define t (cadr l))
       (add-def! (def (if (id? t) (sym t) (sym (car (sl t)))) mod (line f) 'macro '() (hasheq) f #f))]
      [(begin) (collect-defs! mod (cdr l))]
      [(module+ module* module provide require struct) (void)]
      [else
       (when l (hash-update! MOD-TOP-EXPRS mod (lambda (x) (cons f x)) '()))])))

(define (collect-reqs mod forms)
  (define dir (let-values ([(base n d) (split-path mod)]) base))
  (define out '())
  (define (walk s)
    (cond [(sl s) => (lambda (l) (for-each walk l))]
          [(and (syntax? s) (string? (syntax-e s)) (regexp-match? #rx"[.]rkt$" (syntax-e s)))
           (set! out (cons (path->string (simplify-path (build-path dir (syntax-e s)))) out))]
          [else (void)]))
  (for ([f (in-list forms)] #:when (eq? (head f) 'require)) (walk f))
  (reverse out))

(define MODS
  (for/list ([f (in-list FILES)])
    (define stx (read-module f))
    (define forms (if stx (module-body stx) '()))
    (collect-defs! f forms)
    (hash-set! MOD-REQS f (collect-reqs f forms))
    (cons f forms)))

;; cross-check: textual make-parameter occurrences (non-comment)
(define (count-make-parameter)
  (for/sum ([f (in-list FILES)])
    (for/sum ([ln (in-list (file->lines f))])
      (if (regexp-match? #rx"^[^;]*make-parameter" ln) 1 0))))

;; ---------------------------------------------------------------- resolution
(define (bfs-mods start)
  (let loop ([q (list start)] [seen (set start)] [order '()])
    (if (null? q) (reverse order)
        (let* ([m (car q)]
               [nexts (for/list ([r (in-list (hash-ref MOD-REQS m '()))] #:unless (set-member? seen r)) r)])
          (loop (append (cdr q) nexts) (set-union seen (list->set nexts)) (cons m order))))))
(define BFS-CACHE (make-hash))
(define (resolve mod name)
  ;; -> (listof def)
  (define cands (hash-ref DEFS name '()))
  (cond
    [(null? cands) '()]
    [else
     (define order (hash-ref! BFS-CACHE mod (lambda () (bfs-mods mod))))
     (or (for/first ([m (in-list order)]
                     #:when (hash-ref (hash-ref MOD-DEFS m (hasheq)) name #f))
           (list (hash-ref (hash-ref MOD-DEFS m) name)))
         '())]))

;; identifiers in stx, skipping quote / quote-syntax
(define (ids-in stx [acc (mutable-seteq)])
  (let walk ([s stx])
    (cond
      [(id? s) (set-add! acc (sym s))]
      [(memq (head s) '(quote quote-syntax)) (void)]
      [(sl s) => (lambda (l) (for-each walk l))]
      [(and (syntax? s) (pair? (syntax-e s)))  ; improper list
       (let loop ([e (syntax-e s)])
         (cond [(pair? e) (walk (car e)) (loop (cdr e))]
               [(syntax? e) (walk e)]
               [else (void)]))]
      [else (void)]))
  acc)

;; ---------------------------------------------------------------- local bindings
;; find a local binding of name within a def's syntax: (define name rhs) / (define (name ..) ..) / [name rhs]
(define (find-local def-stx name)
  (let/ec k
    (let walk ([s def-stx] [top? #t])
      (define l (sl s))
      (when l
        (define h (head s))
        (cond
          [(and (eq? h 'define) (not top?) (>= (length l) 3))
           (define t (cadr l))
           (cond [(and (id? t) (eq? (sym t) name)) (k (caddr l))]
                 [(and (sl t) (pair? (sl t)) (id? (car (sl t))) (eq? (sym (car (sl t))) name)) (k s)])]
          [(memq h '(let let* letrec letrec* let-values let*-values))
           (define bl (if (id? (cadr l)) (caddr l) (cadr l)))
           (for ([b (in-list (or (sl bl) '()))])
             (define bb (sl b))
             (when (and bb (= 2 (length bb)) (id? (car bb)) (eq? (sym (car bb)) name))
               (k (cadr bb))))])
        (for ([x (in-list l)]) (walk x #f))))
    #f))


;; ---------------------------------------------------------------- expression walker
;; Visits expression positions only (skips binding clauses, patterns, quoted data).
;; on-app: called with (list-of-stx) for every application whose operator is an identifier.
;; on-bind: called with (param-id-stx rhs-stx clause-stx) for parameterize bindings.
(define LET-FORMS '(let let* letrec letrec* let-values let*-values letrec-values))
(define FOR-FORMS '(for for/list for/fold for/and for/or for/sum for/first for/hash for/hasheq
                    for/hasheqv for/vector for/set for/seteq for/last for/product for/foldr
                    for* for*/list for*/fold for*/and for*/or for*/sum for*/first for*/hash
                    for*/hasheq for*/vector for*/set for*/last))
(define (walk-expr stx on-app on-bind)
  (let walk ([s stx])
    (define l (sl s))
    (cond
      [(not l) (void)]
      [(null? l) (void)]
      [else
       (define h (head s))
       (define (walk-defaults hdr)
         (let loop ([e (and (syntax? hdr) (syntax-e hdr))])
           (cond [(pair? e)
                  (define a (car e))
                  (define al (sl a))
                  (when (and al (= 2 (length al)) (id? (car al))) (walk (cadr al)))
                  (loop (cdr e))]
                 [(syntax? e) (loop (syntax-e e))]
                 [else (void)])))
       (define (walk-clause-bodies clauses skip-first?)
         (for ([c (in-list clauses)])
           (define cl (sl c))
           (if cl (for-each walk (if (and skip-first? (pair? cl)) (cdr cl) cl)) (walk c))))
       (cond
         [(memq h '(quote quote-syntax syntax quasisyntax)) (void)]
         [(memq h '(parameterize parameterize*))
          (for ([b (in-list (or (sl (cadr l)) '()))])
            (define bb (sl b))
            (when (and bb (= 2 (length bb)))
              (on-bind (car bb) (cadr bb) b)
              (walk (cadr bb))))
          (for-each walk (cddr l))]
         [(memq h LET-FORMS)
          (define rest (cdr l))
          (define rest2 (if (and (pair? rest) (id? (car rest))) (cdr rest) rest))
          (when (pair? rest2)
            (for ([b (in-list (or (sl (car rest2)) '()))])
              (define bb (sl b))
              (if (and bb (= 2 (length bb))) (walk (cadr bb)) (void)))
            (for-each walk (cdr rest2)))]
         [(memq h FOR-FORMS)
          (define rest (cdr l))
          (define fold? (regexp-match? #rx"fold" (symbol->string h)))
          (define accs (if (and fold? (pair? rest)) (car rest) #f))
          (define rest1 (if fold? (cdr rest) rest))
          (when accs (for ([b (in-list (or (sl accs) '()))]) (define bb (sl b)) (when (and bb (= 2 (length bb))) (walk (cadr bb)))))
          (when (pair? rest1)
            (for ([b (in-list (or (sl (car rest1)) '()))])
              (define bb (sl b))
              (cond [(and bb (= 2 (length bb))) (walk (cadr bb))]
                    [(and bb (> (length bb) 2)) (walk (last bb))]
                    [else (walk b)]))
            (for-each walk (cdr rest1)))]
         [(memq h '(lambda λ))
          (walk-defaults (cadr l))
          (when (>= (length l) 3) (for-each walk (cddr l)))]
         [(eq? h 'case-lambda) (walk-clause-bodies (cdr l) #t)]
         [(eq? h 'define)
          (when (sl (cadr l)) (walk-defaults (cadr l)))
          (when (>= (length l) 3) (for-each walk (cddr l)))]
         [(memq h '(define-values define-syntax define-syntax-rule)) (when (>= (length l) 3) (walk (caddr l)))]
         [(eq? h 'cond) (walk-clause-bodies (cdr l) #f)]
         [(memq h '(case)) (when (pair? (cdr l)) (walk (cadr l)) (walk-clause-bodies (cddr l) #t))]
         [(memq h '(match match*)) (when (pair? (cdr l)) (walk (cadr l)) (walk-clause-bodies (cddr l) #t))]
         [(memq h '(match-define match-let)) (when (>= (length l) 3) (walk (caddr l)))]
         [(eq? h 'with-handlers) (when (pair? (cdr l)) (walk-clause-bodies (or (sl (cadr l)) '()) #f) (for-each walk (cddr l)))]
         [(eq? h 'struct-copy)
          (when (>= (length l) 3) (walk (caddr l))
            (for ([c (in-list (cdddr l))]) (define cl (sl c)) (when (and cl (= 2 (length cl))) (walk (cadr cl)))))]
         [else
          (when (id? (car l)) (on-app l))
          (for-each walk l)])])))

;; ---------------------------------------------------------------- adders & roots
(struct root (kind mod stx where) #:transparent) ; kind: 'lambda 'def 'local 'factory-lambda 'factory-def 'expr
(define ROOTS (make-hash))   ; key (mod . line . kind) -> root
(define ADDERS (make-hasheq)) ; sym -> list of spec: (pos i) | (kw #:k)
(hash-set! ADDERS 'net-add-propagator '((pos 3)))
(hash-set! ADDERS 'net-add-fire-once-propagator '((pos 3)))
(hash-set! ADDERS 'net-add-broadcast-propagator '((pos 4) (pos 5)))
;; merge / contradicts? / widen functions run inside net-cell-write, i.e. inside the fire under BSP
(hash-set! ADDERS 'net-new-cell '((pos 2) (pos 3)))
(hash-set! ADDERS 'net-new-cell-desc '((pos 2) (pos 3)))
(hash-set! ADDERS 'net-new-cell-widen '((pos 2) (pos 3) (pos 4) (pos 5)))
(hash-set! ADDERS 'register-merge-fn!/lattice '((pos 0)))
(define PRIMITIVE-ADDERS '(net-add-propagator net-add-fire-once-propagator net-add-broadcast-propagator
                           net-new-cell net-new-cell-desc net-new-cell-widen register-merge-fn!/lattice))
(define WRAPPER-WHY (make-hasheq)) ; sym -> string

(define (call-args l)
  ;; l = list of arg stx (after operator) -> (values positional kw-hash)
  (let loop ([xs l] [pos '()] [kws (hasheq)])
    (cond [(null? xs) (values (reverse pos) kws)]
          [(and (syntax? (car xs)) (keyword? (syntax-e (car xs))) (pair? (cdr xs)))
           (loop (cddr xs) pos (hash-set kws (syntax-e (car xs)) (cadr xs)))]
          [else (loop (cdr xs) (cons (car xs) pos) kws)])))

(define changed? #f)
(define (add-root! r)
  (define key (list (root-mod r) (line (root-stx r)) (root-kind r) (syntax-position (root-stx r))))
  (unless (hash-ref ROOTS key #f)
    (hash-set! ROOTS key r)
    (set! changed? #t)))

(define (mark-wrapper! d spec why)
  (define old (hash-ref ADDERS (def-name d) '()))
  (unless (member spec old)
    (hash-set! ADDERS (def-name d) (cons spec old))
    (hash-set! WRAPPER-WHY (def-name d) (format "~a:~a ~a" (short (def-mod d)) (def-line d) why))
    (set! changed? #t)))

(define (formal-spec d x)
  (or (for/first ([f (in-list (def-formals d))] [i (in-naturals)] #:when (eq? f x)) (list 'pos i))
      (for/first ([(k v) (in-hash (def-kwformals d))] #:when (eq? v x)) (list 'kw k))))

(define HIGHER-ORDER '(map for-each apply filter-map andmap ormap foldl foldr filter))
;; formals of d used "as a procedure" inside stx: in operator position or passed to a HOF
(define (formals-called d stx)
  (define own (if (lambda-form? stx)
                  (let-values ([(p k) (if (eq? (head stx) 'case-lambda) (values '() (hasheq))
                                          (parse-formals (cadr (sl stx))))])
                    (append p (hash-values k)))
                  '()))
  (define fs (filter (lambda (x) (not (memq x own)))
                     (append (def-formals d) (hash-values (def-kwformals d)))))
  (define out (mutable-seteq))
  (walk-expr (if (lambda-form? stx) stx (datum->syntax #f (list stx)))
             (lambda (l)
               (when (memq (sym (car l)) fs) (set-add! out (sym (car l))))
               (when (and (memq (sym (car l)) HIGHER-ORDER) (pair? (cdr l))
                          (id? (cadr l)) (memq (sym (cadr l)) fs))
                 (set-add! out (sym (cadr l)))))
             void)
  (set->list out))

(define (body-lambdas t)
  (define lams (let acc ([s (def-stx t)] [out '()])
                 (cond [(lambda-form? s) (cons s out)]
                       [(sl s) => (lambda (ll) (foldl (lambda (x o) (acc x o)) out ll))]
                       [else out])))
  (if (def-rhs t) (remq (def-rhs t) lams) lams))

;; is g's j-th positional formal called inside g's body lambdas? (g transforms that argument into the fire)
(define (transformer-arg? t j)
  (and (< j (length (def-formals t)))
       (let ([f (list-ref (def-formals t) j)])
         (for/or ([lm (in-list (body-lambdas t))])
           (memq f (formals-called t lm))))))

(define (tail-exprs e)
  ;; tail positions of a branchy form
  (define l (sl e))
  (case (head e)
    [(if) (if (>= (length l) 4) (list (caddr l) (cadddr l)) '())]
    [(cond) (for/list ([c (in-list (cdr l))] #:when (and (sl c) (pair? (sl c)))) (last (sl c)))]
    [(case match) (for/list ([c (in-list (cddr l))] #:when (and (sl c) (pair? (sl c)))) (last (sl c)))]
    [(when unless begin let let* letrec) (list (last l))]
    [(and or) (cdr l)]
    [else '()]))

(define (resolve-fire! e d mod where [depth 0])
  ;; d: enclosing top-level def (or #f for module-level), e: fire expression stx
  (when (< depth 8)
    (cond
      [(lambda-form? e)
       (add-root! (root 'lambda mod e where))
       (when d
         (for ([x (in-list (formals-called d e))])
           (define sp (formal-spec d x))
           (when sp (mark-wrapper! d sp (format "formal ~a called inside installed fire" x)))))]
      [(id? e)
       (define x (sym e))
       (define sp (and d (formal-spec d x)))
       (cond
         [sp (mark-wrapper! d sp (format "formal ~a passed as fire" x))]
         [(and d (find-local (def-stx d) x))
          => (lambda (rhs)
               (if (eq? (head rhs) 'define)
                   (begin (add-root! (root 'local mod rhs where))
                          (for ([y (in-list (formals-called d rhs))])
                            (define sp2 (formal-spec d y))
                            (when sp2 (mark-wrapper! d sp2 (format "formal ~a called in local fire ~a" y x)))))
                   (resolve-fire! rhs d mod where (add1 depth))))]
         [else
          (for ([t (in-list (resolve mod x))])
            (case (def-kind t)
              [(fun) (add-root! (root 'def (def-mod t) (def-stx t) where))]
              [(val) (when (and (def-rhs t) (not (memq (head (def-rhs t)) '(make-parameter))))
                       (resolve-fire! (def-rhs t) t (def-mod t) where (add1 depth)))]
              [else (void)]))])]
      [(memq (head e) '(if cond case match when unless begin let let* letrec and or))
       (for ([x (in-list (tail-exprs e))]) (resolve-fire! x d mod where (add1 depth)))]
      [(and (sl e) (pair? (sl e)))
       (define l (sl e))
       (define op (car l))
       (cond
         [(id? op)
          (define g (sym op))
          (define gsp (and d (formal-spec d g)))
          (when gsp (mark-wrapper! d gsp (format "formal ~a called as fire factory" g)))
          (define local-g (and d (not gsp) (find-local (def-stx d) g)))
          (cond
            [local-g (add-root! (root 'local mod local-g where))]
            [else
             (define-values (pos kws) (call-args (cdr l)))
             (for ([t (in-list (resolve mod g))] #:when (eq? (def-kind t) 'fun))
               (define bl (body-lambdas t))
               (if (null? bl)
                   (add-root! (root 'factory-def (def-mod t) (def-stx t) where))
                   (for ([lm (in-list bl)]) (add-root! (root 'factory-lambda (def-mod t) lm where))))
               ;; transformer arguments: lambdas always; identifiers only when g calls that formal in its fire
               (for ([a (in-list pos)] [j (in-naturals)])
                 (when (or (lambda-form? a)
                           (and (id? a) (transformer-arg? t j)))
                   (resolve-fire! a d mod where (add1 depth)))))])]
         [else (add-root! (root 'expr mod e where))])]
      [else (void)])))

;; scan every def and module-level expr for adder calls
(define (scan-adder-calls!)
  (for ([(mod defs) (in-hash MOD-DEFS)])
    (for ([(n d) (in-hash defs)])
      (scan-stx! (def-stx d) d mod)))
  (for ([(mod exprs) (in-hash MOD-TOP-EXPRS)])
    (for ([e (in-list exprs)]) (scan-stx! e #f mod))))

(define (scan-stx! s d mod)
  (define l (sl s))
  (when (and l (pair? l))
    (define h (head s))
    (when (and h (hash-ref ADDERS h #f)
               ;; skip the adder's own definition header
               (not (and d (eq? (def-name d) h) (eq? s (cadr (sl (def-stx d)))))))
      (define-values (pos kws) (call-args (cdr l)))
      (for ([spec (in-list (hash-ref ADDERS h))])
        (define a (case (car spec)
                    [(pos) (and (< (cadr spec) (length pos)) (list-ref pos (cadr spec)))]
                    [(kw) (hash-ref kws (cadr spec) #f)]))
        (when a
          (resolve-fire! a d mod (format "~a:~a via ~a" (short mod) (line s) h)))))
    (for ([x (in-list l)]) (scan-stx! x d mod))))

(let loop ([i 0])
  (set! changed? #f)
  (scan-adder-calls!)
  (when (and changed? (< i 20)) (loop (add1 i))))

;; ---------------------------------------------------------------- callback dispatch
;; A parameter that holds a FUNCTION dispatches: a fire that reads (p) calls whatever was
;; assigned / bound to p. Collect function-valued assignments and bindings (following
;; installer formals to their call sites).
(define PARAM-FUNS (make-hasheq))   ; sym -> list of (mod . stx)
(define INSTALLER-FORMALS '())      ; list of (param installer-def j)
(define (note-param-fun! p v mod d)
  (cond [(lambda-form? v) (hash-update! PARAMS-FUNS-proxy p (lambda (l) (cons (cons mod v) l)) '())]
        [(id? v)
         (define j (and d (formal-spec d (sym v))))
         (cond [(and j (eq? (car j) 'pos)) (set! INSTALLER-FORMALS (cons (list p d (cadr j)) INSTALLER-FORMALS))]
               [else (for ([t (in-list (resolve mod (sym v)))] #:when (eq? (def-kind t) 'fun))
                       (hash-update! PARAMS-FUNS-proxy p (lambda (l) (cons (cons (def-mod t) (def-stx t)) l)) '()))])]
        [else (void)]))
(define PARAMS-FUNS-proxy PARAM-FUNS)
(define (scan-param-funs stx mod d)
  (walk-expr stx
             (lambda (l) (define h (sym (car l)))
               (when (and (hash-ref PARAMS h #f) (= 2 (length l))) (note-param-fun! h (cadr l) mod d)))
             (lambda (pid rhs clause)
               (when (and (id? pid) (hash-ref PARAMS (sym pid) #f)) (note-param-fun! (sym pid) rhs mod d)))))
(for ([(mod defs) (in-hash MOD-DEFS)]) (for ([(n d) (in-hash defs)]) (scan-param-funs (def-stx d) mod d)))
(for ([(mod exprs) (in-hash MOD-TOP-EXPRS)]) (for ([x (in-list exprs)]) (scan-param-funs x mod #f)))
;; installer formals -> call sites
(define (scan-installer-calls! stx mod d)
  (walk-expr stx
             (lambda (l)
               (for ([pf (in-list INSTALLER-FORMALS)])
                 (define inst (cadr pf))
                 (when (eq? (sym (car l)) (def-name inst))
                   (define-values (pos kws) (call-args (cdr l)))
                   (when (< (caddr pf) (length pos))
                     (note-param-fun! (car pf) (list-ref pos (caddr pf)) mod d)))))
             void))
(let ([ifs INSTALLER-FORMALS])
  (set! INSTALLER-FORMALS ifs)
  (for ([(mod defs) (in-hash MOD-DEFS)]) (for ([(n d) (in-hash defs)]) (scan-installer-calls! (def-stx d) mod d)))
  (for ([(mod exprs) (in-hash MOD-TOP-EXPRS)]) (for ([x (in-list exprs)]) (scan-installer-calls! x mod #f))))

;; ---------------------------------------------------------------- reach
(define REACH (make-hash))   ; key -> parent (string root desc | key)
(define REGION (make-hash))  ; key -> (mod . stx) for every reached region
(define (def-key d) (cons (def-mod d) (def-name d)))
(define work '())
(define (enqueue! k mod stx parent)
  (unless (hash-ref REACH k #f)
    (hash-set! REACH k parent)
    (hash-set! REGION k (cons mod stx))
    (set! work-tail (cons k work-tail))))
(define work-tail '())
(define LOCALS-CACHE (make-hasheq))
(define (local-binders stx)
  (hash-ref! LOCALS-CACHE stx
    (lambda ()
      (define out (mutable-seteq))
      (define (add-formals! hdr)
        (let loop ([e (and (syntax? hdr) (syntax-e hdr))])
          (cond [(pair? e)
                 (define a (car e))
                 (cond [(id? a) (set-add! out (sym a))]
                       [(and (sl a) (pair? (sl a)) (id? (car (sl a)))) (set-add! out (sym (car (sl a))))])
                 (loop (cdr e))]
                [(syntax? e) (loop (syntax-e e))]
                [(symbol? e) (set-add! out e)]
                [else (void)])))
      (let walk ([s stx] [top? #t])
        (define l (sl s))
        (when (and l (pair? l))
          (define h (head s))
          (cond
            [(memq h '(lambda λ)) (add-formals! (cadr l))]
            [(and (eq? h 'define) (not top?))
             (define t (cadr l))
             (cond [(id? t) (set-add! out (sym t))]
                   [(sl t) (set-add! out (sym (car (sl t)))) (add-formals! (datum->syntax #f (cdr (sl t))))])]
            [(and (eq? h 'define) top? (sl (cadr l)))
             (add-formals! (datum->syntax #f (cdr (sl (cadr l)))))]
            [(or (memq h LET-FORMS) (memq h FOR-FORMS))
             (define rest (cdr l))
             (when (and (pair? rest) (id? (car rest))) (set-add! out (sym (car rest))))
             (define rest2 (if (and (pair? rest) (id? (car rest))) (cdr rest) rest))
             (define clause-lists (if (and (memq h FOR-FORMS) (regexp-match? #rx"fold" (symbol->string h)) (pair? rest2) (pair? (cdr rest2)))
                                      (list (car rest2) (cadr rest2))
                                      (if (pair? rest2) (list (car rest2)) '())))
             (for ([cls (in-list clause-lists)])
               (for ([b (in-list (or (sl cls) '()))])
                 (define bb (sl b))
                 (when (and bb (pair? bb))
                   (cond [(id? (car bb)) (set-add! out (sym (car bb)))]
                         [(sl (car bb)) (for ([x (in-list (sl (car bb)))]) (when (id? x) (set-add! out (sym x))))]))))])
          (for ([x (in-list l)]) (walk x #f))))
      out)))
(define (reach-from! stx mod parent)
  (define locals (local-binders stx))
  (for ([x (in-set (ids-in stx))] #:unless (set-member? locals x))
    (for ([t (in-list (resolve mod x))])
      (enqueue! (def-key t) (def-mod t) (def-stx t) parent))
    (for ([mf (in-list (hash-ref PARAM-FUNS x '()))])
      (define st (cdr mf))
      (define k (if (eq? (head st) 'define)
                    (let ([nm (let ([t (cadr (sl st))]) (if (id? t) (sym t) (sym (car (sl t)))))]) (cons (car mf) nm))
                    (cons (car mf) (format "lambda@~a:~a via ~a" (short (car mf)) (line st) x))))
      (enqueue! k (car mf) st parent))))
(for ([(k r) (in-hash ROOTS)])
  (reach-from! (root-stx r) (root-mod r)
               (format "root ~a ~a:~a (~a)" (root-kind r) (short (root-mod r)) (line (root-stx r)) (root-where r))))
(let loop ()
  (when (null? work) (set! work (reverse work-tail)) (set! work-tail '()))
  (unless (null? work)
    (define k (car work))
    (set! work (cdr work))
    (define rg (hash-ref REGION k))
    (reach-from! (cdr rg) (car rg) k)
    (loop)))

;; per-root reach: which roots reach each region (by region key), via a separate light BFS per root
(define (region-succs k)
  (hash-ref! SUCC-CACHE k
             (lambda ()
               (define rg (hash-ref REGION k))
               (succs-of (cdr rg) (car rg)))))
(define SUCC-CACHE (make-hash))
(define (succs-of stx mod)
  (define out '())
  (define locals (local-binders stx))
  (for ([x (in-set (ids-in stx))] #:unless (set-member? locals x))
    (for ([t (in-list (resolve mod x))]) (set! out (cons (def-key t) out)))
    (for ([mf (in-list (hash-ref PARAM-FUNS x '()))])
      (define st (cdr mf))
      (set! out (cons (if (eq? (head st) 'define)
                          (let ([nm (let ([t (cadr (sl st))]) (if (id? t) (sym t) (sym (car (sl t)))))]) (cons (car mf) nm))
                          (cons (car mf) (format "lambda@~a:~a via ~a" (short (car mf)) (line st) x)))
                      out))))
  (filter (lambda (k) (hash-ref REGION k #f)) out))
(define ROOT-REACHERS (make-hash)) ; region key -> set of root-module short names
(for ([(rk r) (in-hash ROOTS)])
  (define tag (short (root-mod r)))
  (define seen (make-hash))
  (let bfs ([q (succs-of (root-stx r) (root-mod r))])
    (unless (null? q)
      (define nxt '())
      (for ([k (in-list q)] #:unless (hash-ref seen k #f))
        (hash-set! seen k #t)
        (hash-update! ROOT-REACHERS k (lambda (s) (set-add s tag)) (set))
        (set! nxt (append (region-succs k) nxt)))
      (bfs nxt))))

(define (path-to k)
  (let loop ([k k] [acc '()] [n 0])
    (define p (hash-ref REACH k #f))
    (cond [(or (not p) (> n 40)) (reverse acc)]
          [(string? p) (reverse (cons p acc))]
          [else (loop p (cons (format "~a:~a" (short (car p)) (cdr p)) acc) (add1 n))])))
(define (enclosing-def-for mod stx)
  (for/first ([(n d) (in-hash (hash-ref MOD-DEFS mod (hasheq)))]
              #:when (let ([p (syntax-position stx)] [dp (syntax-position (def-stx d))] [ds (syntax-span (def-stx d))])
                       (and p dp ds (<= dp p (+ dp ds)))))
    d))

;; ---------------------------------------------------------------- uses
(struct use (kind param mod line enclosing) #:transparent) ; kind: read assign bind firstclass
(define (param? x) (hash-ref PARAMS x #f))

(define (enclosing-of d) (if d (def-name d) '<module-level>))
(define (scan-uses stx mod d emit!)
  (walk-expr stx
             (lambda (l)
               (define h (sym (car l)))
               (when (param? h)
                 (case (length l)
                   [(1) (emit! (use 'read h mod (line (car l)) (enclosing-of d)))]
                   [(2) (emit! (use 'assign h mod (line (car l)) (enclosing-of d)))]
                   [else (void)]))
               (for ([x (in-list (cdr l))])
                 (when (and (id? x) (param? (sym x)))
                   (emit! (use 'firstclass (sym x) mod (line x) (enclosing-of d))))))
             (lambda (pid rhs clause)
               (when (and (id? pid) (param? (sym pid)))
                 (emit! (use 'bind (sym pid) mod (line clause) (enclosing-of d)))))))

;; global census over every production def and module-level expr
(define ALL-USES '())
(define (emit-all! u) (set! ALL-USES (cons u ALL-USES)))
(for ([(mod defs) (in-hash MOD-DEFS)])
  (for ([(n d) (in-hash defs)])
    ;; for (define p (make-parameter ...)) the def itself is not a use
    (scan-uses (def-stx d) mod d emit-all!)))
(for ([(mod exprs) (in-hash MOD-TOP-EXPRS)])
  (for ([e (in-list exprs)]) (scan-uses e mod #f emit-all!)))

;; module-level-called installer functions (assignment inside them = "install time")
(define TOP-CALLED (mutable-seteq))
(for ([(mod exprs) (in-hash MOD-TOP-EXPRS)])
  (for ([e (in-list exprs)])
    (define h (head e))
    (when h (set-add! TOP-CALLED h))))

;; fire-reachable uses: uses inside root regions + inside reached defs
(define FIRE-USES '())
(define (emit-fire! u) (set! FIRE-USES (cons u FIRE-USES)))
(for ([(k r) (in-hash ROOTS)])
  (scan-uses (root-stx r) (root-mod r)
             (let ([enc (for/first ([(n d) (in-hash (hash-ref MOD-DEFS (root-mod r) (hasheq)))]
                                    #:when (let ([p (syntax-position (root-stx r))]
                                                 [dp (syntax-position (def-stx d))]
                                                 [ds (syntax-span (def-stx d))])
                                             (and p dp ds (<= dp p (+ dp ds)))))
                          d)])
               enc)
             emit-fire!))
(for ([(k rg) (in-hash REGION)])
  (scan-uses (cdr rg) (car rg) (enclosing-def-for (car rg) (cdr rg)) emit-fire!))

;; mutation sites in fire-reachable code
(define MUTATORS '(set-box! hash-set! hash-remove! hash-update! hash-clear! vector-set! set-mcar! set-mcdr!
                   hash-ref! box-cas! unsafe-set-box! fxvector-set! unsafe-fxvector-set! hash-set*!))
(define MUTS '())
(define (scan-muts stx mod d)
  (define mod-defs (hash-ref MOD-DEFS mod (hasheq)))
  (let walk ([s stx])
    (define l (sl s))
    (when (and l (pair? l))
      (define h (head s))
      (cond
        [(memq h '(quote quote-syntax)) (void)]
        [else
         (when (and h (or (memq h MUTATORS)
                          (and (regexp-match? #rx"^set-.*!$" (symbol->string h))
                               (not (memq h '(set-add! set-remove!))))))
           (define tgt (and (pair? (cdr l)) (cadr l)))
           (define tgt-str (if tgt (let ([o (open-output-string)]) (write (syntax->datum tgt) o)
                                     (let ([s (get-output-string o)]) (if (> (string-length s) 60) (substring s 0 60) s)))
                               ""))
           (define class
             (cond [(not tgt) 'none]
                   [(and (id? tgt) (hash-ref mod-defs (sym tgt) #f)) 'module-var]
                   [(and (id? tgt) (pair? (resolve mod (sym tgt)))
                         (not (find-local (if d (def-stx d) stx) (sym tgt)))) 'imported-var]
                   [(and (sl tgt) (= 1 (length (sl tgt))) (id? (car (sl tgt))) (param? (sym (car (sl tgt))))) 'via-param]
                   [(contains-param-read? tgt) 'via-param-expr]
                   [else 'local-or-field]))
           (set! MUTS (cons (list h class (short mod) (line s) (enclosing-of d) tgt-str) MUTS)))
         (when (and (eq? h 'set!) (pair? (cdr l)) (id? (cadr l)))
           (define x (sym (cadr l)))
           (define class (cond [(and (hash-ref mod-defs x #f)
                                     (not (and d (find-local (def-stx d) x)))) 'module-var-set!]
                               [else 'local-set!]))
           (set! MUTS (cons (list 'set! class (short mod) (line s) (enclosing-of d) (symbol->string x)) MUTS)))
         (for-each walk l)]))))
(define (contains-param-read? stx)
  (let/ec k
    (let walk ([s stx])
      (define l (sl s))
      (when (and l (= 1 (length l)) (id? (car l)) (param? (sym (car l)))) (k #t))
      (when l (for-each walk l)))
    #f))
(for ([(k r) (in-hash ROOTS)]) (scan-muts (root-stx r) (root-mod r) (enclosing-def-for (root-mod r) (root-stx r))))
(for ([(k rg) (in-hash REGION)])
  (scan-muts (cdr rg) (car rg) (enclosing-def-for (car rg) (cdr rg))))

;; ---------------------------------------------------------------- report
(define (dedupe us)
  (remove-duplicates us (lambda (a b) (and (eq? (use-kind a) (use-kind b)) (eq? (use-param a) (use-param b))
                                            (equal? (use-mod a) (use-mod b)) (= (use-line a) (use-line b))))))
(set! ALL-USES (dedupe ALL-USES))
(set! FIRE-USES (dedupe FIRE-USES))

(define (classify p)
  (define us (filter (lambda (u) (eq? (use-param u) p)) ALL-USES))
  (define binds (filter (lambda (u) (eq? (use-kind u) 'bind)) us))
  (define assigns (filter (lambda (u) (eq? (use-kind u) 'assign)) us))
  (define mod-level (filter (lambda (u) (eq? (use-enclosing u) '<module-level>)) assigns))
  (define install (filter (lambda (u) (and (not (eq? (use-enclosing u) '<module-level>))
                                           (or (set-member? TOP-CALLED (use-enclosing u))
                                               (regexp-match? #rx"^install-" (symbol->string (use-enclosing u))))))
                          assigns))
  (define per-cmd (filter (lambda (u) (not (or (memq u mod-level) (memq u install)))) assigns))
  (append (if (pair? binds) '("parameterize") '())
          (if (pair? per-cmd) '("direct(fn)") '())
          (if (pair? install) '("install-time") '())
          (if (pair? mod-level) '("module-level") '())
          (if (and (null? binds) (null? assigns)) '("never-assigned(default)") '())))

(define (fmt-sites us) (string-join (for/list ([u (in-list (sort us < #:key use-line))])
                                      (format "~a:~a(~a)" (short (use-mod u)) (use-line u) (use-enclosing u))) "; "))

(define fire-read-params
  (sort (remove-duplicates (for/list ([u (in-list FIRE-USES)] #:when (eq? (use-kind u) 'read)) (use-param u)))
        symbol<?))

(with-output-to-file (build-path OUT "census-summary.txt") #:exists 'replace
  (lambda ()
    (printf "W2-5 static census at ROOT=~a\n" ROOT)
    (printf "files scanned: ~a ; top-level defs: ~a ; parameters (define p (make-parameter..)): ~a ; textual non-comment make-parameter lines: ~a\n"
            (length FILES) (for/sum ([(k v) (in-hash DEFS)]) (length v))
            (for/sum ([(k v) (in-hash PARAMS)]) (length v)) (count-make-parameter))
    (printf "adders (primitive + wrappers by fixpoint): ~a\n" (hash-count ADDERS))
    (for ([(k v) (in-hash ADDERS)]) (printf "  ADDER ~a ~s ~a\n" k v (hash-ref WRAPPER-WHY k "primitive")))
    (printf "fire roots: ~a  (by kind: ~a)\n" (hash-count ROOTS)
            (let ([h (make-hasheq)]) (for ([(k r) (in-hash ROOTS)]) (hash-update! h (root-kind r) add1 0)) h))
    (printf "reached top-level defs: ~a\n" (hash-count REACH))
    (printf "\n== GLOBAL: production reads per parameter of interest ==\n")
    (for ([p (in-list '(current-source-loc current-worldview-bitmask current-bsp-fire-round? current-cell-id-namespace))])
      (define us (filter (lambda (u) (eq? (use-param u) p)) ALL-USES))
      (for ([k (in-list '(read assign bind firstclass))])
        (define uk (filter (lambda (u) (eq? (use-kind u) k)) us))
        (printf "  ~a ~a ~a: ~a\n" p k (length uk) (fmt-sites uk))))
    (printf "\n== FIRE-REACHABLE parameter READS: ~a parameters ==\n" (length fire-read-params))
    (for ([p (in-list fire-read-params)])
      (define fr (filter (lambda (u) (and (eq? (use-param u) p) (eq? (use-kind u) 'read))) FIRE-USES))
      (define d (car (hash-ref PARAMS p)))
      (define reachers
        (for/fold ([s (set)]) ([u (in-list fr)])
          (set-union s (hash-ref ROOT-REACHERS (cons (use-mod u) (use-enclosing u))
                                 (lambda () (set (format "direct-in-root:~a" (short (use-mod u)))))))))
      (printf "~a | def ~a:~a | assigned: ~a | fire-reads ~a: ~a | reached-from-root-modules: ~a\n" p (short (def-mod d)) (def-line d)
              (string-join (classify p) ",") (length fr) (fmt-sites fr) (string-join (sort (set->list reachers) string<?) ",")))
    (printf "\n== FIRE-REACHABLE parameter ASSIGNMENTS (p v) ==\n")
    (for ([u (in-list (sort (filter (lambda (u) (eq? (use-kind u) 'assign)) FIRE-USES) string<? #:key (lambda (u) (format "~a~a" (use-param u) (use-line u)))))])
      (printf "  ~a ~a:~a in ~a\n" (use-param u) (short (use-mod u)) (use-line u) (use-enclosing u)))
    (printf "\n== FIRE-REACHABLE parameterize BINDINGS ==\n")
    (for ([u (in-list (sort (filter (lambda (u) (eq? (use-kind u) 'bind)) FIRE-USES) string<? #:key (lambda (u) (format "~a~a" (use-param u) (use-line u)))))])
      (printf "  ~a ~a:~a in ~a\n" (use-param u) (short (use-mod u)) (use-line u) (use-enclosing u)))
    (printf "\n== FIRE-REACHABLE MUTATION SITES (non-local) ==\n")
    (for ([m (in-list (sort (remove-duplicates MUTS) string<? #:key (lambda (m) (format "~a ~a ~a" (cadr m) (caddr m) (cadddr m)))))]
          #:unless (memq (cadr m) '(local-or-field local-set! none)))
      (printf "  ~a\n" m))
    (printf "\n== FIRE-REACHABLE MUTATION SITES (local-or-field; review) count: ~a ==\n"
            (length (filter (lambda (m) (memq (cadr m) '(local-or-field local-set!))) (remove-duplicates MUTS))))
    (for ([m (in-list (sort (remove-duplicates MUTS) string<? #:key (lambda (m) (format "~a ~a ~a" (cadr m) (caddr m) (cadddr m)))))]
          #:when (memq (cadr m) '(local-or-field)))
      (printf "  ~a\n" m))))

;; per-parameter full table (all production parameters)
(with-output-to-file (build-path OUT "census-params.tsv") #:exists 'replace
  (lambda ()
    (printf "param\tdef\tassigned\tn_read_all\tn_read_fire\tbind_sites\tassign_sites\tfire_read_sites\n")
    (for ([p (in-list (sort (hash-keys PARAMS) symbol<?))])
      (define d (car (hash-ref PARAMS p)))
      (define us (filter (lambda (u) (eq? (use-param u) p)) ALL-USES))
      (define fr (filter (lambda (u) (and (eq? (use-param u) p) (eq? (use-kind u) 'read))) FIRE-USES))
      (printf "~a\t~a:~a\t~a\t~a\t~a\t~a\t~a\t~a\n" p (short (def-mod d)) (def-line d) (string-join (classify p) ",")
              (length (filter (lambda (u) (eq? (use-kind u) 'read)) us)) (length fr)
              (fmt-sites (filter (lambda (u) (eq? (use-kind u) 'bind)) us))
              (fmt-sites (filter (lambda (u) (eq? (use-kind u) 'assign)) us))
              (fmt-sites fr)))))

;; witness paths for fire reads
(with-output-to-file (build-path OUT "census-paths.txt") #:exists 'replace
  (lambda ()
    (for ([p (in-list fire-read-params)])
      (define fr (filter (lambda (u) (and (eq? (use-param u) p) (eq? (use-kind u) 'read))) FIRE-USES))
      (for ([u (in-list fr)])
        (define k (cons (use-mod u) (use-enclosing u)))
        (printf "~a @ ~a:~a  path: ~a\n" p (short (use-mod u)) (use-line u)
                (string-join (reverse (path-to k)) " <- "))))))

;; roots list
(with-output-to-file (build-path OUT "census-roots.txt") #:exists 'replace
  (lambda ()
    (for ([r (in-list (sort (hash-values ROOTS) string<? #:key (lambda (r) (format "~a~a" (short (root-mod r)) (line (root-stx r))))))])
      (printf "~a ~a:~a  ~a\n" (root-kind r) (short (root-mod r)) (line (root-stx r)) (root-where r)))))
(printf "done; see ~a\n" OUT)
