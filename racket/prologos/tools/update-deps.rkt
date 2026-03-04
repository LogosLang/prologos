#lang racket/base

;; update-deps.rkt — Regenerate/verify dep-graph.rkt dependency data
;;
;; Usage:
;;   racket tools/update-deps.rkt           # print discovered deps to stdout
;;   racket tools/update-deps.rkt --check   # verify current data matches actual requires
;;   racket tools/update-deps.rkt --write   # regenerate dep-graph.rkt data sections

(require racket/cmdline
         racket/file
         racket/list
         racket/match
         racket/path
         racket/port
         racket/set
         racket/string
         "dep-graph.rkt")

;; ============================================================
;; Project paths
;; ============================================================

;; Anchor from the script's own location: tools/ is inside prologos/
(define tools-dir
  (let ([src (resolved-module-path-name
              (variable-reference->resolved-module-path
               (#%variable-reference)))])
    (simplify-path (path-only src))))

(define project-root (simplify-path (build-path tools-dir "..")))
(define source-dir project-root)
(define tests-dir  (build-path project-root "tests"))
(define lib-dir    (build-path project-root "lib" "prologos"))

;; ============================================================
;; Source module dependency scanning
;; (scan-rkt-requires, scan-test-source-deps, scan-test-prologos-deps,
;;  scan-prologos-requires, test-uses-driver? are imported from dep-graph.rkt)
;; ============================================================

;; Scan all source .rkt files in the project root (not in subdirs)
(define (discover-source-deps)
  (define files
    (for/list ([f (in-list (directory-list source-dir))]
               #:when (and (string-suffix? (path->string f) ".rkt")
                           (file-exists? (build-path source-dir f))
                           ;; Exclude info.rkt and other non-source files
                           (not (member (path->string f)
                                        '("info.rkt")))))
      (path->string f)))
  (for/hasheq ([fname (in-list (sort files string<?))])
    (define full (build-path source-dir fname))
    (define raw-deps (scan-rkt-requires full))
    ;; Filter to only known source modules
    (define known-sources (list->seteq (map string->symbol files)))
    (define filtered
      (filter (λ (d) (set-member? known-sources d)) raw-deps))
    (values (string->symbol fname) filtered)))

;; ============================================================
;; Test file dependency discovery
;; (uses scan-test-source-deps, test-uses-driver?, scan-test-prologos-deps
;;  from dep-graph.rkt)
;; ============================================================

;; Discover all test dependencies
(define (discover-test-deps)
  (define files
    (for/list ([f (in-list (directory-list tests-dir))]
               #:when (and (string-prefix? (path->string f) "test-")
                           (string-suffix? (path->string f) ".rkt")
                           (file-exists? (build-path tests-dir f))))
      (path->string f)))
  (for/hasheq ([fname (in-list (sort files string<?))])
    (define full (build-path tests-dir fname))
    (define src-deps (scan-test-source-deps full))
    (define driver? (test-uses-driver? full))
    (values (string->symbol fname)
            (test-dep src-deps driver?))))

;; Discover test .prologos deps
(define (discover-test-prologos-deps)
  (define files
    (for/list ([f (in-list (directory-list tests-dir))]
               #:when (and (string-prefix? (path->string f) "test-")
                           (string-suffix? (path->string f) ".rkt")
                           (file-exists? (build-path tests-dir f))))
      (path->string f)))
  (for/hasheq ([fname (in-list (sort files string<?))]
               #:when (let ([full (build-path tests-dir fname)])
                        (and (test-uses-driver? full)
                             (not (null? (scan-test-prologos-deps full))))))
    (define full (build-path tests-dir fname))
    (values (string->symbol fname)
            (scan-test-prologos-deps full))))

;; ============================================================
;; .prologos library dependency scanning
;; ============================================================

;; Walk lib/prologos/ recursively to find all .prologos files
(define (discover-prologos-lib-deps)
  (define all-files (find-prologos-files lib-dir))
  (for/hasheq ([entry (in-list all-files)])
    (match-define (cons mod-name filepath) entry)
    (define raw-deps (scan-prologos-requires filepath))
    (values mod-name raw-deps)))

;; Find all .prologos files and compute their module names
(define (find-prologos-files dir)
  (define results '())
  (let walk ([d dir] [prefix "prologos"])
    (when (directory-exists? d)
      (for ([f (in-list (directory-list d))])
        (define full (build-path d f))
        (define name (path->string f))
        (cond
          [(directory-exists? full)
           (walk full (string-append prefix "::" name))]
          [(string-suffix? name ".prologos")
           (define mod-name
             (string->symbol
              (string-append prefix "::"
                             (substring name 0
                                        (- (string-length name)
                                           (string-length ".prologos"))))))
           (set! results (cons (cons mod-name full) results))]))))
  (sort results (λ (a b) (symbol<? (car a) (car b)))))

;; ============================================================
;; Comparison / --check mode
;; ============================================================

(define (compare-hash-deps label current-data discovered-data)
  (define mismatches 0)

  ;; Check for keys in discovered but missing from current
  (for ([k (in-hash-keys discovered-data)])
    (unless (hash-has-key? current-data k)
      (printf "  MISSING from ~a: ~a\n    discovered deps: ~a\n"
              label k (hash-ref discovered-data k))
      (set! mismatches (add1 mismatches))))

  ;; Check for keys in current but missing from discovered
  (for ([k (in-hash-keys current-data)])
    (unless (hash-has-key? discovered-data k)
      (printf "  EXTRA in ~a: ~a (in dep-graph but not found on disk)\n"
              label k)
      (set! mismatches (add1 mismatches))))

  ;; Check for dep value mismatches
  (for ([(k v) (in-hash discovered-data)]
        #:when (hash-has-key? current-data k))
    (define current-v (hash-ref current-data k))
    (define disc-deps
      (if (test-dep? v)
          (sort (test-dep-source-modules v) symbol<?)
          (sort v symbol<?)))
    (define curr-deps
      (if (test-dep? current-v)
          (sort (test-dep-source-modules current-v) symbol<?)
          (sort current-v symbol<?)))
    (unless (equal? disc-deps curr-deps)
      (printf "  MISMATCH in ~a key ~a:\n    current:    ~a\n    discovered: ~a\n"
              label k curr-deps disc-deps)
      (set! mismatches (add1 mismatches)))
    ;; For test-dep, also check uses-driver?
    (when (and (test-dep? v) (test-dep? current-v))
      (unless (equal? (test-dep-uses-driver? v) (test-dep-uses-driver? current-v))
        (printf "  MISMATCH in ~a key ~a uses-driver?:\n    current: ~a  discovered: ~a\n"
                label k (test-dep-uses-driver? current-v) (test-dep-uses-driver? v))
        (set! mismatches (add1 mismatches)))))

  mismatches)

(define (run-check)
  (printf "Scanning project for actual dependencies...\n\n")

  (printf "=== Layer 1: Source module deps ===\n")
  (define disc-source (discover-source-deps))
  (define source-mm (compare-hash-deps "source-deps" source-deps disc-source))
  (if (zero? source-mm)
      (printf "  ✓ ~a source modules match\n" (hash-count disc-source))
      (printf "  ✗ ~a mismatches\n" source-mm))

  (printf "\n=== Layer 2: Test → source module deps ===\n")
  (define disc-test (discover-test-deps))
  (define test-mm (compare-hash-deps "test-deps" test-deps disc-test))
  (if (zero? test-mm)
      (printf "  ✓ ~a test files match\n" (hash-count disc-test))
      (printf "  ✗ ~a mismatches\n" test-mm))

  (printf "\n=== Layer 3: .prologos library deps ===\n")
  (define disc-prologos (discover-prologos-lib-deps))
  (define prologos-mm (compare-hash-deps "prologos-lib-deps" prologos-lib-deps disc-prologos))
  (if (zero? prologos-mm)
      (printf "  ✓ ~a .prologos modules match\n" (hash-count disc-prologos))
      (printf "  ✗ ~a mismatches\n" prologos-mm))

  (printf "\n=== Layer 3b: Test → .prologos runtime deps ===\n")
  (define disc-test-pl (discover-test-prologos-deps))
  (define tpl-mm (compare-hash-deps "test-prologos-deps" test-prologos-deps disc-test-pl))
  (if (zero? tpl-mm)
      (printf "  ✓ ~a test→prologos mappings match\n" (hash-count disc-test-pl))
      (printf "  ✗ ~a mismatches\n" tpl-mm))

  (define total (+ source-mm test-mm prologos-mm tpl-mm))
  (printf "\n~a\n"
          (if (zero? total)
              "All dependency data is up to date. ✓"
              (format "~a total mismatches found. Run with --write to update." total)))
  (unless (zero? total)
    (exit 1)))

;; ============================================================
;; Write mode — regenerate dep-graph.rkt data sections
;; ============================================================

;; Find a balanced-paren form starting at marker string.
;; Returns (cons start-pos end-pos) or #f.
(define (find-balanced-form text marker)
  (define start (regexp-match-positions (regexp-quote marker) text))
  (cond
    [(not start) #f]
    [else
     (define pos (caar start))
     (define len (string-length text))
     (let loop ([i pos] [depth 0] [started? #f])
       (cond
         [(>= i len) #f]
         [(char=? (string-ref text i) #\()
          (loop (add1 i) (add1 depth) #t)]
         [(char=? (string-ref text i) #\))
          (define new-depth (sub1 depth))
          (if (and started? (zero? new-depth))
              (cons pos (add1 i))
              (loop (add1 i) new-depth #t))]
         [else (loop (add1 i) depth started?)]))]))

;; Format a simple symbol → symbol-list hash as (define name (hasheq ...))
(define (format-simple-hash name data)
  (define entries (sort (hash->list data) (λ (a b) (symbol<? (car a) (car b)))))
  (define lines
    (for/list ([entry (in-list entries)])
      (define k (car entry))
      (define v (cdr entry))
      (define vals (sort v symbol<?))
      (if (null? vals)
          (format "   '~a~a'()" k (pad-to k 30))
          (format "   '~a~a'(~a)" k (pad-to k 30)
                  (string-join (map (λ (s) (format "~a" s)) vals) " ")))))
  (string-append
   (format "(define ~a\n  (hasheq\n" name)
   (string-join lines "\n")
   "))"))

;; Format test-deps hash as (define test-deps (hasheq ...))
(define (format-test-deps-hash data)
  (define entries (sort (hash->list data) (λ (a b) (symbol<? (car a) (car b)))))
  (define lines
    (for/list ([entry (in-list entries)])
      (define k (car entry))
      (define td (cdr entry))
      (define mods (sort (test-dep-source-modules td) symbol<?))
      (define driver? (test-dep-uses-driver? td))
      (if (null? mods)
          (format "   '~a\n   (test-dep '() ~a)" k driver?)
          (format "   '~a\n   (test-dep '(~a) ~a)"
                  k
                  (string-join (map (λ (s) (format "~a" s)) mods) " ")
                  driver?))))
  (string-append
   "(define test-deps\n  (hasheq\n"
   (string-join lines "\n")
   "))"))

;; Padding helper for alignment
(define (pad-to sym width)
  (define s (symbol->string sym))
  (define need (max 1 (- width (string-length s))))
  (make-string need #\space))

;; Replace a balanced-paren form in text with new-text
(define (replace-form text marker new-text)
  (define range (find-balanced-form text marker))
  (cond
    [(not range)
     (eprintf "WARNING: Could not find '~a' in dep-graph.rkt\n" marker)
     text]
    [else
     (string-append
      (substring text 0 (car range))
      new-text
      (substring text (cdr range)))]))

(define (run-write)
  (printf "Scanning project for actual dependencies...\n")

  (define disc-source (discover-source-deps))
  (printf "  Found ~a source modules\n" (hash-count disc-source))

  (define disc-test (discover-test-deps))
  (printf "  Found ~a test files\n" (hash-count disc-test))

  (define disc-prologos (discover-prologos-lib-deps))
  (printf "  Found ~a .prologos modules\n" (hash-count disc-prologos))

  (define disc-test-pl (discover-test-prologos-deps))
  (printf "  Found ~a test→prologos mappings\n" (hash-count disc-test-pl))

  (define dep-graph-path (build-path tools-dir "dep-graph.rkt"))
  (define text (file->string dep-graph-path))

  ;; Replace each data section
  (define text1 (replace-form text "(define source-deps"
                              (format-simple-hash "source-deps" disc-source)))
  (define text2 (replace-form text1 "(define test-deps"
                              (format-test-deps-hash disc-test)))
  (define text3 (replace-form text2 "(define prologos-lib-deps"
                              (format-simple-hash "prologos-lib-deps" disc-prologos)))
  (define text4 (replace-form text3 "(define test-prologos-deps"
                              (format-simple-hash "test-prologos-deps" disc-test-pl)))

  ;; Write back
  (call-with-output-file dep-graph-path
    (λ (out) (display text4 out))
    #:exists 'replace)

  (printf "\nWrote updated dep-graph.rkt\n")
  (printf "Run 'racket tools/update-deps.rkt --check' to verify.\n"))

;; ============================================================
;; Print mode (default)
;; ============================================================

(define (run-print)
  (printf "Scanning project for actual dependencies...\n\n")

  (printf "=== Source module deps (~a modules) ===\n"
          (hash-count (discover-source-deps)))
  (for ([(k v) (in-hash (discover-source-deps))])
    (printf "  ~a → ~a\n" k v))

  (printf "\n=== Test deps (~a files) ===\n"
          (hash-count (discover-test-deps)))
  (for ([(k v) (in-hash (discover-test-deps))])
    (printf "  ~a → src:~a driver?:~a\n"
            k (test-dep-source-modules v) (test-dep-uses-driver? v)))

  (printf "\n=== .prologos lib deps (~a modules) ===\n"
          (hash-count (discover-prologos-lib-deps)))
  (for ([(k v) (in-hash (discover-prologos-lib-deps))])
    (printf "  ~a → ~a\n" k v))

  (printf "\n=== Test→prologos deps ===\n")
  (for ([(k v) (in-hash (discover-test-prologos-deps))])
    (printf "  ~a → ~a\n" k v)))

;; ============================================================
;; Main
;; ============================================================

(define check-mode? (make-parameter #f))
(define write-mode? (make-parameter #f))

(define (main)
  (command-line
   #:program "update-deps"
   #:once-each
   ["--check" "Verify current dep-graph.rkt data matches actual requires"
    (check-mode? #t)]
   ["--write" "Regenerate dep-graph.rkt data sections from actual requires"
    (write-mode? #t)])

  (cond
    [(check-mode?) (run-check)]
    [(write-mode?) (run-write)]
    [else (run-print)]))

(main)
