#lang racket/base

;; lowering-inventory.rkt — Bucket every .prologos file by lowering reachability.
;;
;; For each .prologos in the repo, we attempt:
;;   1. process-file (parse + elaborate + type check)
;;   2. ast-to-low-pnet (translate `main` to Low-PNet IR)
;;   3. low-pnet-to-prop-network round-trip (validation against Racket interp)
;;
;; Results bucketed:
;;   PASS              — round-trips
;;   ELAB_FAIL         — process-file raised (syntax / type error / missing dep)
;;   NO_MAIN           — process-file ok but no `main` value (library file)
;;   AST_TR_FAIL       — ast-to-low-pnet raised (these are the lowering gaps)
;;   ROUND_TRIP_FAIL   — adapter rejected the IR
;;   RUNTIME_FAIL      — interpreter ran but produced wrong / no result
;;
;; Within AST_TR_FAIL, we further bucket by the failure HINT — every
;; `translate-error!` site gives a specific reason; we pattern-match to assign
;; one of:
;;   GATE1_TAGGED_UNION  — multi-arm match, complex sum types
;;   GATE2_RECURSION     — non-tail / mutual / undefined fvar (PReduce territory)
;;   GATE3_STRING        — strings/bytes/chars (None of the existing examples
;;                         hit this through ast-to-low-pnet because the elaborator
;;                         rejects earlier; categorized by source-file regex.)
;;   GATE4_NAF           — relations / NAF (similar; these typically fail at
;;                         elab because of missing relation-runtime hooks)
;;   OTHER_LOWERING      — closures, records, partial app, effects, etc.
;;
;; Output: a markdown table to stdout.
;;
;; Usage:
;;   racket tools/lowering-inventory.rkt
;;   racket tools/lowering-inventory.rkt --out /tmp/inventory.md
;;   racket tools/lowering-inventory.rkt --details   ; lists all failures grouped

(require racket/cmdline
         racket/file
         racket/path
         racket/string
         racket/format
         racket/list
         racket/engine
         racket/runtime-path
         "../racket/prologos/driver.rkt"
         "../racket/prologos/global-env.rkt"
         "../racket/prologos/ast-to-low-pnet.rkt"
         "../racket/prologos/low-pnet-ir.rkt"
         "../racket/prologos/low-pnet-to-prop-network.rkt")

