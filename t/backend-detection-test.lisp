(in-package #:vcs-kit/test)

(describe "backend detection and dispatch"
  (it "reports unknown backend designators"
    (let ((condition
            (%expect-condition vcs-unknown-backend-error
              (find-vcs-backend :missing-backend))))
      (expect (vcs-unknown-backend-error-designator condition)
              :to-equal :missing-backend)
      (expect (member :git
                      (vcs-unknown-backend-error-known-backends condition))
              :to-be-truthy)))

  (it "rejects malformed backend designators with a typed argument error"
    (%expect-condition vcs-argument-error
      (find-vcs-backend 42)))

  (it "rejects malformed backend command designators"
    (%expect-condition error
      (make-vcs-backend :commands '((:status . 42)))))

  (it "dispatches the extended native operation families"
    (let ((repository (make-vcs-repository (host-kit:temporary-directory)
                                           :backend :git
                                           :executable (%program-path "echo"))))
      (dolist (operation '((vcs-branch . "branch")
                           (vcs-worktree . "worktree")
                           (vcs-submodule . "submodule")
                           (vcs-bundle . "bundle")
                           (vcs-maintenance . "maintenance")
                           (vcs-verify . "fsck")))
        (let ((result (funcall (car operation) repository)))
          (expect (process-success-p result) :to-be-truthy)
          (expect (process-result-stdout result)
                  :to-equal (format nil "~A~%" (cdr operation)))))))

  (it "detects repository metadata and reports missing metadata"
    (let ((directory (%temporary-test-directory)))
      (unwind-protect
           (progn
             (ensure-directories-exist (merge-pathnames ".hg/" directory))
             (expect (eq (detect-vcs-backend directory)
                         (find-vcs-backend :mercurial)) :to-be-truthy)
             (let ((repository (open-vcs-repository directory)))
               (expect (vcs-repository-p repository) :to-be-truthy)
               (expect (vcs-backend-name (vcs-repository-backend repository))
                       :to-equal :mercurial))
             (let* ((nested (merge-pathnames "nested/child/" directory))
                    (repository (progn
                                  (ensure-directories-exist nested)
                                  (discover-vcs-repository nested))))
               (expect (vcs-repository-directory repository)
                       :to-equal (namestring
                                  (host-kit:ensure-directory-pathname directory)))
               (expect (vcs-backend-name (vcs-repository-backend repository))
                       :to-equal :mercurial))
             (let ((empty-directory (%temporary-test-directory)))
               (unwind-protect
                    (let ((condition
                            (%expect-condition vcs-backend-detection-error
                              (open-vcs-repository empty-directory))))
                      (expect (vcs-backend-detection-error-directory condition)
                              :to-equal (namestring empty-directory)))
                 (host-kit:delete-directory-tree empty-directory
                                              :validate t
                                              :if-does-not-exist :ignore))))
        (host-kit:delete-directory-tree directory
                                     :validate t
                                     :if-does-not-exist :ignore))))

  (it "detects bare Git repositories"
    (let ((directory (%temporary-test-directory)))
      (unwind-protect
           (progn
             (git-init directory :bare t)
             (expect (eq (detect-vcs-backend directory)
                         (find-vcs-backend :git)) :to-be-truthy)
             (let ((repository (open-vcs-repository directory)))
               (expect (vcs-repository-p repository) :to-be-truthy)
               (expect (vcs-backend-name (vcs-repository-backend repository))
                       :to-equal :git)))
        (host-kit:delete-directory-tree directory
                                     :validate t
                                     :if-does-not-exist :ignore))))

  (it "reports missing metadata after walking repository ancestors"
    (let ((directory (%temporary-test-directory)))
      (unwind-protect
           (let ((condition
                   (%expect-condition vcs-backend-detection-error
                     (discover-vcs-repository directory))))
             (expect (vcs-backend-detection-error-directory condition)
                     :to-equal (namestring directory)))
        (host-kit:delete-directory-tree directory
                                        :validate t
                                        :if-does-not-exist :ignore))))

  (it "can reject metadata when executable validation fails"
    (let ((directory (%temporary-test-directory)))
      (unwind-protect
           (progn
             (ensure-directories-exist (merge-pathnames ".git/" directory))
             (expect (detect-vcs-backend directory :candidates '(:git)
                                         :validate-executable t
                                         :executable "/bin/false") :to-be nil)
             (let ((condition
                     (%expect-condition vcs-backend-detection-error
                       (open-vcs-repository directory :backend :git
                                            :validate-executable t
                                            :executable "/bin/false"))))
               (expect (vcs-backend-detection-error-directory condition)
                       :to-equal (namestring directory))))
        (host-kit:delete-directory-tree directory
                                     :validate t
                                     :if-does-not-exist :ignore)))))
