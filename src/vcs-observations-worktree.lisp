;;;; Structured backend-neutral observations: worktrees.

(in-package #:vcs-kit)

(defun %vcs-worktree-blocks (output)
  (let ((blocks nil)
        (current nil))
    (dolist (line (%split-line-records output))
      (if (string= line "")
          (when current
            (push (nreverse current) blocks)
            (setf current nil))
          (push line current)))
    (when current
      (push (nreverse current) blocks))
    (nreverse blocks)))

(defun %vcs-worktree (block)
  (let ((worktree (%make-vcs-worktree)))
    (dolist (line block)
      (let ((space (position #\Space line)))
        (when space
          (let ((key (subseq line 0 space))
                (value (subseq line (1+ space))))
            (cond
              ((string= key "worktree")
               (setf (vcs-worktree-path worktree) value))
              ((string= key "HEAD")
               (setf (vcs-worktree-head worktree) value))
              ((string= key "branch")
               (setf (vcs-worktree-branch worktree)
                     (if (%starts-with-p "refs/heads/" value)
                         (subseq value (length "refs/heads/"))
                         value)))
              ((string= key "locked")
               (setf (vcs-worktree-locked-p worktree) t))
              ((string= key "prunable")
               (setf (vcs-worktree-prunable-p worktree) t)))))
        (when (string= line "locked")
          (setf (vcs-worktree-locked-p worktree) t))
        (when (string= line "prunable")
          (setf (vcs-worktree-prunable-p worktree) t))
        (when (string= line "bare")
          (setf (vcs-worktree-bare-p worktree) t))))
    worktree))

(defun vcs-list-worktrees (repository &key (arguments nil) (execution-options nil))
  "Return Git worktrees from the porcelain worktree format."
  (%vcs-git-repository repository :worktrees)
  (check-type arguments list)
  (let ((result (%vcs-structured-run repository "worktree"
                                     (append (list "list" "--porcelain") arguments)
                                     execution-options)))
    (mapcar #'%vcs-worktree
            (%vcs-worktree-blocks (%vcs-structured-output result)))))
