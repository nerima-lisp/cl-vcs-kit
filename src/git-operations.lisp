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

;; Working-tree and history mutation.
(%define-checked-operation git-add "add")
(%define-checked-operation git-stage "stage")
(%define-checked-operation git-commit "commit")
(%define-checked-operation git-branch "branch")
(%define-checked-operation git-switch "switch")
(%define-checked-operation git-checkout "checkout")
(%define-checked-operation git-restore "restore")
(%define-checked-operation git-reset "reset")
(%define-checked-operation git-rm "rm")
(%define-checked-operation git-mv "mv")
(%define-checked-operation git-clean "clean")
(%define-checked-operation git-tag "tag")
(%define-checked-operation git-update-ref "update-ref")
(%define-checked-operation git-merge "merge")
(%define-checked-operation git-rebase "rebase")
(%define-checked-operation git-cherry-pick "cherry-pick")
(%define-checked-operation git-revert "revert")
(%define-checked-operation git-stash "stash")
(%define-checked-operation git-sparse-checkout "sparse-checkout")
(%define-checked-operation git-rerere "rerere")

;; Auxiliary, collaboration, and diagnostic commands.
(%define-checked-operation git-backfill "backfill")
(%define-checked-operation git-bugreport "bugreport")
(%define-checked-operation git-citool "citool")
(%define-checked-operation git-diagnose "diagnose")
(%define-checked-operation git-difftool "difftool")
(%define-checked-operation git-filter-branch "filter-branch")
(%define-checked-operation git-for-each-repo "for-each-repo")
(%define-checked-operation git-help "help")
(%define-checked-operation git-instaweb "instaweb")
(%define-checked-operation git-mergetool "mergetool")
(%define-checked-operation git-pack-refs "pack-refs")
(%define-checked-operation git-refs "refs")
(%define-checked-operation git-replay "replay")
(%define-checked-operation git-repo "repo")
(%define-checked-operation git-request-pull "request-pull")

;; Remote, collaboration, and repository maintenance.
(%define-checked-operation git-remote "remote")
(%define-checked-operation git-fetch "fetch")
(%define-checked-operation git-pull "pull")
(%define-checked-operation git-push "push")
(%define-checked-operation git-worktree "worktree")
(%define-checked-operation git-submodule "submodule")
(%define-checked-operation git-notes "notes")
(%define-checked-operation git-bisect "bisect")
(%define-checked-operation git-archive "archive")
(%define-checked-operation git-bundle "bundle")
(%define-checked-operation git-format-patch "format-patch")
(%define-checked-operation git-am "am")
(%define-checked-operation git-apply "apply")
(%define-checked-operation git-fast-export "fast-export")
(%define-checked-operation git-fast-import "fast-import")
(%define-checked-operation git-archimport "archimport")
(%define-checked-operation git-cvsexportcommit "cvsexportcommit")
(%define-checked-operation git-cvsimport "cvsimport")
(%define-checked-operation git-cvsserver "cvsserver")
(%define-checked-operation git-imap-send "imap-send")
(%define-checked-operation git-p4 "p4")
(%define-checked-operation git-quiltimport "quiltimport")
(%define-checked-operation git-send-email "send-email")
(%define-checked-operation git-svn "svn")
(%define-checked-operation git-maintenance "maintenance")
(%define-checked-operation git-gc "gc")
(%define-checked-operation git-prune "prune")
(%define-checked-operation git-prune-packed "prune-packed")
(%define-checked-operation git-repack "repack")
(%define-checked-operation git-fsck "fsck")

;; Plumbing and object/index operations.
(%define-checked-operation git-commit-tree "commit-tree")
(%define-checked-operation git-config "config")
(%define-checked-operation git-credential "credential")
(%define-checked-operation git-fmt-merge-msg "fmt-merge-msg")
(%define-checked-operation git-fsck-objects "fsck-objects")
(%define-checked-operation git-hash-object "hash-object")
(%define-checked-operation git-hook "hook")
(%define-checked-operation git-index-pack "index-pack")
(%define-checked-operation git-init-db "init-db")
(%define-checked-operation git-mailinfo "mailinfo")
(%define-checked-operation git-mailsplit "mailsplit")
(%define-checked-operation git-merge-file "merge-file")
(%define-checked-operation git-merge-index "merge-index")
(%define-checked-operation git-merge-tree "merge-tree")
(%define-checked-operation git-mktag "mktag")
(%define-checked-operation git-mktree "mktree")
(%define-checked-operation git-pack-objects "pack-objects")
(%define-checked-operation git-pack-redundant "pack-redundant")
(%define-checked-operation git-read-tree "read-tree")
(%define-checked-operation git-receive-pack "receive-pack")
(%define-checked-operation git-replace "replace")
(%define-checked-operation git-send-pack "send-pack")
(%define-checked-operation git-stripspace "stripspace")
(%define-checked-operation git-unpack-file "unpack-file")
(%define-checked-operation git-unpack-objects "unpack-objects")
(%define-checked-operation git-update-index "update-index")
(%define-checked-operation git-update-server-info "update-server-info")
(%define-checked-operation git-upload-archive "upload-archive")
(%define-checked-operation git-upload-pack "upload-pack")
(%define-checked-operation git-verify-commit "verify-commit")
(%define-checked-operation git-verify-pack "verify-pack")
(%define-checked-operation git-verify-tag "verify-tag")
(%define-checked-operation git-write-tree "write-tree")
(%define-checked-operation git-checkout-index "checkout-index")
(%define-checked-operation git-commit-graph "commit-graph")
(%define-checked-operation git-multi-pack-index "multi-pack-index")
