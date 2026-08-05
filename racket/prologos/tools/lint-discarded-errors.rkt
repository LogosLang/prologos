#lang racket/base

;; lint-discarded-errors.rkt — find diagnostics that are COMPUTED and THROWN AWAY.
;;
;; `parse-error` and `parse-error-result` RETURN a value; neither raises. That is
;; deliberate and load-bearing: a raise on the parse/expansion path escapes
;; `process-file` and costs the WHOLE FILE, so Prologos's per-command error
;; reporting depends on errors being values that FLOW.
;;
;; The cost of that design is a writable mistake:
;;
;;     (unless (symbol? name)
;;       (parse-error loc "expected a name" name))     ; ← value discarded
;;     (symbol->string name)                           ; ← runs anyway, crashes
;;
;; The guard evaluates its diagnosis, drops it on the floor, and falls through
;; into exactly the code it was written to reject. What the user gets is a raw
;; Racket contract violation and an empty file — with the correct diagnosis
;; computed and unused.
;;
;; A probe-driven sweep (`ccf7adb0`, 2026-08-02) found SIX live instances in
;; parser.rkt, every one of them a whole-file abort. The DEFERRED entry closing
;; that sweep left one thing open, and this file is the answer to it:
;;
;;   "Still open (structural, not a defect): `parse-error` returning rather than
;;    raising is what makes this shape writable at all. Making it raise, or
;;    giving the parser an error monad, would make the class unrepresentable — a
;;    bigger call than a sweep should make. Until then the shape can be
;;    reintroduced by the next guard someone writes."
;;
;; Making it raise would be the WRONG fix — it would trade this class for the
;; whole-file-abort class, which is worse and which the marker-seat work spent
;; this whole arc removing. An error monad is a real option but a large one.
;;
;; So: not unrepresentable, but not undetectable either. This lint is the
;; middle answer. It cannot stop someone writing the shape; it stops the shape
;; SURVIVING, which is the property that actually matters.
;;
;; This is also why it exists as a gate rather than a report. Two other guards
;; in this tree (the parameter lint, the cell lint) rusted precisely because
;; nothing ran them — see tools/git-hooks/pre-commit for that history.
;;
;; ---------------------------------------------------------------------------
;; WHAT IT FLAGS
;;
;; A `when` / `unless` form whose body ENDS in an error-constructing call, and
;; which is NOT the last element of the list containing it — i.e. its value goes
;; nowhere. Plus a bare error-constructing call in the same position.
;;
;; "Not the last element of its parent list" over-approximates "not in tail
;; position": it also catches an error constructor used as a function ARGUMENT.
;; That is intentional. `(cons (when C (parse-error …)) rest)` is legal Racket
;; and is very unlikely to be what anyone meant.
;;
;; WHAT IT DOES NOT FLAG
;;
;; - a `when`/`unless` in tail position (the value flows to the caller — correct)
;; - `(define x (when C (parse-error …)))` (bound, so it flows)
;; - a `cond`/`match` arm ending in one (tail position of the arm)
;;
;; It reads with `read-syntax` and keeps source locations, so a hit reports
;; file:line:col. It does not expand, so it sees the source shape a reviewer
;; sees — which is the shape the mistake is made in.

(require racket/list
         racket/string
         racket/path
         racket/port
         racket/file)

(provide lint-file lint-files main)

