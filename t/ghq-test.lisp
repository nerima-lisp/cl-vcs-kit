(in-package #:vcs-kit/test)

(describe "GHQ process and management operations"
  (it "parses line-oriented output"
    (expect (parse-ghq-lines
             (format nil "one~C~Ctwo~C" #\Return #\Newline #\Newline))
            :to-equal
            '("one" "two")))

  (it "exposes the GHQ management entry points"
    (dolist (name '(run-ghq run-ghq/checked run-ghq/k ghq-version
                    ghq-get ghq-list ghq-roots ghq-root ghq-path
                    ghq-rm ghq-create ghq-migrate ghq-help))
      (expect (fboundp name) :to-be-truthy)))

  (it "maps GHQ get options to direct argv"
    (let ((result
            (ghq-get "owner/project"
                     :update t
                     :ssh t
                     :shallow t
                     :vcs "git"
                     :look t
                     :silent t
                     :branch "main"
                     :no-recursive t
                     :parallel t
                     :bare t
                     :partial "blobless"
                     :executable "/bin/echo")))
      (expect (process-success-p result) :to-be-truthy)
      (expect (process-result-stdout result)
              :to-equal
              (format nil
                      "get -u -p --shallow --vcs git --look --silent --branch main --no-recursive -P --bare --partial blobless owner/project~%"))))

  (it "forwards environment updates through high-level GHQ operations"
    (let ((captured-options nil))
      (with-replaced-function
          (vcs-kit::%run-ghq-checked
           (lambda (command arguments &rest options)
             (declare (ignore command arguments))
             (setf captured-options options)
             (%fake-result)))
        (expect (ghq-list
                 :environment-update '(("VCS_KIT_GHQ_ENV" . "updated-value"))
                 :executable "/bin/echo")
                :to-be nil))
      (expect (getf captured-options :environment-update)
              :to-equal '(("VCS_KIT_GHQ_ENV" . "updated-value")))))

  (it "maps GHQ list filters to parsed paths"
    (expect (ghq-list :full-path t
                      :exact t
                      :vcs "git"
                      :unique t
                      :bare t
                      :arguments '("--custom" "owner/project")
                      :executable "/bin/echo")
            :to-equal
            '("list -p -e --vcs git --unique --bare --custom owner/project")))

  (it "resolves the first GHQ root and path"
    (with-replaced-function
        (vcs-kit::%run-vcs-command
         (lambda (&rest arguments)
           (declare (ignore arguments))
           (%fake-result :stdout (format nil "/one~%/two~%"))))
      (expect (ghq-root :arguments '("/one" "/two") :executable "/bin/echo")
              :to-equal
              "/one"))
    (with-replaced-function
        (vcs-kit::%run-vcs-command
         (lambda (&rest arguments)
           (declare (ignore arguments))
           (%fake-result :stdout (format nil "/full/path~%"))))
      (expect (ghq-path "owner/project"
                        :arguments '("/full/path")
                        :executable "/bin/echo")
              :to-equal
              "/full/path")))

  (it "signals a typed condition for a checked non-zero exit"
    (let ((condition
            (%expect-condition ghq-exit-error
              (run-ghq "ignored"
                       nil
                       :executable (%program-path "false")
                       :check t))))
      (expect (ghq-exit-error-exit-code condition) :to-equal 1)
      (expect (process-result-exit-code (ghq-error-result condition))
              :to-equal
              1)))

  (it "rejects invalid command arguments with typed conditions"
    (let ((condition
            (%expect-condition vcs-argument-error
              (run-ghq nil nil :executable "/bin/echo"))))
      (expect (vcs-argument-error-position condition) :to-equal 0))
    (let ((condition
            (%expect-condition vcs-argument-error
              (run-ghq "version"
                       (list (format nil "bad~Carg" #\Null))
                       :executable "/bin/echo"))))
      (expect (vcs-argument-error-position condition) :to-equal 0))
    (%expect-condition vcs-argument-error
      (ghq-list :output :stream))
    (%expect-condition vcs-argument-error
      (ghq-list :result-type :octets)))

  (it "rejects invalid asynchronous command arguments before launch"
    (%expect-condition vcs-argument-error
      (run-ghq-async nil nil :executable "/bin/echo"))
    (%expect-condition vcs-argument-error
      (run-ghq-async "version"
                     (list (format nil "bad~Carg" #\Null))
                     :executable "/bin/echo")))

  (it "keeps checked wrappers checked and supports GHQ CPS callbacks"
    (%expect-condition ghq-exit-error
      (run-ghq/checked "ignored"
                       nil
                       :executable (%program-path "false")
                       :check nil))
    (let ((success nil)
          (failure nil))
      (run-ghq/k "version"
                 nil
                 (lambda (result) (setf success result))
                 (lambda (condition) (setf failure condition))
                 :executable "/bin/echo")
      (expect (process-success-p success) :to-be-truthy)
      (expect failure :to-be nil)
      (setf success nil)
      (run-ghq/k "ignored"
                 nil
                 (lambda (result) (setf success result))
                 (lambda (condition) (setf failure condition))
                 :executable (%program-path "false"))
      (expect success :to-be nil)
      (expect (typep failure 'ghq-exit-error) :to-be-truthy)))

  (it "maps executable launch failures to a typed GHQ condition"
    (let ((condition
            (%expect-condition ghq-launch-error
              (run-ghq "version"
                       nil
                       :executable "/__vcs_kit_missing_executable__"))))
      (expect (ghq-error-cause condition) :to-be-truthy)))

  (it "maps timeout results to a typed GHQ condition"
    (with-replaced-function
        (vcs-kit::%run-vcs-command
         (lambda (&rest arguments)
           (declare (ignore arguments))
           (%fake-result :status :timeout
                         :exit-code nil
                         :timed-out-p t)))
      (%expect-condition ghq-timeout-error
        (run-ghq "version" nil :executable "/bin/echo"))))

  (it "maps cancellation results to a typed GHQ condition"
    (with-replaced-function
        (vcs-kit::%run-vcs-command
         (lambda (&rest arguments)
           (declare (ignore arguments))
           (%fake-result :status :cancelled
                         :exit-code nil
                         :cancelled-p t)))
      (%expect-condition ghq-cancelled-error
        (run-ghq "version" nil :executable "/bin/echo"))))

  (it "maps subprocess I/O failures to a typed GHQ condition"
    (let ((condition
            (%expect-condition ghq-io-error
              (run-ghq "-c"
                       (list "printf '\\377'")
                       :executable "/bin/sh"
                       :external-format :utf-8
                       :decoding-error-policy :error))))
      (expect (ghq-io-error-stream condition) :to-be :stdout)
      (expect (ghq-error-directory condition) :to-be nil)))

  (it-skip-if (not (%ghq-available-p))
              "runs the installed GHQ executable"
    (let ((result (ghq-version)))
      (expect (process-success-p result) :to-be-truthy)
      (expect (search "ghq version" (process-result-stdout result))
              :to-be-truthy)))

  (it-skip-if (not (%ghq-available-p))
              "executes GHQ read-only management wrappers"
    (let ((roots (ghq-roots))
          (repositories (ghq-list))
          (help (ghq-help)))
      (expect (listp roots) :to-be-truthy)
      (expect (listp repositories) :to-be-truthy)
      (expect (process-success-p help) :to-be-truthy))))
