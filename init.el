;;; init.el --- Pure Emacs 31 Config --- -*- lexical-binding: t; -*-

(setq gc-cons-threshold (* 50 1000 1000))
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 2 1000 1000))
            (message "Loaded in %s with %d GCs" (emacs-init-time) gcs-done)))

(defvar my/cache-dir (expand-file-name "cache/" user-emacs-directory))
(make-directory my/cache-dir t)

(setq custom-file (locate-user-emacs-file "custom-vars.el"))
(load custom-file 'noerror 'nomessage)

(tool-bar-mode 0)
(menu-bar-mode 0)
(scroll-bar-mode 0)
(blink-cursor-mode 0)
(tooltip-mode 0)

(setq inhibit-startup-screen t
      initial-scratch-message ""
      ring-bell-function 'ignore
      use-dialog-box nil
      use-file-dialog nil
      visible-bell nil)

(fset 'yes-or-no-p 'y-or-n-p)
(setq use-short-answers t)

(column-number-mode 1)
(global-display-line-numbers-mode 1)
(setq display-line-numbers-type 'relative)
(global-hl-line-mode 1)

(setq truncate-lines t
      indent-tabs-mode nil
      tab-width 2
      scroll-margin 5
      scroll-conservatively 8)

(setq-default fill-column 100)
(global-display-fill-column-indicator-mode 1)

(add-to-list 'default-frame-alist '(font . "Monospace-18"))

(setq-default show-trailing-whitespace t)
(add-hook 'before-save-hook 'delete-trailing-whitespace)

(electric-pair-mode 1)
(delete-selection-mode 1)

(defun my/set-margins ()
  (dolist (window (window-list))
    (set-window-margins window 2 0)))
(add-hook 'window-configuration-change-hook #'my/set-margins)

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(unless (package-installed-p 'nord-theme)
  (package-refresh-contents)
  (package-install 'nord-theme))

(load-theme 'nord t)

(setq backup-directory-alist `(("." . ,(concat my/cache-dir "backups")))
      backup-by-copying t
      delete-old-versions t
      kept-new-versions 6
      version-control t
      auto-save-default t
      create-lockfiles nil
      make-backup-files nil)

(make-directory (expand-file-name "auto-saves/" my/cache-dir) t)
(setq auto-save-list-file-prefix (expand-file-name "auto-saves/sessions/" my/cache-dir)
      auto-save-file-name-transforms `((".*" ,(expand-file-name "auto-saves/" my/cache-dir) t)))

(savehist-mode 1)
(setq savehist-save-minibuffer-history t
      savehist-additional-variables '(kill-ring register-alist mark-ring
                                      global-mark-ring search-ring regexp-search-ring)
      savehist-file (expand-file-name "history" my/cache-dir)
      history-length 300)

(save-place-mode 1)
(setq save-place-file (expand-file-name "saveplace" my/cache-dir)
      save-place-limit 600)

(recentf-mode 1)
(setq recentf-max-saved-items 300
      recentf-max-menu-items 15
      recentf-auto-cleanup 'never
      recentf-save-file (expand-file-name "recentf" my/cache-dir))

(global-auto-revert-mode 1)
(winner-mode 1)
(repeat-mode 1)

(setq completion-styles '(flex partial-completion)
      completion-ignore-case t
      read-file-name-completion-ignore-case t
      read-buffer-completion-ignore-case t
      completion-auto-help t
      completions-detailed t
      tab-always-indent 'complete)

(icomplete-mode 1)
(icomplete-vertical-mode 1)

(setq icomplete-delay-completions-threshold 0
      icomplete-compute-delay 0
      icomplete-show-matches-on-no-input t
      icomplete-hide-common-prefix nil
      icomplete-prospects-height 10
      icomplete-separator "\n"
      icomplete-scroll t
      icomplete-in-buffer t
      icomplete-vertical-render-prefix-indicator t)

(define-key icomplete-minibuffer-map (kbd "C-n") 'icomplete-forward-completions)
(define-key icomplete-minibuffer-map (kbd "C-p") 'icomplete-backward-completions)
(define-key icomplete-minibuffer-map (kbd "C-v") 'icomplete-vertical-toggle)
(define-key icomplete-minibuffer-map (kbd "RET") 'icomplete-force-complete-and-exit)
(define-key icomplete-minibuffer-map (kbd "<down>") 'icomplete-forward-completions)
(define-key icomplete-minibuffer-map (kbd "<up>") 'icomplete-backward-completions)

(defun my/icomplete-fido-ret ()
  (interactive)
  (if (and (eq (icomplete--category) 'file)
           minibuffer-completing-file-name)
      (let* ((dir (file-name-directory (minibuffer-contents)))
             (current (minibuffer-contents))
             (selected (or (car completion-all-sorted-completions) current))
             (full-path (expand-file-name selected dir)))
        (if (file-directory-p full-path)
            (progn
              (delete-minibuffer-contents)
              (insert (file-name-as-directory full-path)))
          (icomplete-force-complete-and-exit)))
    (icomplete-force-complete-and-exit)))

(define-key icomplete-minibuffer-map (kbd "RET") 'my/icomplete-fido-ret)

(add-hook 'prog-mode-hook 'completion-preview-mode)
(add-hook 'text-mode-hook 'completion-preview-mode)

(setq completion-auto-help t)
(setq completions-format 'one-column)
(setq completion-show-help nil)

(with-eval-after-load 'completion-preview
  (setq completion-preview-exact-match-only nil)
  (setq completion-preview-commands
        '(self-insert-command insert-char delete-backward-char backward-delete-char-untabify))
  (setq completion-preview-minimum-symbol-length 2))

(defvar my/completions-frame nil)
(defvar my/completions-watchdog nil)

(defun my/completions-delete-frame ()
  (when (frame-live-p my/completions-frame)
    (delete-frame my/completions-frame)
    (setq my/completions-frame nil))
  (when my/completions-watchdog
    (remove-hook 'post-command-hook my/completions-watchdog)
    (setq my/completions-watchdog nil)))

(defun my/completions-show ()
  (when (and (get-buffer "*Completions*")
             (display-graphic-p))
    (my/completions-delete-frame)
    
    (when (get-buffer-window "*Completions*")
      (delete-window (get-buffer-window "*Completions*")))
    
    (let* ((parent (selected-frame))
           (buffer (get-buffer "*Completions*"))
           (line-count (with-current-buffer buffer
                         (count-lines (point-min) (point-max))))
           (height (min 15 line-count)))

      (setq my/completions-frame
            (make-frame
             `((parent-frame . ,parent)
               (no-accept-focus . nil)
               (no-focus-on-map . nil)
               (internal-border-width . 1)
               (undecorated . t)
               (left . ,(+ (car (window-pixel-edges))
                          (car (posn-x-y (posn-at-point)))))
               (top . ,(+ (cadr (window-pixel-edges))
                         (cdr (posn-x-y (posn-at-point)))
                         (frame-char-height)))
               (width . 40)
               (height . ,height)
               (minibuffer . nil)
               (visibility . t)
               (cursor-type . nil)
               (menu-bar-lines . 0)
               (tool-bar-lines . 0)
               (tab-bar-lines . 0)
               (right-fringe . 0)
               (left-fringe . 0))))

      (set-window-buffer (frame-root-window my/completions-frame) buffer)

      (let* ((bg (face-background 'default))
             (rgb (color-name-to-rgb bg))
             (darker (apply #'color-rgb-to-hex (mapcar (lambda (c) (* 0.9 c)) rgb))))
        (set-frame-parameter my/completions-frame 'background-color darker))

      (setq my/completions-watchdog
            (lambda ()
              (when (and (frame-live-p my/completions-frame)
                        (or (not (eq (selected-frame) my/completions-frame))
                            (not (get-buffer "*Completions*"))))
                (my/completions-delete-frame))))
      
      (add-hook 'post-command-hook my/completions-watchdog))))

(add-hook 'completion-setup-hook 'my/completions-show)
(add-hook 'completion-in-region-mode-hook
          (lambda ()
            (unless completion-in-region-mode
              (my/completions-delete-frame))))

(setq isearch-lazy-count t
      lazy-count-prefix-format "(%s/%s) "
      lazy-count-suffix-format nil
      search-whitespace-regexp ".*?")

(defun my/isearch-copy ()
  (interactive)
  (when isearch-other-end
    (kill-new (buffer-substring-no-properties isearch-other-end (point)))
    (isearch-exit)))

(define-key isearch-mode-map (kbd "M-w") 'my/isearch-copy)

(global-set-key (kbd "C-x C-r")
                (lambda () (interactive)
                  (find-file (completing-read "Recent: " recentf-list))))

(global-set-key (kbd "C-x C-b") 'ibuffer)
(setq ibuffer-show-empty-filter-groups nil)

(global-set-key (kbd "C-<right>") 'next-buffer)
(global-set-key (kbd "C-<left>") 'previous-buffer)
(global-set-key (kbd "C-c C-c") 'kill-this-buffer)

(global-set-key (kbd "M-o") 'other-window)

(defun my/move-line-down ()
  (interactive)
  (forward-line 1)
  (transpose-lines 1)
  (forward-line -1))

(defun my/move-line-up ()
  (interactive)
  (transpose-lines 1)
  (forward-line -2))

(global-set-key (kbd "M-J") 'my/move-line-down)
(global-set-key (kbd "M-K") 'my/move-line-up)
(global-set-key (kbd "M-j") 'duplicate-dwim)

(defun my/surround (open close)
  (when (use-region-p)
    (let ((beg (region-beginning))
          (end (region-end)))
      (goto-char end)
      (insert close)
      (goto-char beg)
      (insert open))))

(global-set-key (kbd "C-c (") (lambda () (interactive) (my/surround "(" ")")))
(global-set-key (kbd "C-c {") (lambda () (interactive) (my/surround "{" "}")))
(global-set-key (kbd "C-c [") (lambda () (interactive) (my/surround "[" "]")))
(global-set-key (kbd "C-c \"") (lambda () (interactive) (my/surround "\"" "\"")))

(global-set-key (kbd "C-x ;") 'comment-line)

(defun my/pulse-region ()
  (when (region-active-p)
    (pulse-momentary-highlight-region (region-beginning) (region-end))))
(advice-add 'kill-ring-save :after #'my/pulse-region)

(setq dired-listing-switches "-alh --group-directories-first"
      dired-dwim-target t
      dired-kill-when-opening-new-dired-buffer t
      dired-omit-files "^\\.")

(add-hook 'dired-mode-hook 'dired-hide-details-mode)
(add-hook 'dired-mode-hook 'dired-omit-mode)

(defun my/dired-sidebar ()
  (interactive)
  (let* ((dir (or (vc-root-dir) default-directory))
         (buf (dired-noselect dir)))
    (display-buffer-in-side-window
     buf `((side . left)
           (slot . 0)
           (window-width . 35)
           (window-parameters . ((no-other-window . t)
                                 (no-delete-other-windows . t)))))
    (with-current-buffer buf
      (rename-buffer "*Dired*" t))))

(global-set-key (kbd "M-i") 'my/dired-sidebar)

(require 'project)
(setq project-list-file (expand-file-name "projects" my/cache-dir))

(global-set-key (kbd "C-c p f") 'project-find-file)
(global-set-key (kbd "C-c p p") 'project-switch-project)
(global-set-key (kbd "C-c p g") 'project-find-regexp)
(global-set-key (kbd "C-c p b") 'project-switch-to-buffer)

(setq xref-search-program 'ripgrep)

(setq treesit-language-source-alist
      '((rust "https://github.com/tree-sitter/tree-sitter-rust" "master" "src")
        (python "https://github.com/tree-sitter/tree-sitter-python" "master" "src")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "master" "src")
        (typescript "https://github.com/tree-sitter/tree-sitter-typescript" "master" "typescript/src")
        (tsx "https://github.com/tree-sitter/tree-sitter-typescript" "master" "tsx/src")
        (json "https://github.com/tree-sitter/tree-sitter-json" "master" "src")
        (yaml "https://github.com/tree-sitter/tree-sitter-yaml" "master" "src")))

(setq treesit-auto-install-grammar t)

(add-to-list 'major-mode-remap-alist '(rust-mode . rust-ts-mode))
(add-to-list 'major-mode-remap-alist '(python-mode . python-ts-mode))
(add-to-list 'major-mode-remap-alist '(js-mode . js-ts-mode))
(add-to-list 'major-mode-remap-alist '(typescript-mode . typescript-ts-mode))

(require 'eglot)

(setq eglot-autoshutdown t
      eglot-events-buffer-size 0
      eglot-sync-connect nil)

(add-to-list 'eglot-server-programs '((rust-ts-mode rust-mode) . ("rust-analyzer")))
(add-to-list 'eglot-server-programs '(go-mode . ("gopls")))
(add-to-list 'eglot-server-programs '((c-mode c++-mode) . ("clangd")))
(add-to-list 'eglot-server-programs '((python-mode python-ts-mode) . ("pylsp")))
(add-to-list 'eglot-server-programs
             '((js-mode js-ts-mode typescript-mode typescript-ts-mode tsx-ts-mode) .
               ("typescript-language-server" "--stdio")))

(add-hook 'rust-ts-mode-hook 'eglot-ensure)
(add-hook 'rust-mode-hook 'eglot-ensure)
(add-hook 'python-ts-mode-hook 'eglot-ensure)
(add-hook 'python-mode-hook 'eglot-ensure)
(add-hook 'go-mode-hook 'eglot-ensure)
(add-hook 'c-mode-hook 'eglot-ensure)
(add-hook 'c++-mode-hook 'eglot-ensure)
(add-hook 'js-ts-mode-hook 'eglot-ensure)
(add-hook 'typescript-ts-mode-hook 'eglot-ensure)

(define-key eglot-mode-map (kbd "C-c l a") 'eglot-code-actions)
(define-key eglot-mode-map (kbd "C-c l r") 'eglot-rename)
(define-key eglot-mode-map (kbd "C-c l f") 'eglot-format)
(define-key eglot-mode-map (kbd "C-c l d") 'eglot-find-declaration)

(with-eval-after-load 'rust-ts-mode
  (setq rust-ts-mode-indent-offset 2))

(add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-ts-mode))

(add-hook 'prog-mode-hook 'flymake-mode)

(global-set-key (kbd "M-n") 'flymake-goto-next-error)
(global-set-key (kbd "M-p") 'flymake-goto-prev-error)

(setq vc-follow-symlinks t
      vc-make-backup-files nil)

(global-set-key (kbd "C-x g") 'vc-dir)

(defun my/git-add ()
  (interactive)
  (when (buffer-file-name)
    (shell-command (format "git add %s" (buffer-file-name)))
    (message "Added: %s" (file-name-nondirectory (buffer-file-name)))))

(defun my/git-commit ()
  (interactive)
  (let ((msg (read-string "Commit: ")))
    (shell-command (format "git commit -m \"%s\"" msg))
    (message "Committed: %s" msg)))

(global-set-key (kbd "C-c g a") 'my/git-add)
(global-set-key (kbd "C-c g c") 'my/git-commit)

(setq compilation-always-kill t
      compilation-scroll-output t)

(add-hook 'compilation-filter-hook #'ansi-color-compilation-filter)

(global-set-key (kbd "C-c t") 'term)
(global-set-key (kbd "C-c e") 'eshell)

(setq eshell-history-size 100000
      eshell-hist-ignoredups t)

(with-eval-after-load 'eshell
  (setq eshell-prompt-function
        (lambda ()
          (concat
           (if (= eshell-last-command-status 0)
               (propertize "✓ " 'face '(:foreground "green"))
             (propertize "✗ " 'face '(:foreground "red")))
           (propertize (abbreviate-file-name (eshell/pwd))
                       'face '(:foreground "cyan" :weight bold))
           (when-let ((branch (ignore-errors
                                (string-trim
                                 (shell-command-to-string "git branch --show-current 2>/dev/null")))))
             (unless (string-empty-p branch)
               (concat " " (propertize (concat " " branch)
                                       'face '(:foreground "yellow")))))
           (propertize " λ " 'face '(:foreground "blue" :weight bold)))))

  (setq eshell-prompt-regexp "^[^λ]* λ "))

(setq display-buffer-alist
      '(("\\*\\(Backtrace\\|Warnings\\|Messages\\)\\*"
         (display-buffer-in-side-window)
         (window-height . 0.25)
         (side . bottom))
        ("\\*\\([Hh]elp\\)\\*"
         (display-buffer-in-side-window)
         (window-width . 80)
         (side . right))
        ("\\*\\(Flymake diagnostics\\)"
         (display-buffer-in-side-window)
         (window-height . 0.25)
         (side . bottom))
        ("\\*\\(grep\\|xref\\)\\*"
         (display-buffer-in-side-window)
         (window-height . 0.25)
         (side . bottom))))

(defun my/scratchpad ()
  (interactive)
  (switch-to-buffer "*Scratchpad*")
  (when (eq major-mode 'fundamental-mode)
    (emacs-lisp-mode)))

(global-set-key (kbd "C-c s") 'my/scratchpad)

(defun my/kill-others ()
  (interactive)
  (mapc 'kill-buffer (delq (current-buffer) (buffer-list)))
  (message "Killed all other buffers"))

(global-set-key (kbd "C-c K") 'my/kill-others)

(setq save-abbrevs nil)

(define-abbrev-table 'global-abbrev-table
  '(("ra" "→")
    ("la" "←")
    ("ua" "↑")
    ("da" "↓")
    ("todo" "TODO:")
    ("fixme" "FIXME:")
    ("note" "NOTE:")
    ("isodate" "" (lambda () (insert (format-time-string "%Y-%m-%dT%H:%M:%S"))))))

(with-current-buffer (get-buffer-create "*scratch*")
  (erase-buffer)
  (insert (format ";;; Emacs loaded in %s (%d GCs)
;;; 1 external package: nord-theme
;;; Rest: pure Emacs 31 built-in features
;;;
"
                  (emacs-init-time)
                  gcs-done)))

;;; init.el ends here