;; Calls that CONSTRUCT a diagnostic value rather than raising one.
(define ERROR-CTORS '(parse-error parse-error-result))

;; Forms whose value is discarded when they are not last. `when`/`unless` are
;; the shape the sweep actually found; `begin` is included because it wraps.
(define GUARD-FORMS '(when unless))

(struct hit (file line col form snippet) #:transparent)

(define (syntax->datum* stx) (syntax->datum stx))

;; Does this datum END in a call to an error constructor?
;; `(when C a b (parse-error …))` → yes.  `(when C (parse-error …) other)` → no,
;; because then the error is discarded INSIDE the guard, which is a different
;; (and rarer) bug this lint deliberately does not claim to find.
(define (ends-in-error-ctor? d)
  (and (pair? d)
       (let ([lst (and (list? d) d)])
         (and lst
              (pair? (cdr lst))
              (let ([lastf (last lst)])
                (and (pair? lastf)
                     (memq (car lastf) ERROR-CTORS)
                     #t))))))

(define (error-ctor-call? d)
  (and (pair? d) (list? d) (memq (car d) ERROR-CTORS) #t))

(define (guard-form? d)
  (and (pair? d) (list? d) (memq (car d) GUARD-FORMS) (ends-in-error-ctor? d)))

;; A hit is a guard-form or bare error call sitting in a non-final position of
;; an actual BODY SEQUENCE.
(define (offending? d)
  (or (guard-form? d) (error-ctor-call? d)))

;; Where a form's BODY starts, or #f if it has no body sequence.
;;
;; This table is the whole correctness story. The first version of this lint
;; used "not the last element of the enclosing list" as a stand-in for "value
;; discarded", and it was WRONG in the most common way possible: an `if`
;; then-branch is element 2 of 4, so every
;;
;;     (if (not name) (parse-error-result loc "…") (continue …))
;;
;; — a correct guard, the error in TAIL position of the branch — was reported as
;; a discarded diagnostic. 16 hits, all false. A lint that cries wolf on the
;; correct idiom is worse than no lint: it trains people to pass --no-verify.
;;
;; So: only forms that genuinely SEQUENCE, and only their body positions.
(define (body-start d)
  (and (pair? d) (list? d) (symbol? (car d))
       (case (car d)
         [(when unless) 2]
         [(begin begin0) 1]
         [(let* letrec letrec* lambda λ parameterize with-handlers
           let-values let*-values case-lambda) 2]
         [(let) (if (and (> (length d) 1) (symbol? (cadr d))) 3 2)]  ; named let
         [(define define-values) 2]
         [(for for/list for/fold for/hash for/hasheq for/and for/or
           for/first for/last for/sum for/vector for*) 2]
         [else #f])))

;; `cond` / `match` / `case` clauses are body sequences too, but they live one
;; level down (inside each clause), so they are handled by walking the clause
;; itself as a body starting at index 1.
(define (clause-bearing? d)
  (and (pair? d) (list? d) (symbol? (car d))
       (memq (car d) '(cond match case match-let))
       #t))

(define (stx-line stx) (or (syntax-line stx) 0))
(define (stx-col stx) (or (syntax-column stx) 0))

(define (one-line d)
  (define s (with-output-to-string (lambda () (write d))))
  (define collapsed (regexp-replace* #rx"[ \t\n]+" s " "))
  (if (> (string-length collapsed) 96)
      (string-append (substring collapsed 0 93) "...")
      collapsed))

;; Report every element of `elems` except the last that constructs-and-discards.
(define (check-body-seq elems file collect!)
  (when (and (list? elems) (> (length elems) 1))
    (for ([sub (in-list (drop-right elems 1))])
      (define sd (syntax->datum* sub))
      (when (offending? sd)
        (collect! (hit file (stx-line sub) (stx-col sub)
                       (if (error-ctor-call? sd) 'bare (car sd))
                       (one-line sd)))))))

(define (walk stx file collect!)
  ;; `syntax-e` on an IMPROPER list — `(lambda (fmt . args) …)`, of which this
  ;; tree has several — returns a raw pair whose parts are syntax. Recurring on
  ;; that pair used to hand a non-syntax value straight back in, and the
  ;; contract violation aborted the file. Seven files were being SKIPPED that
  ;; way, tree-parser.rkt among them, while the run still printed a total and
  ;; looked complete. A linter that silently drops its hardest inputs is the
  ;; failure mode this whole class is about, so: tolerate non-syntax here.
  (unless (syntax? stx)
    (when (pair? stx)
      (walk (car stx) file collect!)
      (walk (cdr stx) file collect!)))
  (when (syntax? stx)
  (define d (syntax-e stx))
  (cond
    [(list? d)
     (define datum (syntax->datum* stx))
     (define start (body-start datum))
     (when (and start (> (length d) start))
       (check-body-seq (drop d start) file collect!))
     ;; cond / match / case: each clause after the head is itself a body
     ;; sequence, with the test or pattern at index 0.
     (when (clause-bearing? datum)
       (for ([cl (in-list (if (> (length d) 2) (drop d 2) '()))])
         (define cd (syntax-e cl))
         (when (and (list? cd) (> (length cd) 1))
           (check-body-seq (drop cd 1) file collect!))))
     (for ([sub (in-list d)]) (walk sub file collect!))]
    [(pair? d)
     (walk (car d) file collect!)
     (walk (cdr d) file collect!)]
    [(vector? d) (for ([sub (in-vector d)]) (walk sub file collect!))]
    [else (void)])))

(define (lint-file path)
  (define hits '())
  (define (collect! h) (set! hits (cons h hits)))
  (with-handlers ([exn:fail? (lambda (e)
                               (eprintf "lint-discarded-errors: cannot read ~a: ~a\n"
                                        path (exn-message e))
                               '())])
    (call-with-input-file path
      (lambda (in)
        (port-count-lines! in)
        ;; Our sources start with `#lang racket/base`, so the reader has to be
        ;; told to accept it — otherwise every file fails at 1:0 and the lint
        ;; reports "clean" over a tree it never read. (It did exactly that on
        ;; the first run.)
        (parameterize ([read-accept-reader #t]
                       [read-accept-lang #t])
          (let loop ()
            (define stx (read-syntax path in))
            (unless (eof-object? stx)
              (walk stx path collect!)
              (loop)))))))
  (reverse hits))

(define (lint-files paths)
  (append-map lint-file paths))

(define (default-targets)
  (define dir (simplify-path (build-path (path-only (syntax-source #'here)) "..")))
  (for/list ([p (in-list (directory-list dir))]
             #:when (regexp-match? #rx"[.]rkt$" (path->string p)))
    (path->string (build-path dir p))))

;; ---------------------------------------------------------------------------
;; Baseline
;;
;; 18 sites exist today. SIX of them were live whole-file aborts and are already
;; fixed; the rest either recover downstream or are unreachable from the surface,
;; and the `ccf7adb0` sweep deliberately did NOT convert those — some fall
;; through to code that produces a BETTER message, so converting them would
;; regress the diagnostic.
;;
;; So failing on all 18 would block every commit for a set that was examined and
;; consciously left. That is how a guard gets bypassed, and then rusts. The
;; baseline is the same device `lint-parameters.rkt` uses for the same reason:
;; accept today's set, fail on tomorrow's ADDITION.
;;
;; Keyed by file:line:col. Line numbers drift, so a moved site reads as new —
;; the cost of that is one `--save-baseline` after a refactor, which is the
;; right side to err on: a stale baseline that silently forgives is the failure
;; this is guarding against.
(define baseline-path
  (build-path (path-only (syntax-source #'here)) "discarded-errors-baseline.txt"))

(define (hit-key h)
  (format "~a:~a:~a" (file-name-from-path (hit-file h)) (hit-line h) (hit-col h)))

(define (read-baseline)
  (if (file-exists? baseline-path)
      (for/hash ([l (in-list (string-split (file->string baseline-path) "\n"))]
                 #:when (and (> (string-length (string-trim l)) 0)
                             (not (regexp-match? #rx"^#" (string-trim l)))))
        (values (string-trim l) #t))
      (hash)))

(define (write-baseline hits)
  (call-with-output-file baseline-path #:exists 'replace
    (lambda (out)
      (displayln "# discarded-errors-baseline.txt" out)
      (displayln "# Accepted `(when C (parse-error …))` sites as of the last save." out)
      (displayln "# These COMPUTE a diagnostic and discard it. They are accepted" out)
      (displayln "# because each was probed: they recover downstream, or are" out)
      (displayln "# unreachable from the surface, or fall through to a BETTER" out)
      (displayln "# message. They are not endorsements — they are a floor." out)
      (displayln "#" out)
      (displayln "# Regenerate: racket tools/lint-discarded-errors.rkt --save-baseline" out)
      (for ([h (in-list hits)]) (displayln (hit-key h) out)))))

(define (main . argv)
  (define strict? (and (member "--strict" argv) #t))
  (define save? (and (member "--save-baseline" argv) #t))
  (define explicit (filter (lambda (a) (not (regexp-match? #rx"^--" a))) argv))
  (define targets (if (null? explicit) (default-targets) explicit))
  (define hits (lint-files targets))
  (cond
    [save?
     (write-baseline hits)
     (printf "lint-discarded-errors: baseline saved — ~a site~a\n  ~a\n"
             (length hits) (if (= 1 (length hits)) "" "s")
             (path->string baseline-path))
     0]
    [else
     (define baseline (read-baseline))
     (define fresh (filter (lambda (h) (not (hash-ref baseline (hit-key h) #f))) hits))
     (cond
       [(null? fresh)
        (printf "lint-discarded-errors: no NEW discarded diagnostics (~a baselined, ~a files)\n"
                (length hits) (length targets))
        0]
       [else
        (printf "lint-discarded-errors: ~a NEW discarded diagnostic~a\n\n"
                (length fresh) (if (= 1 (length fresh)) "" "s"))
        (for ([h (in-list fresh)])
          (printf "~a:~a:~a\n  ~a\n" (hit-file h) (hit-line h) (hit-col h) (hit-snippet h)))
        (printf "\nEach COMPUTES a diagnostic and discards it: `parse-error` RETURNS a\n")
        (printf "value, it does not raise, so control falls through into the code the\n")
        (printf "guard was written to reject — and the user gets a raw Racket contract\n")
        (printf "violation with an EMPTY file, while the correct message sits unused.\n\n")
        (printf "Return the error instead of guarding with it:\n\n")
        (printf "    (if (symbol? name)\n")
        (printf "        (continue …)\n")
        (printf "        (parse-error loc \"expected a name\" name))\n\n")
        (printf "If a site is genuinely fine (recovers downstream, or falls through to a\n")
        (printf "better message), re-baseline it as a DECISION:\n")
        (printf "    racket tools/lint-discarded-errors.rkt --save-baseline\n")
        (if strict? 1 0)])]))

(module+ main
  (define code (apply main (vector->list (current-command-line-arguments))))
  (exit code))
