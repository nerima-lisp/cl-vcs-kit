(in-package #:vcs-kit)

;; Repository metadata is part of each descriptor so public backend objects
;; and automatic detection cannot disagree.  The second table records only
;; mappings whose common operation name hides a backend-specific or
;; approximate meaning; exact and ordinary aliases are inferred below.
(defparameter *vcs-backend-markers*
  '((:git ".git")
    (:mercurial ".hg")
    (:subversion ".svn")
    (:bazaar ".bzr")
    (:fossil ".fslckout" "_FOSSIL_")
    (:darcs ".darcs")
    (:pijul ".pijul")))

(defparameter *vcs-operation-kind-overrides*
  '((:git
     (:update . :approximate) (:sync . :approximate)
     (:resolve . :approximate) (:lock . :approximate)
     (:unlock . :approximate) (:worktree . :native)
     (:submodule . :native) (:bundle . :native)
     (:maintenance . :native) (:verify . :approximate))
    (:mercurial
     (:fetch . :approximate) (:sync . :approximate)
     (:switch . :approximate) (:checkout . :approximate)
     (:reset . :approximate) (:stash . :approximate)
     (:remote . :approximate) (:clean . :approximate)
     (:worktree . :approximate))
    (:subversion
     (:clone . :approximate) (:branch . :approximate)
     (:tag . :approximate) (:fetch . :approximate)
     (:pull . :approximate) (:push . :approximate)
     (:reset . :approximate) (:remote . :approximate)
     (:sync . :approximate) (:clean . :approximate)
     (:config . :approximate) (:verify . :approximate))
    (:bazaar
     (:clone . :approximate) (:fetch . :approximate)
     (:sync . :approximate) (:reset . :approximate)
     (:stash . :approximate) (:remote . :approximate)
     (:worktree . :approximate) (:verify . :approximate))
    (:fossil
     (:log . :alias) (:show . :approximate)
     (:switch . :approximate) (:checkout . :approximate)
     (:reset . :approximate) (:stash . :approximate)
     (:archive . :approximate) (:config . :approximate)
     (:verify . :approximate))
    (:darcs
     (:log . :alias) (:init . :alias) (:clone . :approximate)
     (:branch . :approximate) (:checkout . :approximate)
     (:commit . :approximate) (:merge . :approximate)
     (:reset . :approximate) (:remote . :approximate)
     (:update . :approximate) (:sync . :approximate)
     (:archive . :approximate) (:blame . :approximate)
     (:clean . :approximate) (:verify . :approximate))
    (:pijul
     (:show . :approximate) (:cat . :approximate)
     (:commit . :approximate) (:branch . :approximate)
     (:switch . :approximate) (:checkout . :approximate)
     (:merge . :approximate) (:revert . :approximate)
     (:remote . :approximate) (:update . :approximate)
     (:sync . :approximate) (:verify . :approximate))))

