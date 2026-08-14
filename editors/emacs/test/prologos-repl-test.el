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
  "Default inline result timeout should be nil.
nil means results persist until the buffer is modified, matching the VS
Code extension.  A number here would silently reintroduce timed expiry."
  (should (null prologos-inline-result-timeout)))

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

(ert-deftest prologos-repl-test/display-keeps-independent-results ()
  "Results for DIFFERENT forms coexist.
This is the behaviour change: results used to be mutually exclusive, so
evaluating a second form erased the first.  Now a screenful of forms can
each carry their own answer, as in the VS Code extension."
  (prologos-repl-test--in-buffer "def a := 1\ndef b := 2"
    (let ((first-end (save-excursion (goto-char (point-min))
                                     (end-of-line) (point)))
          (second-end (point-max)))
      (prologos--display-inline-result "1 : Int" first-end 1 first-end)
      (prologos--display-inline-result "2 : Int" second-end
                                       (1+ first-end) second-end)
      (should (= (length prologos--result-overlays) 2))
      (prologos--clear-inline-results))))

(ert-deftest prologos-repl-test/display-replaces-overlapping-result ()
  "Re-sending the SAME form replaces just that form's result."
  (prologos-repl-test--in-buffer "def a := 1\ndef b := 2"
    (let ((end (save-excursion (goto-char (point-min))
                               (end-of-line) (point))))
      (prologos--display-inline-result "stale" end 1 end)
      (prologos--display-inline-result "1 : Int" end 1 end)
      (should (= (length prologos--result-overlays) 1))
      (should (string-match-p "=> 1 : Int"
                              (overlay-get (car prologos--result-overlays)
                                           'after-string)))
      (prologos--clear-inline-results))))

;; ============================================================
;; Test: Overlay PERSISTENCE (results survive commands, die on edits)
;; ============================================================

(ert-deftest prologos-repl-test/result-survives-commands ()
  "A result must NOT be cleared by the next command.
The old implementation hung clearing on `pre-command-hook', so merely
moving point erased the answer.  Nothing but an edit should clear it."
  (prologos-repl-test--in-buffer "def a := 1"
    (goto-char (point-max))
    (prologos--display-inline-result "1 : Int" (point) 1 (point))
    (should (= (length prologos--result-overlays) 1))
    ;; Simulate real command activity: move around, run a command loop step.
    (goto-char (point-min))
    (forward-word)
    (run-hooks 'pre-command-hook)
    (run-hooks 'post-command-hook)
    (should (= (length prologos--result-overlays) 1))
    (prologos--clear-inline-results)))

(ert-deftest prologos-repl-test/result-cleared-on-modification ()
  "Editing the buffer clears every result, as onDidChangeTextDocument does."
  (prologos-repl-test--in-buffer "def a := 1"
    (goto-char (point-max))
    (prologos--display-inline-result "1 : Int" (point) 1 (point))
    (should (= (length prologos--result-overlays) 1))
    (insert "\ndef b := 2")
    (should (= (length prologos--result-overlays) 0))))

(ert-deftest prologos-repl-test/modification-clears-all-results ()
  "One edit clears ALL results, not just the one at the edit site."
  (prologos-repl-test--in-buffer "def a := 1\ndef b := 2"
    (let ((first-end (save-excursion (goto-char (point-min))
                                     (end-of-line) (point))))
      (prologos--display-inline-result "1 : Int" first-end 1 first-end)
      (prologos--display-inline-result "2 : Int" (point-max)
                                       (1+ first-end) (point-max))
      (should (= (length prologos--result-overlays) 2))
      ;; Edit at the END of the buffer; the result at the TOP must go too.
      (goto-char (point-max))
      (insert " ")
      (should (= (length prologos--result-overlays) 0)))))

(ert-deftest prologos-repl-test/result-cleared-on-keyboard-quit ()
  "C-g dismisses results without touching the text."
  (prologos-repl-test--in-buffer "def a := 1"
    (goto-char (point-max))
    (prologos--display-inline-result "1 : Int" (point) 1 (point))
    (should (= (length prologos--result-overlays) 1))
    (let ((before (buffer-string)))
      (condition-case nil (keyboard-quit) (quit nil))
      (should (= (length prologos--result-overlays) 0))
      (should (string= before (buffer-string))))))

(ert-deftest prologos-repl-test/quit-advice-is-installed ()
  "Every command in `prologos-clear-results-commands' carries the advice.
Includes ones Evil defines, which may not be loaded here -- advice-add
accepts an undefined symbol and applies when it is defined."
  (dolist (cmd prologos-clear-results-commands)
    (should (advice-member-p #'prologos--clear-results-on-quit cmd))))

(ert-deftest prologos-repl-test/quit-clear-is-buffer-local ()
  "A quit in one buffer must not wipe another buffer's results.
Aborting an unrelated prompt should leave results you are still reading."
  (let ((other (generate-new-buffer "*prologos-other*")))
    (unwind-protect
        (progn
          (with-current-buffer other
            (insert "def b := 2")
            (prologos-mode)
            (prologos--display-inline-result "2 : Int" (point-max)
                                             1 (point-max))
            (should (= (length prologos--result-overlays) 1)))
          ;; Quit from a DIFFERENT buffer.
          (with-temp-buffer (condition-case nil (keyboard-quit) (quit nil)))
          (with-current-buffer other
            (should (= (length prologos--result-overlays) 1))))
      (kill-buffer other))))

(ert-deftest prologos-repl-test/unload-function-strips-advice ()
  "Unloading must remove the advice, or every C-g in the session breaks.

`unload-feature' unbinds `prologos--clear-results-on-quit' but leaves
advice installed on `keyboard-quit', so a stale advice reference makes
C-g fail with `void-function' EVERYWHERE -- not just in Prologos
buffers.  The reload script unloads this feature, so this is the live
path, not a hypothetical one."
  (should (fboundp 'prologos-repl-unload-function))
  (let ((saved prologos--advised-quit-commands))
    (unwind-protect
        (progn
          (should (advice-member-p #'prologos--clear-results-on-quit
                                   'keyboard-quit))
          (prologos-repl-unload-function)
          (should-not (advice-member-p #'prologos--clear-results-on-quit
                                       'keyboard-quit))
          ;; C-g must still behave like a plain quit, not error.
          (should (eq 'quit (condition-case nil
                                (progn (keyboard-quit) 'no-signal)
                              (quit 'quit)
                              (error 'error)))))
      ;; Restore for the rest of the suite.
      (setq prologos--advised-quit-commands saved)
      (prologos-refresh-clear-results-advice))))

(ert-deftest prologos-repl-test/clear-results-is-a-command ()
  "prologos-clear-results dismisses results without touching the text."
  (prologos-repl-test--in-buffer "def a := 1"
    (goto-char (point-max))
    (prologos--display-inline-result "1 : Int" (point) 1 (point))
    (let ((before (buffer-string)))
      (prologos-clear-results)
      (should (= (length prologos--result-overlays) 0))
      (should (string= before (buffer-string))))))

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
;; Test: Top-level form detection (layout-based)
;; ============================================================
;;
;; These mirror getTopLevelFormRange in src/forms.ts.  If the two ever
;; disagree, C-x C-e and cmd+enter evaluate different text.

(defun prologos-repl-test--form-at (content line col)
  "Return the form text found with point on LINE (1-based) at COL."
  (let ((buf (generate-new-buffer "*prologos-form-test*")))
    (unwind-protect
        (with-current-buffer buf
          (insert content)
          (prologos-mode)
          (goto-char (point-min))
          (forward-line (1- line))
          (forward-char col)
          (let ((b (prologos--top-level-form-bounds)))
            (and b (buffer-substring-no-properties (car b) (cdr b)))))
      (kill-buffer buf))))

(ert-deftest prologos-repl-test/form-bounds-single-line ()
  "A one-line top-level form is found from anywhere on that line."
  (let ((src "def a := 1\ndef b := 2\n"))
    (should (string= (prologos-repl-test--form-at src 1 0) "def a := 1"))
    (should (string= (prologos-repl-test--form-at src 1 5) "def a := 1"))
    (should (string= (prologos-repl-test--form-at src 2 0) "def b := 2"))))

(ert-deftest prologos-repl-test/form-bounds-bare-expression ()
  "A bare expression is a form.
The retired defun-based command could not see this at all -- its regexp
only matched def/defn/spec/... keywords."
  (should (string= (prologos-repl-test--form-at "[+ 1 2]\n" 1 3)
                   "[+ 1 2]")))

(ert-deftest prologos-repl-test/form-bounds-from-continuation-line ()
  "Point on an indented continuation line finds the whole form."
  (let ((src "defn nth [n xs]\n  | n nil -> none\n  | n x -> x\n\ndef after := 1\n"))
    ;; from the middle clause
    (should (string= (prologos-repl-test--form-at src 2 4)
                     "defn nth [n xs]\n  | n nil -> none\n  | n x -> x"))
    ;; and from the header
    (should (string= (prologos-repl-test--form-at src 1 0)
                     "defn nth [n xs]\n  | n nil -> none\n  | n x -> x"))))

(ert-deftest prologos-repl-test/form-bounds-blank-line-inside-form ()
  "A blank line stays INSIDE the form when the next non-blank is indented."
  (let ((src "defn f [x]\n  let y 1\n\n  [+ x y]\n\ndef after := 1\n"))
    (should (string= (prologos-repl-test--form-at src 1 0)
                     "defn f [x]\n  let y 1\n\n  [+ x y]"))))

(ert-deftest prologos-repl-test/form-bounds-stops-at-next-top-level ()
  "A column-0 line ends the previous form, with no blank line needed."
  (let ((src "def a := 1\ndef b := 2\n"))
    (should (string= (prologos-repl-test--form-at src 1 0) "def a := 1"))))

(ert-deftest prologos-repl-test/form-bounds-stops-at-col0-comment ()
  "A column-0 comment is a boundary, not a continuation."
  (let ((src "def a := 1\n;; a note\ndef b := 2\n"))
    (should (string= (prologos-repl-test--form-at src 1 0) "def a := 1"))))

(ert-deftest prologos-repl-test/form-bounds-trims-trailing-blanks ()
  "Trailing blank lines are not part of the form."
  (let ((src "defn f [x]\n  [+ x 1]\n\n\ndef after := 1\n"))
    (should (string= (prologos-repl-test--form-at src 1 0)
                     "defn f [x]\n  [+ x 1]"))))

(ert-deftest prologos-repl-test/form-bounds-empty-buffer ()
  "An empty buffer has no form -- bounds are nil, and send-form errors."
  (should (null (prologos-repl-test--form-at "" 1 0)))
  (prologos-repl-test--in-buffer ""
    (should-error (prologos-send-form) :type 'user-error)))

;; ============================================================
;; Test: Keymap bindings — prologos-mode
;; ============================================================

(ert-deftest prologos-repl-test/mode-map-repl-binding ()
  "C-c C-z should be bound to prologos-repl in prologos-mode-map."
  (should (eq (lookup-key prologos-mode-map (kbd "C-c C-z"))
              'prologos-repl)))

(ert-deftest prologos-repl-test/mode-map-send-form ()
  "C-x C-e should be bound to prologos-send-form."
  (should (eq (lookup-key prologos-mode-map (kbd "C-x C-e"))
              'prologos-send-form)))

(ert-deftest prologos-repl-test/mode-map-send-form-meta-return ()
  "M-<return> should also send the form.
The Command key is bound to Meta in this configuration, so this is the
same physical gesture as cmd+enter in the VS Code extension."
  (should (eq (lookup-key prologos-mode-map (kbd "M-<return>"))
              'prologos-send-form)))

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

(ert-deftest prologos-repl-test/mode-map-eval-defun-retired ()
  "C-c C-d must be UNBOUND -- prologos-eval-defun-at-point was retired.
Pinned so a copy-paste of the old keymap cannot quietly bring it back."
  (should (null (lookup-key prologos-mode-map (kbd "C-c C-d"))))
  (should-not (fboundp 'prologos-eval-defun-at-point)))

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

(ert-deftest prologos-repl-test/ts-mode-map-send-form ()
  "C-x C-e should be bound in prologos-ts-mode-map."
  (skip-unless (boundp 'prologos-ts-mode-map))
  (should (eq (lookup-key prologos-ts-mode-map (kbd "C-x C-e"))
              'prologos-send-form)))

(ert-deftest prologos-repl-test/ts-mode-map-send-form-meta-return ()
  "M-<return> should also send the form in prologos-ts-mode-map.
Both keymaps must agree; they drifted once already."
  (skip-unless (boundp 'prologos-ts-mode-map))
  (should (eq (lookup-key prologos-ts-mode-map (kbd "M-<return>"))
              'prologos-send-form)))

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

(ert-deftest prologos-repl-test/ts-mode-map-eval-defun-retired ()
  "C-c C-d must be UNBOUND in prologos-ts-mode-map too."
  (skip-unless (boundp 'prologos-ts-mode-map))
  (should (null (lookup-key prologos-ts-mode-map (kbd "C-c C-d")))))

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
  (should (commandp 'prologos-send-form))
  (should (commandp 'prologos-eval-region))
  (should (commandp 'prologos-eval-buffer))
  (should (commandp 'prologos-load-file))
  (should (commandp 'prologos-clear-results))
  (should (commandp 'prologos-repl-clear)))

;; ============================================================
;; Test: Integration — needs a live Racket + the prologos collection
;; ============================================================

(defun prologos-repl-test--kill-repl ()
  "Kill the REPL buffer if one exists, without prompting."
  (when (get-buffer prologos-repl-buffer-name)
    (let ((kill-buffer-query-functions nil))
      (kill-buffer prologos-repl-buffer-name))))

(ert-deftest prologos-repl-test/cold-start-result-is-not-the-banner ()
  "The FIRST evaluation must return its own result, not the startup banner.

Regression pin.  `make-comint-in-buffer' returns before the process has
printed anything, so the banner used to still be in flight when the
first callback was enqueued: the output filter matched the banner's own
trailing prompt, popped that callback, and delivered the version string
as the result -- while the real result arrived later to an empty queue
and was silently dropped.  Only the COLD path shows it, which is why it
survived; and persistent overlays made it stay on screen.
`prologos-repl-ensure' now waits for the first prompt."
  (skip-unless (prologos-repl-test--racket-available-p))
  (unwind-protect
      (progn
        (prologos-repl-test--kill-repl)   ; force the cold path
        (prologos-repl-test--in-buffer "def cold := 1"
          (goto-char (point-max))
          (prologos-send-form)
          (let ((n 0))
            (while (and (null prologos--result-overlays) (< n 240))
              (accept-process-output nil 0.5)
              (setq n (1+ n))))
          (should prologos--result-overlays)
          (let ((text (substring-no-properties
                       (overlay-get (car prologos--result-overlays)
                                    'after-string))))
            (should-not (string-match-p "Prologos v" text))
            (should-not (string-match-p ":quit to exit" text))
            (should (string-match-p "cold" text)))))
    (prologos-repl-test--kill-repl)))

;; ============================================================
;; Provide
;; ============================================================

(provide 'prologos-repl-test)

;;; prologos-repl-test.el ends here
