(in-package #:vcs-kit)

(defun %run-vcs-command-async (executable arguments
                               &key
                                 (input +unspecified-option+)
                                 (timeout +default-vcs-timeout+)
                                 (max-output-characters +unspecified-option+)
                                 (grace-period +unspecified-option+)
                                 (drain-timeout-seconds +unspecified-option+)
                                 command-directory
                                 (environment :inherit)
                                 (environment-update nil)
                                 (output :capture)
                                 (error-output :capture)
                                 (result-type :string)
                                 (external-format :utf-8)
                                 (decoding-error-policy :replace)
                                 event-callback)
  "Start EXECUTABLE asynchronously and return process-kit:PROCESS-TASK.

  The returned task owns cancellation."
  (log-kit:log-info *vcs-logger* "run vcs command asynchronously"
                    :executable executable
                    :arguments arguments
                    :directory command-directory
                    :timeout timeout)
  (let ((command (%make-vcs-command executable
                                     arguments
                                     :directory command-directory
                                     :environment environment
                                     :environment-update environment-update
                                     :output output
                                     :error-output error-output
                                     :result-type result-type
                                     :external-format external-format
                                     :decoding-error-policy
                                     decoding-error-policy))
        (options (%vcs-process-options
                  :input input
                  :timeout timeout
                  :max-output-characters max-output-characters
                  :grace-period grace-period
                  :drain-timeout-seconds drain-timeout-seconds
                  :event-callback event-callback)))
    (apply #'process-kit:run-command-async command options)))
