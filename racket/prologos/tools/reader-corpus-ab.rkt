#lang racket/base
;;; reader-corpus-ab.rkt — the READER CORPUS A/B harness.
;;;
;;; CIU T6 D4.P2. Every reader-touching phase of this track owed a corpus A/B
;;; against a pinned baseline, and every phase RE-DERIVED the harness from
;;; scratch. That is how P1b-ii's first run came back with 5 diffs that were
;;; exactly the 5 owner-modified `.prologos` files: the two legs had read
;;; DIFFERENT CONTENT, so it measured the working tree instead of the change.
;;; This file exists so that cannot happen again.
;;;
;;; ═══════════════════════════════════════════════════════════════════════════
;;; THE ONE RULE: PIN BOTH LEGS' INPUTS, NOT JUST THE CODE.
;;;
;;; The harness deliberately does NOT know how to find a corpus. You hand it a
;;; content snapshot, and you hand the SAME snapshot to both legs. The only
;;; thing that differs between legs is which checkout's reader is running.
;;;
;;;   # 1. one immutable content snapshot, shared by both legs
;;;   git archive HEAD racket/prologos | tar -x -C /tmp/snap
;;;
;;;   # 2. a baseline checkout of the code (NEVER `git stash` — owner WIP lives
;;;   #    in the main tree)
;;;   git worktree add --detach /tmp/base <baseline-sha>
;;;
;;;   # 3. both legs, SAME --corpus, different cwd
;;;   (cd /tmp/base/racket/prologos && racket tools/reader-corpus-ab.rkt \
;;;        --corpus /tmp/snap --out /tmp/a.txt)
;;;   (cd <main>/racket/prologos   && racket tools/reader-corpus-ab.rkt \
;;;        --corpus /tmp/snap --out /tmp/b.txt)
;;;
;;;   # 4. the comparison
;;;   diff /tmp/a.txt /tmp/b.txt
;;;
;;; ═══════════════════════════════════════════════════════════════════════════
;;; TWO FOOTGUNS THIS FILE ENCODES SO THEY CANNOT BE RE-LEARNED:
;;;
;;; (1) THE FALSE ZERO. `tokenize-char-rrb` reads a MUTABLE registry that is
;;;     populated only inside the reader's own entry points. A harness that
;;;     calls the tokenizer directly without `register-default-token-patterns!`
;;;     matches NOTHING — every character becomes a single-char token — and a
;;;     census built on it reports a confident, wrong ZERO. One facet of the P2
;;;     audit did exactly this. `assert-reader-live!` below makes that
;;;     impossible: it fails loudly rather than returning a plausible number.
;;;
;;; (2) THE DANGLING LOCK SYMLINK. Emacs leaves `.#name` symlinks that point at
;;;     nothing, so an unguarded directory walk dies in `open-input-file`. One
;;;     exists for the path-selection acceptance file as of 2026-07-29. We skip
;;;     leading-`.`/`~` basenames, matching the convention the two committed
;;;     corpus walkers in tests/test-parse-reader.rkt already use.

(require racket/cmdline
         racket/file
         racket/list
         racket/path
         racket/string
         "../parse-reader.rkt")

;; ---------------------------------------------------------------------------
;; Footgun (1): prove the reader is actually armed before trusting any output.
;; A multi-token lexeme that MUST split, plus a compound token that MUST fuse.
;; If the registry were empty both would degenerate to single-char tokens.
;; ---------------------------------------------------------------------------
(define (assert-reader-live!)
  (register-default-token-patterns!)
  (define (forms s) (compat-read-all-forms-string s))
  (define probe-multi (forms "def x := 1"))
  (define probe-compound (forms "a.b"))
  (unless (and (= 1 (length probe-multi))
               (= 4 (length (car probe-multi))))
    (error 'reader-corpus-ab
           (string-append
            "TRIPWIRE: the tokenizer is not armed — `def x := 1` did not split "
            "into 4 tokens (got ~s). Every count from this run would be a FALSE "
            "ZERO. Call register-default-token-patterns! before tokenizing.")
           probe-multi))
  (unless (equal? probe-compound '((a ($dot-access b))))
    (error 'reader-corpus-ab
           (string-append
            "TRIPWIRE: compound tokens are not fusing — `a.b` read as ~s "
            "instead of ((a ($dot-access b))). The registry is stale or partial.")
           probe-compound)))

;; ---------------------------------------------------------------------------
;; Footgun (2): skip dotfiles and editor turds, including dangling symlinks.
;; ---------------------------------------------------------------------------
(define (usable-basename? name)
  (not (or (regexp-match? #rx"^\\." name)
           (regexp-match? #rx"^~" name))))

(define (collect-prologos-files root)
  (sort
   (for/list ([p (in-directory root)]
              #:when (and (path-has-extension? p #".prologos")
                          (usable-basename? (path->string (file-name-from-path p)))
                          ;; a dangling symlink answers #f here rather than
                          ;; exploding later in open-input-file
                          (file-exists? p)))
     p)
   string<? #:key path->string))

;; Canonical, diffable, one line per file. `~s` so the datum is compared
;; STRUCTURALLY — a printed form would hide symbol-vs-string differences.
(define (render-file root p)
  (define rel (find-relative-path (simplify-path root) (simplify-path p)))
  (define src (file->string p))
  (define result
    (with-handlers ([(lambda (_) #t)
                     (lambda (e)
                       (format "<<READ-ERROR ~a>>"
                               (if (exn? e) (exn-message e) e)))])
      (format "~s" (compat-read-all-forms-string src))))
  (format "~a\t~a" (path->string rel) result))

(module+ main
  (define corpus #f)
  (define out #f)
  (command-line
   #:program "reader-corpus-ab"
   #:once-each
   [("--corpus") dir
                 ("The CONTENT SNAPSHOT to read. Hand the SAME one to both legs"
                  "— that is the whole point of this harness.")
                 (set! corpus dir)]
   [("--out") file "Where to write the canonical per-file reader output."
              (set! out file)])
  (unless corpus
    (error 'reader-corpus-ab
           "--corpus is REQUIRED. Pointing the two legs at different content is\nthe defect this harness exists to prevent; there is no default."))
  (assert-reader-live!)
  (define files (collect-prologos-files corpus))
  (define lines (for/list ([p (in-list files)]) (render-file corpus p)))
  (define text (string-join lines "\n"))
  (if out
      (begin (display-to-file text out #:exists 'replace)
             (printf "reader-corpus-ab: ~a files -> ~a\n" (length files) out))
      (displayln text))
  (printf "reader-corpus-ab: corpus=~a files=~a read-errors=~a\n"
          corpus (length files)
          (for/sum ([l (in-list lines)])
            (if (regexp-match? #rx"<<READ-ERROR" l) 1 0))))
