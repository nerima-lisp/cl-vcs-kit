;;;; cl-vcs-kit.asd

;;;; ASDF reads this form before the system definition. REPL loads, editor
;;;; evaluation, and flake.nix version parsing may use the current package.
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
  :version "0.2.0"
  :homepage "https://github.com/nerima-lisp/cl-vcs-kit"
  :bug-tracker "https://github.com/nerima-lisp/cl-vcs-kit/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-vcs-kit.git")
  :depends-on ("cl-process-kit" "cl-host-kit" "cl-log-kit")
  :pathname "src"
  :serial t
  :components ((:file "package")
               (:file "types")
               (:file "conditions-core")
               (:file "conditions-git")
               (:file "conditions-ghq")
               (:file "conditions-vcs")
               (:file "execution")
               (:file "execution-async")
               (:file "async")
               (:file "process")
               (:file "ghq")
               (:file "repository")
               (:file "parse-common")
               (:file "parse-status")
               (:file "parse-diff")
               (:file "ghq-structured")
               (:file "vcs-backend-definition")
               (:file "vcs-backend-core")
               (:file "vcs-backend-data")
               (:file "vcs-backend-repository")
               (:file "git-operations")
               (:file "git-operations-generated")
               (:file "vcs-commands-core")
               (:file "vcs-commands-version")
               (:file "vcs-commands-operation")
               (:file "vcs-commands-standalone")
               (:file "vcs-observations-core")
               (:file "vcs-observations-remotes")
               (:file "vcs-observations-refs")
               (:file "vcs-observations-worktree")
               (:file "vcs-observations-submodule")
               (:file "ghq-operations-core")
               (:file "ghq-operations-repository")
               (:file "ghq-operations-management")
               ;; Load export declarations after all definitions.
               (:file "package-exports-core")
               (:file "package-exports-git")
               (:file "package-exports-vcs")
               (:file "package-exports-ghq"))
  ;; Make ASDF's test operation run the test system.
  :in-order-to ((test-op (test-op "cl-vcs-kit/test"))))

(defsystem "cl-vcs-kit/test"
  :description "Test system for cl-vcs-kit."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.2.0"
  :homepage "https://github.com/nerima-lisp/cl-vcs-kit"
  :bug-tracker "https://github.com/nerima-lisp/cl-vcs-kit/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-vcs-kit.git")
  :depends-on ("cl-vcs-kit" "cl-weave" "cl-log-kit")
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
               (:file "operation-contract-test")
               (:file "backend-detection-test")
               (:file "repository-test")
               (:file "repository-query-test")
               (:file "repository-worktree-test")
               (:file "repository-remote-test")
               (:file "git-operation-family-test")
               (:file "backend-operation-property-test")
               (:file "observation-operation-test")
               (:file "operation-test")
               (:file "operation-execution-test")))

(defmethod perform ((operation test-op) (system (eql (find-system "cl-vcs-kit/test"))))
  (declare (ignore operation system))
  (funcall (symbol-function (find-symbol "RUN-TESTS" :vcs-kit/test))))
