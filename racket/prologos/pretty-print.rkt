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
         "processes.rkt"
         "metavar-store.rkt"
         "champ.rkt"
         "rrb.rkt"
         "propagator.rkt"
         "union-find.rkt"
         "atms.rkt"
         "tabling.rkt")

(provide pp-expr
         pp-session
         pp-process
         pp-mult
         pp-function-signature
         pp-datum)

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
    [(expr-zero) "0N"]
    [(expr-nat-val n) (format "~aN" n)]
    [(expr-refl) "refl"]
    [(expr-Nat) "Nat"]
    [(expr-Bool) "Bool"]
    [(expr-true) "true"]
    [(expr-false) "false"]
    [(expr-Unit) "Unit"]
    [(expr-unit) "unit"]
    [(expr-Nil) "Nil"]
    [(expr-nil) "nil"]
    [(expr-hole) "_"]
    [(expr-typed-hole name) (if name (format "??~a" name) "??")]
    [(expr-meta id)
     (let ([sol (meta-solution id)])
       (if sol
           (pp-expr sol names)
           (format "?~a" id)))]
    [(expr-error) "<error>"]

    ;; Unapplied type constructor (HKT)
    [(expr-tycon name) (symbol->string name)]

    ;; Universes
    [(expr-Type l) (format "[Type ~a]" (pp-level l))]

    ;; Successor — detect numeric literals
    [(expr-suc _)
     (let ([n (try-as-nat e)])
       (if n
           (format "~aN" n)
           (format "[suc ~a]" (pp-expr (expr-suc-pred e) names))))]

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

    ;; Application — check for lseq-cell chain, cons-chain, then flatten nested apps
    [(expr-app _ _)
     (let ([lseq-result (try-as-lseq e)])
       (cond
         [lseq-result
          (let ([elem-strs (map (lambda (x) (pp-expr x names)) lseq-result)])
            (format "~~[~a]" (string-join elem-strs " ")))]
         [else
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
                                             " ")))]))]))]

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
    [(expr-p8-eq a b) (format "[p8-eq ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p8-from-nat n) (format "[p8-from-nat ~a]" (pp-expr n names))]
    [(expr-p8-to-rat a) (format "[p8-to-rat ~a]" (pp-expr a names))]
    [(expr-p8-from-rat a) (format "[p8-from-rat ~a]" (pp-expr a names))]
    [(expr-p8-from-int a) (format "[p8-from-int ~a]" (pp-expr a names))]
    [(expr-p8-if-nar t nc vc v)
     (format "[p8-if-nar ~a ~a ~a ~a]"
             (pp-expr t names) (pp-expr nc names) (pp-expr vc names) (pp-expr v names))]

    ;; Posit16
    [(expr-Posit16) "Posit16"]
    [(expr-posit16 v) (format "[posit16 ~a]" v)]
    [(expr-p16-add a b) (format "[p16+ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p16-sub a b) (format "[p16- ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p16-mul a b) (format "[p16* ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p16-div a b) (format "[p16/ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p16-neg a) (format "[p16-neg ~a]" (pp-expr a names))]
    [(expr-p16-abs a) (format "[p16-abs ~a]" (pp-expr a names))]
    [(expr-p16-sqrt a) (format "[p16-sqrt ~a]" (pp-expr a names))]
    [(expr-p16-lt a b) (format "[p16-lt ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p16-le a b) (format "[p16-le ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p16-eq a b) (format "[p16-eq ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p16-from-nat n) (format "[p16-from-nat ~a]" (pp-expr n names))]
    [(expr-p16-to-rat a) (format "[p16-to-rat ~a]" (pp-expr a names))]
    [(expr-p16-from-rat a) (format "[p16-from-rat ~a]" (pp-expr a names))]
    [(expr-p16-from-int a) (format "[p16-from-int ~a]" (pp-expr a names))]
    [(expr-p16-if-nar t nc vc v)
     (format "[p16-if-nar ~a ~a ~a ~a]"
             (pp-expr t names) (pp-expr nc names) (pp-expr vc names) (pp-expr v names))]

    ;; Posit32
    [(expr-Posit32) "Posit32"]
    [(expr-posit32 v) (format "[posit32 ~a]" v)]
    [(expr-p32-add a b) (format "[p32+ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p32-sub a b) (format "[p32- ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p32-mul a b) (format "[p32* ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p32-div a b) (format "[p32/ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p32-neg a) (format "[p32-neg ~a]" (pp-expr a names))]
    [(expr-p32-abs a) (format "[p32-abs ~a]" (pp-expr a names))]
    [(expr-p32-sqrt a) (format "[p32-sqrt ~a]" (pp-expr a names))]
    [(expr-p32-lt a b) (format "[p32-lt ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p32-le a b) (format "[p32-le ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p32-eq a b) (format "[p32-eq ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p32-from-nat n) (format "[p32-from-nat ~a]" (pp-expr n names))]
    [(expr-p32-to-rat a) (format "[p32-to-rat ~a]" (pp-expr a names))]
    [(expr-p32-from-rat a) (format "[p32-from-rat ~a]" (pp-expr a names))]
    [(expr-p32-from-int a) (format "[p32-from-int ~a]" (pp-expr a names))]
    [(expr-p32-if-nar t nc vc v)
     (format "[p32-if-nar ~a ~a ~a ~a]"
             (pp-expr t names) (pp-expr nc names) (pp-expr vc names) (pp-expr v names))]

    ;; Posit64
    [(expr-Posit64) "Posit64"]
    [(expr-posit64 v) (format "[posit64 ~a]" v)]
    [(expr-p64-add a b) (format "[p64+ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p64-sub a b) (format "[p64- ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p64-mul a b) (format "[p64* ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p64-div a b) (format "[p64/ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p64-neg a) (format "[p64-neg ~a]" (pp-expr a names))]
    [(expr-p64-abs a) (format "[p64-abs ~a]" (pp-expr a names))]
    [(expr-p64-sqrt a) (format "[p64-sqrt ~a]" (pp-expr a names))]
    [(expr-p64-lt a b) (format "[p64-lt ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p64-le a b) (format "[p64-le ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p64-eq a b) (format "[p64-eq ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-p64-from-nat n) (format "[p64-from-nat ~a]" (pp-expr n names))]
    [(expr-p64-to-rat a) (format "[p64-to-rat ~a]" (pp-expr a names))]
    [(expr-p64-from-rat a) (format "[p64-from-rat ~a]" (pp-expr a names))]
    [(expr-p64-from-int a) (format "[p64-from-int ~a]" (pp-expr a names))]
    [(expr-p64-if-nar t nc vc v)
     (format "[p64-if-nar ~a ~a ~a ~a]"
             (pp-expr t names) (pp-expr nc names) (pp-expr vc names) (pp-expr v names))]

    ;; Quire8
    [(expr-Quire8) "Quire8"]
    [(expr-quire8-val v) (format "[quire8-val ~a]" v)]
    [(expr-quire8-fma q a b) (format "[q8-fma ~a ~a ~a]" (pp-expr q names) (pp-expr a names) (pp-expr b names))]
    [(expr-quire8-to q) (format "[q8-to ~a]" (pp-expr q names))]

    ;; Quire16
    [(expr-Quire16) "Quire16"]
    [(expr-quire16-val v) (format "[quire16-val ~a]" v)]
    [(expr-quire16-fma q a b) (format "[q16-fma ~a ~a ~a]" (pp-expr q names) (pp-expr a names) (pp-expr b names))]
    [(expr-quire16-to q) (format "[q16-to ~a]" (pp-expr q names))]

    ;; Quire32
    [(expr-Quire32) "Quire32"]
    [(expr-quire32-val v) (format "[quire32-val ~a]" v)]
    [(expr-quire32-fma q a b) (format "[q32-fma ~a ~a ~a]" (pp-expr q names) (pp-expr a names) (pp-expr b names))]
    [(expr-quire32-to q) (format "[q32-to ~a]" (pp-expr q names))]

    ;; Quire64
    [(expr-Quire64) "Quire64"]
    [(expr-quire64-val v) (format "[quire64-val ~a]" v)]
    [(expr-quire64-fma q a b) (format "[q64-fma ~a ~a ~a]" (pp-expr q names) (pp-expr a names) (pp-expr b names))]
    [(expr-quire64-to q) (format "[q64-to ~a]" (pp-expr q names))]

    ;; Symbol
    [(expr-Symbol) "Symbol"]
    [(expr-symbol name) (format "'~a" name)]
    ;; Keyword
    [(expr-Keyword) "Keyword"]
    [(expr-keyword name) (format ":~a" name)]
    ;; Char
    [(expr-Char) "Char"]
    [(expr-char val)
     (cond
       [(char=? val #\newline) "\\newline"]
       [(char=? val #\space)   "\\space"]
       [(char=? val #\tab)     "\\tab"]
       [(char=? val #\return)  "\\return"]
       [else (format "\\~a" val)])]
    ;; String
    [(expr-String) "String"]
    [(expr-string val) (format "~s" val)]
    ;; Map
    [(expr-Map k v) (format "(Map ~a ~a)" (pp-expr k names) (pp-expr v names))]
    [(expr-champ c) "{map ...}"]
    [(expr-map-empty k v) (format "{} : (Map ~a ~a)" (pp-expr k names) (pp-expr v names))]
    [(expr-map-assoc m k v) (format "[map-assoc ~a ~a ~a]" (pp-expr m names) (pp-expr k names) (pp-expr v names))]
    [(expr-map-get m k) (format "[map-get ~a ~a]" (pp-expr m names) (pp-expr k names))]
    [(expr-nil-safe-get m k) (format "[nil-safe-get ~a ~a]" (pp-expr m names) (pp-expr k names))]
    [(expr-nil-check a) (format "[nil? ~a]" (pp-expr a names))]
    [(expr-map-dissoc m k) (format "[map-dissoc ~a ~a]" (pp-expr m names) (pp-expr k names))]
    [(expr-map-size m) (format "[map-size ~a]" (pp-expr m names))]
    [(expr-map-has-key m k) (format "[map-has-key? ~a ~a]" (pp-expr m names) (pp-expr k names))]
    [(expr-map-keys m) (format "[map-keys ~a]" (pp-expr m names))]
    [(expr-map-vals m) (format "[map-vals ~a]" (pp-expr m names))]
    ;; Set
    [(expr-Set a) (format "(Set ~a)" (pp-expr a names))]
    [(expr-hset c)
     (let ([keys (champ-keys c)])
       (if (null? keys)
           "#{}"
           (format "#{~a}" (string-join (map (lambda (k) (pp-expr k names)) keys) " "))))]
    [(expr-set-empty a) (format "(set-empty ~a)" (pp-expr a names))]
    [(expr-set-insert s a) (format "(set-insert ~a ~a)" (pp-expr s names) (pp-expr a names))]
    [(expr-set-member s a) (format "(set-member? ~a ~a)" (pp-expr s names) (pp-expr a names))]
    [(expr-set-delete s a) (format "(set-delete ~a ~a)" (pp-expr s names) (pp-expr a names))]
    [(expr-set-size s) (format "(set-size ~a)" (pp-expr s names))]
    [(expr-set-union s1 s2) (format "(set-union ~a ~a)" (pp-expr s1 names) (pp-expr s2 names))]
    [(expr-set-intersect s1 s2) (format "(set-intersect ~a ~a)" (pp-expr s1 names) (pp-expr s2 names))]
    [(expr-set-diff s1 s2) (format "(set-diff ~a ~a)" (pp-expr s1 names) (pp-expr s2 names))]
    [(expr-set-to-list s) (format "(set-to-list ~a)" (pp-expr s names))]

    ;; PVec
    [(expr-PVec a) (format "(PVec ~a)" (pp-expr a names))]
    [(expr-rrb r)
     (let ([elems (reverse (rrb-fold r (lambda (v acc) (cons (pp-expr v names) acc)) '()))])
       (if (null? elems)
           "@[]"
           (string-append "@[" (string-join elems " ") "]")))]
    [(expr-pvec-empty a) (format "@[] : (PVec ~a)" (pp-expr a names))]
    [(expr-pvec-push v x) (format "[pvec-push ~a ~a]" (pp-expr v names) (pp-expr x names))]
    [(expr-pvec-fold f init vec) (format "[pvec-fold ~a ~a ~a]" (pp-expr f names) (pp-expr init names) (pp-expr vec names))]
    [(expr-pvec-map f vec) (format "[pvec-map ~a ~a]" (pp-expr f names) (pp-expr vec names))]
    [(expr-pvec-filter pred vec) (format "[pvec-filter ~a ~a]" (pp-expr pred names) (pp-expr vec names))]
    [(expr-set-fold f init set) (format "[set-fold ~a ~a ~a]" (pp-expr f names) (pp-expr init names) (pp-expr set names))]
    [(expr-set-filter pred set) (format "[set-filter ~a ~a]" (pp-expr pred names) (pp-expr set names))]
    [(expr-map-fold-entries f init map) (format "[map-fold-entries ~a ~a ~a]" (pp-expr f names) (pp-expr init names) (pp-expr map names))]
    [(expr-map-filter-entries pred map) (format "[map-filter-entries ~a ~a]" (pp-expr pred names) (pp-expr map names))]
    [(expr-map-map-vals f map) (format "[map-map-vals ~a ~a]" (pp-expr f names) (pp-expr map names))]
    [(expr-pvec-nth v i) (format "[pvec-nth ~a ~a]" (pp-expr v names) (pp-expr i names))]
    [(expr-pvec-update v i x) (format "[pvec-update ~a ~a ~a]" (pp-expr v names) (pp-expr i names) (pp-expr x names))]
    [(expr-pvec-length v) (format "[pvec-length ~a]" (pp-expr v names))]
    [(expr-pvec-to-list v) (format "[pvec-to-list ~a]" (pp-expr v names))]
    [(expr-pvec-from-list v) (format "[pvec-from-list ~a]" (pp-expr v names))]
    [(expr-pvec-pop v) (format "[pvec-pop ~a]" (pp-expr v names))]
    [(expr-pvec-concat v1 v2) (format "[pvec-concat ~a ~a]" (pp-expr v1 names) (pp-expr v2 names))]
    [(expr-pvec-slice v lo hi) (format "[pvec-slice ~a ~a ~a]" (pp-expr v names) (pp-expr lo names) (pp-expr hi names))]

    ;; Transient Builders
    [(expr-transient c) (format "[transient ~a]" (pp-expr c names))]
    [(expr-persist c) (format "[persist! ~a]" (pp-expr c names))]
    [(expr-TVec a) (format "(TVec ~a)" (pp-expr a names))]
    [(expr-TMap k v) (format "(TMap ~a ~a)" (pp-expr k names) (pp-expr v names))]
    [(expr-TSet a) (format "(TSet ~a)" (pp-expr a names))]
    [(expr-trrb _) "~trrb[...]"]
    [(expr-tchamp _) "~tchamp{...}"]
    [(expr-thset _) "~thset#{...}"]
    [(expr-transient-vec v) (format "[transient ~a]" (pp-expr v names))]
    [(expr-persist-vec t) (format "[persist! ~a]" (pp-expr t names))]
    [(expr-transient-map m) (format "[transient ~a]" (pp-expr m names))]
    [(expr-persist-map t) (format "[persist! ~a]" (pp-expr t names))]
    [(expr-transient-set s) (format "[transient ~a]" (pp-expr s names))]
    [(expr-persist-set t) (format "[persist! ~a]" (pp-expr t names))]
    [(expr-tvec-push! t x) (format "[tvec-push! ~a ~a]" (pp-expr t names) (pp-expr x names))]
    [(expr-tvec-update! t i x) (format "[tvec-update! ~a ~a ~a]" (pp-expr t names) (pp-expr i names) (pp-expr x names))]
    [(expr-tmap-assoc! t k v) (format "[tmap-assoc! ~a ~a ~a]" (pp-expr t names) (pp-expr k names) (pp-expr v names))]
    [(expr-tmap-dissoc! t k) (format "[tmap-dissoc! ~a ~a]" (pp-expr t names) (pp-expr k names))]
    [(expr-tset-insert! t a) (format "[tset-insert! ~a ~a]" (pp-expr t names) (pp-expr a names))]
    [(expr-tset-delete! t a) (format "[tset-delete! ~a ~a]" (pp-expr t names) (pp-expr a names))]
    ;; Panic
    [(expr-panic msg) (format "(panic ~a)" (pp-expr msg names))]

    ;; PropNetwork
    [(expr-net-type) "PropNetwork"]
    [(expr-cell-id-type) "CellId"]
    [(expr-prop-id-type) "PropId"]
    [(expr-prop-network v) (format "#<prop-network ~a>" (prop-network-fuel v))]
    [(expr-cell-id v) (format "#<cell-id ~a>" (cell-id-n v))]
    [(expr-prop-id v) (format "#<prop-id ~a>" (prop-id-n v))]
    [(expr-net-new fuel) (format "[net-new ~a]" (pp-expr fuel names))]
    [(expr-net-new-cell n init merge)
     (format "[net-new-cell ~a ~a ~a]" (pp-expr n names) (pp-expr init names) (pp-expr merge names))]
    [(expr-net-new-cell-widen n init merge wf nf)
     (format "[net-new-cell-widen ~a ~a ~a ~a ~a]"
             (pp-expr n names) (pp-expr init names) (pp-expr merge names)
             (pp-expr wf names) (pp-expr nf names))]
    [(expr-net-cell-read n c) (format "[net-cell-read ~a ~a]" (pp-expr n names) (pp-expr c names))]
    [(expr-net-cell-write n c v)
     (format "[net-cell-write ~a ~a ~a]" (pp-expr n names) (pp-expr c names) (pp-expr v names))]
    [(expr-net-add-prop n ins outs fn)
     (format "[net-add-prop ~a ~a ~a ~a]"
             (pp-expr n names) (pp-expr ins names) (pp-expr outs names) (pp-expr fn names))]
    [(expr-net-run n) (format "[net-run ~a]" (pp-expr n names))]
    [(expr-net-snapshot n) (format "[net-snapshot ~a]" (pp-expr n names))]
    [(expr-net-contradiction n) (format "[net-contradict? ~a]" (pp-expr n names))]

    ;; UnionFind
    [(expr-uf-type) "UnionFind"]
    [(expr-uf-store v) (format "#<union-find ~a>" (uf-size v))]
    [(expr-uf-empty) "[uf-empty]"]
    [(expr-uf-make-set st id val)
     (format "[uf-make-set ~a ~a ~a]" (pp-expr st names) (pp-expr id names) (pp-expr val names))]
    [(expr-uf-find st id)
     (format "[uf-find ~a ~a]" (pp-expr st names) (pp-expr id names))]
    [(expr-uf-union st id1 id2)
     (format "[uf-union ~a ~a ~a]" (pp-expr st names) (pp-expr id1 names) (pp-expr id2 names))]
    [(expr-uf-value st id)
     (format "[uf-value ~a ~a]" (pp-expr st names) (pp-expr id names))]

    ;; ATMS
    [(expr-atms-type) "ATMS"]
    [(expr-assumption-id-type) "AssumptionId"]
    [(expr-atms-store v)
     (format "#<atms ~a>" (hash-count (atms-assumptions v)))]
    [(expr-assumption-id-val v)
     (format "#<assumption-id ~a>" (assumption-id-n v))]
    [(expr-atms-new net) (format "[atms-new ~a]" (pp-expr net names))]
    [(expr-atms-assume a nm d)
     (format "[atms-assume ~a ~a ~a]" (pp-expr a names) (pp-expr nm names) (pp-expr d names))]
    [(expr-atms-retract a aid)
     (format "[atms-retract ~a ~a]" (pp-expr a names) (pp-expr aid names))]
    [(expr-atms-nogood a aids)
     (format "[atms-nogood ~a ~a]" (pp-expr a names) (pp-expr aids names))]
    [(expr-atms-amb a alts)
     (format "[atms-amb ~a ~a]" (pp-expr a names) (pp-expr alts names))]
    [(expr-atms-solve-all a g)
     (format "[atms-solve-all ~a ~a]" (pp-expr a names) (pp-expr g names))]
    [(expr-atms-read a c)
     (format "[atms-read ~a ~a]" (pp-expr a names) (pp-expr c names))]
    [(expr-atms-write a c v s)
     (format "[atms-write ~a ~a ~a ~a]" (pp-expr a names) (pp-expr c names) (pp-expr v names) (pp-expr s names))]
    [(expr-atms-consistent a aids)
     (format "[atms-consistent? ~a ~a]" (pp-expr a names) (pp-expr aids names))]
    [(expr-atms-worldview a aids)
     (format "[atms-worldview ~a ~a]" (pp-expr a names) (pp-expr aids names))]

    ;; Tabling
    [(expr-table-store-type) "TableStore"]
    [(expr-table-store-val v)
     (format "#<table-store ~a>" (hash-count (table-store-tables v)))]
    ;; Opaque FFI values
    [(expr-opaque v tag) (format "#<opaque:~a>" tag)]
    [(expr-table-new net)
     (format "[table-new ~a]" (pp-expr net names))]
    [(expr-table-register s n m)
     (format "[table-register ~a ~a ~a]" (pp-expr s names) (pp-expr n names) (pp-expr m names))]
    [(expr-table-add s n a)
     (format "[table-add ~a ~a ~a]" (pp-expr s names) (pp-expr n names) (pp-expr a names))]
    [(expr-table-answers s n)
     (format "[table-answers ~a ~a]" (pp-expr s names) (pp-expr n names))]
    [(expr-table-freeze s n)
     (format "[table-freeze ~a ~a]" (pp-expr s names) (pp-expr n names))]
    [(expr-table-complete s n)
     (format "[table-complete? ~a ~a]" (pp-expr s names) (pp-expr n names))]
    [(expr-table-run s)
     (format "[table-run ~a]" (pp-expr s names))]
    [(expr-table-lookup s n a)
     (format "[table-lookup ~a ~a ~a]" (pp-expr s names) (pp-expr n names) (pp-expr a names))]

    ;; Relational language (Phase 7)
    [(expr-solver-type) "Solver"]
    [(expr-goal-type) "Goal"]
    [(expr-derivation-type) "DerivationTree"]
    [(expr-cut) "cut"]
    [(expr-schema-type n) (format "(Schema ~a)" n)]
    [(expr-answer-type t)
     (if t (format "(Answer ~a)" (pp-expr t names)) "Answer")]
    [(expr-relation-type pts)
     (format "(Relation ~a)" (string-join (map (lambda (p) (pp-expr p names)) pts) " "))]
    [(expr-solver-config m)
     (format "(solver-config ~a)" (pp-expr m names))]
    [(expr-logic-var name mode)
     (if mode (format "~a~a" (case mode [(free) "?"] [(in) "+"] [(out) "-"] [else "?"]) name)
         (symbol->string name))]
    [(expr-defr nm sc vs)
     (format "(defr ~a ...~a variants)" nm (length vs))]
    [(expr-defr-variant ps bd)
     (format "(variant [~a] ~a)" (length ps) (string-join (map (lambda (b) (pp-expr b names)) bd) " "))]
    [(expr-rel ps cls)
     (format "(rel [~a] ...)" (length ps))]
    [(expr-clause gs)
     (format "(&> ~a)" (string-join (map (lambda (g) (pp-expr g names)) gs) " "))]
    [(expr-fact-block rs)
     (format "(|| ~a rows)" (length rs))]
    [(expr-fact-row ts)
     (format "(fact ~a)" (string-join (map (lambda (t) (pp-expr t names)) ts) " "))]
    [(expr-goal-app nm as)
     (format "(~a ~a)" (pp-expr nm names) (string-join (map (lambda (a) (pp-expr a names)) as) " "))]
    [(expr-unify-goal l r)
     (format "(= ~a ~a)" (pp-expr l names) (pp-expr r names))]
    [(expr-is-goal v ex)
     (format "(is ~a ~a)" (pp-expr v names) (pp-expr ex names))]
    [(expr-not-goal g)
     (format "(not ~a)" (pp-expr g names))]
    [(expr-schema nm fs)
     (format "(schema ~a ~a fields)" nm (length fs))]
    [(expr-solve g)
     (format "(solve ~a)" (pp-expr g names))]
    [(expr-solve-with sv ov g)
     (format "(solve-with ~a ~a ~a)"
             (if sv (pp-expr sv names) "#f") (if ov (pp-expr ov names) "#f") (pp-expr g names))]
    [(expr-solve-one g)
     (format "(solve-one ~a)" (pp-expr g names))]
    [(expr-explain g)
     (format "(explain ~a)" (pp-expr g names))]
    [(expr-explain-with sv ov g)
     (format "(explain-with ~a ~a ~a)"
             (if sv (pp-expr sv names) "#f") (if ov (pp-expr ov names) "#f") (pp-expr g names))]
    [(expr-narrow func args target vars)
     (format "(narrow ~a [~a] = ~a)"
             (pp-expr func names)
             (string-join (map (lambda (a) (pp-expr a names)) args) " ")
             (pp-expr target names))]
    [(expr-guard cond goal)
     (format "(guard ~a ~a)" (pp-expr cond names) (pp-expr goal names))]

    ;; Int
    [(expr-Int) "Int"]
    [(expr-int v) (number->string v)]
    [(expr-int-add a b) (format "[int+ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-int-sub a b) (format "[int- ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-int-mul a b) (format "[int* ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-int-div a b) (format "[int/ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-int-mod a b) (format "[int-mod ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-int-neg a) (format "[int-neg ~a]" (pp-expr a names))]
    [(expr-int-abs a) (format "[int-abs ~a]" (pp-expr a names))]
    [(expr-int-lt a b) (format "[int< ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-int-le a b) (format "[int<= ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-int-eq a b) (format "[int= ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-from-nat n) (format "[from-nat ~a]" (pp-expr n names))]

    ;; Rat
    [(expr-Rat) "Rat"]
    [(expr-rat v) (number->string v)]
    [(expr-rat-add a b) (format "[rat+ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-rat-sub a b) (format "[rat- ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-rat-mul a b) (format "[rat* ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-rat-div a b) (format "[rat/ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-rat-neg a) (format "[rat-neg ~a]" (pp-expr a names))]
    [(expr-rat-abs a) (format "[rat-abs ~a]" (pp-expr a names))]
    [(expr-rat-lt a b) (format "[rat< ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-rat-le a b) (format "[rat<= ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-rat-eq a b) (format "[rat= ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-from-int n) (format "[from-int ~a]" (pp-expr n names))]
    [(expr-rat-numer a) (format "[rat-numer ~a]" (pp-expr a names))]
    [(expr-rat-denom a) (format "[rat-denom ~a]" (pp-expr a names))]

    ;; Generic arithmetic
    [(expr-generic-add a b) (format "[+ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-generic-sub a b) (format "[- ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-generic-mul a b) (format "[* ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-generic-div a b) (format "[/ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-generic-lt a b) (format "[< ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-generic-le a b) (format "[<= ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-generic-eq a b) (format "[= ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-generic-negate a) (format "[negate ~a]" (pp-expr a names))]
    [(expr-generic-abs a) (format "[abs ~a]" (pp-expr a names))]
    [(expr-generic-from-int t a) (format "[from-integer ~a ~a]" (pp-expr t names) (pp-expr a names))]
    [(expr-generic-from-rat t a) (format "[from-rational ~a ~a]" (pp-expr t names) (pp-expr a names))]

    ;; Foreign function
    [(expr-foreign-fn name _ arity args _ _)
     (if (null? args)
         (format "[foreign ~a]" name)
         (format "[foreign ~a ~a/~a applied]" name (length args) arity))]

    ;; Union types
    [(expr-union l r)
     (format "~a | ~a" (pp-expr l names) (pp-expr r names))]

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
    [(expr-nat-val n) n]
    [(expr-zero) 0]
    [(expr-suc inner)
     (let ([n (try-as-nat inner)])
       (and n (+ n 1)))]
    [_ #f]))

;; Try to interpret an expr as a cons-chain (linked list).
;; cons is a user-defined data type represented as (expr-app (expr-app (expr-fvar 'cons) head) tail).
;; nil is (expr-fvar 'nil).
;; Handles both bare names (cons, nil) and qualified names (prologos::data::list::cons, etc.)
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
      ;; expr-nil — end of proper list (new overloaded nil node)
      [(expr-nil? cur)
       (if (null? elems)
           #f   ;; bare nil — don't print as '[], just show "nil"
           (list (reverse elems) #f))]
      ;; nil — end of proper list (legacy fvar form: bare nil or (nil A) with type arg)
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

;; ---- LSeq literal detection ----

;; Check if symbol name matches 'lseq-cell or ends with '::lseq-cell' (qualified)
(define (lseq-cell-name? name)
  (or (eq? name 'lseq-cell)
      (let ([s (symbol->string name)])
        (let ([len (string-length s)])
          (and (>= len 11)
               (string=? (substring s (- len 11)) "::lseq-cell"))))))

;; Check if symbol name matches 'lseq-nil or ends with '::lseq-nil' (qualified)
(define (lseq-nil-name? name)
  (or (eq? name 'lseq-nil)
      (let ([s (symbol->string name)])
        (let ([len (string-length s)])
          (and (>= len 10)
               (string=? (substring s (- len 10)) "::lseq-nil"))))))

;; Try to detect an lseq-cell chain for ~[...] output.
;; lseq-cell is a data constructor applied to 3 args: (((lseq-cell A) val) thunk)
;; where thunk is a lambda (lam _ body) containing the next cell or nil.
;; Returns: list of element expressions if detected, #f otherwise.
(define (try-as-lseq e)
  (let loop ([cur e] [elems '()] [depth 0])
    (cond
      [(> depth 1000) #f]
      ;; lseq-nil — end of sequence (bare lseq-nil)
      [(and (expr-fvar? cur) (lseq-nil-name? (expr-fvar-name cur)))
       (if (null? elems)
           #f   ;; bare lseq-nil — don't print as ~[], just show "lseq-nil"
           (reverse elems))]
      ;; (lseq-nil A) — lseq-nil applied to type argument
      [(and (expr-app? cur)
            (let ([func (expr-app-func cur)])
              (and (expr-fvar? func)
                   (lseq-nil-name? (expr-fvar-name func)))))
       (if (null? elems)
           #f   ;; bare (lseq-nil A) — don't print as ~[]
           (reverse elems))]
      ;; (((lseq-cell A) val) thunk) — 3-arg version with type param
      ;; thunk is a lambda: (lam _ body) where body is next cell/nil
      [(and (expr-app? cur)
            (let ([f1 (expr-app-func cur)])  ;; ((lseq-cell A) val) applied to thunk
              (and (expr-app? f1)
                   (let ([f2 (expr-app-func f1)])  ;; (lseq-cell A) applied to val
                     (and (expr-app? f2)
                          (let ([f3 (expr-app-func f2)])  ;; lseq-cell applied to A
                            (and (expr-fvar? f3)
                                 (lseq-cell-name? (expr-fvar-name f3)))))))))
       (define val (expr-app-arg (expr-app-func cur)))   ;; the head value
       (define thunk (expr-app-arg cur))                  ;; the thunk
       ;; Check if thunk is a lambda wrapping the next cell/nil
       (cond
         [(expr-lam? thunk)
          (define body (expr-lam-body thunk))
          (loop body (cons val elems) (+ depth 1))]
         [else
          ;; thunk is not a lambda — can't peek inside, bail out
          #f])]
      ;; Also handle: ((lseq-cell val) thunk) — 2-arg version (no implicit type param)
      [(and (expr-app? cur)
            (let ([func (expr-app-func cur)])
              (and (expr-app? func)
                   (let ([inner-func (expr-app-func func)])
                     (and (expr-fvar? inner-func)
                          (lseq-cell-name? (expr-fvar-name inner-func)))))))
       (define val (expr-app-arg (expr-app-func cur)))
       (define thunk (expr-app-arg cur))
       (cond
         [(expr-lam? thunk)
          (define body (expr-lam-body thunk))
          (loop body (cons val elems) (+ depth 1))]
         [else #f])]
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
    [(expr-typed-hole _) #f]
    [(expr-meta _) #f]
    [(expr-error) #f]
    [(expr-tycon _) #f]
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
    [(expr-p8-eq a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p8-from-nat n) (uses-bvar0? n)]
    [(expr-p8-to-rat a) (uses-bvar0? a)]
    [(expr-p8-from-rat a) (uses-bvar0? a)]
    [(expr-p8-from-int a) (uses-bvar0? a)]
    [(expr-p8-if-nar t nc vc v) (or (uses-bvar0? t) (uses-bvar0? nc) (uses-bvar0? vc) (uses-bvar0? v))]
    [(expr-Posit16) #f]
    [(expr-posit16 _) #f]
    [(expr-p16-add a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p16-sub a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p16-mul a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p16-div a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p16-neg a) (uses-bvar0? a)]
    [(expr-p16-abs a) (uses-bvar0? a)]
    [(expr-p16-sqrt a) (uses-bvar0? a)]
    [(expr-p16-lt a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p16-le a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p16-eq a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p16-from-nat n) (uses-bvar0? n)]
    [(expr-p16-to-rat a) (uses-bvar0? a)]
    [(expr-p16-from-rat a) (uses-bvar0? a)]
    [(expr-p16-from-int a) (uses-bvar0? a)]
    [(expr-p16-if-nar t nc vc v) (or (uses-bvar0? t) (uses-bvar0? nc) (uses-bvar0? vc) (uses-bvar0? v))]
    [(expr-Posit32) #f]
    [(expr-posit32 _) #f]
    [(expr-p32-add a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p32-sub a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p32-mul a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p32-div a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p32-neg a) (uses-bvar0? a)]
    [(expr-p32-abs a) (uses-bvar0? a)]
    [(expr-p32-sqrt a) (uses-bvar0? a)]
    [(expr-p32-lt a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p32-le a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p32-eq a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p32-from-nat n) (uses-bvar0? n)]
    [(expr-p32-to-rat a) (uses-bvar0? a)]
    [(expr-p32-from-rat a) (uses-bvar0? a)]
    [(expr-p32-from-int a) (uses-bvar0? a)]
    [(expr-p32-if-nar t nc vc v) (or (uses-bvar0? t) (uses-bvar0? nc) (uses-bvar0? vc) (uses-bvar0? v))]
    [(expr-Posit64) #f]
    [(expr-posit64 _) #f]
    [(expr-p64-add a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p64-sub a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p64-mul a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p64-div a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p64-neg a) (uses-bvar0? a)]
    [(expr-p64-abs a) (uses-bvar0? a)]
    [(expr-p64-sqrt a) (uses-bvar0? a)]
    [(expr-p64-lt a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p64-le a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p64-eq a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-p64-from-nat n) (uses-bvar0? n)]
    [(expr-p64-to-rat a) (uses-bvar0? a)]
    [(expr-p64-from-rat a) (uses-bvar0? a)]
    [(expr-p64-from-int a) (uses-bvar0? a)]
    [(expr-p64-if-nar t nc vc v) (or (uses-bvar0? t) (uses-bvar0? nc) (uses-bvar0? vc) (uses-bvar0? v))]
    ;; Quire8
    [(expr-Quire8) #f]
    [(expr-quire8-val _) #f]
    [(expr-quire8-fma q a b) (or (uses-bvar0? q) (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-quire8-to q) (uses-bvar0? q)]
    ;; Quire16
    [(expr-Quire16) #f]
    [(expr-quire16-val _) #f]
    [(expr-quire16-fma q a b) (or (uses-bvar0? q) (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-quire16-to q) (uses-bvar0? q)]
    ;; Quire32
    [(expr-Quire32) #f]
    [(expr-quire32-val _) #f]
    [(expr-quire32-fma q a b) (or (uses-bvar0? q) (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-quire32-to q) (uses-bvar0? q)]
    ;; Quire64
    [(expr-Quire64) #f]
    [(expr-quire64-val _) #f]
    [(expr-quire64-fma q a b) (or (uses-bvar0? q) (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-quire64-to q) (uses-bvar0? q)]
    ;; Symbol
    [(expr-Symbol) #f]
    [(expr-symbol _) #f]
    ;; Keyword
    [(expr-Keyword) #f]
    [(expr-keyword _) #f]
    ;; Char
    [(expr-Char) #f]
    [(expr-char _) #f]
    ;; String
    [(expr-String) #f]
    [(expr-string _) #f]
    ;; Map
    [(expr-Map k v) (or (uses-bvar0? k) (uses-bvar0? v))]
    [(expr-champ _) #f]
    [(expr-map-empty k v) (or (uses-bvar0? k) (uses-bvar0? v))]
    [(expr-map-assoc m k v) (or (uses-bvar0? m) (uses-bvar0? k) (uses-bvar0? v))]
    [(expr-map-get m k) (or (uses-bvar0? m) (uses-bvar0? k))]
    [(expr-nil-safe-get m k) (or (uses-bvar0? m) (uses-bvar0? k))]
    [(expr-nil-check a) (uses-bvar0? a)]
    [(expr-map-dissoc m k) (or (uses-bvar0? m) (uses-bvar0? k))]
    [(expr-map-size m) (uses-bvar0? m)]
    [(expr-map-has-key m k) (or (uses-bvar0? m) (uses-bvar0? k))]
    [(expr-map-keys m) (uses-bvar0? m)]
    [(expr-map-vals m) (uses-bvar0? m)]
    ;; Set
    [(expr-Set a) (uses-bvar0? a)]
    [(expr-hset _) #f]
    [(expr-set-empty a) (uses-bvar0? a)]
    [(expr-set-insert s a) (or (uses-bvar0? s) (uses-bvar0? a))]
    [(expr-set-member s a) (or (uses-bvar0? s) (uses-bvar0? a))]
    [(expr-set-delete s a) (or (uses-bvar0? s) (uses-bvar0? a))]
    [(expr-set-size s) (uses-bvar0? s)]
    [(expr-set-union s1 s2) (or (uses-bvar0? s1) (uses-bvar0? s2))]
    [(expr-set-intersect s1 s2) (or (uses-bvar0? s1) (uses-bvar0? s2))]
    [(expr-set-diff s1 s2) (or (uses-bvar0? s1) (uses-bvar0? s2))]
    [(expr-set-to-list s) (uses-bvar0? s)]
    ;; PVec
    [(expr-PVec a) (uses-bvar0? a)]
    [(expr-rrb _) #f]
    [(expr-pvec-empty a) (uses-bvar0? a)]
    [(expr-pvec-push v x) (or (uses-bvar0? v) (uses-bvar0? x))]
    [(expr-pvec-fold f init vec) (or (uses-bvar0? f) (uses-bvar0? init) (uses-bvar0? vec))]
    [(expr-pvec-map f vec) (or (uses-bvar0? f) (uses-bvar0? vec))]
    [(expr-pvec-filter pred vec) (or (uses-bvar0? pred) (uses-bvar0? vec))]
    [(expr-set-fold f init set) (or (uses-bvar0? f) (uses-bvar0? init) (uses-bvar0? set))]
    [(expr-set-filter pred set) (or (uses-bvar0? pred) (uses-bvar0? set))]
    [(expr-map-fold-entries f init map) (or (uses-bvar0? f) (uses-bvar0? init) (uses-bvar0? map))]
    [(expr-map-filter-entries pred map) (or (uses-bvar0? pred) (uses-bvar0? map))]
    [(expr-map-map-vals f map) (or (uses-bvar0? f) (uses-bvar0? map))]
    [(expr-pvec-nth v i) (or (uses-bvar0? v) (uses-bvar0? i))]
    [(expr-pvec-update v i x) (or (uses-bvar0? v) (uses-bvar0? i) (uses-bvar0? x))]
    [(expr-pvec-length v) (uses-bvar0? v)]
    [(expr-pvec-to-list v) (uses-bvar0? v)]
    [(expr-pvec-from-list v) (uses-bvar0? v)]
    [(expr-pvec-pop v) (uses-bvar0? v)]
    [(expr-pvec-concat v1 v2) (or (uses-bvar0? v1) (uses-bvar0? v2))]
    [(expr-pvec-slice v lo hi) (or (uses-bvar0? v) (uses-bvar0? lo) (uses-bvar0? hi))]

    ;; Transient Builders
    [(expr-transient c) (uses-bvar0? c)]
    [(expr-persist c) (uses-bvar0? c)]
    [(expr-TVec a) (uses-bvar0? a)]
    [(expr-TMap k v) (or (uses-bvar0? k) (uses-bvar0? v))]
    [(expr-TSet a) (uses-bvar0? a)]
    [(expr-trrb _) #f]
    [(expr-tchamp _) #f]
    [(expr-thset _) #f]
    [(expr-transient-vec v) (uses-bvar0? v)]
    [(expr-persist-vec t) (uses-bvar0? t)]
    [(expr-transient-map m) (uses-bvar0? m)]
    [(expr-persist-map t) (uses-bvar0? t)]
    [(expr-transient-set s) (uses-bvar0? s)]
    [(expr-persist-set t) (uses-bvar0? t)]
    [(expr-tvec-push! t x) (or (uses-bvar0? t) (uses-bvar0? x))]
    [(expr-tvec-update! t i x) (or (uses-bvar0? t) (uses-bvar0? i) (uses-bvar0? x))]
    [(expr-tmap-assoc! t k v) (or (uses-bvar0? t) (uses-bvar0? k) (uses-bvar0? v))]
    [(expr-tmap-dissoc! t k) (or (uses-bvar0? t) (uses-bvar0? k))]
    [(expr-tset-insert! t a) (or (uses-bvar0? t) (uses-bvar0? a))]
    [(expr-tset-delete! t a) (or (uses-bvar0? t) (uses-bvar0? a))]
    ;; Panic
    [(expr-panic msg) (uses-bvar0? msg)]

    ;; PropNetwork
    [(expr-net-type) #f]
    [(expr-cell-id-type) #f]
    [(expr-prop-id-type) #f]
    [(expr-prop-network _) #f]
    [(expr-cell-id _) #f]
    [(expr-prop-id _) #f]
    [(expr-net-new fuel) (uses-bvar0? fuel)]
    [(expr-net-new-cell n init merge) (or (uses-bvar0? n) (uses-bvar0? init) (uses-bvar0? merge))]
    [(expr-net-new-cell-widen n init merge wf nf)
     (or (uses-bvar0? n) (uses-bvar0? init) (uses-bvar0? merge) (uses-bvar0? wf) (uses-bvar0? nf))]
    [(expr-net-cell-read n c) (or (uses-bvar0? n) (uses-bvar0? c))]
    [(expr-net-cell-write n c v) (or (uses-bvar0? n) (uses-bvar0? c) (uses-bvar0? v))]
    [(expr-net-add-prop n ins outs fn) (or (uses-bvar0? n) (uses-bvar0? ins) (uses-bvar0? outs) (uses-bvar0? fn))]
    [(expr-net-run n) (uses-bvar0? n)]
    [(expr-net-snapshot n) (uses-bvar0? n)]
    [(expr-net-contradiction n) (uses-bvar0? n)]

    ;; UnionFind
    [(expr-uf-type) #f]
    [(expr-uf-store _) #f]
    [(expr-uf-empty) #f]
    [(expr-uf-make-set st id val) (or (uses-bvar0? st) (uses-bvar0? id) (uses-bvar0? val))]
    [(expr-uf-find st id) (or (uses-bvar0? st) (uses-bvar0? id))]
    [(expr-uf-union st id1 id2) (or (uses-bvar0? st) (uses-bvar0? id1) (uses-bvar0? id2))]
    [(expr-uf-value st id) (or (uses-bvar0? st) (uses-bvar0? id))]

    ;; ATMS
    [(expr-atms-type) #f]
    [(expr-assumption-id-type) #f]
    [(expr-atms-store _) #f]
    [(expr-assumption-id-val _) #f]
    [(expr-atms-new net) (uses-bvar0? net)]
    [(expr-atms-assume a nm d) (or (uses-bvar0? a) (uses-bvar0? nm) (uses-bvar0? d))]
    [(expr-atms-retract a aid) (or (uses-bvar0? a) (uses-bvar0? aid))]
    [(expr-atms-nogood a aids) (or (uses-bvar0? a) (uses-bvar0? aids))]
    [(expr-atms-amb a alts) (or (uses-bvar0? a) (uses-bvar0? alts))]
    [(expr-atms-solve-all a g) (or (uses-bvar0? a) (uses-bvar0? g))]
    [(expr-atms-read a c) (or (uses-bvar0? a) (uses-bvar0? c))]
    [(expr-atms-write a c v s) (or (uses-bvar0? a) (uses-bvar0? c) (uses-bvar0? v) (uses-bvar0? s))]
    [(expr-atms-consistent a aids) (or (uses-bvar0? a) (uses-bvar0? aids))]
    [(expr-atms-worldview a aids) (or (uses-bvar0? a) (uses-bvar0? aids))]

    ;; Tabling
    [(expr-table-store-type) #f]
    [(expr-table-store-val _) #f]
    ;; Opaque FFI values (no bound variables)
    [(expr-opaque _ _) #f]
    [(expr-table-new net) (uses-bvar0? net)]
    [(expr-table-register s n m) (or (uses-bvar0? s) (uses-bvar0? n) (uses-bvar0? m))]
    [(expr-table-add s n a) (or (uses-bvar0? s) (uses-bvar0? n) (uses-bvar0? a))]
    [(expr-table-answers s n) (or (uses-bvar0? s) (uses-bvar0? n))]
    [(expr-table-freeze s n) (or (uses-bvar0? s) (uses-bvar0? n))]
    [(expr-table-complete s n) (or (uses-bvar0? s) (uses-bvar0? n))]
    [(expr-table-run s) (uses-bvar0? s)]
    [(expr-table-lookup s n a) (or (uses-bvar0? s) (uses-bvar0? n) (uses-bvar0? a))]

    ;; Relational language (Phase 7)
    [(expr-solver-type) #f] [(expr-goal-type) #f] [(expr-derivation-type) #f] [(expr-cut) #f]
    [(expr-schema-type _) #f] [(expr-logic-var _ _) #f]
    [(expr-answer-type t) (and t (uses-bvar0? t))]
    [(expr-relation-type pts) (ormap uses-bvar0? pts)]
    [(expr-solver-config m) (uses-bvar0? m)]
    [(expr-defr nm sc vs) (or (and sc (uses-bvar0? sc)) (ormap uses-bvar0? vs))]
    [(expr-defr-variant ps bd) (ormap uses-bvar0? bd)]
    [(expr-rel ps cls) (ormap uses-bvar0? cls)]
    [(expr-clause gs) (ormap uses-bvar0? gs)]
    [(expr-fact-block rs) (ormap uses-bvar0? rs)]
    [(expr-fact-row ts) (ormap uses-bvar0? ts)]
    [(expr-goal-app nm as) (or (uses-bvar0? nm) (ormap uses-bvar0? as))]
    [(expr-unify-goal l r) (or (uses-bvar0? l) (uses-bvar0? r))]
    [(expr-is-goal v ex) (or (uses-bvar0? v) (uses-bvar0? ex))]
    [(expr-not-goal g) (uses-bvar0? g)]
    [(expr-schema nm fs) (ormap uses-bvar0? fs)]
    [(expr-solve g) (uses-bvar0? g)]
    [(expr-solve-with sv ov g) (or (and sv (uses-bvar0? sv)) (and ov (uses-bvar0? ov)) (uses-bvar0? g))]
    [(expr-solve-one g) (uses-bvar0? g)]
    [(expr-explain g) (uses-bvar0? g)]
    [(expr-explain-with sv ov g) (or (and sv (uses-bvar0? sv)) (and ov (uses-bvar0? ov)) (uses-bvar0? g))]
    [(expr-narrow func args target vars) (or (uses-bvar0? func) (ormap uses-bvar0? args) (uses-bvar0? target))]
    [(expr-guard cond goal) (or (uses-bvar0? cond) (uses-bvar0? goal))]

    [(expr-Int) #f]
    [(expr-int _) #f]
    [(expr-int-add a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-int-sub a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-int-mul a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-int-div a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-int-mod a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-int-neg a) (uses-bvar0? a)]
    [(expr-int-abs a) (uses-bvar0? a)]
    [(expr-int-lt a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-int-le a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-int-eq a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-from-nat n) (uses-bvar0? n)]
    [(expr-Rat) #f]
    [(expr-rat _) #f]
    [(expr-rat-add a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-rat-sub a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-rat-mul a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-rat-div a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-rat-neg a) (uses-bvar0? a)]
    [(expr-rat-abs a) (uses-bvar0? a)]
    [(expr-rat-lt a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-rat-le a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-rat-eq a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-from-int n) (uses-bvar0? n)]
    [(expr-rat-numer a) (uses-bvar0? a)]
    [(expr-rat-denom a) (uses-bvar0? a)]
    ;; Generic arithmetic
    [(expr-generic-add a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-generic-sub a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-generic-mul a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-generic-div a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-generic-lt a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-generic-le a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-generic-eq a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-generic-negate a) (uses-bvar0? a)]
    [(expr-generic-abs a) (uses-bvar0? a)]
    [(expr-generic-from-int t a) (or (uses-bvar0? t) (uses-bvar0? a))]
    [(expr-generic-from-rat t a) (or (uses-bvar0? t) (uses-bvar0? a))]
    [(expr-foreign-fn _ _ _ _ _ _) #f]
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
    [(sess-async-send t cont)
     (format "[!!~a . ~a]" (pp-expr t names) (pp-session cont names))]
    [(sess-async-recv t cont)
     (format "[??~a . ~a]" (pp-expr t names) (pp-session cont names))]
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

;; ========================================
;; Pretty-print processes
;; ========================================

;; pp-process: convert proc-* tree → readable string
(define (pp-process p)
  (match p
    [(proc-stop) "stop"]
    [(proc-send e c cont)
     (format "send(~a, ~a, ~a)" c (pp-expr e) (pp-process cont))]
    [(proc-recv c binding ty cont)
     (cond
       [(and binding ty) (format "recv(~a as ~a : ~a, ~a)" c binding (pp-expr ty) (pp-process cont))]
       [binding (format "recv(~a as ~a, ~a)" c binding (pp-process cont))]
       [ty (format "recv(~a : ~a, ~a)" c (pp-expr ty) (pp-process cont))]
       [else (format "recv(~a, ~a)" c (pp-process cont))])]
    [(proc-sel c label cont)
     (format "sel(~a.~a, ~a)" c label (pp-process cont))]
    [(proc-case c branches)
     (format "case(~a, { ~a })" c (pp-proc-branches branches))]
    [(proc-new s cont)
     (format "new(~a, ~a)" (pp-expr s) (pp-process cont))]
    [(proc-par p1 p2)
     (format "(~a | ~a)" (pp-process p1) (pp-process p2))]
    [(proc-link c1 c2)
     (format "link(~a, ~a)" c1 c2)]
    [(proc-solve ty cont)
     (format "solve(~a, ~a)" (pp-expr ty) (pp-process cont))]
    ;; S5b: Boundary operations
    [(proc-open path sess cap cont)
     (if cap
         (format "open(~a : ~a {~a}, ~a)" (pp-expr path) (pp-expr sess) (pp-expr cap) (pp-process cont))
         (format "open(~a : ~a, ~a)" (pp-expr path) (pp-expr sess) (pp-process cont)))]
    [(proc-connect addr sess cap cont)
     (if cap
         (format "connect(~a : ~a {~a}, ~a)" (pp-expr addr) (pp-expr sess) (pp-expr cap) (pp-process cont))
         (format "connect(~a : ~a, ~a)" (pp-expr addr) (pp-expr sess) (pp-process cont)))]
    [(proc-listen port sess cap cont)
     (if cap
         (format "listen(~a : ~a {~a}, ~a)" (pp-expr port) (pp-expr sess) (pp-expr cap) (pp-process cont))
         (format "listen(~a : ~a, ~a)" (pp-expr port) (pp-expr sess) (pp-process cont)))]
    [_ (format "~a" p)]))

(define (pp-proc-branches bl)
  (string-join
   (map (lambda (b) (format "~a: ~a" (car b) (pp-process (cdr b))))
        bl)
   ", "))

;; ========================================
;; Datum-level pretty-printer (preparse layer)
;; ========================================
;;
;; pp-datum converts preparse-level datums (with sentinel symbols like
;; $quote, $angle-type, $brace-params, etc.) into readable Prologos
;; syntax strings. Unlike pp-expr which works on core AST Expr structs,
;; pp-datum works at the raw datum level — lists, symbols, numbers.
;;

(define (pp-datum d)
  (cond
    ;; Null
    [(null? d) "()"]

    ;; Boolean
    [(boolean? d) (if d "true" "false")]

    ;; Number (integer, rational)
    [(number? d) (format "~a" d)]

    ;; Sentinel symbols
    [(eq? d '$pipe-gt) "|>"]
    [(eq? d '$compose) ">>"]
    [(eq? d '$pipe) "|"]
    [(eq? d '$rest) "..."]

    ;; Regular symbol
    [(symbol? d) (symbol->string d)]

    ;; String
    [(string? d) (format "~s" d)]  ; uses Racket quoting for strings

    ;; Keyword (Racket keyword)
    [(keyword? d) (format ":~a" (keyword->string d))]

    ;; Pairs / lists — check for sentinel heads
    [(pair? d)
     (let ([h (car d)])
       (cond
         ;; ($quote expr) → 'expr
         [(and (eq? h '$quote) (pair? (cdr d)) (null? (cddr d)))
          (format "'~a" (pp-datum (cadr d)))]

         ;; ($angle-type content ...) → <content ...>
         [(eq? h '$angle-type)
          (format "<~a>" (pp-datum-list (cdr d)))]

         ;; ($brace-params A B C) → {A B C}
         [(eq? h '$brace-params)
          (format "{~a}" (pp-datum-list (cdr d)))]

         ;; ($list-literal e1 e2 ...) → '[e1 e2 ...]
         ;; handles ($list-tail tail) as last element → '[e1 e2 | tail]
         [(eq? h '$list-literal)
          (let-values ([(elems tail) (split-list-literal (cdr d))])
            (if tail
                (format "'[~a | ~a]"
                        (pp-datum-list elems)
                        (pp-datum tail))
                (format "'[~a]" (pp-datum-list elems))))]

         ;; ($set-literal e1 e2 ...) → #{e1 e2 ...}
         [(eq? h '$set-literal)
          (format "#{~a}" (pp-datum-list (cdr d)))]

         ;; ($vec-literal e1 e2 ...) → @[e1 e2 ...]
         [(eq? h '$vec-literal)
          (format "@[~a]" (pp-datum-list (cdr d)))]

         ;; ($lseq-literal e1 e2 ...) → ~[e1 e2 ...]
         [(eq? h '$lseq-literal)
          (format "~~[~a]" (pp-datum-list (cdr d)))]

         ;; ($rest-param name) → ...name
         [(and (eq? h '$rest-param) (pair? (cdr d)) (null? (cddr d)))
          (format "...~a" (pp-datum (cadr d)))]

         ;; ($approx-literal val) → ~val
         [(and (eq? h '$approx-literal) (pair? (cdr d)) (null? (cddr d)))
          (format "~~~a" (pp-datum (cadr d)))]

         ;; ($list-tail expr) — standalone (shouldn't appear outside $list-literal)
         [(and (eq? h '$list-tail) (pair? (cdr d)) (null? (cddr d)))
          (format "| ~a" (pp-datum (cadr d)))]

         ;; ($quasiquote expr) → `expr
         [(and (eq? h '$quasiquote) (pair? (cdr d)) (null? (cddr d)))
          (format "`~a" (pp-datum (cadr d)))]

         ;; ($unquote expr) → ,expr
         [(and (eq? h '$unquote) (pair? (cdr d)) (null? (cddr d)))
          (format ",~a" (pp-datum (cadr d)))]

         ;; Regular list
         [else
          (format "(~a)" (pp-datum-list d))]))]

    ;; Fallback
    [else (format "~s" d)]))

;; Pretty-print a list of datums, space-separated
(define (pp-datum-list ds)
  (cond
    [(null? ds) ""]
    [(pair? ds)
     (string-join (map pp-datum ds) " ")]
    ;; Improper list (dotted pair at end)
    [else (format ". ~a" (pp-datum ds))]))

;; Split $list-literal arguments into regular elements and optional tail.
;; The last element may be ($list-tail expr) indicating an improper list.
(define (split-list-literal args)
  (cond
    [(null? args) (values '() #f)]
    [(and (pair? (car args))
          (pair? (car (car args)))  ; safety
          (eq? (caar args) '$list-tail)
          (null? (cdr args)))
     ;; Last element is ($list-tail expr)
     (values '() (cadar args))]
    [(and (pair? args) (null? (cdr args))
          (pair? (car args))
          (eq? (car (car args)) '$list-tail))
     ;; Last element is ($list-tail expr)
     (values '() (cadr (car args)))]
    [else
     (let-values ([(rest tail) (split-list-literal (cdr args))])
       (values (cons (car args) rest) tail))]))
