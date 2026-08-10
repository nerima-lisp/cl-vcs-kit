(in-package #:vcs-kit/test)

(describe "Asynchronous process and structured GHQ APIs"
  (it "preserves process-kit tasks and event inspection"
    (let ((task (run-git-async
                 nil
                 "--version"
                 nil
                 :executable (%program-path "echo")
                 :environment-update '(("POSIXLY_CORRECT" . "1"))
                 :event-callback (lambda (event)
                                   (declare (ignore event))))))
      (expect (vcs-task-state task) :to-be-truthy)
      (multiple-value-bind (result completed-p)
          (await-vcs-task task)
        (expect completed-p :to-be-truthy)
        (expect (process-success-p result) :to-be-truthy)
        (expect (process-result-stdout result)
                :to-equal
                (format nil "--version~%"))
        (expect (eq result (vcs-task-result task)) :to-be-truthy)
        (expect (vcs-task-condition task) :to-be nil)
        (expect (listp (vcs-task-events task)) :to-be-truthy)
        (expect (vcs-task-callback-errors task) :to-be nil)
        (expect (vcs-task-dropped-event-count task) :to-equal 0)
        (let ((step (next-vcs-event task :cursor 1 :timeout 0d0)))
          (expect (member (process-kit:process-event-step-status step)
                          '(:event :gap :terminal :timeout))
                  :to-be-truthy)))
      (expect (eq (cancel-vcs-task task) task) :to-be-truthy)))

  (it "starts Git, GHQ, and backend-neutral version tasks"
    (dolist (task (list (git-version-async
                         :executable (%program-path "echo")
                         :environment-update '(("POSIXLY_CORRECT" . "1")))
                        (ghq-version-async
                         :executable (%program-path "echo")
                         :environment-update '(("POSIXLY_CORRECT" . "1")))
                        (vcs-version-async
                         :backend :git
                         :executable (%program-path "echo")
                         :environment-update '(("POSIXLY_CORRECT" . "1")))))
      (multiple-value-bind (result completed-p)
          (await-vcs-task task :timeout 5d0)
        (expect completed-p :to-be-truthy)
        (expect (process-success-p result) :to-be-truthy)
        (expect (process-result-stdout result)
                :to-equal
                (format nil "--version~%")))))

  (it "runs synchronous Git, GHQ, and backend-neutral versions"
    (dolist (result (list (git-version
                           :executable (%program-path "echo")
                           :environment-update '(("POSIXLY_CORRECT" . "1")))
                          (ghq-version
                           :executable (%program-path "echo")
                           :environment-update '(("POSIXLY_CORRECT" . "1")))
                          (vcs-version :backend :git
                                       :executable (%program-path "echo")
                                       :environment-update '(("POSIXLY_CORRECT" . "1")))))
      (expect (process-success-p result) :to-be-truthy)
      (expect (process-result-stdout result)
              :to-equal
              (format nil "--version~%"))))

  (it "starts a normalized backend operation task"
    (let* ((repository
             (make-vcs-repository (uiop:temporary-directory)
                                  :backend :git
                                  :executable (%program-path "echo")))
           (task (run-vcs-operation-async repository :status '("file"))))
      (multiple-value-bind (result completed-p)
          (await-vcs-task task :timeout 5d0)
        (expect completed-p :to-be-truthy)
        (expect (process-success-p result) :to-be-truthy)
        (expect (process-result-stdout result)
                :to-equal
                (format nil "status file~%")))))

  (it "maps asynchronous launch failures to typed conditions"
    (%expect-condition git-launch-error
      (run-git-async nil "--version" nil
                     :executable "/definitely-missing-git-executable"))
    (%expect-condition ghq-launch-error
      (run-ghq-async "--version" nil
                     :executable "/definitely-missing-ghq-executable"))
    (%expect-condition vcs-command-launch-error
      (run-vcs-async nil "status" nil
                     :executable "/definitely-missing-vcs-executable")))

  (it "maps GHQ paths to repository specifications using the deepest root"
    (let* ((primary-root "test-root/src/")
           (secondary-root "test-root/")
           (first-path "test-root/src/owner/project")
           (second-path "test-root/other/repo")
           (orphan-path "elsewhere/orphan")
           (entries nil)
           (calls nil))
      (with-replaced-function
          (vcs-kit::%run-ghq-checked
           (lambda (command arguments &rest options)
             (declare (ignore options))
             (push (list command arguments) calls)
             (%fake-result
              :stdout
              (if (string= command "list")
                  (format nil "~A~%~A~%~A~%"
                          first-path second-path orphan-path)
                  (format nil "~A~%~A~%/~%"
                          primary-root secondary-root)))))
        (setf entries
              (ghq-list-repositories
               :vcs "git"
               :arguments '("--custom")
               :root-arguments '("--configured"))))
      (expect (mapcar #'ghq-repository-entry-specification entries)
              :to-equal
              '("owner/project" "other/repo" "elsewhere/orphan"))
      (expect (mapcar #'ghq-repository-entry-path entries)
              :to-equal
              (list first-path second-path orphan-path))
      (expect (mapcar #'ghq-repository-entry-backend entries)
              :to-equal
              '("git" "git" "git"))
      (expect (nreverse calls)
              :to-equal
              '(("list" ("-p" "--vcs" "git" "--custom"))
                ("root" ("--all" "--configured"))))))

  (it "marks the primary GHQ root in root entries"
    (let ((entries nil))
      (with-replaced-function
          (vcs-kit::%run-ghq-checked
           (lambda (command arguments &rest options)
             (declare (ignore command arguments options))
             (%fake-result :stdout (format nil "/first~%/second~%"))))
        (setf entries (ghq-list-root-entries)))
      (expect (mapcar #'ghq-root-entry-path entries)
              :to-equal
              '("/first" "/second"))
      (expect (mapcar #'ghq-root-entry-primary-p entries)
              :to-equal
              '(t nil))))

  (it "keeps GHQ path identity well-defined at root boundaries"
    (expect (vcs-kit::%ghq-root-prefix-p "/root/" "/root/repo")
            :to-be
            t)
    (expect (vcs-kit::%ghq-root-prefix-p "/root/" "/rooted/repo")
            :to-be
            nil)
    (expect (vcs-kit::%ghq-relative-path "/root/" (list "/root/"))
            :to-equal
            "")
    (expect (vcs-kit::%ghq-relative-path "/" (list "/"))
            :to-equal
            "")
    (expect (vcs-kit::%ghq-relative-path
             "/root/src/owner/project"
             (list "/root/" "/root/src/"))
            :to-equal
            "owner/project")
    (expect (vcs-kit::%ghq-repository-specification
             "/root/src/owner/project"
             (list "/root/" "/root/src/"))
            :to-equal
            "owner/project")
    (expect (vcs-kit::%ghq-relative-path "/rooted/repo" (list "/root/"))
            :to-equal
            "/rooted/repo")
    (expect (vcs-kit::%ghq-repository-specification
             "/root/a//b"
             (list "/root/"))
            :to-equal
            "a/b")
    (let ((entries nil)
          (root-entries nil))
      (with-replaced-function
          (vcs-kit::%run-ghq-checked
           (lambda (command arguments &rest options)
             (declare (ignore arguments options))
             (%fake-result
              :stdout
              (if (string= command "list")
                  (format nil "/orphan/repo~%")
                  ""))))
        (setf entries (ghq-list-repositories))
        (setf root-entries (ghq-list-root-entries)))
      (expect (mapcar #'ghq-repository-entry-specification entries)
              :to-equal
              '("orphan/repo"))
      (expect root-entries :to-be nil))))
