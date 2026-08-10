(in-package #:vcs-kit)

(defun %starts-with-p (prefix string)
  (and (stringp string)
       (<= (length prefix) (length string))
       (string= prefix string :end2 (length prefix))))

(defun %ends-with-p (suffix string)
  (and (stringp string)
       (<= (length suffix) (length string))
       (string= suffix string
                :start2 (- (length string) (length suffix)))))

(defun %whitespace-character-p (character)
  (or (char= character #\Space)
      (char= character #\Tab)))

(defun %split-whitespace-fields (string)
  (let ((fields nil)
        (length (length string))
        (position 0))
    (loop while (< position length)
          do (loop while (and (< position length)
                              (%whitespace-character-p (char string position)))
                    do (incf position))
             (when (< position length)
               (let ((end position))
                 (loop while (and (< end length)
                                  (not (%whitespace-character-p
                                        (char string end))))
                       do (incf end))
                 (push (subseq string position end) fields)
                 (setf position end))))
    (nreverse fields)))

(defun %split-line-records (string)
  (let ((records nil)
        (length (length string))
        (start 0))
    (loop for end = (position #\Newline string :start start)
          do (if end
                 (progn
                   (push (if (and (> end start)
                                  (char= (char string (1- end)) #\Return))
                             (subseq string start (1- end))
                             (subseq string start end))
                         records)
                   (setf start (1+ end)))
                 (progn
                   (when (< start length)
                     (push (if (and (> length start)
                                    (char= (char string (1- length)) #\Return))
                               (subseq string start (1- length))
                               (subseq string start length))
                           records))
                   (return))))
    (nreverse records)))

(defun %split-tab-fields (string)
  (let ((fields nil)
        (length (length string))
        (start 0))
    (loop for end = (position #\Tab string :start start)
          do (if end
                 (progn
                   (push (subseq string start end) fields)
                   (setf start (1+ end)))
                 (progn
                   (push (subseq string start length) fields)
                   (return))))
    (nreverse fields)))

(defun %split-nul-records-vector (text)
  (check-type text string)
  (let ((length (length text))
        (records (make-array 128 :adjustable t :fill-pointer 0))
        (start 0))
    (loop for end = (position #\Null text :start start)
          do (if end
                 (progn
                   (vector-push-extend (subseq text start end) records)
                   (setf start (1+ end)))
                 (progn
                   (when (< start length)
                     (vector-push-extend (subseq text start length) records))
                   (return))))
    records))

(defun split-nul-records (text)
  "Split TEXT at NUL bytes, omitting only the final empty record.

Unlike a generic split operation, empty records between NUL bytes are
preserved.  This is required for Git's `-z` formats, where the delimiter is
part of the protocol rather than ordinary whitespace."
  (coerce (%split-nul-records-vector text) 'list))

(defun %parse-error (format-name record position)
  (error 'git-parse-error
         :format-name format-name
         :record record
         :position position))

(defun %fixed-fields-and-tail-vector
    (format-name record count position &optional (start 0))
  (let ((fields (make-array count))
        (length (length record)))
    (loop for field-position from 0 below count
          for separator = (position #\Space record :start start)
          do (when (or (null separator) (= separator start))
               (%parse-error format-name record position))
             (setf (aref fields field-position)
                   (subseq record start separator))
             (setf start (1+ separator)))
    (values fields
            (subseq record start length))))

(defun %fixed-tab-fields-and-tail (format-name record count position)
  (let ((fields nil)
        (length (length record))
        (start 0))
    (loop repeat count
          for separator = (position #\Tab record :start start)
          do (when (or (null separator) (= separator start))
               (%parse-error format-name record position))
             (push (subseq record start separator) fields)
             (setf start (1+ separator)))
    (values (nreverse fields)
            (subseq record start length))))

(defun %fixed-tab-fields-and-tail-vector
    (format-name record count position)
  (let ((fields (make-array count))
        (length (length record))
        (start 0))
    (loop for field-position from 0 below count
          for separator = (position #\Tab record :start start)
          do (when (or (null separator) (= separator start))
               (%parse-error format-name record position))
             (setf (aref fields field-position)
                   (subseq record start separator))
             (setf start (1+ separator)))
    (values fields
            (subseq record start length))))

(defun %parse-integer-field (format-name field record position)
  (handler-case
      (parse-integer field :junk-allowed nil)
    (error ()
      (%parse-error format-name record position))))

(defun %parse-optional-integer-field (format-name field record position)
  (unless (string= field "-")
    (%parse-integer-field format-name field record position)))
