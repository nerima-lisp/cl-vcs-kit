(in-package #:vcs-kit/test)

(describe "process option data"
  (it "keeps omitted and explicitly supplied options distinct"
    (let* ((token (make-vcs-cancellation-token))
           (callback (lambda (&rest arguments)
                       (declare (ignore arguments))))
           (options
             (vcs-kit::%vcs-process-options
              :input nil
              :timeout 3
              :max-output-characters 4096
              :cancellation-token token
              :grace-period 0
              :drain-timeout-seconds 2
              :event-callback callback)))
      (expect (getf options :input) :to-be nil)
      (expect (getf options :timeout) :to-equal 3)
      (expect (getf options :max-output-characters) :to-equal 4096)
      (expect (getf options :cancellation-token) :to-be token)
      (expect (getf options :grace-period) :to-equal 0)
      (expect (getf options :drain-timeout-seconds) :to-equal 2)
      (expect (getf options :event-callback) :to-be callback)
      (expect (getf options :on-timeout) :to-be :return)
      (expect (getf options :on-cancel) :to-be :return)))

  (it "omits optional process keys when they were not supplied"
    (let ((options (vcs-kit::%vcs-process-options :timeout 7)))
      (expect (getf options :timeout) :to-equal 7)
      (expect (getf options :on-timeout) :to-be :return)
      (expect (getf options :on-cancel) :to-be :return)
      (dolist (key '(:input :max-output-characters :cancellation-token
                     :grace-period :drain-timeout-seconds :event-callback))
        (expect (getf options key) :to-be nil)
        (expect (member key options) :to-be nil)))))

(describe "Git process execution"
  (it "returns the direct process-kit result"
    (let ((result (run-git nil
                           "status"
                           '("--porcelain" "path with spaces")
                           :executable (%program-path "echo"))))
      (expect (process-success-p result) :to-be-truthy)
      (expect (process-result-program result) :to-equal (%program-path "echo"))
      (expect (process-result-arguments result)
              :to-equal
              '("status" "--porcelain" "path with spaces"))
      (expect (process-result-stdout result)
              :to-equal
              (format nil "status --porcelain path with spaces~%"))))

  (it "signals a typed condition for a checked non-zero exit"
    (let ((condition
            (%expect-condition git-exit-error
              (run-git nil
                       "ignored"
                       nil
                       :executable (%program-path "false")
                       :check t))))
      (expect (git-exit-error-exit-code condition) :to-equal 1)
      (expect (process-result-exit-code (git-error-result condition))
              :to-equal
              1)))

  (it "returns an unchecked failed result when requested"
    (let ((result (run-git nil
                           "ignored"
                           nil
                           :executable (%program-path "false"))))
      (expect (process-success-p result) :to-be nil)
      (expect (process-result-exit-code result) :to-equal 1)))

  (it "rejects invalid command arguments with typed conditions"
    (let ((condition
            (%expect-condition vcs-argument-error
              (run-git nil nil nil :executable (%program-path "echo")))))
      (expect (vcs-argument-error-position condition) :to-equal 0))
    (let ((condition
            (%expect-condition vcs-argument-error
              (run-git nil
                       "status"
                       (list (format nil "bad~Carg" #\Null))
                       :executable (%program-path "echo")))))
      (expect (vcs-argument-error-position condition) :to-equal 0))
    (let ((condition
            (%expect-condition vcs-argument-error
              (run-git nil "status" (list nil) :executable (%program-path "echo")))))
      (expect (vcs-argument-error-position condition) :to-equal 0))
    (%expect-condition vcs-argument-error
      (run-git nil "status" nil :executable "")))

  (it "rejects invalid asynchronous command arguments before launch"
    (%expect-condition vcs-argument-error
      (run-git-async nil nil nil :executable (%program-path "echo")))
    (%expect-condition vcs-argument-error
      (run-git-async nil
                     "status"
                     (list (format nil "bad~Carg" #\Null))
                     :executable (%program-path "echo"))))

  (it "maps synchronous launch failures to a typed condition"
    (let ((condition
            (%expect-condition git-launch-error
              (run-git nil
                       "--version"
                       nil
                       :executable "/definitely-missing-git-executable"))))
      (expect (git-error-command condition) :to-equal "--version")
      (expect (git-error-arguments condition) :to-be nil)))

  (it "maps subprocess I/O failures to a typed condition"
    (let ((condition
            (%expect-condition git-io-error
              (run-git nil
                       "-c"
                       (list "printf '\\377'")
                       :executable "/bin/sh"
                       :external-format :utf-8
                       :decoding-error-policy :error))))
      (expect (git-io-error-stream condition) :to-be :stdout)
      (expect (git-error-directory condition) :to-be nil)))

  (it "maps timeout results to a typed condition"
    (with-replaced-function
        (vcs-kit::%run-vcs-command
         (lambda (&rest arguments)
           (declare (ignore arguments))
           (%fake-result :status :timeout
                         :exit-code nil
                         :timed-out-p t)))
      (%expect-condition git-timeout-error
        (run-git nil "status" nil :executable (%program-path "echo")))))

  (it "maps cancellation results to a typed condition"
    (with-replaced-function
        (vcs-kit::%run-vcs-command
         (lambda (&rest arguments)
           (declare (ignore arguments))
           (%fake-result :status :cancelled
                         :exit-code nil
                         :cancelled-p t)))
      (%expect-condition git-cancelled-error
        (run-git nil "status" nil :executable (%program-path "echo")))))

  (it "supports cancellation tokens"
    (let ((token (make-vcs-cancellation-token)))
      (expect (vcs-cancellation-requested-p token) :to-be nil)
      (cancel-vcs token)
      (expect (vcs-cancellation-requested-p token) :to-be-truthy)))

  (it "supports a synchronous CPS success continuation"
    (let ((failure nil))
      (with-continuation-result (result next calledp)
          (run-git/k nil
                     "--version"
                     nil
                     #'next
                     (lambda (condition)
                       (setf failure condition))
                     :executable (%program-path "echo"))
        (expect calledp :to-be-truthy)
        (expect failure :to-be nil)
        (expect (process-success-p result) :to-be-truthy))))

  (it "routes a synchronous CPS failure continuation"
    (let ((success nil)
          (failure nil))
      (run-git/k nil
                 "ignored"
                 nil
                 (lambda (result)
                   (setf success result))
                 (lambda (condition)
                   (setf failure condition))
                 :executable (%program-path "false"))
      (expect success :to-be nil)
      (expect failure :to-be-truthy)
      (expect (typep failure 'git-exit-error) :to-be-truthy))))
