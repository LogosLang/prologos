#lang racket/base

;;; split-whales.rkt — Split whale test files (>20 test-cases) into smaller parts
;;;
;;; Usage:
;;;   racket tools/split-whales.rkt                     ; split all known whales
;;;   racket tools/split-whales.rkt tests/test-foo.rkt  ; split a specific file
;;;
;;; Each part gets the original preamble + ~N/ceil(N/20) test-cases.
;;; Prefers splitting at section headers (;; ====) when they fall near
;;; the target split point (within ±3 tests).
;;;
;;; Does NOT delete originals — verify the splits first, then delete manually.

(require racket/file
         racket/list
         racket/path
         racket/port
         racket/string)

;; ---------------------------------------------------------------------------
;; Configuration
;; ---------------------------------------------------------------------------

(define MAX-TESTS-PER-PART 20)
(define SECTION-TOLERANCE 3)  ; how far from ideal split to prefer a section boundary

;; Known whale files (relative to tests/)
(define known-whales
  '("test-stdlib-02-traits.rkt"
    "test-stdlib-01-data.rkt"
    "test-stdlib-03-list.rkt"
    "test-trait-impl.rkt"
    "test-numeric-traits.rkt"
    "test-cross-family-conversions.rkt"
    "test-prelude-system.rkt"
    "test-collection-traits.rkt"
    "test-lseq.rkt"
    "test-surface-defmacro.rkt"
    "test-map-set-traits.rkt"
    "test-eq-ord-extended.rkt"
    "test-list-extended-01.rkt"
    "test-generic-ops.rkt"
    "test-list-extended-02.rkt"))

;; ---------------------------------------------------------------------------
;; Parsing: identify preamble, test-cases, and section headers
;; ---------------------------------------------------------------------------

