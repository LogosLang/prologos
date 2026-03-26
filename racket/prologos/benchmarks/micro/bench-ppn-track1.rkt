#lang racket/base

;;;
;;; bench-ppn-track1.rkt — Microbenchmarks for PPN Track 1: Lexer + Structure as Propagators
;;;
;;; Measures tokenizer throughput, structure-building costs, indent resolution
;;; simulation, content-addressed hashing, and E2E reader costs on real files.
;;; Run from racket/prologos/:
;;;
;;;   "/Applications/Racket v9.0/bin/racket" benchmarks/micro/bench-ppn-track1.rkt
;;;

(require "../../reader.rkt"
         "../../driver.rkt"
         "../../propagator.rkt"
         "../../parse-lattice.rkt"
         "../../tests/test-support.rkt"
         racket/file
         racket/list
         racket/port
         racket/string)

;; ============================================================
;; Bench macro — inline timing (no dependency on bench-micro.rkt)
;; ============================================================

(define-syntax-rule (bench label iters body ...)
  (let ()
    (collect-garbage) (collect-garbage)
    (define start (current-inexact-milliseconds))
    (for ([_ (in-range iters)])
      body ...)
    (define elapsed (- (current-inexact-milliseconds) start))
    (printf "  ~a: ~a ns/call (~a calls, ~a ms total)\n"
            label
            (exact->inexact (/ (* elapsed 1000000) iters))
            iters
            (exact->inexact elapsed))))

;; ============================================================
;; Test strings
;; ============================================================

(define representative-string
  (string-append
   "def x : Int := 42\n"
   "spec f Int -> Int\n"
   "defn f [x] [int+ x 1]\n"
   "def greeting := \"hello world\"\n"
   "'[1 2 3 4 5]\n"
   "{:name \"alice\" :age 30}"))

(define large-string
  (string-join (make-list 50 representative-string) "\n"))

(define many-identifiers-string
  (string-join (build-list 100 (lambda (i) (format "ident_~a" i))) " "))

(define deeply-nested-brackets "[[[[[[[[[[[x]]]]]]]]]]]")

(define deeply-indented-string
  (string-append
   "def x\n"
   "  where\n"
   "    a\n"
   "      b\n"
   "        c\n"
   "          d\n"
   "            e\n"
   "              f\n"
   "                g\n"
   "                  h"))

(define bracket-heavy-string
  "[map [fn [x : Int] [int+ [int* x 2] [int- x 1]]] '[1 2 3 4 5]]")


