(in-package #:vcs-kit/test)

(describe "pure line differences"
  (it "has no hunks for empty or identical inputs"
    (dolist (text (list "" "same" (format nil "same~%")))
      (let ((result (compute-line-diff text text)))
        (expect (line-diff-result-status result) :to-be :ok)
        (expect (line-diff-result-edit-distance result) :to-equal 0)
        (expect (line-diff-result-hunks result) :to-equal nil)
        (expect (format-unified-diff result) :to-equal ""))))

  (it "represents an insertion into an empty file"
    (let* ((result (compute-line-diff "" (format nil "new~%")))
           (hunk (first (line-diff-result-hunks result)))
           (line (first (line-diff-hunk-lines hunk))))
      (expect (line-diff-result-p result) :to-be-truthy)
      (expect (line-diff-hunk-p hunk) :to-be-truthy)
      (expect (line-diff-line-p line) :to-be-truthy)
      (expect (line-diff-hunk-old-start hunk) :to-equal 0)
      (expect (line-diff-hunk-old-count hunk) :to-equal 0)
      (expect (line-diff-hunk-new-start hunk) :to-equal 1)
      (expect (line-diff-hunk-new-count hunk) :to-equal 1)
      (expect (line-diff-line-kind line) :to-be :insert)
      (expect (line-diff-line-text line) :to-equal "new")
      (expect (line-diff-line-newline-p line) :to-be-truthy)
      (expect (format-unified-diff result) :to-equal
              (format nil "--- a~%+++ b~%@@ -0,0 +1 @@~%+new~%"))))

  (it "represents deletion into an empty file and optional paths"
    (let ((result (compute-line-diff "old" "" :old-path "before" :new-path "after")))
      (expect (line-diff-result-old-path result) :to-equal "before")
      (expect (line-diff-result-new-path result) :to-equal "after")
      (expect (format-unified-diff result) :to-equal
              (format nil "--- before~%+++ after~%@@ -1 +0,0 @@~%-old~%\\ No newline at end of file~%"))))

  (it "compares final newlines and marks each affected side"
    (expect (format-unified-diff (compute-line-diff "same" (format nil "same~%")))
            :to-equal
            (format nil "--- a~%+++ b~%@@ -1 +1 @@~%-same~%\\ No newline at end of file~%+same~%"))
    (expect (format-unified-diff (compute-line-diff "old" "new"))
            :to-equal
            (format nil "--- a~%+++ b~%@@ -1 +1 @@~%-old~%\\ No newline at end of file~%+new~%\\ No newline at end of file~%")))

  (it "uses three context lines by default"
    (let* ((old (format nil "0~%1~%2~%3~%4~%5~%6~%7~%8~%"))
           (new (format nil "0~%1~%2~%3~%x~%5~%6~%7~%8~%"))
           (result (compute-line-diff old new))
           (hunk (first (line-diff-result-hunks result))))
      (expect (line-diff-hunk-old-start hunk) :to-equal 2)
      (expect (line-diff-hunk-old-count hunk) :to-equal 7)
      (expect (line-diff-hunk-new-count hunk) :to-equal 7)
      (expect (line-diff-line-kind (first (line-diff-hunk-lines hunk))) :to-be :context)
      (expect (format-unified-diff result) :to-equal
              (format nil "--- a~%+++ b~%@@ -2,7 +2,7 @@~% 1~% 2~% 3~%-4~%+x~% 5~% 6~% 7~%"))))

  (it "separates distant changes and merges touching context"
    (let ((old (format nil "a~%b~%c~%d~%e~%f~%g~%"))
          (new (format nil "A~%b~%c~%d~%e~%f~%G~%")))
      (expect (length (line-diff-result-hunks (compute-line-diff old new :context 1)))
              :to-equal 2)
      (expect (length (line-diff-result-hunks (compute-line-diff old new :context 3)))
              :to-equal 1)))

  (it "supports zero context and insertions at the end"
    (expect (format-unified-diff
             (compute-line-diff (format nil "a~%") (format nil "a~%b~%") :context 0))
            :to-equal (format nil "--- a~%+++ b~%@@ -1,0 +2 @@~%+b~%")))

  (it "retains empty lines, carriage returns and Unicode text"
    (let* ((result (compute-line-diff "" (format nil "~%猫~C~%" #\Return)))
           (lines (line-diff-hunk-lines (first (line-diff-result-hunks result)))))
      (expect (mapcar #'line-diff-line-text lines)
              :to-equal (list "" (format nil "猫~C" #\Return)))))

  (it "returns too-large only when the edit-distance bound is exceeded"
    (let ((result (compute-line-diff "a" "b" :max-edit-distance 1)))
      (expect (line-diff-result-status result) :to-be :too-large)
      (expect (line-diff-result-hunks result) :to-equal nil)
      (expect (line-diff-result-edit-distance result) :to-be nil)
      (%expect-condition error (format-unified-diff result)))
    (expect (line-diff-result-status (compute-line-diff "a" "b" :max-edit-distance 2))
            :to-be :ok)
    (expect (line-diff-result-status (compute-line-diff "" "a" :max-edit-distance 0))
            :to-be :too-large)
    (expect (line-diff-result-status (compute-line-diff "same" "same" :max-edit-distance 0))
            :to-be :ok))

  (it "rejects invalid argument types"
    (%expect-condition type-error (compute-line-diff 1 ""))
    (%expect-condition type-error (compute-line-diff "" nil))
    (%expect-condition type-error (compute-line-diff "" "" :context -1))
    (%expect-condition type-error (compute-line-diff "" "" :max-edit-distance -1))
    (%expect-condition type-error (compute-line-diff "" "" :old-path 1))
    (%expect-condition type-error (compute-line-diff "" "" :new-path 1)))

  (it "reconstructs both inputs for every short binary line sequence"
    (let ((inputs (list "")))
      (loop for length from 1 to 4 do
        (dotimes (bits (ash 1 length))
          (push (with-output-to-string (stream)
                  (dotimes (index length)
                    (write-line (if (logbitp index bits) "a" "b") stream)))
                inputs)))
      (dolist (old inputs)
        (dolist (new inputs)
          (let* ((result (compute-line-diff old new :context 8))
                 (lines (and (line-diff-result-hunks result)
                             (line-diff-hunk-lines (first (line-diff-result-hunks result))))))
            (if (string= old new)
                (expect lines :to-equal nil)
                (dolist (side '(:old :new))
                  (expect
                   (with-output-to-string (stream)
                     (dolist (line lines)
                       (unless (eq (line-diff-line-kind line)
                                   (if (eq side :old) :insert :delete))
                         (write-string (line-diff-line-text line) stream)
                         (when (line-diff-line-newline-p line)
                           (terpri stream)))))
                   :to-equal (if (eq side :old) old new))))))))))
