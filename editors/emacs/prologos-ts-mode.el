;;; prologos-ts-mode.el --- Tree-sitter major mode for Prologos -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Prologos Contributors
;; Version: 0.2.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages tree-sitter
;; URL: https://github.com/prologos-lang/prologos

;;; Commentary:

;; Tree-sitter based major mode for editing Prologos source files (.prologos).
;; Uses the tree-sitter grammar for accurate font-lock, navigation, and imenu.
;;
;; Requirements:
;; - Emacs 29.1+ with treesit support
;; - The prologos tree-sitter grammar installed in ~/.emacs.d/tree-sitter/.
;;   Build + install it with editors/tree-sitter-prologos/install.sh
;;   (rerun after grammar.js changes; a stale grammar makes Emacs 31 disable
;;   font-lock features with a treesit-font-lock-rules-mismatch warning).
;;
;; Features:
;; - Tree-sitter based font-lock (4 levels)
;; - Imenu support for defn, def, data, and deftype declarations
;; - Defun navigation (C-M-a / C-M-e) via treesit
;; - #lang detection for WS vs sexp mode
;; - WS mode indentation (TAB cycling, reused from prologos-indent.el)
;; - Automatic fallback to prologos-mode when grammar unavailable

;;; Code:

(require 'treesit)
(require 'cl-lib)
(require 'prologos-mode)
(require 'prologos-font-lock)
(require 'prologos-indent)

;; REPL integration (autoloaded — only loaded when first invoked)
(autoload 'prologos-repl "prologos-repl" "Start or switch to the Prologos REPL." t)
(autoload 'prologos-send-form "prologos-repl" "Send the top-level form at point." t)
;; Autoloaded too, so the retired name still resolves from a cold Emacs --
;; the obsolete alias itself lives in prologos-repl.el.
(autoload 'prologos-eval-last-sexp "prologos-repl" "Obsolete alias for `prologos-send-form'." t)
(autoload 'prologos-eval-region "prologos-repl" "Evaluate the region." t)
(autoload 'prologos-eval-buffer "prologos-repl" "Evaluate the entire buffer." t)
(autoload 'prologos-load-file "prologos-repl" "Load current file into REPL." t)
(autoload 'prologos-clear-results "prologos-repl" "Clear inline result overlays." t)

;; ============================================================
;; Font-lock — generated from the SHARED query file
;; ============================================================
;;
;; The highlight rules live in
;; `editors/tree-sitter-prologos/queries/highlights.scm' and are shared with the
;; VS Code semantic-token provider.  Emacs used to carry its own inline copy,
;; which is why query work landed in VS Code and reached Emacs not at all: this
;; file had ZERO references to highlights.scm and no captures for map keys,
;; keyword literals, PVec literals or path steps.  Reading the shared file ENDS
;; that duplication rather than deepening it.
;;
;; Three properties of the arrangement are load-bearing:
;;
;;   ORDER IS SEMANTIC.  highlights.scm is first-match-wins by FILE ORDER, and
;;   so is this.  `treesit-font-lock-settings' is applied in LIST order --
;;   verified empirically rather than assumed, because the plausible alternative
;;   (feature LEVEL governs) would silently invert the file's precedence and
;;   turn, say, the `map_literal key:' rule into a vacuous one.  A rule with
;;   :override nil cannot repaint what an earlier rule already painted, so
;;   emitting settings in file order reproduces the file's semantics exactly.
;;   Hence: settings stay in file order, and :override is NEVER set.
;;
;;   GENERIC CAPTURES.  The file names captures `@variable.parameter', not Emacs
;;   faces.  `prologos-ts--capture-faces' maps them, using the same
;;   `foo.bar.baz' -> `foo.bar' -> `foo' fallback as CAPTURE_MAP in
;;   src/semanticTokens.ts.  The queries rely on that fallback existing.
;;
;;   FEATURES ARE OURS ALONE.  A .scm has no notion of
;;   `treesit-font-lock-level', so the feature is derived from the capture name.
;;   It controls enable/disable ONLY, never order.

(defvar prologos-ts--dir
  (file-name-directory (or load-file-name buffer-file-name default-directory))
  "Directory of this file, captured at LOAD time.
`load-file-name' is bound only while loading, so it cannot be read later.")

(defcustom prologos-ts-highlights-file
  (expand-file-name "../tree-sitter-prologos/queries/highlights.scm"
                    prologos-ts--dir)
  "Shared tree-sitter highlight query, also consumed by the VS Code extension."
  :type 'file
  :group 'prologos)

(defconst prologos-ts--capture-faces
  '(("keyword"             . font-lock-keyword-face)
    ("function"            . font-lock-function-name-face)
    ("constructor"         . font-lock-constant-face)
    ("type"                . font-lock-type-face)
    ("type.builtin"        . font-lock-type-face)
    ("type.definition"     . font-lock-type-face)
    ("constant"            . font-lock-constant-face)
    ("constant.builtin"    . font-lock-constant-face)
    ;; `:foo' — renamed from constant.other to the Neovim standard for
    ;; symbols/atoms. The FACE is unchanged on purpose: the rename is a
    ;; vocabulary change, not a colour decision.
    ("string.special.symbol" . font-lock-constant-face)
    ("module"              . font-lock-constant-face)
    ("property"            . font-lock-property-use-face)
    ("operator"            . font-lock-operator-face)
    ("number"              . font-lock-number-face)
    ("string"              . font-lock-string-face)
    ("character"           . font-lock-string-face)
    ("comment"             . font-lock-comment-face)
    ("attribute"           . prologos-multiplicity-face)
    ("variable.parameter"  . font-lock-variable-name-face)
    ("variable.logic"      . font-lock-variable-name-face)
    ("variable.hole"       . prologos-hole-face)
    ;; `variable' is deliberately NIL, and the rule is DROPPED rather than
    ;; painted.  highlights.scm ends with a bare `(identifier) @variable'
    ;; fallback that claims every otherwise-unmatched identifier.  In VS Code
    ;; `variable' is the NEUTRAL token, so that costs nothing; in Emacs the
    ;; neutral rendering is *no face at all*, and mapping it to
    ;; `font-lock-variable-name-face' would colour every identifier in the
    ;; buffer -- a wall of colour, and a regression against today's behaviour,
    ;; where Emacs paints none of them.
    ;;
    ;; This also drops the `identifier_pattern' and `let_binding' rules, which
    ;; share the capture.  Those ARE binding sites and arguably deserve colour;
    ;; if we want that, the right fix is a DISTINCT capture in the shared .scm
    ;; (`@variable.definition'), which would benefit both editors -- not a
    ;; second divergent mapping here.
    ("variable"            . nil))
  "Map from highlights.scm capture names to Emacs faces.
A nil face means the rule is dropped.  Lookup falls back
`foo.bar.baz' -> `foo.bar' -> `foo', mirroring CAPTURE_MAP in
src/semanticTokens.ts.")

(defconst prologos-ts--capture-features
  '(("comment"    . comment)
    ("string"     . string)
    ("character"  . string)
    ("keyword"    . keyword)
    ("function"   . function)
    ("module"     . definition)
    ("type"       . type)
    ("constant"   . constant)
    ("constructor" . constant)
    ("property"   . property)
    ("number"     . number)
    ("operator"   . operator)
    ("attribute"  . multiplicity)
    ("variable"   . variable))
  "Map from capture name to `treesit-font-lock-feature-list' feature.
Same prefix fallback as `prologos-ts--capture-faces'.  Features govern
enable/disable via `treesit-font-lock-level' and NOTHING about order.")

(defun prologos-ts--capture-lookup (capture alist)
  "Look CAPTURE up in ALIST, falling back on dotted prefixes.
`foo.bar.baz' tries `foo.bar.baz', then `foo.bar', then `foo' — the same
walk CAPTURE_MAP performs in src/semanticTokens.ts.

⚠ `save-match-data' is REQUIRED, not hygiene.  This runs inside the
replacement function of `replace-regexp-in-string', which reads the match
data back after REP returns; the `string-match' below clobbers it and the
replacement then lands one character short.  The observed symptom was
`@font-lock-type-facen' / `@prologos-hole-facee' — the capture's final
character stranded after the substitution.  Those are VALID capture names,
so every query still compiled and zero were skipped; they simply named
faces that do not exist and painted nothing."
  (save-match-data
    (let ((name capture) hit)
      (while (and name (not hit))
        (setq hit (assoc name alist))
        (setq name (and (string-match "\\`\\(.*\\)\\.[^.]+\\'" name)
                        (match-string 1 name))))
      hit)))

(defun prologos-ts-translate-query-predicates (query)
  "Return QUERY with every `#match?'/`#not-match?' regexp in Emacs dialect.

Extracted so the font-lock builder and the EHP parity harness
\(parity/dump-captures.el) share ONE implementation.  They must: a harness
that skips this step silently loses every `#match?'-driven capture to the
`(identifier) @variable' fallback, and would then bake that wrong answer
into the golden and blame the OTHER editor for the difference.  Measured
2026-08-14 while building the harness: `Int', `zero' and `solve' all came
back as @variable.

DOUBLES the backslashes.  tree-sitter parses the query text and unescapes
string literals BEFORE Emacs ever sees the regexp, so a single `\\(' arrives
as a bare `(' and the Emacs-dialect regexp decays right back into the PCRE
one that matches nothing.  Measured: single -> nil captures, doubled ->
(\"Int\" \"Bool\").  LITERAL=t, so NEWTEXT is inserted verbatim: it must be
the TWO-character string \"\\\\\", i.e. \"\\\\\\\\\" in source.  Writing the
usual four-backslash form doubles twice and emits four.

Signals an error if `prologos-ts--translate-regexp' refuses a pattern; the
caller decides whether that skips the pattern or fails the run."
  (replace-regexp-in-string
   "(#\\(?:match\\|not-match\\)\\?[ \t\n]+@[^ \t\n]+[ \t\n]+\"\\(\\(?:[^\"\\\\]\\|\\\\.\\)*\\)\""
   (lambda (m)
     (save-match-data
       (string-match
        "\\`\\(.*\"\\)\\(\\(?:[^\"\\\\]\\|\\\\.\\)*\\)\\(\"\\)\\'" m)
       (concat
        (match-string 1 m)
        (replace-regexp-in-string
         "\\\\" "\\\\"
         (prologos-ts--translate-regexp (match-string 2 m))
         t t)
        (match-string 3 m))))
   query t t))

(defun prologos-ts--translate-regexp (re)
  "Translate RE from tree-sitter (PCRE-ish) syntax to Emacs regexp syntax.

Emacs DOES evaluate `#match?' in a string query — but with EMACS regexp
syntax, where `(', `)' and `|' are LITERAL.  So highlights.scm's
`^(Int|Bool)$' matches the literal text \"(Int|Bool)\", i.e. nothing, and
does so SILENTLY: the query compiles and the rule is simply dead.  That
killed all three identifier-matched rules (pseudo-keywords, builtin types,
builtin constants) — a regression against the inline rules this replaced,
which used Emacs's own `:match' form.

Signals an error on any construct not handled, so an untranslatable
pattern is SKIPPED VISIBLY rather than shipped dead."
  (let ((out "") (i 0) (n (length re)))
    (while (< i n)
      (let ((c (aref re i)))
        (cond
         ;; Escape: copy the pair through untouched.
         ((eq c ?\\)
          (when (>= (1+ i) n) (error "Trailing backslash in regexp %S" re))
          (let ((next (aref re (1+ i))))
            (when (memq next '(?d ?w ?s ?D ?W ?S ?b ?B))
              (error "PCRE class \\%c has no direct Emacs equivalent in %S" next re))
            (setq out (concat out (substring re i (+ i 2))) i (+ i 2))))
         ;; Character class: copy verbatim to the closing bracket.
         ((eq c ?\[)
          (let ((j (1+ i)))
            (when (and (< j n) (eq (aref re j) ?^)) (setq j (1+ j)))
            (when (and (< j n) (eq (aref re j) ?\])) (setq j (1+ j)))
            (while (and (< j n) (not (eq (aref re j) ?\]))) (setq j (1+ j)))
            (when (>= j n) (error "Unterminated [...] in regexp %S" re))
            (setq out (concat out (substring re i (1+ j))) i (1+ j))))
         ;; Groups and alternation are the whole point of the translation.
         ((eq c ?\()
          (if (and (< (+ i 2) n) (eq (aref re (1+ i)) ??) (eq (aref re (+ i 2)) ?:))
              (setq out (concat out "\\(?:") i (+ i 3))
            (setq out (concat out "\\(?:") i (1+ i))))
         ((eq c ?\)) (setq out (concat out "\\)") i (1+ i)))
         ((eq c ?|)  (setq out (concat out "\\|") i (1+ i)))
         ((eq c ?{)  (error "PCRE {n,m} repetition is untranslated in %S" re))
         (t (setq out (concat out (string c)) i (1+ i))))))
    out))

(defun prologos-ts--split-query (text)
  "Split TEXT, a tree-sitter query file, into top-level patterns IN ORDER.
A pattern is one balanced group (or a bare string) plus any `@capture'
tokens that immediately follow it.  Emacs's own sexp scanner does the
lexing, so strings, comments and both bracket kinds are handled for us."
  (with-temp-buffer
    (insert text)
    (let ((tbl (make-syntax-table)))
      (modify-syntax-entry ?\( "()" tbl)
      (modify-syntax-entry ?\) ")(" tbl)
      (modify-syntax-entry ?\[ "(]" tbl)
      (modify-syntax-entry ?\] ")[" tbl)
      (modify-syntax-entry ?\" "\"" tbl)
      (modify-syntax-entry ?\\ "\\" tbl)
      (modify-syntax-entry ?\; "<" tbl)
      (modify-syntax-entry ?\n ">" tbl)
      ;; Everything that can appear inside a capture or predicate name must be
      ;; symbol-constituent, or `forward-sexp' stops mid-token.
      (dolist (c '(?@ ?. ?- ?? ?! ?# ?_ ?* ?> ?< ?= ?| ?& ?: ?+ ?/ ?%))
        (modify-syntax-entry c "_" tbl))
      (set-syntax-table tbl))
    (goto-char (point-min))
    (let (out)
      (while (progn (forward-comment (buffer-size)) (not (eobp)))
        (let ((start (point)) end)
          (forward-sexp 1)
          (setq end (point))
          ;; Absorb trailing @captures belonging to this pattern.
          (while (save-excursion
                   (forward-comment (buffer-size))
                   (and (not (eobp)) (eq (char-after) ?@)))
            (forward-comment (buffer-size))
            (forward-sexp 1)
            (setq end (point)))
          (push (string-trim (buffer-substring-no-properties start end)) out)))
      (nreverse out))))

(defun prologos-ts--pattern-captures (pattern)
  "Return the distinct capture names in PATTERN, in order of appearance."
  (let ((pos 0) out)
    (while (string-match "@\\([a-zA-Z][a-zA-Z0-9._]*\\)" pattern pos)
      (cl-pushnew (match-string 1 pattern) out :test #'equal)
      (setq pos (match-end 0)))
    (nreverse out)))

(defvar prologos-ts--skipped-patterns nil
  "Patterns skipped while building the rules, with the reason.
Non-nil here means Emacs is showing LESS than highlights.scm specifies.")

(defun prologos-ts--build-font-lock-rules (&optional file)
  "Build `treesit-font-lock-rules' arguments from FILE (a .scm query).
Returns the argument list, in FILE ORDER.  Patterns whose capture has no
face, or which the installed grammar cannot compile, are skipped and
recorded in `prologos-ts--skipped-patterns' — a query that references a
node type the grammar lacks would otherwise take the whole feature down
with it (`treesit-font-lock-rules-mismatch')."
  (setq file (or file prologos-ts-highlights-file))
  (setq prologos-ts--skipped-patterns nil)
  (if (not (file-readable-p file))
      (progn
        (display-warning
         'prologos
         (format "highlights.scm not found at %s — tree-sitter font-lock disabled" file)
         :error)
        nil)
    (let ((patterns (prologos-ts--split-query
                     (with-temp-buffer (insert-file-contents file)
                                       (buffer-string))))
          args)
      (dolist (pat patterns)
        (let* ((caps (prologos-ts--pattern-captures pat))
               (primary (car caps))
               (face-cell (and primary (prologos-ts--capture-lookup
                                        primary prologos-ts--capture-faces)))
               (feature (cdr (or (and primary (prologos-ts--capture-lookup
                                               primary prologos-ts--capture-features))
                                 '(nil . nil)))))
          (cond
           ((null primary)
            (push (cons pat "no capture") prologos-ts--skipped-patterns))
           ((null face-cell)
            (push (cons pat (format "capture %s not in the face map" primary))
                  prologos-ts--skipped-patterns))
           ((null (cdr face-cell))
            ;; Deliberately unpainted (see `variable' above) — not a defect.
            nil)
           (t
            ;; Rewrite every @capture in the pattern (predicates reference it
            ;; too, so a partial rewrite would break `#match?'), then translate
            ;; any #match? regexp into Emacs syntax.
            (let* ((q (replace-regexp-in-string
                       "@\\([a-zA-Z][a-zA-Z0-9._]*\\)"
                       (lambda (m)
                         (let* ((c (substring m 1))
                                (cell (prologos-ts--capture-lookup
                                       c prologos-ts--capture-faces)))
                           (if (and cell (cdr cell))
                               (concat "@" (symbol-name (cdr cell)))
                             m)))
                       pat t t))
                   (q (condition-case err
                          (prologos-ts-translate-query-predicates q)
                        (error
                         (push (cons pat (format "regexp translation: %S" err))
                               prologos-ts--skipped-patterns)
                         nil))))
              ;; q is nil when regexp translation refused the pattern; it has
              ;; already been recorded as skipped.
              (when (and q
                         (condition-case err
                             (progn (treesit-query-compile 'prologos q t) t)
                           (error (push (cons pat (format "%S" err))
                                        prologos-ts--skipped-patterns)
                                  nil)))
                (setq args (append args (list :language 'prologos
                                              :feature (or feature 'variable)
                                              q)))))))))
      (when prologos-ts--skipped-patterns
        (display-warning
         'prologos
         (concat
          (format "%d highlight pattern(s) skipped — those constructs will not\ncolour:\n"
                  (length prologos-ts--skipped-patterns))
          (mapconcat (lambda (s)
                       (format "  %s"
                               (replace-regexp-in-string
                                "\n *" " " (truncate-string-to-width (car s) 68))))
                     (reverse prologos-ts--skipped-patterns) "\n")
          "\n\nIf these name node types the grammar should have, the usual cause is a
STALE MAPPED GRAMMAR: Emacs maps a tree-sitter dylib once per session and
cannot unmap it, so install.sh replaces the file on disk while this session
keeps the parser it already loaded.  Reloading the Emacs side cannot fix
that — it is the one case that needs a fresh Emacs.  Full detail in
`prologos-ts--skipped-patterns'.")
         :warning))
      args)))

(defconst prologos-ts-font-lock-rules
  (let ((args (prologos-ts--build-font-lock-rules)))
    (and args (apply #'treesit-font-lock-rules args)))
  "Tree-sitter font-lock rules for Prologos, generated from highlights.scm.")

;; ============================================================
;; Defun name extraction
;; ============================================================

(defun prologos-ts--defun-name (node)
  "Return the name of the defun NODE for imenu and which-func."
  (treesit-node-text
   (treesit-node-child-by-field-name node "name")
   t))

;; ============================================================
;; Syntactic fontification fallback for tree-sitter
;; ============================================================
;;
;; The tree-sitter grammar doesn't handle all Prologos constructs
;; (e.g., `foreign' declarations).  Comments near ERROR nodes don't
;; get (comment) tree-sitter nodes, so they lose their face.
;;
;; This wrapper runs tree-sitter fontification first, then applies
;; Emacs's built-in syntactic fontification (using the syntax table)
;; as a safety net — any comment or string that tree-sitter missed
;; gets its face from the standard `syntax-ppss' based pass.

(defun prologos-ts--syntactic-fallback (beg end)
  "Apply comment/string faces via `syntax-ppss' in region BEG..END.
Only applies to positions where the `face' property is still nil,
so tree-sitter results are never overridden.

Handles three cases:
1. Point starts inside a comment or string (multi-line continuation).
2. Line begins with `;' — apply comment delimiter + comment faces.
3. Otherwise scan within the line for mid-line strings and comments
   that tree-sitter missed (e.g., on `foreign' declaration lines
   inside ERROR nodes)."
  (save-excursion
    (goto-char beg)
    (beginning-of-line)
    (while (< (point) end)
      (let* ((ppss (syntax-ppss (point)))
             (in-string (nth 3 ppss))
             (in-comment (nth 4 ppss))
             (start (point)))
        (cond
         (in-comment
          ;; Inside a comment — apply face to end of line
          (let ((comment-end (line-end-position)))
            (prologos-ts--apply-fallback-face
             start comment-end in-string in-comment)
            (goto-char (min (1+ comment-end) end))))
         (in-string
          ;; Inside a string — find its end via parse-partial-sexp
          (let ((string-end (save-excursion
                              (parse-partial-sexp (point) end nil nil ppss
                                                  'syntax-table)
                              (point))))
            (prologos-ts--apply-fallback-face
             start string-end in-string in-comment)
            (goto-char string-end)))
         (t
          ;; Not inside string or comment at start of line.
          ;; Check if line begins with comment delimiters.
          (if (looking-at "\\(;+\\)\\(.*\\)$")
              (let ((delim-end (match-end 1))
                    (line-end (match-end 0)))
                (prologos-ts--apply-fallback-face-range
                 start delim-end 'font-lock-comment-delimiter-face)
                (when (< delim-end line-end)
                  (prologos-ts--apply-fallback-face-range
                   delim-end line-end 'font-lock-comment-face))
                (goto-char (min (1+ line-end) end)))
            ;; Scan within the line for mid-line syntactic constructs.
            ;; This catches strings like "racket/base" and inline comments
            ;; on lines the tree-sitter grammar can't parse (ERROR nodes).
            (prologos-ts--scan-line-for-syntax end)
            (forward-line 1))))))))

(defun prologos-ts--scan-line-for-syntax (region-end)
  "Scan current line for mid-line strings and comments missed by tree-sitter.
Applies `font-lock-string-face' to string literals and
`font-lock-comment-face' to trailing comments.  Only touches
positions where `face' is still nil.  REGION-END bounds the scan."
  (let ((line-end (min (line-end-position) region-end))
        (pos (point)))
    (while (< pos line-end)
      (let ((ppss (syntax-ppss pos)))
        (cond
         ;; Entered a string
         ((nth 3 ppss)
          (let ((str-start (nth 8 ppss))  ; string/comment start position
                (str-end (save-excursion
                           (parse-partial-sexp pos line-end nil nil ppss
                                               'syntax-table)
                           (point))))
            ;; Apply string face (skip generic-string = racket blocks)
            (unless (eq (nth 3 ppss) t)
              (prologos-ts--apply-fallback-face-range pos str-end
                                                      'font-lock-string-face))
            (setq pos str-end)))
         ;; Entered a comment
         ((nth 4 ppss)
          (prologos-ts--apply-fallback-face-range pos line-end
                                                  'font-lock-comment-face)
          (setq pos line-end))
         ;; Normal code — advance to the next syntactically interesting char
         (t
          (let ((next (save-excursion
                        (parse-partial-sexp pos line-end nil nil ppss
                                            'syntax-table)
                        (point))))
            ;; If parse didn't advance (e.g., at line-end), force progress
            (setq pos (if (= next pos) line-end next)))))))))

(defun prologos-ts--apply-fallback-face (beg end in-string in-comment)
  "Apply syntactic face in BEG..END based on IN-STRING and IN-COMMENT.
Only applies where existing face is nil."
  (let ((face (cond
               (in-comment 'font-lock-comment-face)
               ((eq in-string t) nil)       ; generic-string (racket block)
               (in-string 'font-lock-string-face)
               (t nil))))
    (when face
      (prologos-ts--apply-fallback-face-range beg end face))))

(defun prologos-ts--apply-fallback-face-range (beg end face)
  "Apply FACE to positions in BEG..END where existing face is nil."
  (let ((pos beg))
    (while (< pos end)
      (let ((existing (get-text-property pos 'face))
            (next-change (or (next-single-property-change pos 'face nil end)
                             end)))
        (when (null existing)
          (put-text-property pos (min next-change end) 'face face))
        (setq pos next-change)))))

;; ============================================================
;; Native racket{...} block fontification for tree-sitter mode
;; ============================================================
;;
;; The tree-sitter grammar doesn't have a racket_escape node, so
;; racket{...} blocks parse as ERROR with their content treated as
;; regular Prologos nodes.  This pass finds racket blocks, applies
;; `prologos-racket-delimiter-face' to the delimiters, and delegates
;; to `prologos--fontify-racket-block-natively' (from prologos-font-lock.el)
;; for scheme-mode/racket-mode highlighting of the interior.

(defun prologos-ts--fontify-racket-blocks (beg end)
  "Find and natively fontify all racket{...} blocks in BEG..END.
Applies `prologos-racket-delimiter-face' to `racket{' and `}' delimiters,
and delegates interior fontification to scheme-mode/racket-mode."
  (save-excursion
    (goto-char beg)
    (while (re-search-forward "racket{" end t)
      (let ((kw-start (match-beginning 0))
            (brace-start (1- (point)))
            (content-start (point)))
        ;; Skip if inside a comment or string
        (unless (let ((ppss (save-excursion (syntax-ppss brace-start))))
                  (or (nth 3 ppss) (nth 4 ppss)))
          ;; Find matching } by brace counting
          (let ((depth 1)
                close)
            (save-excursion
              (goto-char content-start)
              (while (and (> depth 0) (re-search-forward "[{}]" end t))
                (cond
                 ((eq (char-before) ?\{) (setq depth (1+ depth)))
                 ((eq (char-before) ?\})
                  (setq depth (1- depth))
                  (when (= depth 0)
                    (setq close (1- (point))))))))
            (when close
              ;; Highlight delimiters
              (put-text-property kw-start (1+ brace-start)
                                 'face 'prologos-racket-delimiter-face)
              (put-text-property close (1+ close)
                                 'face 'prologos-racket-delimiter-face)
              ;; Natively fontify the interior content
              (when (< content-start close)
                (save-match-data
                  (prologos--fontify-racket-block-natively content-start close)))
              (goto-char (1+ close)))))))))

;; ============================================================
;; Keymap
;; ============================================================

(defvar prologos-ts-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-z") #'prologos-repl)
    (define-key map (kbd "C-x C-e") #'prologos-send-form)
    ;; M-<return> is the cmd+enter equivalent here: this configuration
    ;; binds the Command key to Meta, so this is the same physical
    ;; gesture the VS Code extension binds to prologos.evalTopLevel.
    (define-key map (kbd "M-<return>") #'prologos-send-form)
    (define-key map (kbd "C-c C-r") #'prologos-eval-region)
    (define-key map (kbd "C-c C-k") #'prologos-eval-buffer)
    (define-key map (kbd "C-c C-l") #'prologos-load-file)
    map)
  "Keymap for `prologos-ts-mode'.")

;; ============================================================
;; Mode definition
;; ============================================================

;;;###autoload
(define-derived-mode prologos-ts-mode prog-mode "Prologos"
  "Tree-sitter based major mode for editing Prologos source files."
  :group 'prologos
  :syntax-table (if (boundp 'prologos-mode-syntax-table)
                    prologos-mode-syntax-table
                  (make-syntax-table))

  ;; Ensure tree-sitter parser is available
  (unless (treesit-ready-p 'prologos)
    (error "Tree-sitter grammar for `prologos' is not available"))

  (treesit-parser-create 'prologos)

  ;; Font-lock — tree-sitter rules
  (setq-local treesit-font-lock-settings prologos-ts-font-lock-rules)
  (setq-local treesit-font-lock-feature-list
              '((comment string)
                (keyword function definition)
                (type constant number multiplicity property variable)
                (operator)))

  ;; Syntax propertize — angle brackets + racket{...} escape blocks
  (setq-local syntax-propertize-function #'prologos--syntax-propertize)
  (add-hook 'syntax-propertize-extend-region-functions
            #'prologos--extend-region-for-syntax nil t)

  ;; Extend jit-lock region across racket{...} blocks
  (add-hook 'jit-lock-after-change-extend-region-functions
            #'prologos--jit-lock-extend-region nil t)

  ;; WS mode — .prologos files always use whitespace-significant syntax
  (prologos--detect-lang-mode)

  ;; Indentation — WS mode: indentation IS the syntax, use TAB cycling
  (setq-local indent-line-function #'prologos--ws-indent-line)

  ;; Comments
  (setq-local comment-start ";; ")
  (setq-local comment-end "")
  (setq-local comment-start-skip ";+\\s-*")

  ;; Navigation via treesit
  (setq-local treesit-defun-type-regexp
              (rx (or "defn_form" "def_form" "data_form" "deftype_form")))
  (setq-local treesit-defun-name-function #'prologos-ts--defun-name)

  ;; Imenu via treesit
  (setq-local treesit-simple-imenu-settings
              '(("Function" "\\`defn_form\\'" nil nil)
                ("Function" "\\`def_form\\'" nil nil)
                ("Type" "\\`data_form\\'" nil nil)
                ("Type" "\\`deftype_form\\'" nil nil)))

  ;; Activate tree-sitter features
  (treesit-major-mode-setup)

  ;; After treesit-major-mode-setup: install a wrapper around the
  ;; fontify-region function that runs three passes:
  ;; 1. Standard tree-sitter font-lock
  ;; 2. Syntactic fallback (comments/strings in ERROR regions)
  ;; 3. Native racket{...} block fontification (scheme-mode highlighting)
  (let ((original-fn font-lock-fontify-region-function))
    (setq-local font-lock-fontify-region-function
                (lambda (beg end &optional loudly)
                  ;; Pass 1: tree-sitter font-lock
                  (funcall original-fn beg end loudly)
                  ;; Pass 2: syntactic fallback for missed comments/strings
                  (prologos-ts--syntactic-fallback beg end)
                  ;; Pass 3: native racket{...} block highlighting
                  (when prologos-fontify-racket-blocks-natively
                    (prologos-ts--fontify-racket-blocks beg end))))))

;; ============================================================
;; Auto-mode fallback
;; ============================================================

;;;###autoload
(defun prologos-ts-mode-or-fallback ()
  "Use `prologos-ts-mode' if tree-sitter grammar available, else `prologos-mode'."
  (if (treesit-ready-p 'prologos t)
      (prologos-ts-mode)
    (prologos-mode)))

;; Override auto-mode-alist to use tree-sitter fallback dispatcher.
;; This takes precedence over prologos-mode.el's plain binding because
;; add-to-list pushes to the front of the alist.
;;;###autoload
(add-to-list 'auto-mode-alist '("\\.prologos\\'" . prologos-ts-mode-or-fallback))

(provide 'prologos-ts-mode)

;;; prologos-ts-mode.el ends here



;;; TODO Sprint 3-7/8 of Implementation Prologos Surfer
