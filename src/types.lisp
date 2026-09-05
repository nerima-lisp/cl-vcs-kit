(in-package #:vcs-kit)

(deftype vcs-cancellation-token ()
  "A cancellation token accepted by the process-backed VCS runners."
  'process-kit:cancellation-token)

(defstruct (repository
            (:constructor %make-repository)
            (:copier nil))
  "A Git repository handle rooted at DIRECTORY, taken by every Git entry point.
MAKE-REPOSITORY builds one without probing, so GIT-DIRECTORY and
COMMON-DIRECTORY stay NIL unless the caller supplies them; OPEN-REPOSITORY
resolves both to absolute paths."
  (directory "" :type string)
  (git-directory nil :type (or null string))
  (common-directory nil :type (or null string))
  (bare-p nil :type boolean)
  (executable "git" :type string)
  (default-timeout 30d0 :type (or null real))
  (environment :inherit :type (or null list (member :inherit))))

(defstruct (status-snapshot
            (:constructor %make-status-snapshot)
            (:copier nil))
  branch-head
  branch-upstream
  ahead
  behind
  stash-count
  (entries nil :type list))

(defstruct (status-entry
            (:constructor %make-status-entry)
            (:copier nil))
  (kind :ordinary :type keyword)
  (index-status " " :type string)
  (worktree-status " " :type string)
  (submodule "N..." :type string)
  head-mode
  index-mode
  worktree-mode
  conflict-mode-1
  conflict-mode-2
  conflict-mode-3
  head-object
  index-object
  conflict-object-1
  conflict-object-2
  conflict-object-3
  score
  path
  original-path)

(defstruct (name-status-entry
            (:constructor %make-name-status-entry)
            (:copier nil))
  (status "" :type string)
  (path "" :type string)
  original-path)

(defstruct (numstat-entry
            (:constructor %make-numstat-entry)
            (:copier nil))
  additions
  deletions
  (path "" :type string)
  original-path
  (binary-p nil :type boolean))

;; Backend-neutral value objects.  These describe the data
;; exchanged by common VCS operations rather than mirroring one command's
;; textual output.  A backend may leave fields NIL when its native protocol
;; does not expose the corresponding information.
(defstruct (vcs-status-snapshot
            (:constructor %make-vcs-status-snapshot)
            (:copier nil))
  "The repository-wide half of a VCS-STATUS-STRUCTURED result.
BRANCH-HEAD, BRANCH-UPSTREAM, AHEAD, BEHIND and STASH-COUNT are NIL when the
backend emitted no matching header; a branch with no upstream leaves
BRANCH-UPSTREAM, AHEAD and BEHIND all NIL.  ENTRIES holds VCS-STATUS-ENTRY."
  branch-head
  branch-upstream
  ahead
  behind
  stash-count
  (entries nil :type list))

(defstruct (vcs-status-entry
            (:constructor %make-vcs-status-entry)
            (:copier nil))
  "One changed path in a VCS-STATUS-SNAPSHOT's ENTRIES list.
KIND is :ORDINARY, :RENAME-OR-COPY, :UNMERGED, :UNTRACKED or :IGNORED.
CONFLICT-OBJECT-1, -2 and -3 are the three merge stages and are NIL for every
KIND but :UNMERGED.  ORIGINAL-PATH is NIL unless PATH was renamed or copied."
  (kind :ordinary :type keyword)
  (index-status " " :type string)
  (worktree-status " " :type string)
  (submodule "N..." :type string)
  path
  original-path
  conflict-object-1
  conflict-object-2
  conflict-object-3)

(defstruct (vcs-remote
            (:constructor %make-vcs-remote)
            (:copier nil))
  "One remote from VCS-LIST-REMOTES, with its URLs and configured refspecs.
FETCH-URL or PUSH-URL is NIL when the backend listed no URL for that direction.
FETCH-REFSPECS and PUSH-REFSPECS are empty when the remote configures no
refspec in that direction."
  (name "" :type string)
  fetch-url
  push-url
  (fetch-refspecs nil :type list)
  (push-refspecs nil :type list))

(defstruct (vcs-branch
            (:constructor %make-vcs-branch)
            (:copier nil))
  "One local branch from VCS-LIST-BRANCHES, in the backend's listing order.
CURRENT-P is true for the checked-out branch.  UPSTREAM is NIL when the branch
tracks nothing, and AHEAD and BEHIND are then NIL as well; otherwise they count
the commits on each side of the NAME...UPSTREAM symmetric difference."
  (name "" :type string)
  (current-p nil :type boolean)
  upstream
  ahead
  behind)

(defstruct (vcs-tag
            (:constructor %make-vcs-tag)
            (:copier nil))
  "One tag from VCS-LIST-TAGS, lightweight or annotated.
TARGET is the object the tag names, peeled to the commit when ANNOTATED-P is
true.  MESSAGE and TAGGER are NIL for a lightweight tag or an empty field, and
SIGNATURE-STATUS is always NIL because no signature is verified."
  (name "" :type string)
  target
  (annotated-p nil :type boolean)
  message
  tagger
  signature-status)

(defstruct (vcs-commit
            (:constructor %make-vcs-commit)
            (:copier nil))
  "One commit from VCS-LIST-COMMITS, in the backend's traversal order.
PARENTS holds the parent IDs in recorded order and is empty for a root commit.
TREE, AUTHOR, COMMITTER, AUTHORED-AT, COMMITTED-AT and MESSAGE are NIL when the
backend reported that field empty; ENCODING is NIL for the default encoding."
  (id "" :type string)
  (parents nil :type list)
  tree
  author
  committer
  authored-at
  committed-at
  message
  encoding)

(defstruct (vcs-diff-entry
            (:constructor %make-vcs-diff-entry)
            (:copier nil))
  "One changed path from VCS-DIFF-ENTRIES, merging name-status with numstat.
STATUS is the backend's raw change code, and ORIGINAL-PATH is NIL unless the
change was a rename or a copy.  ADDITIONS and DELETIONS are NIL exactly when
BINARY-P is true, because a binary blob has no line counts."
  (status "" :type string)
  (path "" :type string)
  original-path
  additions
  deletions
  (binary-p nil :type boolean))

(defstruct (vcs-conflict
            (:constructor %make-vcs-conflict)
            (:copier nil))
  "One unmerged path from VCS-LIST-CONFLICTS, derived from its status entry.
BASE, OURS and THEIRS are the stage 1, 2 and 3 object IDs.  Each is NIL when
that stage is absent, as it is for an add/add or a delete/modify conflict."
  (path "" :type string)
  base
  ours
  theirs)

(defstruct (vcs-stash-entry
            (:constructor %make-vcs-stash-entry)
            (:copier nil))
  "One stash from VCS-LIST-STASHES, most recent first.
REFERENCE is the selector later stash commands accept, such as \"stash@{0}\",
and MESSAGE is the stash's reflog subject.  DATE is reserved for the stash
timestamp and is not yet reliably populated."
  (reference "" :type string)
  (message "" :type string)
  date)

(defstruct (vcs-worktree
            (:constructor %make-vcs-worktree)
            (:copier nil))
  "One worktree from VCS-LIST-WORKTREES, one per porcelain record block.
BRANCH is stored without its refs/heads/ prefix and is NIL for a detached or
bare worktree; HEAD is NIL when the block reported no commit.  BARE-P,
LOCKED-P and PRUNABLE-P are true only when the backend marked the worktree so."
  (path "" :type string)
  head
  branch
  (bare-p nil :type boolean)
  (locked-p nil :type boolean)
  (prunable-p nil :type boolean))

(defstruct (vcs-submodule
            (:constructor %make-vcs-submodule)
            (:copier nil))
  "One submodule from VCS-LIST-SUBMODULES, one per recursive status line.
HEAD is the recorded commit and WORKTREE-STATUS the one-character state marker.
NAME is NIL when no configuration entry maps PATH to a name, and URL is then
NIL too; INDEX is NIL when PATH is absent from the index."
  (path "" :type string)
  name
  url
  head
  index
  worktree-status)

;; Backend-neutral repository handles.  The original REPOSITORY structure is
;; retained for the Git-specific API; these structures provide the common
;; protocol used by all registered VCS backends.
(defstruct (vcs-backend
            (:constructor %make-vcs-backend)
            (:copier nil))
  (name :custom :type keyword)
  (executable "" :type string)
  (aliases nil :type list)
  (capabilities nil :type list)
  (commands nil :type list)
  (operation-kinds nil :type list)
  ;; Semantic observations are separate from raw command mappings.
  (structured-operations nil :type list)
  (markers nil :type list))

(defstruct (vcs-operation-info
            (:constructor %make-vcs-operation-info)
            (:copier nil))
  (operation :custom :type keyword)
  command
  (mapping-kind :alias :type keyword))

(defstruct (vcs-repository
            (:constructor %make-vcs-repository)
            (:copier nil))
  "A backend-neutral repository handle rooted at DIRECTORY.
MAKE-VCS-REPOSITORY, OPEN-VCS-REPOSITORY and DISCOVER-VCS-REPOSITORY each
return one whose BACKEND is a registered VCS-BACKEND and whose EXECUTABLE
defaults to that backend's own.  A NIL BACKEND means none was resolved."
  (directory "" :type string)
  (backend nil :type (or null vcs-backend))
  (executable "" :type string)
  (default-timeout 30d0 :type (or null real))
  (environment :inherit :type (or null list (member :inherit))))

;; GHQ value objects keep repository discovery data separate from command
;; execution.  A specification is the portable GHQ identity; PATH is the
;; resolved local location; BACKEND records an explicit GHQ VCS filter when
;; one was supplied by the caller.
(defstruct (ghq-repository-entry
            (:constructor make-ghq-repository-entry
                (&key (specification "") (path "") backend))
            (:copier nil))
  "One repository from GHQ-LIST-REPOSITORIES.
SPECIFICATION is the portable GHQ identity taken relative to the deepest
configured root, and PATH is the absolute local checkout.  BACKEND is NIL
unless the caller passed an explicit GHQ VCS filter, which is echoed back."
  (specification "" :type string)
  (path "" :type string)
  backend)

(defstruct (ghq-root-entry
            (:constructor make-ghq-root-entry (&key (path "") primary-p))
            (:copier nil))
  "One GHQ root from GHQ-LIST-ROOT-ENTRIES, in the order GHQ reported them.
PRIMARY-P is true for the first root only and NIL for every later one."
  (path "" :type string)
  (primary-p nil :type boolean))
