(in-package #:vcs-kit)

(define-condition git-error (vcs-error)
  ((repository
    :initarg :repository
    :reader git-error-repository)
   (command
    :initarg :command
    :reader git-error-command)
   (arguments
    :initarg :arguments
    :reader git-error-arguments)
   (result
    :initarg :result
    :initform nil
    :reader git-error-result)
   (cause
    :initarg :cause
    :initform nil
    :reader git-error-cause)
   (directory
    :initarg :directory
    :initform nil
    :reader git-error-directory))
  (:report
   (lambda (condition stream)
     (format stream "Git command failed: ~A~{ ~A~}"
             (git-error-command condition)
             (git-error-arguments condition)))))

(define-condition git-exit-error (git-error)
  ((exit-code
    :initarg :exit-code
    :initform nil
    :reader git-exit-error-exit-code))
  (:report
   (lambda (condition stream)
     (format stream "Git command failed: ~A~{ ~A~}"
             (git-error-command condition)
             (git-error-arguments condition))
     (when (git-exit-error-exit-code condition)
       (format stream " (exit ~D)" (git-exit-error-exit-code condition))))))

(define-condition git-timeout-error (git-error)
  ()
  (:report
   (lambda (condition stream)
     (format stream "Git command timed out: ~A~{ ~A~}"
             (git-error-command condition)
             (git-error-arguments condition)))))

(define-condition git-cancelled-error (git-error)
  ()
  (:report
   (lambda (condition stream)
     (format stream "Git command was cancelled: ~A~{ ~A~}"
             (git-error-command condition)
             (git-error-arguments condition)))))

(define-condition git-launch-error (git-error)
  ()
  (:report
   (lambda (condition stream)
     (format stream "Git could not be launched: ~A~{ ~A~}"
             (git-error-command condition)
             (git-error-arguments condition))
     (%report-command-context stream
                              (git-error-directory condition)
                              (git-error-cause condition)))))

(define-condition git-io-error (git-error)
  ((stream
    :initarg :stream
    :initform nil
    :reader git-io-error-stream))
  (:report
   (lambda (condition stream)
     (format stream "Git command I/O failed: ~A~{ ~A~}"
             (git-error-command condition)
             (git-error-arguments condition))
     (%report-command-context stream
                              (git-error-directory condition)
                              (git-error-cause condition)))))

(define-condition git-parse-error (vcs-error)
  ((format-name
    :initarg :format-name
    :reader git-parse-error-format-name)
   (record
    :initarg :record
    :reader git-parse-error-record)
   (position
    :initarg :position
    :initform nil
    :reader git-parse-error-position))
  (:report
   (lambda (condition stream)
     (format stream "Could not parse Git ~A record~@[ at position ~D~]: ~S"
             (git-parse-error-format-name condition)
             (git-parse-error-position condition)
             (git-parse-error-record condition)))))
