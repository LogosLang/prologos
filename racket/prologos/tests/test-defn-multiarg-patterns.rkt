#lang racket/base

;;;
;;; Tests for Multi-Arg Pattern Disambiguation in `defn name | ... -> ...`
;;;
;;; Eigentrust pitfalls doc #7 fix: bare-token patterns after `|` in
;;; `defn name | pat -> body | ...` were ambiguous between
;;;   (a) one compound pattern: `cons r nil` → cons-of-(r,nil)   [ML/Haskell-like]
;;;   (b) N separate arg patterns: `cons r nil` → cons, r, nil   [old behavior]
;;;
;;; The fix in parser.rkt's parse-defn-clause auto-detects (a) when the
;;; leading token is a known constructor whose field count matches the
;;; remaining tokens. Otherwise it falls back to (b), preserving genuinely
;;; multi-arg defns like `defn add | x y -> [+ x y]`.
;;;
;;; Coverage:
;;; - Single-arg multi-clause (regression of canonical multi-clause defn)
;;; - Multi-arg multi-clause with all-variable patterns (regression of (b))
;;; - Eigentrust reproducer (sum-rows): `cons r nil` → one compound
;;; - Multi-arg with constructor patterns in non-first positions
;;; - Wildcards `_` mixed in
;;;

(require rackunit
         racket/string
         "test-support.rkt"
         ;; 2026-07-31: the unreachable-arm cases assert on the error VALUE
         "../errors.rkt")

;; ========================================
;; Helpers
;; ========================================
;; Use test-support.rkt's run-ns-* helpers (canonical post-S2.e pattern;
;; the manual parameterize block here referenced retired
;; `current-mult-meta-store` and friends — fixed 2026-04-27).

;; Prepend namespace declarations so test strings (which lack their own
;; ns headers) get a namespace context — needed for prelude refs.
(define (run-last s) (run-ns-last (string-append "(ns test)\n" s)))
(define (run-ws s) (run-ns-ws-all (string-append "ns test\n" s)))
(define (run-ws-last s) (run-ns-ws-last (string-append "ns test\n" s)))

;; ========================================
;; A. Single-arg multi-clause regression
;; ========================================
;; The canonical `is-zero` example from prologos-syntax.md.

(test-case "marg/single-arg-is-zero"
  (check-equal?
   (run-ws-last
    "defn iz-marg\n  | zero  -> true\n  | suc _ -> false\neval [iz-marg 0N]")
   "true : Bool")
  (check-equal?
   (run-ws-last
    "defn iz-marg2\n  | zero  -> true\n  | suc _ -> false\neval [iz-marg2 3N]")
   "false : Bool"))

;; ========================================
;; B. Multi-arg with all-variable patterns: must NOT be packed
;; ========================================
;; `x y` does not have a leading ctor, so falls back to N args.
;; Critical regression: confirms genuinely multi-arg defns still work.

(test-case "marg/all-var-two-arg"
  ;; `defn add-marg | x y -> [+ x y]` — 2 args, both variables
  ;; Use Nat constructors so the type infers as Nat -> Nat -> Nat
  (check-equal?
   (run-ws-last
    "spec add-marg Nat -> Nat -> Nat\ndefn add-marg\n  | x y -> [+ x y]\neval [add-marg 3N 4N]")
   "7N : Nat"))

(test-case "marg/all-var-three-arg"
  ;; 3 args, all variable — must be parsed as 3 args
  (check-equal?
   (run-ws-last
    "spec triple-add Nat -> Nat -> Nat -> Nat\ndefn triple-add\n  | x y z -> [+ [+ x y] z]\neval [triple-add 1N 2N 3N]")
   "6N : Nat"))

;; ========================================
;; C. Eigentrust reproducer: `cons r nil` packs to one compound
;; ========================================

