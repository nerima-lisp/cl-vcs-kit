(in-package #:vcs-kit/test)

(defparameter *generated-git-operations*
  '(git-add git-stage git-commit git-branch git-switch git-checkout
    git-restore git-reset git-rm git-mv git-clean git-tag
    git-update-ref git-merge git-rebase git-cherry-pick
    git-revert git-stash git-sparse-checkout git-rerere
    git-cherry git-check-mailmap git-column git-diff-pairs
    git-format-rev git-get-tar-commit-id
    git-interpret-trailers git-last-modified git-ls-remote
    git-name-rev git-patch-id git-range-diff git-show-index
    git-var
    git-backfill git-bugreport git-citool git-diagnose
    git-difftool git-filter-branch git-for-each-repo git-help
    git-instaweb git-mergetool git-pack-refs git-refs
    git-replay git-repo git-request-pull
    git-remote git-fetch git-pull git-push git-worktree
    git-submodule git-notes git-bisect git-archive git-bundle
    git-format-patch git-am git-apply git-fast-export
    git-fast-import git-archimport git-cvsexportcommit
    git-cvsimport git-cvsserver git-imap-send git-p4
    git-quiltimport git-send-email git-svn git-maintenance
    git-gc git-prune git-prune-packed git-repack git-fsck
    git-commit-tree git-config git-credential git-fmt-merge-msg
    git-fsck-objects git-hash-object git-hook git-index-pack
    git-init-db git-mailinfo git-mailsplit git-merge-file
    git-merge-index git-merge-tree git-mktag git-mktree
    git-pack-objects git-pack-redundant git-read-tree
    git-receive-pack git-replace git-send-pack git-stripspace
    git-unpack-file git-unpack-objects git-update-index
    git-update-server-info git-upload-archive git-upload-pack
    git-verify-commit git-verify-pack git-verify-tag git-write-tree
    git-checkout-index git-commit-graph git-multi-pack-index))

