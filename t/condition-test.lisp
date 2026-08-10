(in-package #:vcs-kit/test)

(defun %condition-report-string (condition)
  (princ-to-string condition))

(describe "typed failure conditions"
  (it "reports the base VCS error"
    (expect (%condition-report-string (make-condition 'vcs-error))
            :to-equal
            "VCS operation failed"))

  (it "preserves Git failure context"
    (let* ((result (%fake-result :exit-code 7))
           (condition
             (make-condition 'git-error
                             :repository :repository
                             :command "status"
                             :arguments '("--short")
                             :result result
                             :cause :cause)))
      (expect (git-error-repository condition) :to-be :repository)
      (expect (git-error-command condition) :to-equal "status")
      (expect (git-error-arguments condition) :to-equal '("--short"))
      (expect (git-error-result condition) :to-be result)
      (expect (git-error-cause condition) :to-be :cause)
      (expect (%condition-report-string condition)
              :to-equal
              "Git command failed: status --short")))

  (it "reports every Git process outcome"
    (dolist (entry
              (list
               (list (make-condition 'git-exit-error
                                     :repository nil
                                     :command "commit"
                                     :arguments nil
                                     :exit-code 2)
                     "Git command failed: commit (exit 2)")
               (list (make-condition 'git-exit-error
                                     :repository nil
                                     :command "commit"
                                     :arguments nil)
                     "Git command failed: commit")
               (list (make-condition 'git-timeout-error
                                     :repository nil
                                     :command "fetch"
                                     :arguments '("origin"))
                     "Git command timed out: fetch origin")
               (list (make-condition 'git-cancelled-error
                                     :repository nil
                                     :command "pull"
                                     :arguments nil)
                     "Git command was cancelled: pull")
               (list (make-condition 'git-launch-error
                                     :repository nil
                                     :command "status"
                                     :arguments nil)
                     "Git could not be launched: status")
               (list (make-condition 'git-io-error
                                     :repository nil
                                     :command "show"
                                     :arguments '("HEAD")
                                     :stream :stdout)
                     "Git command I/O failed: show HEAD")
               (list (make-condition 'git-launch-error
                                     :repository nil
                                     :command "status"
                                     :arguments nil
                                     :directory "repo"
                                     :cause :cause)
                     "Git could not be launched: status in repo: CAUSE")))
      (expect (%condition-report-string (first entry))
              :to-equal
              (second entry))))

  (it "reports Git parse positions only when available"
    (let ((with-position
            (make-condition 'git-parse-error
                            :format-name "status"
                            :record "bad"
                            :position 3))
          (without-position
            (make-condition 'git-parse-error
                            :format-name "diff"
                            :record "bad")))
      (expect (git-parse-error-format-name with-position)
              :to-equal
              "status")
      (expect (git-parse-error-record with-position) :to-equal "bad")
      (expect (git-parse-error-position with-position) :to-equal 3)
      (expect (%condition-report-string with-position)
              :to-equal
              "Could not parse Git status record at position 3: \"bad\"")
      (expect (search "at position" (%condition-report-string without-position))
              :to-be
              nil)))

  (it "preserves and reports GHQ failure context"
    (let* ((result (%fake-result :exit-code 9))
           (condition
             (make-condition 'ghq-error
                             :command "list"
                             :arguments '("--full-path")
                             :result result
                             :cause :cause)))
      (expect (ghq-error-command condition) :to-equal "list")
      (expect (ghq-error-arguments condition) :to-equal '("--full-path"))
      (expect (ghq-error-result condition) :to-be result)
      (expect (ghq-error-cause condition) :to-be :cause)
      (expect (%condition-report-string condition)
              :to-equal
              "GHQ command failed: list --full-path")))

  (it "reports every GHQ process outcome"
    (dolist (entry
              (list
               (list (make-condition 'ghq-exit-error
                                     :command "rm"
                                     :arguments '("owner/project")
                                     :exit-code 4)
                     "GHQ command failed: rm owner/project (exit 4)")
               (list (make-condition 'ghq-exit-error
                                     :command "rm"
                                     :arguments nil)
                     "GHQ command failed: rm")
               (list (make-condition 'ghq-timeout-error
                                     :command "get"
                                     :arguments '("owner/project"))
                     "GHQ command timed out: get owner/project")
               (list (make-condition 'ghq-cancelled-error
                                     :command "list"
                                     :arguments nil)
                     "GHQ command was cancelled: list")
               (list (make-condition 'ghq-launch-error
                                     :command "help"
                                     :arguments nil)
                     "GHQ could not be launched: help")))
      (expect (%condition-report-string (first entry))
              :to-equal
              (second entry))))

  (it "reports GHQ I/O context"
    (let ((condition
            (make-condition 'ghq-io-error
                            :command "list"
                            :arguments nil
                            :directory "repo"
                            :cause :cause
                            :stream :stderr)))
      (expect (ghq-io-error-stream condition) :to-be :stderr)
      (expect (%condition-report-string condition)
              :to-equal
              "GHQ command I/O failed: list in repo: CAUSE")))

  (it "reports backend-neutral command and backend failures"
    (let ((backend (find-vcs-backend :git)))
      (dolist (entry
                (list
                 (list (make-condition 'vcs-argument-error
                                       :argument "--bad"
                                       :position 2
                                       :reason "bad")
                       "Invalid VCS command argument at position 2: \"--bad\" (bad)")
                 (list (make-condition 'vcs-command-error
                                       :command "status"
                                       :arguments '("--short"))
                       "VCS command failed: status --short")
                 (list (make-condition 'vcs-command-exit-error
                                       :command "status"
                                       :arguments '("--short")
                                       :exit-code 2)
                       "VCS command failed: status --short (exit 2)")
                 (list (make-condition 'vcs-command-exit-error
                                       :command "status"
                                       :arguments nil)
                       "VCS command failed: status (exit NIL)")
                 (list (make-condition 'vcs-command-timeout-error
                                       :command "fetch"
                                       :arguments '("origin"))
                       "VCS command timed out: fetch origin")
                 (list (make-condition 'vcs-command-cancelled-error
                                       :command "pull"
                                       :arguments nil)
                       "VCS command was cancelled: pull")
                 (list (make-condition 'vcs-command-launch-error
                                       :command "status"
                                       :arguments '("--short")
                                       :directory "repo"
                                       :cause :cause)
                       "VCS could not be launched: status --short in repo: CAUSE")
                 (list (make-condition 'vcs-command-io-error
                                       :command "status"
                                       :arguments '("--short")
                                       :directory "repo"
                                       :cause :cause
                                       :stream :stdout)
                       "VCS command I/O failed: status --short in repo: CAUSE")
                 (list (make-condition 'vcs-unknown-backend-error
                                       :designator :missing
                                       :known-backends '(:git :mercurial))
                       "Unknown VCS backend :MISSING (known backends: GIT, MERCURIAL)")
                 (list (make-condition 'vcs-unknown-backend-error
                                       :designator :missing)
                       "Unknown VCS backend :MISSING (known backends: )")
                 (list (make-condition 'vcs-backend-registration-error
                                       :backend backend
                                       :designator :git
                                       :conflicting-backend backend)
                       "VCS backend designator :GIT is already claimed by GIT")
                 (list (make-condition 'vcs-backend-detection-error
                                       :directory "repo")
                       "Could not detect a VCS backend in repo")
                 (list (make-condition 'vcs-backend-detection-error)
                       "Could not detect a VCS backend in NIL")
                 (list (make-condition 'vcs-unsupported-operation-error
                                       :backend backend
                                       :operation :commit
                                       :capabilities '(:status))
                       "VCS backend GIT does not support operation COMMIT")
                 (list (make-condition 'vcs-unsupported-operation-error
                                       :backend backend
                                       :operation :commit)
                       "VCS backend GIT does not support operation COMMIT")))
        (expect (%condition-report-string (first entry))
                :to-equal
                (second entry)))
      (let ((condition
              (make-condition 'vcs-command-io-error
                              :command "status"
                              :arguments nil
                              :stream :stdout)))
        (expect (vcs-command-io-error-stream condition) :to-be :stdout)))))