(test-case "marg/eigentrust-sum-rows-typechecks"
  ;; The eigentrust reproducer: previously failed with `Unbound variable
  ;; sum-rows::1` because bare-token clauses produced split arities
  ;; (1, 3, 3 instead of 1, 1, 1). With the fix, all three clauses are
  ;; arity 1 and `sum-rows-eig` defines as `[List Nat] -> Nat` — a single
  ;; function, no per-clause helpers, no unbound reference.
  ;;
  ;; This test verifies the *parsing* fix (single arity, single function).
  ;; A latent compile-match-tree bug (variable bindings for outer-param
  ;; names broken across nested compound dispatch) is orthogonal and
  ;; tracked separately; see commit message for details. We exercise the
  ;; eigentrust case at empty + singleton inputs which are unaffected.
  (define results
    (run-ws
     (string-append
      "spec sum-rows-eig [List Nat] -> Nat\n"
      "defn sum-rows-eig\n"
      "  | nil            -> 0N\n"
      "  | cons r nil     -> r\n"
      "  | cons r rest    -> [+ r [sum-rows-eig rest]]\n"
      "eval [sum-rows-eig '[5N]]")))
  ;; First non-error result line confirms parse + type-check + arity-1 def.
  (check-true (for/or ([r (in-list results)])
                (and (string? r)
                     (string-contains? r "sum-rows-eig")
                     (string-contains? r "List Nat] -> Nat")))))

(test-case "marg/eigentrust-sum-rows-empty"
  ;; Empty list → first clause matches: nil → 0N (no nested binding bug).
  (define results
    (run-ws
     (string-append
      "spec sum-rows-eig2 [List Nat] -> Nat\n"
      "defn sum-rows-eig2\n"
      "  | nil            -> 0N\n"
      "  | cons r nil     -> r\n"
      "  | cons r rest    -> [+ r [sum-rows-eig2 rest]]\n"
      "eval [sum-rows-eig2 [the [List Nat] nil]]")))
  (check-true (for/or ([r (in-list results)])
                (and (string? r) (string-contains? r "0N")))))

(test-case "marg/eigentrust-sum-rows-singleton"
  ;; Singleton list → second clause matches: cons r nil → r.
  ;; This is the boundary that the fix unlocks — pre-fix the function
  ;; was arity-1 with only the nil clause, so any non-empty list would
  ;; hit ??__match-fail.
  (define results
    (run-ws
     (string-append
      "spec sum-rows-eig3 [List Nat] -> Nat\n"
      "defn sum-rows-eig3\n"
      "  | nil            -> 0N\n"
      "  | cons r nil     -> r\n"
      "  | cons r rest    -> [+ r [sum-rows-eig3 rest]]\n"
      "eval [sum-rows-eig3 '[42N]]")))
  (check-true (for/or ([r (in-list results)])
                (and (string? r) (string-contains? r "42N")))))

;; ========================================
;; D. Constructor patterns in non-first positions
;; ========================================
;; `[+ ... 0N]`-like patterns: peano addition with zero on the right.

(test-case "marg/ctor-pattern-non-first-position"
  ;; `add-zero-r | n zero -> n | n [suc m] -> [suc [add-zero-r n m]]`
  ;; Bare `n zero` has leading `n` (variable, not ctor) → falls back to 2 args.
  ;; This is the "bare patterns" case where the user genuinely wants N args.
  (check-equal?
   (run-ws-last
    (string-append
     "spec add-zr Nat -> Nat -> Nat\n"
     "defn add-zr\n"
     "  | n zero    -> n\n"
     "  | n [suc m] -> [suc [add-zr n m]]\n"
     "eval [add-zr 2N 3N]"))
   "5N : Nat"))

;; ========================================
;; E. Wildcards mixed in
;; ========================================

(test-case "marg/wildcard-in-bare-tokens"
  ;; `cons _ nil` — `cons` is leading ctor with 2 fields, 2 remaining tokens.
  ;; Should be packed as one pattern: cons-of-(_,nil).
  (check-equal?
   (run-ws-last
    (string-append
     "defn singleton?\n"
     "  | nil          -> false\n"
     "  | cons _ nil   -> true\n"
     "  | cons _ _     -> false\n"
     "eval [singleton? '[42N]]"))
   "true : Bool")
  (check-equal?
   (run-ws-last
    (string-append
     "defn singleton?2\n"
     "  | nil          -> false\n"
     "  | cons _ nil   -> true\n"
     "  | cons _ _     -> false\n"
     "eval [singleton?2 '[1N 2N]]"))
   "false : Bool"))

