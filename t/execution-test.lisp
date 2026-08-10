(in-package #:vcs-kit/test)

(describe "VCS execution values"
  (it "normalizes command arguments and subcommands"
    (expect (vcs-kit::%argument-strings '("one" #p"relative" 42))
            :to-equal
            '("one" "relative" "42"))
    (expect (vcs-kit::%subcommand-string 'STATUS) :to-equal "status")
    (expect (vcs-kit::%subcommand-string "status") :to-equal "status")
    (expect (vcs-kit::%search-executable-p "git") :to-be-truthy)
    (expect (vcs-kit::%search-executable-p "/bin/git") :to-be nil)
    (expect (vcs-kit::%search-executable-p "git\\wrapper") :to-be nil))

  (it "rejects invalid command argument boundaries"
    (%expect-condition vcs-argument-error
      (vcs-kit::%argument-string nil))
    (%expect-condition vcs-argument-error
      (vcs-kit::%argument-string (format nil "bad~Cvalue" #\Null)))
    (%expect-condition vcs-argument-error
      (vcs-kit::%subcommand-string nil))
    (%expect-condition vcs-argument-error
      (vcs-kit::%subcommand-string 42))
    (expect (vcs-kit::%proper-list-p '("valid")) :to-be-truthy)
    (expect (vcs-kit::%proper-list-p (cons "dotted" "tail")) :to-be nil))

  (it "preserves explicit timeout and environment values"
    (let ((repository (make-repository (host-kit:temporary-directory)
                                       :default-timeout nil
                                       :environment nil)))
      (expect (vcs-kit::%effective-timeout
               vcs-kit::+unspecified-timeout+
               repository)
              :to-be nil)
      (expect (vcs-kit::%effective-timeout 7d0 repository) :to-equal 7d0)
      (expect (vcs-kit::%effective-timeout
               vcs-kit::+unspecified-timeout+
               nil)
              :to-equal vcs-kit::+default-vcs-timeout+)
      (expect (vcs-kit::%effective-environment
               vcs-kit::+unspecified-option+
               repository)
              :to-be nil)
      (expect (vcs-kit::%effective-environment
               vcs-kit::+unspecified-option+
               nil)
              :to-be :inherit)
      (expect (vcs-kit::%effective-environment nil repository)
              :to-be nil)))

  (it "retains explicit process options while omitting absent options"
    (let* ((token (list :cancel-token))
           (callback (lambda (event) event))
           (defaults (vcs-kit::%vcs-process-options :timeout 3d0))
           (explicit (vcs-kit::%vcs-process-options
                      :input nil
                      :timeout 4d0
                      :max-output-characters 128
                      :cancellation-token token
                      :grace-period 1d0
                      :drain-timeout-seconds 2d0
                      :event-callback callback)))
      (expect (getf defaults :timeout) :to-equal 3d0)
      (expect (getf defaults :on-timeout) :to-be :return)
      (expect (getf defaults :on-cancel) :to-be :return)
      (dolist (key '(:input :max-output-characters :cancellation-token
                     :grace-period :drain-timeout-seconds :event-callback))
        (expect (member key defaults) :to-be nil))
      (expect (getf explicit :input) :to-be nil)
      (expect (getf explicit :max-output-characters) :to-equal 128)
      (expect (getf explicit :cancellation-token) :to-be token)
      (expect (getf explicit :grace-period) :to-equal 1d0)
      (expect (getf explicit :drain-timeout-seconds) :to-equal 2d0)
      (expect (getf explicit :event-callback) :to-be callback)))

  (it "passes every asynchronous execution option to process-kit"
    (let ((callback (lambda (event) event))
          (call nil))
      (with-replaced-function
          (process-kit:run-command-async
           (lambda (command &rest options)
             (setf call (list command options))
             :process-task))
        (expect
         (vcs-kit::%run-vcs-command-async
          "/bin/echo"
          '("status")
          :input nil
          :timeout 4d0
          :max-output-characters 128
          :grace-period 1d0
          :drain-timeout-seconds 2d0
          :command-directory "/tmp"
          :environment nil
          :environment-update '(("VCS_KIT_TEST" . "1"))
          :output :capture
          :error-output :capture
          :result-type :string
          :external-format :utf-8
          :decoding-error-policy :error
          :event-callback callback)
         :to-be :process-task)
        (expect call :to-be-truthy)
        (expect (getf (second call) :timeout) :to-equal 4d0)
        (expect (getf (second call) :input) :to-be nil)
        (expect (getf (second call) :max-output-characters) :to-equal 128)
        (expect (getf (second call) :grace-period) :to-equal 1d0)
        (expect (getf (second call) :drain-timeout-seconds) :to-equal 2d0)
        (expect (getf (second call) :event-callback) :to-be callback))))

  (it "applies the asynchronous process defaults when options are omitted"
    (let ((call nil))
      (with-replaced-function
          (process-kit:run-command-async
           (lambda (command &rest options)
             (setf call (list command options))
             :process-task))
        (expect (vcs-kit::%run-vcs-command-async "/bin/echo" '("status"))
                :to-be :process-task)
        (expect call :to-be-truthy)
        (expect (getf (second call) :timeout)
                :to-equal vcs-kit::+default-vcs-timeout+)
        (expect (getf (second call) :on-timeout) :to-be :return)
        (expect (getf (second call) :on-cancel) :to-be :return))))

  (it "applies the synchronous process defaults when options are omitted"
    (let ((call nil))
      (with-replaced-function
          (process-kit:run-command
           (lambda (command &rest options)
             (setf call (list command options))
             :process-result))
        (expect (vcs-kit::%run-vcs-command "/bin/echo" '("status"))
                :to-be :process-result)
        (expect call :to-be-truthy)
        (expect (getf (second call) :timeout)
                :to-equal vcs-kit::+default-vcs-timeout+)
        (expect (getf (second call) :on-timeout) :to-be :return)
        (expect (getf (second call) :on-cancel) :to-be :return))))

  (it "emits structured fields through the configurable logger"
    (let* ((records nil)
           (logger
             (log-kit:make-logger
              :name "test-vcs-kit"
              :handler
              (log-kit:make-function-handler
               (lambda (record) (push record records))))))
      (let ((vcs-kit:*vcs-logger* logger))
        (with-replaced-function
            (process-kit:run-command
             (lambda (command &rest options)
               (declare (ignore command options))
               :process-result))
          (expect (vcs-kit::%run-vcs-command
                   "/bin/echo" '("status")
                   :command-directory "/tmp"
                   :timeout 4d0)
                  :to-be :process-result)))
      (let ((record (first records)))
        (expect record :to-be-truthy)
        (expect (log-kit:log-record-message record)
                :to-equal "run vcs command")
        (expect (cdr (assoc :executable (log-kit:log-record-fields record)))
                :to-equal "/bin/echo")
        (expect (cdr (assoc :timeout (log-kit:log-record-fields record)))
                :to-equal 4d0))))

  (it "logs asynchronous command starts through the same logger"
    (let* ((records nil)
           (logger
             (log-kit:make-logger
              :name "test-vcs-kit-async"
              :handler
              (log-kit:make-function-handler
               (lambda (record) (push record records)))))
           (vcs-kit:*vcs-logger* logger))
      (with-replaced-function
          (process-kit:run-command-async
           (lambda (command &rest options)
             (declare (ignore command options))
             :process-task))
        (expect (vcs-kit::%run-vcs-command-async
                 "/bin/echo" '("status") :timeout 5d0)
                :to-be :process-task))
      (let ((record (first records)))
        (expect record :to-be-truthy)
        (expect (log-kit:log-record-message record)
                :to-equal "run vcs command asynchronously")
        (expect (cdr (assoc :timeout (log-kit:log-record-fields record)))
                :to-equal 5d0))))

  (it "normalizes environment alists at the process boundary"
    (let ((result
            (run-vcs nil
                     "-c"
                     (list "printf '%s' \"$VCS_KIT_TEST_ENV\"")
                     :executable "/bin/sh"
                     :environment
                     '(("VCS_KIT_TEST_ENV" . "repository-value"))
                     :environment-update
                     '(("VCS_KIT_TEST_ENV" . "updated-value")))))
      (expect (process-result-stdout result)
              :to-equal "updated-value")))

  (it "accepts string environments and rejects malformed environment values"
    (multiple-value-bind (environment environment-update)
        (vcs-kit::%normalize-environment-values
         vcs-kit::+unspecified-option+
         '(("VCS_KIT_TEST_DEFAULT" . "default-value")))
      (expect environment :to-be :inherit)
      (expect environment-update
              :to-equal
              '(("VCS_KIT_TEST_DEFAULT" . "default-value"))))
    (multiple-value-bind (environment environment-update)
        (vcs-kit::%normalize-environment-values
         :inherit
         '(("VCS_KIT_TEST_EMPTY")
           ("VCS_KIT_TEST_BLANK" . "")))
      (expect environment :to-be :inherit)
      (expect environment-update
              :to-equal
              '(("VCS_KIT_TEST_EMPTY")
                ("VCS_KIT_TEST_BLANK" . ""))))
    (multiple-value-bind (environment environment-update)
        (vcs-kit::%normalize-environment-values
         '("VCS_KIT_TEST_ENV=string-value")
         '(("VCS_KIT_TEST_EXTRA" . "extra-value")))
      (expect environment :to-equal '("VCS_KIT_TEST_ENV=string-value"))
      (expect environment-update
              :to-equal
              '(("VCS_KIT_TEST_EXTRA" . "extra-value"))))
    (dolist (environment (list :inherit nil))
      (multiple-value-bind (normalized updates)
          (vcs-kit::%normalize-environment-values
           environment
           '(("VCS_KIT_TEST_EXTRA" . "extra-value")))
        (expect normalized :to-be environment)
        (expect updates :to-equal
                '(("VCS_KIT_TEST_EXTRA" . "extra-value")))))
    (multiple-value-bind (environment updates)
        (vcs-kit::%normalize-environment-values
         '(("VCS_KIT_TEST_BASE" . "base-value")
           ("VCS_KIT_TEST_EXTRA" . "old-value"))
         '(("VCS_KIT_TEST_EXTRA" . "new-value")
           ("VCS_KIT_TEST_ADDED" . "added-value")))
      (expect environment :to-be :inherit)
      (expect updates :to-equal
              '(("VCS_KIT_TEST_BASE" . "base-value")
                ("VCS_KIT_TEST_EXTRA" . "new-value")
                ("VCS_KIT_TEST_ADDED" . "added-value"))))
    (dolist (updates (list '(("BAD=KEY" . "value"))
                           '(("" . "value"))
                           '(("BAD" . (format nil "bad~Cvalue" #\Null)))
                           '(("BAD" . 7))
                           '(("DUP" . "one") ("DUP" . "two"))
                           '(("BAD" . "value") . "tail")
                           '("not-an-entry")))
      (%expect-condition vcs-argument-error
        (vcs-kit::%make-vcs-command (%program-path "echo")
                                    nil
                                    :environment-update updates)))
    (dolist (environment (list '(42)
                                '(("BAD=KEY" . "value"))
                                '(("DUP" . "one") ("DUP" . "two"))))
      (%expect-condition vcs-argument-error
        (vcs-kit::%make-vcs-command (%program-path "echo")
                                    nil
                                    :environment environment)))
    (%expect-condition vcs-argument-error
      (vcs-kit::%make-vcs-command "" nil)))

  (it "trims process output at the VCS boundary"
    (expect (vcs-kit::%result-output
             (%fake-result :stdout (format nil "  value~%")))
            :to-equal
            "value"))

  (it "dispatches synchronous result callbacks"
    (let ((success nil)
          (failure nil))
      (vcs-kit::with-vcs-result
          (result
           (lambda (value) (setf success value))
           (lambda (condition) (setf failure condition)))
        17)
      (expect success :to-equal 17)
      (expect failure :to-be nil)
      (vcs-kit::with-vcs-result
          (result
           (lambda (value) (setf success value))
           (lambda (condition) (setf failure condition)))
        (error 'vcs-error))
      (expect failure :to-be-truthy))))
