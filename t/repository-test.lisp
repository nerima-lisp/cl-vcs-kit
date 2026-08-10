(in-package #:vcs-kit/test)

(describe "Git repository operations"
  (it "discovers, stages, commits, and clones a repository"
    (%with-temporary-repository (repository)
      (let* ((directory (repository-directory repository))
             (nested (merge-pathnames "nested/" (pathname directory)))
             (file-name "odd name.txt")
             (clone-directory
               (merge-pathnames "clone/" (pathname directory))))
        (ensure-directories-exist nested)
        (expect (repository-bare-p repository) :to-be nil)
        (expect (status-snapshot-branch-head (git-status repository))
                :to-equal
                "main")
        (expect (repository-directory (discover-repository nested))
                :to-equal
                directory)
        (%write-test-file directory file-name
                          (format nil "first~%second~%"))
        (expect (process-success-p
                 (git-add repository "--" file-name))
                :to-be-truthy)
        (let* ((status (git-status repository))
               (entry (first (status-snapshot-entries status)))
               (name-status (git-diff-name-status repository "--cached"))
               (numstat (git-diff-numstat repository "--cached")))
          (expect (status-entry-kind entry) :to-be :ordinary)
          (expect (status-entry-index-status entry) :to-equal "A")
          (expect (status-entry-path entry) :to-equal file-name)
          (expect (name-status-entry-status (first name-status)) :to-equal "A")
          (expect (name-status-entry-path (first name-status))
                  :to-equal
                  file-name)
          (expect (numstat-entry-additions (first numstat)) :to-equal 2)
          (expect (numstat-entry-deletions (first numstat)) :to-equal 0))
        (git-config repository "user.name" "VCS Kit Test")
        (git-config repository "user.email" "vcs-kit@example.invalid")
        (git-config repository "commit.gpgSign" "false")
        (git-config repository "tag.gpgSign" "false")
        (expect (process-success-p
                 (git-commit repository "-m" "initial"))
                :to-be-truthy)
        (expect (length (git-rev-parse-value repository "HEAD")) :to-equal 40)
        (expect (search "initial"
                        (process-result-stdout
                         (git-log repository "--format=%s" "-1")))
                :to-be-truthy)
        (expect (process-success-p (git-tag repository "v1.0.0"))
                :to-be-truthy)
        (expect (process-success-p (git-branch repository "topic"))
                :to-be-truthy)
        (expect (repository-directory (open-repository nested))
                :to-equal
                directory)
        (expect (repository-bare-p (open-repository directory)) :to-be nil)
        (expect (process-success-p
                 (git-clone (pathname directory) clone-directory))
                :to-be-truthy)
        (expect (repository-bare-p (open-repository clone-directory))
                :to-be nil)
        (%expect-condition git-exit-error
          (git-rev-parse repository "refs/heads/does-not-exist")))))

  (it "returns backend-neutral structured Git observations"
    (%with-temporary-repository (repository)
      (let* ((directory (repository-directory repository))
             (file-name "structured.txt")
             (remote-url "https://example.invalid/vcs-kit.git"))
        (%write-test-file directory file-name
                          (format nil "first~%second~%"))
        (git-add repository "--" file-name)
        (git-config repository "user.name" "VCS Kit Test")
        (git-config repository "user.email" "vcs-kit@example.invalid")
        (git-config repository "commit.gpgSign" "false")
        (git-config repository "tag.gpgSign" "false")
        (git-commit repository "-m" "initial")
        (git-tag repository "v1.0.0")
        (git-tag repository "-a" "v1.1.0" "-m" "release")
        (git-branch repository "topic")
        (git-remote repository "add" "origin" remote-url)
        (git-config repository
                    "remote.origin.push"
                    "refs/heads/main:refs/heads/main")
        (let* ((status (vcs-status-structured repository))
               (branches (vcs-list-branches repository))
               (tags (vcs-list-tags repository))
               (commits (vcs-list-commits repository))
               (remotes (vcs-list-remotes repository))
               (worktrees (vcs-list-worktrees repository)))
          (expect (vcs-status-snapshot-branch-head status)
                  :to-equal
                  "main")
          (expect (vcs-status-snapshot-entries status) :to-equal nil)
          (let ((main (find "main" branches
                            :key #'vcs-branch-name
                            :test #'string=))
                (topic (find "topic" branches
                             :key #'vcs-branch-name
                             :test #'string=)))
            (expect main :to-be-truthy)
            (expect (vcs-branch-current-p main) :to-be-truthy)
            (expect topic :to-be-truthy)
            (expect (vcs-branch-current-p topic) :to-be nil))
          (expect (length tags) :to-equal 2)
          (let ((annotated (find "v1.1.0" tags
                                 :key #'vcs-tag-name
                                 :test #'string=)))
            (expect annotated :to-be-truthy)
            (expect (vcs-tag-annotated-p annotated) :to-be-truthy)
            (expect (length (vcs-tag-target annotated)) :to-equal 40))
          (let ((commit (first commits)))
            (expect (length commits) :to-equal 1)
            (expect (length (vcs-commit-id commit)) :to-equal 40)
            (expect (vcs-commit-message commit) :to-contain "initial")
            (expect (length (vcs-commit-tree commit)) :to-equal 40))
          (let ((origin (find "origin" remotes
                              :key #'vcs-remote-name
                              :test #'string=)))
            (expect origin :to-be-truthy)
            (expect (vcs-remote-fetch-url origin) :to-equal remote-url)
            (expect (vcs-remote-push-url origin) :to-equal remote-url)
            (expect (vcs-remote-fetch-refspecs origin)
                    :to-contain
                    "+refs/heads/*:refs/remotes/origin/*")
            (expect (vcs-remote-push-refspecs origin)
                    :to-contain
                    "refs/heads/main:refs/heads/main"))
          (expect (length worktrees) :to-equal 1)
          (let ((worktree (first worktrees)))
            (expect (vcs-worktree-path worktree)
                    :to-equal
                    (string-right-trim "/" directory))
            (expect (vcs-worktree-branch worktree) :to-equal "main")
            (expect (length (vcs-worktree-head worktree)) :to-equal 40))
          (expect (vcs-list-submodules repository) :to-equal nil)
          (expect (vcs-list-conflicts repository) :to-equal nil))
        (%write-test-file directory file-name
                          (format nil "first~%third~%"))
        (let* ((status (vcs-status-structured repository))
               (status-entry (first (vcs-status-snapshot-entries status)))
               (diff (vcs-diff-entries repository))
               (diff-entry (first diff)))
          (expect (length (vcs-status-snapshot-entries status)) :to-equal 1)
          (expect (vcs-status-entry-path status-entry) :to-equal file-name)
          (expect (vcs-status-entry-worktree-status status-entry)
                  :to-equal
                  "M")
          (expect (length diff) :to-equal 1)
          (expect (vcs-diff-entry-path diff-entry) :to-equal file-name)
          (expect (vcs-diff-entry-additions diff-entry) :to-equal 1)
          (expect (vcs-diff-entry-deletions diff-entry) :to-equal 1))
        (git-stash repository "push" "-m" "semantic test")
        (let ((stashes (vcs-list-stashes repository)))
          (expect (length stashes) :to-equal 1)
          (expect (vcs-stash-entry-reference (first stashes))
                  :to-equal
                  "stash@{0}")
          (expect (vcs-stash-entry-message (first stashes))
                  :to-contain
                  "semantic test"))
        (%write-test-file directory "rename-source.txt"
                          (format nil "rename me~%"))
        (git-add repository "--" "rename-source.txt")
        (git-commit repository "-m" "add rename source")
        (git-mv repository "--" "rename-source.txt" "rename-target.txt")
        (let ((rename (first (vcs-diff-entries repository
                                              :arguments '("--cached")))))
          (expect (length (vcs-diff-entries repository
                                            :arguments '("--cached")))
                  :to-equal
                  1)
          (expect (char (vcs-diff-entry-status rename) 0) :to-equal #\R)
          (expect (vcs-diff-entry-original-path rename)
                  :to-equal
                  "rename-source.txt")
          (expect (vcs-diff-entry-path rename)
                  :to-equal
                  "rename-target.txt")
          (expect (vcs-diff-entry-additions rename) :to-equal 0)
          (expect (vcs-diff-entry-deletions rename) :to-equal 0))
        (let* ((non-git (make-vcs-repository directory :backend :mercurial))
               (condition (%expect-condition vcs-unsupported-operation-error
                           (vcs-list-branches non-git))))
          (expect (vcs-unsupported-operation-error-operation condition)
                  :to-equal
                  :branches)))))

  (it "parses worktree marker flags from porcelain output"
    (let ((repository (make-vcs-repository (uiop:temporary-directory)
                                           :backend :git)))
      (with-replaced-function
          (vcs-kit::%vcs-structured-run
           (lambda (called-repository command arguments execution-options)
             (declare (ignore called-repository arguments execution-options))
             (expect command :to-equal "worktree")
             (%fake-result
              :stdout
              (format nil
                      "worktree main~%HEAD main-head~%branch refs/heads/main~%~%worktree locked~%HEAD locked-head~%branch refs/heads/topic~%locked reason~%~%worktree prunable~%HEAD prunable-head~%branch refs/heads/stale~%prunable reason~%~%worktree bare~%HEAD bare-head~%bare~%"))))
        (let* ((worktrees (vcs-list-worktrees repository))
               (main (first worktrees))
               (locked (second worktrees))
               (prunable (third worktrees))
               (bare (fourth worktrees)))
          (expect (length worktrees) :to-equal 4)
          (expect (vcs-worktree-branch main) :to-equal "main")
          (expect (vcs-worktree-locked-p main) :to-be nil)
          (expect (vcs-worktree-locked-p locked) :to-be-truthy)
          (expect (vcs-worktree-branch locked) :to-equal "topic")
          (expect (vcs-worktree-prunable-p prunable) :to-be-truthy)
          (expect (vcs-worktree-branch prunable) :to-equal "stale")
          (expect (vcs-worktree-bare-p bare) :to-be-truthy)))))

  (it "parses structured refs and rejects malformed records"
    (let ((repository (make-vcs-repository (uiop:temporary-directory)
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
                    (%fake-result
                     :stdout
                     (format nil "*~Cmain~Corigin/main~%" #\Tab #\Tab))))
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
               (main (find "main" branches
                           :key #'vcs-branch-name
                           :test #'string=))
               (topic (find "topic" branches
                            :key #'vcs-branch-name
                            :test #'string=))
               (tags (vcs-list-tags repository))
               (lightweight (find "v1" tags
                                  :key #'vcs-tag-name
                                  :test #'string=))
               (annotated (find "v2" tags
                                :key #'vcs-tag-name
                                :test #'string=)))
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
        (%expect-condition error
          (vcs-list-branches repository))
        (setf mode :malformed-divergence)
        (%expect-condition error
          (vcs-list-branches repository))
        (setf mode :malformed-tag)
        (%expect-condition error
          (vcs-list-tags repository)))))

  (it "projects unmerged status entries as conflicts"
    (let ((repository (make-vcs-repository (uiop:temporary-directory)
                                           :backend :git)))
      (with-replaced-function
          (vcs-kit::vcs-status-structured
           (lambda (called-repository &rest arguments)
             (declare (ignore called-repository arguments))
             (vcs-kit::%make-vcs-status-snapshot
              :entries
              (list
               (vcs-kit::%make-vcs-status-entry
                :kind :ordinary
                :path "clean.txt")
               (vcs-kit::%make-vcs-status-entry
                :kind :unmerged
                :path "conflict.txt"
                :conflict-object-1 "base-object"
                :conflict-object-2 "ours-object"
                :conflict-object-3 "theirs-object")))))
        (let ((conflicts (vcs-list-conflicts repository)))
          (expect (length conflicts) :to-equal 1)
          (let ((conflict (first conflicts)))
            (expect (vcs-conflict-path conflict) :to-equal "conflict.txt")
            (expect (vcs-conflict-base conflict) :to-equal "base-object")
            (expect (vcs-conflict-ours conflict) :to-equal "ours-object")
            (expect (vcs-conflict-theirs conflict)
                    :to-equal
                    "theirs-object"))))))

  (it "rejects mismatched structured diff streams"
    (let ((repository (make-vcs-repository (uiop:temporary-directory)
                                           :backend :git)))
      (with-replaced-function
          (vcs-kit::%vcs-structured-run
           (lambda (called-repository command arguments execution-options)
             (declare (ignore called-repository command execution-options))
             (if (member "--name-status" arguments :test #'string=)
                 (%fake-result
                  :stdout
                  (format nil "M~Cfile.txt~C" #\Null #\Null))
                 (%fake-result :stdout ""))))
        (%expect-condition error
          (vcs-diff-entries repository)))))

  (it "handles optional Git queries and rejects malformed history"
    (let ((repository (make-vcs-repository (uiop:temporary-directory)
                                           :backend :git)))
      (with-replaced-function
          (vcs-kit::%vcs-structured-run
           (lambda (called-repository command arguments execution-options)
             (declare (ignore called-repository arguments execution-options))
             (cond
               ((string= command "remote")
                (%fake-result
                 :stdout
                 (format nil
                         "~%not-a-remote~%origin~Chttps://example.invalid/repo (fetch)~%"
                         #\Tab)))
               ((string= command "config")
                (error 'vcs-command-exit-error :exit-code 1))
               (t
                (error "Unexpected fake structured command: ~A" command)))))
        (let ((remote (first (vcs-list-remotes repository))))
          (expect (vcs-remote-name remote) :to-equal "origin")
          (expect (vcs-remote-fetch-url remote)
                  :to-equal
                  "https://example.invalid/repo")
          (expect (vcs-remote-push-url remote) :to-be nil)
          (expect (vcs-remote-fetch-refspecs remote) :to-equal nil)
          (expect (vcs-remote-push-refspecs remote) :to-equal nil)))
      (with-replaced-function
          (vcs-kit::%vcs-structured-run
           (lambda (called-repository command arguments execution-options)
             (declare (ignore called-repository command arguments
                              execution-options))
             (error 'vcs-command-exit-error :exit-code 2)))
        (let ((condition
                (%expect-condition vcs-command-exit-error
                  (vcs-list-remotes repository))))
          (expect (vcs-command-exit-error-exit-code condition)
                  :to-equal
                  2)))
      (with-replaced-function
          (vcs-kit::%vcs-structured-run
           (lambda (called-repository command arguments execution-options)
             (declare (ignore called-repository arguments execution-options))
             (cond
               ((string= command "log")
                (%fake-result :stdout (%join-nul "only")))
               ((string= command "stash")
                (%fake-result
                 :stdout
                 (format nil "~%stash@{0}~Cmessage~%" #\Null)))
               (t
                (error "Unexpected fake structured command: ~A" command)))))
        (%expect-condition error
          (vcs-list-commits repository))
        (%expect-condition error
          (vcs-list-stashes repository)))))

)