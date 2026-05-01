#lang racket/base

;; t3-probe.rkt — investigate what the elaborator emits for various
;; multi-arity defn forms relevant to Tier 3 LLVM lowering.

(require racket/file
         "../racket/prologos/driver.rkt"
         "../racket/prologos/global-env.rkt"
         "../racket/prologos/syntax.rkt"
         "../racket/prologos/pretty-print.rkt")

(define probes
  (list
   ;; -- (1) Simple Bool dispatch via choose --
   (cons 'choose-bool
         "spec choose Bool -> Int -> Int -> Int
defn choose
  | true  a _ -> a
  | false _ b -> b

def main : Int := [choose true 42 0]\n")

   ;; -- (2) Int recursion via literal dispatch --
   (cons 'fact-int
         "spec fact Int -> Int
defn fact
  | 0 -> 1
  | n -> [int* n [fact [int- n 1]]]

def main : Int := [fact 5]\n")

   ;; -- (3) Int dispatch via int comparison --
   (cons 'int-eq-cond
         "spec is-zero Int -> Bool
defn is-zero [n] [int-eq n 0]

def main : Bool := [is-zero 0]\n")

   ;; -- (4) Manual conditional via match on Bool, returning Int --
   (cons 'manual-bool
         "spec choose-int Bool -> Int -> Int -> Int
defn choose-int [b x y]
  match b
    | true  -> x
    | false -> y

def main : Int := [choose-int [int-eq 1 1] 42 0]\n")

   ;; -- (5) Bool returned from a function called in main --
   (cons 'bool-returner
         "spec is-pos Int -> Bool
defn is-pos [n] [int-lt 0 n]

def main : Bool := [is-pos 5]\n")
   ))

(define dump-names '(main choose fact fact::1 is-zero is-pos choose-int))

(define (probe! tag src)
  (printf "==== probe: ~a ====~n" tag)
  (printf "src:~n~a~n----~n" src)
  ;; Best-effort reset of names that earlier probes may have populated.
  (for ([n (in-list dump-names)])
    (with-handlers ([exn:fail? (lambda (e) (void))])
      (global-env-remove! n)))
  (with-handlers ([exn:fail? (lambda (e)
                               (printf "FAIL: ~a~n" (exn-message e)))])
    ;; Use a tmp file path to invoke process-file (WS path).
    (define tmp (make-temporary-file "probe-~a.prologos"))
    (with-output-to-file tmp #:exists 'replace
      (lambda () (display src)))
    (process-file tmp)
    (delete-file tmp)
    ;; Dump everything that looks user-defined.
    (for ([n (in-list dump-names)])
      (define t (global-env-lookup-type n))
      (define v (global-env-lookup-value n))
      (when t
        (printf "~n  ~a~n    type : ~v~n    value: ~v~n" n t v))))
  (newline))

(for ([p (in-list probes)])
  (probe! (car p) (cdr p)))
