;;; check-regexps.el --- EHP P5: #match? dialect gate -*- lexical-binding: t; -*-

;;; Commentary:

;; Asserts that every `#match?' regex in the SHARED highlights.scm can be
;; honoured by BOTH consumers.
;;
;; The two consumers do not read the same dialect.  VS Code hands the pattern
;; to the tree-sitter query engine (PCRE-ish).  Emacs evaluates `#match?'
;; itself, in EMACS regexp syntax, where `(', `)' and `|' are literal — so
;; `^(Int|Bool)$' matches the literal text "(Int|Bool)", i.e. nothing, and does
;; so SILENTLY.  `prologos-ts--translate-regexp' bridges that at runtime and
;; raises on anything it cannot express.
;;
;; Why a gate on top of a translator that already raises: the translator
;; protects EMACS, at runtime, when someone happens to open a file.  This gate
;; protects the SHARED CONTRACT, at commit time, for both consumers — including
;; the case the translator structurally cannot see, a pattern that is valid
;; PCRE and silently DIFFERENT in Emacs.  Neither subsumes the other.
;;
;; It deliberately owns no idea of its own about what is translatable: it calls
;; the translator.  Two parallel definitions of one subset would drift, and
;; this project has paid for that shape more than once.
;;
;; Usage: ./check-regexps.sh

;;; Code:

(require 'prologos-ts-mode)
(require 'cl-lib)

(defconst prologos-rx-check--query
  (expand-file-name
   "../queries/highlights.scm"
   (file-name-directory (or load-file-name buffer-file-name default-directory)))
  "The shared query.  Path captured at LOAD time — `load-file-name' is nil later.")

(defun prologos-rx-check--extract (text)
  "Return a list of (LINE . REGEX) for every `#match?' predicate in TEXT.

Walks character by character tracking string and comment state rather than
regexing the raw text.  ⚠ That is not fastidiousness: two sibling gates have
already been broken by COMMENT PROSE that happened to contain the token they
were scanning for, and a regex may itself contain a `;'.  A comment mentioning
`#match?' must not become a lint target, and a `;' inside a pattern must not
start a comment."
  (let ((i 0) (n (length text)) (line 1)
        (pending nil)          ; saw #match?, waiting for its string
        (found '()))
    (while (< i n)
      (let ((c (aref text i)))
        (cond
         ;; newline
         ((eq c ?\n) (cl-incf line) (cl-incf i))
         ;; comment: skip to end of line (not inside a string — we never are here)
         ((eq c ?\;)
          (while (and (< i n) (not (eq (aref text i) ?\n))) (cl-incf i)))
         ;; string literal
         ((eq c ?\")
          (let ((start (1+ i)) (buf ""))
            (cl-incf i)
            (while (and (< i n) (not (eq (aref text i) ?\")))
              (if (eq (aref text i) ?\\)
                  (progn (setq buf (concat buf (substring text i (min n (+ i 2)))))
                         (cl-incf i 2))
                (setq buf (concat buf (string (aref text i))))
                (cl-incf i)))
            (cl-incf i)                 ; closing quote
            (ignore start)
            (when pending
              (push (cons line buf) found)
              (setq pending nil))))
         ;; a predicate name
         ((and (eq c ?#) (string-match-p "\\`#\\(not-\\)?match\\?"
                                         (substring text i (min n (+ i 12)))))
          (setq pending line)
          (cl-incf i))
         (t (cl-incf i)))))
    (nreverse found)))

(defun prologos-rx-check ()
  "Gate every `#match?' regex in the shared query.  Exit non-zero on failure."
  (unless (file-readable-p prologos-rx-check--query)
    (message "FATAL: cannot read %s" prologos-rx-check--query)
    (kill-emacs 2))
  (let* ((text (with-temp-buffer
                 (insert-file-contents prologos-rx-check--query)
                 (buffer-string)))
         (rows (prologos-rx-check--extract text))
         (bad 0))
    (message "")
    (message "  #match? predicates in queries/highlights.scm: %d" (length rows))
    (message "")
    (dolist (row rows)
      (let ((line (car row)) (re (cdr row)))
        (condition-case err
            (let ((translated (prologos-ts--translate-regexp re)))
              (unless (ignore-errors (string-match-p translated "") t)
                (error "translates but does not compile in Emacs"))
              (message "  ok    :%-4d %s" line
                       (if (> (length re) 58) (concat (substring re 0 55) "...") re)))
          (error
           (cl-incf bad)
           (message "  FAIL  :%-4d %s" line re)
           (message "        %s" (error-message-string err))))))
    (message "")
    (if (zerop bad)
        (progn (message "PASS — every #match? is honourable by both consumers.")
               (kill-emacs 0))
      (message "FAIL — %d pattern(s) outside the translatable subset." bad)
      (message "")
      (message "  The shared query must use only constructs BOTH consumers can")
      (message "  honour.  Rewrite the pattern, or move the distinction into the")
      (message "  grammar so the query can match a node type instead of a name.")
      (kill-emacs 1))))

(provide 'check-regexps)

;;; check-regexps.el ends here
