;;; prologos-repl.el --- REPL integration for Prologos -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Prologos Contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: languages
;; URL: https://github.com/prologos-lang/prologos

;;; Commentary:

;; Comint-based REPL integration for Prologos.  Provides:
;; - Start/switch to REPL (C-c C-z)
;; - Evaluate last sexp with inline result overlay (C-x C-e)
;; - Evaluate region (C-c C-r)
;; - Evaluate buffer (C-c C-k)
;; - Load file into REPL (C-c C-l)
;; - Evaluate defun at point (C-c C-d)
;;
;; Inline result overlays (CIDER-style) appear at the evaluation point
;; and auto-clear on the next command or after a configurable timeout.

;;; Code:

(require 'comint)
(require 'seq)

;; Forward declarations to avoid byte-compile warnings
(defvar prologos-mode-syntax-table)
(defvar prologos-font-lock-keywords)

;; ============================================================
;; Customization
;; ============================================================

(defgroup prologos-repl nil
  "REPL integration for Prologos."
  :group 'prologos
  :prefix "prologos-")

(defcustom prologos-program "racket"
  "Path to the Racket executable."
  :type 'string
  :group 'prologos-repl)

(defcustom prologos-program-args '("-l" "prologos/repl")
  "Arguments passed to Racket to start the Prologos REPL."
  :type '(repeat string)
  :group 'prologos-repl)

(defcustom prologos-repl-buffer-name "*prologos-repl*"
  "Name of the Prologos REPL buffer."
  :type 'string
  :group 'prologos-repl)

(defcustom prologos-inline-result-timeout 10
  "Seconds before inline result overlays are auto-removed.
Set to nil to keep overlays until the next command."
  :type '(choice integer (const :tag "Keep until next command" nil))
  :group 'prologos-repl)

;; ============================================================
;; Faces
;; ============================================================

(defface prologos-result-overlay-face
  '((t :inherit font-lock-comment-face :slant italic))
  "Face for inline evaluation result overlays."
  :group 'prologos-repl)

;; ============================================================
;; REPL mode (derived from comint-mode)
;; ============================================================

(define-derived-mode prologos-repl-mode comint-mode "Prologos-REPL"
  "Major mode for the Prologos REPL.
Derived from `comint-mode' with Prologos-specific prompt handling
and syntax highlighting."
  :syntax-table (if (boundp 'prologos-mode-syntax-table)
                    prologos-mode-syntax-table
                  (make-syntax-table))
  ;; Prompt: "> " (verified from repl.rkt line 43)
  (setq-local comint-prompt-regexp "^> ")
  (setq-local comint-prompt-read-only t)
  (setq-local comint-input-ignoredups t)
  (setq-local comint-input-ring-size 500)
  (setq-local comint-process-echoes nil)
  ;; Font-lock (reuse prologos keywords if available)
  (setq-local font-lock-defaults
              (if (boundp 'prologos-font-lock-keywords)
                  '(prologos-font-lock-keywords nil nil)
                nil))
  ;; Install our output filter for async callback dispatch
  (add-hook 'comint-output-filter-functions
            #'prologos--output-filter nil t))

;; ============================================================
;; REPL process management
;; ============================================================

(defun prologos-repl ()
  "Start or switch to the Prologos REPL.
If a REPL process is already running, switch to its buffer.
Otherwise, start a new REPL process."
  (interactive)
  (let ((buf (get-buffer prologos-repl-buffer-name)))
    (if (and buf (comint-check-proc buf))
        (pop-to-buffer buf)
      (let ((new-buf (apply #'make-comint-in-buffer
                            "prologos"
                            prologos-repl-buffer-name
                            prologos-program nil
                            prologos-program-args)))
        (with-current-buffer new-buf
          (prologos-repl-mode))
        (pop-to-buffer new-buf)))))

(defun prologos-repl-ensure ()
  "Ensure a Prologos REPL is running.  Return the process.
If no REPL is running, start one without switching windows."
  (let ((buf (get-buffer prologos-repl-buffer-name)))
    (unless (and buf (comint-check-proc buf))
      (save-window-excursion (prologos-repl)))
    (get-buffer-process prologos-repl-buffer-name)))

;; ============================================================
;; Output filter + callback queue (async evaluation)
;; ============================================================

(defvar-local prologos--callback-queue nil
  "Queue of (CALLBACK . SOURCE-BUFFER) pairs awaiting REPL output.
Each entry is a cons cell where CALLBACK is a function accepting
one string argument (the REPL response) and SOURCE-BUFFER is the
buffer that initiated the evaluation.")

(defvar-local prologos--pending-output ""
  "Accumulated output from the REPL between prompts.")

(defun prologos--output-filter (output)
  "Comint output filter: accumulate OUTPUT, dispatch on prompt.
When a complete response is detected (output ending with the REPL
prompt), pop the next callback from the queue and invoke it with
the cleaned response string."
  (setq prologos--pending-output
        (concat prologos--pending-output output))
  ;; Check if we have a complete response (prompt appears at end of output).
  ;; The REPL prints "\n> " after each result.
  (when (string-match "\n> \\'" prologos--pending-output)
    (let* ((raw prologos--pending-output)
           ;; Strip the trailing prompt
           (response (substring raw 0 (match-beginning 0)))
           ;; Strip leading prompt echo if present
           (response (if (string-prefix-p "> " response)
                         (substring response 2)
                       response))
           (response (string-trim response))
           (entry (pop prologos--callback-queue)))
      (setq prologos--pending-output "")
      (when entry
        (let ((callback (car entry))
              (src-buf  (cdr entry)))
          (when (and callback (buffer-live-p src-buf))
            (with-current-buffer src-buf
              (funcall callback response))))))))

;; ============================================================
;; Send expression to REPL
;; ============================================================

(defun prologos--send-eval (expr callback)
  "Send EXPR to the REPL for evaluation.
When the response arrives, call CALLBACK with the result string.
CALLBACK is invoked in the source buffer that called this function."
  (let ((proc (prologos-repl-ensure))
        (src-buf (current-buffer)))
    (with-current-buffer (process-buffer proc)
      ;; Reset pending output for clean capture
      (setq prologos--pending-output "")
      ;; Enqueue callback (FIFO — append to end)
      (setq prologos--callback-queue
            (append prologos--callback-queue
                    (list (cons callback src-buf)))))
    ;; Send the expression to the REPL process
    (comint-send-string proc (concat expr "\n"))))

;; ============================================================
;; Result parsing
;; ============================================================

(defun prologos--parse-result (output)
  "Parse REPL OUTPUT into a display-friendly result string.
Filters out prompt echoes and trims whitespace."
  (let ((lines (split-string output "\n" t)))
    ;; Filter out prompt-prefixed lines and blank lines
    (let ((result-lines
           (seq-filter (lambda (line)
                         (and (not (string-prefix-p "> " line))
                              (not (string-blank-p line))))
                       lines)))
      (string-join (mapcar #'string-trim result-lines) "\n"))))

;; ============================================================
;; Inline result overlays (CIDER-style)
;; ============================================================

(defvar-local prologos--result-overlays nil
  "List of active inline result overlays in the current buffer.")

(defun prologos--display-inline-result (result pos)
  "Display RESULT as an inline overlay at POS.
The overlay shows \" => RESULT\" after the evaluation point.
It is removed on the next command or after `prologos-inline-result-timeout'."
  ;; Clear any existing result overlays first
  (prologos--clear-inline-results)
  (let ((ov (make-overlay pos pos nil t t)))
    (overlay-put ov 'after-string
                 (propertize (format " => %s" result)
                             'face 'prologos-result-overlay-face))
    (overlay-put ov 'prologos-result t)
    (push ov prologos--result-overlays)
    ;; Auto-remove after timeout (if configured)
    (when prologos-inline-result-timeout
      (run-at-time prologos-inline-result-timeout nil
                   (lambda ()
                     (when (overlay-buffer ov)
                       (delete-overlay ov)
                       (setq prologos--result-overlays
                             (delq ov prologos--result-overlays))))))
    ;; Remove on next user command
    (add-hook 'pre-command-hook #'prologos--clear-inline-results nil t)))

(defun prologos--clear-inline-results ()
  "Remove all inline result overlays from the current buffer."
  (dolist (ov prologos--result-overlays)
    (when (overlay-buffer ov)
      (delete-overlay ov)))
  (setq prologos--result-overlays nil)
  (remove-hook 'pre-command-hook #'prologos--clear-inline-results t))

;; ============================================================
;; Evaluation commands
;; ============================================================

(defun prologos-eval-last-sexp ()
  "Evaluate the S-expression before point and display result inline.
The result appears as an overlay at point (CIDER-style)."
  (interactive)
  (let* ((end (point))
         (beg (save-excursion (backward-sexp) (point)))
         (sexp (buffer-substring-no-properties beg end))
         (display-pos end))
    (prologos--send-eval sexp
      (lambda (output)
        (let ((result (prologos--parse-result output)))
          (when (and result (not (string-empty-p result)))
            (prologos--display-inline-result result display-pos)))))))

(defun prologos-eval-region (beg end)
  "Evaluate the region from BEG to END and display result inline."
  (interactive "r")
  (let ((code (buffer-substring-no-properties beg end))
        (display-pos end))
    (prologos--send-eval code
      (lambda (output)
        (let ((result (prologos--parse-result output)))
          (when (and result (not (string-empty-p result)))
            (prologos--display-inline-result result display-pos)))))))

(defun prologos-eval-buffer ()
  "Evaluate the entire buffer in the REPL.
Saves to a temporary file and uses :load for reliable multi-form processing.
Results are displayed in the echo area."
  (interactive)
  (let* ((tmp (make-temp-file "prologos-eval-" nil ".prologos"))
         (code (buffer-substring-no-properties (point-min) (point-max))))
    (write-region code nil tmp nil 'silent)
    (prologos--send-eval (format ":load \"%s\"" tmp)
      (lambda (output)
        (ignore-errors (delete-file tmp))
        (let ((result (prologos--parse-result output)))
          (message "Buffer evaluated: %s"
                   (or result "(no output)")))))))

(defun prologos-load-file ()
  "Load the current file into the REPL using the :load command.
Saves the buffer before loading."
  (interactive)
  (unless (buffer-file-name)
    (user-error "Buffer is not visiting a file"))
  (save-buffer)
  (let ((cmd (format ":load \"%s\"" (buffer-file-name))))
    (prologos--send-eval cmd
      (lambda (output)
        (let ((result (prologos--parse-result output)))
          (message "File loaded: %s"
                   (or result "(no output)")))))))

(defun prologos-eval-defun-at-point ()
  "Evaluate the top-level form at point and display result inline."
  (interactive)
  (save-excursion
    (end-of-defun)
    (let ((end (point)))
      (beginning-of-defun)
      (let ((beg (point))
            (display-pos end))
        (let ((code (buffer-substring-no-properties beg end)))
          (prologos--send-eval code
            (lambda (output)
              (let ((result (prologos--parse-result output)))
                (when (and result (not (string-empty-p result)))
                  (prologos--display-inline-result
                   result display-pos))))))))))

(defun prologos-repl-clear ()
  "Clear the Prologos REPL buffer."
  (interactive)
  (let ((buf (get-buffer prologos-repl-buffer-name)))
    (when buf
      (with-current-buffer buf
        (comint-clear-buffer)))))

;; ============================================================
;; Provide
;; ============================================================

(provide 'prologos-repl)

;;; prologos-repl.el ends here