;; ============================================================
;; Accumulator to prevent dead-code elimination
;; ============================================================
(define accum (box #f))
(define (keep! v) (set-box! accum v))


;; ============================================================
;; A. Tokenizer Breakdown
;; ============================================================

(printf "\n=== A. Tokenizer Breakdown ===\n\n")

;; A1: tokenize-string on representative string
(printf "--- A1: tokenize-string on representative multi-form string ---\n")
(define a1-tokens #f)
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (set! a1-tokens (tokenize-string representative-string))
  (define token-count (length a1-tokens))
  (printf "  Token count: ~a\n" token-count)
  (collect-garbage) (collect-garbage)
  (define start (current-inexact-milliseconds))
  (for ([_ (in-range 100)])
    (keep! (tokenize-string representative-string)))
  (define elapsed (- (current-inexact-milliseconds) start))
  (define total-ns (* elapsed 1000000))
  (printf "  Total: ~a ns/call (~a calls, ~a ms total)\n"
          (exact->inexact (/ total-ns 100))
          100
          (exact->inexact elapsed))
  (printf "  Per-token: ~a ns/token\n"
          (exact->inexact (/ total-ns (* 100 token-count)))))

;; A2: Token type distribution
(printf "\n--- A2: Token type distribution ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (when a1-tokens
    (define type-counts (make-hash))
    (for ([tok (in-list a1-tokens)])
      (define tt (token-type tok))
      (hash-set! type-counts tt (add1 (hash-ref type-counts tt 0))))
    (for ([(tt count) (in-hash type-counts)])
      (printf "  ~a: ~a\n" tt count))))

;; A3: tokenize-string on LARGE string (50x repeat)
(printf "\n--- A3: tokenize-string on LARGE string (50x repeat) ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (define large-tokens (tokenize-string large-string))
  (define large-token-count (length large-tokens))
  (printf "  Large token count: ~a\n" large-token-count)
  (collect-garbage) (collect-garbage)
  (define start (current-inexact-milliseconds))
  (for ([_ (in-range 10)])
    (keep! (tokenize-string large-string)))
  (define elapsed (- (current-inexact-milliseconds) start))
  (define total-ns (* elapsed 1000000))
  (printf "  Total: ~a ns/call (~a calls, ~a ms total)\n"
          (exact->inexact (/ total-ns 10))
          10
          (exact->inexact elapsed))
  (printf "  Per-token: ~a ns/token\n"
          (exact->inexact (/ total-ns (* 10 large-token-count))))
  (when a1-tokens
    (define small-per-token
      (let ()
        (collect-garbage) (collect-garbage)
        (define s (current-inexact-milliseconds))
        (for ([_ (in-range 100)])
          (keep! (tokenize-string representative-string)))
        (define e (- (current-inexact-milliseconds) s))
        (/ (* e 1000000) (* 100 (length a1-tokens)))))
    (define large-per-token (/ total-ns (* 10 large-token-count)))
    (printf "  Scaling factor (large/small per-token): ~a\n"
            (exact->inexact (/ large-per-token small-per-token)))))

;; A4: tokenize-string on many identifiers
(printf "\n--- A4: tokenize-string on 100 identifiers ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (bench "100 identifiers" 100 (keep! (tokenize-string many-identifiers-string))))

;; A5: tokenize-string on deeply nested brackets
(printf "\n--- A5: tokenize-string on deeply nested brackets ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (bench "nested brackets (10 deep)" 100 (keep! (tokenize-string deeply-nested-brackets))))


;; ============================================================
;; B. Structure Building Breakdown
;; ============================================================

(printf "\n=== B. Structure Building Breakdown ===\n\n")

;; B1: read-all-forms-string on representative string
(printf "--- B1: read-all-forms-string on representative string ---\n")
(define b1-elapsed #f)
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (collect-garbage) (collect-garbage)
  (define start (current-inexact-milliseconds))
  (for ([_ (in-range 100)])
    (keep! (read-all-forms-string representative-string)))
  (set! b1-elapsed (- (current-inexact-milliseconds) start))
  (printf "  read-all-forms-string: ~a ns/call (~a calls, ~a ms total)\n"
          (exact->inexact (/ (* b1-elapsed 1000000) 100))
          100
          (exact->inexact b1-elapsed)))

;; B2: Structure time = B1 - A1
(printf "\n--- B2: Structure time = B1 - A1 ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  ;; Re-measure A1 in same conditions for fair comparison
  (collect-garbage) (collect-garbage)
  (define a1-start (current-inexact-milliseconds))
  (for ([_ (in-range 100)])
    (keep! (tokenize-string representative-string)))
  (define a1-elapsed (- (current-inexact-milliseconds) a1-start))
  (when b1-elapsed
    (define structure-ms (- b1-elapsed a1-elapsed))
    (printf "  Tokenize (A1): ~a ms/100 calls\n" (exact->inexact a1-elapsed))
    (printf "  Read-all (B1): ~a ms/100 calls\n" (exact->inexact b1-elapsed))
    (printf "  Structure only: ~a ms/100 calls (~a ns/call)\n"
            (exact->inexact structure-ms)
            (exact->inexact (/ (* structure-ms 1000000) 100)))
    (printf "  Ratio (structure/total): ~a\n"
            (if (> b1-elapsed 0)
                (exact->inexact (/ structure-ms b1-elapsed))
                "N/A"))))

;; B3: read-all-forms-string on LARGE string (50x)
(printf "\n--- B3: read-all-forms-string on LARGE string (50x) ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (bench "large string (50x)" 10 (keep! (read-all-forms-string large-string))))

;; B4: read-all-forms-string on deeply indented content
(printf "\n--- B4: read-all-forms-string on deeply indented content ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (bench "deeply indented" 100 (keep! (read-all-forms-string deeply-indented-string))))

;; B5: Line and indent analysis (no timing)
(printf "\n--- B5: Line and indent analysis of representative string ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (define lines (string-split representative-string "\n"))
  (printf "  Line count: ~a\n" (length lines))
  (define indents
    (for/list ([line (in-list lines)])
      (define trimmed (string-trim line #:left? #t #:right? #f))
      (- (string-length line) (string-length trimmed))))
  (printf "  Indent levels: ~a\n" indents)
  (define avg-indent
    (if (null? indents) 0
        (/ (apply + indents) (length indents))))
  (printf "  Average indent depth: ~a\n" (exact->inexact avg-indent)))

;; B6: read-all-forms-string on bracket-heavy content
(printf "\n--- B6: read-all-forms-string on bracket-heavy content ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (bench "bracket-heavy" 100 (keep! (read-all-forms-string bracket-heavy-string))))


;; ============================================================
;; C. Constraint Chain Simulation (indent resolution)
;; ============================================================

(printf "\n=== C. Constraint Chain Simulation ===\n\n")

;; Simulate indent resolution: given indent levels, compute parent-child map
(define (resolve-parents indent-levels)
  (define stack '())  ;; list of (indent . line-id)
  (for/list ([indent (in-list indent-levels)]
             [i (in-naturals)])
    ;; Pop until top < indent
    (set! stack (let loop ([s stack])
                  (if (and (pair? s) (>= (car (car s)) indent))
                      (loop (cdr s))
                      s)))
    (define parent (if (null? stack) 'root (cdr (car stack))))
    (set! stack (cons (cons indent i) stack))
    (cons i parent)))

;; Simulate incremental resolution: resolve from a start index onward
(define (resolve-parents-incremental indent-levels start-index initial-stack)
  (define stack initial-stack)
  (for/list ([indent (in-list (list-tail indent-levels start-index))]
             [i (in-naturals start-index)])
    (set! stack (let loop ([s stack])
                  (if (and (pair? s) (>= (car (car s)) indent))
                      (loop (cdr s))
                      s)))
    (define parent (if (null? stack) 'root (cdr (car stack))))
    (set! stack (cons (cons indent i) stack))
    (cons i parent)))

(define base-indent-pattern '(0 2 4 2 0 2 4 4 2 0))

;; C1: 200 lines, 100 iterations
(printf "--- C1: Indent resolution, 200 lines ---\n")
(define indent-200
  (apply append (make-list 20 base-indent-pattern)))

(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (bench "resolve-parents 200 lines" 100 (keep! (resolve-parents indent-200))))

;; C2: 2000 lines, 10 iterations
(printf "\n--- C2: Indent resolution, 2000 lines ---\n")
(define indent-2000
  (apply append (make-list 200 base-indent-pattern)))

(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (bench "resolve-parents 2000 lines" 10 (keep! (resolve-parents indent-2000))))

;; C3: Full vs incremental resolution
(printf "\n--- C3: Full vs incremental resolution ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  ;; Modify indent at line 100: change from 2 to 4
  (define indent-200-modified
    (for/list ([indent (in-list indent-200)]
               [i (in-naturals)])
      (if (= i 100) 4 indent)))
  ;; Full resolution
  (collect-garbage) (collect-garbage)
  (define full-start (current-inexact-milliseconds))
  (for ([_ (in-range 100)])
    (keep! (resolve-parents indent-200-modified)))
  (define full-elapsed (- (current-inexact-milliseconds) full-start))
  (printf "  Full re-resolve (200 lines): ~a ns/call\n"
          (exact->inexact (/ (* full-elapsed 1000000) 100)))
  ;; Build stack state at line 100 by resolving first 100 lines
  (define pre-stack
    (let ([stack '()])
      (for ([indent (in-list (take indent-200-modified 100))]
            [i (in-naturals)])
        (set! stack (let loop ([s stack])
                      (if (and (pair? s) (>= (car (car s)) indent))
                          (loop (cdr s))
                          s)))
        (set! stack (cons (cons indent i) stack)))
      stack))
  ;; Incremental resolution from line 100 onward
  (collect-garbage) (collect-garbage)
  (define incr-start (current-inexact-milliseconds))
  (for ([_ (in-range 100)])
    (keep! (resolve-parents-incremental indent-200-modified 100 pre-stack)))
  (define incr-elapsed (- (current-inexact-milliseconds) incr-start))
  (printf "  Incremental from line 100 (100 lines): ~a ns/call\n"
          (exact->inexact (/ (* incr-elapsed 1000000) 100)))
  (printf "  Speedup (full/incremental): ~a\n"
          (if (> incr-elapsed 0)
              (exact->inexact (/ full-elapsed incr-elapsed))
              "N/A")))

;; C4: Max stack depth
(printf "\n--- C4: Context cell size (max stack depth) ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (define max-depth 0)
  (define stack '())
  (for ([indent (in-list indent-200)]
        [i (in-naturals)])
    (set! stack (let loop ([s stack])
                  (if (and (pair? s) (>= (car (car s)) indent))
                      (loop (cdr s))
                      s)))
    (set! stack (cons (cons indent i) stack))
    (when (> (length stack) max-depth)
      (set! max-depth (length stack))))
  (printf "  Max stack depth for 200 lines: ~a\n" max-depth)
  ;; Also for 2000 lines
  (set! max-depth 0)
  (set! stack '())
  (for ([indent (in-list indent-2000)]
        [i (in-naturals)])
    (set! stack (let loop ([s stack])
                  (if (and (pair? s) (>= (car (car s)) indent))
                      (loop (cdr s))
                      s)))
    (set! stack (cons (cons indent i) stack))
    (when (> (length stack) max-depth)
      (set! max-depth (length stack))))
  (printf "  Max stack depth for 2000 lines: ~a\n" max-depth))


;; ============================================================
;; D. Golden Baseline Capture (analysis, not timing)
;; ============================================================

(printf "\n=== D. Golden Baseline Capture ===\n\n")

;; D1: Count .prologos files
(printf "--- D1: .prologos file counts ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (define (find-prologos-files dir)
    (if (directory-exists? dir)
        (let loop ([path dir] [acc '()])
          (for/fold ([acc acc]) ([entry (in-list (directory-list path #:build? #t))])
            (cond
              [(directory-exists? entry) (loop entry acc)]
              [(regexp-match? #rx"\\.prologos$" (path->string entry))
               (cons entry acc)]
              [else acc])))
        '()))
  (define lib-files (find-prologos-files (build-path "lib" "prologos")))
  (define example-files (find-prologos-files (build-path "examples")))
  (printf "  lib/prologos/: ~a files\n" (length lib-files))
  (printf "  examples/: ~a files\n" (length example-files))
  (printf "  Total: ~a files\n" (+ (length lib-files) (length example-files))))

;; D2: Representative file stats
(printf "\n--- D2: Representative file stats ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (define (file-stats path)
    (if (file-exists? path)
        (let ()
          (define content (file->string path))
          (define lines (string-split content "\n"))
          (define tokens (tokenize-string content))
          (define forms (read-all-forms-string content))
          (printf "  ~a:\n    Lines: ~a  Tokens: ~a  Forms: ~a\n"
                  path (length lines) (length tokens) (length forms)))
        (printf "  ~a: NOT FOUND\n" path)))
  ;; Smallest: core.prologos (60 lines)
  (file-stats "lib/prologos/core.prologos")
  ;; Medium: data/nat.prologos
  (file-stats "lib/prologos/data/nat.prologos")
  ;; Large: data/list.prologos (584 lines)
  (file-stats "lib/prologos/data/list.prologos"))

;; D3: Largest file
(printf "\n--- D3: Largest .prologos file ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (define (find-all-prologos)
    (define dirs (list (build-path "lib" "prologos") (build-path "examples")))
    (apply append
           (for/list ([dir (in-list dirs)])
             (if (directory-exists? dir)
                 (let loop ([path dir] [acc '()])
                   (for/fold ([acc acc]) ([entry (in-list (directory-list path #:build? #t))])
                     (cond
                       [(directory-exists? entry) (loop entry acc)]
                       [(regexp-match? #rx"\\.prologos$" (path->string entry))
                        (cons entry acc)]
                       [else acc])))
                 '()))))
  (define all-files (find-all-prologos))
  (define-values (largest-path largest-lines)
    (for/fold ([best #f] [best-lines 0])
              ([f (in-list all-files)])
      (define content (file->string f))
      (define n (length (string-split content "\n")))
      (if (> n best-lines)
          (values f n)
          (values best best-lines))))
  (when largest-path
    (printf "  Largest: ~a (~a lines)\n" largest-path largest-lines)))


;; ============================================================
;; E. E2E Reader Costs
;; ============================================================

(printf "\n=== E. E2E Reader Costs ===\n\n")

;; E1: core.prologos
(printf "--- E1: read-all-forms-string on lib/prologos/core.prologos ---\n")
(define e1-path "lib/prologos/core.prologos")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (when (file-exists? e1-path)
    (define content (file->string e1-path))
    (printf "  Size: ~a bytes, ~a lines\n"
            (string-length content) (length (string-split content "\n")))
    (bench "core.prologos" 20 (keep! (read-all-forms-string content)))))

;; E2: data/list.prologos
(printf "\n--- E2: read-all-forms-string on lib/prologos/data/list.prologos ---\n")
(define e2-path "lib/prologos/data/list.prologos")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (when (file-exists? e2-path)
    (define content (file->string e2-path))
    (printf "  Size: ~a bytes, ~a lines\n"
            (string-length content) (length (string-split content "\n")))
    (bench "list.prologos" 20 (keep! (read-all-forms-string content)))))

;; E3: acceptance file (may not exist yet)
(printf "\n--- E3: read-all-forms-string on acceptance file ---\n")
(define e3-path "examples/2026-03-26-ppn-track0.prologos")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (if (file-exists? e3-path)
      (let ()
        (define content (file->string e3-path))
        (printf "  Size: ~a bytes, ~a lines\n"
                (string-length content) (length (string-split content "\n")))
        (bench "ppn-track0 acceptance" 20 (keep! (read-all-forms-string content))))
      ;; Fallback: use a large example file
      (let ()
        (define fallback "examples/numerics-tutorial-demo.prologos")
        (if (file-exists? fallback)
            (let ()
              (define content (file->string fallback))
              (printf "  Acceptance file not found, using fallback: ~a\n" fallback)
              (printf "  Size: ~a bytes, ~a lines\n"
                      (string-length content) (length (string-split content "\n")))
              (bench "fallback large file" 20 (keep! (read-all-forms-string content))))
            (printf "  SKIPPED: no acceptance or fallback file found\n")))))


;; ============================================================
;; F. Content-Addressed Hashing
;; ============================================================

(printf "\n=== F. Content-Addressed Hashing ===\n\n")

;; F1: Create 1000 token-cell-value structs, measure hash throughput
(printf "--- F1: Hash throughput on 1000 token-cell-value structs ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (define structs
    (for/vector ([i (in-range 1000)])
      (make-token 'identifier
                  (format "ident_~a" i)
                  (* i 10)
                  (+ (* i 10) 6)
                  0
                  #f)))
  (collect-garbage) (collect-garbage)
  (define start (current-inexact-milliseconds))
  (for ([_ (in-range 10000)])
    (for ([s (in-vector structs)])
      (keep! (equal-hash-code s))))
  (define elapsed (- (current-inexact-milliseconds) start))
  (define total-hashes (* 10000 1000))
  (printf "  ~a ns/hash (~a hashes, ~a ms total)\n"
          (exact->inexact (/ (* elapsed 1000000) total-hashes))
          total-hashes
          (exact->inexact elapsed)))

;; F2: Insert 1000 structs into hash, measure lookup throughput
(printf "\n--- F2: Hash lookup throughput ---\n")
(with-handlers ([exn:fail? (lambda (e) (printf "  SKIPPED: ~a\n" (exn-message e)))])
  (define structs
    (for/vector ([i (in-range 1000)])
      (make-token 'identifier
                  (format "ident_~a" i)
                  (* i 10)
                  (+ (* i 10) 6)
                  0
                  #f)))
  ;; Build the hash table
  (define ht (make-hash))
  (for ([s (in-vector structs)]
        [i (in-naturals)])
    (hash-set! ht s i))
  (printf "  Hash table size: ~a entries\n" (hash-count ht))
  ;; Measure lookup
  (collect-garbage) (collect-garbage)
  (define start (current-inexact-milliseconds))
  (for ([_ (in-range 10000)])
    (for ([s (in-vector structs)])
      (keep! (hash-ref ht s #f))))
  (define elapsed (- (current-inexact-milliseconds) start))
  (define total-lookups (* 10000 1000))
  (printf "  ~a ns/lookup (~a lookups, ~a ms total)\n"
          (exact->inexact (/ (* elapsed 1000000) total-lookups))
          total-lookups
          (exact->inexact elapsed)))


;; ============================================================
;; Summary
;; ============================================================

(printf "\n=== SUMMARY ===\n\n")

(with-handlers ([exn:fail? (lambda (e) (printf "  Summary computation error: ~a\n" (exn-message e)))])
  ;; Re-measure for summary: tokenize vs read-all on representative string
  (collect-garbage) (collect-garbage)
  (define tok-start (current-inexact-milliseconds))
  (for ([_ (in-range 100)])
    (keep! (tokenize-string representative-string)))
  (define tok-elapsed (- (current-inexact-milliseconds) tok-start))

  (collect-garbage) (collect-garbage)
  (define read-start (current-inexact-milliseconds))
  (for ([_ (in-range 100)])
    (keep! (read-all-forms-string representative-string)))
  (define read-elapsed (- (current-inexact-milliseconds) read-start))

  (define structure-fraction
    (if (> read-elapsed 0) (/ (- read-elapsed tok-elapsed) read-elapsed) 0))

  (printf "--- Tokenizer vs structure time ratio ---\n")
  (printf "  Tokenize: ~a ms/100 calls\n" (exact->inexact tok-elapsed))
  (printf "  Read-all: ~a ms/100 calls\n" (exact->inexact read-elapsed))
  (printf "  Structure fraction: ~a%%\n"
          (exact->inexact (* 100 structure-fraction)))

  ;; Per-token cost at different scales
  (printf "\n--- Per-token cost at different scales ---\n")
  (define small-tokens (tokenize-string representative-string))
  (define small-per-token-ns
    (/ (* tok-elapsed 1000000) (* 100 (length small-tokens))))
  (printf "  Small (~a tokens): ~a ns/token\n"
          (length small-tokens)
          (exact->inexact small-per-token-ns))

  (collect-garbage) (collect-garbage)
  (define large-tok-start (current-inexact-milliseconds))
  (for ([_ (in-range 10)])
    (keep! (tokenize-string large-string)))
  (define large-tok-elapsed (- (current-inexact-milliseconds) large-tok-start))
  (define large-tokens (tokenize-string large-string))
  (define large-per-token-ns
    (/ (* large-tok-elapsed 1000000) (* 10 (length large-tokens))))
  (printf "  Large (~a tokens): ~a ns/token\n"
          (length large-tokens)
          (exact->inexact large-per-token-ns))

  ;; Indent resolution: full vs incremental
  (printf "\n--- Full vs incremental indent resolution ---\n")
  (collect-garbage) (collect-garbage)
  (define full-start (current-inexact-milliseconds))
  (for ([_ (in-range 100)])
    (keep! (resolve-parents indent-200)))
  (define full-elapsed (- (current-inexact-milliseconds) full-start))

  ;; Build stack at midpoint
  (define pre-stack
    (let ([stack '()])
      (for ([indent (in-list (take indent-200 100))]
            [i (in-naturals)])
        (set! stack (let loop ([s stack])
                      (if (and (pair? s) (>= (car (car s)) indent))
                          (loop (cdr s))
                          s)))
        (set! stack (cons (cons indent i) stack)))
      stack))
  (collect-garbage) (collect-garbage)
  (define incr-start (current-inexact-milliseconds))
  (for ([_ (in-range 100)])
    (keep! (resolve-parents-incremental indent-200 100 pre-stack)))
  (define incr-elapsed (- (current-inexact-milliseconds) incr-start))
  (printf "  Full (200 lines): ~a ns/call\n"
          (exact->inexact (/ (* full-elapsed 1000000) 100)))
  (printf "  Incremental (100 lines from mid): ~a ns/call\n"
          (exact->inexact (/ (* incr-elapsed 1000000) 100)))
  (printf "  Speedup: ~ax\n"
          (if (> incr-elapsed 0)
              (exact->inexact (/ full-elapsed incr-elapsed))
              "N/A"))

  ;; E2E reader costs comparison
  (printf "\n--- E2E reader costs (small/medium/large) ---\n")
  (define (measure-file label path iters)
    (if (file-exists? path)
        (let ()
          (define content (file->string path))
          (define lines (length (string-split content "\n")))
          (collect-garbage) (collect-garbage)
          (define s (current-inexact-milliseconds))
          (for ([_ (in-range iters)])
            (keep! (read-all-forms-string content)))
          (define e (- (current-inexact-milliseconds) s))
          (define ms-per-call (/ e iters))
          (printf "  ~a (~a lines): ~a ms/call\n"
                  label lines (exact->inexact ms-per-call))
          ms-per-call)
        (begin
          (printf "  ~a: NOT FOUND\n" label)
          #f)))
  (measure-file "core.prologos" "lib/prologos/core.prologos" 20)
  (measure-file "nat.prologos" "lib/prologos/data/nat.prologos" 20)
  (measure-file "list.prologos" "lib/prologos/data/list.prologos" 20))

(printf "\n=== DONE ===\n")
