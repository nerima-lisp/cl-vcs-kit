(in-package #:vcs-kit)

(defun %parse-score (field record position)
  (when (or (< (length field) 2)
            (not (member (char field 0) '(#\R #\C))))
    (%parse-error "status" record position))
  (%parse-integer-field "status" (subseq field 1) record position))

(defun %parse-status-xy (xy record position)
  (unless (= (length xy) 2)
    (%parse-error "status" record position))
  (values (string (char xy 0))
          (string (char xy 1))))

(defun %parse-branch-ahead-behind (value record position)
  (let ((fields (%split-whitespace-fields value)))
    (unless (= (length fields) 2)
      (%parse-error "status" record position))
    (values (%parse-integer-field "status" (first fields) record position)
            (%parse-integer-field "status" (second fields) record position))))

(defun parse-status (text)
  "Parse Git's porcelain v2 status stream, normally produced with `-z`."
  (check-type text string)
  (let* ((records (%split-nul-records-vector text))
         (record-count (length records))
         (snapshot (%make-status-snapshot))
         (entries nil)
         (position 0))
    (loop while (< position record-count)
          for record = (aref records position)
          do (cond
               ((string= record "")
                (%parse-error "status" record position))
               ((char= (char record 0) #\#)
                (cond
                  ((%starts-with-p "# branch.head " record)
                   (setf (status-snapshot-branch-head snapshot)
                         (subseq record (length "# branch.head "))))
                  ((%starts-with-p "# branch.upstream " record)
                   (setf (status-snapshot-branch-upstream snapshot)
                         (subseq record (length "# branch.upstream "))))
                  ((%starts-with-p "# branch.ab " record)
                   (multiple-value-bind (ahead behind)
                       (%parse-branch-ahead-behind
                        (subseq record (length "# branch.ab "))
                        record position)
                     (setf (status-snapshot-ahead snapshot) ahead
                           (status-snapshot-behind snapshot) behind)))
                  ((%starts-with-p "# stash " record)
                   (setf (status-snapshot-stash-count snapshot)
                         (%parse-integer-field
                          "status"
                          (subseq record (length "# stash "))
                          record position)))
                  ;; Headers outside the fields modeled by this API do not
                  ;; affect the status snapshot.
                  (t nil)))
               ((%starts-with-p "1 " record)
                (multiple-value-bind (fields path)
                    (%fixed-fields-and-tail-vector "status"
                                             record
                                             7
                                             position
                                             2)
                  (multiple-value-bind (index-status worktree-status)
                      (%parse-status-xy (aref fields 0) record position)
                    (push (%make-status-entry
                           :kind :ordinary
                           :index-status index-status
                           :worktree-status worktree-status
                           :submodule (aref fields 1)
                           :head-mode (aref fields 2)
                           :index-mode (aref fields 3)
                           :worktree-mode (aref fields 4)
                           :head-object (aref fields 5)
                           :index-object (aref fields 6)
                           :path path)
                          entries))))
               ((%starts-with-p "2 " record)
                (multiple-value-bind (fields path)
                    (%fixed-fields-and-tail-vector "status"
                                             record
                                             8
                                             position
                                             2)
                  (let ((original-position (1+ position)))
                    (when (>= original-position record-count)
                      (%parse-error "status" record position))
                    (multiple-value-bind (index-status worktree-status)
                        (%parse-status-xy (aref fields 0) record position)
                      (push (%make-status-entry
                             :kind :rename-or-copy
                             :index-status index-status
                             :worktree-status worktree-status
                             :submodule (aref fields 1)
                             :head-mode (aref fields 2)
                             :index-mode (aref fields 3)
                             :worktree-mode (aref fields 4)
                             :head-object (aref fields 5)
                             :index-object (aref fields 6)
                             :score (%parse-score (aref fields 7)
                                                  record position)
                             :path path
                             :original-path (aref records original-position))
                            entries))
                    (setf position original-position))))
               ((%starts-with-p "u " record)
                (multiple-value-bind (fields path)
                    (%fixed-fields-and-tail-vector "status"
                                             record
                                             9
                                             position
                                             2)
                  (multiple-value-bind (index-status worktree-status)
                      (%parse-status-xy (aref fields 0) record position)
                    (push (%make-status-entry
                           :kind :unmerged
                           :index-status index-status
                           :worktree-status worktree-status
                           :submodule (aref fields 1)
                           :conflict-mode-1 (aref fields 2)
                           :conflict-mode-2 (aref fields 3)
                           :conflict-mode-3 (aref fields 4)
                           :worktree-mode (aref fields 5)
                           :conflict-object-1 (aref fields 6)
                           :conflict-object-2 (aref fields 7)
                           :conflict-object-3 (aref fields 8)
                           :path path)
                          entries))))
               ((or (%starts-with-p "? " record)
                    (%starts-with-p "! " record))
                (push (%make-status-entry
                       :kind (if (char= (char record 0) #\?)
                                 :untracked
                                 :ignored)
                       :path (subseq record 2))
                      entries))
               (t
                (%parse-error "status" record position)))
             (incf position))
    (setf (status-snapshot-entries snapshot) (nreverse entries))
    snapshot))
