;;;; Structured backend-neutral observations: status, diff, and remotes.

(in-package #:vcs-kit)

(defun %vcs-git-repository (repository &optional operation)
  "Return REPOSITORY when it is a Git repository, or signal a capability error."
  (cond
    ((typep repository 'repository)
     (let ((backend (find-vcs-backend :git)))
       (if (or (null operation)
               (vcs-backend-supports-structured-operation-p backend operation))
           (make-vcs-repository
            (repository-directory repository)
            :backend backend
            :executable (repository-executable repository)
            :default-timeout (repository-default-timeout repository)
            :environment (repository-environment repository))
           (error 'vcs-unsupported-operation-error
                  :backend backend
                  :repository repository
                  :operation operation
                  :capabilities (vcs-backend-capabilities backend)))))
    ((typep repository 'vcs-repository)
     (let* ((backend (find-vcs-backend
                      (vcs-repository-backend repository)))
            (name (vcs-backend-name backend)))
       (if (and (eq name :git)
                (or (null operation)
                    (vcs-backend-supports-structured-operation-p backend operation)))
           repository
           (error 'vcs-unsupported-operation-error
                  :backend backend
                  :repository repository
                  :operation operation
                  :capabilities (vcs-backend-capabilities backend)))))
    (t
     (error 'type-error
            :datum repository
            :expected-type '(or repository vcs-repository)))))

(defun %vcs-structured-options (options)
  "Validate execution OPTIONS and force captured string output for a parser."
  (%structured-execution-options options))

(defun %vcs-structured-run (repository command arguments execution-options)
  "Run a checked machine-readable command and retain its untrimmed stdout."
  (let ((repository (if (typep repository 'repository)
                        (%vcs-git-repository repository)
                        repository)))
    (apply #'run-vcs/checked repository command arguments
           (%vcs-structured-options execution-options))))

(defun %vcs-structured-output (result)
  (or (process-result-stdout result) ""))

(defun %vcs-empty-to-nil (value)
  (unless (string= value "")
    value))

(defun %vcs-strip-nul-record-separator-newlines (text)
  "Remove Git's display newline immediately following a NUL record separator."
  (with-output-to-string (stream)
    (loop for index from 0 below (length text)
          for character = (char text index)
          unless (and (member character '(#\Newline #\Return))
                      (plusp index)
                      (char= (char text (1- index)) #\Null))
            do (write-char character stream))))

(defun %vcs-status-snapshot (snapshot)
  (%make-vcs-status-snapshot
   :branch-head (status-snapshot-branch-head snapshot)
   :branch-upstream (status-snapshot-branch-upstream snapshot)
   :ahead (status-snapshot-ahead snapshot)
   :behind (status-snapshot-behind snapshot)
   :stash-count (status-snapshot-stash-count snapshot)
   :entries nil))

(defun %vcs-status-entry (entry)
  (%make-vcs-status-entry
   :kind (status-entry-kind entry)
   :index-status (status-entry-index-status entry)
   :worktree-status (status-entry-worktree-status entry)
   :submodule (status-entry-submodule entry)
   :path (status-entry-path entry)
   :original-path (status-entry-original-path entry)
   :conflict-object-1 (status-entry-conflict-object-1 entry)
   :conflict-object-2 (status-entry-conflict-object-2 entry)
   :conflict-object-3 (status-entry-conflict-object-3 entry)))

(defun vcs-status-structured (repository &key
                                          (untracked-files :normal)
                                          ignored
                                          show-stash
                                          no-renames
                                          (arguments nil)
                                          (execution-options nil))
  "Return Git status as a VCS-STATUS-SNAPSHOT and VCS-STATUS-ENTRY list.

The raw GIT-STATUS operation remains available for callers that need the
backend-specific result.  It rejects non-Git
repositories until another backend has a defined equivalent parser."
  (%vcs-git-repository repository :status)
  (check-type arguments list)
  (let* ((command-arguments
           (append (list "--porcelain=v2" "--branch" "-z"
                         (%status-untracked-option untracked-files))
                   (when ignored (list "--ignored"))
                   (when show-stash (list "--show-stash"))
                   (when no-renames (list "--no-renames"))
                   arguments))
         (result (%vcs-structured-run repository "status" command-arguments
                                       execution-options))
         (parsed (parse-status (%vcs-structured-output result)))
         (snapshot (%vcs-status-snapshot parsed)))
    (setf (vcs-status-snapshot-entries snapshot)
          (mapcar #'%vcs-status-entry (status-snapshot-entries parsed)))
    snapshot))

(defun %vcs-diff-entry (name-status numstat)
  (let ((status (name-status-entry-status name-status))
        (path (name-status-entry-path name-status))
        (original-path (name-status-entry-original-path name-status)))
    (%make-vcs-diff-entry
     :status status
     :path path
     :original-path original-path
     :additions (numstat-entry-additions numstat)
     :deletions (numstat-entry-deletions numstat)
     :binary-p (numstat-entry-binary-p numstat))))

(defun vcs-diff-entries (repository &key
                                      (arguments nil)
                                      (execution-options nil))
  "Return a machine-readable Git diff by merging name-status and numstat."
  (%vcs-git-repository repository :diff)
  (check-type arguments list)
  (let* ((name-result (%vcs-structured-run
                       repository "diff"
                       (append (list "--find-renames" "--name-status" "-z")
                               arguments)
                       execution-options))
         (numstat-result (%vcs-structured-run
                          repository "diff"
                          (append (list "--find-renames" "--numstat" "-z")
                                  arguments)
                          execution-options))
         (name-status (parse-name-status
                       (%vcs-structured-output name-result)))
         (numstat (parse-numstat (%vcs-structured-output numstat-result))))
    (unless (= (length name-status) (length numstat))
      (error "Git diff streams have different entry counts: ~D and ~D."
             (length name-status) (length numstat)))
    (mapcar #'%vcs-diff-entry name-status numstat)))
