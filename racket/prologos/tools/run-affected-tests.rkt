#lang racket/base

;; run-affected-tests.rkt — CLI entry point for targeted test running
;;
;; Usage:
;;   racket tools/run-affected-tests.rkt              # diff against HEAD, run affected
;;   racket tools/run-affected-tests.rkt --dry-run    # just print affected list
;;   racket tools/run-affected-tests.rkt --against main  # diff against main branch
;;   racket tools/run-affected-tests.rkt --all        # run everything
;;   racket tools/run-affected-tests.rkt --jobs 4     # override parallelism (default 10)
;;   racket tools/run-affected-tests.rkt --no-skip   # ignore .skip-tests, run everything
;;   racket tools/run-affected-tests.rkt --skip-only # run ONLY the normally-skipped tests

(require racket/cmdline
         racket/list
         racket/path
         racket/port
         racket/set
         racket/string
         racket/system
         "dep-graph.rkt")

;; ============================================================
;; Skip list support
;; ============================================================

;; Read skip list from tests/.skip-tests.
;; Returns list of (symbol . reason-or-#f) pairs.
;; Missing file → empty list (no error).
(define (read-skip-list tests-dir)
  (define skip-file (build-path tests-dir ".skip-tests"))
  (if (file-exists? skip-file)
      (let ([lines (call-with-input-file skip-file
                     (lambda (in)
                       (for/list ([line (in-lines in)]) line)))])
        (filter-map
         (lambda (line)
           (define trimmed (string-trim line))
           (cond
             [(string=? trimmed "") #f]
             [(string-prefix? trimmed "#") #f]
             [else
              (define parts (string-split trimmed "#" #:trim? #f))
              (define filename (string-trim (car parts)))
              (define reason (and (> (length parts) 1)
                                  (string-trim (string-join (cdr parts) "#"))))
              (cons (string->symbol filename) reason)]))
         lines))
      '()))

;; Apply skip filter to a test list.
;; Returns two values: (tests-to-run . tests-skipped)
(define (apply-skip-filter test-list tests-dir)
  (cond
    [(no-skip?) (values test-list '())]
    [else
     (define skip-entries (append (read-skip-list tests-dir)
                                  (map (λ (s) (cons s #f)) (extra-skips))))
     (define skip-names (map car skip-entries))
     (define filtered (filter (λ (t) (not (member t skip-names))) test-list))
     (define actually-skipped (filter (λ (t) (member t skip-names)) test-list))
     ;; Report skipped tests to stderr
     (unless (null? actually-skipped)
       (eprintf "Skipping ~a known pathological test(s):\n" (length actually-skipped))
       (for ([t (in-list actually-skipped)])
         (define entry (assq t skip-entries))
         (define reason (and entry (cdr entry)))
         (eprintf "  ~a~a\n" t (if reason (format "  (~a)" reason) "")))
       (eprintf "\n"))
     (if (skip-only?)
         (values actually-skipped filtered)  ; invert: run skipped, skip non-skipped
         (values filtered actually-skipped))]))

;; ============================================================
;; Path classification
;; ============================================================

;; The project root is racket/prologos/ — git paths are relative to repo root
(define prologos-prefix "racket/prologos/")

;; Classify a git-relative path into a changed-* struct, or #f if irrelevant
(define (classify-path path)
  (cond
    ;; Must be under racket/prologos/
    [(not (string-prefix? path prologos-prefix)) #f]
    [else
     (define rel (substring path (string-length prologos-prefix)))
     (cond
       ;; tools/ — meta-tooling, ignore
       [(string-prefix? rel "tools/") #f]
       ;; tests/examples/*.rkt — example files
       [(string-prefix? rel "tests/examples/")
        (define fname (last (string-split rel "/")))
        (changed-example (string->symbol fname))]
       ;; tests/*.rkt — test files
       [(string-prefix? rel "tests/")
        (define fname (last (string-split rel "/")))
        (changed-test (string->symbol fname))]
       ;; lib/prologos/**/*.prologos — library modules
       [(and (string-prefix? rel "lib/prologos/")
             (string-suffix? rel ".prologos"))
        ;; Convert path to module name:
        ;; lib/prologos/data/nat.prologos → prologos.data.nat
        (define without-prefix (substring rel (string-length "lib/")))
        (define without-ext (substring without-prefix 0
                              (- (string-length without-prefix)
                                 (string-length ".prologos"))))
        (define mod-name (string-replace without-ext "/" "."))
        (changed-prologos (string->symbol mod-name))]
       ;; lib/examples/**/*.prologos — example .prologos files
       ;; These are tested via test-lang.rkt (they load through the driver)
       [(and (string-prefix? rel "lib/examples/")
             (string-suffix? rel ".prologos"))
        (changed-test (string->symbol "test-lang.rkt"))]
       ;; info.rkt — package metadata, run all tests
       [(equal? rel "info.rkt") 'run-all]
       ;; *.rkt source files (not in tests/ or tools/)
       [(and (string-suffix? rel ".rkt")
             (not (string-contains? rel "/")))
        (changed-source (string->symbol rel))]
       ;; docs/ and other non-code — ignore
       [else #f])]))

;; ============================================================
;; Git diff integration
;; ============================================================

(define (run-git-command . args)
  (define cmd (string-join (cons "git" args) " "))
  (define output (with-output-to-string
                   (λ () (system cmd))))
  (if (string=? output "")
      '()
      (string-split (string-trim output) "\n")))

(define (get-changed-files against)
  (define diff-files
    (if against
        (run-git-command "diff" "--name-only" against)
        ;; Default: both staged and unstaged changes against HEAD
        (remove-duplicates
         (append (run-git-command "diff" "--name-only" "HEAD")
                 (run-git-command "diff" "--name-only" "--staged")))))
  (define untracked
    (run-git-command "ls-files" "--others" "--exclude-standard"))
  (remove-duplicates (append diff-files untracked)))

;; ============================================================
;; Main
;; ============================================================

(define dry-run? (make-parameter #f))
(define against-target (make-parameter #f))
(define run-all? (make-parameter #f))
(define num-jobs (make-parameter 10))
(define no-skip? (make-parameter #f))
(define skip-only? (make-parameter #f))
(define extra-skips (make-parameter '()))

(define (main)
  (command-line
   #:program "run-affected-tests"
   #:once-each
   ["--dry-run" "Only print affected tests, don't run them"
    (dry-run? #t)]
   ["--against" target "Diff against this ref (default: HEAD)"
    (against-target target)]
   ["--all" "Run all tests regardless of changes"
    (run-all? #t)]
   ["--jobs" n "Number of parallel jobs (default: 10)"
    (num-jobs (string->number n))]
   ["--no-skip" "Ignore .skip-tests, run all affected tests"
    (no-skip? #t)]
   ["--skip-only" "Run ONLY the normally-skipped tests"
    (skip-only? #t)]
   #:multi
   ["--skip" file "Skip an additional test file (additive with .skip-tests)"
    (extra-skips (cons (string->symbol file) (extra-skips)))])

  ;; Anchor from script's own location: tools/ → prologos/
  (define tools-dir
    (let ([src (resolved-module-path-name
                (variable-reference->resolved-module-path
                 (#%variable-reference)))])
      (simplify-path (path-only src))))
  (define project-root
    (path->string (simplify-path (build-path tools-dir ".."))))

  (define tests-dir
    (build-path project-root "tests"))

  (cond
    ;; --all: run everything (subject to skip filter)
    [(run-all?)
     (define all-tests (all-test-files))
     (define-values (to-run skipped) (apply-skip-filter all-tests tests-dir))
     (cond
       [(null? to-run)
        (printf "No tests to run (all ~a tests are skipped).\n" (length all-tests))]
       [else
        (printf "Running ~a of ~a test files~a...\n"
                (length to-run) (length all-tests)
                (if (null? skipped) "" (format " (~a skipped)" (length skipped))))
        (when (dry-run?)
          (for ([t (in-list to-run)])
            (printf "  ~a\n" t)))
        (unless (dry-run?)
          (define test-paths
            (for/list ([t (in-list to-run)])
              (path->string (build-path tests-dir (symbol->string t)))))
          (run-tests test-paths))])]

    ;; Normal mode: compute affected tests from git diff
    [else
     (define raw-paths (get-changed-files (against-target)))
     (when (null? raw-paths)
       (printf "No changed files detected. Nothing to test.\n")
       (exit 0))

     ;; Classify paths
     (define classified
       (filter-map classify-path raw-paths))

     ;; Check for run-all trigger (e.g., info.rkt changed)
     (define force-all?
       (member 'run-all classified))

     (cond
       [force-all?
        (printf "info.rkt changed — running ALL tests.\n")
        (define all-tests (all-test-files))
        (define-values (to-run skipped) (apply-skip-filter all-tests tests-dir))
        (printf "Running ~a of ~a test files~a...\n"
                (length to-run) (length all-tests)
                (if (null? skipped) "" (format " (~a skipped)" (length skipped))))
        (unless (dry-run?)
          (define test-paths
            (for/list ([t (in-list to-run)])
              (path->string (build-path tests-dir (symbol->string t)))))
          (run-tests test-paths))]

       [else
        ;; Filter out 'run-all from classified list (shouldn't be there but safety)
        (define changes (filter (λ (x) (not (eq? x 'run-all))) classified))

        (when (null? changes)
          (printf "Changed files are outside the prologos source tree. Nothing to test.\n")
          (exit 0))

        ;; Print summary of detected changes
        (printf "Detected changes:\n")
        (for ([c (in-list changes)])
          (cond
            [(changed-source? c)
             (printf "  source: ~a\n" (changed-source-name c))]
            [(changed-test? c)
             (printf "  test:   ~a\n" (changed-test-name c))]
            [(changed-prologos? c)
             (printf "  lib:    ~a\n" (changed-prologos-name c))]
            [(changed-example? c)
             (printf "  example: ~a\n" (changed-example-name c))]))

        ;; Compute affected tests (pass project-root for auto-scan of new files)
        (define affected (compute-affected-tests changes #:project-root project-root))

        ;; Apply skip filter
        (define-values (to-run skipped) (apply-skip-filter affected tests-dir))

        (cond
          [(null? to-run)
           (if (null? affected)
               (printf "\nNo tests affected by these changes.\n")
               (printf "\nNo tests to run (~a affected, all skipped).\n"
                       (length affected)))]
          [else
           (printf "\nAffected tests (~a of ~a~a):\n"
                   (length to-run)
                   (length (all-test-files))
                   (if (null? skipped) ""
                       (format ", ~a skipped" (length skipped))))
           (for ([t (in-list to-run)])
             (printf "  ~a\n" t))
           (unless (dry-run?)
             (define test-paths
               (for/list ([t (in-list to-run)])
                 (path->string (build-path tests-dir (symbol->string t)))))
             (run-tests test-paths))])])]))

(define (run-tests test-paths)
  (printf "\n--- Running ~a test files with -j ~a ---\n"
          (length test-paths) (num-jobs))
  (define cmd
    (string-join
     (append (list "raco" "test"
                   "-j" (number->string (num-jobs)))
             test-paths)
     " "))
  (define ok? (system cmd))
  (unless ok?
    (exit 1)))

(main)
