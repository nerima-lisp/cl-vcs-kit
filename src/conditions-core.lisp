(in-package #:vcs-kit)

(define-condition vcs-error (error)
  ()
  (:report
   (lambda (condition stream)
     (declare (ignore condition))
     (write-string "VCS operation failed" stream))))

(defun %report-command-context (stream directory cause)
  (when directory
    (format stream " in ~A" directory))
  (when cause
    (format stream ": ~A" cause)))

(define-condition vcs-argument-error (vcs-error)
  ((argument
    :initarg :argument
    :reader vcs-argument-error-argument)
   (position
    :initarg :position
    :initform nil
    :reader vcs-argument-error-position)
   (reason
    :initarg :reason
    :initform "invalid command argument"
    :reader vcs-argument-error-reason))
  (:report
   (lambda (condition stream)
     (format stream "Invalid VCS command argument~@[ at position ~D~]: ~S (~A)"
             (vcs-argument-error-position condition)
             (vcs-argument-error-argument condition)
             (vcs-argument-error-reason condition)))))
