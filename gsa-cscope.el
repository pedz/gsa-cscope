;;; gsa-cscope.el --- GSA additions to cscope

;; We really need cscope to work :-)
(require 'cscope)

;; Always drag in the ofs-dce feature
(require 'osf-dce)

(defgroup gsa-cscope nil
  "GSA cscope additions"
  :group 'languages)

(defcustom gsa-cscope-sandbox-path
  (file-name-as-directory
   (if (file-exists-p (expand-file-name "~/.sandboxrc"))
       (let* ((sandbox (find-file (expand-file-name "~/.sandboxrc")))
	      (path (if (re-search-forward "^base \\* \\(.*\\)" nil t)
			(match-string 1))))
	 (kill-buffer sandbox)
	 path)
     (expand-file-name "~/sandbox")))
  "Path to the base of the user's sandboxes.
The default is dug out of the user's .sandboxrc file if possible.
Otherwise, ~/sandbox is used"
  :group 'gsa-cscope
  :type 'string)

(defcustom gsa-cscope-dir-patterns
  (list
   ;; Pattern to match files found in backing trees
   '("^\\(/gsa/.*/aix\\(53\\|61\\|71\\)./\\)[^/]*/"
     (concat (match-string 1 default-directory) "cscope/bin/cscope") ; which cscope to use
     "-d -q -l"							     ; options to pass
     (match-string 0 default-directory)				     ; to level dir
     (concat (match-string 1 default-directory) "cscope/mono.db"))   ; cscope database

   ;; Pattern to match files found in a sandbox
   (list
    (concat gsa-cscope-sandbox-path "[^/]+/")
    '(concat
      (file-name-as-directory			;add /
       (directory-file-name			;move up to parent
	(file-name-directory			;remove any /
	 (file-truename				;walk sym links
	  (concat				;append "link" to get to backing tree
	   (file-name-as-directory		;add / if needed
	    (match-string 0 default-directory)) ;path to sandbox
	   "link")))))
      "cscope/bin/cscope")			;which cscope to use
    "-d -q -l"					;options to pass to cscope
    '(match-string 0 default-directory)
    '(concat					;append cscope/mono.db
      (file-name-as-directory			;add /
       (directory-file-name			;move up to parent
	(file-name-directory			;remove any /
	 (file-truename				;walk sym links
	  (concat				;append "link"
	   (file-name-as-directory		;add / if needed
	    (match-string 0 default-directory)) ;path to sandbox
	   "link")))))
      "cscope/mono.db")))
  "A list of patterns to prepend to `cscope-dir-patterns'.
The default adds two patterns.  One matches files in the backing trees.
The second matches files in the user's sandbox."
  :type 'list
  :group 'gsa-cscope)

(defcustom gsa-pattern-list
  '( "/gsa/ausgsa/projects/a/aix/aix[0-9][0-9]?/[0-9][0-9]00-[0-9][0-9]Gold"
     "/gsa/ausgsa/projects/a/aix/aix[0-9][0-9]?/[0-9][0-9]00-[0-9][0-9]-[0-9][0-9]_SP"
     "/gsa/ausgsa/projects/a/aix/aix[0-9][0-9]?/[0-9][0-9]?_COMPLETE" )
  "List of patterns for the backing trees"
  :type 'list
  :group 'gsa-cscope)

(defcustom gsa-cscope-match-cache
  (expand-file-name "~/.emacs.d/gsa_match_cache.el")
  "Path to an elisp file that is created and maintained by the
`gsa-cscope-create-matches' command"
  :type 'string
  :group 'gsa-cscope)

;; Prepend the GSA patters since they should be more specific.
(setq cscope-dir-patterns (append gsa-cscope-dir-patterns cscope-dir-patterns))

(defun gsa-cscope-matches nil
  "The list of directories that match the patterns in `gsa-pattern-list'.
`gsa-cscope-create-matches' is used to create and update
`gsa-cscope-match-cache' which is an elisp file that sets the value to
  `gsa-cscope-matches'.")

(defun gsa-cscope-create-matches ()
  "Creates the file at `gsa-cscope-match-cache' which defines `gsa-cscope-matches'.
It then loads the file after creating it."
  (interactive)
  (let* ((file (find-file gsa-cscope-match-cache))
	 (_dummy (message "Creating cache... this may take a half minute or more."))
	 (the-list (apply 'append (mapcar 'file-expand-wildcards gsa-pattern-list))))
    (erase-buffer)
    (insert (format "(setq gsa-cscope-matches '%S)" the-list))
    (basic-save-buffer)
    (kill-buffer file))
  (gsa-cscope-load-match-cache))

(defvar gsa-cscope-obarray nil
  "An obarray of the base component for each of the paths in `gsa-cscope-matches'.")

(defun gsa-cscope-load-match-cache ()
  "Loads the file specified by `gsa-cscope-match-cache'.
The load should set `gsa-cscope-matches' which is then used to create
`gsa-cscope-obarray'."
  (interactive)
  (load gsa-cscope-match-cache)
  (setq gsa-cscope-obarray (make-vector 23 0))
  (mapc (lambda (dir)
	  (put (intern (file-name-nondirectory (directory-file-name dir)) gsa-cscope-obarray)
	       'full-path dir))
	gsa-cscope-matches))

(if (file-exists-p gsa-cscope-match-cache)
    (gsa-cscope-load-match-cache))

;;;###autoload
(defun gsa-cscope-start ( sym )
  (interactive (list (completing-read "Prompt: " 
				      (or gsa-cscope-obarray
					  (progn
					    (gsa-cscope-create-matches)
					    gsa-cscope-obarray)) nil t)))
  (let ((old-sym sym))
    (unless (symbolp sym)
      (setq sym (intern-soft sym gsa-cscope-obarray)))
    (unless sym
      (error "%s is not a valid build level" old-sym)))
  (let* ((dir (file-name-as-directory (get sym 'full-path)))
	 (parent (file-name-as-directory
		  (file-name-directory
		   (directory-file-name dir))))
	 (cscope (concat parent "cscope/bin/cscope"))
	 (options "-d -q -l")
	 (database (concat parent "cscope/mono.db")))
    (cscope-init-process cscope options dir database)
    (switch-to-buffer (cscope-out-buffer-get))))
