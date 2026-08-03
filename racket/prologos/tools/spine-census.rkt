#lang racket/base

;;;
;;; spine-census.rkt — the dual-spine DIVERGENCE CENSUS.
;;;
;;; ═══════════════════════════════════════════════════════════════════════════
;;; WHAT THIS IS, AND WHAT IT DELIBERATELY IS NOT
;;;
;;; driver.rkt's `merge-preparse-and-tree-parser` merges two parser spines and
;;; its last arm is `[else tree-surf]` — "tree parser wins for user forms".
;;; MEASURED 2026-08-02: the tree spine wins 0 of 5,171 corpus forms and never
;;; has, because the merge key was broken three ways. Correcting the key makes
;;; the corpus REGRESS (errors 359 -> 724, 32 test files fail), so the spine is
;;; held shut at an admission gate (`tree-spine-admitted?`, driver.rkt).
;;;
;;; This tool answers the question that gate defers: **exactly WHERE do the two
;;; spines disagree, and why?**
;;;
;;; It is a CENSUS, not a GATE. It never fails a build and nothing depends on
;;; it. That is deliberate: a build-failing oracle would be red from birth and
;;; stay red until someone repairs a 1,971-line parser, so its value would be
;;; entirely contingent on a decision (commission the spine vs retire the merge)
;;; that has not been made. A census is useful under BOTH answers — it is the
;;; repair backlog under one and the evidence base under the other.
;;;
;;; ═══════════════════════════════════════════════════════════════════════════
;;; THE TWO MODES ARE TWO ARCHITECTURES, NOT TWO CONFIGURATIONS
;;;
;;; `parse-form-tree` (tree-parser.rkt) forks on whether `current-source-str` is
;;; set, and the fork is an ACCIDENT of which entry point you came through:
;;; `process-string-ws` parameterizes it, `process-file` does not.
;;;
;;;   LEGACY mode (source-str "")  — the `parse-*-tree` family: 33 functions,
;;;     1,971 lines. A SECOND PARSER. Every drift-class defect lives here: the
;;;     atom table is 11 of parser.rkt's 42, head dispatch ~58 of ~357, and the
;;;     stale arms (map literals, `<A -> B>` multiplicity, `check`'s type).
;;;
;;;   DATUM mode (source-str set) — `parse-eval-tree-for-cell`: tree node -> stx
;;;     -> datum -> normalize -> preparse-expand-single -> **parse-datum**, i.e.
;;;     the SAME parser the preparse spine uses. The tree is used as a READER,
;;;     not as a parser. The drift classes are impossible here BY CONSTRUCTION,
;;;     because there is only one atom table and one head dispatch.
;;;
;;;   RAW-DATUM mode — as DATUM, plus `current-raw-node` bound to the matching
;;;     node from the UNGROUPED tree. This is the DESIGNED hook (tree-parser.rkt
;;;     reads `(or (current-raw-node) node)` for exactly this conversion, and
;;;     form-cells.rkt sets it) which the merge path simply binds to #f.
;;;
;;; MEASURED over all 163 files — agreement where BOTH spines produced a surf:
;;;
;;;     LEGACY      428/1454 = 29%   (1026 divergences)
;;;     DATUM       954/1162 = 82%   ( 208 divergences)
;;;     RAW-DATUM  1542/1568 = 98%   (  26 divergences)
;;;
;;; The DATUM->RAW-DATUM jump has one cause. `tree-node->stx-elements` FLATTENS a
;;; node and RE-GROUPS it, and the `$…` sentinels are minted by that regrouping
;;; FROM THE BRACKET TOKENS. On the grouped tree those tokens are already
;;; consumed into group nodes, and `flatten-with-boundaries` emits only
;;; indent-open/indent-close around a child — dropping its TAG. So:
;;;     preparse  (def xs := ($list-literal 1 2 3))
;;;     tree      (def xs := (1 2 3))
;;; and `$list-literal`/`$brace-params`/`$vec-literal`/`$angle-type` all collapse
;;; to bare applications. Feeding the UNGROUPED node fixes every one of them.
;;;
;;; ⚠ THE RESIDUAL 26 ARE STRUCTURAL, NOT COSMETIC — I guessed wrong and checked.
;;; They look like generated-name noise (`$Add-A`, `$Eq-A`, `$Lattice-A`) but are
;;; not: `preparse: $Add-A` vs `tree: x` is an implicit DICTIONARY BINDER that
;;; whole-file `preparse-expand-all` inserts from cross-form `spec`/trait context
;;; and per-form `preparse-expand-single` cannot see. That is the one defect class
;;; no converter fix reaches; it needs the tree spine to have whole-file expansion
;;; context. So 98% is the realistic ceiling for the datum path as architected.
;;;
;;; Usage:
;;;   racket tools/spine-census.rkt FILE ...           — all three modes
;;;   racket tools/spine-census.rkt --mode raw-datum   — one mode only
;;;   racket tools/spine-census.rkt --verbose          — per-divergence detail
;;;

(require racket/list
         racket/string
         racket/file
         racket/path
         racket/port
         racket/cmdline
         "../parse-reader.rkt"
         "../rrb.rkt"
         "../surface-rewrite.rkt"
         "../tree-parser.rkt"
         "../parser.rkt"
         "../macros.rkt"
         "../surface-syntax.rkt"
         "../source-location.rkt"
         "../errors.rkt")

;; ════════════════════════════════════════════════════════════════════════════
;; The srcloc mask table — BY FIELD NAME, derived from source, self-checking.
;; ════════════════════════════════════════════════════════════════════════════
;;
;; ⚠ MASKING BY POSITION IS WRONG, and it is wrong in exactly one place. A
;; census of all 377 surf structs (read as DATA, so multi-line forms are
;; included) found `srcloc` last in 376 of them and at index 3 of 5 in
;; `surf-narrow` — `(lhs rhs vars srcloc constraint-map)`. A "drop the last
;; field" comparator would compare surf-narrow's SRCLOC as data and skip its
;; CONSTRAINT-MAP entirely: a silent wrong answer inside the very instrument
;; built to find silent wrong answers. (A first pass over single-line struct
;; forms with a regex reported 292/292 clean and would have shipped that bug.)
;;
;; So the table is derived by READING surface-syntax.rkt at startup rather than
;; embedded as a constant — it cannot go stale — and an unknown struct is a
;; LOUD error, never a silent unmasked comparison.

(define (read-forms-from-file p)
  (define src (file->string p))
  (define nl (for/first ([i (in-range (string-length src))]
                         #:when (char=? (string-ref src i) #\newline)) i))
  (with-input-from-string (substring src (add1 (or nl 0)))
    (lambda () (let loop ([a '()])
                 (define f (read))
                 (if (eof-object? f) (reverse a) (loop (cons f a)))))))

(define (find-forms pred f)
  (cond [(pred f) (list f)]
        [(pair? f) (append (find-forms pred (car f)) (find-forms pred (cdr f)))]
        [else '()]))

;; struct-name symbol -> index of the srcloc/loc field
(define (locate-surface-syntax)
  (let loop ([d (current-directory)] [n 0])
    (define cand (build-path d "surface-syntax.rkt"))
    (cond [(file-exists? cand) cand]
          [(> n 4) (error 'spine-census "cannot locate surface-syntax.rkt from ~a" (current-directory))]
          [else (loop (build-path d 'up) (add1 n))])))

(define (surf-struct-form? f)
  (and (pair? f) (eq? (car f) 'struct)
       (pair? (cdr f)) (symbol? (cadr f))
       (regexp-match? #rx"^surf-" (symbol->string (cadr f)))
       (pair? (cddr f)) (list? (caddr f))))

(define (build-srcloc-index)
  (define tbl (make-hasheq))
  (define forms (read-forms-from-file (locate-surface-syntax)))
  (for ([s (in-list (find-forms surf-struct-form? forms))])
    (define flds (caddr s))
    (define idx (for/first ([f (in-list flds)] [i (in-naturals)]
                            #:when (memq f '(srcloc loc)))
                  i))
    (hash-set! tbl (cadr s) idx))
  tbl)

(define srcloc-index (build-srcloc-index))

(define (mask-index-for name)
  (define hit (hash-ref srcloc-index name 'absent))
  (when (eq? hit 'absent)
    (error 'spine-census
           (string-append
            "no srcloc-mask entry for struct `~a`. The mask table is derived from\n"
            "surface-syntax.rkt; a struct it does not know would be compared with its\n"
            "srcloc AS DATA, reporting a divergence that is not one. Failing loudly\n"
            "rather than returning a plausible wrong census.")
           name))
  hit)

;; ════════════════════════════════════════════════════════════════════════════
;; The generic reflective comparator
;; ════════════════════════════════════════════════════════════════════════════
;;
;; All 377 surf structs are #:transparent and none are #:mutable, so a
;; struct->vector walk is both possible and sound. (loose-bvar.rkt records that
;; struct->vector allocates per node — 6.9x on a hot scan — which is irrelevant
;; here: this is an offline census, not a compiler path.)
;;
;; Returns #f when equivalent, or a divergence descriptor:
;;   (list path-string reason a-repr b-repr)

;; NOTE: `struct-info` returns #f for the type when the struct is not
;; transparent in the current inspector. All surf structs ARE transparent
;; (verified: 377 defs, 386 #:transparent, 0 #:mutable), so a #f here means the
;; value is some OTHER struct — not a surf — and is compared with equal?.
(define (struct-name-of v)
  (and (struct? v)
       (let-values ([(st _sk) (struct-info v)])
         (and st
              (let-values ([(name _i _a _acc _m _im _s _sk2) (struct-type-info st)])
                name)))))

(define (surf-struct? v)
  (define n (struct-name-of v))
  (and n (regexp-match? #rx"^surf-" (symbol->string n))))

(define (short v)
  (define s (format "~s" v))
  (if (> (string-length s) 90) (string-append (substring s 0 90) "…") s))

;; ⚠ RECURSION MUST ENTER *EVERY* TRANSPARENT STRUCT, NOT JUST surf-* ONES.
;;
;; A first cut recursed only into surf structs and compared everything else with
;; `equal?`. That is a confident WRONG answer, not a conservative one: surf nodes
;; are routinely reached through NON-surf carriers — `binder-info` holds a
;; surf-type, which holds a srcloc — so `equal?` on the carrier compared the
;; nested srclocs as data. On the first corpus run it manufactured ~500 false
;; divergences out of 1,039, all of them "differences" in file paths and line
;; numbers. The tell was that the reported values had `struct:srcloc` inside them.
;;
;; So: recurse into any transparent struct. Mask the srcloc slot of surf structs
;; via the name-derived table, and additionally treat any field where BOTH sides
;; hold a srcloc as equal (covers non-surf carriers with their own loc fields).
(define (diff a b [path "."])
  (define na (struct-name-of a))
  (define nb (struct-name-of b))
  (cond
    [(and na nb)
     (cond
       [(not (eq? na nb)) (list path "node-kind" (format "~a" na) (format "~a" nb))]
       [else
        ;; surf structs have a known srcloc slot; other transparent structs do not
        (define mask (if (surf-struct? a) (mask-index-for na) #f))
        (define va (struct->vector a))
        (define vb (struct->vector b))
        (cond
          [(not (= (vector-length va) (vector-length vb)))
           (list path "arity" (format "~a" (vector-length va)) (format "~a" (vector-length vb)))]
          [else
           ;; slot 0 of struct->vector is the type tag; fields start at 1
           (for/or ([i (in-range 1 (vector-length va))])
             (define x (vector-ref va i))
             (define y (vector-ref vb i))
             (and (not (and mask (= (sub1 i) mask)))     ;; the surf srcloc slot
                  (not (and (srcloc? x) (srcloc? y)))    ;; any other loc field
                  (diff x y (format "~a/~a[~a]" path na (sub1 i)))))])])]
    ;; one side a struct, the other not
    [(or na nb) (list path "struct-vs-value" (short a) (short b))]
    [(and (pair? a) (pair? b))
     (or (diff (car a) (car b) (string-append path "/car"))
         (diff (cdr a) (cdr b) (string-append path "/cdr")))]
    [(and (null? a) (null? b)) #f]
    [(and (srcloc? a) (srcloc? b)) #f]
    [(equal? a b) #f]
    [else (list path "value" (short a) (short b))]))

;; ════════════════════════════════════════════════════════════════════════════
;; The two spines
;; ════════════════════════════════════════════════════════════════════════════

;; Replicates driver.rkt's read-all-syntax-ws (not exported).
(define (ws-syntaxes src source-name)
  (register-default-token-patterns!)
  (define pt (read-to-tree src))
  (define refined-root (refine-tag (parse-tree-root pt)))
  (define refined-pt (struct-copy parse-tree pt [root refined-root]))
  (read-all-forms-from-tree refined-pt src source-name))

(define (preparse-surfs src source-name)
  (map parse-toplevel-datum (preparse-expand-all (ws-syntaxes src source-name))))

;; THREE tree-spine configurations:
;;   'legacy    — current-source-str "" : the parse-*-tree family (a 2nd PARSER)
;;   'datum     — current-source-str set: tree-node->stx-form on the GROUPED node
;;   'raw-datum — as 'datum, but with `current-raw-node` bound to the matching
;;                node from the UNGROUPED tree.
;;
;; ⚠ Why 'raw-datum exists. `tree-node->stx-elements` FLATTENS a node and then
;; RE-GROUPS it, and the `$…` sentinels (`$list-literal`, `$brace-params`,
;; `$vec-literal`, `$angle-type`) are minted by that regrouping FROM THE BRACKET
;; TOKENS. On the grouped tree those tokens have already been consumed into group
;; nodes, and `flatten-with-boundaries` emits only `indent-open`/`indent-close`
;; around a child node — it drops the node's TAG. So the sentinel head is lost:
;;   preparse  (def xs := ($list-literal 1 2 3))
;;   tree      (def xs := (1 2 3))
;; `current-raw-node` is the DESIGNED hook for this (tree-parser.rkt uses
;; `(or (current-raw-node) node)` for exactly this conversion, and form-cells.rkt
;; sets it from a raw-node map) — but the merge path binds it to #f.
(define (tree-surfs src mode)
  (register-default-token-patterns!)
  (define pt (read-to-tree src))
  (define grouped (rewrite-tree (refine-tag (group-tree-node (parse-tree-root pt)))))
  (cond
    [(not (eq? mode 'raw-datum))
     (parameterize ([current-source-str (if (eq? mode 'datum) src "")]
                    [current-raw-node #f])
       (parse-top-level-forms-from-tree grouped))]
    [else
     ;; line -> ungrouped (refine-tag-only) node, mirroring form-cells.rkt's raw-map
     (define raw-root (refine-tag (parse-tree-root (read-to-tree src))))
     (define raw-by-line
       (for/hash ([c (in-list (rrb-to-list (parse-tree-node-children raw-root)))]
                  #:when (parse-tree-node? c)
                  #:when (let ([l (parse-tree-node-srcloc c)])
                           (and (pair? l) (number? (car l)))))
         (values (car (parse-tree-node-srcloc c)) c)))
     (parameterize ([current-source-str src])
       (for/list ([c (in-list (rrb-to-list (parse-tree-node-children grouped)))])
         (define line (and (parse-tree-node? c)
                           (let ([l (parse-tree-node-srcloc c)])
                             (and (pair? l) (number? (car l)) (car l)))))
         (parameterize ([current-raw-node (and line (hash-ref raw-by-line line #f))])
           (parse-form-tree c))))]))

;; ⚠ PAIRING IS NOT DONE BY SOURCE LINE, and that is a finding, not a shortcut.
;;
;; The obvious pairing is the merge's own key. It cannot be used, because it does
;; not work in EITHER mode and fails differently in each:
;;   · LEGACY — tree srclocs are 0-based lists; preparse's are 1-based structs.
;;     Correctable (add1), and that is what the merge's own defect note is about.
;;   · DATUM  — `parse-eval-tree-for-cell` builds syntax with `datum->syntax #f`,
;;     which carries NO position, so `datum-srcloc` yields `(srcloc "<unknown>"
;;     0 0 0)`. Line 0 is the unknown sentinel: EVERY datum-mode tree surf is
;;     unkeyable. Measured — line-pairing matched 0 of 9 forms on the first file.
;;
;; Using a different key per mode would make the two modes incomparable, which
;; defeats the point. So pairing is by IDENTITY: (kind, name) for named forms,
;; and order-within-kind for the anonymous ones. Mode-independent, and it does
;; not smuggle the defect under investigation into the instrument measuring it.
(define (name-of s)
  (cond [(surf-def? s) (surf-def-name s)]
        [(surf-defn? s) (surf-defn-name s)]
        [(surf-defn-multi? s) (surf-defn-multi-name s)]
        [else #f]))

;; identity token: (kind . name) for named, (kind . ordinal) for anonymous
(define (identities surfs)
  (define seen (make-hash))
  (for/list ([s (in-list surfs)])
    (define k (kind-of s))
    (define n (name-of s))
    (define key (if n (cons k n) (cons k 'anon)))
    (define i (hash-ref seen key 0))
    (hash-set! seen key (add1 i))
    (list* k (or n 'anon) i)))

(define (kind-of s)
  (cond [(surf-def? s) 'def] [(surf-defn? s) 'defn] [(surf-defn-multi? s) 'defn-multi]
        [(surf-eval? s) 'eval] [(surf-check? s) 'check] [(surf-infer? s) 'infer]
        [else #f]))

;; ════════════════════════════════════════════════════════════════════════════
;; Per-file census
;; ════════════════════════════════════════════════════════════════════════════

(struct row (file mode kind verdict reason path a b) #:transparent)

(define (census-file path mode verbose?)
  (define src (file->string path))
  (define name (path->string path))
  (with-handlers ([(lambda (_) #t)
                   (lambda (e) (list (row name mode 'FILE 'crash
                                          (if (exn? e) (exn-message e) (format "~a" e))
                                          "" "" "")))])
    (define ps-all (preparse-surfs src name))
    (define ts-all (tree-surfs src mode))
    ;; eligible = the six kinds `same-form-type?` admits. NOTE: a bare top-level
    ;; expression is NOT one — preparse leaves it as surf-app / surf-num-lit /…,
    ;; never surf-eval — so the merge's reach is much narrower than "six kinds"
    ;; suggests. That ratio is itself reported below.
    (define ps (filter (lambda (s) (and (not (prologos-error? s)) (kind-of s))) ps-all))
    (define ts (filter (lambda (s) (and (not (prologos-error? s)) (kind-of s))) ts-all))
    (define t-index (make-hash))
    (for ([s (in-list ts)] [id (in-list (identities ts))])
      (hash-set! t-index id s))
    (cons
     (row name mode 'ELIGIBILITY 'stat
          (format "~a eligible of ~a top-level preparse surfs" (length ps) (length ps-all))
          "" "" "")
     (for/list ([p (in-list ps)] [id (in-list (identities ps))])
       (define t (hash-ref t-index id #f))
       (cond
         [(not t) (row name mode (kind-of p) 'no-tree-surf "" "" "" "")]
         [else
          (define d (diff p t))
          (if d
              (row name mode (kind-of p) 'DIVERGE (cadr d) (car d) (caddr d) (cadddr d))
              (row name mode (kind-of p) 'equivalent "" "" "" ""))])))))

;; ════════════════════════════════════════════════════════════════════════════

(define (report rows mode verbose?)
  (define all-rs (filter (lambda (r) (eq? (row-mode r) mode)) rows))
  (define rs (filter (lambda (r) (not (eq? (row-kind r) 'ELIGIBILITY))) all-rs))
  (define elig (filter (lambda (r) (eq? (row-kind r) 'ELIGIBILITY)) all-rs))
  (define (n v) (length (filter (lambda (r) (eq? (row-verdict r) v)) rs)))
  (define total (length rs))
  (define eq-n (n 'equivalent))
  (printf "\n══════ MODE: ~a ══════\n" (string-upcase (symbol->string mode)))
  (printf "  merge-eligible preparse forms : ~a\n" total)
  (printf "  EQUIVALENT (tree could win)   : ~a  (~a%)\n" eq-n
          (if (zero? total) 0 (round (/ (* 100.0 eq-n) total))))
  (printf "  DIVERGE                       : ~a\n" (n 'DIVERGE))
  (let ([both (+ eq-n (n 'DIVERGE))])
    (printf "  ► AGREEMENT where BOTH spines produced a surf: ~a/~a (~a%)\n"
            eq-n both (if (zero? both) 0 (round (/ (* 100.0 eq-n) both)))))
  (printf "  kind-mismatch                 : ~a\n" (n 'kind-mismatch))
  (printf "  no tree surf at that line     : ~a\n" (n 'no-tree-surf))
  (printf "  file crashes                  : ~a\n" (n 'crash))
  (for ([r (in-list rs)] #:when (eq? (row-verdict r) 'crash))
    (printf "      CRASH ~a :: ~a\n" (file-name-from-path (row-file r))
            (substring (row-reason r) 0 (min 80 (string-length (row-reason r))))))
  (let ([tot-el (for/sum ([r (in-list elig)])
                  (string->number (car (regexp-match #rx"^[0-9]+" (row-reason r)))))]
        [tot-all (for/sum ([r (in-list elig)])
                   (string->number (cadr (regexp-match #rx"of ([0-9]+)" (row-reason r)))))])
    (printf "  ELIGIBILITY: ~a of ~a top-level preparse surfs are merge-eligible (~a%)\n"
            tot-el tot-all (if (zero? tot-all) 0 (round (/ (* 100.0 tot-el) tot-all)))))
  (printf "\n  -- EQUIVALENT by form kind (this is the admission allowlist) --\n")
  (for ([k (in-list '(def defn defn-multi eval check infer))])
    (define of-kind (filter (lambda (r) (eq? (row-kind r) k)) rs))
    (define ok (filter (lambda (r) (eq? (row-verdict r) 'equivalent)) of-kind))
    (unless (null? of-kind)
      (printf "     ~a~a ~a/~a equivalent\n"
              k (make-string (max 1 (- 12 (string-length (symbol->string k)))) #\space)
              (length ok) (length of-kind))))
  (printf "\n  -- divergence REASONS (top 12) --\n")
  (define reasons (make-hash))
  (for ([r (in-list rs)] #:when (eq? (row-verdict r) 'DIVERGE))
    (hash-update! reasons (cons (row-reason r) (row-a r)) add1 0))
  (for ([kv (in-list (take (sort (hash->list reasons) > #:key cdr)
                           (min 12 (hash-count reasons))))])
    (printf "     ~a x  ~a  |  ~a\n" (cdr kv) (car (car kv)) (cdr (car kv))))
  (when verbose?
    (printf "\n  -- first 25 divergences --\n")
    (for ([r (in-list (take (filter (lambda (r) (eq? (row-verdict r) 'DIVERGE)) rs)
                            (min 25 (n 'DIVERGE))))])
      (printf "     ~a\n       ~a at ~a\n       preparse: ~a\n       tree:     ~a\n"
              (file-name-from-path (row-file r)) (row-reason r) (row-path r)
              (row-a r) (row-b r)))))

(module+ main
  (define mode-sel 'all)
  (define verbose? #f)
  (define files
    (command-line
     #:program "spine-census"
     #:once-each
     [("--mode") m "legacy | datum | raw-datum | all (default all)" (set! mode-sel (string->symbol m))]
     [("--verbose") "Show individual divergences" (set! verbose? #t)]
     #:args fs fs))
  (when (null? files)
    (error 'spine-census "pass .prologos files explicitly (the driver script supplies the corpus)"))
  (define targets (map string->path files))
  (define modes (if (memq mode-sel '(both all)) '(legacy datum raw-datum) (list mode-sel)))
  (define rows
    (append* (for*/list ([m (in-list modes)] [p (in-list targets)])
               (census-file p m verbose?))))
  (for ([m (in-list modes)]) (report rows m verbose?))
  (printf "\n(files: ~a · masked structs known: ~a)\n" (length targets) (hash-count srcloc-index)))
