(in-package #:vcs-kit)

(defun %run-vcs-standalone (backend operation arguments
                            &key executable timeout environment directory
                              (environment-update nil)
                              (input +unspecified-option+)
                              (output :capture)
                              (error-output :capture)
                              (result-type :string)
                              (external-format :utf-8)
                              (max-output-characters +unspecified-option+)
                              cancellation-token
                              (grace-period +unspecified-option+)
                              (drain-timeout-seconds +unspecified-option+)
                              (decoding-error-policy :replace))
  (let ((command (%vcs-required-command backend operation nil)))
    (run-vcs/checked nil command arguments
                     :executable (or executable
                                     (vcs-backend-executable backend))
                     :timeout timeout
                     :environment environment
                     :environment-update environment-update
                     :directory directory
                     :input input
                     :output output
                     :error-output error-output
                     :result-type result-type
                     :external-format external-format
                     :max-output-characters max-output-characters
                     :cancellation-token cancellation-token
                     :grace-period grace-period
                     :drain-timeout-seconds drain-timeout-seconds
                     :decoding-error-policy decoding-error-policy)))

(defun vcs-init (directory &key
                           (backend :git)
                           (arguments nil)
                           executable
                           (timeout +unspecified-timeout+)
                           (environment +unspecified-option+)
                           (environment-update nil)
                           (input +unspecified-option+)
                           (output :capture)
                           (error-output :capture)
                           (result-type :string)
                           (external-format :utf-8)
                           (max-output-characters +unspecified-option+)
                           cancellation-token
                           (grace-period +unspecified-option+)
                           (drain-timeout-seconds +unspecified-option+)
                           (decoding-error-policy :replace))
  (check-type arguments list)
  (let ((backend (find-vcs-backend backend))
        (target (%directory-string directory)))
    (%run-vcs-standalone backend :init
                         (append arguments (list target))
                         :executable executable
                         :timeout timeout
                         :environment environment
                         :environment-update environment-update
                         :directory (%vcs-parent-directory-string target)
                         :input input
                         :output output
                         :error-output error-output
                         :result-type result-type
                         :external-format external-format
                         :max-output-characters max-output-characters
                         :cancellation-token cancellation-token
                         :grace-period grace-period
                         :drain-timeout-seconds drain-timeout-seconds
                         :decoding-error-policy decoding-error-policy)))

(defun vcs-clone (source directory &key
                                (backend :git)
                                (arguments nil)
                                executable
                                (timeout +unspecified-timeout+)
                                (environment +unspecified-option+)
                                (environment-update nil)
                                (input +unspecified-option+)
                                (output :capture)
                                (error-output :capture)
                                (result-type :string)
                                (external-format :utf-8)
                                (max-output-characters +unspecified-option+)
                                cancellation-token
                                (grace-period +unspecified-option+)
                                (drain-timeout-seconds +unspecified-option+)
                                (decoding-error-policy :replace))
  (check-type source (or string pathname))
  (check-type arguments list)
  (let ((backend (find-vcs-backend backend))
        (target (%directory-string directory)))
    (%run-vcs-standalone backend :clone
                         (append arguments (list source target))
                         :executable executable
                         :timeout timeout
                         :environment environment
                         :environment-update environment-update
                         :directory (%vcs-parent-directory-string target)
                         :input input
                         :output output
                         :error-output error-output
                         :result-type result-type
                         :external-format external-format
                         :max-output-characters max-output-characters
                         :cancellation-token cancellation-token
                         :grace-period grace-period
                         :drain-timeout-seconds drain-timeout-seconds
                         :decoding-error-policy decoding-error-policy)))
