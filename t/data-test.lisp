(in-package #:vcs-kit/test)

(describe "public data records"
  (it "preserves repository configuration"
    (let ((repository
            (make-repository (uiop:temporary-directory)
                             :git-directory "git"
                             :common-directory "common"
                             :bare-p t
                             :executable "/bin/echo"
                             :default-timeout 7d0
                             :environment nil))
          (inherited (make-repository (uiop:temporary-directory))))
      (expect (repository-p repository) :to-be-truthy)
      (expect (repository-git-directory repository) :to-equal "git")
      (expect (repository-common-directory repository) :to-equal "common")
      (expect (repository-bare-p repository) :to-be-truthy)
      (expect (repository-executable repository) :to-equal "/bin/echo")
      (expect (repository-default-timeout repository) :to-equal 7d0)
      (expect (repository-environment repository) :to-be nil)
      (expect (repository-environment inherited) :to-be :inherit)))

  (it "exposes every field in the structured records"
    (let* ((snapshot
             (vcs-kit::%make-status-snapshot
              :branch-head "main"
              :branch-upstream "origin/main"
              :ahead 2
              :behind 1
              :stash-count 3
              :entries '(:entry)))
           (status
             (vcs-kit::%make-status-entry
              :kind :unmerged
              :index-status "U"
              :worktree-status "U"
              :submodule "S..."
              :head-mode "100644"
              :index-mode "100644"
              :worktree-mode "100755"
              :conflict-mode-1 "100644"
              :conflict-mode-2 "100755"
              :conflict-mode-3 "100644"
              :head-object "aaa"
              :index-object "bbb"
              :conflict-object-1 "ccc"
              :conflict-object-2 "ddd"
              :conflict-object-3 "eee"
              :score 90
              :path "new.txt"
              :original-path "old.txt"))
           (name-status
             (vcs-kit::%make-name-status-entry
              :status "R100"
              :path "new.txt"
              :original-path "old.txt"))
           (numstat
             (vcs-kit::%make-numstat-entry
              :additions 12
              :deletions 3
              :path "new.txt"
              :original-path "old.txt"
              :binary-p t)))
      (expect (status-snapshot-p snapshot) :to-be-truthy)
      (expect (status-snapshot-branch-head snapshot) :to-equal "main")
      (expect (status-snapshot-branch-upstream snapshot)
              :to-equal
              "origin/main")
      (expect (status-snapshot-ahead snapshot) :to-equal 2)
      (expect (status-snapshot-behind snapshot) :to-equal 1)
      (expect (status-snapshot-stash-count snapshot) :to-equal 3)
      (expect (status-snapshot-entries snapshot) :to-equal '(:entry))
      (expect (status-entry-p status) :to-be-truthy)
      (expect (status-entry-kind status) :to-be :unmerged)
      (expect (status-entry-index-status status) :to-equal "U")
      (expect (status-entry-worktree-status status) :to-equal "U")
      (expect (status-entry-submodule status) :to-equal "S...")
      (expect (status-entry-head-mode status) :to-equal "100644")
      (expect (status-entry-index-mode status) :to-equal "100644")
      (expect (status-entry-worktree-mode status) :to-equal "100755")
      (expect (status-entry-conflict-mode-1 status) :to-equal "100644")
      (expect (status-entry-conflict-mode-2 status) :to-equal "100755")
      (expect (status-entry-conflict-mode-3 status) :to-equal "100644")
      (expect (status-entry-head-object status) :to-equal "aaa")
      (expect (status-entry-index-object status) :to-equal "bbb")
      (expect (status-entry-conflict-object-1 status) :to-equal "ccc")
      (expect (status-entry-conflict-object-2 status) :to-equal "ddd")
      (expect (status-entry-conflict-object-3 status) :to-equal "eee")
      (expect (status-entry-score status) :to-equal 90)
      (expect (status-entry-path status) :to-equal "new.txt")
      (expect (status-entry-original-path status) :to-equal "old.txt")
      (expect (name-status-entry-p name-status) :to-be-truthy)
      (expect (name-status-entry-status name-status) :to-equal "R100")
      (expect (name-status-entry-path name-status) :to-equal "new.txt")
      (expect (name-status-entry-original-path name-status)
              :to-equal
              "old.txt")
      (expect (numstat-entry-p numstat) :to-be-truthy)
      (expect (numstat-entry-additions numstat) :to-equal 12)
      (expect (numstat-entry-deletions numstat) :to-equal 3)
      (expect (numstat-entry-path numstat) :to-equal "new.txt")
      (expect (numstat-entry-original-path numstat) :to-equal "old.txt")
      (expect (numstat-entry-binary-p numstat) :to-be-truthy)))

  (it "provides the declared defaults for every data record"
    (flet ((exercise (record predicate fields)
             (expect (funcall predicate record) :to-be-truthy)
             (dolist (field fields)
               (destructuring-bind (accessor expected) field
                 (expect (funcall accessor record) :to-equal expected)))))
      (exercise
       (vcs-kit::%make-repository)
       #'repository-p
       (list (list #'repository-directory "")
             (list #'repository-git-directory nil)
             (list #'repository-common-directory nil)
             (list #'repository-bare-p nil)
             (list #'repository-executable "git")
             (list #'repository-default-timeout 30d0)
             (list #'repository-environment :inherit)))
      (exercise
       (vcs-kit::%make-status-snapshot)
       #'status-snapshot-p
       (list (list #'status-snapshot-branch-head nil)
             (list #'status-snapshot-branch-upstream nil)
             (list #'status-snapshot-ahead nil)
             (list #'status-snapshot-behind nil)
             (list #'status-snapshot-stash-count nil)
             (list #'status-snapshot-entries nil)))
      (exercise
       (vcs-kit::%make-status-entry)
       #'status-entry-p
       (list (list #'status-entry-kind :ordinary)
             (list #'status-entry-index-status " ")
             (list #'status-entry-worktree-status " ")
             (list #'status-entry-submodule "N...")
             (list #'status-entry-head-mode nil)
             (list #'status-entry-index-mode nil)
             (list #'status-entry-worktree-mode nil)
             (list #'status-entry-conflict-mode-1 nil)
             (list #'status-entry-conflict-mode-2 nil)
             (list #'status-entry-conflict-mode-3 nil)
             (list #'status-entry-head-object nil)
             (list #'status-entry-index-object nil)
             (list #'status-entry-conflict-object-1 nil)
             (list #'status-entry-conflict-object-2 nil)
             (list #'status-entry-conflict-object-3 nil)
             (list #'status-entry-score nil)
             (list #'status-entry-path nil)
             (list #'status-entry-original-path nil)))
      (exercise
       (vcs-kit::%make-name-status-entry)
       #'name-status-entry-p
       (list (list #'name-status-entry-status "")
             (list #'name-status-entry-path "")
             (list #'name-status-entry-original-path nil)))
      (exercise
       (vcs-kit::%make-numstat-entry)
       #'numstat-entry-p
       (list (list #'numstat-entry-additions nil)
             (list #'numstat-entry-deletions nil)
             (list #'numstat-entry-path "")
             (list #'numstat-entry-original-path nil)
             (list #'numstat-entry-binary-p nil)))
      (exercise
       (vcs-kit::%make-vcs-status-snapshot)
       #'vcs-status-snapshot-p
       (list (list #'vcs-status-snapshot-branch-head nil)
             (list #'vcs-status-snapshot-branch-upstream nil)
             (list #'vcs-status-snapshot-ahead nil)
             (list #'vcs-status-snapshot-behind nil)
             (list #'vcs-status-snapshot-stash-count nil)
             (list #'vcs-status-snapshot-entries nil)))
      (exercise
       (vcs-kit::%make-vcs-status-entry)
       #'vcs-status-entry-p
       (list (list #'vcs-status-entry-kind :ordinary)
             (list #'vcs-status-entry-index-status " ")
             (list #'vcs-status-entry-worktree-status " ")
             (list #'vcs-status-entry-submodule "N...")
             (list #'vcs-status-entry-path nil)
             (list #'vcs-status-entry-original-path nil)
             (list #'vcs-status-entry-conflict-object-1 nil)
             (list #'vcs-status-entry-conflict-object-2 nil)
             (list #'vcs-status-entry-conflict-object-3 nil)))
      (exercise
       (vcs-kit::%make-vcs-remote)
       #'vcs-remote-p
       (list (list #'vcs-remote-name "")
             (list #'vcs-remote-fetch-url nil)
             (list #'vcs-remote-push-url nil)
             (list #'vcs-remote-fetch-refspecs nil)
             (list #'vcs-remote-push-refspecs nil)))
      (exercise
       (vcs-kit::%make-vcs-branch)
       #'vcs-branch-p
       (list (list #'vcs-branch-name "")
             (list #'vcs-branch-current-p nil)
             (list #'vcs-branch-upstream nil)
             (list #'vcs-branch-ahead nil)
             (list #'vcs-branch-behind nil)))
      (exercise
       (vcs-kit::%make-vcs-tag)
       #'vcs-tag-p
       (list (list #'vcs-tag-name "")
             (list #'vcs-tag-target nil)
             (list #'vcs-tag-annotated-p nil)
             (list #'vcs-tag-message nil)
             (list #'vcs-tag-tagger nil)
             (list #'vcs-tag-signature-status nil)))
      (exercise
       (vcs-kit::%make-vcs-commit)
       #'vcs-commit-p
       (list (list #'vcs-commit-id "")
             (list #'vcs-commit-parents nil)
             (list #'vcs-commit-tree nil)
             (list #'vcs-commit-author nil)
             (list #'vcs-commit-committer nil)
             (list #'vcs-commit-authored-at nil)
             (list #'vcs-commit-committed-at nil)
             (list #'vcs-commit-message nil)
             (list #'vcs-commit-encoding nil)))
      (exercise
       (vcs-kit::%make-vcs-diff-entry)
       #'vcs-diff-entry-p
       (list (list #'vcs-diff-entry-status "")
             (list #'vcs-diff-entry-path "")
             (list #'vcs-diff-entry-original-path nil)
             (list #'vcs-diff-entry-additions nil)
             (list #'vcs-diff-entry-deletions nil)
             (list #'vcs-diff-entry-binary-p nil)))
      (exercise
       (vcs-kit::%make-vcs-conflict)
       #'vcs-conflict-p
       (list (list #'vcs-conflict-path "")
             (list #'vcs-conflict-base nil)
             (list #'vcs-conflict-ours nil)
             (list #'vcs-conflict-theirs nil)))
      (exercise
       (vcs-kit::%make-vcs-stash-entry)
       #'vcs-stash-entry-p
       (list (list #'vcs-stash-entry-reference "")
             (list #'vcs-stash-entry-message "")
             (list #'vcs-stash-entry-date nil)))
      (exercise
       (vcs-kit::%make-vcs-worktree)
       #'vcs-worktree-p
       (list (list #'vcs-worktree-path "")
             (list #'vcs-worktree-head nil)
             (list #'vcs-worktree-branch nil)
             (list #'vcs-worktree-bare-p nil)
             (list #'vcs-worktree-locked-p nil)
             (list #'vcs-worktree-prunable-p nil)))
      (exercise
       (vcs-kit::%make-vcs-submodule)
       #'vcs-submodule-p
       (list (list #'vcs-submodule-path "")
             (list #'vcs-submodule-name nil)
             (list #'vcs-submodule-url nil)
             (list #'vcs-submodule-head nil)
             (list #'vcs-submodule-index nil)
             (list #'vcs-submodule-worktree-status nil)))
      (exercise
       (vcs-kit::%make-vcs-backend)
       #'vcs-backend-p
       (list (list #'vcs-backend-name :custom)
             (list #'vcs-backend-executable "")
             (list #'vcs-backend-aliases nil)
             (list #'vcs-backend-capabilities nil)
             (list #'vcs-backend-commands nil)
             (list #'vcs-backend-operation-kinds nil)
             (list #'vcs-backend-structured-operations nil)
             (list #'vcs-backend-markers nil)))
      (exercise
       (vcs-kit::%make-vcs-operation-info)
       #'vcs-operation-info-p
       (list (list #'vcs-operation-info-operation :custom)
             (list #'vcs-operation-info-command nil)
             (list #'vcs-operation-info-mapping-kind :alias)))
      (exercise
       (vcs-kit::%make-vcs-repository)
       #'vcs-repository-p
       (list (list #'vcs-repository-directory "")
             (list #'vcs-repository-backend nil)
             (list #'vcs-repository-executable "")
             (list #'vcs-repository-default-timeout 30d0)
             (list #'vcs-repository-environment :inherit)))
      (exercise
       (make-ghq-repository-entry)
       #'ghq-repository-entry-p
       (list (list #'ghq-repository-entry-specification "")
             (list #'ghq-repository-entry-path "")
             (list #'ghq-repository-entry-backend nil)))
      (exercise
       (make-ghq-root-entry)
       #'ghq-root-entry-p
       (list (list #'ghq-root-entry-path "")
             (list #'ghq-root-entry-primary-p nil))))))
