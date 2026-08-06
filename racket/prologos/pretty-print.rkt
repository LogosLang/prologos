#lang racket/base

;;;
;;; PROLOGOS PRETTY PRINTER
;;; Convert core AST (Expr, Session, Process) back to readable surface syntax strings.
;;; Uses a name supply to convert de Bruijn indices to human-readable names.
;;;

(require racket/match
         racket/string
         racket/flonum
         racket/math
         "posit-impl.rkt"
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
         pp-datum
         ;; D4.P4b-i slice 3: exported for the WALKER pin only. `expr-select`'s
         ;; branches slot now holds an expr (the selector carrier), so this
         ;; walker must recurse into it — but a bvar inside a selector is
         ;; UNCONSTRUCTIBLE from surface syntax at P4 (selectors are
         ;; monomorphic and hold bare symbols), so the pin has to call the
         ;; walker directly. Same rationale as `select-reduce`'s P4a export;
         ;; zero behavioural change.
         uses-bvar0?)

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
;; Q10-complete numeric display (Numerics N2; sigil-free N6c)
;; ========================================
;;
;; "Display = a re-readable literal of the same value."
;;   - Posit32 → <shortest-decimal>, bare (decimal notation IS Posit32 post-N6b);
;;     integral values force a `.0` so they re-read as Posit32, not Int
;;   - Posit8/16/64 → <shortest-decimal>pNN (mirrors Float32's `2.5f32`)
;;   - Float64 → <shortest-decimal>f  ;  Float32 → <shortest-decimal>f32
;;   - Rat    → plain exact notation (fractions; integral Rat displays bare —
;;     re-reads as Int, which widens back via Int <: Rat)
;; Non-finite floats + NaR have no reader literal; we print the bare name
;; (+nan.0 / +inf.0 / -inf.0 / NaR) — display-only, does not round-trip.

;; Float64 display: `<decimal>f` for finite, bare name for non-finite.
(define (float64->display v)
  (cond
    [(nan? v) "+nan.0"]
    [(= v +inf.0) "+inf.0"]
    [(= v -inf.0) "-inf.0"]
    ;; number->string already yields the shortest round-tripping double decimal.
    [else (string-append (number->string v) "f")]))

;; Float32 display: `<decimal>f32` for finite, bare name for non-finite.
;; v is a flonum that is exactly single-representable (flsingle-rounded).
(define (float32->display v)
  (cond
    [(nan? v) "+nan.0"]
    [(= v +inf.0) "+inf.0"]
    [(= v -inf.0) "-inf.0"]
    [else
     (string-append
      (shortest-decimal (inexact->exact v)
                        (lambda (q) (flsingle (exact->inexact q)))
                        v)
      "f32")]))

;; Posit display (N6c, sigil-free): Posit32 bare (integral → forced `.0`);
;; Posit64 → `<d>p` (symmetry with Float64's `<d>f`); Posit8/16 → `<d>pNN`
;; (integral mantissa re-reads via the pNN integer shape, e.g. `2p8`).
;; NaR = bare name, all widths (no reader form).
(define (posit->display n v)
  (let ([s (posit-shortest-decimal n v)])
    (cond
      [(string=? s "NaR") "NaR"]
      [(= n 32)
       (if (or (string-contains? s ".") (string-contains? s "e"))
           s
           (string-append s ".0"))]
      [(= n 64) (string-append s "p")]  ;; Posit64 → bare `p` (symmetry with Float64's `f`)
      [else (string-append s "p" (number->string n))])))

;; ========================================
;; Pretty-print expressions
;; ========================================

;; pp-expr: convert Expr -> string
;; names is a list of name strings (stack), innermost binding first
;; CIU T6 D4.P3a: render one select branch back to its surface spelling.
;; branch = (listof step); step = symbol | (cons '@sub branches).
;; First segment bare, later keys `.k`, sub-block `.{…}` (always terminal).
(define (pp-select-branch b)
  ;; D4.P3b: `^` continuation suffixes (the surface spellings, Q_T7 grammar)
  (define (cont->string c)
    (cond
      [(eq? c 'dissolve) "^"]
      [(eq? c 'synth) "^_"]
      [(eq? c 'collapse) "^-"]
      [(eq? c 'collapse-synth) "^-_"]
      [(and (pair? c) (eq? (car c) 'rename))
       (string-append "^" (symbol->string (cdr c)))]
      [(and (pair? c) (eq? (car c) 'collapse-rename))
       (string-append "^-" (symbol->string (cdr c)))]
      [else "^?"]))
  ;; D4.P4a: the NINTH step-kind dispatch site — missed by the original
  ;; census because it OPEN-CODED the shape tests (`(and (pair? s) (eq? (car
  ;; s) '@ord))`) instead of using the exported predicates, so an
  ;; identifier-grep could not see it. Its old `[else (format "~a" s)]`
  ;; leaked a raw s-expression into user-facing output and diagnostics.
  ;;
  ;; This is the ONE site that does not RAISE on a missed kind. `pp-expr` is
  ;; on the error-message path (driver.rkt:291,309,507,798,834 and the typing
  ;; hints), so a raise here converts a real diagnostic into an internal
  ;; crash — and `typing-errors.rkt`'s catch-all handler could swallow it,
  ;; achieving strictly LESS than a visible marker. The marker is loud,
  ;; grep-able, and names the kind. Written scope decision, not an omission.
  (define (step->string s first?)
    (case (select-step-kind/display s)
      [(key) (if first? (symbol->string s) (string-append "." (symbol->string s)))]
      ;; D4.P3c: ordinal STEP (.N — descends) vs @ord BRANCH head (bare N)
      [(ord-step) (if first? (number->string s) (string-append "." (number->string s)))]
      [(ord-branch) (number->string (cadr s))]
      [(caret)
       (string-append (if first? "" ".") (symbol->string (cadr s))
                      (cont->string (caddr s)))]
      ;; ⚠ D4.P4d-0 slice 5: honour `first?` — this arm hardcoded `.{` and
      ;; ignored the flag the bcast arm passes, so `users:{a b}` rendered as the
      ;; NONEXISTENT spelling `users:.{a b}` in every diagnostic path (the bcast
      ;; arm's own comment claimed otherwise). Non-first stays `.{…}` — the
      ;; terminal sub-block's real spelling.
      [(sub)
       (string-append (if first? "{" ".{")
                      (string-join (map pp-select-branch (cdr s)) " ") "}")]
      ;; D4.P4c-3 (Q_U7): the ω step renders with its own glyph and its WRAPPED
      ;; step's rendering — `users:name`, `users:{a b}`. `first?` passes to the
      ;; inner step as #t so the inner never emits a leading dot: `:` is already
      ;; the separator, and `users:.name` would be wrong.
      [(bcast) (string-append ":" (step->string (select-bcast-inner s) #t))]
      [else (format "«unrendered-step-kind:~a:~s»" (select-step-kind/display s) s)]))
  (apply string-append
         (for/list ([s (in-list b)] [i (in-naturals)])
           (step->string s (zero? i)))))

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
    ;; PPN Track 4 Phase 4b: cell-id fast path (cells authoritative)
    [(expr-meta id cell-id)
     (let ([sol (meta-solution/cell-id cell-id id)])
       (if sol
           (pp-expr sol names)
           (format "?~a" id)))]
    [(expr-num-lit val _ _ _) (format "~a" val)]  ;; N4: transient literal (usually collapsed pre-display)
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
    [(expr-fst e1) (format "[fst ~a]" (pp-expr e1 names))]
    [(expr-snd e1) (format "[snd ~a]" (pp-expr e1 names))]

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
    [(expr-posit8 v) (posit->display 8 v)]
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
    [(expr-posit16 v) (posit->display 16 v)]
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
    [(expr-posit32 v) (posit->display 32 v)]
    [(expr-Float32) "Float32"]
    [(expr-float32 v) (float32->display v)]
    [(expr-Float64) "Float64"]
    [(expr-float64 v) (float64->display v)]
    ;; Float ops (Numerics N3b)
    [(expr-f32-add a b) (format "[f32+ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-f32-sub a b) (format "[f32- ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-f32-mul a b) (format "[f32* ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-f32-div a b) (format "[f32/ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-f32-neg a) (format "[f32-neg ~a]" (pp-expr a names))]
    [(expr-f32-abs a) (format "[f32-abs ~a]" (pp-expr a names))]
    [(expr-f32-sqrt a) (format "[f32-sqrt ~a]" (pp-expr a names))]
    [(expr-f32-lt a b) (format "[f32-lt ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-f32-le a b) (format "[f32-le ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-f32-eq a b) (format "[f32-eq ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-f64-add a b) (format "[f64+ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-f64-sub a b) (format "[f64- ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-f64-mul a b) (format "[f64* ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-f64-div a b) (format "[f64/ ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-f64-neg a) (format "[f64-neg ~a]" (pp-expr a names))]
    [(expr-f64-abs a) (format "[f64-abs ~a]" (pp-expr a names))]
    [(expr-f64-sqrt a) (format "[f64-sqrt ~a]" (pp-expr a names))]
    [(expr-f64-lt a b) (format "[f64-lt ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-f64-le a b) (format "[f64-le ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-f64-eq a b) (format "[f64-eq ~a ~a]" (pp-expr a names) (pp-expr b names))]
    ;; Cross-width Float conversions (Numerics N3e-rest)
    [(expr-float-finite a) (format "[float-finite? ~a]" (pp-expr a names))]
    [(expr-float-to-rat a) (format "[float-to-rat ~a]" (pp-expr a names))]
    [(expr-float-to-int a) (format "[float-to-int ~a]" (pp-expr a names))]
    [(expr-float-to-float32 a) (format "[float-to-float32 ~a]" (pp-expr a names))]
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
    [(expr-posit64 v) (posit->display 64 v)]
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
    ;; Record/tuple structural-row type (CIU T6 F1): keyword-domain → {:a Int :b String};
    ;; nat-domain → ⟨Int String⟩ (tuple, F1a-col). dyn tail → trailing " | _" (F1a.2).
    [(expr-Record kd fields tail)
     (let ([body (string-join
                  (for/list ([fld (in-list fields)])
                    (if (eq? kd 'keyword)
                        ;; F1b.3 (D24): 'unknown marks display as a `?` label
                        ;; suffix ({:a? Int | _}). Known edge: a 'present field
                        ;; whose label itself ends in `?` is indistinguishable
                        ;; (accepted display-only ambiguity, syntax.rkt spec).
                        (format ":~a~a ~a" (car fld)
                                (if (eq? (record-field-presence (cdr fld)) 'unknown) "?" "")
                                (pp-expr (record-field-type (cdr fld)) names))
                        (pp-expr (record-field-type (cdr fld)) names)))
                  " ")]
           [dyn (if (eq? tail 'dyn) " | _" "")])
       (if (eq? kd 'keyword)
           (format "{~a~a}" body dyn)
           (format "⟨~a~a⟩" body dyn)))]
    ;; Map
    [(expr-Map k v) (format "[Map ~a ~a]" (pp-expr k names) (pp-expr v names))]
    [(expr-champ c)
     (let ([entries (champ-entries c)])
       (if (null? entries)
           "{}"
           (format "{~a}"
                   (string-join
                    (map (lambda (entry)
                           (format "~a ~a"
                                   (pp-expr (car entry) names)
                                   (pp-expr (cdr entry) names)))
                         entries)
                    ", "))))]
    [(expr-map-empty k v) (format "{} : (Map ~a ~a)" (pp-expr k names) (pp-expr v names))]
    ;; SUB.3: a map-assoc SPINE rooted at map-empty renders in brace form,
    ;; matching the champ display — under ruling (D), open maps (e.g. lambda
    ;; bodies referencing their param) stay spines, and their display must not
    ;; regress from `{:a y}` to `[map-assoc {} :a y]`. Chains with a non-empty
    ;; head keep the explicit bracket form.
    [(expr-map-assoc m k v)
     (let loop ([node (expr-map-assoc m k v)] [acc '()])
       (match node
         [(expr-map-assoc m* k* v*) (loop m* (cons (cons k* v*) acc))]
         [(expr-map-empty _ _)
          (format "{~a}"
                  (string-join
                   (map (lambda (entry)
                          (format "~a ~a"
                                  (pp-expr (car entry) names)
                                  (pp-expr (cdr entry) names)))
                        acc)
                   ", "))]
         [_ (format "[map-assoc ~a ~a ~a]" (pp-expr m names) (pp-expr k names) (pp-expr v names))]))]
    ;; P2.b slice 4: the strictness slot is invisible in display (cosmetic
    ;; invariance — user syntax has no spelling for it).
    [(expr-map-get m k _) (format "[map-get ~a ~a]" (pp-expr m names) (pp-expr k names))]
    ;; CIU T6 F1b.5-s2: validate — compact display (plan is baked internals)
    [(? expr-validate? v)
     (format "[validate ~a ~a]"
             (expr-validate-schema-name v)
             (pp-expr (expr-validate-subject v) names))]
    ;; CIU T6 D4.P3a: select — render the SURFACE spelling. D4.P4b-ii-1: the
    ;; spelling now DEPENDS ON THE SORT. Hard-coding `subject{…}` was correct
    ;; while `'block` was the only sort that could reach here; once b-ii-2
    ;; migrates the fold, `x.a` would render as `x{a}` in every error message
    ;; and every `def` echo — silent wrong output on the DIAGNOSTIC path, which
    ;; is the worst place for it. Found by the P4b-ii-1 adversarial verify;
    ;; third consecutive slice whose census missed a pretty-print.rkt site.
    [(expr-select subject (expr-path branches sort) _)
     (case sort
       [(block) (format "~a{~a}"
                        (pp-expr subject names)
                        (string-join (map pp-select-branch branches) " "))]
       ;; the path sort is the DOT spelling. Grade-1 selectors are
       ;; single-branch by construction (a comma/space branch list is block
       ;; syntax), so a multi-branch carrier here would be malformed — render
       ;; it visibly rather than silently picking the first, per the
       ;; no-silent-catch-all discipline this phase exists to enforce.
       [(path)  (if (= (length branches) 1)
                    (format "~a.~a" (pp-expr subject names)
                            (string-join (map pp-select-branch (list (car branches))) ""))
                    (format "~a.<malformed multi-branch path selector: ~a>"
                            (pp-expr subject names)
                            (string-join (map pp-select-branch branches) " | ")))]
       ;; NON-raising, deliberately: pp-expr is on the error-message path
       ;; (driver.rkt's diagnostics + the typing hints), so a raise here would
       ;; convert a real diagnostic into an internal crash — and
       ;; typing-errors' catch-all could swallow it, achieving strictly LESS
       ;; than a visible marker. Same ruling as P4a's site 13.
       [else    (format "~a<?~a?>{~a}"
                        (pp-expr subject names) sort
                        (string-join (map pp-select-branch branches) " "))])]
    [(expr-get c k _) (format "[get ~a ~a]" (pp-expr c names) (pp-expr k names))]
    [(expr-nil-safe-get m k) (format "[nil-safe-get ~a ~a]" (pp-expr m names) (pp-expr k names))]
    [(expr-nil-check a) (format "[nil? ~a]" (pp-expr a names))]
    [(expr-map-dissoc m k) (format "[map-dissoc ~a ~a]" (pp-expr m names) (pp-expr k names))]
    [(expr-map-size m) (format "[map-size ~a]" (pp-expr m names))]
    [(expr-map-has-key m k) (format "[map-has-key? ~a ~a]" (pp-expr m names) (pp-expr k names))]
    [(expr-map-keys m) (format "[map-keys ~a]" (pp-expr m names))]
    [(expr-map-vals m) (format "[map-vals ~a]" (pp-expr m names))]
    ;; Set
    [(expr-Set a) (format "[Set ~a]" (pp-expr a names))]
    [(expr-hset c)
     (let ([keys (champ-keys c)])
       (if (null? keys)
           "#{}"
           (format "#{~a}" (string-join (map (lambda (k) (pp-expr k names)) keys) " "))))]
    [(expr-set-empty a) (format "[set-empty ~a]" (pp-expr a names))]
    [(expr-set-insert s a) (format "[set-insert ~a ~a]" (pp-expr s names) (pp-expr a names))]
    [(expr-set-member s a) (format "[set-member? ~a ~a]" (pp-expr s names) (pp-expr a names))]
    [(expr-set-delete s a) (format "[set-delete ~a ~a]" (pp-expr s names) (pp-expr a names))]
    [(expr-set-size s) (format "[set-size ~a]" (pp-expr s names))]
    [(expr-set-union s1 s2) (format "[set-union ~a ~a]" (pp-expr s1 names) (pp-expr s2 names))]
    [(expr-set-intersect s1 s2) (format "[set-intersect ~a ~a]" (pp-expr s1 names) (pp-expr s2 names))]
    [(expr-set-diff s1 s2) (format "[set-diff ~a ~a]" (pp-expr s1 names) (pp-expr s2 names))]
    [(expr-set-to-list s) (format "[set-to-list ~a]" (pp-expr s names))]

    ;; PVec
    [(expr-PVec a) (format "[PVec ~a]" (pp-expr a names))]
    [(expr-rrb r)
     (let ([elems (reverse (rrb-fold r (lambda (v acc) (cons (pp-expr v names) acc)) '()))])
       (if (null? elems)
           "@[]"
           (string-append "@[" (string-join elems " ") "]")))]
    [(expr-pvec-empty a) (format "@[] : [PVec ~a]" (pp-expr a names))]
    [(expr-pvec-push v x) (format "[pvec-push ~a ~a]" (pp-expr v names) (pp-expr x names))]
    [(expr-pvec-literal elems)
     (format "@[~a]" (string-join (map (lambda (e) (pp-expr e names)) elems) " "))]
    [(expr-list-literal elems _)
     (format "'[~a]" (string-join (map (lambda (e) (pp-expr e names)) elems) " "))]
    [(expr-map-literal keys vals _)
     (format "{~a}" (string-join (for/list ([k (in-list keys)] [v (in-list vals)])
                                   (format "~a ~a" (pp-expr k names) (pp-expr v names)))
                                 " "))]
    [(expr-pvec-fold f init vec) (format "[pvec-fold ~a ~a ~a]" (pp-expr f names) (pp-expr init names) (pp-expr vec names))]
    [(expr-pvec-map f vec) (format "[pvec-map ~a ~a]" (pp-expr f names) (pp-expr vec names))]
    [(expr-pvec-filter pred vec) (format "[pvec-filter ~a ~a]" (pp-expr pred names) (pp-expr vec names))]
    [(expr-set-fold f init set) (format "[set-fold ~a ~a ~a]" (pp-expr f names) (pp-expr init names) (pp-expr set names))]
    [(expr-set-filter pred set) (format "[set-filter ~a ~a]" (pp-expr pred names) (pp-expr set names))]
    [(expr-map-fold-entries f init map) (format "[map-fold-entries ~a ~a ~a]" (pp-expr f names) (pp-expr init names) (pp-expr map names))]
    [(expr-map-filter-entries pred map) (format "[map-filter-entries ~a ~a]" (pp-expr pred names) (pp-expr map names))]
    [(expr-map-map-vals f map) (format "[map-map-vals ~a ~a]" (pp-expr f names) (pp-expr map names))]
    ;; Path values
    [(expr-path branches _)
     (define (pp-branch segs)
       (string-join (for/list ([s (in-list segs)])
                      ;; D4.P4b-i: segments are bare SYMBOLS (the step
                      ;; encoding). The expr-keyword/expr-symbol arms are the
                      ;; pre-convergence shapes and are gone with them.
                      (symbol->string s))
                    "."))
     (if (= (length branches) 1)
         (format "#p(~a)" (pp-branch (car branches)))
         (format "#p(~a)" (string-join (map pp-branch branches) " | ")))]
    [(expr-Path) "Path"]
    [(expr-get-in target paths)
     (format "[get-in ~a ~a]" (pp-expr target names) (pp-expr paths names))]
    [(expr-update-in target paths fn)
     (format "[update-in ~a ~a ~a]" (pp-expr target names) (pp-expr paths names) (pp-expr fn names))]
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
    [(expr-TVec a) (format "[TVec ~a]" (pp-expr a names))]
    [(expr-TMap k v) (format "[TMap ~a ~a]" (pp-expr k names) (pp-expr v names))]
    [(expr-TSet a) (format "[TSet ~a]" (pp-expr a names))]
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
    [(expr-prop-network v) (format "#<prop-network ~a>" (net-cell-read v fuel-cell-id))]  ;; D.4 1C-iv-a: cell-API
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
     (if goal
         (format "(guard ~a ~a)" (pp-expr cond names) (pp-expr goal names))
         (format "(guard ~a)" (pp-expr cond names)))]

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
    [(expr-rat v) (number->string v)]  ;; (N6c) plain exact notation — D-N6.3 revert
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
    [(expr-generic-gt a b) (format "[> ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-generic-ge a b) (format "[>= ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-generic-eq a b) (format "[= ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-generic-mod a b) (format "[mod ~a ~a]" (pp-expr a names) (pp-expr b names))]
    [(expr-generic-negate a) (format "[negate ~a]" (pp-expr a names))]
    [(expr-generic-abs a) (format "[abs ~a]" (pp-expr a names))]
    [(expr-generic-from-int t a) (format "[from-integer ~a ~a]" (pp-expr t names) (pp-expr a names))]
    [(expr-generic-from-rat t a) (format "[from-rational ~a ~a]" (pp-expr t names) (pp-expr a names))]

    ;; Foreign function
    [(expr-foreign-fn name _ arity args _ _ _ _)
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
    [(expr-meta _ _) #f]
    [(expr-error) #f]
    [(expr-tycon _) #f]
    [(expr-suc e1) (uses-bvar0? e1)]
    [(expr-lam _ t body) (or (uses-bvar0? t) (uses-bvar0? body))]
    [(expr-Pi _ dom cod) (or (uses-bvar0? dom) (uses-bvar0? cod))]
    [(expr-Sigma t1 t2) (or (uses-bvar0? t1) (uses-bvar0? t2))]
    [(? expr-Record? rec) (for/or ([fld (in-list (expr-Record-fields rec))]) (uses-bvar0? (record-field-type (cdr fld))))]
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
    [(expr-Float32) #f]
    [(expr-float32 _) #f]
    [(expr-Float64) #f]
    [(expr-float64 _) #f]
    ;; Float ops (Numerics N3b)
    [(expr-f32-add a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-f32-sub a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-f32-mul a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-f32-div a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-f32-neg a) (uses-bvar0? a)]
    [(expr-f32-abs a) (uses-bvar0? a)]
    [(expr-f32-sqrt a) (uses-bvar0? a)]
    [(expr-f32-lt a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-f32-le a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-f32-eq a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-f64-add a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-f64-sub a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-f64-mul a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-f64-div a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-f64-neg a) (uses-bvar0? a)]
    [(expr-f64-abs a) (uses-bvar0? a)]
    [(expr-f64-sqrt a) (uses-bvar0? a)]
    [(expr-f64-lt a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-f64-le a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-f64-eq a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    ;; Cross-width Float conversions (Numerics N3e-rest)
    [(expr-float-finite a) (uses-bvar0? a)]
    [(expr-float-to-rat a) (uses-bvar0? a)]
    [(expr-float-to-int a) (uses-bvar0? a)]
    [(expr-float-to-float32 a) (uses-bvar0? a)]
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
    [(expr-map-get m k a) (or (uses-bvar0? m) (uses-bvar0? k)
                              (and (expr? a) (uses-bvar0? a)))]
    ;; CIU T6 F1b.5-s2: validate — subject + plan expr slots
    [(? expr-validate? v)
     (or (uses-bvar0? (expr-validate-subject v))
         (for/or ([entry (in-list (expr-validate-plan v))])
           (or (and (caddr entry) (uses-bvar0? (caddr entry)))
               (and (cadddr entry) (uses-bvar0? (cadddr entry))))))]
    ;; CIU T6 D4.P3a: select — subject is the only expr slot
    ;; D4.P4b-i slice 3: the branches slot holds an expr — recurse into it.
    ;; Inert at P4 (selectors hold symbols) but correct by construction; the
    ;; old subject-only arm is the Exhaustive-Walkers signature.
    ;; D4.P4b-ii-2b (the verify, M2): the tier is an EXPR slot now, and both
    ;; twins guard theirs (`expr-map-get`, `expr-get` use `(and (expr? a) …)`).
    ;; Unreachable today — `strictness-slot` mints under `ctx-empty`, so the
    ;; slot is closed — but "unreachable today" is exactly how the silent-walker
    ;; class starts, and the comment above claiming the subject is the only
    ;; expr slot has been false since this slice.
    [(expr-select subject sel tier)
     (or (uses-bvar0? subject) (uses-bvar0? sel)
         (and (expr? tier) (uses-bvar0? tier)))]
    [(expr-get c k a) (or (uses-bvar0? c) (uses-bvar0? k)
                          (and (expr? a) (uses-bvar0? a)))]
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
    [(expr-pvec-literal elems) (ormap uses-bvar0? elems)]
    [(expr-list-literal elems chain) (or (ormap uses-bvar0? elems) (uses-bvar0? chain))]
    [(expr-map-literal keys vals chain)
     (or (ormap uses-bvar0? keys) (ormap uses-bvar0? vals) (uses-bvar0? chain))]
    [(expr-pvec-fold f init vec) (or (uses-bvar0? f) (uses-bvar0? init) (uses-bvar0? vec))]
    [(expr-pvec-map f vec) (or (uses-bvar0? f) (uses-bvar0? vec))]
    [(expr-pvec-filter pred vec) (or (uses-bvar0? pred) (uses-bvar0? vec))]
    [(expr-set-fold f init set) (or (uses-bvar0? f) (uses-bvar0? init) (uses-bvar0? set))]
    [(expr-set-filter pred set) (or (uses-bvar0? pred) (uses-bvar0? set))]
    [(expr-map-fold-entries f init map) (or (uses-bvar0? f) (uses-bvar0? init) (uses-bvar0? map))]
    [(expr-map-filter-entries pred map) (or (uses-bvar0? pred) (uses-bvar0? map))]
    [(expr-map-map-vals f map) (or (uses-bvar0? f) (uses-bvar0? map))]
    ;; Path values — no bound variables
    [(expr-path _ _) #f]
    [(expr-Path) #f]
    [(expr-get-in target paths) (or (uses-bvar0? target) (uses-bvar0? paths))]
    [(expr-update-in target paths fn) (or (uses-bvar0? target) (uses-bvar0? paths) (uses-bvar0? fn))]
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
    [(expr-logic-var _ _) #f]
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
    [(expr-solve g) (uses-bvar0? g)]
    [(expr-solve-with sv ov g) (or (and sv (uses-bvar0? sv)) (and ov (uses-bvar0? ov)) (uses-bvar0? g))]
    [(expr-solve-one g) (uses-bvar0? g)]
    [(expr-explain g) (uses-bvar0? g)]
    [(expr-explain-with sv ov g) (or (and sv (uses-bvar0? sv)) (and ov (uses-bvar0? ov)) (uses-bvar0? g))]
    [(expr-narrow func args target vars) (or (uses-bvar0? func) (ormap uses-bvar0? args) (uses-bvar0? target))]
    [(expr-guard cond goal) (or (uses-bvar0? cond) (and goal (uses-bvar0? goal)))]

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
    [(expr-generic-gt a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-generic-ge a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-generic-eq a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-generic-mod a b) (or (uses-bvar0? a) (uses-bvar0? b))]
    [(expr-generic-negate a) (uses-bvar0? a)]
    [(expr-generic-abs a) (uses-bvar0? a)]
    [(expr-generic-from-int t a) (or (uses-bvar0? t) (uses-bvar0? a))]
    [(expr-generic-from-rat t a) (or (uses-bvar0? t) (uses-bvar0? a))]
    [(expr-foreign-fn _ _ _ _ _ _ _ _) #f]
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

         ;; ⭐ D4.P4b-ii-2b — ($select-path subj field) → subj.field.
         ;; THE FOURTH CONSECUTIVE MISSED pretty-print.rkt SITE, found by the
         ;; verify. `pp-expr`'s select arm was fixed at b-ii-1 and that census
         ;; STOPPED THERE — `pp-datum` is the datum-layer twin, 1000 lines
         ;; down the same file, and the fold migration is a datum-layer change.
         ;; Without this arm `expand r.a` emitted the raw sentinel
         ;; `($select-path r a)` where HEAD emitted readable `(map-get r :a)`:
         ;; a REGRESSION on the most common access surface in the language,
         ;; silent, on the introspection path (driver's expand/expand-1/
         ;; expand-full). Nesting composes: `r.a.b` renders `r.a.b`.
         [(and (eq? h '$select-path) (pair? (cdr d)) (pair? (cddr d))
               (null? (cdddr d)))
          (format "~a.~a" (pp-datum (cadr d)) (pp-datum (caddr d)))]

         ;; ($rest-param name) → ...name
         [(and (eq? h '$rest-param) (pair? (cdr d)) (null? (cddr d)))
          (format "...~a" (pp-datum (cadr d)))]

         ;; (N6c) $approx-literal pp-datum case removed (~N deprecated)

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
