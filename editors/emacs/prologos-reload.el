;;; prologos-reload.el --- Reload Prologos Emacs support in place -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Prologos Contributors
;; Keywords: languages, tools

;;; Commentary:

;; Reload the Prologos editor support after pulling new code, WITHOUT
;; restarting Emacs (which is expensive).
;;
;;   M-x load-file RET editors/emacs/prologos-reload.el RET
;;   M-x prologos-reload
;;
;; or, to keep the paste-into-*scratch* habit, evaluate:
;;
;;   (load "~/dev/projects/logos/prologos/editors/emacs/prologos-reload.el")
;;   (prologos-reload)
;;
;; Safe to re-run any time.
;;
;; WHY A NAIVE `load' IS NOT ENOUGH — three separate reasons, each of which
;; produced a confusing half-reload before it was handled here:
;;
;;   1. `defvar' and `defcustom' do NOTHING when the symbol is already bound,
;;      so a plain reload keeps the OLD keymaps and the OLD defaults.
;;   2. Buffer-local hooks survive a reload, so state installed by the previous
;;      implementation keeps running in exactly the buffers you were working in.
;;   3. A live buffer holds the old keymap OBJECT until its major mode is
;;      re-entered.
;;
;; ⚠ ONE THING THIS CANNOT FIX: a stale tree-sitter grammar.  Emacs maps a
;; grammar dylib once per session and cannot unmap it, so `install.sh' replaces
;; the file on disk while the running session keeps the parser it already
;; loaded.  The symptom is skipped highlight patterns naming node types the
;; grammar should have; the report below surfaces it, and only a fresh Emacs
;; clears it.
;;
;; Originally a personal script in ~/scripts/elisp; moved into the repo
;; 2026-08-14 at the owner's request so it tracks the code it reloads.

;;; Code:

;; Forward declarations.  This file deliberately does NOT `require' the modules
;; it reloads — requiring them would defeat the `unload-feature' step — so the
;; byte-compiler cannot see them.
(defvar prologos-ts-mode-map)
(defvar prologos-inline-result-timeout)
(defvar prologos-repl-buffer-name)
(defvar prologos-ts-font-lock-rules)
(defvar prologos-ts--skipped-patterns)
(defvar prologos--advised-quit-commands)
(defvar prologos--result-overlays)
(declare-function prologos-repl-mode "prologos-repl")
(declare-function prologos--output-filter "prologos-repl" (output))
(declare-function prologos--clear-results-on-quit "prologos-repl" (&rest args))

(defvar prologos-reload--this-dir
  (file-name-directory (or load-file-name buffer-file-name default-directory))
  "Directory of this file, captured at LOAD time.
Derived rather than hardcoded so the script follows the checkout it
ships in — including a git worktree.")

(defconst prologos-reload-modules
  '(prologos-mode
    prologos-font-lock
    prologos-indent
    prologos-repl
    prologos-surfer
    prologos-surfer-navigation
    prologos-ts-mode)
  "Modules to reload, in DEPENDENCY order.
Missing files are skipped, so the optional surfer modules cost nothing
when they are not installed.")

(defconst prologos-reload-stale-vars
  '(prologos-mode-map
    prologos-ts-mode-map
    prologos-ts--dir
    prologos-ts-highlights-file
    prologos-inline-result-timeout
    prologos-repl-startup-timeout
    prologos-clear-results-commands)
  "Variables that must be force-unbound before reloading.
`defvar'/`defcustom' skip an already-bound symbol, so without this the
keymaps and defaults silently stay at their previous values.")

(defconst prologos-reload-retired-fns
  '(prologos-eval-defun-at-point)
  "Functions retired upstream that must not linger as stale definitions.")

