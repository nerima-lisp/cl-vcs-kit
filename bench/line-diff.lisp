(defpackage #:vcs-kit/benchmark (:use #:cl #:vcs-kit) (:export #:run-line-diff-benchmarks)) (in-package #:vcs-kit/benchmark)

(defun %benchmark-line-text (variant)
  (with-output-to-string (stream)
    (loop for index below 20000
          do (format stream "~A-~D~%"
                     (ecase variant
                       (:original "line")
                       (:changed (if (zerop (mod index 200)) "changed" "line"))
                       (:different "other"))
                     index))))

(defun %benchmark-repeated-line-text (changed-p)
  (with-output-to-string (stream)
    (loop for index below 20000
          do (write-line (cond ((and changed-p (zerop (mod index 200))) "changed")
                               ((zerop (mod index 10)) "repeat")
                               (t ""))
                         stream))))

(defun %benchmark-terminated-lines (text)
  (loop for start = 0 then (1+ end)
        for end = (position #\Newline text :start start)
        while end collect (subseq text start end)))

(defun %benchmark-blank-line-text (changed-count)
  (let ((positions (loop for change below changed-count
                         collect (floor (* change 20000) changed-count))))
    (with-output-to-string (stream)
      (dotimes (index 20000)
        (if (eql index (first positions))
            (progn (pop positions) (write-line "changed" stream))
            (terpri stream))))))

(defun %benchmark-check-blank-fixture (old new changed-count)
  (let ((old-lines (%benchmark-terminated-lines old))
        (new-lines (%benchmark-terminated-lines new))
        (positions (loop for change below changed-count
                         collect (floor (* change 20000) changed-count))))
    (assert (= 20000 (length old-lines) (length new-lines)))
    (assert (every (lambda (line) (string= line "")) old-lines))
    (assert (= changed-count (count "changed" new-lines :test #'string=)))
    (assert (loop for line in new-lines for index from 0
                  always (string= line (if (member index positions) "changed" ""))))
    ;; Every sentinel is absent from OLD, bounding the LCS by N-K. Removing
    ;; them leaves an all-blank witness of that length, so distance is 2K.
    (let ((witness (remove "changed" new-lines :test #'string=)))
      (assert (= (- 20000 changed-count) (length witness)))
      (assert (equal witness (nthcdr changed-count old-lines))))))

(defun %benchmark-check-repeated-fixture (old new)
  (let* ((old-lines (%benchmark-terminated-lines old))
         (new-lines (%benchmark-terminated-lines new))
         (witness (loop for line in old-lines for index from 0
                        unless (zerop (mod index 200)) collect line)))
    (assert (= 20000 (length old-lines) (length new-lines)))
    (assert (= 18000 (count "" old-lines :test #'string=)))
    (assert (every (lambda (line) (member line '("" "repeat") :test #'string=)) old-lines))
    (assert (= 100 (count "changed" new-lines :test #'string=)))
    (assert (loop for old-line in old-lines for new-line in new-lines for index from 0
                  always (if (zerop (mod index 200))
                             (string= new-line "changed")
                             (string= old-line new-line))))
    ;; The 100 new sentinels cannot match any old line, bounding the LCS by
    ;; 19,900. This equal subsequence attains it, proving edit distance 200.
    (assert (= 19900 (length witness)))
    (assert (equal witness (remove "changed" new-lines :test #'string=)))))

(defun %benchmark-line-diff-check (result expected-status changed-count)
  (assert (eq (line-diff-result-status result) expected-status))
  (if (eq expected-status :ok)
      (let ((deleted 0) (inserted 0))
        (assert (= (line-diff-result-edit-distance result) (* 2 changed-count)))
        (assert (line-diff-result-hunks result))
        (dolist (hunk (line-diff-result-hunks result))
          (dolist (line (line-diff-hunk-lines hunk))
            (case (line-diff-line-kind line)
              (:delete (incf deleted))
              (:insert (incf inserted)))))
        (assert (= deleted inserted changed-count)))
      (progn
        (assert (null (line-diff-result-hunks result)))
        (assert (null (line-diff-result-edit-distance result))))))

(defun %benchmark-line-diff-sample (old new distance expected-status changed-count)
  (sb-ext:gc :full t)
  (let* ((start-bytes (sb-ext:get-bytes-consed))
         (start-gc-time sb-ext:*gc-run-time*)
         (start-time (get-internal-real-time))
         (result (compute-line-diff old new :max-edit-distance distance))
         (elapsed-ms (* 1000.0d0
                        (/ (- (get-internal-real-time) start-time)
                           internal-time-units-per-second)))
         (allocated-bytes (- (sb-ext:get-bytes-consed) start-bytes))
         (gc-ms (* 1000.0d0
                   (/ (- sb-ext:*gc-run-time* start-gc-time)
                      internal-time-units-per-second))))
    (%benchmark-line-diff-check result expected-status changed-count)
    ;; Cumulative allocation bounds simultaneous heap use; include input strings
    ;; that were allocated before the measured call.
    (list elapsed-ms
          (+ allocated-bytes
             (sb-ext:primitive-object-size old)
             (sb-ext:primitive-object-size new))
          allocated-bytes gc-ms
          (line-diff-result-edit-distance result)
          (line-diff-result-status result))))

(defun %benchmark-line-diff-report (fixture distance warmups observations)
  (assert (= 25 (length observations)))
  (let* ((ordered (sort (mapcar #'first observations) #'<))
         (count (length ordered))
         (median (nth (floor count 2) ordered))
         (p95 (nth (1- (ceiling (* 95 count) 100)) ordered))
         (maximum (car (last ordered)))
         (allocation (reduce #'max observations :key #'third))
         (memory (reduce #'max observations :key #'second))
         (gc-ms (reduce #'+ observations :key #'fourth))
         (achieved-distance (fifth (first observations)))
         (result-status (sixth (first observations))))
    (format t "~&line-diff ~A lines=20000 distance-limit=~D warmups=~D samples=~D median-ms=~,3F p95-ms=~,3F max-ms=~,3F allocated-bytes-max=~D peak-heap-upper-bound-bytes=~D gc-run-ms-total=~,3F gc-count=unavailable minimal-distance=~D result-status=~A result-edit-distance=~A~%"
            (getf fixture :name) distance warmups count median p95 maximum allocation memory gc-ms
            (* 2 (getf fixture :changes)) result-status achieved-distance)
    (list :case (getf fixture :name) :distance distance :samples count
          :median-ms median :p95-ms p95 :max-ms maximum
          :allocated-bytes-max allocation :peak-heap-upper-bound-bytes memory
          :gc-run-ms-total gc-ms :gc-count :unavailable
          :minimal-distance (* 2 (getf fixture :changes))
          :result-status result-status :edit-distance achieved-distance
          :budget-ms (getf fixture :budget-ms))))

(defun run-line-diff-benchmarks (&key (distances '(512 256 1024))
                                        (uptime-text "not collected (caller did not supply uptime)"))
  "Run the line-diff gate; UPTIME-TEXT is captured by the caller.
The production limit 512 runs first and is gated; other limits are diagnostics."
  (let* ((old (%benchmark-line-text :original))
         (repeated (%benchmark-repeated-line-text nil))
         (blank (%benchmark-blank-line-text 0))
         (fixtures
           (list (list :name "100-substitutions" :old old
                       :new (%benchmark-line-text :changed) :changes 100 :budget-ms 100)
                 (list :name "100-repetitive-substitutions" :old repeated
                       :new (%benchmark-repeated-line-text t) :changes 100 :budget-ms 100)
                 (list :name "100-blank-substitutions" :old blank
                       :new (%benchmark-blank-line-text 100) :changes 100 :budget-ms 100 :blank t)
                 (list :name "256-blank-substitutions" :old blank
                       :new (%benchmark-blank-line-text 256) :changes 256 :budget-ms 100 :blank t)
                 (list :name "all-different-cutoff" :old old
                       :new (%benchmark-line-text :different) :changes 20000 :budget-ms 500)))
         (samples 25)
         (warmups 2)
         (reports nil))
    (dolist (fixture fixtures)
      (assert (= 20000 (count #\Newline (getf fixture :old))
                 (count #\Newline (getf fixture :new))))
      (when (getf fixture :blank)
        (%benchmark-check-blank-fixture (getf fixture :old) (getf fixture :new)
                                       (getf fixture :changes))))
    (%benchmark-check-repeated-fixture repeated (getf (second fixtures) :new))
    (assert distances)
    (format t "~&line-diff uptime=~A~%" uptime-text)
    (dolist (distance distances)
      (let ((observations (mapcar (lambda (fixture) (cons fixture nil)) fixtures)))
        (dotimes (trial (+ warmups samples))
          (dolist (fixture (loop for offset below (length fixtures)
                                 collect (nth (mod (+ trial offset) (length fixtures)) fixtures)))
            (let ((observation
                    (%benchmark-line-diff-sample
                     (getf fixture :old) (getf fixture :new) distance
                     (if (> (* 2 (getf fixture :changes)) distance) :too-large :ok)
                     (getf fixture :changes))))
              (when (>= trial warmups)
                (push observation (cdr (assoc fixture observations :test #'eq)))))))
        (let ((current-reports
                (mapcar (lambda (fixture)
                          (%benchmark-line-diff-report fixture distance warmups
                                                       (cdr (assoc fixture observations :test #'eq))))
                        fixtures)))
          (dolist (report current-reports) (push report reports))
          ;; Print every workload before asserting so both blank cases survive
          ;; in the log even if one budget fails.
          (when (= distance 512)
            (dolist (report current-reports)
              (assert (<= (getf report :p95-ms) (getf report :budget-ms)))
              (assert (<= (getf report :peak-heap-upper-bound-bytes)
                          (* 32 1024 1024))))))))
    (nreverse reports)))
