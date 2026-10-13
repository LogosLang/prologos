#lang racket/base
;;;
;;; test-champ-key-equality.rkt — DEFERRED 146: how CHAMP compares keys
;;;
;;; Racket CS's `equal?` allocates on EVERY top-level comparison of two distinct
;;; records (rumble/equal.ss: the record branch builds a `deeper-context` box and a
;;; recursion closure; measured 64 B for a one-field struct, transparent, prefab,
;;; authentic, custom prop:equal+hash and opaque alike). CHAMP data entries already
;;; store the caller's hash, and every production caller hashes consistently with
;;; `equal?`, so two keys whose hashes differ cannot be equal: comparing the stored
;;; hash first is sound and skips `equal?` entirely.
;;;
;;; Measured on benchmarks/comparative (19 files, instrumented build): 76 % of
;;; data-entry comparisons are `eq?` hits (0 B); 20 % reach `equal?` with DIFFERENT
;;; hashes — almost all inserts of a new key onto another key's data entry — and
;;; carry 85 % of the `equal?` bytes; 3.5 % are fresh-but-equal hits.
;;;
;;; The pins count `equal?` invocations through a key type whose equal-proc counts
;;; itself, so they are exact and do not depend on allocation figures.

(require rackunit
         rackcheck
         racket/list
         "../champ.rkt")

;; ---- a key whose equal? calls are counted --------------------------------
(define equal-calls 0)
(struct ckey (n)
  #:property prop:equal+hash
  (list (lambda (a b rec) (set! equal-calls (add1 equal-calls)) (= (ckey-n a) (ckey-n b)))
        (lambda (a rec) (ckey-n a))
        (lambda (a rec) (ckey-n a))))
(define-syntax-rule (count-equal-calls body ...)
  (begin (set! equal-calls 0) (let () body ... (void)) equal-calls))

;; All keys share level-0 segment 0 (hash = 32n), so the second key lands on the
;; first key's data entry — the path that used to call equal? to learn "different".
(define (h32 k) (* 32 (ckey-n k)))
(define (build keys) (for/fold ([m champ-empty]) ([k (in-list keys)]) (champ-insert m (h32 k) k (ckey-n k))))

(test-case "146: inserting a NEW key onto another key's data entry never calls equal?"
  (define keys (for/list ([i 20]) (ckey i)))
  (check-equal? (count-equal-calls (build keys)) 0))

