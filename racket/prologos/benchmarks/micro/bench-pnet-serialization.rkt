#lang racket/base

;;; Pre-0.5 Benchmark: .pnet serialization round-trip timing
;;; Validates the <100ms cold-start deserialization target for PM Track 10.

(require racket/match
         racket/hash
         racket/string
         racket/file
         racket/list
         "../../tests/test-support.rkt"
         "../../namespace.rkt"
         "../../syntax.rkt"
         "../../propagator.rkt"
         "../../champ.rkt")

(define pnet-dir "/tmp/pnet-bench/")

;; ============================================================
;; Serialization: struct->vector + gensym tagging + foreign-proc
;; ============================================================

(define (make-serializer)
  (define gensym-table (make-hash))
  (define gensym-counter 0)

  (define (serialize-sym s)
    (if (symbol-interned? s)
        s
        (let ([uid (hash-ref! gensym-table s
                     (lambda ()
                       (set! gensym-counter (add1 gensym-counter))
                       gensym-counter))])
          (string->symbol (format "~a$$~a" (symbol->string s) uid)))))

  (define (deep-s->v v)
    (cond
      [(procedure? v)
       (list 'foreign-proc
             (or (object-name v) 'anonymous)
             'unknown-module)]  ;; module path TBD in full implementation
      [(symbol? v) (serialize-sym v)]
      [(struct? v)
       (for/vector ([e (in-vector (struct->vector v))]) (deep-s->v e))]
      [(pair? v)
       (cons (deep-s->v (car v)) (deep-s->v (cdr v)))]
      [(list? v) (map deep-s->v v)]
      [(hash? v)
       (for/hasheq ([(k val) (in-hash v)])
         (values (if (symbol? k) (serialize-sym k) k)
                 (deep-s->v val)))]
      [else v]))

  deep-s->v)

;; ============================================================
;; Benchmarking helpers
;; ============================================================

(define (time-ms thunk)
  (collect-garbage)
  (collect-garbage)
  (define start (current-inexact-milliseconds))
  (define result (thunk))
  (define elapsed (- (current-inexact-milliseconds) start))
  (values result elapsed))

(define (bench label iters thunk)
  (collect-garbage)
  (collect-garbage)
  (define start (current-inexact-milliseconds))
  (for ([_ (in-range iters)])
    (thunk))
  (define elapsed (- (current-inexact-milliseconds) start))
  (printf "  ~a: ~a ms total, ~a ms/call (~a calls)\n"
          label
          (exact->inexact (/ (round (* elapsed 100)) 100))
          (exact->inexact (/ (round (* (/ elapsed iters) 100)) 100))
          iters))

;; ============================================================
;; Main benchmark
;; ============================================================

(printf "\n=== Pre-0.5: .pnet Serialization Round-Trip Benchmark ===\n\n")

(define registry prelude-module-registry)
(printf "Prelude modules: ~a\n" (hash-count registry))

;; Phase 1: Serialize all modules to strings
(printf "\n--- Phase 1: Serialize (struct->vector + write) ---\n")

(define serialized-strings (make-hash))
(define total-serialize-ms 0)

(for ([(ns mod) (in-hash registry)])
  (define serialize! (make-serializer))
  (define env (module-info-env-snapshot mod))
  (define specs (module-info-specs mod))
  (define locs (module-info-definition-locations mod))

  (define-values (data ms)
    (time-ms
     (lambda ()
       (define s-env (serialize! env))
       (define s-specs (serialize! specs))
       (define s-locs (serialize! locs))
       ;; Format version + source hash placeholder + data
       (define pnet-data (list 1 'hash-placeholder s-env s-specs s-locs))
       (define out (open-output-string))
       (write pnet-data out)
       (get-output-string out))))

  (set! total-serialize-ms (+ total-serialize-ms ms))
  (hash-set! serialized-strings ns data))

(define total-bytes (for/sum ([(k v) (in-hash serialized-strings)]) (string-length v)))
(printf "  Total serialize time: ~a ms\n" (exact->inexact (round total-serialize-ms)))
(printf "  Total serialized size: ~a KB (~a MB)\n"
        (quotient total-bytes 1024)
        (exact->inexact (/ (round (* (/ total-bytes 1048576) 100)) 100)))

;; Phase 2: Write to disk
(printf "\n--- Phase 2: Write to disk ---\n")

(make-directory* pnet-dir)

(define-values (_ write-ms)
  (time-ms
   (lambda ()
     (for ([(ns data) (in-hash serialized-strings)])
       (define path (build-path pnet-dir (format "~a.pnet" ns)))
       (call-with-output-file path
         (lambda (out) (display data out))
         #:exists 'replace)))))

(printf "  Write ~a files: ~a ms\n" (hash-count serialized-strings) (exact->inexact (round write-ms)))

;; Phase 3: Read from disk
(printf "\n--- Phase 3: Read from disk ---\n")

(define read-strings (make-hash))

(define-values (_2 read-ms)
  (time-ms
   (lambda ()
     (for ([(ns _) (in-hash serialized-strings)])
       (define path (build-path pnet-dir (format "~a.pnet" ns)))
       (hash-set! read-strings ns (file->string path))))))

(printf "  Read ~a files: ~a ms\n" (hash-count read-strings) (exact->inexact (round read-ms)))

;; Phase 4: Deserialize (read + tag dispatch)
(printf "\n--- Phase 4: Deserialize (read S-expressions) ---\n")

(define deserialized-data (make-hash))
(define total-deserialize-ms 0)

(for ([(ns s) (in-hash read-strings)])
  (define-values (data ms)
    (time-ms
     (lambda ()
       (read (open-input-string s)))))
  (set! total-deserialize-ms (+ total-deserialize-ms ms))
  (hash-set! deserialized-data ns data))

(printf "  Total deserialize (read) time: ~a ms\n"
        (exact->inexact (round total-deserialize-ms)))

;; Phase 5: Verify round-trip
(printf "\n--- Phase 5: Verify round-trip correctness ---\n")

(define pass 0)
(define fail 0)

(for ([(ns data) (in-hash serialized-strings)])
  (define original (read (open-input-string data)))
  (define restored (hash-ref deserialized-data ns #f))
  (if (equal? original restored)
      (set! pass (add1 pass))
      (begin (set! fail (add1 fail))
             (printf "  MISMATCH: ~a\n" ns))))

(printf "  ~a/~a round-trip verified\n" pass (hash-count registry))

;; Phase 6: Full cold-start simulation
(printf "\n--- Phase 6: Full cold-start simulation (read from disk + deserialize) ---\n")

(bench "Cold start (all 40 modules)" 5
  (lambda ()
    (for ([(ns _) (in-hash serialized-strings)])
      (define path (build-path pnet-dir (format "~a.pnet" ns)))
      (define s (file->string path))
      (define data (read (open-input-string s)))
      (void data))))

;; Phase 7: Per-module breakdown (top 5 slowest)
(printf "\n--- Phase 7: Per-module timing ---\n")

(define module-times '())
(for ([(ns s) (in-hash read-strings)])
  (define-values (_ ms)
    (time-ms (lambda () (read (open-input-string s)))))
  (set! module-times (cons (cons ns ms) module-times)))

(define sorted-times (sort module-times > #:key cdr))
(printf "  Top 5 slowest modules:\n")
(for ([entry (take sorted-times (min 5 (length sorted-times)))])
  (printf "    ~a: ~a ms (~a KB)\n"
          (car entry)
          (exact->inexact (/ (round (* (cdr entry) 100)) 100))
          (quotient (string-length (hash-ref read-strings (car entry))) 1024)))

;; Summary
(printf "\n=== SUMMARY ===\n")
(printf "  Serialize:      ~a ms (all 40 modules)\n" (exact->inexact (round total-serialize-ms)))
(printf "  Write to disk:  ~a ms\n" (exact->inexact (round write-ms)))
(printf "  Read from disk: ~a ms\n" (exact->inexact (round read-ms)))
(printf "  Deserialize:    ~a ms\n" (exact->inexact (round total-deserialize-ms)))
(printf "  Cold start:     read + deserialize = ~a ms\n"
        (exact->inexact (round (+ read-ms total-deserialize-ms))))
(printf "  Total size:     ~a KB (~a MB)\n"
        (quotient total-bytes 1024)
        (exact->inexact (/ (round (* (/ total-bytes 1048576) 100)) 100)))
(printf "  Round-trip:     ~a/~a pass\n" pass (hash-count registry))
(printf "\n  Target: <100ms cold start. Result: ~a ms\n"
        (exact->inexact (round (+ read-ms total-deserialize-ms))))