(test-case "marg/wildcard-in-all-var"
  ;; `_ _` — both wildcards, no leading ctor → 2 args.
  (check-equal?
   (run-ws-last
    (string-append
     "spec const-zero-2 Nat -> Nat -> Nat\n"
     "defn const-zero-2\n"
     "  | _ _ -> 0N\n"
     "eval [const-zero-2 5N 7N]"))
   "0N : Nat"))

;; ========================================
;; F. Mixed: some clauses pack, others don't
;; ========================================
;; All clauses must end up at the SAME arity. A bare-pattern clause
;; whose leading token is a ctor with matching arity packs to one
;; pattern; a `nil` clause is already one pattern. Both → arity 1.

(test-case "marg/mixed-leading-ctor-and-nullary"
  ;; nil (1 token, nullary ctor) + cons _ _ (3 tokens, packs to 1 compound)
  (check-equal?
   (run-ws-last
    (string-append
     "spec list-len-marg [List Nat] -> Nat\n"
     "defn list-len-marg\n"
     "  | nil          -> 0N\n"
     "  | cons _ rest  -> [suc [list-len-marg rest]]\n"
     "eval [list-len-marg '[10N 20N 30N]]"))
   "3N : Nat"))

;; ========================================
;; G. Bracketed form continues to work (regression)
;; ========================================
;; `[cons r nil]` (single bracket) is the explicit way to write a
;; compound pattern in a multi-arg context. This remains supported.

(test-case "marg/double-bracket-compound-still-works"
  ;; [[cons _ nil]] (double bracket) is the legacy way to write a
  ;; compound pattern as a single arg in the bracketed form: outer
  ;; bracket = "this is the params list with 1 element"; inner bracket
  ;; = "the element is the compound pattern (cons _ nil)". This path
  ;; is unchanged by the fix (regression check).
  (check-equal?
   (run-ws-last
    (string-append
     "defn singleton?-dblbracket\n"
     "  | [[nil]]        -> false\n"
     "  | [[cons _ nil]] -> true\n"
     "  | [[cons _ _]]   -> false\n"
     "eval [singleton?-dblbracket '[42N]]"))
   "true : Bool"))

;; ========================================
;; Unreachable arms are rejected (2026-07-31)
;; ========================================
;; An arm following an IRREFUTABLE arm can never run — and, the reason this is a
;; correctness bug rather than a style nit, it is never TYPE-CHECKED either. The
;; pattern compiler drops it, so its body escapes the checker entirely and a
;; String body where a Nat is expected was accepted silently.
;;
;; The reported symptom was subtler: `normalize-pattern` turns a bare name into a
;; constructor pattern only when `lookup-ctor` knows it, so an UNKNOWN name (a
;; typo, or a constructor whose type is not imported) stays a VARIABLE pattern —
;; irrefutable — and silently eats every later arm. Same defect, two angles, so
;; the check is on REACHABILITY: it needs no guess about whether a lowercase name
;; was "meant" as a constructor, which is genuinely ambiguous in isolation.

