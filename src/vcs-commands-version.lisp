(in-package #:vcs-kit)

(defun vcs-version (&key
                      (backend :git)
                      executable
                      directory
                      (input +unspecified-option+)
                      (output :capture)
                      (error-output :capture)
                      (result-type :string)
                      (external-format :utf-8)
                      (timeout +unspecified-timeout+)
                      (environment +unspecified-option+)
                      (environment-update nil)
                      (max-output-characters +unspecified-option+)
                      cancellation-token
                      (grace-period +unspecified-option+)
                      (drain-timeout-seconds +unspecified-option+)
                      (decoding-error-policy :replace))
  "Return the direct PROCESS-RESULT of BACKEND's version command.

BACKEND is a descriptor or a name/alias designator and defaults to :GIT.
EXECUTABLE defaults to BACKEND's own executable, and the command is BACKEND's
:VERSION mapping or `--version` when it declares none.  The result is not
checked: a non-zero exit status is returned rather than signalled, so the
caller inspects PROCESS-RESULT-EXIT-CODE itself.

Signals VCS-UNKNOWN-BACKEND-ERROR when BACKEND names no registered backend,
VCS-COMMAND-TIMEOUT-ERROR when the timeout elapsed,
VCS-COMMAND-CANCELLED-ERROR when CANCELLATION-TOKEN fired,
VCS-COMMAND-LAUNCH-ERROR when the executable could not be started, and
VCS-COMMAND-IO-ERROR when stream I/O failed.  VCS-ARGUMENT-ERROR is signalled
when BACKEND's resolved executable is empty and when ENVIRONMENT or
ENVIRONMENT-UPDATE is malformed; TYPE-ERROR when EXECUTABLE is neither NIL nor
a string."
  (let* ((backend (find-vcs-backend backend))
         (executable (or executable (vcs-backend-executable backend)))
         (command (or (vcs-operation-command backend :version)
                      "--version")))
    (run-vcs nil command nil
             :executable executable
             :directory directory
             :input input
             :output output
             :error-output error-output
             :result-type result-type
             :external-format external-format
             :timeout timeout
             :environment environment
             :environment-update environment-update
             :max-output-characters max-output-characters
             :cancellation-token cancellation-token
             :grace-period grace-period
             :drain-timeout-seconds drain-timeout-seconds
             :decoding-error-policy decoding-error-policy)))

(defun vcs-version-async (&key
                            (backend :git)
                            executable
                            directory
                            (input +unspecified-option+)
                            (output :capture)
                            (error-output :capture)
                            (result-type :string)
                            (external-format :utf-8)
                            (timeout +unspecified-timeout+)
                            (environment +unspecified-option+)
                            (environment-update nil)
                            (max-output-characters +unspecified-option+)
                            (grace-period +unspecified-option+)
                            (drain-timeout-seconds +unspecified-option+)
                            (decoding-error-policy :replace)
                            event-callback)
  "Start a backend version command and return its process task."
  (let* ((backend (find-vcs-backend backend))
         (executable (or executable (vcs-backend-executable backend)))
         (command (or (vcs-operation-command backend :version)
                      "--version")))
    (run-vcs-async nil command nil
                   :executable executable
                   :directory directory
                   :input input
                   :output output
                   :error-output error-output
                   :result-type result-type
                   :external-format external-format
                   :timeout timeout
                   :environment environment
                   :environment-update environment-update
                   :max-output-characters max-output-characters
                   :grace-period grace-period
                   :drain-timeout-seconds drain-timeout-seconds
                   :decoding-error-policy decoding-error-policy
                   :event-callback event-callback)))
