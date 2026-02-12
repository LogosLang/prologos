;;; prologos-repl-test.el --- ERT tests for prologos-repl -*- lexical-binding: t; -*-

;;; Commentary:

;; Automated tests for Prologos REPL integration: result parsing,
;; inline overlays, keymap bindings, and customization defaults.
;; Integration tests (requiring a running Racket process) are
;; skipped when Racket is not available.

;;; Code:

(require 'ert)
(require 'prologos-repl)
(require 'prologos-mode)

;; ============================================================
;; Helpers
;; ============================================================

(defmacro prologos-repl-test--in-buffer (content &rest body)
  "Execute BODY in a temp buffer with CONTENT in `prologos-mode'."
  (declare (indent 1))
  `(let ((buf (generate-new-buffer "*prologos-repl-test*")))
     (unwind-protect
         (with-current-buffer buf
           (insert ,content)
           (goto-char (point-min))
           (prologos-mode)
           ,@body)
       (kill-buffer buf))))

(defun prologos-repl-test--racket-available-p ()
  "Return non-nil if Racket is available on PATH."
  (executable-find "racket"))

;; ============================================================
;; Test: Customization defaults
;; ============================================================

(ert-deftest prologos-repl-test/default-program ()
  "Default program should be 'racket'."
  (should (string= prologos-program "racket")))

(ert-deftest prologos-repl-test/default-args ()
  "Default args should launch prologos/repl."
  (should (equal prologos-program-args '("-l" "prologos/repl"))))

(ert-deftest prologos-repl-test/default-buffer-name ()
  "Default REPL buffer name should be *prologos-repl*."
  (should (string= prologos-repl-buffer-name "*prologos-repl*")))

(ert-deftest prologos-repl-test/default-timeout ()
  "Default inline result timeout should be 10 seconds."
  (should (= prologos-inline-result-timeout 10)))

;; ============================================================
;; Test: Result parsing
;; ============================================================

(ert-deftest prologos-repl-test/parse-result-eval ()
  "Parse a simple eval result."
  (should (string= (prologos--parse-result "zero : Nat")
                    "zero : Nat")))

(ert-deftest prologos-repl-test/parse-result-def ()
  "Parse a definition result."
  (should (string= (prologos--parse-result "id : (Pi (A :m0 (Type 0)) (-> A A)) defined.")
                    "id : (Pi (A :m0 (Type 0)) (-> A A)) defined.")))

(ert-deftest prologos-repl-test/parse-result-multiline ()
  "Parse multi-line output (e.g., from :env)."
  (let ((output "  id : (-> A A)\n  add : (-> Nat Nat Nat)"))
    (should (string= (prologos--parse-result output)
                      "id : (-> A A)\nadd : (-> Nat Nat Nat)"))))

(ert-deftest prologos-repl-test/parse-result-error ()
  "Parse error output."
  (should (string= (prologos--parse-result "Error: type mismatch")
                    "Error: type mismatch")))

(ert-deftest prologos-repl-test/parse-result-ok ()
  "Parse 'OK' check result."
  (should (string= (prologos--parse-result "OK")
                    "OK")))

(ert-deftest prologos-repl-test/parse-result-strips-prompt ()
  "Prompt-prefixed lines should be filtered out."
  (let ((output "> (eval zero)\nzero : Nat"))
    (should (string= (prologos--parse-result output)
                      "zero : Nat"))))

(ert-deftest prologos-repl-test/parse-result-empty ()
  "Empty output should parse to empty string."
  (should (string= (prologos--parse-result "")
                    "")))

(ert-deftest prologos-repl-test/parse-result-macro ()
  "Parse macro definition result."
  (should (string= (prologos--parse-result "Macro defined.")
                    "Macro defined.")))

(ert-deftest prologos-repl-test/parse-result-type-alias ()
  "Parse type alias result."
  (should (string= (prologos--parse-result "Type alias defined.")
                    "Type alias defined.")))

;; ============================================================
;; Test: Inline overlay management
;; ============================================================

(ert-deftest prologos-repl-test/display-inline-result ()
  "Displaying an inline result should create an overlay."
  (prologos-repl-test--in-buffer "(eval zero)"
    (goto-char (point-max))
    (prologos--display-inline-result "zero : Nat" (point))
    (should (= (length prologos--result-overlays) 1))
    (let ((ov (car prologos--result-overlays)))
      (should (overlay-get ov 'prologos-result))
      (should (string-match-p "=> zero : Nat"
                              (overlay-get ov 'after-string))))
    ;; Clean up
    (prologos--clear-inline-results)))

(ert-deftest prologos-repl-test/clear-inline-results ()
  "Clearing should remove all result overlays."
  (prologos-repl-test--in-buffer "(eval zero)"
    (goto-char (point-max))
    (prologos--display-inline-result "zero : Nat" (point))
    (should (= (length prologos--result-overlays) 1))
    (prologos--clear-inline-results)
    (should (= (length prologos--result-overlays) 0))))

(ert-deftest prologos-repl-test/display-replaces-previous ()
  "Displaying a new result should clear the previous one."
  (prologos-repl-test--in-buffer "(eval zero)\n(eval true)"
    (goto-char 12) ;; after first sexp
    (prologos--display-inline-result "zero : Nat" (point))
    (should (= (length prologos--result-overlays) 1))
    ;; Display a second result — should clear the first
    (goto-char (point-max))
    (prologos--display-inline-result "true : Bool" (point))
    (should (= (length prologos--result-overlays) 1))
    (let ((ov (car prologos--result-overlays)))
      (should (string-match-p "=> true : Bool"
                              (overlay-get ov 'after-string))))
    ;; Clean up
    (prologos--clear-inline-results)))

(ert-deftest prologos-repl-test/overlay-face ()
  "Inline result overlay should use the correct face."
  (prologos-repl-test--in-buffer "(eval zero)"
    (goto-char (point-max))
    (prologos--display-inline-result "zero : Nat" (point))
    (let* ((ov (car prologos--result-overlays))
           (str (overlay-get ov 'after-string)))
      (should (eq (get-text-property 0 'face str)
                  'prologos-result-overlay-face)))
    (prologos--clear-inline-results)))

;; ============================================================
;; Test: Keymap bindings — prologos-mode
;; ============================================================

(ert-deftest prologos-repl-test/mode-map-repl-binding ()
  "C-c C-z should be bound to prologos-repl in prologos-mode-map."
  (should (eq (lookup-key prologos-mode-map (kbd "C-c C-z"))
              'prologos-repl)))

(ert-deftest prologos-repl-test/mode-map-eval-last-sexp ()
  "C-x C-e should be bound to prologos-eval-last-sexp."
  (should (eq (lookup-key prologos-mode-map (kbd "C-x C-e"))
              'prologos-eval-last-sexp)))

(ert-deftest prologos-repl-test/mode-map-eval-region ()
  "C-c C-r should be bound to prologos-eval-region."
  (should (eq (lookup-key prologos-mode-map (kbd "C-c C-r"))
              'prologos-eval-region)))

(ert-deftest prologos-repl-test/mode-map-eval-buffer ()
  "C-c C-k should be bound to prologos-eval-buffer."
  (should (eq (lookup-key prologos-mode-map (kbd "C-c C-k"))
              'prologos-eval-buffer)))

(ert-deftest prologos-repl-test/mode-map-load-file ()
  "C-c C-l should be bound to prologos-load-file."
  (should (eq (lookup-key prologos-mode-map (kbd "C-c C-l"))
              'prologos-load-file)))

(ert-deftest prologos-repl-test/mode-map-eval-defun ()
  "C-c C-d should be bound to prologos-eval-defun-at-point."
  (should (eq (lookup-key prologos-mode-map (kbd "C-c C-d"))
              'prologos-eval-defun-at-point)))

;; ============================================================
;; Test: Keymap bindings — prologos-ts-mode (if available)
;; ============================================================

(ert-deftest prologos-repl-test/ts-mode-map-exists ()
  "prologos-ts-mode-map should be defined."
  (skip-unless (boundp 'prologos-ts-mode-map))
  (should (keymapp prologos-ts-mode-map)))

(ert-deftest prologos-repl-test/ts-mode-map-repl-binding ()
  "C-c C-z should be bound in prologos-ts-mode-map."
  (skip-unless (boundp 'prologos-ts-mode-map))
  (should (eq (lookup-key prologos-ts-mode-map (kbd "C-c C-z"))
              'prologos-repl)))

(ert-deftest prologos-repl-test/ts-mode-map-eval-last-sexp ()
  "C-x C-e should be bound in prologos-ts-mode-map."
  (skip-unless (boundp 'prologos-ts-mode-map))
  (should (eq (lookup-key prologos-ts-mode-map (kbd "C-x C-e"))
              'prologos-eval-last-sexp)))

(ert-deftest prologos-repl-test/ts-mode-map-eval-region ()
  "C-c C-r should be bound in prologos-ts-mode-map."
  (skip-unless (boundp 'prologos-ts-mode-map))
  (should (eq (lookup-key prologos-ts-mode-map (kbd "C-c C-r"))
              'prologos-eval-region)))

(ert-deftest prologos-repl-test/ts-mode-map-eval-buffer ()
  "C-c C-k should be bound in prologos-ts-mode-map."
  (skip-unless (boundp 'prologos-ts-mode-map))
  (should (eq (lookup-key prologos-ts-mode-map (kbd "C-c C-k"))
              'prologos-eval-buffer)))

(ert-deftest prologos-repl-test/ts-mode-map-load-file ()
  "C-c C-l should be bound in prologos-ts-mode-map."
  (skip-unless (boundp 'prologos-ts-mode-map))
  (should (eq (lookup-key prologos-ts-mode-map (kbd "C-c C-l"))
              'prologos-load-file)))

(ert-deftest prologos-repl-test/ts-mode-map-eval-defun ()
  "C-c C-d should be bound in prologos-ts-mode-map."
  (skip-unless (boundp 'prologos-ts-mode-map))
  (should (eq (lookup-key prologos-ts-mode-map (kbd "C-c C-d"))
              'prologos-eval-defun-at-point)))

;; ============================================================
;; Test: REPL mode definition
;; ============================================================

(ert-deftest prologos-repl-test/repl-mode-is-comint-derived ()
  "prologos-repl-mode should be derived from comint-mode."
  (should (provided-mode-derived-p 'prologos-repl-mode 'comint-mode)))

;; ============================================================
;; Test: Face definition
;; ============================================================

(ert-deftest prologos-repl-test/result-face-defined ()
  "prologos-result-overlay-face should be a valid face."
  (should (facep 'prologos-result-overlay-face)))

;; ============================================================
;; Test: Interactive commands are defined
;; ============================================================

(ert-deftest prologos-repl-test/commands-interactive ()
  "All evaluation commands should be interactive."
  (should (commandp 'prologos-repl))
  (should (commandp 'prologos-eval-last-sexp))
  (should (commandp 'prologos-eval-region))
  (should (commandp 'prologos-eval-buffer))
  (should (commandp 'prologos-load-file))
  (should (commandp 'prologos-eval-defun-at-point))
  (should (commandp 'prologos-repl-clear)))

;; ============================================================
;; Provide
;; ============================================================

(provide 'prologos-repl-test)

;;; prologos-repl-test.el ends here
