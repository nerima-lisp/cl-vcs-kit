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
    git-var git-show-branch
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
    (let ((repository (make-repository (host-kit:temporary-directory)))
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
    (let ((repository (make-repository (host-kit:temporary-directory)))
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