;;;###autoload
(defun prologos-reload ()
  "Reload Prologos Emacs support from source, in place."
  (interactive)
  (let ((dir prologos-reload--this-dir)
        (moded-buffers '())
        (loaded '()))

    ;; 1. Remember which buffers are in a Prologos mode, and where point is.
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (when (memq major-mode '(prologos-mode prologos-ts-mode))
          (push (list buf major-mode (point)) moded-buffers))))

    ;; 2. Drop global ADVICE before anything gets unbound.
    ;;    `unload-feature' unbinds the advice function but leaves the advice
    ;;    installed, so a stale reference would make every C-g in the session
    ;;    fail with `void-function' — in any buffer, Prologos or not.
    ;;    `prologos-repl-unload-function' handles this, but `unload-feature'
    ;;    is allowed to refuse, and then nothing would.
    (when (boundp 'prologos--advised-quit-commands)
      (dolist (cmd prologos--advised-quit-commands)
        (when (fboundp 'prologos--clear-results-on-quit)
          (advice-remove cmd #'prologos--clear-results-on-quit))))

    ;; 3. Scrub per-buffer state left behind by the OLD implementation.
    ;;    Buffer-local hooks survive a reload, so without this the previous
    ;;    behaviour keeps running in the buffers you were working in.
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (when (fboundp 'prologos--clear-inline-results)
          (remove-hook 'pre-command-hook #'prologos--clear-inline-results t))
        (when (fboundp 'prologos--clear-inline-results-on-change)
          (remove-hook 'after-change-functions
                       #'prologos--clear-inline-results-on-change t))
        (dolist (ov (overlays-in (point-min) (point-max)))
          (when (overlay-get ov 'prologos-result)
            (delete-overlay ov)))
        (when (boundp 'prologos--result-overlays)
          (setq prologos--result-overlays nil))))

    ;; 4. Unload every loaded feature, reverse dependency order.  The broad
    ;;    sweep; step 5 is the deterministic part.  `unload-feature' can refuse
    ;;    while a buffer is still in a mode it defines, hence FORCE + guard.
    (dolist (m (reverse prologos-reload-modules))
      (when (featurep m)
        (condition-case _ (unload-feature m t) (error nil))))

    ;; 5. Force-unbind what a reload would otherwise silently keep.
    (dolist (v prologos-reload-stale-vars) (when (boundp v) (makunbound v)))
    (dolist (f prologos-reload-retired-fns) (when (fboundp f) (fmakunbound f)))

    ;; 6. Load fresh SOURCE.  Explicit path + NOSUFFIX, so a stale .elc sitting
    ;;    next to the .el can never be picked up.
    (add-to-list 'load-path dir)
    (dolist (m prologos-reload-modules)
      (let ((src (expand-file-name (concat (symbol-name m) ".el") dir)))
        (when (file-readable-p src)
          (load src nil t t)
          (push m loaded))))

    ;; 7. Re-enter the major mode so live buffers pick up the NEW keymap:
    ;;    until then the buffer still holds the old keymap object.
    (dolist (entry moded-buffers)
      (pcase-let ((`(,buf ,mode ,pos) entry))
        (when (buffer-live-p buf)
          (with-current-buffer buf
            (funcall mode)
            (goto-char (min pos (point-max)))))))

    ;; 8. A running REPL keeps its process and its session — the Racket side is
    ;;    untouched, so whatever you have defined survives.  Two Emacs-side
    ;;    repairs are needed though: `unload-feature' drops the REPL buffer out
    ;;    of its major mode, losing the prompt regexp, read-only prompt and
    ;;    font-lock; and its output filter goes with it.
    (let ((rbuf (and (boundp 'prologos-repl-buffer-name)
                     (get-buffer prologos-repl-buffer-name))))
      (when (buffer-live-p rbuf)
        (with-current-buffer rbuf
          (unless (derived-mode-p 'prologos-repl-mode)
            (prologos-repl-mode))
          (add-hook 'comint-output-filter-functions
                    #'prologos--output-filter nil t))))

    ;; 9. Report, so a silent half-reload is visible.
    (message
     (concat "Prologos reloaded — %d module(s), %d buffer(s) re-moded\n"
             "  C-x C-e        -> %s\n"
             "  M-<return>     -> %s\n"
             "  C-c C-d        -> %s   (expect nil — retired)\n"
             "  result timeout -> %s   (expect nil — persist until edit)\n"
             "  highlight rules-> %d generated, %d skipped%s")
     (length loaded) (length moded-buffers)
     (lookup-key prologos-ts-mode-map (kbd "C-x C-e"))
     (lookup-key prologos-ts-mode-map (kbd "M-<return>"))
     (lookup-key prologos-ts-mode-map (kbd "C-c C-d"))
     prologos-inline-result-timeout
     (length prologos-ts-font-lock-rules)
     (length prologos-ts--skipped-patterns)
     (if prologos-ts--skipped-patterns
         "  ⚠ see *Warnings* — usually a stale mapped grammar, which needs a fresh Emacs"
       ""))))

(provide 'prologos-reload)

;;; prologos-reload.el ends here
