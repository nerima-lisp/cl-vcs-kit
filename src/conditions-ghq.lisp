(in-package #:vcs-kit)

(define-condition ghq-error (vcs-error)
  ((command
    :initarg :command
    :reader ghq-error-command)
   (arguments
    :initarg :arguments
    :reader ghq-error-arguments)
   (result
    :initarg :result
    :initform nil
    :reader ghq-error-result)
   (cause
    :initarg :cause
    :initform nil
    :reader ghq-error-cause)
   (directory
    :initarg :directory
    :initform nil
    :reader ghq-error-directory))
  (:report
   (lambda (condition stream)
     (format stream "GHQ command failed: ~A~{ ~A~}"
             (ghq-error-command condition)
             (ghq-error-arguments condition)))))

(define-condition ghq-exit-error (ghq-error)
  ((exit-code
    :initarg :exit-code
    :initform nil
    :reader ghq-exit-error-exit-code))
  (:report
   (lambda (condition stream)
     (format stream "GHQ command failed: ~A~{ ~A~}"
             (ghq-error-command condition)
             (ghq-error-arguments condition))
     (when (ghq-exit-error-exit-code condition)
       (format stream " (exit ~D)" (ghq-exit-error-exit-code condition))))))

(define-condition ghq-timeout-error (ghq-error)
  ()
  (:report
   (lambda (condition stream)
     (format stream "GHQ command timed out: ~A~{ ~A~}"
             (ghq-error-command condition)
             (ghq-error-arguments condition)))))

(define-condition ghq-cancelled-error (ghq-error)
  ()
  (:report
   (lambda (condition stream)
     (format stream "GHQ command was cancelled: ~A~{ ~A~}"
             (ghq-error-command condition)
             (ghq-error-arguments condition)))))

(define-condition ghq-launch-error (ghq-error)
  ()
  (:report
   (lambda (condition stream)
     (format stream "GHQ could not be launched: ~A~{ ~A~}"
             (ghq-error-command condition)
             (ghq-error-arguments condition))
     (%report-command-context stream
                              (ghq-error-directory condition)
                              (ghq-error-cause condition)))))

(define-condition ghq-io-error (ghq-error)
  ((stream
    :initarg :stream
    :initform nil
    :reader ghq-io-error-stream))
  (:report
   (lambda (condition stream)
     (format stream "GHQ command I/O failed: ~A~{ ~A~}"
             (ghq-error-command condition)
             (ghq-error-arguments condition))
     (%report-command-context stream
                              (ghq-error-directory condition)
                              (ghq-error-cause condition)))))
