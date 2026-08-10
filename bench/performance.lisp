(require :asdf)
(asdf:load-system "cl-vcs-kit")

(in-package #:vcs-kit)

(defun %benchmark-status-text (count)
  (with-output-to-string (stream)
    (loop for index below count
          do (when (plusp index)
               (write-char #\Null stream))
             (format stream
                     "1 .M N... 100644 100644 100644 1111111 2222222 file-~D.txt"
                     index))))

(defun %benchmark-name-status-text (count)
  (with-output-to-string (stream)
    (loop for index below count
          do (when (plusp index)
               (write-char #\Null stream))
             (format stream "M")
             (write-char #\Null stream)
             (format stream "file-~D.txt" index))))

(defun %benchmark-name-status-line-text (count)
  (with-output-to-string (stream)
    (loop for index below count
          do (when (plusp index)
               (write-char #\Newline stream))
             (format stream "M~Cfile-~D.txt" #\Tab index))))

(defun %benchmark-numstat-text (count)
  (with-output-to-string (stream)
    (loop for index below count
          do (when (plusp index)
               (write-char #\Null stream))
             (format stream "1~C2~Cfile-~D.txt"
                     #\Tab #\Tab index))))

(defun %benchmark-numstat-line-text (count)
  (with-output-to-string (stream)
    (loop for index below count
          do (when (plusp index)
               (write-char #\Newline stream))
             (format stream "1~C2~Cfile-~D.txt"
                     #\Tab #\Tab index))))

(defun %benchmark-commit-fields (count)
  (loop repeat count
        append (list "id" "parents" "tree" "author" "authored-at"
                     "committer" "committed-at" "encoding" "message")))

(defun %benchmark-record-groups-subseq (fields size)
  (loop for start from 0 below (length fields) by size
        collect (subseq fields start (+ start size))))

(defun %benchmark-record-groups-linear (fields size)
  (let ((remaining fields))
    (loop while remaining
          collect (loop repeat size
                        collect (pop remaining)))))

(defun %benchmark-commits-grouped (fields)
  (mapcar (lambda (group)
            (%make-vcs-commit
             :id (%vcs-empty-to-nil (first group))
             :parents (%split-whitespace-fields (second group))
             :tree (%vcs-empty-to-nil (third group))
             :author (%vcs-empty-to-nil (fourth group))
             :committer (%vcs-empty-to-nil (sixth group))
             :authored-at (%vcs-empty-to-nil (fifth group))
             :committed-at (%vcs-empty-to-nil (seventh group))
             :message (%vcs-empty-to-nil (ninth group))
             :encoding (%vcs-empty-to-nil (eighth group))))
          (%benchmark-record-groups-linear fields 9)))

(defun %benchmark-parser (name parser text expected result-count iterations)
  (let ((warmup (funcall parser text)))
    (assert (= (funcall result-count warmup) expected))
    (let* ((start-time (get-internal-real-time))
           (start-bytes (sb-ext:get-bytes-consed))
           (last-result
             (loop repeat iterations
                   do (setf warmup (funcall parser text))
                   finally (return warmup)))
           (elapsed (/ (- (get-internal-real-time) start-time)
                       internal-time-units-per-second))
           (bytes (- (sb-ext:get-bytes-consed) start-bytes)))
      (format t "~A records=~D iterations=~D seconds=~,6F bytes=~D results=~D~%"
              name
              expected
              iterations
              elapsed
              bytes
              (funcall result-count last-result)))))

(let* ((count 10000)
       (group-count 2000)
       (iterations 3)
       (status-text (%benchmark-status-text count))
       (name-status-text (%benchmark-name-status-text count))
       (name-status-line-text (%benchmark-name-status-line-text count))
       (numstat-text (%benchmark-numstat-text count))
       (numstat-line-text (%benchmark-numstat-line-text count))
       (commit-fields (%benchmark-commit-fields group-count))
       (commit-fields-vector (coerce commit-fields 'vector))
       (ghq-path "/root/src/owner/project")
       (ghq-roots
         (append (loop for index below 32
                       collect (format nil "/root/no-match-~D/" index))
                 (list "/root/" "/root/src/")))
       (normalized-ghq-roots (mapcar #'%ghq-normalize-root ghq-roots))
       (ghq-iterations 10000))
  (%benchmark-parser
   "status" #'parse-status status-text
   count
   (lambda (snapshot) (length (status-snapshot-entries snapshot)))
   iterations)
  (%benchmark-parser
   "name-status" #'parse-name-status name-status-text
   count
   #'length
   iterations)
  (%benchmark-parser
   "name-status-lines" #'parse-name-status name-status-line-text
   count
   #'length
   iterations)
  (%benchmark-parser
   "numstat" #'parse-numstat numstat-text
   count
   #'length
   iterations)
  (%benchmark-parser
   "numstat-lines" #'parse-numstat numstat-line-text
   count
   #'length
   iterations)
  (assert (equal (%benchmark-record-groups-subseq commit-fields 9)
                 (%benchmark-record-groups-linear commit-fields 9)))
  (%benchmark-parser
   "record-groups-subseq"
   (lambda (fields) (%benchmark-record-groups-subseq fields 9))
   commit-fields
   group-count
   #'length
   iterations)
  (%benchmark-parser
   "record-groups-linear"
   (lambda (fields) (%benchmark-record-groups-linear fields 9))
   commit-fields
   group-count
   #'length
   iterations)
  (%benchmark-parser
   "commits-grouped"
   #'%benchmark-commits-grouped
   commit-fields
   group-count
   #'length
   iterations)
  (%benchmark-parser
   "commits-vector-direct"
   #'%vcs-commits-from-fields
   commit-fields-vector
   group-count
   #'length
   iterations)
  (%benchmark-parser
   "ghq-specification-normalize-each-call"
   (lambda (path) (%ghq-repository-specification path ghq-roots))
   ghq-path
   1
   (lambda (specification)
     (if (string= specification "owner/project") 1 0))
   ghq-iterations)
  (%benchmark-parser
   "ghq-specification-normalized-roots"
   (lambda (path)
     (%ghq-repository-specification-normalized path normalized-ghq-roots))
   ghq-path
   1
   (lambda (specification)
     (if (string= specification "owner/project") 1 0))
   ghq-iterations))
