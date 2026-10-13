#lang racket/base
;; pnet-diff151b.rkt — DEFERRED 151 (b): does a v12 (fasl) body deserialize to the SAME data as the
;; v11 (text) body, for caches written the same way (one cold run each)?
;;   racket pnet-diff151b.rkt <v11 cache dir> <v11 root> <v12 cache dir> <v12 root>
;; 1. Per module: v11 body (2nd `read`) vs v12 body (newline, then fasl->s-exp), after replacing each
;;    tree's root prefix with "@ROOT@" and canonicalizing hashes (pnet-diff151.rkt's `norm`).
;; 2. What `norm` erases, counted on both sides: mutable strings / vectors / boxes / hashes, hash
;;    kinds (eq / eqv / equal), uninterned and unreadable symbols. A difference here is a semantic
;;    difference the equality check cannot see.
(require racket/file racket/list racket/string racket/path racket/fasl)
(define-values (d11 r11 d12 r12)
  (apply values (vector->list (current-command-line-arguments))))
(define (norm root v)
  (let loop ([v v])
    (cond
      [(string? v) (string-replace v root "@ROOT@")]
      [(path? v) (string-replace (path->string v) root "@ROOT@")]
      [(pair? v) (cons (loop (car v)) (loop (cdr v)))]
      [(vector? v) (for/vector #:length (vector-length v) ([x (in-vector v)]) (loop x))]
      [(hash? v)
       (list 'H (sort (for/list ([(k x) (in-hash v)]) (cons (format "~s" (loop k)) (loop x)))
                      string<? #:key car))]
      [(box? v) (box (loop (unbox v)))]
      [else v])))
(define (kinds v)
  (define c (make-hash))
  (define (inc! k) (hash-update! c k add1 0))
  (let loop ([v v])
    (cond
      [(string? v) (inc! (if (immutable? v) 'string-imm 'string-MUT))]
      [(symbol? v) (inc! (cond [(symbol-interned? v) 'sym-interned]
                               [(symbol-unreadable? v) 'sym-UNREADABLE]
                               [else 'sym-UNINTERNED]))]
      [(pair? v) (loop (car v)) (loop (cdr v))]
      [(vector? v) (inc! (if (immutable? v) 'vector-imm 'vector-MUT)) (for ([x (in-vector v)]) (loop x))]
      [(box? v) (inc! (if (immutable? v) 'box-imm 'box-MUT)) (loop (unbox v))]
      [(hash? v)
       (inc! (string->symbol (format "hash-~a-~a" (cond [(hash-eq? v) 'eq] [(hash-eqv? v) 'eqv] [else 'equal])
                                     (if (immutable? v) 'imm 'MUT))))
       (for ([(k x) (in-hash v)]) (loop k) (loop x))]
      [(bytes? v) (inc! (if (immutable? v) 'bytes-imm 'bytes-MUT))]
      [(flonum? v) (inc! 'flonum)]
      [(char? v) (inc! 'char)]
      [(keyword? v) (inc! 'keyword)]
      [else (void)]))
  c)
(define (merge! into c) (for ([(k n) (in-hash c)]) (hash-update! into k (λ (x) (+ x n)) 0)))
(define (rel dir f) (path->string (find-relative-path (simplify-path dir) (simplify-path f))))
(define (pnets d) (for/hash ([f (in-directory d)] #:when (regexp-match? #rx"[.]pnet$" (path->string f)))
                    (values (rel d f) f)))
(define f11 (pnets d11)) (define f12 (pnets d12))
(define common (sort (filter (λ (k) (hash-ref f12 k #f)) (hash-keys f11)) string<?))
(printf "modules: v11 ~a, v12 ~a, common ~a\n" (hash-count f11) (hash-count f12) (length common))
(define k11 (make-hash)) (define k12 (make-hash))
(define-values (n-eq b11 b12)
  (for/fold ([e 0] [b11 0] [b12 0]) ([k common])
    (define-values (h11 body11) (call-with-input-file (hash-ref f11 k) (λ (in) (let* ([h (read in)] [b (read in)]) (values h b)))))
    (define-values (h12 body12) (call-with-input-file (hash-ref f12 k)
                                  (λ (in) (let* ([h (read in)] [_ (read-char in)] [b (fasl->s-exp in)]) (values h b)))))
    (merge! k11 (kinds body11)) (merge! k12 (kinds body12))
    (define same (equal? (norm r11 body11) (norm r12 body12)))
    (define key-eq (equal? (norm r11 (caddr h11)) (norm r12 (caddr h12))))
    (unless (and same key-eq)
      (define slot (for/first ([a (norm r11 body11)] [b (norm r12 body12)] [i (in-naturals 2)] #:unless (equal? a b)) i))
      (printf "  DIFF ~a key-eq ~a first differing slot ~a\n" k key-eq slot))
    (values (if (and same key-eq) (add1 e) e)
            (+ b11 (file-size (hash-ref f11 k))) (+ b12 (file-size (hash-ref f12 k))))))
(printf "equal (modulo root path, canonical hashes): ~a / ~a   bytes v11 ~a  v12 ~a\n" n-eq (length common) b11 b12)
(define (~a-pad s) (let ([x (symbol->string s)]) (string-append x (make-string (max 0 (- 18 (string-length x))) #\space))))
(printf "what norm erases (count per kind, v11 text -> v12 fasl):\n")
(for ([k (sort (remove-duplicates (append (hash-keys k11) (hash-keys k12))) string<? #:key symbol->string)])
  (define a (hash-ref k11 k 0)) (define b (hash-ref k12 k 0))
  (printf "  ~a ~a -> ~a~a\n" (~a-pad k) a b (if (= a b) "" "   <-- DIFFERS")))
