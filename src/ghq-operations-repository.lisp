;;;; GHQ operations: repository retrieval and listing.

(in-package #:vcs-kit)

(defmacro %define-ghq-get-or-clone (name documentation command)
  "Define one of the GHQ repository retrieval entry points.

GHQ-GET and GHQ-CLONE intentionally share their complete process contract;
keeping that contract in one expansion prevents their keyword interfaces from
drifting while leaving ordinary, inspectable functions at the public boundary."
  `(defun ,name (repository-specification &key
                                           update
                                           ssh
                                           shallow
                                           vcs
                                           look
                                           silent
                                           branch
                                           no-recursive
                                           parallel
                                           bare
                                           partial
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
                                           (grace-period +unspecified-option+)
                                           (drain-timeout-seconds
                                             +unspecified-option+)
                                           (decoding-error-policy :replace))
     ,documentation
     (%ghq-get-or-clone
      ,command repository-specification update ssh shallow vcs look silent
      branch no-recursive parallel bare partial arguments
      :executable executable
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

(%define-ghq-get-or-clone
 ghq-get
 "Get or update one or more repositories through GHQ.

REPOSITORY-SPECIFICATION may be one repository specification or a list of
specifications.  ARGUMENTS is inserted before the specifications."
 "get")

(%define-ghq-get-or-clone
 ghq-clone
 "Clone one or more repositories through GHQ's CLONE alias.

The keyword options and argument ordering match GHQ-GET."
 "clone")

(defun ghq-list (&key query exact full-path vcs unique bare
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
  "List GHQ-managed repositories, optionally filtered by QUERY."
  (check-type arguments list)
  (%check-ghq-text-options output result-type)
  (let* ((command-arguments
           (append (when full-path (list "-p"))
                   (when exact (list "-e"))
                   (when vcs (%ghq-option "--vcs" vcs))
                   (when unique (list "--unique"))
                   (when bare (list "--bare"))
                   arguments
                   (when query (list (%argument-string query)))))
         (result (%run-ghq-checked "list" command-arguments
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
                                   :drain-timeout-seconds
                                   drain-timeout-seconds
                                   :decoding-error-policy
                                   decoding-error-policy)))
    (parse-ghq-lines (%result-output result))))
