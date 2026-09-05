(in-package #:vcs-kit)

;; Backend-neutral command failures. Git and GHQ operations keep their
;; backend-specific conditions.
(define-condition vcs-command-error (vcs-error)
  ((repository
    :initarg :repository
    :initform nil
    :reader vcs-command-error-repository)
   (command
    :initarg :command
    :initform nil
    :reader vcs-command-error-command)
   (arguments
    :initarg :arguments
    :initform nil
    :reader vcs-command-error-arguments)
   (result
    :initarg :result
    :initform nil
    :reader vcs-command-error-result)
   (cause
    :initarg :cause
    :initform nil
    :reader vcs-command-error-cause)
   (directory
    :initarg :directory
    :initform nil
    :reader vcs-command-error-directory))
  (:report
   (lambda (condition stream)
     (format stream "VCS command failed: ~A~{ ~A~}"
             (vcs-command-error-command condition)
             (vcs-command-error-arguments condition)))))

(define-condition vcs-command-exit-error (vcs-command-error)
  ((exit-code
    :initarg :exit-code
    :initform nil
    :reader vcs-command-exit-error-exit-code))
  (:report
   (lambda (condition stream)
     (format stream "VCS command failed: ~A~{ ~A~} (exit ~D)"
             (vcs-command-error-command condition)
             (vcs-command-error-arguments condition)
             (vcs-command-exit-error-exit-code condition)))))

(define-condition vcs-command-timeout-error (vcs-command-error)
  ()
  (:report
   (lambda (condition stream)
     (format stream "VCS command timed out: ~A~{ ~A~}"
             (vcs-command-error-command condition)
             (vcs-command-error-arguments condition)))))

(define-condition vcs-command-cancelled-error (vcs-command-error)
  ()
  (:report
   (lambda (condition stream)
     (format stream "VCS command was cancelled: ~A~{ ~A~}"
             (vcs-command-error-command condition)
             (vcs-command-error-arguments condition)))))

(define-condition vcs-command-launch-error (vcs-command-error)
  ()
  (:report
   (lambda (condition stream)
     (format stream "VCS could not be launched: ~A~{ ~A~}"
             (vcs-command-error-command condition)
             (vcs-command-error-arguments condition))
     (%report-command-context stream
                              (vcs-command-error-directory condition)
                              (vcs-command-error-cause condition)))))

(define-condition vcs-command-io-error (vcs-command-error)
  ((stream
    :initarg :stream
    :initform nil
    :reader vcs-command-io-error-stream))
  (:report
   (lambda (condition stream)
     (format stream "VCS command I/O failed: ~A~{ ~A~}"
             (vcs-command-error-command condition)
             (vcs-command-error-arguments condition))
     (%report-command-context stream
                              (vcs-command-error-directory condition)
                              (vcs-command-error-cause condition)))))

(define-condition vcs-backend-error (vcs-error)
  ((backend
    :initarg :backend
    :initform nil
    :reader vcs-backend-error-backend)))

(define-condition vcs-unknown-backend-error (vcs-backend-error)
  ((designator
    :initarg :designator
    :initform nil
    :reader vcs-unknown-backend-error-designator)
   (known-backends
    :initarg :known-backends
    :initform nil
    :reader vcs-unknown-backend-error-known-backends))
  (:report
   (lambda (condition stream)
     (format stream "Unknown VCS backend ~S (known backends: ~{~A~^, ~})"
             (vcs-unknown-backend-error-designator condition)
             (vcs-unknown-backend-error-known-backends condition)))))

(define-condition vcs-backend-registration-error (vcs-backend-error)
  ((designator
    :initarg :designator
    :initform nil
    :reader vcs-backend-registration-error-designator)
   (conflicting-backend
    :initarg :conflicting-backend
    :initform nil
    :reader vcs-backend-registration-error-conflicting-backend))
  (:report
   (lambda (condition stream)
     (format stream "VCS backend designator ~S is already claimed by ~A"
             (vcs-backend-registration-error-designator condition)
             (vcs-backend-name
              (vcs-backend-error-backend condition))))))

(define-condition vcs-backend-detection-error (vcs-backend-error)
  ((directory
    :initarg :directory
    :initform nil
    :reader vcs-backend-detection-error-directory))
  (:report
   (lambda (condition stream)
     (format stream "Could not detect a VCS backend in ~A"
             (vcs-backend-detection-error-directory condition)))))

(define-condition vcs-unsupported-operation-error (vcs-backend-error)
  ((repository
    :initarg :repository
    :initform nil
    :reader vcs-unsupported-operation-error-repository)
   (operation
    :initarg :operation
    :initform nil
    :reader vcs-unsupported-operation-error-operation)
   (capabilities
    :initarg :capabilities
    :initform nil
    :reader vcs-unsupported-operation-error-capabilities))
  (:report
   (lambda (condition stream)
     (format stream "VCS backend ~A does not support operation ~A"
             (vcs-backend-name
              (vcs-backend-error-backend condition))
             (vcs-unsupported-operation-error-operation condition)))))