(define (unreachable? s)
  (define r (with-handlers ([(lambda (_) #t) (lambda (e) e)]) (run-last s)))
  (and (prologos-error? r)
       (regexp-match? #rx"unreachable match arm" (prologos-error-message r))))

(test-case "unreachable/dead arm after a catch-all is rejected"
  ;; Before the check this DEFINED CLEAN, with a String body where Nat is
  ;; expected — the arm was never type-checked.
  (check-true
   (unreachable? "(spec d2 Nat -> Nat)\n(defn d2 [v] (match v (n -> 1N) (zero -> \"dead\")))")))

(test-case "unreachable/an unrecognised constructor name eats later arms"
  ;; THE reported shape. `vnil` is not a known constructor here, so it became an
  ;; irrefutable variable pattern and arm 2 was dead.
  (check-true
   (unreachable?
    "(spec d1 Nat -> Nat)\n(defn d1 [v] (match v (vnil -> 1N) (vcons a b -> \"not-a-nat\")))")))

(test-case "unreachable/the multi-clause defn form is checked too"
  ;; The other entry point: clause groups compile through compile-pattern-group,
  ;; not compile-match-expression.
  (check-true
   (unreachable? "(spec d4 Nat -> Nat)\n(defn d4 ($pipe (n) -> 1N) ($pipe (zero) -> 2N))")))

(test-case "unreachable/a variable arm LAST stays legal (idiomatic default)"
  ;; Only arms AFTER an irrefutable one are flagged — the catch-all itself is the
  ;; idiomatic default and must keep working, on both entry points.
  (check-equal?
   (run-ws-last "defn ok1\n  | zero -> 1N\n  | n    -> 2N\neval [ok1 5N]")
   "2N : Nat")
  ;; same, on the match-EXPRESSION entry point (the negative cases above use it)
  (check-false
   (unreachable?
    "(spec ok2 Nat -> Nat)\n(defn ok2 [v] (match v (zero -> 1N) (n -> 2N)))")))

(test-case "unreachable/a GUARD keeps later arms reachable"
  ;; A guarded arm can fail, so it is refutable and does not shadow what follows.
  ;; The guard clause in the irrefutability test is what makes this work.
  (check-false
   (unreachable?
    "(spec g1 Nat -> Nat)\n(defn g1 [v] (match v (n when (int-lt n 1N) -> 1N) (m -> 2N)))")))

;; ========================================
;; A constructor of ANOTHER type is rejected (2026-07-31)
;; ========================================
;; `reduce-arm-ctx` resolved an arm's constructor via a bare-name global-env
;; lookup with no check that it belongs to the type being matched, so an arm
;; naming a FOREIGN type's constructor was accepted. A `Bool` is never a `Box3`,
;; so that arm can never match — silent dead code with no diagnostic. Narrower
;; than the unreachable-arm case above: this arm's body IS type-checked.

(test-case "cross-ctor/an arm naming another type's constructor is rejected"
  (define r
    (with-handlers ([(lambda (_) #t) (lambda (e) e)])
      (run-last
       (string-append
        "(data Box3 (mk-b3 : Nat))\n"
        "(spec crossctor Bool -> Nat)\n"
        "(defn crossctor [b] (match b (true -> 1N) (mk-b3 x -> 2N)))"))))
  (check-true (prologos-error? r) (format "expected an error, got: ~v" r)))

(test-case "cross-ctor/the type's OWN constructors still work"
  ;; The membership test must not reject legitimate arms — including a match on
  ;; the user type itself, where both constructors belong.
  (check-equal?
   (run-ws-last
    (string-append
     "data Box3\n  | mk-b3 Nat\n  | empty3\n"
     "defn unbox\n  | mk-b3 k -> k\n  | empty3  -> 0N\n"
     "eval [unbox [mk-b3 7N]]"))
   "7N : Nat"))

;; ========================================
;; Multiplicities survive an arrow spec (2026-07-31)
;; ========================================
;; `extract-pi-binders` matched a `surf-arrow`'s multiplicity field as `_` and
;; substituted 'mw, so every binder derived from an arrow type came back
;; unrestricted — `A -1> B` and `A -> B` were indistinguishable to all its
;; consumers. Visible symptom: a multi-clause `defn` with a linear spec was
;; rejected OUT OF HAND whatever its body did (the generated lambda got 'mw while
;; the Pi said :1, and checkQ's lam-vs-Pi arm requires them equal), while the
;; SAME function written with bracket params + an inline match was accepted.

(define (mult-violation? s)
  (define r (with-handlers ([(lambda (_) #t) (lambda (e) e)]) (run-last s)))
  (and (prologos-error? r)
       (regexp-match? #rx"Multiplicity" (prologos-error-message r))))

(define handle-decl "(data Handle2 (mk-h : Nat))\n")

(test-case "spec-mult/a linear multi-clause defn is ACCEPTED when correct"
  ;; The regression: this was rejected for its spec alone.
  (check-false
   (mult-violation?
    (string-append handle-decl
                   "(spec ok1 Handle2 -1> Nat -> Handle2)\n"
                   "(defn ok1 ($pipe (h n) -> h))"))))

(test-case "spec-mult/linearity is still ENFORCED in that form"
  ;; The control that matters: the fix must restore checking, not disable it.
  (check-true
   (mult-violation?
    (string-append handle-decl
                   "(spec bad2 Handle2 -1> Nat -> Nat)\n"
                   "(defn bad2 ($pipe (h n) -> 0N))"))
   "a linear parameter left unused must still violate")
  (check-true
   (mult-violation?
    (string-append handle-decl
                   "(spec bad3 Handle2 -0> Handle2)\n"
                   "(defn bad3 ($pipe (h) -> h))"))
   "an erased parameter used at runtime must still violate"))

(test-case "spec-mult/the two spellings of the same function now agree"
  ;; Destructuring a linear value: bracket-params + inline match (the stdlib fio
  ;; spelling) and the multi-clause form must both be accepted.
  (define decl (string-append handle-decl "(spec c Handle2 -1> Nat)\n"))
  (check-false (mult-violation? (string-append decl "(defn c [h] (match h (mk-h k -> k)))")))
  (check-false (mult-violation? (string-append decl "(defn c ($pipe (mk-h k) -> k))"))))

;; ========================================
;; Guards in the bare-`|` clause form (2026-07-31)
;; ========================================
;; `parse-defn-clause` split the pre-arrow forms into patterns with NO `when`
;; handling, though the bracketed-header parser has always had it. So a guard was
;; silently parsed as EXTRA PATTERNS — `| n when [int-lt n 0] -> 7` became three
;; patterns — giving clauses of mismatched arity. The pattern compiler then
;; indexed off the end of its parameter list and died with a raw Racket
;; `list-ref: index too large for list`, which killed the WHOLE FILE: no
;; per-command error, and no output from commands BEFORE the offending one.
;;
;; Guards now parse, so the form works rather than merely failing politely — and
;; the semantics are pinned, not just the absence of a crash.

(test-case "guard-bare/a guarded clause group compiles and DISPATCHES"
  (check-equal?
   (run-ws-last
    (string-append
     "defn classify\n  | n when [int-lt n 0] -> 7\n  | n -> 5\n"
     "eval [classify -3]"))
   "7 : Int")
  (check-equal?
   (run-ws-last
    (string-append
     "defn classify2\n  | n when [int-lt n 0] -> 7\n  | n -> 5\n"
     "eval [classify2 3]"))
   "5 : Int"))

(test-case "guard-bare/successive guards fall through in order"
  (define src
    (string-append
     "defn sign\n"
     "  | n when [int-lt n 0] -> 0\n"
     "  | n when [int-eq n 0] -> 1\n"
     "  | n                   -> 2\n"))
  (check-equal? (run-ws-last (string-append src "eval [sign -5]")) "0 : Int")
  (check-equal? (run-ws-last (string-append src "eval [sign 0]"))  "1 : Int")
  (check-equal? (run-ws-last (string-append src "eval [sign 5]"))  "2 : Int"))

(test-case "guard-bare/an earlier command's output survives (no whole-file abort)"
  ;; The crash took the entire file down, so a command BEFORE the guarded defn
  ;; produced no output at all. This is the containment pin.
  (define rs (run-ws (string-append
                      "def before := 1\n"
                      "defn m07\n  | n when [int-lt n 0] -> 7\n  | n -> 5\n"
                      "def after := 2\n")))
  (check-true (>= (length rs) 3) (format "expected all commands to report; got: ~v" rs))
  (check-false (ormap prologos-error? rs) (format "expected no errors; got: ~v" rs)))

(test-case "guard-bare/the bracketed-header form is unchanged"
  (check-equal?
   (run-ws-last
    (string-append
     "defn classify3 [n]\n  | n when [int-lt n 0] -> 7\n  | n -> 5\n"
     "eval [classify3 -3]"))
   "7 : Int"))
