;;;; GHQ operations: roots and repository management.

(in-package #:vcs-kit)

(defmacro %run-ghq-management (command arguments
                                &key executable timeout input environment
                                  environment-update directory output
                                  error-output result-type external-format
                                  max-output-characters cancellation-token
                                  grace-period drain-timeout-seconds
                                  decoding-error-policy)
  "Run a GHQ management command with the common process options."
  `(%run-ghq-checked ,command
                     ,arguments
                     :executable ,executable
                     :timeout ,timeout
                     :input ,input
                     :environment ,environment
                     :environment-update ,environment-update
                     :directory ,directory
                     :output ,output
                     :error-output ,error-output
                     :result-type ,result-type
                     :external-format ,external-format
                     :max-output-characters ,max-output-characters
                     :cancellation-token ,cancellation-token
                     :grace-period ,grace-period
                     :drain-timeout-seconds ,drain-timeout-seconds
                     :decoding-error-policy ,decoding-error-policy))

(defun ghq-roots (&key all
                        (arguments nil)
                        (executable "ghq")
                        (timeout +unspecified-timeout+)
                        (environment +unspecified-option+)
                        (environment-update nil)
                        directory
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
  "Return the configured GHQ roots as a list of strings."
  (check-type arguments list)
  (%check-ghq-text-options output result-type)
  (let ((result
          (%run-ghq-management "root"
                                (append (when all (list "--all")) arguments)
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
                                :decoding-error-policy decoding-error-policy)))
    (parse-ghq-lines (%result-output result))))

(defun ghq-root (&rest options)
  "Return the primary GHQ root, or all roots when :ALL is true."
  (let ((roots (apply #'ghq-roots options)))
    (if (getf options :all)
        roots
        (first roots))))

(defun ghq-path (repository-specification &rest options)
  "Resolve an exact repository specification to its first full path.

Use GHQ-LIST directly when callers need to distinguish zero or multiple
matches."
  (let ((options (copy-list options)))
    (remf options :query)
    (remf options :exact)
    (remf options :full-path)
    (first
     (apply #'ghq-list
            :query repository-specification
            :exact t
            :full-path t
            options))))

(defun ghq-rm (repository-specification &key dry-run bare
                                              (arguments nil)
                                              (executable "ghq")
                                              (timeout +unspecified-timeout+)
                                              (environment +unspecified-option+)
                                              (environment-update nil)
                                              directory
                                              (input +unspecified-option+)
                                              (output :capture)
                                              (error-output :capture)
                                              (result-type :string)
                                              (external-format :utf-8)
                                              (max-output-characters
                                                +unspecified-option+)
                                              cancellation-token
                                              (grace-period
                                                +unspecified-option+)
                                              (drain-timeout-seconds
                                                +unspecified-option+)
                                              (decoding-error-policy :replace))
  "Remove a GHQ-managed repository, optionally using :DRY-RUN."
  (check-type repository-specification (or string pathname))
  (check-type arguments list)
  (%run-ghq-management "rm"
                    (append (when dry-run (list "--dry-run"))
                            (when bare (list "--bare"))
                            arguments
                            (list (%argument-string repository-specification)))
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

(defun ghq-create (repository-specification &key vcs bare
                                                  (arguments nil)
                                                  (executable "ghq")
                                                  (timeout +unspecified-timeout+)
                                                  (environment
                                                    +unspecified-option+)
                                                  (environment-update nil)
                                                  directory
                                                  (input
                                                    +unspecified-option+)
                                                  (output :capture)
                                                  (error-output :capture)
                                                  (result-type :string)
                                                  (external-format :utf-8)
                                                  (max-output-characters
                                                    +unspecified-option+)
                                                  cancellation-token
                                                  (grace-period
                                                    +unspecified-option+)
                                                  (drain-timeout-seconds
                                                    +unspecified-option+)
                                                  (decoding-error-policy
                                                    :replace))
  "Create a repository directory managed by GHQ."
  (check-type repository-specification (or string pathname))
  (check-type arguments list)
  (%run-ghq-management "create"
                    (append (when vcs (%ghq-option "--vcs" vcs))
                            (when bare (list "--bare"))
                            arguments
                            (list (%argument-string repository-specification)))
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

(defun ghq-migrate (directory &key yes dry-run
                                      (arguments nil)
                                      (executable "ghq")
                                      (timeout +unspecified-timeout+)
                                      (environment +unspecified-option+)
                                      (environment-update nil)
                                      working-directory
                                      (input +unspecified-option+)
                                      (output :capture)
                                      (error-output :capture)
                                      (result-type :string)
                                      (external-format :utf-8)
                                      (max-output-characters
                                        +unspecified-option+)
                                      cancellation-token
                                      (grace-period +unspecified-option+)
                                      (drain-timeout-seconds
                                        +unspecified-option+)
                                      (decoding-error-policy :replace))
  "Migrate a local repository directory into GHQ's layout."
  (check-type directory (or string pathname))
  (check-type arguments list)
  (%run-ghq-management "migrate"
                    (append (when yes (list "-y"))
                            (when dry-run (list "--dry-run"))
                            arguments
                            (list (%argument-string directory)))
                    :executable executable
                    :timeout timeout
                    :input input
                    :environment environment
                    :environment-update environment-update
                    :directory working-directory
                    :output output
                    :error-output error-output
                    :result-type result-type
                    :external-format external-format
                    :max-output-characters max-output-characters
                    :cancellation-token cancellation-token
                    :grace-period grace-period
                    :drain-timeout-seconds drain-timeout-seconds
                    :decoding-error-policy decoding-error-policy))

(defun ghq-help (&rest options)
  "Return GHQ's help output as a process result."
  (apply #'run-ghq/checked "help" nil options))
