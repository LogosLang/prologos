#lang racket/base
;; P4e-2 grounding — IR INJECTION: does the typing/reduction twin already give `(@bcast 0) (@star flatten)`
;; (the reader cannot spell `x:0*` today) the meaning Q_U46 + Q_U27 predict, and does `(@bcast (@id))` hit the
;; closed-union raise (the negative control: ε is a NEW kind every walker must learn)?
;; CIU 6 P4e-2 mini-audit RA-3 / RA-7. Run:  racket inject.rkt   (writes inject.out beside this file)
(require racket/runtime-path)
(define-runtime-path out-path "inject.out")
(module+ main
(require racket/list racket/port
         (file "../../../../../../../racket/prologos/driver.rkt")
         (file "../../../../../../../racket/prologos/surface-syntax.rkt")
         (file "../../../../../../../racket/prologos/errors.rkt")
         (file "../../../../../../../racket/prologos/metavar-store.rkt")
         (file "../../../../../../../racket/prologos/elaborator-network.rkt"))
(define out (open-output-file out-path #:exists 'truncate))
(define fixtures
  (string-append
   "ns p4e2inject\n"
   "def t3 := @[@[@[1 2] @[3]] @[@[4] @[5 6]]]\n"     ;; rank 3
   "def values := @[@[1 2 3] @[4 5 6] @[7 8 9]]\n"
   "def recs := @[{:k @[1 2]} {:k @[3]}]\n"))
;; each case: a WS spelling the reader DOES parse, and a step-list rewrite applied to its select
(define (rewrite-steps sf f)
  (cond
    [(surf-select? sf)
     (struct-copy surf-select sf [branches (map f (surf-select-branches sf))])]
    [else sf]))
(define cases
  (list
   ;; control: the keyed twin, as parsed
   (list "recs:k*  (as parsed: (@bcast k) (@star flatten))" "recs:k*" values)
   ;; the ordinal-sort sibling, injected: (@bcast 0) (@star flatten)
   (list "t3 with (@bcast 0) (@star flatten)  — `t3:0*`, unspellable today" "t3:k*"
         (lambda (br) (map (lambda (s) (if (and (pair? s) (eq? (car s) '@bcast)) (list '@bcast 0) s)) br)))
   ;; today's spellable equivalents of what `t3:0*` should mean (Q_U46: join the per-element 0th elements)
   (list "t3:0  (the broadcast alone)" "t3:0" values)
   (list "t3:0{0 1}*  (known-length ravel of the broadcast's result)" "t3:0{0 1}*" values)
   ;; the negative control: ε injected as a tagged step the classifier does not know
   (list "values with (@bcast (@id)) (@star flatten)  — the ε kind, not yet in the union" "values:k*"
         (lambda (br) (map (lambda (s) (if (and (pair? s) (eq? (car s) '@bcast)) (list '@bcast (list '@id)) s)) br)))))
(define src (string-append fixtures
                           (apply string-append (map (lambda (c) (string-append (cadr c) "\n")) cases))))
(define nfix 3)   ;; ns is consumed: 3 defs
(define rs
  (parameterize ([current-prop-net-box (box (make-elaboration-network))])
    (reset-meta-store!)
    (define surfs (ws-string->surfs src))
    (for/list ([sf (in-list surfs)] [i (in-naturals)])
      (define c (and (>= i nfix) (list-ref cases (- i nfix))))
      (define sf* (if (and c (not (eq? (caddr c) values))) (rewrite-steps sf (caddr c)) sf))
      (with-handlers ([exn:fail? (lambda (e) (format "RAISED: ~a" (car (regexp-split #rx"\n" (exn-message e)))))])
        (define r (process-command sf*))
        (cond [(prologos-error? r) (format "ERROR: ~a" (prologos-error-message r))]
              [else (format "~a" r)])))))
(for ([r (in-list rs)] [i (in-naturals)])
  (define label (if (>= i nfix) (car (list-ref cases (- i nfix))) "fixture"))
  (fprintf out "~a: ~a\n    => ~a\n" i label r))
(close-output-port out))
