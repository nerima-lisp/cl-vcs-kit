(in-package #:vcs-kit/test)

(describe "Git repository operations"
  (it "constructs repository initialization and clone options"
    (let ((directory (%temporary-test-directory))
          (calls nil))
      (unwind-protect
           (with-replaced-function
               (vcs-kit::run-git/checked
                (lambda (repository command arguments &rest options)
                  (push (list repository command arguments options) calls)
                  (%fake-result)))
             (git-init directory
                       :bare t
                       :initial-branch "main"
                       :template "/tmp/template")
             (git-clone "source" directory
                        :bare t
                        :branch "main"
                        :depth 1
                        :recursive t
                        :no-checkout t
                        :arguments '("--quiet")))
        (host-kit:delete-directory-tree directory
                                     :validate t
                                     :if-does-not-exist :ignore))
      (let ((init (second calls))
            (clone (first calls)))
        (expect (second init) :to-equal "init")
        (expect (third init)
                :to-equal '("--bare" "--initial-branch" "main"
                            "--template" "/tmp/template"))
        (expect (second clone) :to-equal "clone")
        (expect (third clone)
                :to-equal (list "--bare" "--branch" "main" "--depth" "1"
                                "--recurse-submodules" "--no-checkout" "--quiet"
                                "source" (namestring directory))))))

  (it "resolves repository-relative and absolute Git paths"
    (let ((repository (make-repository "/tmp/project/")))
      (expect (vcs-kit::%resolve-git-path repository "../shared/.git")
              :to-equal "/tmp/project/../shared/.git")
      (expect (vcs-kit::%resolve-git-path repository "/var/lib/git/common")
              :to-equal "/var/lib/git/common")))

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
        (expect (repository-directory (open-repository nested))
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

)
