(in-package #:vcs-kit/test)

(describe "repository remote and submodule metadata"
  (it "batches remote refspec configuration queries"
    (let ((repository (make-vcs-repository (host-kit:temporary-directory)
                                           :backend :git))
          (calls nil))
      (with-replaced-function
          (vcs-kit::%vcs-structured-run
           (lambda (called-repository command arguments execution-options)
             (declare (ignore called-repository execution-options))
             (push (list command arguments) calls)
             (cond
               ((string= command "remote")
                (%fake-result
                 :stdout
                 (format nil
                         "origin~Chttps://example.invalid/origin (fetch)~%backup~Chttps://example.invalid/backup (fetch)~%"
                         #\Tab #\Tab)))
               ((string= command "config")
                (%fake-result
                 :stdout
                 (format nil
                         "remote.origin.fetch first-fetch~%remote.origin.fetch second-fetch~%remote.origin.push origin-push~%remote.backup.fetch backup-fetch~%remote.origin.url ignored~%")))
               (t
                (error "Unexpected fake structured command: ~A" command)))))
        (let* ((remotes (vcs-list-remotes repository))
               (origin (first remotes))
               (backup (second remotes))
               (config-call
                 (find-if (lambda (call)
                            (string= (first call) "config"))
                          calls)))
          (expect (length calls) :to-equal 2)
          (expect (mapcar (lambda (remote)
                            (vcs-remote-name remote))
                          remotes)
                  :to-equal
                  '("origin" "backup"))
          (expect (vcs-remote-fetch-refspecs origin)
                  :to-equal
                  '("first-fetch" "second-fetch"))
          (expect (vcs-remote-push-refspecs origin)
                  :to-equal
                  '("origin-push"))
          (expect (vcs-remote-fetch-refspecs backup)
                  :to-equal
                  '("backup-fetch"))
          (expect (vcs-remote-push-refspecs backup)
                  :to-be
                  nil)
          (expect (second config-call)
                  :to-equal
                  '("--get-regexp" "^remote\\..*\\."))))))

  (it "propagates remote refspec configuration failures"
    (let ((repository (make-vcs-repository (host-kit:temporary-directory)
                                           :backend :git)))
      (with-replaced-function
          (vcs-kit::%vcs-structured-run
           (lambda (called-repository command arguments execution-options)
             (declare (ignore called-repository arguments execution-options))
             (if (string= command "remote")
                 (%fake-result
                  :stdout
                  (format nil
                          "origin~Chttps://example.invalid/origin (fetch)~%"
                          #\Tab))
                 (error 'vcs-command-exit-error :exit-code 2))))
        (let ((condition
                (%expect-condition vcs-command-exit-error
                  (vcs-list-remotes repository))))
          (expect (vcs-command-exit-error-exit-code condition)
                  :to-equal
                  2)))))

  (it "uses fallback submodule metadata and rejects malformed records"
    (let ((repository (make-vcs-repository (host-kit:temporary-directory)
                                           :backend :git))
          (mode :valid))
      (with-replaced-function
          (vcs-kit::%vcs-structured-run
           (lambda (called-repository command arguments execution-options)
             (declare (ignore called-repository execution-options))
             (cond
               ((string= command "submodule")
                (%fake-result
                 :stdout
                 (if (eq mode :valid)
                     (format nil " abc123 deps/child (dirty)~%")
                     (format nil "malformed~%"))))
               ((string= command "config")
                (cond
                  ((member "--file" arguments :test #'string=)
                   (error 'vcs-command-exit-error :exit-code 1))
                  ((member "--get-regexp" arguments :test #'string=)
                   (%fake-result
                    :stdout
                    (format nil "submodule.child.path deps/child~%")))
                  ((member "--get" arguments :test #'string=)
                   (%fake-result
                    :stdout
                    (format nil "https://example.invalid/child~%")))
                  (t
                   (error "Unexpected fake config arguments: ~S"
                          arguments))))
               ((string= command "ls-files")
                (%fake-result
                 :stdout
                 (format nil "160000 index-object 0~Cdeps/child~%" #\Tab)))
               (t
                (error "Unexpected fake structured command: ~A" command)))))
        (let ((submodule (first (vcs-list-submodules repository))))
          (expect (vcs-submodule-path submodule) :to-equal "deps/child")
          (expect (vcs-submodule-name submodule) :to-equal "child")
          (expect (vcs-submodule-url submodule)
                  :to-equal
                  "https://example.invalid/child")
          (expect (vcs-submodule-head submodule) :to-equal "abc123")
          (expect (vcs-submodule-index submodule) :to-equal "index-object")
          (expect (vcs-submodule-worktree-status submodule) :to-equal " "))
        (setf mode :malformed)
        (%expect-condition error
          (vcs-list-submodules repository)))))

  (it "returns structured Git submodule metadata"
    (%with-temporary-repository (repository)
      (let* ((parent-directory (repository-directory repository))
             (source-directory
               (merge-pathnames "submodule-source/"
                                (pathname parent-directory)))
             (submodule-path "deps/child"))
        (git-init source-directory :initial-branch "main")
        (let ((source (open-repository source-directory)))
          (%write-test-file source-directory "child.txt"
                            (format nil "child content~%"))
          (git-add source "--" "child.txt")
          (git-config source "user.name" "VCS Kit Test")
          (git-config source "user.email" "vcs-kit@example.invalid")
          (git-config source "commit.gpgSign" "false")
          (git-commit source "-m" "child"))
        (git-config repository "protocol.file.allow" "always")
        (git-submodule repository "add" "-f"
                       (namestring source-directory)
                       submodule-path
                       :execution-options
                       '(:environment-update (("GIT_ALLOW_PROTOCOL" . "file"))))
        (let* ((submodules (vcs-list-submodules repository))
               (submodule (first submodules))
               (source (open-repository source-directory))
               (source-head (git-rev-parse-value source "HEAD")))
          (expect (length submodules) :to-equal 1)
          (expect (vcs-submodule-path submodule) :to-equal submodule-path)
          (expect (vcs-submodule-name submodule) :to-equal submodule-path)
          (expect (vcs-submodule-url submodule)
                  :to-equal
                  (namestring source-directory))
          (expect (vcs-submodule-head submodule) :to-equal source-head)
          (expect (vcs-submodule-index submodule) :to-equal source-head)
          (expect (vcs-submodule-worktree-status submodule)
                  :to-equal
                  " ")))))

  (it "provides the documented repository construction controls"
    (let ((repository
            (make-repository #p"/tmp/"
                             :executable "git"
                             :default-timeout 12d0
                             :environment '(("GIT_CONFIG_NOSYSTEM" . "1"))
                             :bare-p t)))
      (expect (repository-executable repository) :to-equal "git")
      (expect (repository-default-timeout repository) :to-equal 12d0)
      (expect (repository-environment repository)
              :to-equal
              '(("GIT_CONFIG_NOSYSTEM" . "1")))
      (expect (repository-bare-p repository) :to-be-truthy))))