(describe "generated Git operation families"
  (it "exposes every documented checked operation"
    (dolist (name *generated-git-operations*)
      (expect (fboundp name) :to-be-truthy)))

  (it "dispatches every generated operation through the checked runner"
    (let ((repository (make-repository (uiop:temporary-directory)))
          (calls 0))
      (with-replaced-function
          (vcs-kit::run-git/checked
           (lambda (&rest arguments)
             (declare (ignore arguments))
             (incf calls)
             (%fake-result)))
        (dolist (name *generated-git-operations*)
          (expect (process-success-p (funcall name repository))
                  :to-be-truthy)))
      (expect calls :to-equal (length *generated-git-operations*))))

  (it "parses the specialized observation operations"
    (let ((repository (make-repository (uiop:temporary-directory)))
          (calls 0))
      (with-replaced-function
          (vcs-kit::run-git/checked
           (lambda (repository command arguments &rest options)
             (declare (ignore repository arguments options))
             (incf calls)
             (%fake-result
              :stdout (if (string= command "rev-parse")
                          (format nil " value ~%")
                          ""))))
        (expect (process-success-p (git-diff repository "HEAD"))
                :to-be-truthy)
        (expect (process-success-p (git-diff-stat repository "HEAD"))
                :to-be-truthy)
        (expect (git-diff-name-status repository "HEAD") :to-be nil)
        (expect (git-diff-numstat repository "HEAD") :to-be nil)
        (expect (process-success-p (git-diff-check repository "HEAD"))
                :to-be-truthy)
        (dolist (untracked-files '(:no :normal :all))
        (expect (status-snapshot-p
                 (git-status repository
                             :untracked-files untracked-files
                             :ignored t
                             :show-stash t
                             :no-renames t
                             :arguments '("path")))
                  :to-be-truthy))
        (expect (git-rev-parse-value repository) :to-equal "value")
      (expect calls :to-equal 9)))))

(describe "backend-neutral VCS operations"
  (it "exposes the built-in backends and aliases"
    (dolist (name '(:git :mercurial :subversion :bazaar :fossil :darcs :pijul))
      (expect (vcs-backend-p (find-vcs-backend name)) :to-be-truthy))
    (expect (eq (find-vcs-backend :hg)
                (find-vcs-backend :mercurial))
            :to-be-truthy)
    (expect (eq (find-vcs-backend :svn)
                (find-vcs-backend :subversion))
            :to-be-truthy)
    (expect (vcs-backend-supports-operation-p :git :status)
            :to-be-truthy)
    (expect (vcs-operation-command :git :status)
            :to-equal "status")
    (expect (vcs-backend-markers (find-vcs-backend :git))
            :to-equal '(".git"))
    (expect (vcs-operation-kind :git :status)
            :to-equal :exact)
    (expect (vcs-operation-kind :git :worktree)
            :to-equal :native)
    (expect (vcs-operation-kind :mercurial :fetch)
            :to-equal :approximate)
    (dolist (name '(vcs-worktree vcs-submodule vcs-bundle
                    vcs-maintenance vcs-verify))
      (expect (fboundp name) :to-be-truthy)))

  (it "keeps every built-in descriptor internally coherent"
    (dolist (backend (available-vcs-backends))
      (expect (vcs-supported-operations backend) :to-be-truthy)
      (dolist (operation (vcs-supported-operations backend))
        (let ((info (vcs-operation-info backend operation)))
          (expect (vcs-operation-command backend operation)
                  :to-be-truthy)
          (expect info :to-be-truthy)
          (expect (member (vcs-operation-info-mapping-kind info)
                          '(:exact :alias :approximate :native))
                  :to-be-truthy)))))

  (it "registers a custom backend and dispatches normalized operations"
    (let ((backend
            (make-vcs-backend
             :name :echo
             :aliases '("echo-vcs" echo-short)
             :executable (%program-path "echo")
             :markers (list (pathname ".echo-vcs"))
             :commands (list (list :status "show-status" "--raw")
                             (list :version "version")
                             (cons :help
                                   (lambda (backend operation)
                                     (declare (ignore backend operation))
                                     "help"))))))
      (unwind-protect
           (progn
             (register-vcs-backend backend)
             (expect (eq (find-vcs-backend "echo-vcs") backend)
                     :to-be-truthy)
             (expect (eq (find-vcs-backend 'echo-short) backend)
                     :to-be-truthy)
             (let* ((repository
                      (make-vcs-repository (uiop:temporary-directory)
                                           :backend :echo))
                    (result (vcs-status repository "item")))
               (expect (process-success-p result) :to-be-truthy)
               (expect (process-result-program result)
                       :to-equal (%program-path "echo"))
               (expect (process-result-stdout result)
                       :to-equal (format nil "show-status --raw item~%")))
             (expect (vcs-operation-command backend :version)
                     :to-equal "version")
             (expect (vcs-operation-command backend :help)
                     :to-equal "help")
             (expect (vcs-backend-markers backend)
                     :to-equal '(".echo-vcs")))
        (when (find :echo (available-vcs-backends)
                    :key #'vcs-backend-name)
          (unregister-vcs-backend :echo)))))

  (it "keeps declared capabilities authoritative"
    (let ((backend
            (make-vcs-backend
             :name :capability-echo
             :executable (%program-path "echo")
             :capabilities '(:status)
             :structured-operations '(:status)
             :commands '((:status . "status")
                         (:version . "--version")))))
      (unwind-protect
           (progn
             (register-vcs-backend backend)
             (expect (vcs-backend-supports-operation-p backend :status)
                     :to-be-truthy)
             (expect (vcs-backend-supports-operation-p backend :version)
                     :to-be-falsy)
             (expect (vcs-supported-operations backend)
                     :to-equal '(:status))
             (expect (vcs-backend-supports-structured-operation-p backend :status)
                     :to-be-truthy)
             (expect (vcs-structured-operations backend)
                     :to-equal '(:status))
             (expect (vcs-operation-command backend :version)
                     :to-be-falsy)
             (expect (vcs-operation-info backend :status)
                     :to-be-truthy))
        (when (find :capability-echo (available-vcs-backends)
                    :key #'vcs-backend-name)
          (unregister-vcs-backend :capability-echo)))))

  (it "rejects backend name and alias collisions"
    (let ((first
            (make-vcs-backend
             :name :collision-first
             :aliases '(:collision-shared)
             :commands '((:status . "status"))))
          (second
            (make-vcs-backend
             :name :collision-second
             :aliases '(:collision-shared)
             :commands '((:status . "status")))))
      (unwind-protect
           (progn
             (register-vcs-backend first)
             (let ((same-name
                     (make-vcs-backend
                      :name :collision-first
                      :commands '((:status . "status")))))
               (let ((condition
                       (%expect-condition vcs-backend-registration-error
                         (register-vcs-backend same-name :replace nil))))
                 (expect
                  (vcs-backend-registration-error-designator condition)
                  :to-equal :collision-first)
                 (expect
                  (eq (vcs-backend-registration-error-conflicting-backend
                       condition)
                      first)
                  :to-be-truthy)))
             (let ((condition
                     (%expect-condition vcs-backend-registration-error
                       (register-vcs-backend second))))
               (expect
                (vcs-backend-registration-error-designator condition)
                :to-equal :collision-shared)
               (expect
                (eq (vcs-backend-registration-error-conflicting-backend
                     condition)
                    first)
                :to-be-truthy)))
        (dolist (name '(:collision-first :collision-second))
          (when (find name (available-vcs-backends)
                      :key #'vcs-backend-name)
            (unregister-vcs-backend name))))))

  (it "rejects self-colliding backend designators at registration"
    (let ((backend
            (make-vcs-backend
             :name :self-collision
             :aliases '(:self-collision)
             :commands '((:status . "status")))))
      (let ((condition
              (%expect-condition vcs-backend-registration-error
                (register-vcs-backend backend))))
        (expect (vcs-backend-registration-error-designator condition)
                :to-equal :self-collision)
        (expect (eq (vcs-backend-registration-error-conflicting-backend
                     condition)
                    backend)
                :to-be-truthy))))

  (it "rejects capabilities without executable command mappings"
    (%expect-condition error
      (make-vcs-backend
       :name :invalid-capability
       :capabilities '(:status)
       :commands '((:version . "--version"))))
    (%expect-condition error
      (make-vcs-backend
       :name :invalid-operation-kind
       :operation-kinds '((:version . :exact))
       :commands '((:status . "status"))))
    (%expect-condition error
      (make-vcs-backend
       :name :invalid-mapping-entry
       :operation-kinds '(invalid)
       :commands '((:status . "status"))))
    (%expect-condition error
      (make-vcs-backend
       :name :invalid-mapping-kind
       :operation-kinds '((:status . :invalid))
       :commands '((:status . "status"))))
    (%expect-condition error
      (make-vcs-backend
       :name :duplicate-operation-mapping
       :operation-kinds '((:status . :exact)
                          (:status . :alias))
       :commands '((:status . "status"))))
    (%expect-condition error
      (make-vcs-backend
       :name :invalid-command-entry
       :commands '(invalid)))
    (%expect-condition error
      (make-vcs-backend
       :name :duplicate-command
       :commands '((:status . "status")
                   (:status . "status")))))

  (it "detects metadata declared by a registered backend"
    (let ((parent (%temporary-test-directory))
          (backend
            (make-vcs-backend
             :name :marker-echo
             :executable (%program-path "echo")
             :markers '(".marker-vcs")
             :commands '((:status . "status")))))
      (unwind-protect
           (progn
             (register-vcs-backend backend)
             (ensure-directories-exist (merge-pathnames ".marker-vcs/"
                                                        parent))
             (let ((nested (merge-pathnames "nested/child/" parent)))
               (ensure-directories-exist nested)
               (expect (eq (detect-vcs-backend parent
                                               :candidates '(:marker-echo))
                           backend)
                       :to-be-truthy)
               (expect (eq (detect-vcs-backend
                            parent
                            :candidates '(:marker-echo)
                            :validate-executable t)
                           backend)
                       :to-be-truthy)
               (expect (eq (detect-vcs-backend
                            parent
                            :candidates '(:marker-echo)
                            :validate-executable t
                            :executable (%program-path "echo"))
                           backend)
                       :to-be-truthy)
               (let ((repository
                       (discover-vcs-repository nested
                                                :candidates '(:marker-echo)
                                                :validate-executable t
                                                :executable (%program-path "echo"))))
                 (expect (vcs-repository-directory repository)
                         :to-equal (namestring
                                    (uiop:ensure-directory-pathname parent)))
                 (expect (eq (vcs-repository-backend repository) backend)
                         :to-be-truthy))))
        (when (find :marker-echo (available-vcs-backends)
                    :key #'vcs-backend-name)
          (unregister-vcs-backend :marker-echo))
        (uiop:delete-directory-tree parent
                                     :validate t
                                     :if-does-not-exist :ignore))))

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

  (it "parses worktree flags with and without explanatory values"
    (let ((worktree
            (vcs-kit::%vcs-worktree
             '("worktree /tmp/linked" "HEAD abc123"
               "branch refs/heads/topic"
               "locked reason"
               "prunable reason"
               "bare"))))
      (expect (vcs-worktree-path worktree) :to-equal "/tmp/linked")
      (expect (vcs-worktree-head worktree) :to-equal "abc123")
      (expect (vcs-worktree-branch worktree) :to-equal "topic")
      (expect (vcs-worktree-bare-p worktree) :to-be-truthy)
      (expect (vcs-worktree-locked-p worktree) :to-be-truthy)
      (expect (vcs-worktree-prunable-p worktree) :to-be-truthy))
    (let ((detached (vcs-kit::%vcs-worktree '("branch detached"))))
      (expect (vcs-worktree-branch detached) :to-equal "detached")))

  (it "dispatches the extended native operation families"
    (let ((repository (make-vcs-repository (uiop:temporary-directory)
                                           :backend :git
                                           :executable (%program-path "echo"))))
      (dolist (operation '((vcs-worktree . "worktree")
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
                         (find-vcs-backend :mercurial))
                     :to-be-truthy)
             (let ((repository (open-vcs-repository directory)))
               (expect (vcs-repository-p repository) :to-be-truthy)
               (expect (vcs-backend-name
                        (vcs-repository-backend repository))
                       :to-equal :mercurial))
             (let* ((nested (merge-pathnames "nested/child/" directory))
                    (repository (progn
                                  (ensure-directories-exist nested)
                                  (discover-vcs-repository nested))))
               (expect (vcs-repository-directory repository)
                       :to-equal (namestring
                                  (uiop:ensure-directory-pathname directory)))
               (expect (vcs-backend-name
                        (vcs-repository-backend repository))
                       :to-equal :mercurial))
             (let ((empty-directory (%temporary-test-directory)))
               (unwind-protect
                    (let ((condition
                            (%expect-condition vcs-backend-detection-error
                              (open-vcs-repository empty-directory))))
                      (expect (vcs-backend-detection-error-directory condition)
                              :to-equal (namestring empty-directory)))
                 (uiop:delete-directory-tree empty-directory
                                              :validate t
                                              :if-does-not-exist :ignore))))
        (uiop:delete-directory-tree directory
                                     :validate t
                                     :if-does-not-exist :ignore))))

  (it "detects bare Git repositories"
    (let ((directory (%temporary-test-directory)))
      (unwind-protect
           (progn
             (git-init directory :bare t)
             (expect (eq (detect-vcs-backend directory)
                         (find-vcs-backend :git))
                     :to-be-truthy)
             (let ((repository (open-vcs-repository directory)))
               (expect (vcs-repository-p repository) :to-be-truthy)
               (expect (vcs-backend-name
                        (vcs-repository-backend repository))
                       :to-equal :git)))
        (uiop:delete-directory-tree directory
                                     :validate t
                                     :if-does-not-exist :ignore))))

  (it "can reject metadata when executable validation fails"
    (let ((directory (%temporary-test-directory)))
      (unwind-protect
           (progn
             (ensure-directories-exist (merge-pathnames ".git/" directory))
             (expect (detect-vcs-backend
                      directory
                      :candidates '(:git)
                      :validate-executable t
                      :executable "/bin/false")
                     :to-be nil)
             (let ((condition
                     (%expect-condition vcs-backend-detection-error
                       (open-vcs-repository
                        directory
                        :backend :git
                        :validate-executable t
                        :executable "/bin/false"))))
               (expect (vcs-backend-detection-error-directory condition)
                       :to-equal (namestring directory))))
        (uiop:delete-directory-tree directory
                                     :validate t
                                     :if-does-not-exist :ignore))))

)