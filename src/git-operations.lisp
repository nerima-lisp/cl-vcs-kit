(in-package #:vcs-kit)

(defmacro %define-checked-operation (name command)
  `(defun ,name (repository &rest arguments)
     (multiple-value-bind (arguments options)
         (%split-vcs-operation-options arguments)
       (apply #'run-git/checked repository ,command arguments options))))

(defun %status-untracked-option (value)
  (ecase value
    (:no "--untracked-files=no")
    (:normal "--untracked-files=normal")
    (:all "--untracked-files=all")))

(defun %structured-execution-options (options)
  "Validate execution OPTIONS and force captured string output for a parser."
  (unless (%proper-list-p options)
    (error 'vcs-argument-error
           :argument options
           :reason "structured VCS execution options must be a proper list"))
  (unless (evenp (length options))
    (error 'vcs-argument-error
           :argument options
           :reason "structured VCS execution options must be a property list"))
  (let ((seen nil))
    (loop for key in options by #'cddr
        do (unless (keywordp key)
             (error 'vcs-argument-error
                    :argument key
                    :reason "structured VCS execution option keys must be keywords"))
           (when (member key seen)
             (error 'vcs-argument-error
                    :argument key
                    :reason "duplicate structured VCS execution option"))
           (push key seen)
           (when (member key '(:output :error-output :result-type :check))
             (error 'vcs-argument-error
                    :argument key
                    :reason "structured VCS execution option is parser-owned"))))
  (append '(:output :capture :error-output :capture :result-type :string)
          options))

(defun git-status (repository
                   &key
                     (untracked-files :normal)
                     ignored
                     show-stash
                     no-renames
                     (arguments nil)
                     (execution-options nil))
  "Return a structured porcelain-v2 status snapshot.

ARGUMENTS is appended after the machine-readable status options, which makes
it possible to pass pathspecs or additional Git status options.  EXECUTION-OPTIONS
is a property list of process controls such as :TIMEOUT or
:CANCELLATION-TOKEN; parser-owned output controls are rejected."
  (check-type arguments list)
  (let ((status-arguments
          (append (list "--porcelain=v2"
                        "--branch"
                        "-z"
                        (%status-untracked-option untracked-files))
                  (when ignored (list "--ignored"))
                  (when show-stash (list "--show-stash"))
                  (when no-renames (list "--no-renames"))
                  arguments)))
    (parse-status
     (process-result-stdout
      (apply #'run-git/checked repository "status" status-arguments
             (%structured-execution-options execution-options))))))

(%define-checked-operation git-diff "diff")

(defun git-diff-stat (repository &rest arguments)
  "Run `git diff --stat` and return its process result."
  (multiple-value-bind (arguments options)
      (%split-vcs-operation-options arguments)
    (apply #'run-git/checked repository "diff"
           (cons "--stat" arguments)
           options)))

(defun git-diff-name-status (repository &rest arguments)
  "Return structured records from `git diff --name-status -z`."
  (multiple-value-bind (arguments options)
      (%split-vcs-operation-options arguments)
    (parse-name-status
     (process-result-stdout
      (apply #'run-git/checked repository "diff"
             (append (list "--name-status" "-z") arguments)
             (%structured-execution-options options))))))

(defun git-diff-numstat (repository &rest arguments)
  "Return structured records from `git diff --numstat -z`."
  (multiple-value-bind (arguments options)
      (%split-vcs-operation-options arguments)
    (parse-numstat
     (process-result-stdout
      (apply #'run-git/checked repository "diff"
             (append (list "--numstat" "-z") arguments)
             (%structured-execution-options options))))))

(%define-checked-operation git-show "show")
(%define-checked-operation git-log "log")
(%define-checked-operation git-reflog "reflog")
(%define-checked-operation git-rev-list "rev-list")
(%define-checked-operation git-rev-parse "rev-parse")
(%define-checked-operation git-for-each-ref "for-each-ref")
(%define-checked-operation git-show-ref "show-ref")
(%define-checked-operation git-symbolic-ref "symbolic-ref")
(%define-checked-operation git-merge-base "merge-base")
(%define-checked-operation git-cat-file "cat-file")
(%define-checked-operation git-ls-tree "ls-tree")
(%define-checked-operation git-ls-files "ls-files")
(%define-checked-operation git-check-ignore "check-ignore")
(%define-checked-operation git-check-attr "check-attr")
(%define-checked-operation git-check-ref-format "check-ref-format")

(defun git-diff-check (repository &rest arguments)
  "Run `git diff --check` and return its process result."
  (multiple-value-bind (arguments options)
      (%split-vcs-operation-options arguments)
    (apply #'run-git/checked repository "diff"
           (cons "--check" arguments)
           options)))

(%define-checked-operation git-diff-files "diff-files")
(%define-checked-operation git-diff-index "diff-index")
(%define-checked-operation git-diff-tree "diff-tree")
(%define-checked-operation git-count-objects "count-objects")
(%define-checked-operation git-describe "describe")
(%define-checked-operation git-blame "blame")
(%define-checked-operation git-annotate "annotate")
(%define-checked-operation git-grep "grep")
(%define-checked-operation git-shortlog "shortlog")
(%define-checked-operation git-show-branch "show-branch")
(%define-checked-operation git-whatchanged "whatchanged")
(%define-checked-operation git-cherry "cherry")
(%define-checked-operation git-check-mailmap "check-mailmap")
(%define-checked-operation git-column "column")
(%define-checked-operation git-diff-pairs "diff-pairs")
(%define-checked-operation git-format-rev "format-rev")
(%define-checked-operation git-get-tar-commit-id "get-tar-commit-id")
(%define-checked-operation git-interpret-trailers "interpret-trailers")
(%define-checked-operation git-last-modified "last-modified")
(%define-checked-operation git-ls-remote "ls-remote")
(%define-checked-operation git-name-rev "name-rev")
(%define-checked-operation git-patch-id "patch-id")
(%define-checked-operation git-range-diff "range-diff")
(%define-checked-operation git-show-index "show-index")
(%define-checked-operation git-var "var")

(defun git-rev-parse-value (repository &rest arguments)
  "Return the trimmed first textual value from `git rev-parse`."
  (%result-output
   (apply #'git-rev-parse repository arguments)))