(test-case "146: a miss whose path ends on a different-hash data entry never calls equal?"
  (define m (build (for/list ([i 20]) (ckey i))))
  ;; ckey 99 (hash 3168) and ckey 3 (hash 96) share level-0 AND level-1 segments
  (check-equal? (count-equal-calls (check-equal? (champ-lookup m (h32 (ckey 99)) (ckey 99)) 'none)) 0)
  (check-equal? (count-equal-calls (check-false (champ-has-key? m (h32 (ckey 99)) (ckey 99)))) 0)
  (check-equal? (count-equal-calls (champ-delete m (h32 (ckey 99)) (ckey 99))) 0))

(test-case "146: a fresh but equal key is still found — exactly one equal? call"
  (define m (build (for/list ([i 20]) (ckey i))))
  (define fresh (ckey 5))
  (check-equal? (count-equal-calls (check-equal? (champ-lookup m (h32 fresh) fresh) 5)) 1)
  ;; and updating through a fresh key replaces, not adds
  (define m2 (champ-insert m (h32 fresh) fresh 'five))
  (check-equal? (champ-size m2) 20)
  (check-equal? (champ-lookup m2 (h32 (ckey 5)) (ckey 5)) 'five))

(test-case "146: a stored key is found by eq? alone — zero equal? calls"
  (define keys (for/list ([i 20]) (ckey i)))
  (define m (build keys))
  (check-equal? (count-equal-calls (for ([k keys]) (champ-lookup m (h32 k) k))) 0))

(test-case "146: true hash collisions (same hash, unequal keys) still separate"
  (define (h-coll k) 7)                       ;; every key collides
  (define m (for/fold ([m champ-empty]) ([i 5]) (champ-insert m (h-coll (ckey i)) (ckey i) i)))
  (check-equal? (champ-size m) 5)
  (for ([i 5]) (check-equal? (champ-lookup m 7 (ckey i)) i))
  (check-equal? (champ-lookup m 7 (ckey 9)) 'none)
  (define m2 (champ-delete m 7 (ckey 2)))
  (check-equal? (champ-size m2) 4)
  (check-equal? (champ-lookup m2 7 (ckey 2)) 'none))

(test-case "146: owner-ID transient insert / insert-join / delete skip equal? on differing hashes"
  (define-values (root edit size) (champ-transient-owned champ-empty))
  (define sb (box size))
  (define calls
    (count-equal-calls
     (define n1
       (for/fold ([n root]) ([i 20])
         (define-values (n* _a) (tchamp-insert-owned! n sb (* 32 i) (ckey i) i edit))
         n*))
     (define n2
       (for/fold ([n n1]) ([i (in-range 20 40)])
         (define-values (n* _a) (tchamp-insert-join-owned! n sb (* 32 i) (ckey i) i + edit))
         n*))
     ;; delete absent keys whose paths end on different-hash data entries
     (for/fold ([n n2]) ([i (in-range 99 104)])
       (define-values (n* _r) (tchamp-delete-owned! n sb (* 32 i) (ckey i) edit))
       n*)))
  (check-equal? calls 0)
  (check-equal? (unbox sb) 40))

;; ---- the model property: CHAMP ≡ an equal?-keyed immutable hash --------------
;; Keys are FRESH instances on every operation (equal, never eq), and the hash
;; function forces both shared segments (32 * …) and full collisions (pairs 2m,
;; 2m+1 share a hash), so every comparison path is exercised.
(define (hk k) (* 32 (quotient (ckey-n k) 2)))
(define gen:op
  (gen:let ([tag (gen:one-of '(ins ins tins del look))] [n (gen:integer-in 0 23)] [v (gen:integer-in 0 9)])
    (list tag n v)))

(test-case "146: property — persistent CHAMP agrees with an equal?-hash model"
  (check-property
   (make-config #:tests 300)
   (property ([ops (gen:list gen:op #:max-length 60)])
     (define-values (m ref)
       (for/fold ([m champ-empty] [ref (hash)]) ([op (in-list ops)])
         (define k (ckey (cadr op)))
         (case (car op)
           [(ins tins) (values (champ-insert m (hk k) k (caddr op)) (hash-set ref k (caddr op)))]
           [(del) (values (champ-delete m (hk k) k) (hash-remove ref k))]
           [else
            (check-equal? (champ-lookup m (hk k) k) (hash-ref ref k 'none))
            (values m ref)])))
     (check-equal? (champ-size m) (hash-count ref))
     (for ([i 24])
       (define k (ckey i))
       (check-equal? (champ-lookup m (hk k) k) (hash-ref ref k 'none))
       (check-equal? (champ-has-key? m (hk k) k) (hash-has-key? ref k))))))

(test-case "146: property — owner-ID transient CHAMP agrees with the model after freeze"
  (check-property
   (make-config #:tests 300)
   (property ([ops (gen:list gen:op #:max-length 60)])
     (define-values (root edit size) (champ-transient-owned champ-empty))
     (define sb (box size))
     (define-values (n ref)
       (for/fold ([n root] [ref (hash)]) ([op (in-list ops)])
         (define k (ckey (cadr op)))
         (case (car op)
           [(ins) (define-values (n* _a) (tchamp-insert-join-owned! n sb (hk k) k (caddr op) max edit))
                  (values n* (hash-update ref k (lambda (old) (max old (caddr op))) (caddr op)))]
           [(tins) (define-values (n* _a) (tchamp-insert-owned! n sb (hk k) k (caddr op) edit))
                   (values n* (hash-set ref k (caddr op)))]
           [(del) (define-values (n* _r) (tchamp-delete-owned! n sb (hk k) k edit))
                  (values n* (hash-remove ref k))]
           [else (values n ref)])))
     (define m (tchamp-freeze-owned n (unbox sb) edit))
     (check-equal? (champ-size m) (hash-count ref))
     (for ([i 24])
       (define k (ckey i))
       (check-equal? (champ-lookup m (hk k) k) (hash-ref ref k 'none))))))
