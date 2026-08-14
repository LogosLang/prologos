;;; prologos-repl.el --- REPL integration for Prologos -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Prologos Contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "28.1"))
;; Keywords: languages
;; URL: https://github.com/prologos-lang/prologos

;;; Commentary:

;; Comint-based REPL integration for Prologos.  Provides:
;; - Start/switch to REPL (C-c C-z)
;; - Send the top-level form at point (C-x C-e, M-<return>)
;; - Evaluate region (C-c C-r)
;; - Evaluate buffer (C-c C-k)
;; - Load file into REPL (C-c C-l)
;;
;; Inline result overlays appear at the end of the evaluated form and
;; PERSIST until the buffer is modified.
;;
;; Both behaviours deliberately track the VS Code extension so the two
;; editors agree:
;;
;;   `prologos-send-form' <-> `prologos.evalTopLevel' (cmd+enter).  The
;;   form is located by LAYOUT, not by sexp motion -- see
;;   `prologos--top-level-form-bounds', which mirrors
;;   `getTopLevelFormRange' in src/forms.ts.
;;
;;   Overlay lifetime <-> DecorationsManager in src/decorations.ts, which
;;   clears on `onDidChangeTextDocument' rather than on a timer or the
;;   next command.  A result describes the text that produced it, so
;;   editing invalidates it and nothing else does.

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

(defcustom prologos-repl-startup-timeout 30
  "Seconds to wait for the REPL's startup banner before giving up.
A cold REPL loads the prelude, so the first prompt can take a while."
  :type 'number
  :group 'prologos-repl)

(defcustom prologos-clear-results-commands
  '(keyboard-quit
    minibuffer-keyboard-quit
    keyboard-escape-quit
    evil-force-normal-state
    evil-normal-state
    evil-escape)
  "Commands that also dismiss inline results.
Editing always clears results; these are the additional \"done looking
at that\" gestures -- C-g, and ESC under Evil.

Advice is attached to every symbol listed, INCLUDING ones not defined
yet, so Evil need not be loaded first.  If ESC runs something else in
your configuration, add it here and call
`prologos-refresh-clear-results-advice'."
  :type '(repeat symbol)
  :group 'prologos-repl)

(defcustom prologos-inline-result-timeout nil
  "Seconds before inline result overlays are auto-removed.
The default nil keeps a result visible until the buffer is modified,
matching the VS Code extension.  Set a number to also expire results on
a timer."
  :type '(choice (const :tag "Keep until the buffer is modified" nil)
                 (integer :tag "Seconds"))
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
  ;; Prompt: "> " for main prompt, "  " for WS continuation
  (setq-local comint-prompt-regexp "^\\(?:> \\|  \\)")
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
;; Session state
;; ============================================================
;;
;; Declared here, ahead of their first use in `prologos--wait-for-prompt'
;; below.  Defining them further down compiles with an "assignment to
;; free variable" warning.

(defvar-local prologos--callback-queue nil
  "Queue of (CALLBACK . SOURCE-BUFFER) pairs awaiting REPL output.
Each entry is a cons cell where CALLBACK is a function accepting
one string argument (the REPL response) and SOURCE-BUFFER is the
buffer that initiated the evaluation.")

(defvar-local prologos--pending-output ""
  "Accumulated output from the REPL between prompts.")

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

(defun prologos--wait-for-prompt (proc)
  "Block until PROC has printed a prompt, or the startup timeout elapses.
Return non-nil if the prompt arrived."
  (with-current-buffer (process-buffer proc)
    (let ((deadline (+ (float-time) prologos-repl-startup-timeout))
          (seen nil))
      (while (and (not seen) (< (float-time) deadline))
        (setq seen (equal "> " (buffer-substring-no-properties
                                (max (point-min) (- (point-max) 2))
                                (point-max))))
        (unless seen (accept-process-output proc 0.1)))
      ;; Whatever the banner left behind is not anybody's result.
      (setq prologos--pending-output "")
      seen)))

(defun prologos-repl-ensure ()
  "Ensure a Prologos REPL is running.  Return the process.
If no REPL is running, start one without switching windows and wait for
its startup banner.

The wait is load-bearing, not politeness.  `make-comint-in-buffer'
returns before the process has printed anything, so without it the
banner is still in flight when the caller enqueues its callback: the
output filter then matches the banner's own trailing prompt, pops that
callback, and hands the BANNER back as the evaluation result -- while
the real result arrives later to an empty queue and is discarded.  The
symptom is a first evaluation that answers with the version string."
  (let ((buf (get-buffer prologos-repl-buffer-name)))
    (unless (and buf (comint-check-proc buf))
      (save-window-excursion (prologos-repl))
      (let ((proc (get-buffer-process prologos-repl-buffer-name)))
        (when proc (prologos--wait-for-prompt proc))))
    (get-buffer-process prologos-repl-buffer-name)))

