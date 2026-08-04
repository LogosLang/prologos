#lang racket/base

;;; test-branch-numlit-wellformed.rkt — a resolved numeric literal never
;;; collapses to a MALFORMED node.
;;;
;;; DEFERRED.md § "a numeric-LITERAL first branch adopts any second-branch
;;; type" describes an unsoundness with three candidate fixes. This file pins
;;; the third — the only one that is a local, obviously-correct change — and,
;;; just as importantly, pins the part it does NOT fix, so nobody mistakes one
;;; for the other.
;;;
;;; The mechanism, from the entry: `check`'s N4 arm has three cases for a
;;; numeric literal against expected type T. The META case does
;;; `(unify ctx alpha T)` and defers. Branch 1 of a multi-clause `defn` is
;;; checked against the motive META, so a literal there takes that link; branch
;;; 2 then solves the meta to something concrete, `alpha` IS that meta, and
;;; nothing re-validates. The "defer" names an obligation never discharged.
;;;
;;; `collapse-num-lit`'s own comment used to say "Representability is validated
;;; in check-mode; here we trust the resolved type" — and on this path
;;; check-mode never validates, so it built `(expr-int 3/2)`.

(require rackunit
         racket/list
         racket/string
         racket/file
         "test-support.rkt"
         "../driver.rkt"
         "../namespace.rkt")

(define (run-file-results src)
  (define tmp (make-temporary-file "prologos-numlit-~a.prologos"))
  (call-with-output-file tmp #:exists 'replace (lambda (o) (display src o)))
  (define rs (parameterize ([current-lib-paths (list prelude-lib-dir)]
                            [current-module-registry prelude-module-registry])
               (install-module-loader!)
               (process-file (path->string tmp))))
  (delete-file tmp)
  (map (lambda (r) (format "~a" r)) rs))

(test-case "numlit/an Int-typed slot never holds a non-integral literal"
  ;; THE FIX. Before: `3/2 : Int` — an expr-int whose payload is a ratio, which
  ;; can crash any consumer that believes the struct's contract. After: the
  ;; collapse declines, the transient literal survives to default-metas, and a
  ;; well-formed value comes out.
  (define rs (run-file-results
              "ns numlit-a\n\ndefn d10 | 0 -> 1.5 | n -> 2\n[d10 0]\n"))
  (define last-r (last rs))
  (check-false (regexp-match? #rx"3/2" last-r)
               (format "a malformed Int literal was constructed: ~a" last-r))
  (check-true (regexp-match? #rx"1[.]5" last-r) (format "~a" last-r)))

(test-case "numlit/the TYPE-level unsoundness is NOT fixed (pinned as open)"
  ;; Deliberate. The entry warns "do not mistake this one for a fix", so the
  ;; residue is asserted rather than left to be rediscovered: `d8` is still
  ;; accepted at `Int -> String` and still yields a numeric value under it.
  ;; When the obligation is properly discharged (Num Track 1), THIS is the
  ;; assertion that flips.
  (define rs (run-file-results
              "ns numlit-b\n\ndefn d8 | 0 -> 1.5 | n -> \"x\"\n[d8 0]\n"))
  (check-true (ormap (lambda (r) (regexp-match? #rx"Int -> String" r)) rs)
              (format "~v" rs))
  (check-true (regexp-match? #rx"String" (last rs))
              (format "still a numeric value under a String type: ~a" (last rs))))

(test-case "numlit/ordinary numeric literals are untouched"
  ;; The guard sits on a path every numeric literal in every program takes, so
  ;; the ordinary cases are the ones that must not move.
  (define rs (run-file-results
              (string-append "ns numlit-c\n\n"
                             "def a : Int := 3\n"
                             "def b : Nat := 3N\n"
                             "def c := 1.5\n"
                             "def d : Rat := 3/2\n"
                             "a\nb\nc\nd\n")))
  (check-false (ormap (lambda (r) (regexp-match? #rx"error" r)) rs) (format "~v" rs))
  (define tail (list-tail rs (- (length rs) 4)))
  (check-true (regexp-match? #rx"^3 : Int" (first tail))  (format "~a" (first tail)))
  (check-true (regexp-match? #rx"^3N? : Nat" (second tail)) (format "~a" (second tail)))
  (check-true (regexp-match? #rx"1[.]5" (third tail))     (format "~a" (third tail)))
  (check-true (regexp-match? #rx"3/2 : .*Rat" (fourth tail)) (format "~a" (fourth tail))))

(test-case "numlit/a NEGATIVE literal still cannot land in a Nat slot"
  ;; The Nat guard is nonneg as well as integral; this is the half a naive
  ;; `exact-integer?` check would have dropped.
  (define rs (run-file-results "ns numlit-d\n\ndefn dn | 0 -> -2 | n -> 1N\n[dn 0]\n"))
  (check-false (ormap (lambda (r) (regexp-match? #rx"-2 : .*Nat" r)) rs)
               (format "a negative value under Nat: ~v" rs)))
