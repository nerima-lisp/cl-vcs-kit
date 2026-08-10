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
backend-specific result.  This function deliberately rejects non-Git
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

(defun %vcs-remote-record (remotes name)
  (let ((remote (find name remotes :key #'vcs-remote-name :test #'string=)))
    (if remote
        (values remote remotes)
        (let ((remote (%make-vcs-remote :name name)))
          (values remote (cons remote remotes))))))

(defun %vcs-optional-command-lines (repository command arguments
                                      execution-options)
  "Return command lines, treating Git's missing-value exit status as empty.

Git uses exit status one for several successful queries that simply find no
matching configuration or path.  Structured readers need to distinguish that
case from all other command failures."
  (handler-case
      (let ((result (%vcs-structured-run repository command arguments
                                         execution-options)))
        (%split-line-records (%vcs-structured-output result)))
    (vcs-command-exit-error (condition)
      (unless (= (or (vcs-command-exit-error-exit-code condition) -1) 1)
        (error condition)))))

(defun %vcs-optional-config-lines (repository arguments execution-options)
  (%vcs-optional-command-lines repository "config" arguments
                                execution-options))

(defun %vcs-config-value (repository arguments execution-options)
  (first (%vcs-optional-config-lines repository arguments execution-options)))

(defun %vcs-remote-config-key (key)
  (let ((prefix "remote."))
    (multiple-value-bind (suffix direction)
        (cond
          ((%ends-with-p ".fetch" key)
           (values ".fetch" :fetch))
          ((%ends-with-p ".push" key)
           (values ".push" :push)))
      (when (and suffix
                 (%starts-with-p prefix key)
                 (> (length key) (+ (length prefix) (length suffix))))
        (values (subseq key
                        (length prefix)
                        (- (length key) (length suffix)))
                direction)))))

(defun %vcs-remote-refspec-table (repository execution-options)
  (let ((table (make-hash-table :test #'equal)))
    (dolist (line
              (%vcs-optional-config-lines
               repository
               (list "--get-regexp" "^remote\\..*\\.")
               execution-options))
      (let ((separator (position-if #'%whitespace-character-p line)))
        (when separator
          (let ((key (subseq line 0 separator))
                (value (string-left-trim '(#\Space #\Tab)
                                         (subseq line (1+ separator)))))
            (multiple-value-bind (name direction)
                (%vcs-remote-config-key key)
              (when name
                (push value (gethash (cons name direction) table))))))))
    (maphash (lambda (key values)
               (setf (gethash key table) (nreverse values)))
             table)
    table))

(defun vcs-list-remotes (repository &key (arguments nil) (execution-options nil))
  "Return Git remotes with URLs and configured fetch/push refspecs."
  (%vcs-git-repository repository :remotes)
  (check-type arguments list)
  (let ((result (%vcs-structured-run repository "remote"
                                     (cons "-v" arguments)
                                     execution-options))
        (remotes nil))
    (dolist (line (%split-line-records (%vcs-structured-output result)))
      (unless (string= line "")
        (let* ((tab (position #\Tab line))
               (name (and tab (subseq line 0 tab)))
               (rest (and tab (subseq line (1+ tab))))
               (fetch-p (and rest (search " (fetch)" rest :from-end t)))
               (push-p (and rest (search " (push)" rest :from-end t)))
               (suffix-position (or fetch-p push-p)))
          (when (and name rest suffix-position)
            (let* ((url (subseq rest 0 suffix-position))
                   (remote nil))
              (multiple-value-setq (remote remotes)
                (%vcs-remote-record remotes name))
              (if fetch-p
                        (setf (vcs-remote-fetch-url remote) url)
                        (setf (vcs-remote-push-url remote) url)))))))
    (let ((refspec-table
            (when remotes
              (%vcs-remote-refspec-table repository execution-options))))
      (dolist (remote remotes)
        (let ((name (vcs-remote-name remote)))
          (setf (vcs-remote-fetch-refspecs remote)
                (gethash (cons name :fetch) refspec-table)
                (vcs-remote-push-refspecs remote)
                (gethash (cons name :push) refspec-table)))))
    (nreverse remotes)))
