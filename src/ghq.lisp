(in-package #:vcs-kit)

(defun %signal-ghq-failure (command arguments result)
  (cond
    ((process-result-timed-out-p result)
     (error 'ghq-timeout-error
            :command command
            :arguments arguments
            :result result))
    ((process-result-cancelled-p result)
     (error 'ghq-cancelled-error
            :command command
            :arguments arguments
            :result result))
    ((not (process-success-p result))
     (error 'ghq-exit-error
            :command command
            :arguments arguments
            :result result
            :exit-code (process-result-exit-code result)))))

(defun run-ghq (command arguments &key
                              (executable "ghq")
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
  "Run GHQ COMMAND with ARGUMENTS without invoking a shell.

The returned value is the direct PROCESS-KIT:PROCESS-RESULT.  A checked
invocation signals a typed GHQ condition for every unsuccessful outcome."
  (check-type executable (or null string))
  (check-type arguments list)
  (unless (or (stringp command)
              (and (symbolp command) (not (null command))))
    (error 'vcs-argument-error
           :argument command
           :position 0
           :reason "a GHQ command must be a non-NIL string or symbol"))
  (let* ((executable (or executable "ghq"))
         (command (%subcommand-string command 0))
         (arguments (%argument-strings arguments))
         (result
           (handler-case
               (%run-vcs-command executable
                                 (cons command arguments)
                                 :input input
                                 :timeout (%effective-timeout timeout nil)
                                 :max-output-characters max-output-characters
                                 :cancellation-token cancellation-token
                                 :grace-period grace-period
                                 :drain-timeout-seconds drain-timeout-seconds
                                 :command-directory directory
                                 :environment (%effective-environment environment
                                                                       nil)
                                 :environment-update environment-update
                                 :output output
                                 :error-output error-output
                                 :result-type result-type
                                 :external-format external-format
                                 :decoding-error-policy decoding-error-policy)
             (process-kit:process-launch-error (condition)
               (error 'ghq-launch-error
                      :command command
                      :arguments arguments
                      :directory directory
                      :cause condition))
             (process-kit:process-io-error (condition)
               (error 'ghq-io-error
                      :command command
                      :arguments arguments
                      :directory directory
                      :stream (process-kit:process-io-error-stream condition)
                      :cause condition)))))
    (when (or check
              (process-result-timed-out-p result)
              (process-result-cancelled-p result))
      (%signal-ghq-failure command arguments result))
    result))

(defun run-ghq-async (command arguments
                      &key
                        (executable "ghq")
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
  "Start a GHQ command and return PROCESS-KIT's process task."
  (check-type executable (or null string))
  (check-type arguments list)
  (unless (or (stringp command)
              (and (symbolp command) (not (null command))))
    (error 'vcs-argument-error
           :argument command
           :position 0
           :reason "a GHQ command must be a non-NIL string or symbol"))
  (let* ((executable (or executable "ghq"))
         (command (%subcommand-string command 0))
         (arguments (%argument-strings arguments)))
    (handler-case
        (%run-vcs-command-async executable
                                (cons command arguments)
                                :input input
                                :timeout (%effective-timeout timeout nil)
                                :max-output-characters max-output-characters
                                :grace-period grace-period
                                :drain-timeout-seconds drain-timeout-seconds
                                :command-directory directory
                                :environment (%effective-environment
                                              environment nil)
                                :environment-update environment-update
                                :output output
                                :error-output error-output
                                :result-type result-type
                                :external-format external-format
                                :decoding-error-policy decoding-error-policy
                                :event-callback event-callback)
      (process-kit:process-launch-error (condition)
        (error 'ghq-launch-error
               :command command
               :arguments arguments
               :directory directory
               :cause condition)))))

(defun run-ghq/checked (command arguments &rest options)
  "Run GHQ and signal a typed condition for every unsuccessful outcome."
  (remf options :check)
  (apply #'run-ghq command arguments :check t options))

(defun run-ghq/k (command arguments on-success on-failure &rest options)
  "Return the value ON-SUCCESS or ON-FAILURE returns for a checked GHQ command.

Only a VCS-ERROR reaches ON-FAILURE: the dispatch is a HANDLER-CASE on that
one type, which covers GHQ-ERROR and its subtypes and also VCS-ARGUMENT-ERROR,
which is a sibling of GHQ-ERROR rather than a subtype of it.  A TYPE-ERROR
from an argument of the wrong type, and a
PROGRAM-ERROR from a malformed OPTIONS plist, propagate past both
continuations to the caller, so a caller that must not escape still needs its
own handler.

ON-SUCCESS and ON-FAILURE are positional. This keeps the call shaped like
RUN-GHQ/CHECKED, which takes execution options as a flat &REST. A &KEY form
would satisfy the three-required-argument limit of the org API standard, but
would change the public calling convention. See reference/api.md."
  (with-vcs-result (result on-success on-failure)
    (apply #'run-ghq/checked command arguments options)))

(defun ghq-version (&rest options)
  "Return the result of `ghq --version`."
  (apply #'run-ghq/checked "--version" nil options))

(defun ghq-version-async (&rest options)
  "Start `ghq --version` and return its PROCESS-KIT task."
  (apply #'run-ghq-async "--version" nil options))

(defun parse-ghq-lines (output)
  "Parse GHQ's one-path-per-line output into a list of strings."
  (check-type output string)
  (with-input-from-string (stream output)
    (loop for line = (read-line stream nil nil)
          while line
          collect (string-right-trim '(#\Return) line))))
