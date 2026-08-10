;;;; Structured backend-neutral observations: branches, tags, and history.

(in-package #:vcs-kit)

(defun %vcs-branch-counts (repository branch upstream execution-options)
  (let* ((range (format nil "~A...~A" branch upstream))
         (result (%vcs-structured-run repository "rev-list"
                                      (list "--left-right" "--count" range)
                                      execution-options))
         (fields (%split-whitespace-fields (%vcs-structured-output result))))
    (unless (= (length fields) 2)
      (error "Malformed Git branch divergence output for ~A: ~S."
             branch (%vcs-structured-output result)))
    (values (parse-integer (first fields))
            (parse-integer (second fields)))))

(defun vcs-list-branches (repository &key (arguments nil) (execution-options nil))
  "Return local Git branches and their upstream divergence."
  (%vcs-git-repository repository :branches)
  (check-type arguments list)
  (let ((result (%vcs-structured-run
                repository "for-each-ref"
                 (append (list "--format=%(HEAD)%09%(refname:short)%09%(upstream:short)"
                              "refs/heads")
                        arguments)
                execution-options))
        (branches nil))
    (dolist (line (%split-line-records (%vcs-structured-output result)))
      (unless (string= line "")
        (let ((fields (%split-tab-fields line)))
          (unless (>= (length fields) 3)
            (error "Malformed Git branch output: ~S." line))
          (let* ((current-p (string= (first fields) "*"))
                 (name (second fields))
                 (upstream (%vcs-empty-to-nil (third fields)))
                 (ahead nil)
                 (behind nil))
            (when upstream
              (multiple-value-setq (ahead behind)
                (%vcs-branch-counts repository name upstream execution-options)))
            (push (%make-vcs-branch :name name
                                    :current-p current-p
                                    :upstream upstream
                                    :ahead ahead
                                    :behind behind)
                  branches)))))
    (nreverse branches)))

(defun vcs-list-tags (repository &key (arguments nil) (execution-options nil))
  "Return local Git tags, including peeled targets for annotated tags."
  (%vcs-git-repository repository :tags)
  (check-type arguments list)
  (let ((result (%vcs-structured-run
                repository "for-each-ref"
                 (append (list "--format=%(refname:short)%09%(objectname)%09%(objecttype)%09%(subject)%09%(taggername)"
                              "refs/tags")
                        arguments)
                execution-options))
        (tags nil))
    (dolist (line (%split-line-records (%vcs-structured-output result)))
      (unless (string= line "")
        (let ((fields (%split-tab-fields line)))
          (unless (>= (length fields) 5)
            (error "Malformed Git tag output: ~S." line))
          (let* ((name (first fields))
                 (object (second fields))
                 (annotated-p (string= (third fields) "tag"))
                 (target (if annotated-p
                             (let ((target-result
                                     (%vcs-structured-run
                                      repository "rev-parse"
                                      (list (format nil "~A^{}" name))
                                      execution-options)))
                               (string-trim '(#\Space #\Tab #\Newline #\Return)
                                            (%vcs-structured-output target-result)))
                             object)))
            (push (%make-vcs-tag
                   :name name
                   :target target
                   :annotated-p annotated-p
                   :message (%vcs-empty-to-nil (fourth fields))
                   :tagger (%vcs-empty-to-nil (fifth fields))
                   :signature-status nil)
                  tags)))))
    (nreverse tags)))

(defun %vcs-commits-from-fields (fields)
  (let ((field-count (length fields))
        (size 9))
    (unless (zerop (mod field-count size))
      (error "Malformed Git ~A output: expected groups of ~D fields, got ~D."
             "commit" size field-count))
    (loop for base from 0 below field-count by size
          collect (%make-vcs-commit
                   :id (%vcs-empty-to-nil (aref fields base))
                   :parents (%split-whitespace-fields
                             (aref fields (1+ base)))
                   :tree (%vcs-empty-to-nil (aref fields (+ base 2)))
                   :author (%vcs-empty-to-nil (aref fields (+ base 3)))
                   :committer (%vcs-empty-to-nil (aref fields (+ base 5)))
                   :authored-at (%vcs-empty-to-nil (aref fields (+ base 4)))
                   :committed-at (%vcs-empty-to-nil (aref fields (+ base 6)))
                   :message (%vcs-empty-to-nil (aref fields (+ base 8)))
                   :encoding (%vcs-empty-to-nil (aref fields (+ base 7)))))))

(defun vcs-list-commits (repository &key
                                      (arguments nil)
                                      (execution-options nil))
  "Return Git commits using a stable NUL-delimited log format."
  (%vcs-git-repository repository :commits)
  (check-type arguments list)
  (let* ((log-format "--format=%H%x00%P%x00%T%x00%an <%ae>%x00%aI%x00%cn <%ce>%x00%cI%x00%e%x00%B%x00")
         (result (%vcs-structured-run
                  repository "log"
                  (append (list "--no-color" log-format) arguments)
                  execution-options))
         (fields (%split-nul-records-vector
                  (%vcs-strip-nul-record-separator-newlines
                   (%vcs-structured-output result)))))
    (%vcs-commits-from-fields fields)))

(defun vcs-list-stashes (repository &key (arguments nil) (execution-options nil))
  "Return Git stash entries."
  (%vcs-git-repository repository :stashes)
  (check-type arguments list)
  (let* ((result (%vcs-structured-run
                  repository "stash"
                  (append (list "list" "--format=%gd%x00%gs%x00%gI") arguments)
                  execution-options))
         (entries nil))
    (dolist (line (%split-line-records (%vcs-structured-output result)))
      (unless (string= line "")
        (let ((fields (%split-nul-records-vector line)))
          (unless (>= (length fields) 3)
            (error "Malformed Git stash output: ~S." line))
          (push (%make-vcs-stash-entry
                 :reference (%vcs-empty-to-nil (aref fields 0))
                 :message (%vcs-empty-to-nil (aref fields 1))
                 :date (%vcs-empty-to-nil (aref fields 2)))
                entries))))
    (nreverse entries)))

(defun vcs-list-conflicts (repository &key
                                        (arguments nil)
                                        (execution-options nil))
  "Return unmerged Git paths and their three-way conflict object IDs."
  (let ((status (vcs-status-structured repository
                                       :arguments arguments
                                       :execution-options execution-options)))
    (loop for entry in (vcs-status-snapshot-entries status)
          when (eq (vcs-status-entry-kind entry) :unmerged)
            collect (%make-vcs-conflict
                     :path (vcs-status-entry-path entry)
                     :base (vcs-status-entry-conflict-object-1 entry)
                     :ours (vcs-status-entry-conflict-object-2 entry)
                     :theirs (vcs-status-entry-conflict-object-3 entry)))))
