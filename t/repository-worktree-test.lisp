(in-package #:vcs-kit/test)

(describe "repository worktree observations"
  (it "parses worktree marker flags from porcelain output"
    (let ((repository (make-vcs-repository (host-kit:temporary-directory)
                                           :backend :git)))
      (with-replaced-function
          (vcs-kit::%vcs-structured-run
           (lambda (called-repository command arguments execution-options)
             (declare (ignore called-repository arguments execution-options))
             (expect command :to-equal "worktree")
             (%fake-result
              :stdout
              (format nil
                      "worktree main~%HEAD main-head~%branch refs/heads/main~%~%worktree locked~%HEAD locked-head~%branch refs/heads/topic~%locked reason~%locked~%~%worktree prunable~%HEAD prunable-head~%branch refs/heads/stale~%prunable reason~%prunable~%~%worktree bare~%HEAD bare-head~%bare~%"))))
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
          (expect (vcs-worktree-bare-p bare) :to-be-truthy))))
  )
)
