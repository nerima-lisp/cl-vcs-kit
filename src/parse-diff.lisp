(in-package #:vcs-kit)

(defun %name-status-code-p (status)
  (and (not (string= status ""))
       (member (char status 0)
               '(#\A #\B #\C #\D #\M #\R #\T #\U #\X)
               :test #'char=)))

(defun %validate-name-status (status record position)
  (unless (%name-status-code-p status)
    (%parse-error "name-status" record position))
  status)

(defun %rename-or-copy-status-p (status)
  (and (not (string= status ""))
       (member (char status 0) '(#\R #\C))))

(defun %make-name-status-entry-from-fields (status fields record position)
  (%validate-name-status status record position)
  (cond
    ((%rename-or-copy-status-p status)
     (unless (= (length fields) 3)
       (%parse-error "name-status" record position))
     (%make-name-status-entry
      :status status
      :path (third fields)
      :original-path (second fields)))
    (t
     (unless (= (length fields) 2)
       (%parse-error "name-status" record position))
     (%make-name-status-entry
      :status status
      :path (second fields)))))

(defun parse-name-status (text)
  "Parse `git diff --name-status -z` output.

For rename and copy records PATH is the destination and ORIGINAL-PATH is the
source path."
  (check-type text string)
  (if (find #\Null text)
      (let* ((records (%split-nul-records-vector text))
             (record-count (length records))
             (entries nil)
             (position 0))
        (loop while (< position record-count)
              for status = (aref records position)
              do (when (string= status "")
                   (%parse-error "name-status" status position))
                 (%validate-name-status status status position)
                 (incf position)
                 (if (%rename-or-copy-status-p status)
                     (progn
                       (when (>= (1+ position) record-count)
                         (%parse-error "name-status" status position))
                       (push (%make-name-status-entry
                              :status status
                              :original-path (aref records position)
                              :path (aref records (1+ position)))
                             entries)
                       (incf position 2))
                     (progn
                       (when (>= position record-count)
                         (%parse-error "name-status" status position))
                       (push (%make-name-status-entry
                              :status status
                              :path (aref records position))
                             entries)
                       (incf position))))
        (nreverse entries))
      (loop for record in (%split-line-records text)
            for position from 0
            collect (let ((fields (%split-tab-fields record)))
                      (when (< (length fields) 2)
                        (%parse-error "name-status" record position))
                      (%make-name-status-entry-from-fields
                       (first fields) fields record position)))))

(defun %make-parsed-numstat-entry
    (additions deletions path original-path)
  (let ((binary-p (not (and additions deletions))))
    (%make-numstat-entry :additions additions
                         :deletions deletions
                         :path path
                         :original-path original-path
                         :binary-p binary-p)))

(defun %parse-numstat-record (record position)
  (multiple-value-bind (fields path)
      (%fixed-tab-fields-and-tail "numstat" record 2 position)
    (values (%parse-optional-integer-field
             "numstat" (first fields)
             record position)
            (%parse-optional-integer-field
             "numstat" (second fields)
             record position)
            path)))

(defun %parse-numstat-record-vector (record position)
  (multiple-value-bind (fields path)
      (%fixed-tab-fields-and-tail-vector "numstat" record 2 position)
    (values (%parse-optional-integer-field
             "numstat" (aref fields 0) record position)
            (%parse-optional-integer-field
             "numstat" (aref fields 1)
             record position)
            path)))

(defun parse-numstat (text)
  "Parse `git diff --numstat -z` output.

The optional ORIGINAL-PATH slot is populated when Git emits a separate path
record for a rename or copy."
  (check-type text string)
  (let* ((nul-p (find #\Null text))
         (records (if nul-p
                      (%split-nul-records-vector text)
                      (coerce (%split-line-records text) 'vector)))
         (record-count (length records))
         (entries nil)
         (position 0))
    (loop while (< position record-count)
          for record = (aref records position)
          do (if (find #\Tab record)
                 (multiple-value-bind (additions deletions path)
                     (if nul-p
                         (%parse-numstat-record-vector record position)
                         (%parse-numstat-record record position))
                   (if (and nul-p (string= path "")
                             (< (1+ position) record-count))
                       (let ((original-path (aref records (1+ position))))
                         (if (and (< (+ position 2) record-count)
                                  (not (find #\Tab
                                             (aref records (+ position 2)))))
                             (progn
                               (push (%make-parsed-numstat-entry
                                      additions deletions
                                       (aref records (+ position 2))
                                      original-path)
                                     entries)
                               (incf position 3))
                             (progn
                               (push (%make-parsed-numstat-entry
                                      additions deletions
                                      original-path
                                      nil)
                                     entries)
                               (incf position 2))))
                       (progn
                         (push (%make-parsed-numstat-entry
                                additions deletions path nil)
                               entries)
                         (incf position))))
                 (if (and nul-p entries)
                     (let* ((previous (pop entries))
                            (replacement
                              (%make-parsed-numstat-entry
                               (numstat-entry-additions previous)
                               (numstat-entry-deletions previous)
                               record
                               (numstat-entry-path previous))))
                       (push replacement entries)
                       (incf position))
                     (%parse-error "numstat" record position))))
    (nreverse entries)))
