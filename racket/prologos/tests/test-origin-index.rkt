#lang racket/base
;; DEFERRED 58 — the ORIGIN INDEX's two load-bearing properties.
;;
;; `strip-with-origin!` replaces `syntax->datum` on the per-form preparse path.
;; That makes two things load-bearing, and neither is something a green suite
;; would demonstrate on its own:
;;   (A) SOUNDNESS — it must produce EXACTLY the datum `syntax->datum` produces.
;;       A divergence here would corrupt every downstream arm, and the shapes
;;       most likely to diverge (improper lists, vectors, boxes, nested empties)
;;       are the ones no `.prologos` fixture happens to contain.
;;   (B) IDENTITY — the recorded key must be `eq?` to the pair actually handed to
;;       the expander, since cons-cell identity IS the provenance marker. A
;;       second `syntax->datum` over the same object shares nothing, so an
;;       accidental re-strip anywhere silently reduces the index to a no-op that
;;       still type-checks and still passes every behavioural test.
(require rackunit
         (only-in "../macros.rkt" strip-with-origin!))

(define (dat s) (syntax->datum s))
(define (strip s) (strip-with-origin! s (make-hasheq)))

;; ── (A) datum equivalence, over shapes chosen to break a naive walker ────────
(define SHAPES
  (list #'()
        #'atom
        #'"str"
        #'42
        #'(a b c)
        #'(a (b (c (d))))
        #'(a . b)                      ; improper
        #'(a b . c)                    ; improper with a spine
        #'(() (()) ((())))             ; nested empties
        #'#(1 2 3)                     ; vector
        #'#(1 (2 3) #(4))              ; nested vector
        #'(a #(b (c)) d)               ; vector inside a list
        #'(1 #f #t #\x "s" |sym|)
        #'((a . b) (c . d))
        #'(defr q (?a) ($clause-sep) (foo a "x"))))

(for ([s (in-list SHAPES)] [i (in-naturals)])
  (test-case (format "DEFERRED 58 (A): strip-with-origin! = syntax->datum, shape ~a" i)
    (check-equal? (strip s) (dat s)
                  (format "datum divergence on ~s" (dat s)))))

;; ── (B) identity: the key IS the pair the expander receives ──────────────────
(test-case "DEFERRED 58 (B): every recorded key is eq? to a node of the produced datum"
  (define idx (make-hasheq))
  (define stx #'(let (v ($goal-rhs (rel (f) (fc f "blue")))) (some v)))
  (define d (strip-with-origin! stx idx))
  ;; collect every compound node of the produced datum, by identity
  (define seen (make-hasheq))
  (let walk ([x d])
    (when (pair? x)
      (hash-set! seen x #t)
      (walk (car x))
      (walk (cdr x))))
  (for ([(k _) (in-hash idx)])
    (check-true (hash-ref seen k #f)
                (format "recorded key is not a node of the produced datum: ~s" k)))
  (check-true (> (hash-count idx) 3) "index should record the nested compounds"))

(test-case "DEFERRED 58 (B): a nested subtree is recoverable by IDENTITY at depth"
  ;; The property the whole fix rests on: pull a deeply-nested node out of the
  ;; produced datum and look it up by eq? — the index must hand back the syntax
  ;; object it came from, with that node's OWN srcloc, not the form's.
  (define idx (make-hasheq))
  (define stx #'(let (v ($goal-rhs (rel (f) (fc f "blue")))) (some v)))
  (define d (strip-with-origin! stx idx))
  (define nested (cadr (cadr d)))          ; the ($goal-rhs (rel …)) subtree
  (check-true (pair? nested))
  (check-eq? (car nested) '$goal-rhs)
  (define hit (hash-ref idx nested #f))
  (check-true (syntax? hit) "the nested subtree must be recoverable by identity")
  (check-equal? (syntax->datum hit) nested "and it must be the SAME subtree"))

(test-case "DEFERRED 58 (B): a SECOND strip shares no keys — why each strip needs its own index"
  ;; Pins the trap the audit measured: `syntax->datum` allocates fresh pairs, so
  ;; an index built over one strip is useless against another. If this ever
  ;; starts passing, cons-cell identity is no longer the marker and the fix's
  ;; premise has changed.
  (define stx #'(let (v ($goal-rhs (rel (f) (fc f "blue")))) (some v)))
  (define idx (make-hasheq))
  (define d1 (strip-with-origin! stx idx))
  (define d2 (strip-with-origin! stx (make-hasheq)))
  (check-equal? d1 d2 "the two strips must agree as DATA")
  (check-false (hash-ref idx (cadr (cadr d2)) #f)
               "but a node from a second strip must NOT resolve in the first index"))
