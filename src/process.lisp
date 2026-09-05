(in-package #:vcs-kit)

(defun make-vcs-cancellation-token ()
  "Create a cancellation token for a Git or GHQ invocation."
  (process-kit:make-cancellation-token))

(defun cancel-vcs (token)
  "Request cancellation of a process using TOKEN."
  (check-type token vcs-cancellation-token)
  (process-kit:cancel token))

(defun vcs-cancellation-requested-p (token)
  "Return true when cancellation has been requested for TOKEN."
  (check-type token vcs-cancellation-token)
  (process-kit:cancellation-requested-p token))

(defun %git-executable (repository executable)
  (or executable
      (and repository (repository-executable repository))
      "git"))

(defun %signal-git-failure (repository command arguments result)
  (cond
    ((process-result-timed-out-p result)
     (error 'git-timeout-error
            :repository repository
            :command command
            :arguments arguments
            :result result))
    ((process-result-cancelled-p result)
     (error 'git-cancelled-error
            :repository repository
            :command command
            :arguments arguments
            :result result))
    ((not (process-success-p result))
     (error 'git-exit-error
            :repository repository
            :command command
            :arguments arguments
            :result result
            :exit-code (process-result-exit-code result)))))

(defun run-git (repository subcommand arguments
                &key executable
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
  "Run SUBCOMMAND with ARGUMENTS in REPOSITORY without invoking a shell.

The returned value is the direct PROCESS-KIT:PROCESS-RESULT.  When CHECK is
true, a non-zero exit status signals GIT-EXIT-ERROR.  Timeout and
cancellation outcomes always signal their corresponding VCS-KIT condition."
  (check-type repository (or null repository))
  (check-type executable (or null string))
  (check-type arguments list)
  (unless (or (stringp subcommand)
              (and (symbolp subcommand) (not (null subcommand))))
    (error 'vcs-argument-error
           :argument subcommand
           :position 0
           :reason "a Git subcommand must be a non-NIL string or symbol"))
  (let* ((executable (%git-executable repository executable))
         (subcommand (%subcommand-string subcommand 0))
         (arguments (%argument-strings arguments))
         (command-arguments (cons subcommand arguments))
         (directory (or directory
                        (and repository (repository-directory repository))))
         (environment (%effective-environment environment repository))
         (result
           (handler-case
               (%run-vcs-command executable
                                 command-arguments
                                 :input input
                                 :timeout (%effective-timeout timeout repository)
                                 :max-output-characters max-output-characters
                                 :cancellation-token cancellation-token
                                 :grace-period grace-period
                                 :drain-timeout-seconds drain-timeout-seconds
                                 :command-directory directory
                                 :environment environment
                                 :environment-update environment-update
                                 :output output
                                 :error-output error-output
                                 :result-type result-type
                                 :external-format external-format
                                 :decoding-error-policy decoding-error-policy)
             (process-kit:process-launch-error (condition)
               (error 'git-launch-error
                      :repository repository
                      :command subcommand
                      :arguments arguments
                      :directory directory
                      :cause condition))
             (process-kit:process-io-error (condition)
               (error 'git-io-error
                      :repository repository
                      :command subcommand
                      :arguments arguments
                      :directory directory
                      :stream (process-kit:process-io-error-stream condition)
                      :cause condition)))))
    (when (or check
              (process-result-timed-out-p result)
              (process-result-cancelled-p result))
      (%signal-git-failure repository subcommand arguments result))
    result))

(defun run-git-async (repository subcommand arguments
                      &key executable
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
  "Start a Git command and return PROCESS-KIT's process task.

The task owns cancellation and exposes PROCESS-KIT's event history through
the VCS-KIT task functions.  EVENT-CALLBACK receives direct process events."
  (check-type repository (or null repository))
  (check-type executable (or null string))
  (check-type arguments list)
  (unless (or (stringp subcommand)
              (and (symbolp subcommand) (not (null subcommand))))
    (error 'vcs-argument-error
           :argument subcommand
           :position 0
           :reason "a Git subcommand must be a non-NIL string or symbol"))
  (let* ((executable (%git-executable repository executable))
         (subcommand (%subcommand-string subcommand 0))
         (arguments (%argument-strings arguments))
         (directory (or directory
                        (and repository (repository-directory repository))))
         (environment (%effective-environment environment repository)))
    (handler-case
        (%run-vcs-command-async executable
                                (cons subcommand arguments)
                                :input input
                                :timeout (%effective-timeout timeout repository)
                                :max-output-characters max-output-characters
                                :grace-period grace-period
                                :drain-timeout-seconds drain-timeout-seconds
                                :command-directory directory
                                :environment environment
                                :environment-update environment-update
                                :output output
                                :error-output error-output
                                :result-type result-type
                                :external-format external-format
                                :decoding-error-policy decoding-error-policy
                                :event-callback event-callback)
      (process-kit:process-launch-error (condition)
        (error 'git-launch-error
               :repository repository
               :command subcommand
               :arguments arguments
               :directory directory
               :cause condition)))))

(defun run-git/checked (repository subcommand arguments &rest options)
  "Run Git and signal a typed error for every unsuccessful result."
  (remf options :check)
  (apply #'run-git repository subcommand arguments :check t options))

(defun run-git/k (repository subcommand arguments on-success on-failure
                  &rest options)
  "Return the value ON-SUCCESS or ON-FAILURE returns for a checked Git command.

Use this synchronous CPS entry point when a caller wants a single success/error
continuation without establishing a condition handler.

Only a VCS-ERROR reaches ON-FAILURE: the dispatch is a HANDLER-CASE on that
one type, which covers GIT-ERROR and its subtypes and also VCS-ARGUMENT-ERROR
and GIT-PARSE-ERROR, which are siblings of GIT-ERROR rather than subtypes of
it.  A TYPE-ERROR from an argument of the wrong type, and a
PROGRAM-ERROR from a malformed OPTIONS plist, propagate past both
continuations to the caller, so a caller that must not escape still needs its
own handler.

ON-SUCCESS and ON-FAILURE are positional by design, an accepted exception to
the three-required-argument limit of the org API standard: it keeps this call
shaped like RUN-GIT/CHECKED, which takes execution options as a flat &REST.  A
&KEY form that satisfies the limit does exist; reference/api.md records why it
was not taken."
  (with-vcs-result (result on-success on-failure)
      (apply #'run-git/checked repository subcommand arguments options)))

(defun git-version (&key executable
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
  "Return the direct result of `git --version`."
  (run-git nil "--version" nil
           :executable executable
           :timeout timeout
           :input input
           :environment environment
           :environment-update environment-update
           :directory directory
           :output output
           :error-output error-output
           :result-type result-type
           :external-format external-format
           :max-output-characters max-output-characters
           :cancellation-token cancellation-token
           :grace-period grace-period
           :drain-timeout-seconds drain-timeout-seconds
           :decoding-error-policy decoding-error-policy))

(defun git-version-async (&rest options)
  "Start `git --version` and return its PROCESS-KIT task."
  (apply #'run-git-async nil "--version" nil options))
