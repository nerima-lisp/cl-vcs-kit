;;;; GHQ operations: shared argument and process boundaries.

(in-package #:vcs-kit)

(defun %ghq-spec-list (specification)
  (cond
    ((or (stringp specification) (pathnamep specification))
     (list specification))
    ((listp specification)
     (mapcar (lambda (spec)
               (check-type spec (or string pathname))
               spec)
             specification))
    (t
     (error 'type-error
            :datum specification
            :expected-type '(or string pathname list)))))

(defun %ghq-option (name value)
  (list name (%argument-string value)))

(defun %ghq-get-arguments (specification update ssh shallow vcs look silent branch
                           no-recursive parallel bare partial arguments)
  (append (when update (list "-u"))
          (when ssh (list "-p"))
          (when shallow (list "--shallow"))
          (when vcs (%ghq-option "--vcs" vcs))
          (when look (list "--look"))
          (when silent (list "--silent"))
          (when branch (%ghq-option "--branch" branch))
          (when no-recursive (list "--no-recursive"))
          (when parallel (list "-P"))
          (when bare (list "--bare"))
          (when partial (%ghq-option "--partial" partial))
          arguments
          (%ghq-spec-list specification)))

(defun %run-ghq-checked (command arguments
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
                           cancellation-token
                           (grace-period +unspecified-option+)
                           (drain-timeout-seconds +unspecified-option+)
                           (decoding-error-policy :replace))
  (run-ghq/checked command arguments
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

(defun %check-ghq-text-options (output result-type)
  (unless (eq output :capture)
    (error 'vcs-argument-error
           :argument output
           :reason "GHQ structured output requires :OUTPUT :CAPTURE"))
  (unless (eq result-type :string)
    (error 'vcs-argument-error
           :argument result-type
           :reason "GHQ structured output requires :RESULT-TYPE :STRING")))

(defun %ghq-get-or-clone (command repository-specification
                          update ssh shallow vcs look silent branch
                          no-recursive parallel bare partial arguments
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
                            cancellation-token
                            (grace-period +unspecified-option+)
                            (drain-timeout-seconds +unspecified-option+)
                            (decoding-error-policy :replace))
  (check-type arguments list)
  (%run-ghq-checked
   command
   (%ghq-get-arguments repository-specification update ssh shallow vcs look
                       silent branch no-recursive parallel bare partial
                       arguments)
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
