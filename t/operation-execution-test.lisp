(in-package #:vcs-kit/test)

(defparameter *generated-vcs-operations*
  '(vcs-status vcs-diff vcs-log vcs-show vcs-cat vcs-add vcs-remove vcs-move
    vcs-commit vcs-branch vcs-switch vcs-checkout vcs-tag vcs-fetch vcs-pull
    vcs-push vcs-merge vcs-rebase vcs-reset vcs-revert vcs-stash vcs-remote
    vcs-update vcs-sync vcs-archive vcs-annotate vcs-blame vcs-resolve
    vcs-clean vcs-lock vcs-unlock vcs-config vcs-help vcs-worktree
    vcs-submodule vcs-bundle vcs-maintenance vcs-verify))

(describe "VCS command execution and continuations"
  (it "dispatches every generated VCS operation through one table-driven harness"
    (let ((repository (make-vcs-repository (host-kit:temporary-directory)
                                            :backend :git))
          (calls nil))
      (with-replaced-function
          (vcs-kit::run-vcs/checked
           (lambda (called-repository command arguments &rest options)
             (push (list called-repository command arguments options) calls)
             (%fake-result)))
        (dolist (name *generated-vcs-operations*)
          (expect (fboundp name) :to-be-truthy)
          (expect (process-success-p
                   (funcall name repository "fixture"
                            :execution-options '(:timeout nil)))
                  :to-be-truthy)))
      (expect (length calls) :to-equal (length *generated-vcs-operations*))))

  (it "runs direct argv and preserves typed failures"
    (let ((repository
            (make-vcs-repository (host-kit:temporary-directory)
                                 :backend :git
                                 :executable (%program-path "echo"))))
      (let ((result (run-vcs repository "status" '("file"))))
        (expect (process-success-p result) :to-be-truthy)
        (expect (process-result-stdout result)
                :to-equal (format nil "status file~%")))
      (let ((result (run-vcs nil '("-c" "printf list-command") nil
                             :executable "/bin/sh")))
        (expect (process-result-stdout result)
                :to-equal "list-command"))
      (let* ((condition
               (%expect-condition vcs-command-exit-error
                 (run-vcs nil "-c" '("exit 7")
                          :executable "/bin/sh"
                          :check t)))
             (result (vcs-command-error-result condition)))
        (expect (vcs-command-exit-error-exit-code condition) :to-equal 7)
        (expect (process-result-exit-code result) :to-equal 7))
      (%expect-condition vcs-command-launch-error
        (run-vcs nil "status" nil
                 :executable "/definitely-missing-vcs-executable"
                 :check t))))

  (it "maps generic subprocess I/O failures to a typed condition"
    (let ((condition
            (%expect-condition vcs-command-io-error
              (run-vcs nil
                       "-c"
                       (list "printf '\\377'")
                       :executable "/bin/sh"
                       :external-format :utf-8
                       :decoding-error-policy :error))))
      (expect (vcs-command-io-error-stream condition) :to-be :stdout)
      (expect (vcs-command-error-directory condition) :to-be nil)))

  (it "maps asynchronous subprocess I/O failures to a typed condition"
    (with-replaced-function
        (vcs-kit::%run-vcs-command-async
         (lambda (&rest arguments)
           (declare (ignore arguments))
           (error 'process-kit:process-io-error
                  :stream :stderr
                  :cause :test-cause)))
      (let ((condition
              (%expect-condition vcs-command-io-error
                (run-vcs-async nil "status" nil
                               :executable (%program-path "echo")))))
        (expect (vcs-command-io-error-stream condition) :to-be :stderr)
        (expect (vcs-command-error-directory condition) :to-be nil))))

  (it "maps timeout and cancellation results to typed conditions"
    (with-replaced-function
        (vcs-kit::%run-vcs-command
         (lambda (&rest arguments)
           (declare (ignore arguments))
           (%fake-result :status :timeout
                         :exit-code nil
                         :timed-out-p t)))
      (let ((condition
              (%expect-condition vcs-command-timeout-error
                (run-vcs nil "status" nil
                         :executable (%program-path "echo")
                         :check t))))
        (expect (vcs-command-error-command condition)
                :to-equal "status")
        (expect (vcs-command-error-arguments condition)
                :to-be nil)))
    (with-replaced-function
        (vcs-kit::%run-vcs-command
         (lambda (&rest arguments)
           (declare (ignore arguments))
           (%fake-result :status :cancelled
                         :exit-code nil
                         :cancelled-p t)))
      (let ((condition
              (%expect-condition vcs-command-cancelled-error
                (run-vcs nil "status" nil
                         :executable (%program-path "echo")
                         :check t))))
        (expect (vcs-command-error-command condition)
                :to-equal "status")
        (expect (vcs-command-error-arguments condition)
                :to-be nil))))

  (it "separates normalized arguments from execution options"
    (let ((repository (make-vcs-repository (host-kit:temporary-directory)
                                            :backend :git))
          (call nil))
      (with-replaced-function
          (vcs-kit::run-vcs/checked
           (lambda (called-repository command arguments &rest options)
             (setf call (list called-repository command arguments options))
             (%fake-result)))
        (vcs-status repository "--porcelain"
                    :execution-options
                    '(:timeout nil
                      :environment :inherit
                      :max-output-characters 64)))
      (expect (eq (first call) repository) :to-be-truthy)
      (expect (second call) :to-equal "status")
      (expect (third call) :to-equal '("--porcelain"))
      (expect (fourth call)
              :to-equal
                 '(:timeout nil
                   :environment :inherit
                   :max-output-characters 64))
      (%expect-condition vcs-argument-error
        (vcs-status repository :execution-options '(:timeout)))
      (%expect-condition vcs-argument-error
        (vcs-status repository
                    :execution-options
                    (list :timeout nil :environment)))
      (%expect-condition vcs-argument-error
        (vcs-status repository
                    :execution-options
                    '((:timeout) nil)))
      (%expect-condition vcs-argument-error
        (vcs-status repository
                    :execution-options '(:timeout nil)
                    "--after-marker"))
      (%expect-condition vcs-argument-error
        (vcs-kit::%split-vcs-operation-options
         '(:execution-options . 1)))
      (%expect-condition vcs-argument-error
        (vcs-status repository
                    :execution-options '(:timeout . 1)))))

  (it "rejects malformed and parser-owned structured Git options"
    (let ((repository (make-vcs-repository (host-kit:temporary-directory)
                                            :backend :git)))
      (%expect-condition vcs-argument-error
        (git-status repository
                    :execution-options '(:timeout . 1)))
      (%expect-condition vcs-argument-error
        (git-status repository
                    :execution-options '(:timeout)))
      (%expect-condition vcs-argument-error
        (git-status repository
                    :execution-options '((:timeout) nil)))
      (%expect-condition vcs-argument-error
        (git-status repository
                    :execution-options '(:timeout nil :timeout 1)))
      (%expect-condition vcs-argument-error
        (git-status repository
                    :execution-options '(:output :capture)))))

  (it "dispatches generic success and failure continuations"
    (let ((success nil)
          (failure nil)
          (repository (make-vcs-repository (host-kit:temporary-directory)
                                            :backend :git
                                            :executable (%program-path "echo"))))
      (run-vcs/k repository "status" '("file")
                 (lambda (result)
                   (setf success (process-result-stdout result)))
                 (lambda (condition)
                   (setf failure condition)))
      (expect success :to-equal (format nil "status file~%"))
      (expect failure :to-be-falsy)
      (run-vcs/k nil "-c" '("exit 9")
                 (lambda (result)
                   (setf success result))
                 (lambda (condition)
                   (setf failure condition))
                 :executable "/bin/sh")
      (expect (typep failure 'vcs-command-exit-error) :to-be-truthy)
      (expect (vcs-command-exit-error-exit-code failure) :to-equal 9)
      (let ((operation-success nil)
            (operation-failure nil))
        (run-vcs-operation/k repository :status '("file")
                             (lambda (result)
                               (setf operation-success
                                     (process-result-stdout result)))
                             (lambda (condition)
                               (setf operation-failure condition)))
        (expect operation-success :to-equal (format nil "status file~%"))
        (expect operation-failure :to-be nil))))

  (it "constructs standalone init and clone argv"
    (let* ((parent (%temporary-test-directory))
           (init-target (merge-pathnames "initialized/" parent))
           (clone-target (merge-pathnames "cloned/" parent)))
      (unwind-protect
           (progn
             (let ((result (vcs-init init-target :executable (%program-path "echo"))))
               (expect (process-result-stdout result)
                       :to-equal
                       (format nil "init ~A~%" (namestring init-target))))
             (let ((result (vcs-clone "source" clone-target
                                       :executable (%program-path "echo"))))
               (expect (process-result-stdout result)
                       :to-equal
                       (format nil "clone source ~A~%"
                               (namestring clone-target)))))
        (host-kit:delete-directory-tree parent
                                     :validate t
                                     :if-does-not-exist :ignore))))

  (it "forwards standalone execution options through the shared runner"
    (let* ((calls nil)
           (parent (%temporary-test-directory))
           (clone-target (merge-pathnames "cloned/" parent)))
      (unwind-protect
           (progn
             (with-replaced-function
                 (vcs-kit::run-vcs/checked
                  (lambda (repository command arguments &rest options)
                    (push (list repository command arguments options) calls)
                    (%fake-result)))
               (vcs-init (merge-pathnames "initialized/" parent)
                         :arguments '("--bare")
                         :executable "/custom/vcs"
                         :timeout 3
                         :environment '(("MODE" . "test"))
                         :environment-update '(("TRACE" . "1"))
                         :input "input"
                         :output :string
                         :error-output :string
                         :result-type :string
                         :external-format :utf-8
                         :max-output-characters 64
                         :cancellation-token :token
                         :grace-period 1
                         :drain-timeout-seconds 2
                         :decoding-error-policy :error)
               (vcs-clone "source" clone-target
                          :arguments '("--mirror")
                          :timeout nil))
             (expect (length calls) :to-equal 2)
             (expect (second (first calls)) :to-equal "clone")
             (expect (third (first calls))
                     :to-equal (list "--mirror" "source"
                                     (namestring clone-target))))
        (host-kit:delete-directory-tree parent
                                    :validate t
                                    :if-does-not-exist :ignore))))

  (it "rejects malformed standalone operation inputs"
    (expect (%expect-condition error
              (vcs-init nil))
            :to-be-truthy)
    (expect (%expect-condition type-error
              (vcs-clone nil (host-kit:temporary-directory)))
            :to-be-truthy)
    (expect (%expect-condition type-error
              (vcs-init (host-kit:temporary-directory)
                        :arguments '("--valid" . "dotted")))
            :to-be-truthy))

  (it "signals unsupported normalized operations"
    (let ((backend
            (make-vcs-backend
             :name :minimal
             :executable (%program-path "echo")
             :commands '((:status . "status")))))
      (unwind-protect
           (progn
             (register-vcs-backend backend)
             (let* ((repository
                      (make-vcs-repository (host-kit:temporary-directory)
                                           :backend :minimal))
                    (condition
                      (%expect-condition vcs-unsupported-operation-error
                        (vcs-commit repository))))
               (expect (vcs-unsupported-operation-error-operation condition)
                       :to-equal :commit)
               (expect (eq (vcs-unsupported-operation-error-repository
                            condition)
                           repository)
                       :to-be-truthy)
               (expect (eq (vcs-backend-error-backend condition) backend)
                       :to-be-truthy)))
        (when (find :minimal (available-vcs-backends)
                    :key #'vcs-backend-name)
          (unregister-vcs-backend :minimal))))))