;; ============================================================
;; Output filter + callback queue (async evaluation)
;; ============================================================

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
           ;; Strip leading prompt echo if present (main or continuation)
           (response (if (string-prefix-p "> " response)
                         (substring response 2)
                       response))
           ;; Strip WS continuation prompt artifacts
           (response (replace-regexp-in-string "^  \n" "" response))
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
    ;; Send the expression followed by blank line (WS mode termination)
    (comint-send-string proc (concat expr "\n\n"))))

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
;; Top-level form detection (layout-based)
;; ============================================================
;;
;; Prologos WS mode is layout-sensitive: a top-level form starts at
;; column 0 and owns the indented lines beneath it.  Sexp motion is the
;; wrong tool -- `backward-sexp' sees one bracket group, not the form,
;; and the keyword-based defun regexp cannot see a bare `[+ 1 2]' at
;; all.  These three predicates mirror `isTopLevelStart' /
;; `isContinuationLine' / `getTopLevelFormRange' in src/forms.ts so that
;; C-x C-e and cmd+enter select the same text.

(defun prologos--line-blank-p ()
  "Non-nil if the current line is empty or whitespace-only."
  (save-excursion
    (beginning-of-line)
    (looking-at-p "[[:space:]]*$")))

(defun prologos--top-level-start-p ()
  "Non-nil if the current line opens a top-level form.
That is: non-blank, beginning at column 0, and not a comment-only line."
  (save-excursion
    (beginning-of-line)
    (and (not (looking-at-p "[[:space:]]*$"))
         (not (looking-at-p "[[:space:]]"))
         (not (looking-at-p ";")))))

(defun prologos--continuation-p ()
  "Non-nil if the current line continues the form above it.
That is: non-blank and indented.  A column-0 line -- code or comment --
is a form boundary, never a continuation."
  (save-excursion
    (beginning-of-line)
    (and (not (looking-at-p "[[:space:]]*$"))
         (looking-at-p "[[:space:]]"))))

(defun prologos--goto-line-1 (n)
  "Move to the beginning of line N (1-based).  Internal helper."
  (goto-char (point-min))
  (forward-line (1- n)))

(defun prologos--top-level-form-bounds ()
  "Return (BEG . END) buffer positions of the top-level form at point.
Return nil when there is no form (empty buffer, or a buffer of blanks).

Walks UP to the column-0 line that opens the form, then DOWN across its
indented continuation lines.  An interior blank line stays inside the
form when the next non-blank line is still indented; a blank followed by
column-0 content ends it.  Trailing blank lines are trimmed."
  (save-excursion
    (let ((max-line (line-number-at-pos (point-max)))
          (start (line-number-at-pos))
          (end nil))
      ;; --- walk UP to the opening column-0 line ---
      (unless (progn (prologos--goto-line-1 start)
                     (prologos--top-level-start-p))
        (while (and (> start 1)
                    (progn (setq start (1- start))
                           (prologos--goto-line-1 start)
                           (not (prologos--top-level-start-p))))))
      ;; --- walk DOWN across continuation lines ---
      (setq end start)
      (let ((i (1+ start))
            (stop nil))
        (while (and (not stop) (<= i max-line))
          (prologos--goto-line-1 i)
          (cond
           ((prologos--line-blank-p)
            ;; Interior blank only if the next non-blank line is indented.
            (let ((j (1+ i)))
              (while (and (<= j max-line)
                          (progn (prologos--goto-line-1 j)
                                 (prologos--line-blank-p)))
                (setq j (1+ j)))
              (if (and (<= j max-line)
                       (progn (prologos--goto-line-1 j)
                              (prologos--continuation-p)))
                  (setq end i)
                (setq stop t))))
           ((prologos--continuation-p) (setq end i))
           (t (setq stop t)))
          (setq i (1+ i))))
      ;; --- trim trailing blanks ---
      (while (and (> end start)
                  (progn (prologos--goto-line-1 end)
                         (prologos--line-blank-p)))
        (setq end (1- end)))
      ;; --- positions ---
      (prologos--goto-line-1 start)
      (let ((beg (point)))
        (prologos--goto-line-1 end)
        (end-of-line)
        (and (< beg (point)) (cons beg (point)))))))