;; The descriptors intentionally cover both the common protocol and the
;; important native commands that do not have a portable high-level meaning.
;; RUN-VCS remains the escape hatch for any command not represented here.
(defparameter *vcs-backends*
  (mapcar
   (lambda (spec)
     (destructuring-bind (name executable aliases commands
                          &optional structured-operations)
         spec
       (make-vcs-backend :name name
                         :executable executable
                         :aliases aliases
                         :commands commands
                         :structured-operations structured-operations
                         :markers (cdr (assoc name *vcs-backend-markers*))
                         :operation-kinds
                         (cdr (assoc name *vcs-operation-kind-overrides*)))))
   '((:git "git" nil
      ((:status . "status") (:diff . "diff") (:log . "log")
       (:show . "show") (:cat . "cat-file") (:init . "init")
       (:clone . "clone") (:add . "add") (:remove . "rm")
       (:move . "mv") (:commit . "commit") (:branch . "branch")
       (:switch . "switch") (:checkout . "checkout") (:tag . "tag")
       (:fetch . "fetch") (:pull . "pull") (:push . "push")
       (:merge . "merge") (:rebase . "rebase") (:reset . "reset")
       (:revert . "revert") (:stash . "stash") (:remote . "remote")
       (:update . "update-ref") (:sync . "fetch") (:archive . "archive")
       (:annotate . "annotate") (:blame . "blame")
       (:resolve . "checkout") (:clean . "clean")
       (:lock . "update-index") (:unlock . "update-index")
       (:config . "config") (:help . "help") (:version . "--version")
       (:worktree . "worktree") (:submodule . "submodule")
       (:bundle . "bundle") (:maintenance . "maintenance")
       (:verify . "fsck"))
      (:status :diff :remotes :branches :tags :commits :stashes
       :conflicts :worktrees :submodules))
     (:mercurial "hg" (:hg)
      ((:status . "status") (:diff . "diff") (:log . "log")
       (:show . "cat") (:cat . "cat") (:init . "init")
       (:clone . "clone") (:add . "add") (:remove . "remove")
       (:move . "rename") (:commit . "commit") (:branch . "branch")
       (:switch . "update") (:checkout . "update") (:tag . "tag")
       (:fetch . "pull") (:pull . "pull") (:push . "push")
       (:merge . "merge") (:rebase . "rebase") (:reset . "rollback")
       (:revert . "revert") (:stash . "shelve") (:remote . "paths")
       (:update . "update") (:sync . "pull") (:archive . "archive")
       (:annotate . "annotate") (:blame . "annotate")
       (:resolve . "resolve") (:clean . "purge")
       (:config . "showconfig") (:help . "help") (:version . "--version")
       (:worktree . "share") (:verify . "verify")))
     (:subversion "svn" (:svn)
      ((:status . "status") (:diff . "diff") (:log . "log")
       (:show . "cat") (:cat . "cat") (:clone . "checkout")
       (:checkout . "checkout") (:add . "add") (:remove . "delete")
       (:move . "move") (:commit . "commit") (:branch . "copy")
       (:switch . "switch") (:tag . "copy") (:fetch . "update")
       (:pull . "update") (:push . "commit") (:merge . "merge")
       (:reset . "revert") (:revert . "revert") (:remote . "info")
       (:update . "update") (:sync . "update") (:archive . "export")
       (:annotate . "blame") (:blame . "blame") (:clean . "cleanup")
       (:lock . "lock") (:unlock . "unlock") (:config . "propget")
       (:help . "help") (:version . "--version") (:verify . "status")))
     (:bazaar "bzr" (:bzr)
      ((:status . "status") (:diff . "diff") (:log . "log")
       (:show . "cat") (:cat . "cat") (:init . "init")
       (:clone . "branch") (:checkout . "checkout") (:add . "add")
       (:remove . "remove") (:move . "move") (:commit . "commit")
       (:branch . "branch") (:switch . "switch") (:tag . "tag")
       (:fetch . "pull") (:pull . "pull") (:push . "push")
       (:merge . "merge") (:rebase . "rebase") (:reset . "uncommit")
       (:revert . "revert") (:stash . "shelve") (:remote . "info")
       (:update . "update") (:sync . "pull") (:archive . "export")
       (:annotate . "annotate") (:blame . "annotate")
       (:clean . "clean-tree") (:config . "config") (:help . "help")
       (:version . "--version") (:verify . "check")
       (:worktree . "bind")))
     (:fossil "fossil" nil
      ((:status . "status") (:diff . "diff") (:log . "timeline")
       (:show . "info") (:cat . "cat") (:init . "init")
       (:clone . "clone") (:add . "add") (:remove . "rm")
       (:move . "mv") (:commit . "commit") (:branch . "branch")
       (:switch . "update") (:checkout . "open") (:tag . "tag")
       (:fetch . "pull") (:pull . "pull") (:push . "push")
       (:merge . "merge") (:rebase . "rebase") (:reset . "undo")
       (:revert . "revert") (:stash . "stash") (:remote . "remote")
       (:update . "update") (:sync . "sync") (:archive . "zip")
       (:annotate . "annotate") (:blame . "annotate")
       (:clean . "clean") (:config . "settings") (:help . "help")
       (:version . "version") (:verify . "rebuild")))
     (:darcs "darcs" nil
      ((:status . "status") (:diff . "diff") (:log . "changes")
       (:show . "show") (:cat . "show") (:init . "initialize")
       (:clone . "get") (:add . "add") (:remove . "remove")
       (:move . "move") (:commit . "record") (:branch . "get")
       (:checkout . "get") (:tag . "tag") (:fetch . "pull")
       (:pull . "pull") (:push . "push") (:merge . "apply")
       (:rebase . "rebase") (:reset . "rollback") (:revert . "revert")
       (:remote . "show") (:update . "pull") (:sync . "pull")
       (:archive . "dist") (:annotate . "annotate")
       (:blame . "annotate") (:clean . "revert") (:help . "help")
       (:version . "--version") (:verify . "check")))
     (:pijul "pijul" nil
      ((:status . "status") (:diff . "diff") (:log . "log")
       (:show . "log") (:cat . "file") (:init . "init")
       (:clone . "clone") (:add . "add") (:remove . "remove")
       (:move . "move") (:commit . "record") (:branch . "channel")
       (:switch . "channel") (:checkout . "channel") (:tag . "tag")
       (:fetch . "pull") (:pull . "pull") (:push . "push")
       (:merge . "apply") (:reset . "reset") (:revert . "unrecord")
       (:remote . "remote") (:update . "pull") (:sync . "pull")
       (:archive . "archive") (:clean . "clean") (:help . "help")
       (:version . "--version") (:verify . "check"))))))
