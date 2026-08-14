;;; dump-captures.el --- Emacs side of the EHP parity harness -*- lexical-binding: t; -*-

;;; Commentary:

;; Runs `queries/highlights.scm' over a fixture and prints one TSV line per
;; capture:  LINE <TAB> COL <TAB> CAPTURE <TAB> TEXT
;;
;; The VS Code side (dump-captures.mjs) prints the SAME format over the same
;; query via web-tree-sitter.  `check-parity.sh' diffs the two against a
;; committed golden file.  That is the whole harness: it turns "build once"
;; from a claim about the .scm into a property that fails a test when broken.
;;
;; ⚠ RAW captures, every match, sorted canonically by (line, col, capture).
;;
;; NOT the consumer's resolved first-match-wins view, and the distinction is
;; load-bearing.  The two engines return captures in their own order, so a dump
;; that applies "first match wins" has to assume an order — and `treesit-query-
;; capture' returns in NODE order, not query-file order, so the obvious
;; implementation of that rule is quietly wrong.  Baking it into the golden
;; would encode one engine's traversal as the contract.
;;
;; A canonically-sorted RAW list is order-independent and strictly more
;; information: both consumers run the SAME query over the SAME grammar, so
;; their raw lists must be identical, and any difference is a real parity bug
;; (engine behaviour or predicate dialect).  How each consumer then RESOLVES
;; overlaps is a separate, per-consumer concern, checked separately.
;;
;; Usage:
;;   emacs -Q --batch -L ../../emacs -l dump-captures.el \
;;         --eval '(prologos-parity-dump "fixture.prologos")'

;;; Code:

(require 'treesit)
(require 'cl-lib)
;; For `prologos-ts-translate-query-predicates'.  Not optional: without it the
;; `#match?' predicates are evaluated as PCRE by an engine that speaks Emacs
;; regexp, every identifier-matched capture falls through to the
;; `(identifier) @variable' fallback, and the golden records that wrong answer
;; as the contract.  Measured while building this: `Int', `zero' and `solve'
;; all dumped as @variable, and `type.builtin' appeared NOWHERE.
(require 'prologos-ts-mode)

(defvar prologos-parity--this-dir
  (file-name-directory (or load-file-name buffer-file-name default-directory))
  "Directory of this file, captured at LOAD time (`load-file-name' is nil later).")

(defun prologos-parity--query-file ()
  (expand-file-name "../queries/highlights.scm" prologos-parity--this-dir))

(defun prologos-parity-captures (file)
  "Return the captures Emacs would paint in FILE, first-match-wins.
Each element is (LINE COL CAPTURE TEXT), 1-based line, 0-based column."
  (unless (treesit-language-available-p 'prologos)
    (error "prologos grammar not installed — run ../install.sh"))
  (with-temp-buffer
    (insert-file-contents file)
    (treesit-parser-create 'prologos)
    (let* ((root (treesit-buffer-root-node))
           (query (prologos-ts-translate-query-predicates
                   (with-temp-buffer
                     (insert-file-contents (prologos-parity--query-file))
                     (buffer-string))))
           (raw (treesit-query-capture root query))
           (out '()))
      (dolist (pair raw)
        (let* ((cap (car pair))
               (node (cdr pair))
               (start (treesit-node-start node)))
          (push (list (line-number-at-pos start)
                      (save-excursion (goto-char start) (current-column))
                      (symbol-name cap)
                      (treesit-node-text node t))
                out)))
      ;; Canonical order, so the comparison never depends on either engine's
      ;; traversal.
      (sort out
            (lambda (a b)
              (cond ((/= (nth 0 a) (nth 0 b)) (< (nth 0 a) (nth 0 b)))
                    ((/= (nth 1 a) (nth 1 b)) (< (nth 1 a) (nth 1 b)))
                    (t (string< (nth 2 a) (nth 2 b)))))))))

(defun prologos-parity-dump (file)
  "Print FILE's captures as TSV on stdout."
  (dolist (row (prologos-parity-captures file))
    (princ (format "%d\t%d\t%s\t%s\n"
                   (nth 0 row) (nth 1 row) (nth 2 row)
                   ;; collapse newlines so one capture is always one line
                   (replace-regexp-in-string "\n" "\\\\n" (nth 3 row))))))

(defun prologos-parity-error-count (file)
  "Print the ERROR-node count for FILE.
A fixture with ERROR nodes yields no captures inside them, which would bake
a hole into the golden and make the harness agree about nothing."
  (with-temp-buffer
    (insert-file-contents file)
    (treesit-parser-create 'prologos)
    (let ((n 0) (stack (list (treesit-buffer-root-node))))
      (while stack
        (let ((x (pop stack)))
          (when (equal (treesit-node-type x) "ERROR") (cl-incf n))
          (dolist (c (treesit-node-children x)) (push c stack))))
      (princ (format "ERROR nodes: %d\n" n)))))

(provide 'dump-captures)

;;; dump-captures.el ends here