(define-runtime-path repo-root "..")
(define out-path (make-parameter #f))
(define details? (make-parameter #f))
(define limit-n  (make-parameter #f))
(define filter-rx (make-parameter #f))
(define per-file-timeout-ms (make-parameter 20000))

(command-line
 #:program "lowering-inventory"
 #:once-each
 [("--out") f "Mirror table output to this file" (out-path f)]
 [("--details") "Print per-file failure detail listings" (details? #t)]
 [("--limit") n "Limit to first N files (for fast iteration)"
  (limit-n (string->number n))]
 [("--filter") rx "Only process files whose path matches this regex"
  (filter-rx (regexp rx))]
 [("--timeout") ms "Per-file probe timeout in milliseconds (default 20000)"
  (per-file-timeout-ms (string->number ms))])

;; ============================================================
;; File discovery
;; ============================================================

(define examples-roots
  (list (build-path repo-root "racket" "prologos" "examples")
        (build-path repo-root "racket" "prologos" "lib" "examples")))

(define all-files
  (let ()
    (define raw
      (apply append
             (for/list ([root (in-list examples-roots)])
               (cond
                 [(directory-exists? root)
                  (for/list ([p (in-directory root)]
                             #:when (and (file-exists? p)
                                         (regexp-match? #px"\\.prologos$" (path->string p))))
                    p)]
                 [else '()]))))
    (define filtered
      (cond [(filter-rx) (filter (lambda (p) (regexp-match? (filter-rx) (path->string p))) raw)]
            [else raw]))
    (define sorted (sort filtered path<?))
    (cond [(limit-n) (take sorted (min (limit-n) (length sorted)))]
          [else sorted])))

;; ============================================================
;; Bucket assignment
;; ============================================================

(define (categorize-ast-tr-hint hint)
  ;; hint is the `hint` field of ast-translation-error.
  (define s (cond [(string? hint) hint] [else (format "~v" hint)]))
  (cond
    [(or (regexp-match? #rx"expr-reduce with" s)
         (regexp-match? #rx"sum types" s)
         (regexp-match? #rx"tagged-union" s)
         (regexp-match? #rx"List|Maybe|Either" s))
     'GATE1_TAGGED_UNION]
    [(or (regexp-match? #rx"non-tail-recursive" s)
         (regexp-match? #rx"mutually recursive" s)
         (regexp-match? #rx"non-tail position" s)
         (regexp-match? #rx"non-recursive helpers" s))
     'GATE2_RECURSION]
    [(regexp-match? #rx"bare reference" s)
     'GATE2_RECURSION]
    [(or (regexp-match? #rx"closure|first-class function" s)
         (regexp-match? #rx"erased" s))
     'OTHER_LOWERING]
    [else 'OTHER_LOWERING]))

(define (categorize-source-content path)
  ;; For elaboration-failed files, peek at source to bucket by FEATURE
  ;; (string heavy → GATE3, relation heavy → GATE4, etc.).
  (define content
    (with-handlers ([exn:fail? (lambda _ "")])
      (file->string path)))
  (cond
    [(regexp-match? #rx"\"|str::|str-ops::|char-at|str-len" content) 'GATE3_STRING]
    [(regexp-match? #rx"naf|relate|relation|<-" content) 'GATE4_NAF]
    [else #f]))

;; ============================================================
;; Per-file probe
;; ============================================================

(struct probe-r (path bucket detail) #:transparent)

(define (truncate-msg s)
  (define n (min 200 (string-length s)))
  (regexp-replace* #rx"[\n\r]" (substring s 0 n) " "))

(define (do-probe path)
  ;; INNER probe: runs in an engine so we can time it out.
  (with-handlers
    ([exn:fail?
      (lambda (e)
        (define msg (exn-message e))
        (define src-bucket (categorize-source-content path))
        (probe-r path
                 (or src-bucket 'ELAB_FAIL)
                 (truncate-msg msg)))])
    (parameterize ([current-output-port (open-output-string)]
                   [current-error-port  (open-output-string)])
      (process-file path))
    (define mt (with-handlers ([exn:fail? (lambda _ #f)])
                 (global-env-lookup-type 'main)))
    (define mb (with-handlers ([exn:fail? (lambda _ #f)])
                 (global-env-lookup-value 'main)))
    (cond
      [(or (not mt) (not mb))
       (probe-r path 'NO_MAIN "no `main` value defined")]
      [else
       (with-handlers
         ([(lambda (e) (and (exn:fail? e)
                            (regexp-match? #rx"ast-to-low-pnet|ast-translation"
                                           (exn-message e))))
           (lambda (e)
             (define msg (exn-message e))
             (define hint (and (ast-translation-error? e) (ast-translation-error-hint e)))
             (define bucket
               (cond [hint (categorize-ast-tr-hint hint)]
                     [(regexp-match? #rx"non-tail|bare reference|mutually" msg) 'GATE2_RECURSION]
                     [(regexp-match? #rx"reduce with" msg) 'GATE1_TAGGED_UNION]
                     [else 'OTHER_LOWERING]))
             (probe-r path bucket (truncate-msg msg)))])
         (define lp (ast-to-low-pnet mt mb (path->string path)))
         (with-handlers
           ([exn:fail?
             (lambda (e)
               (probe-r path 'ROUND_TRIP_FAIL (truncate-msg (exn-message e))))])
           (define raw (run-low-pnet lp 1000000))
           (probe-r path 'PASS (format "result=~v" raw))))])))

(define (probe path)
  ;; OUTER probe with timeout via Racket engines.
  (define eng (engine (lambda (_) (do-probe path))))
  (cond
    [(engine-run (per-file-timeout-ms) eng)
     (engine-result eng)]
    [else
     (engine-kill eng)
     (probe-r path 'TIMEOUT
              (format "exceeded ~ams" (per-file-timeout-ms)))]))

;; ============================================================
;; Driver
;; ============================================================

(printf "lowering-inventory: probing ~a .prologos files...~n" (length all-files))

(define results
  (for/list ([(p i) (in-indexed (in-list all-files))])
    (define t0 (current-inexact-milliseconds))
    (define rel
      (let ([s (path->string p)])
        (regexp-replace #px"^.*/prologos/" s "")))
    (printf "  [~a/~a] ~a... " (+ i 1) (length all-files) rel)
    (flush-output)
    (define r (probe p))
    (define elapsed (- (current-inexact-milliseconds) t0))
    (printf "~a (~ams)~n" (probe-r-bucket r) (round elapsed))
    (flush-output)
    r))

;; ============================================================
;; Reporting
;; ============================================================

(define bucket-order
  '(PASS NO_MAIN ELAB_FAIL ROUND_TRIP_FAIL RUNTIME_FAIL TIMEOUT
    GATE1_TAGGED_UNION GATE2_RECURSION GATE3_STRING GATE4_NAF OTHER_LOWERING))

(define (count-bucket b)
  (length (filter (lambda (r) (eq? (probe-r-bucket r) b)) results)))

(define (emit out)
  (define (P fmt . args) (apply fprintf out fmt args))
  (P "~n# Lowering Inventory — coverage of ast-to-low-pnet across all .prologos files~n~n")
  (P "Total files probed: ~a~n~n" (length results))

  (P "## Bucket summary~n~n")
  (P "| Bucket | Count | What it means | Gate |~n")
  (P "|---|---|---|---|~n")
  (define labels
    `((PASS                 "Round-trips through ast-to-low-pnet → run-low-pnet"   "—")
      (NO_MAIN              "Library file or no `main` value (not lowerable target)" "—")
      (ELAB_FAIL            "process-file raised — parse/elab/type-check error"      "—")
      (ROUND_TRIP_FAIL      "Adapter rejected the IR (validate-low-pnet etc.)"       "—")
      (RUNTIME_FAIL         "Interpreter ran but result diverged from expected"      "—")
      (TIMEOUT              "Probe exceeded per-file timeout (likely infinite loop in elab/lowering)" "—")
      (GATE1_TAGGED_UNION   "Multi-arm match, sum types beyond Bool/Nat (List, Maybe, Either, ADTs)" "Gate 1")
      (GATE2_RECURSION      "Non-tail / mutual recursion, bare fvar, undefined symbols" "Gate 2 (PReduce)")
      (GATE3_STRING         "Strings, bytes, chars (heuristic: source matches str:: / char-at / etc.)" "Gate 3")
      (GATE4_NAF            "NAF / relations (heuristic: source matches naf / <- / relation)" "Gate 4")
      (OTHER_LOWERING       "Closures, records, partial app, effects, other unsupported AST" "Future")))
  (for ([row (in-list labels)])
    (define b (car row))
    (define n (count-bucket b))
    (when (> n 0)
      (P "| ~a | ~a | ~a | ~a |~n" b n (cadr row) (caddr row))))

  (when (details?)
    (P "~n## Per-bucket file listings~n")
    (for ([b (in-list bucket-order)])
      (define files (filter (lambda (r) (eq? (probe-r-bucket r) b)) results))
      (when (pair? files)
        (P "~n### ~a (~a files)~n~n" b (length files))
        (for ([r (in-list files)])
          (define rel
            (let ([s (path->string (probe-r-path r))])
              (regexp-replace #px"^.*/prologos/" s "")))
          (P "- `~a`~n" rel)
          (when (and (probe-r-detail r) (not (eq? b 'PASS)))
            (P "  - ~a~n"
               (regexp-replace* #rx"\n" (probe-r-detail r) " "))))))))

(emit (current-output-port))
(when (out-path)
  (call-with-output-file (out-path) #:exists 'truncate
    (lambda (out) (emit out)))
  (printf "~nReport mirrored to ~a~n" (out-path)))