;; ============================================================
;; Inline result overlays
;; ============================================================

(defvar-local prologos--result-overlays nil
  "List of active inline result overlays in the current buffer.")

(defun prologos--ranges-overlap-p (a-beg a-end b-beg b-end)
  "Non-nil if A-BEG..A-END and B-BEG..B-END overlap.
A zero-width range is treated as a point, so it overlaps any range it
touches; that keeps region evaluations, which carry no form bounds,
from stacking duplicate overlays at one spot."
  (if (or (= a-beg a-end) (= b-beg b-end))
      (and (<= b-beg a-end) (<= a-beg b-end))
    (and (< a-beg b-end) (< b-beg a-end))))

(defun prologos--clear-overlapping-results (beg end)
  "Delete result overlays whose source form overlaps BEG..END.
Results for other forms are left alone, so a buffer can show several at
once -- the same rule the VS Code DecorationsManager applies when it
filters entries by `range.intersection'."
  (dolist (ov (copy-sequence prologos--result-overlays))
    (let ((obeg (overlay-get ov 'prologos-form-beg))
          (oend (overlay-get ov 'prologos-form-end)))
      (when (and obeg oend
                 (prologos--ranges-overlap-p beg end obeg oend))
        (when (overlay-buffer ov) (delete-overlay ov))
        (setq prologos--result-overlays
              (delq ov prologos--result-overlays))))))

(defun prologos--display-inline-result (result pos &optional form-beg form-end)
  "Display RESULT as an inline overlay at POS.
The overlay shows \" => RESULT\" after POS.  FORM-BEG and FORM-END record
which form produced it, so a later result for an overlapping form
replaces this one while results for other forms persist alongside.

The overlay lives until the buffer is modified.  It is NOT cleared by
the next command -- moving point, scrolling and switching windows all
leave it in place, so a screenful of results stays readable.  Set
`prologos-inline-result-timeout' to also expire it on a timer."
  (let ((beg (or form-beg pos))
        (end (or form-end pos))
        (buf (current-buffer)))
    (prologos--clear-overlapping-results beg end)
    (let ((ov (make-overlay pos pos nil t t)))
      (overlay-put ov 'after-string
                   (propertize (format " => %s" result)
                               'face 'prologos-result-overlay-face))
      (overlay-put ov 'prologos-result t)
      (overlay-put ov 'prologos-form-beg beg)
      (overlay-put ov 'prologos-form-end end)
      (push ov prologos--result-overlays)
      ;; Optional timer expiry.  The timer fires in whatever buffer is
      ;; current, so the list surgery has to be done in OURS.
      (when prologos-inline-result-timeout
        (run-at-time prologos-inline-result-timeout nil
                     (lambda ()
                       (when (overlay-buffer ov)
                         (delete-overlay ov))
                       (when (buffer-live-p buf)
                         (with-current-buffer buf
                           (setq prologos--result-overlays
                                 (delq ov prologos--result-overlays)))))))
      ;; Clear on the first modification of the buffer.
      (add-hook 'after-change-functions
                #'prologos--clear-inline-results-on-change nil t))))

(defun prologos--clear-inline-results-on-change (&rest _)
  "Clear inline results because the buffer changed.
Mirrors the VS Code extension's `onDidChangeTextDocument' handler: a
result describes the text that produced it, so any edit invalidates
every result in the buffer.  Arguments from `after-change-functions'
are ignored -- the rule is all-or-nothing, exactly as it is there."
  (prologos--clear-inline-results))

(defun prologos--clear-inline-results ()
  "Remove all inline result overlays from the current buffer."
  (dolist (ov prologos--result-overlays)
    (when (overlay-buffer ov)
      (delete-overlay ov)))
  (setq prologos--result-overlays nil)
  (remove-hook 'after-change-functions
               #'prologos--clear-inline-results-on-change t))

(defun prologos-clear-results ()
  "Remove all inline result overlays from the current buffer.
Results persist until an edit, so this is the way to dismiss them
without touching the text."
  (interactive)
  (prologos--clear-inline-results))

;; ------------------------------------------------------------
;; Dismiss on a quit gesture (C-g, ESC)
;; ------------------------------------------------------------
;;
;; ADVICE, not `post-command-hook', and the choice is forced: C-g runs
;; `keyboard-quit', which SIGNALS.  The signal unwinds past the command
;; loop's post-command-hook call, so a hook-based check of `this-command'
;; is not reliably reached.  Advice runs before the signal, always.

(defvar prologos--advised-quit-commands nil
  "Commands currently carrying `prologos--clear-results-on-quit'.")

(defun prologos--clear-results-on-quit (&rest _)
  "Advice: dismiss THIS buffer's inline results on a quit gesture.
Only the current buffer is touched, so aborting an unrelated minibuffer
prompt with C-g does not wipe results you are still reading elsewhere."
  (when prologos--result-overlays
    (prologos--clear-inline-results)))

(defun prologos-refresh-clear-results-advice ()
  "Sync quit-clearing advice with `prologos-clear-results-commands'.
Call after customizing that list."
  (interactive)
  (dolist (cmd prologos--advised-quit-commands)
    (unless (memq cmd prologos-clear-results-commands)
      (advice-remove cmd #'prologos--clear-results-on-quit)))
  (setq prologos--advised-quit-commands nil)
  (dolist (cmd prologos-clear-results-commands)
    ;; advice-add accepts a symbol that is not fbound yet; the advice
    ;; takes effect if and when the command is defined.
    (unless (advice-member-p #'prologos--clear-results-on-quit cmd)
      (advice-add cmd :before #'prologos--clear-results-on-quit))
    (push cmd prologos--advised-quit-commands)))

(prologos-refresh-clear-results-advice)

(defun prologos-repl-unload-function ()
  "Strip quit-clearing advice when this feature is unloaded.

NOT optional.  `unload-feature' unbinds
`prologos--clear-results-on-quit' but leaves the advice installed on
`keyboard-quit', so without this hook EVERY C-g in the session -- in any
buffer, Prologos or not -- fails with `void-function'.  The reload
script unloads this feature, which is exactly when it would bite.

Returning nil lets `unload-feature' proceed with normal unloading."
  (dolist (cmd prologos--advised-quit-commands)
    (advice-remove cmd #'prologos--clear-results-on-quit))
  (setq prologos--advised-quit-commands nil)
  nil)

;; ============================================================
;; Evaluation commands
;; ============================================================

(defun prologos-send-form ()
  "Send the top-level form at point to the REPL; show the result inline.

The form is chosen by LAYOUT -- the enclosing column-0 line plus the
indented lines beneath it -- which is what `prologos.evalTopLevel'
\(cmd+enter) does in the VS Code extension.  Point may sit anywhere
inside the form, including on a continuation line.

The result appears at the end of the form and stays there until the
buffer is modified.  Results for different forms accumulate; re-sending
a form replaces just its own result."
  (interactive)
  (let ((bounds (prologos--top-level-form-bounds)))
    (unless bounds
      (user-error "No Prologos form at point"))
    (let* ((beg (car bounds))
           (end (cdr bounds))
           (code (buffer-substring-no-properties beg end)))
      (prologos--send-eval code
        (lambda (output)
          (let ((result (prologos--parse-result output)))
            (when (and result (not (string-empty-p result)))
              (prologos--display-inline-result result end beg end))))))))

(define-obsolete-function-alias 'prologos-eval-last-sexp
  #'prologos-send-form "0.2.0")

(defun prologos-eval-region (beg end)
  "Evaluate the region from BEG to END and display result inline."
  (interactive "r")
  (let ((code (buffer-substring-no-properties beg end)))
    (prologos--send-eval code
      (lambda (output)
        (let ((result (prologos--parse-result output)))
          (when (and result (not (string-empty-p result)))
            (prologos--display-inline-result result end beg end)))))))

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

;; `prologos-eval-defun-at-point' (C-c C-d) was RETIRED in 0.2.0.  It
;; duplicated `prologos-send-form' but detected the form with
;; `prologos-beginning-of-defun' (a def/defn/spec/... keyword regexp,
;; blind to a bare `[+ 1 2]') and `forward-sexp' (which ends a
;; multi-line form at its first bracket group).  Use
;; `prologos-send-form'; C-c C-d is now unbound.

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
