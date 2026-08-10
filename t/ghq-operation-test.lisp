(in-package #:vcs-kit/test)

(describe "GHQ management argument builders"
  (it "dispatches all management wrappers through the checked runner"
    (let ((calls nil))
      (with-replaced-function
          (vcs-kit::run-ghq/checked
           (lambda (command arguments &rest options)
             (declare (ignore options))
             (push (list command arguments) calls)
             (%fake-result
              :stdout (if (member command '("list" "root") :test #'string=)
                          (format nil "/one~%/two~%")
                          ""))))
        (ghq-get '("owner/project" "team/project")
                 :arguments '("--custom"))
        (ghq-clone "owner/project"
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
                   :arguments '("--clone-extra"))
        (expect (ghq-list :query "term" :arguments '("--filter"))
                :to-equal
                '("/one" "/two"))
        (expect (ghq-roots :all t :arguments '("--configured"))
                :to-equal
                '("/one" "/two"))
        (expect (ghq-root :all t)
                :to-equal
                '("/one" "/two"))
        (expect (ghq-path "owner/project"
                          :query "ignored"
                          :exact nil
                          :full-path nil
                          :arguments '("--extra"))
                :to-equal
                "/one")
        (ghq-rm "owner/project"
                :dry-run t
                :bare t
                :arguments '("--force"))
        (ghq-create "owner/project"
                    :vcs "git"
                    :bare t
                    :arguments '("--create-extra"))
        (ghq-migrate "/tmp/repository"
                      :yes t
                      :dry-run t
                      :arguments '("--migrate-extra"))
        (ghq-help)
        (expect (nreverse calls)
                :to-equal
                '(("get" ("--custom" "owner/project" "team/project"))
                  ("clone" ("-u" "-p" "--shallow" "--vcs" "git"
                            "--look" "--silent" "--branch" "main"
                            "--no-recursive" "-P" "--bare" "--partial"
                            "blobless" "--clone-extra" "owner/project"))
                  ("list" ("--filter" "term"))
                  ("root" ("--all" "--configured"))
                  ("root" ("--all"))
                  ("list" ("-p" "-e" "--extra" "owner/project"))
                  ("rm" ("--dry-run" "--bare" "--force" "owner/project"))
                  ("create" ("--vcs" "git" "--bare" "--create-extra"
                              "owner/project"))
                  ("migrate" ("-y" "--dry-run" "--migrate-extra"
                                   "/tmp/repository"))
                  ("help" nil))))))

  (it "uses the documented defaults for every GHQ management wrapper"
    (let ((calls nil))
      (with-replaced-function
          (vcs-kit::%run-ghq-checked
           (lambda (command arguments &rest options)
             (declare (ignore options))
             (push (list command arguments) calls)
             (%fake-result
              :stdout (if (string= command "root")
                          (format nil "/root~%")
                          (if (string= command "list")
                              (format nil "/root/repository~%")
                              "")))))
        (ghq-get "owner/project")
        (ghq-clone "owner/project")
        (expect (ghq-list) :to-equal '("/root/repository"))
        (expect (ghq-roots) :to-equal '("/root"))
        (expect (ghq-root) :to-equal "/root")
        (expect (ghq-path "owner/project") :to-equal "/root/repository")
        (ghq-rm "owner/project")
        (ghq-create "owner/project")
        (ghq-migrate "/tmp/repository"))
      (expect (mapcar #'first (nreverse calls))
              :to-equal
              '("get" "clone" "list" "root" "root" "list" "rm"
                "create" "migrate"))))

  (it "rejects invalid GHQ specifications and argument lists"
    (%expect-condition type-error
      (vcs-kit::%ghq-spec-list 42))
    (%expect-condition type-error
      (ghq-list :arguments 42))
    (%expect-condition type-error
      (ghq-clone "owner/project" :arguments 42))
    (%expect-condition type-error
      (ghq-rm 42))))
