;;;; cl-vcs-kit.asd

;;;; This form comes FIRST, before any defsystem. ASDF binds *package* to
;;;; ASDF-USER only for a file it loads itself; read any other way -- a REPL
;;;; `load`, an editor evaluating the buffer, flake.nix parsing :version -- the
;;;; file is read in whatever package happens to be current. Saying it makes
;;;; the file self-contained.
(in-package #:asdf-user)

(defsystem "cl-vcs-kit"
  :description "Typed Common Lisp interfaces to Git and GHQ"
  :long-description "Typed, non-shell interfaces to Git, other version-control
systems, and GHQ. Arguments reach the executable directly rather than through a
shell, process output is captured as structured results, and failures are
signaled as conditions that retain the underlying command result."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.1"
  :homepage "https://github.com/nerima-lisp/cl-vcs-kit"
  :bug-tracker "https://github.com/nerima-lisp/cl-vcs-kit/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-vcs-kit.git")
  :depends-on ("cl-process-kit")
  :pathname "src"
  :serial t
  :components ((:file "package")
               (:file "types")
               (:file "conditions-core")
               (:file "conditions-git")
               (:file "conditions-ghq")
               (:file "conditions-vcs")
               (:file "execution")
               (:file "async")
               (:file "process")
               (:file "ghq")
               (:file "repository")
               (:file "parse-common")
               (:file "parse-status")
               (:file "parse-diff")
               (:file "ghq-structured")
               (:file "vcs-backend-core")
               (:file "vcs-backend-data")
               (:file "vcs-backend-repository")
               (:file "vcs-commands-core")
               (:file "vcs-commands-operation")
               (:file "vcs-commands-standalone")
               (:file "vcs-observations-core")
               (:file "vcs-observations-refs")
               (:file "vcs-observations-worktree")
               (:file "vcs-observations-submodule")
               (:file "git-operations")
               (:file "ghq-operations-core")
               (:file "ghq-operations-repository")
               (:file "ghq-operations-management")
               ;; Export declarations are loaded after every definition so the
               ;; package contract is visible to clients without a monolithic
               ;; package file.
               (:file "package-exports-core")
               (:file "package-exports-git")
               (:file "package-exports-vcs")
               (:file "package-exports-ghq"))
  ;; Without this, `asdf:test-system "cl-vcs-kit"` succeeds while running zero
  ;; tests -- a green result that measures nothing.
  :in-order-to ((test-op (test-op "cl-vcs-kit/test"))))

(defsystem "cl-vcs-kit/test"
  :description "Test system for cl-vcs-kit."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.1"
  :homepage "https://github.com/nerima-lisp/cl-vcs-kit"
  :bug-tracker "https://github.com/nerima-lisp/cl-vcs-kit/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-vcs-kit.git")
  :depends-on ("cl-vcs-kit" "cl-weave")
  :pathname "t"
  :serial t
  :components ((:file "package")
               (:file "support")
               (:file "runner")
               (:file "condition-test")
               (:file "data-test")
               (:file "execution-test")
               (:file "parser-test")
               (:file "process-test")
               (:file "ghq-test")
               (:file "ghq-operation-test")
               (:file "advanced-api-test")
               (:file "repository-test")
               (:file "repository-remote-test")
               (:file "operation-test")
               (:file "operation-execution-test")))

(defmethod perform ((operation test-op) (system (eql (find-system "cl-vcs-kit/test"))))
  (declare (ignore operation system))
  (uiop:symbol-call :vcs-kit/test :run-tests))
