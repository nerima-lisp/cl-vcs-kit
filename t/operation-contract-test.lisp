(in-package #:vcs-kit/test)

(describe "operation contracts"
  (it "keeps deterministic backend command names snapshot-stable"
    (let* ((directory (merge-pathnames
                       (format nil "cl-vcs-kit-snapshot-~A/" (gensym))
                       (host-kit:temporary-directory)))
           (file (merge-pathnames "operations.snapshots" directory)))
      (ensure-directories-exist directory)
      (unwind-protect
           (progn
             (with-open-file (stream file
                                     :direction :output
                                     :if-exists :supersede
                                     :if-does-not-exist :create)
               (write '(("git/status" . "\"status\""))
                      :stream stream))
             (let ((cl-weave::*snapshot-directory* directory)
                   (cl-weave::*snapshot-file-name* "operations.snapshots"))
               (expect (vcs-operation-command :git :status)
                       :to-match-snapshot
                       "git/status")))
        (ignore-errors (delete-file file))))))
