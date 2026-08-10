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
    (let ((repository (make-repository (uiop:temporary-directory)
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
         '("VCS_KIT_TEST_ENV=string-value")
         '(("VCS_KIT_TEST_EXTRA" . "extra-value")))
      (expect environment :to-equal '("VCS_KIT_TEST_ENV=string-value"))
      (expect environment-update
              :to-equal
              '(("VCS_KIT_TEST_EXTRA" . "extra-value"))))
    (dolist (updates (list '(("BAD=KEY" . "value"))
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
