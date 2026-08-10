(in-package #:vcs-kit/test)

(defmacro %expect-condition (condition-type &body body)
  `(let ((caught nil))
     (handler-case
         (progn ,@body)
       (,condition-type (condition)
         (setf caught condition)))
     (expect caught :to-be-truthy)
     caught))

(defun %join-nul (&rest records)
  (with-output-to-string (stream)
    (dolist (record records)
      (write-string record stream)
      (write-char #\Null stream))))

(defun %join-lines (&rest records)
  (with-output-to-string (stream)
    (dolist (record records)
      (write-string record stream)
      (write-char #\Newline stream))))

(defun %temporary-test-directory ()
  (let ((directory
          (merge-pathnames
           (format nil "cl-vcs-kit-~36R/" (random (expt 2 60)))
           (uiop:temporary-directory))))
    (ensure-directories-exist directory)
    directory))

(defun %write-test-file (directory name contents)
  (let ((path (merge-pathnames name (uiop:ensure-directory-pathname directory))))
    (with-open-file (stream path
                            :direction :output
                            :if-exists :supersede
                            :if-does-not-exist :create
                            :external-format :utf-8)
      (write-string contents stream))
    path))

(defun %program-path (program)
  program)

(defun %fake-result (&key
                       (program "test")
                       (arguments nil)
                       (status :exited)
                       (exit-code 0)
                       (stdout "")
                       (stderr "")
                       (timed-out-p nil)
                       (cancelled-p nil)
                       signal)
  (process-kit:make-process-result
   :program program
   :arguments arguments
   :pid 1
   :status status
   :duration-seconds 0d0
   :exit-code exit-code
   :stdout stdout
   :stderr stderr
   :timed-out-p timed-out-p
   :cancelled-p cancelled-p
   :signal signal))

(defun %ghq-available-p ()
  (handler-case
      (progn
        (run-ghq "--version" nil :timeout 5d0)
        t)
    (ghq-launch-error () nil)))

(defmacro %with-temporary-repository ((variable) &body body)
  `(let ((directory (%temporary-test-directory)))
     (unwind-protect
          (progn
            (git-init directory :initial-branch "main")
            (let ((,variable (open-repository directory)))
              ,@body))
       (uiop:delete-directory-tree directory
                                   :validate t
                                   :if-does-not-exist :ignore))))
