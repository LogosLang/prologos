#lang racket/base

;;;
;;; test-definition-entry-01.rkt — PPN 4C Addendum Phase 4A.a (Q3 §18.15.5)
;;;   + Phase 4A.b-ii (§18.17.10): merge revised to LAST-WRITE-WINS.
;;;
;;; Unit tests for the STRUCTURAL DefinitionEntry value shape (definition-entry.rkt):
;;;   def-entry-merge — per-component LAST-WRITE-WINS (:type new-wins; :value
;;;   new-wins-unless-#f-pending); def-bot / def-collision sentinels; 'infra-bot
;;;   universal-sentinel handling. Re-definitions are LEGAL (current language-design
;;;   intent) → LWW, NOT set-once. def-collision is the UNREACHABLE forward-compat ⊤.
;;;
;;; Deployed at 4A.b-ii: per-name definition cells hold a def-entry merged by
;;; def-entry-merge; namespace.rkt's mnr API wraps/unwraps to (cons type value).
;;;

(require rackunit
         "../definition-entry.rkt")

;; ========================================
;; Bot absorption (def-bot + 'infra-bot universal sentinel)
;; ========================================

(test-case "def-entry-merge: def-bot + entry → entry"
  (check-equal? (def-entry-merge def-bot (def-entry 'Int 42)) (def-entry 'Int 42)))

(test-case "def-entry-merge: entry + def-bot → entry"
  (check-equal? (def-entry-merge (def-entry 'Int 42) def-bot) (def-entry 'Int 42)))

(test-case "def-entry-merge: 'infra-bot + entry → entry (universal sentinel)"
  (check-equal? (def-entry-merge 'infra-bot (def-entry 'Bool #t)) (def-entry 'Bool #t)))

(test-case "def-entry-merge: entry + 'infra-bot → entry (universal sentinel)"
  (check-equal? (def-entry-merge (def-entry 'Bool #t) 'infra-bot) (def-entry 'Bool #t)))

;; ========================================
;; def-collision absorption (⊤) — forward-compat: UNREACHABLE from the LWW merge,
;; but still absorbs if fed directly (the constructor + #:contradicts? are kept so
;; a future set-once policy re-activates without a substrate change, §18.17.10).
;; ========================================

(test-case "def-entry-merge: def-collision + entry → def-collision (absorbs)"
  (check-equal? (def-entry-merge def-collision (def-entry 'Int 1)) def-collision))

(test-case "def-entry-merge: entry + def-collision → def-collision (absorbs)"
  (check-equal? (def-entry-merge (def-entry 'Int 1) def-collision) def-collision))

;; ========================================
;; :value LWW (recursive-def commit + idempotence + #f-pending-keeps-old)
;; ========================================

(test-case "def-entry-merge: type-only then value commit ((t #f) + (t v) → (t v))"
  ;; Recursive-def pattern: type registered first (value=#f), value committed after.
  (check-equal? (def-entry-merge (def-entry 'Int #f) (def-entry 'Int 42))
                (def-entry 'Int 42)))

(test-case "def-entry-merge: value-pending both sides stays pending ((t #f) + (t #f))"
  (check-equal? (def-entry-merge (def-entry 'Int #f) (def-entry 'Int #f))
                (def-entry 'Int #f)))

(test-case "def-entry-merge: idempotent ((t v) + (t v) → (t v))"
  (check-equal? (def-entry-merge (def-entry 'Int 42) (def-entry 'Int 42))
                (def-entry 'Int 42)))

(test-case "def-entry-merge: #f-pending new keeps old value ((t v) + (t #f) → (t v))"
  ;; A type-only re-register must NOT clobber an already-committed value.
  (check-equal? (def-entry-merge (def-entry 'Int 42) (def-entry 'Int #f))
                (def-entry 'Int 42)))

;; ========================================
;; LWW redefinition (LEGAL — current language-design intent, §18.17.10)
;; ========================================

(test-case "def-entry-merge: value redefinition (same type, diff value) → NEW wins (LWW)"
  ;; Re-definitions are LEGAL: def x:=1; def x:=2 → x=2 (NOT a collision).
  (check-equal? (def-entry-merge (def-entry 'Int 1) (def-entry 'Int 2))
                (def-entry 'Int 2)))

(test-case "def-entry-merge: full redefinition (diff type AND value) → NEW wins (LWW)"
  (check-equal? (def-entry-merge (def-entry 'Int 1) (def-entry 'String "a"))
                (def-entry 'String "a")))

(test-case "def-entry-merge: type redefinition (new type wins, value committed)"
  (check-equal? (def-entry-merge (def-entry 'Int #f) (def-entry 'Nat 7))
                (def-entry 'Nat 7)))

;; ========================================
;; Non-conforming shape errors loudly (Correct-by-Construction)
;; ========================================

(test-case "def-entry-merge: non-conforming shape errors (surfaces migration bugs)"
  (check-exn exn:fail?
             (lambda () (def-entry-merge (cons 'Int 1) (def-entry 'Int 2)))))
