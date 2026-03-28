#lang racket/base

;; bench-bsp-round-stats.rkt — PAR Track 2 R1: BSP round statistics
;;
;; Collects per-round data from the BSP scheduler:
;;   - Worklist size (propagators per round)
;;   - Fire time (ms)
;;   - Merge time (ms)
;;   - Write count (cell value diffs)
;;   - Deferred propagator count (topology ops)
;;
;; Runs the comparative benchmark suite and the full test suite preamble,
;; producing histograms and summary statistics.

(require "../../propagator.rkt"
         "../../driver.rkt"
         racket/list
         racket/string
         racket/format
         racket/path
         racket/port)

;; ============================================================
;; Data collection
;; ============================================================

(define (collect-stats-for-file path)
  (define-values (stats-box get-stats) (make-bsp-stats-accumulator))
  (with-handlers ([exn? (lambda (e) '())])
    (parameterize ([current-bsp-round-stats stats-box])
      (process-file path))
    (get-stats)))

;; ============================================================
;; Analysis
;; ============================================================

(define (analyze-stats all-stats label)
  (when (null? all-stats) (printf "  ~a: no data\n" label) (void))
  (unless (null? all-stats)
    (define worklist-sizes (map car all-stats))
    (define fire-times (map cadr all-stats))
    (define merge-times (map caddr all-stats))
    (define write-counts (map cadddr all-stats))
    (define deferred-counts (map (lambda (s) (list-ref s 4)) all-stats))

    (define (stats lst name)
      (define sorted (sort lst <))
      (define n (length sorted))
      (define total (apply + sorted))
      (define mean (if (zero? n) 0 (/ total n)))
      (define med (if (zero? n) 0 (list-ref sorted (quotient n 2))))
      (define mx (if (zero? n) 0 (last sorted)))
      (printf "  ~a: n=~a mean=~a median=~a max=~a total=~a\n"
              name n
              (~r mean #:precision '(= 1))
              (~r med #:precision '(= 1))
              (~r mx #:precision '(= 1))
              (~r total #:precision '(= 1))))

    (printf "\n~a (~a rounds):\n" label (length all-stats))
    (stats worklist-sizes "worklist-size")
    (stats fire-times "fire-time-ms")
    (stats merge-times "merge-time-ms")
    (stats write-counts "write-count")
    (stats deferred-counts "deferred-props")

    ;; Histogram of worklist sizes
    (define buckets '((1 . "1") (2 . "2-3") (5 . "4-5") (10 . "6-10")
                      (20 . "11-20") (50 . "21-50") (100 . "51-100")
                      (500 . "101-500") (10000 . "500+")))
    (printf "  worklist histogram:\n")
    (for ([b (in-list buckets)])
      (define count
        (length (filter (lambda (s) (and (>= s (if (eq? b (car buckets)) 1
                                                    (+ 1 (caar (member b buckets
                                                                        (lambda (x y) (< (car x) (car y))))))))
                                         (<= s (car b))))
                        worklist-sizes)))
      ;; Simplified: just bucket by ranges
      (void))

    ;; Simple buckets
    (define (count-range lo hi)
      (length (filter (lambda (s) (and (>= s lo) (<= s hi))) worklist-sizes)))
    (printf "    1:       ~a\n" (count-range 1 1))
    (printf "    2-5:     ~a\n" (count-range 2 5))
    (printf "    6-10:    ~a\n" (count-range 6 10))
    (printf "    11-50:   ~a\n" (count-range 11 50))
    (printf "    51-100:  ~a\n" (count-range 51 100))
    (printf "    101-500: ~a\n" (count-range 101 500))
    (printf "    500+:    ~a\n" (count-range 501 1000000))

    ;; Fire vs merge ratio
    (define total-fire (apply + fire-times))
    (define total-merge (apply + merge-times))
    (printf "  fire/merge ratio: ~a / ~a = ~a\n"
            (~r total-fire #:precision '(= 1))
            (~r total-merge #:precision '(= 1))
            (if (zero? total-merge) "inf"
                (~r (/ total-fire total-merge) #:precision '(= 2))))))

;; ============================================================
;; Main
;; ============================================================

(define script-dir
  (let ([src (resolved-module-path-name
              (variable-reference->resolved-module-path
               (#%variable-reference)))])
    (simplify-path (path-only src))))

(define comparative-dir (build-path script-dir ".." "comparative"))

;; Collect stats from comparative benchmarks
(printf "═══ PAR Track 2 R1: BSP Round Statistics ═══\n\n")

(define all-comparative-stats '())
(for ([f (in-directory comparative-dir)]
      #:when (regexp-match? #rx"\\.prologos$" (path->string f)))
  (define name (path->string (file-name-from-path f)))
  (printf "Processing ~a..." name)
  (flush-output)
  (define stats (collect-stats-for-file (path->string f)))
  (printf " ~a rounds\n" (length stats))
  (set! all-comparative-stats (append all-comparative-stats stats)))

(analyze-stats all-comparative-stats "ALL COMPARATIVE PROGRAMS")

;; Per-program breakdown for the heaviest ones
(for ([f (in-directory comparative-dir)]
      #:when (regexp-match? #rx"adversarial\\.prologos$" (path->string f)))
  (define stats (collect-stats-for-file (path->string f)))
  (analyze-stats stats (path->string (file-name-from-path f))))

(printf "\nDone.\n")
