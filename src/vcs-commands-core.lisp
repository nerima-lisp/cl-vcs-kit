(in-package #:vcs-kit)

(defun run-vcs (repository command arguments
                &key
                  (executable +unspecified-option+)
                  check
                  (timeout +unspecified-timeout+)
                  (input +unspecified-option+)
                  (environment +unspecified-option+)
                  (environment-update nil)
                  directory
                  (output :capture)
                  (error-output :capture)
                  (result-type :string)
                  (external-format :utf-8)
                  (max-output-characters +unspecified-option+)
                  cancellation-token
                  (grace-period +unspecified-option+)
                  (drain-timeout-seconds +unspecified-option+)
                  (decoding-error-policy :replace))
  "Run a backend command with direct argv execution and typed failures.

COMMAND may be a command string/symbol or a list of command fragments.  The
  raw function is intentionally public: the normalized operation layer cannot
enumerate every native command of every VCS."
  (check-type repository (or null vcs-repository))
  (check-type arguments list)
  (unless (eq executable +unspecified-option+)
    (check-type executable (or null string)))
  (let* ((command-arguments
           (append (if (and (listp command) command)
                       (%argument-strings command)
                       (list (%subcommand-string command 0)))
                   (%argument-strings arguments)))
         (actual-executable (%vcs-effective-executable repository executable))
         (actual-timeout (%vcs-effective-timeout repository timeout))
         (actual-environment (%vcs-effective-environment
                              repository environment))
         (actual-directory (or directory
                               (and repository
                                    (vcs-repository-directory repository)))))
    (check-type actual-executable string)
    (handler-case
        (let ((result
                (%run-vcs-command actual-executable
                                  command-arguments
                                  :input input
                                  :timeout actual-timeout
                                  :max-output-characters max-output-characters
                                  :cancellation-token cancellation-token
                                  :grace-period grace-period
                                  :drain-timeout-seconds drain-timeout-seconds
                                  :command-directory actual-directory
                                  :environment actual-environment
                                  :environment-update environment-update
                                  :output output
                                  :error-output error-output
                                  :result-type result-type
                                  :external-format external-format
                                  :decoding-error-policy decoding-error-policy)))
          (when (or check
                    (process-result-timed-out-p result)
                    (process-result-cancelled-p result))
            (%signal-vcs-failure repository command arguments result))
          result)
      (process-kit:process-launch-error (cause)
        (error 'vcs-command-launch-error
               :repository repository
               :command command
               :arguments arguments
               :directory actual-directory
               :cause cause))
      (process-kit:process-io-error (cause)
        (error 'vcs-command-io-error
               :repository repository
               :command command
               :arguments arguments
               :directory actual-directory
               :stream (process-kit:process-io-error-stream cause)
          :cause cause)))))

(defun run-vcs-async (repository command arguments
                      &key
                        (executable +unspecified-option+)
                        (timeout +unspecified-timeout+)
                        (input +unspecified-option+)
                        (environment +unspecified-option+)
                        (environment-update nil)
                        directory
                        (output :capture)
                        (error-output :capture)
                        (result-type :string)
                        (external-format :utf-8)
                        (max-output-characters +unspecified-option+)
                        (grace-period +unspecified-option+)
                        (drain-timeout-seconds +unspecified-option+)
                        (decoding-error-policy :replace)
                        event-callback)
  "Start a backend command and return PROCESS-KIT's process task."
  (check-type repository (or null vcs-repository))
  (check-type arguments list)
  (unless (eq executable +unspecified-option+)
    (check-type executable (or null string)))
  (let* ((command-arguments
           (append (if (and (listp command) command)
                       (%argument-strings command)
                       (list (%subcommand-string command 0)))
                   (%argument-strings arguments)))
         (actual-executable (%vcs-effective-executable repository executable))
         (actual-timeout (%vcs-effective-timeout repository timeout))
         (actual-environment (%vcs-effective-environment
                              repository environment))
         (actual-directory (or directory
                               (and repository
                                    (vcs-repository-directory repository)))))
    (check-type actual-executable string)
    (handler-case
        (%run-vcs-command-async actual-executable
                                command-arguments
                                :input input
                                :timeout actual-timeout
                                :max-output-characters max-output-characters
                                :grace-period grace-period
                                :drain-timeout-seconds drain-timeout-seconds
                                :command-directory actual-directory
                                :environment actual-environment
                                :environment-update environment-update
                                :output output
                                :error-output error-output
                                :result-type result-type
                                :external-format external-format
                                :decoding-error-policy decoding-error-policy
                                :event-callback event-callback)
      (process-kit:process-launch-error (cause)
        (error 'vcs-command-launch-error
               :repository repository
               :command command
               :arguments arguments
               :directory actual-directory
               :cause cause))
      (process-kit:process-io-error (cause)
        (error 'vcs-command-io-error
               :repository repository
               :command command
               :arguments arguments
               :directory actual-directory
               :stream (process-kit:process-io-error-stream cause)
               :cause cause)))))

(defun run-vcs/checked (repository command arguments &rest options)
  "Return the PROCESS-RESULT of COMMAND in REPOSITORY, or signal the failure.

COMMAND and ARGUMENTS carry the meaning they have in RUN-VCS, and OPTIONS is
forwarded there as keyword arguments.  A :CHECK entry in OPTIONS is dropped:
checking is unconditional here, so a returned result is always a success.

Signals VCS-COMMAND-EXIT-ERROR for a non-zero exit status,
VCS-COMMAND-TIMEOUT-ERROR when the timeout elapsed,
VCS-COMMAND-CANCELLED-ERROR when the cancellation token fired,
VCS-COMMAND-LAUNCH-ERROR when the executable could not be started, and
VCS-COMMAND-IO-ERROR when stream I/O failed.  VCS-ARGUMENT-ERROR is signalled
for a command or argument that is NIL, contains a NUL character, or is
neither a string nor a non-NIL symbol, for an empty effective executable, and
for a malformed :ENVIRONMENT or :ENVIRONMENT-UPDATE value.  TYPE-ERROR is
signalled when REPOSITORY is neither NIL nor a VCS-REPOSITORY, when ARGUMENTS
is not a list, or when :EXECUTABLE is neither NIL nor a string.  Because
OPTIONS reaches RUN-VCS through APPLY, an odd-length or unrecognized OPTIONS
plist signals PROGRAM-ERROR from RUN-VCS rather than from here."
  (let ((options
          (loop for (key value) on options by #'cddr
                unless (eq key :check)
                  append (list key value))))
    (apply #'run-vcs repository command arguments :check t options)))

(defun run-vcs/k (repository command arguments on-success on-failure
                  &rest options)
  "Return the value ON-SUCCESS or ON-FAILURE returns for a checked raw VCS command.

Only a VCS-ERROR reaches ON-FAILURE: the dispatch is a HANDLER-CASE on that one
type, so it covers VCS-COMMAND-ERROR, VCS-BACKEND-ERROR, and
VCS-ARGUMENT-ERROR alike.  The TYPE-ERROR and PROGRAM-ERROR that
RUN-VCS/CHECKED documents propagate past both continuations to the caller, so
a caller that must not escape still needs its own handler.

ON-SUCCESS and ON-FAILURE are positional by design, an accepted exception to
the three-required-argument limit of the org API standard: it keeps this call
shaped like RUN-VCS/CHECKED, which takes execution options as a flat &REST.  A
&KEY form that satisfies the limit does exist; reference/api.md records why it
was not taken."
  (with-vcs-result (result on-success on-failure)
    (apply #'run-vcs/checked repository command arguments options)))

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
