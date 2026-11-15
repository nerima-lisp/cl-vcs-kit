(in-package #:vcs-kit)

(defun %line-diff-split (text)
  (let* ((count (+ (count #\Newline text)
                   (if (and (plusp (length text))
                            (char/= (char text (1- (length text))) #\Newline))
                       1 0)))
         (lines (make-array count))
         (start 0))
    (dotimes (index count lines)
      (let ((end (position #\Newline text :start start)))
        (setf (aref lines index)
              (%make-line-diff-line :context (subseq text start end) (not (null end))))
        (when end (setf start (1+ end)))))))

(defun %line-diff-tokens (lines identifiers)
  (let ((tokens (make-array (length lines) :element-type 'fixnum)))
    (dotimes (index (length lines) tokens)
      (let* ((line (aref lines index))
             (text (line-diff-line-text line))
             (identifier (or (gethash text identifiers)
                             (setf (gethash text identifiers)
                                   (hash-table-count identifiers)))))
        ;; The low bit keeps identical text with and without a final LF distinct.
        (setf (aref tokens index)
              (logior (ash identifier 1)
                      (if (line-diff-line-newline-p line) 1 0)))))))

(defun %line-diff-predecessor (frontier diagonal distance)
  (let ((index (ash (+ diagonal distance) -1)))
    (if (or (= diagonal (- distance))
            (and (/= diagonal distance)
                 (< (aref frontier (1- index)) (aref frontier index))))
        (1+ diagonal)
        (1- diagonal))))

(defun %line-diff-backtrack (old new trace distance)
  (let ((x (length old))
        (y (length new))
        (lines nil))
    (loop for step from distance downto 1 do
      (let* ((previous (aref trace (1- step)))
             (diagonal (%line-diff-predecessor previous (- x y) step))
             (previous-x (aref previous (ash (+ diagonal step -1) -1)))
             (previous-y (- previous-x diagonal)))
        (loop while (and (> x previous-x) (> y previous-y)) do
          (push (aref old (decf x)) lines)
          (decf y))
        (let* ((insert-p (= x previous-x))
               (line (if insert-p (aref new (decf y)) (aref old (decf x)))))
          (push (%make-line-diff-line (if insert-p :insert :delete)
                                      (line-diff-line-text line)
                                      (line-diff-line-newline-p line))
                lines))))
    (loop while (plusp x) do
      (push (aref old (decf x)) lines))
    (coerce lines 'vector)))

(defun %line-diff-search (old new limit)
  (let* ((old-count (length old))
         (new-count (length new))
         (bound (min limit (+ old-count new-count))))
    (when (> (abs (- old-count new-count)) bound)
      (return-from %line-diff-search (values nil nil)))
    ;; The seed is the distance -1 layer at diagonal 1, before any input.
    (let* ((identifiers (make-hash-table :test #'equal :size (+ old-count new-count)))
           (old-tokens (%line-diff-tokens old identifiers))
           (new-tokens (%line-diff-tokens new identifiers))
           (previous (make-array 1 :element-type 'fixnum :initial-element 0))
           (trace (make-array (1+ bound))))
      (declare (type (simple-array fixnum (*)) old-tokens new-tokens))
      (loop for distance from 0 to bound do
        (let ((current (make-array (1+ distance) :element-type 'fixnum)))
          (loop for diagonal from (- distance) to distance by 2
                for index from 0 do
            (let* ((predecessor (%line-diff-predecessor previous diagonal distance))
                   (x (+ (aref previous (ash (+ predecessor distance -1) -1))
                         (if (< predecessor diagonal) 1 0)))
                   (y (- x diagonal)))
              (loop while (and (< x old-count) (< y new-count)
                               (= (aref old-tokens x) (aref new-tokens y)))
                    do (incf x) (incf y))
              (setf (aref current index) x)
              (when (and (>= x old-count) (>= y new-count))
                (return-from %line-diff-search
                  (values (%line-diff-backtrack old new trace distance) distance)))))
          ;; Only diagonals -d, -d+2, ..., d are reachable in layer d.
          (setf (aref trace distance) current
                previous current)))
      (values nil nil))))

(defun %line-diff-context-p (line)
  (eq (line-diff-line-kind line) :context))

(defun %line-diff-hunks (lines context)
  (let* ((count (length lines))
         (old-positions (make-array (1+ count) :element-type 'fixnum :initial-element 0))
         (new-positions (make-array (1+ count) :element-type 'fixnum :initial-element 0))
         (changes nil)
         (hunks nil))
    (dotimes (index count)
      (let ((kind (line-diff-line-kind (aref lines index))))
        (setf (aref old-positions (1+ index))
              (+ (aref old-positions index) (if (eq kind :insert) 0 1))
              (aref new-positions (1+ index))
              (+ (aref new-positions index) (if (eq kind :delete) 0 1)))
        (unless (%line-diff-context-p (aref lines index))
          (push index changes))))
    (setf changes (nreverse changes))
    (loop while changes do
      (let* ((first (pop changes))
             (last first)
             (start (max 0 (- first context))))
        (loop while (and changes (<= (first changes) (+ last (* 2 context) 1)))
              do (setf last (pop changes)))
        (let* ((end (min count (+ last context 1)))
               (old-before (aref old-positions start))
               (new-before (aref new-positions start))
               (old-count (- (aref old-positions end) old-before))
               (new-count (- (aref new-positions end) new-before)))
          (push (%make-line-diff-hunk
                 :old-start (+ old-before (if (zerop old-count) 0 1))
                 :old-count old-count
                 :new-start (+ new-before (if (zerop new-count) 0 1))
                 :new-count new-count
                 :lines (loop for index from start below end collect (aref lines index)))
                hunks))))
    (nreverse hunks)))

(defun %line-diff-path-label-p (path)
  (or (null path)
      (and (stringp path)
           (not (find #\Newline path))
           (not (find #\Return path)))))

(defun compute-line-diff (old-text new-text &key old-path new-path (context 3) (max-edit-distance 512))
  "Compare two strings without I/O, returning a LINE-DIFF-RESULT.
The default edit-distance limit is 512 insertions plus deletions; replacements
cost two. A distance above the limit returns :TOO-LARGE with no partial hunks
or edit distance. The bound is deterministic and never uses elapsed time.
CONTEXT defaults to three lines. LF separates lines; CR remains part of the
text. A final newline participates in equality. Optional path labels must be
strings without LF or CR, or NIL; other values signal TYPE-ERROR.
Hunk starts are one-based except zero-length ranges, which name the preceding
line (zero at the beginning). Inputs are not modified.
For D = min(MAX-EDIT-DISTANCE, old line count + new line count), temporary
storage is O(total input characters + D^2). Trace layer d retains only its d+1
reachable diagonals, for at most (D+1)(D+2)/2 fixnum entries."
  (check-type old-text string)
  (check-type new-text string)
  (check-type old-path (satisfies %line-diff-path-label-p))
  (check-type new-path (satisfies %line-diff-path-label-p))
  (check-type context (integer 0 *))
  (check-type max-edit-distance (integer 0 *))
  (multiple-value-bind (lines distance)
      (%line-diff-search (%line-diff-split old-text) (%line-diff-split new-text) max-edit-distance)
    (%make-line-diff-result :status (if distance :ok :too-large)
                            :hunks (when distance (%line-diff-hunks lines context))
                            :old-path old-path :new-path new-path
                            :edit-distance distance)))

(defun %line-diff-write-range (start count stream)
  (format stream "~D" start)
  (unless (= count 1) (format stream ",~D" count)))

(defun format-unified-diff (result)
  "Format successful RESULT as unified text; identical inputs produce an empty string.
Omitted path labels are a and b. Labels containing LF or CR signal TYPE-ERROR,
including labels changed through result accessors. A :TOO-LARGE result signals
an error."
  (check-type result line-diff-result)
  (check-type (line-diff-result-old-path result) (satisfies %line-diff-path-label-p))
  (check-type (line-diff-result-new-path result) (satisfies %line-diff-path-label-p))
  (unless (eq (line-diff-result-status result) :ok)
    (error "The line difference exceeds the edit-distance limit."))
  (with-output-to-string (stream)
    (when (line-diff-result-hunks result)
      (format stream "--- ~A~%+++ ~A~%"
              (or (line-diff-result-old-path result) "a")
              (or (line-diff-result-new-path result) "b"))
      (dolist (hunk (line-diff-result-hunks result))
        (write-string "@@ -" stream)
        (%line-diff-write-range (line-diff-hunk-old-start hunk) (line-diff-hunk-old-count hunk) stream)
        (write-string " +" stream)
        (%line-diff-write-range (line-diff-hunk-new-start hunk) (line-diff-hunk-new-count hunk) stream)
        (write-line " @@" stream)
        (dolist (line (line-diff-hunk-lines hunk))
          (write-char (ecase (line-diff-line-kind line)
                        (:context #\Space) (:delete #\-) (:insert #\+))
                      stream)
          (write-line (line-diff-line-text line) stream)
          (unless (line-diff-line-newline-p line)
            (write-line "\\ No newline at end of file" stream)))))))
