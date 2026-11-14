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

(defun %benchmark-line-diff-check (result expected-status)
  (assert (eq (line-diff-result-status result) expected-status))
  (if (eq expected-status :ok)
      (let ((deleted 0)
            (inserted 0))
        (assert (= (line-diff-result-edit-distance result) 200))
        (assert (line-diff-result-hunks result))
        (dolist (hunk (line-diff-result-hunks result))
          (dolist (line (line-diff-hunk-lines hunk))
            (case (line-diff-line-kind line)
              (:delete (incf deleted))
              (:insert (incf inserted)))))
        (assert (= deleted inserted 100)))
      (progn
        (assert (null (line-diff-result-hunks result)))
        (assert (null (line-diff-result-edit-distance result))))))

(defun %benchmark-line-diff-sample (old new distance expected-status)
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
    (%benchmark-line-diff-check result expected-status)
    ;; Cumulative allocation bounds simultaneous heap use; include input strings
    ;; that were allocated before the measured call.
    (list elapsed-ms
          (+ allocated-bytes
             (sb-ext:primitive-object-size old)
             (sb-ext:primitive-object-size new))
          allocated-bytes
          gc-ms)))

(defun %benchmark-line-diff-report (name distance warmups observations)
  (assert (= 25 (length observations)))
  (let* ((ordered (sort (mapcar #'first observations) #'<))
         (count (length ordered))
         (median (nth (floor count 2) ordered))
         (p95 (nth (1- (ceiling (* 95 count) 100)) ordered))
         (maximum (car (last ordered)))
         (allocation (reduce #'max observations :key #'third))
         (memory (reduce #'max observations :key #'second))
         (gc-ms (reduce #'+ observations :key #'fourth)))
    (format t "~&line-diff ~A lines=20000 distance-limit=~D warmups=~D samples=~D median-ms=~,3F p95-ms=~,3F max-ms=~,3F allocated-bytes-max=~D peak-heap-upper-bound-bytes=~D gc-run-ms-total=~,3F gc-count=unavailable~%"
            name distance warmups count median p95 maximum allocation memory gc-ms)
    (list :case name :distance distance :samples count
          :median-ms median :p95-ms p95 :max-ms maximum
          :allocated-bytes-max allocation :peak-heap-upper-bound-bytes memory
          :gc-run-ms-total gc-ms :gc-count :unavailable)))

(defun run-line-diff-benchmarks (&key (distances '(256 512 1024))
                                        (uptime-text "not collected (Nix sandbox)"))
  "Run the line-diff gate; UPTIME-TEXT is captured by the caller outside the sandbox.
Only the production distance limit 512 is gated; other limits are diagnostics."
  (let ((old (%benchmark-line-text :original))
        (changed (%benchmark-line-text :changed))
        (different (%benchmark-line-text :different))
        (samples 25)
        (warmups 2)
        (reports nil))
    (assert (= 20000 (count #\Newline old) (count #\Newline changed)
               (count #\Newline different)))
    (assert distances)
    (format t "~&line-diff uptime=~A~%" uptime-text)
    (dolist (distance distances)
      (let ((small nil)
            (large nil))
        (dotimes (trial (+ warmups samples))
          (dolist (kind (if (evenp trial) '(:ok :too-large) '(:too-large :ok)))
            (let ((observation
                    (%benchmark-line-diff-sample
                     old (if (eq kind :ok) changed different) distance kind)))
              (when (>= trial warmups)
                (if (eq kind :ok)
                    (push observation small)
                    (push observation large))))))
        (let ((small-report (%benchmark-line-diff-report
                             "100-substitutions" distance warmups small))
              (large-report (%benchmark-line-diff-report
                             "all-different-cutoff" distance warmups large)))
          (push small-report reports)
          (push large-report reports)
          ;; Print both workloads before any assertion so a failed gate retains
          ;; the cutoff and allocation diagnostics as well as the sparse result.
          (when (= distance 512)
            (dolist (report (list small-report large-report))
              (assert (<= (getf report :p95-ms)
                          (if (string= (getf report :case) "100-substitutions") 100 500)))
              (assert (<= (getf report :peak-heap-upper-bound-bytes)
                          (* 32 1024 1024))))))))
    (nreverse reports)))
