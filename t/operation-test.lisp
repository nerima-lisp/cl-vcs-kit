(in-package #:vcs-kit/test)

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
                      (make-vcs-repository (host-kit:temporary-directory)
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

  (it "replaces a registered backend without retaining stale aliases"
    (let ((original
            (make-vcs-backend
             :name :replaceable
             :aliases '(:old-alias)
             :commands '((:status . "old-status"))))
          (replacement
            (make-vcs-backend
             :name :replaceable
             :aliases '(:new-alias)
             :commands '((:status . "new-status")))))
      (unwind-protect
           (progn
             (register-vcs-backend original)
             (register-vcs-backend replacement)
             (expect (eq (find-vcs-backend :replaceable) replacement)
                     :to-be-truthy)
             (expect (eq (find-vcs-backend :new-alias) replacement)
                     :to-be-truthy)
             (%expect-condition vcs-unknown-backend-error
               (find-vcs-backend :old-alias)))
        (when (find :replaceable (available-vcs-backends)
                    :key #'vcs-backend-name)
          (unregister-vcs-backend :replaceable)))))

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
             (expect (vcs-backend-supports-structured-operation-p backend :version)
                     :to-be-falsy)
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
       :name :undeclared-operation-kind
       :capabilities '(:status)
       :operation-kinds '((:version . :exact))
       :commands '((:status . "status")
                   (:version . "version"))))
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
                                    (host-kit:ensure-directory-pathname parent)))
                 (expect (eq (vcs-repository-backend repository) backend)
                         :to-be-truthy))))
        (when (find :marker-echo (available-vcs-backends)
                    :key #'vcs-backend-name)
          (unregister-vcs-backend :marker-echo))
        (host-kit:delete-directory-tree parent
                                     :validate t
                                     :if-does-not-exist :ignore))))

)
