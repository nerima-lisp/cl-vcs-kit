(in-package #:vcs-kit)

(defparameter +unspecified-timeout+ (gensym "UNSPECIFIED-TIMEOUT-"))
(defparameter +unspecified-option+ (gensym "UNSPECIFIED-"))
(defparameter +default-vcs-timeout+ 30d0)

(defparameter *vcs-logger*
  (log-kit:make-logger :name "vcs-kit"
                       :handler (log-kit:make-null-handler))
  "Logger used by process-backed VCS operations.

Bind this variable to a LOG-KIT logger to receive structured operation events;
the default is silent for library callers.")

(defun %argument-string (argument &optional position)
  (unless argument
    (error 'vcs-argument-error
           :argument argument
           :position position
           :reason "command arguments cannot be NIL"))
  (let ((string
          (typecase argument
            (string argument)
            (pathname (namestring argument))
            (t (princ-to-string argument)))))
    (when (position #\Null string)
      (error 'vcs-argument-error
             :argument argument
             :position position
             :reason "command arguments cannot contain NUL"))
    string))

(defun %argument-strings (arguments)
  (loop for argument in arguments
        for position from 0
        collect (%argument-string argument position)))

(defun %subcommand-string (subcommand &optional position)
  (unless (or (stringp subcommand)
              (and (symbolp subcommand) (not (null subcommand))))
    (error 'vcs-argument-error
           :argument subcommand
           :position position
           :reason "a command must be a non-NIL string or symbol"))
  (%argument-string
   (if (stringp subcommand)
       subcommand
       (string-downcase (symbol-name subcommand)))
   position))

(defun %search-executable-p (executable)
  (and (stringp executable)
       (not (or (find #\/ executable)
                (find #\\ executable)))))

(defun %effective-timeout (timeout repository)
  (if (eq timeout +unspecified-timeout+)
      (if repository
          (repository-default-timeout repository)
          +default-vcs-timeout+)
      timeout))

(defun %effective-environment (environment repository)
  (if (eq environment +unspecified-option+)
      (if repository
          (repository-environment repository)
          :inherit)
      environment))

(defun %proper-list-p (value)
  (handler-case
      (not (null (list-length value)))
    (type-error () nil)))

(defun %environment-update-entry-p (entry)
  (and (consp entry)
       (stringp (car entry))
       (not (string= (car entry) ""))
       (not (find #\= (car entry)))
       (not (find #\Null (car entry)))
       (or (null (cdr entry))
           (and (stringp (cdr entry))
                (not (find #\Null (cdr entry)))))))

(defun %valid-environment-update-p (value)
  (and (%proper-list-p value)
       (every #'%environment-update-entry-p value)
       (= (length value)
          (length (remove-duplicates value
                                     :key #'car
                                     :test #'string=)))))

(defun %merge-environment-updates (base extra)
  (append (remove-if (lambda (entry)
                       (find (car entry) extra
                             :key #'car
                             :test #'string=))
                     base)
          extra))

(defun %normalize-environment-values (environment environment-update)
  (unless (%valid-environment-update-p environment-update)
    (error 'vcs-argument-error
           :argument environment-update
           :reason "environment updates must be an alist of unique string keys"))
  (cond
    ((eq environment +unspecified-option+)
     (values :inherit environment-update))
    ((or (eq environment :inherit)
         (null environment))
     (values environment environment-update))
    ((and (%proper-list-p environment)
          (every #'stringp environment))
     (values environment environment-update))
    ((and (%proper-list-p environment)
          (every #'%environment-update-entry-p environment)
          (= (length environment)
             (length (remove-duplicates environment
                                        :key #'car
                                        :test #'string=))))
     (values :inherit
             (%merge-environment-updates environment environment-update)))
    (t
     (error 'vcs-argument-error
            :argument environment
            :reason
            "environment must be :INHERIT, NIL, KEY=VALUE strings, or an alist"))))

(defun %make-vcs-command (executable arguments
                           &key directory environment environment-update
                             (output :capture) (error-output :capture)
                             (result-type :string) (external-format :utf-8)
                             (decoding-error-policy :replace))
  (unless (and (stringp executable)
               (not (string= executable "")))
    (error 'vcs-argument-error
           :argument executable
           :reason "the executable must be a non-empty string"))
  (multiple-value-bind (environment environment-update)
      (%normalize-environment-values environment environment-update)
    (process-kit:make-command
     executable
     arguments
     :search (%search-executable-p executable)
     :environment-policy (if (eq environment +unspecified-option+)
                             :inherit
                             environment)
     :environment-update environment-update
     :directory directory
     :stdin :inherit
     :stdout output
     :stderr error-output
     :result-type result-type
     :external-format external-format
     :decoding-error-policy decoding-error-policy)))

(defun %vcs-process-options (&key
                               (input +unspecified-option+)
                               timeout
                               (max-output-characters +unspecified-option+)
                               cancellation-token
                               (grace-period +unspecified-option+)
                               (drain-timeout-seconds +unspecified-option+)
                               event-callback)
  "Build the process-kit options shared by sync and async execution.

The sentinel values are kept at this boundary so callers can distinguish an
omitted option from an explicit NIL.  It returns data only;
the process invocation remains in the synchronous and asynchronous runners."
  (let ((options (list :timeout timeout
                       :on-timeout :return
                       :on-cancel :return)))
    (flet ((add-option (key value)
             (unless (eq value +unspecified-option+)
               (setf options (list* key value options))))
           (add-present-option (key value)
             (when value
               (setf options (list* key value options)))))
      (add-option :input input)
      (add-option :max-output-characters max-output-characters)
      (add-present-option :cancellation-token cancellation-token)
      (add-option :grace-period grace-period)
      (add-option :drain-timeout-seconds drain-timeout-seconds)
      (add-present-option :event-callback event-callback))
    options))

(defun %run-vcs-command (executable arguments
                         &key
                           (input +unspecified-option+)
                           (timeout +default-vcs-timeout+)
                           (max-output-characters +unspecified-option+)
                           cancellation-token
                           (grace-period +unspecified-option+)
                           (drain-timeout-seconds +unspecified-option+)
                           command-directory
                           (environment :inherit)
                           (environment-update nil)
                           (output :capture)
                           (error-output :capture)
                           (result-type :string)
                           (external-format :utf-8)
                           (decoding-error-policy :replace))
  (log-kit:log-info *vcs-logger* "run vcs command"
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
                  :cancellation-token cancellation-token
                  :grace-period grace-period
                  :drain-timeout-seconds drain-timeout-seconds)))
    (apply #'process-kit:run-command command options)))

(defun %result-output (result)
  (string-trim '(#\Space #\Tab #\Newline #\Return #\Null)
               (or (process-result-stdout result) "")))

(defun %dispatch-vcs-result (thunk on-success on-failure)
  (handler-case
      (funcall on-success (funcall thunk))
    (vcs-error (condition)
      (funcall on-failure condition))))

(defmacro with-vcs-result ((result on-success on-failure) form)
  "Run FORM and dispatch its value or a VCS-ERROR to a callback.

Synchronous CPS lets callers keep control flow in
callbacks while the process implementation remains replaceable by the
asynchronous process-kit API."
  `(%dispatch-vcs-result
     (lambda () ,form)
     (lambda (,result)
       (funcall ,on-success ,result))
     (lambda (condition)
       (funcall ,on-failure condition))))
