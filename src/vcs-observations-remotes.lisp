;;;; Structured remote and refspec observations

(in-package #:vcs-kit)

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