;; A test-case starts at a line matching /^\(test-case /
(define (test-case-line? line)
  (and (>= (string-length line) 11)
       (string-prefix? line "(test-case ")))

;; A section header line matches /^;; ====/
(define (section-header-line? line)
  (and (>= (string-length line) 7)
       (string-prefix? line ";; ====")))

;; Parse a file into: preamble-lines and a list of test-blocks.
;; Each test-block is a list of lines starting with any lead-in
;; (section headers, comments, blank lines) followed by the (test-case
;; line and its body lines until the next test-case's lead-in.
;;
;; Returns (values preamble-lines  test-blocks)
(define (parse-test-file path)
  (define all-lines (file->lines path))

  ;; Find the index of the first (test-case line
  (define first-tc-idx
    (for/first ([line (in-list all-lines)]
                [i (in-naturals)]
                #:when (test-case-line? line))
      i))

  (unless first-tc-idx
    (error 'parse-test-file "no test-case found in ~a" path))

  ;; Walk backwards from first-tc-idx to find where the "lead-in"
  ;; for the first test starts (section headers, sub-headers, blank lines).
  ;; The preamble ends before that lead-in.
  ;; Stop walking back if we hit a define, require, #lang, or ;;; doc comment.
  (define lead-in-start
    (let loop ([i (sub1 first-tc-idx)])
      (cond
        [(< i 0) 0]
        [else
         (define line (list-ref all-lines i))
         (cond
           [(or (string-prefix? line "(define ")
                (string-prefix? line "(require ")
                (string-prefix? line "#lang ")
                (string-prefix? line "(provide ")
                (string-prefix? line ";;;"))
            (add1 i)]
           [(or (string=? line "")
                (section-header-line? line)
                (string-prefix? line ";; "))
            (loop (sub1 i))]
           [else (add1 i)])])))

  (define preamble (take all-lines lead-in-start))

  ;; Parse the rest into test-blocks
  (define rest-lines (drop all-lines lead-in-start))

  ;; Find test-case line indices within rest-lines
  (define tc-indices
    (for/list ([line (in-list rest-lines)]
               [i (in-naturals)]
               #:when (test-case-line? line))
      i))

  ;; For each test-case, find where its "lead-in" begins by walking
  ;; backwards from the test-case line through blank lines, section
  ;; headers, and comments.
  (define (find-lead-in-start tc-idx prev-end)
    (let loop ([i (sub1 tc-idx)])
      (cond
        [(< i prev-end) prev-end]
        [(let ([line (list-ref rest-lines i)])
           (or (string=? line "")
               (section-header-line? line)
               (string-prefix? line ";; ")))
         (loop (sub1 i))]
        [else (add1 i)])))

  ;; Build block start positions
  (define block-starts
    (let loop ([tcs tc-indices] [prev-end 0] [acc '()])
      (cond
        [(null? tcs) (reverse acc)]
        [else
         (define tc-idx (car tcs))
         (define li-start (find-lead-in-start tc-idx prev-end))
         (loop (cdr tcs) (add1 tc-idx) (cons li-start acc))])))

  ;; Each block goes from block-starts[i] to block-starts[i+1]-1 (or EOF)
  (define test-blocks
    (for/list ([start (in-list block-starts)]
               [end (in-list (append (cdr block-starts)
                                     (list (length rest-lines))))])
      (for/list ([i (in-range start end)])
        (list-ref rest-lines i))))

  (values preamble test-blocks))

;; ---------------------------------------------------------------------------
;; Splitting: distribute test-blocks into parts
;; ---------------------------------------------------------------------------

;; Check if any line in the lead-in (before the test-case line)
;; is a section header
(define (block-has-section-header? block)
  (for/or ([line (in-list block)]
           #:break (test-case-line? line))
    (section-header-line? line)))

;; Split test-blocks into num-parts groups, preferring section boundaries.
(define (split-into-parts test-blocks num-parts)
  (define total (length test-blocks))
  (define target-size (ceiling (/ total num-parts)))

  ;; Greedy algorithm: accumulate blocks, split when we reach target-size.
  ;; If a section header falls within ±SECTION-TOLERANCE of the target,
  ;; prefer splitting there.
  (let loop ([remaining test-blocks]
             [current-part '()]
             [current-count 0]
             [parts-so-far '()]
             [parts-left num-parts])
    (cond
      ;; No more blocks to distribute
      [(null? remaining)
       (if (null? current-part)
           (reverse parts-so-far)
           (reverse (cons (reverse current-part) parts-so-far)))]

      ;; Last part: take everything remaining
      [(= parts-left 1)
       (define final-part (append (reverse current-part) remaining))
       (reverse (cons final-part parts-so-far))]

      [else
       (define block (car remaining))
       (define rest (cdr remaining))
       (define new-count (add1 current-count))

       ;; Check split conditions
       (define at-target? (>= new-count target-size))
       (define near-target? (>= new-count (- target-size SECTION-TOLERANCE)))
       (define next-is-section?
         (and (not (null? rest))
              (block-has-section-header? (car rest))))

       (cond
         ;; At or past target: split here
         [at-target?
          (define new-part (reverse (cons block current-part)))
          (define new-parts-left (sub1 parts-left))
          (loop rest '() 0
                (cons new-part parts-so-far)
                new-parts-left)]

         ;; Near target and next block starts a new section: split here
         [(and near-target? next-is-section?)
          (define new-part (reverse (cons block current-part)))
          (define new-parts-left (sub1 parts-left))
          (loop rest '() 0
                (cons new-part parts-so-far)
                new-parts-left)]

         ;; Otherwise: add to current part
         [else
          (loop rest (cons block current-part) new-count
                parts-so-far parts-left)])])))

;; ---------------------------------------------------------------------------
;; Output: write split files
;; ---------------------------------------------------------------------------

(define (make-part-filename original-path part-num)
  (define dir (path-only original-path))
  (define name (path->string (file-name-from-path original-path)))
  ;; Strip .rkt extension
  (define base (substring name 0 (- (string-length name) 4)))
  (build-path dir (format "~a-~a.rkt" base (pad-num part-num))))

(define (pad-num n)
  (if (< n 10) (format "0~a" n) (format "~a" n)))

(define (write-part-file path preamble test-blocks part-num total-parts
                         original-name)
  (define out-path (make-part-filename path part-num))
  (define num-tests (length test-blocks))

  ;; Build the file content
  (define content
    (string-append
     ;; Preamble
     (string-join preamble "\n")
     "\n\n"
     ;; The test blocks
     (string-join
      (for/list ([block (in-list test-blocks)])
        (string-join block "\n"))
      "\n\n")
     "\n"))

  (call-with-output-file out-path
    (lambda (out)
      (display content out))
    #:exists 'replace)

  (printf "  wrote ~a (~a tests)\n"
          (path->string (file-name-from-path out-path))
          num-tests)
  out-path)

;; ---------------------------------------------------------------------------
;; Main: process a single whale file
;; ---------------------------------------------------------------------------

(define (process-whale-file filepath)
  (unless (file-exists? filepath)
    (error 'split-whales "file not found: ~a" filepath))

  (define-values (preamble test-blocks) (parse-test-file filepath))
  (define num-tests (length test-blocks))
  (define num-parts (inexact->exact (ceiling (/ num-tests MAX-TESTS-PER-PART))))

  (define name (path->string (file-name-from-path filepath)))
  (printf "\n~a: ~a tests -> ~a parts\n" name num-tests num-parts)

  (cond
    [(<= num-parts 1)
     (printf "  skipping (already under ~a tests)\n" MAX-TESTS-PER-PART)
     '()]
    [else
     (define parts (split-into-parts test-blocks num-parts))

     ;; Verify: total tests across parts == original
     (define total-in-parts (apply + (map length parts)))
     (unless (= total-in-parts num-tests)
       (error 'split-whales
              "BUG: test count mismatch! original=~a, split=~a"
              num-tests total-in-parts))

     (define written-files
       (for/list ([part (in-list parts)]
                  [i (in-naturals 1)])
         (write-part-file filepath preamble part i num-parts name)))

     ;; Print dep-graph update info
     (printf "  dep-graph update: replace '~a with:\n" name)
     (for ([f (in-list written-files)])
       (printf "    '~a\n" (path->string (file-name-from-path f))))

     written-files]))

;; ---------------------------------------------------------------------------
;; Entry point
;; ---------------------------------------------------------------------------

(define (main)
  (define args (vector->list (current-command-line-arguments)))

  (define here-dir
    (let ([src (syntax-source #'here)])
      (if src
          (path->string (simplify-path (path-only src)))
          (path->string (current-directory)))))

  (define tests-dir
    (path->string (simplify-path (build-path here-dir ".." "tests"))))

  (define files-to-process
    (cond
      [(null? args)
       ;; Process all known whales
       (for/list ([name (in-list known-whales)])
         (build-path tests-dir name))]
      [else
       ;; Process specified files
       (for/list ([arg (in-list args)])
         (if (absolute-path? arg)
             (string->path arg)
             (build-path tests-dir arg)))]))

  (printf "split-whales: splitting ~a file(s)\n" (length files-to-process))
  (printf "  max tests per part: ~a\n" MAX-TESTS-PER-PART)
  (printf "  section tolerance: +/-~a tests\n" SECTION-TOLERANCE)

  (define all-written '())

  (for ([f (in-list files-to-process)])
    (define written (process-whale-file f))
    (set! all-written (append all-written written)))

  (printf "\n========================================\n")
  (printf "Done. ~a files written.\n" (length all-written))
  (printf "Next steps:\n")
  (printf "  1. Verify: racket tools/run-affected-tests.rkt --all\n")
  (printf "  2. Update tools/dep-graph.rkt with new filenames\n")
  (printf "  3. Delete original whale files\n")
  (printf "  4. Re-run: racket tools/run-affected-tests.rkt --all\n"))

(main)
