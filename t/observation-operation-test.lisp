(in-package #:vcs-kit/test)

(describe "structured operation observations"
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

  (it "keeps unknown worktree records inert and rejects malformed submodules"
    (let ((worktree (vcs-kit::%vcs-worktree '("unknown-record"))))
      (expect (vcs-worktree-path worktree) :to-equal "")
      (expect (vcs-worktree-head worktree) :to-be nil)
      (expect (vcs-worktree-branch worktree) :to-be nil))
    (%expect-condition error
      (vcs-kit::%vcs-submodule-line "+only-head")))

  (it "normalizes submodule descriptions and configuration keys"
    (let ((described (vcs-kit::%vcs-submodule-line
                      "-abc123 path/to/lib (nested description)"))
          (plain (vcs-kit::%vcs-submodule-line "+def456 path/to/plain")))
      (expect (vcs-submodule-path described) :to-equal "path/to/lib")
      (expect (vcs-submodule-head described) :to-equal "abc123")
      (expect (vcs-submodule-path plain) :to-equal "path/to/plain")
      (expect (vcs-submodule-worktree-status plain) :to-equal "+"))
    (expect (vcs-kit::%vcs-submodule-configuration
             "submodule.core.path libs/core")
            :to-equal '("libs/core" . "core"))
    (expect (vcs-kit::%vcs-submodule-configuration
             "submodule..path invalid")
            :to-be nil)
    (expect (vcs-kit::%vcs-submodule-configuration "malformed")
            :to-be nil))

  (it "keeps worktree blocks without a trailing separator"
    (let ((blocks (vcs-kit::%vcs-worktree-blocks
                   (format nil "worktree /tmp/one~%HEAD one~%~%worktree /tmp/two"))))
      (expect (length blocks) :to-equal 2)
      (expect (first (second blocks)) :to-equal "worktree /tmp/two")))

  (it "parses structured refs and rejects malformed records"
    (let ((repository (make-vcs-repository (host-kit:temporary-directory)
                                           :backend :git))
          (mode :valid))
      (with-replaced-function
          (vcs-kit::%vcs-structured-run
           (lambda (called-repository command arguments execution-options)
             (declare (ignore called-repository execution-options))
             (cond
               ((eq mode :malformed)
                (%fake-result :stdout (format nil "malformed~%")))
               ((eq mode :malformed-tag)
                (%fake-result :stdout (format nil "malformed-tag~%")))
               ((eq mode :malformed-divergence)
                (if (string= command "rev-list")
                    (%fake-result :stdout (format nil "not-a-count~%"))
                    (%fake-result :stdout
                                  (format nil "*~Cmain~Corigin/main~%"
                                          #\Tab #\Tab))))
               ((string= command "for-each-ref")
                (if (member "refs/tags" arguments :test #'string=)
                    (%fake-result
                     :stdout
                     (format nil
                             "~%v1~Cv1-object~Ccommit~CLightweight~C~%v2~Cv2-object~Ctag~CAnnotated~CTagger~%"
                             #\Tab #\Tab #\Tab #\Tab
                             #\Tab #\Tab #\Tab #\Tab))
                    (%fake-result
                     :stdout
                     (format nil "~%*~Cmain~Corigin/main~% ~Ctopic~C~%"
                             #\Tab #\Tab #\Tab #\Tab))))
               ((string= command "rev-list")
                (%fake-result :stdout (format nil "2~C1~%" #\Tab)))
               ((string= command "rev-parse")
                (%fake-result :stdout (format nil "peeled-object~%")))
               (t
                (error "Unexpected fake structured command: ~A ~S"
                       command arguments)))))
        (let* ((branches (vcs-list-branches repository))
               (main (find "main" branches :key #'vcs-branch-name :test #'string=))
               (topic (find "topic" branches :key #'vcs-branch-name :test #'string=))
               (tags (vcs-list-tags repository))
               (lightweight (find "v1" tags :key #'vcs-tag-name :test #'string=))
               (annotated (find "v2" tags :key #'vcs-tag-name :test #'string=)))
          (expect (length branches) :to-equal 2)
          (expect (vcs-branch-current-p main) :to-be-truthy)
          (expect (vcs-branch-upstream main) :to-equal "origin/main")
          (expect (vcs-branch-ahead main) :to-equal 2)
          (expect (vcs-branch-behind main) :to-equal 1)
          (expect (vcs-branch-upstream topic) :to-be nil)
          (expect (vcs-branch-ahead topic) :to-be nil)
          (expect (vcs-tag-target lightweight) :to-equal "v1-object")
          (expect (vcs-tag-annotated-p lightweight) :to-be nil)
          (expect (vcs-tag-target annotated) :to-equal "peeled-object")
          (expect (vcs-tag-annotated-p annotated) :to-be-truthy)
          (expect (vcs-tag-tagger annotated) :to-equal "Tagger"))
        (setf mode :malformed)
        (%expect-condition error (vcs-list-branches repository))
        (setf mode :malformed-divergence)
        (%expect-condition error (vcs-list-branches repository))
        (setf mode :malformed-tag)
        (%expect-condition error (vcs-list-tags repository)))))
  )
