(in-package #:vcs-kit)

(defun %vcs-required-command (backend operation repository)
  (let* ((backend (find-vcs-backend backend))
         (operation (%vcs-keyword operation))
         (command (and (vcs-backend-supports-operation-p backend operation)
                       (%vcs-backend-command backend operation))))
    (or command
      (error 'vcs-unsupported-operation-error
             :backend backend
             :repository repository
             :operation operation
             :capabilities (vcs-backend-capabilities backend)))))

(defun run-vcs-operation (repository operation arguments &rest options)
  "Run a normalized operation on a backend-neutral repository."
  (check-type repository vcs-repository)
  (check-type arguments list)
  (let* ((backend (vcs-repository-backend repository))
         (command (%vcs-required-command backend operation repository)))
    (apply #'run-vcs/checked repository command arguments options)))

(defun run-vcs-operation-async (repository operation arguments &rest options)
  "Start a normalized backend operation and return its process task."
  (check-type repository vcs-repository)
  (check-type arguments list)
  (let* ((backend (vcs-repository-backend repository))
         (command (%vcs-required-command backend operation repository)))
    (apply #'run-vcs-async repository command arguments options)))

(defun run-vcs-operation/k
    (repository operation arguments on-success on-failure &rest options)
  "Return the value ON-SUCCESS or ON-FAILURE returns for a normalized operation.

Only a VCS-ERROR reaches ON-FAILURE: the dispatch is a HANDLER-CASE on that one
type, so it covers VCS-UNSUPPORTED-OPERATION-ERROR and VCS-UNKNOWN-BACKEND-ERROR
from resolving OPERATION as well as the command failures.  A TYPE-ERROR from an
argument of the wrong type, and a PROGRAM-ERROR from a malformed OPTIONS plist,
propagate past both continuations to the caller, so a caller that must not
escape still needs its own handler.

ON-SUCCESS and ON-FAILURE are positional. This keeps the call shaped like
RUN-VCS-OPERATION, which takes execution options as a flat &REST. A &KEY form
would satisfy the three-required-argument limit of the org API standard, but
would change the public calling convention. See reference/api.md."
  (with-vcs-result (result on-success on-failure)
    (apply #'run-vcs-operation repository operation arguments options)))

(defun %split-vcs-operation-options (arguments)
  (unless (%proper-list-p arguments)
    (error 'vcs-argument-error
           :argument arguments
           :reason "VCS operation arguments must be a proper list"))
  (let ((marker (position :execution-options arguments :from-end t
                          :test #'eq)))
    (if marker
        (let ((remaining (nthcdr (1+ marker) arguments)))
          (unless (= (length remaining) 1)
            (error 'vcs-argument-error
                   :argument remaining
                   :position marker
                   :reason "VCS operation execution options must be the final value"))
          (let ((options (first remaining)))
            (unless (%proper-list-p options)
              (error 'vcs-argument-error
                     :argument options
                     :position marker
                     :reason "VCS operation execution options must be a proper list"))
            (unless (evenp (length options))
              (error 'vcs-argument-error
                     :argument options
                     :position marker
                     :reason "VCS operation execution options must be a property list"))
            (loop for key in options by #'cddr
                  unless (keywordp key)
                    do (error 'vcs-argument-error
                              :argument key
                              :position marker
                              :reason "VCS operation execution option keys must be keywords"))
            (values (subseq arguments 0 marker) options)))
        (values arguments nil))))

(defmacro %define-vcs-operation (name operation)
  `(defun ,name (repository &rest arguments)
     (multiple-value-bind (arguments options)
         (%split-vcs-operation-options arguments)
       (apply #'run-vcs-operation repository ,operation arguments options))))

(%define-vcs-operation vcs-status :status)
(%define-vcs-operation vcs-diff :diff)
(%define-vcs-operation vcs-log :log)
(%define-vcs-operation vcs-show :show)
(%define-vcs-operation vcs-cat :cat)
(%define-vcs-operation vcs-add :add)
(%define-vcs-operation vcs-remove :remove)
(%define-vcs-operation vcs-move :move)
(%define-vcs-operation vcs-commit :commit)
(%define-vcs-operation vcs-branch :branch)
(%define-vcs-operation vcs-switch :switch)
(%define-vcs-operation vcs-checkout :checkout)
(%define-vcs-operation vcs-tag :tag)
(%define-vcs-operation vcs-fetch :fetch)
(%define-vcs-operation vcs-pull :pull)
(%define-vcs-operation vcs-push :push)
(%define-vcs-operation vcs-merge :merge)
(%define-vcs-operation vcs-rebase :rebase)
(%define-vcs-operation vcs-reset :reset)
(%define-vcs-operation vcs-revert :revert)
(%define-vcs-operation vcs-stash :stash)
(%define-vcs-operation vcs-remote :remote)
(%define-vcs-operation vcs-update :update)
(%define-vcs-operation vcs-sync :sync)
(%define-vcs-operation vcs-archive :archive)
(%define-vcs-operation vcs-annotate :annotate)
(%define-vcs-operation vcs-blame :blame)
(%define-vcs-operation vcs-resolve :resolve)
(%define-vcs-operation vcs-clean :clean)
(%define-vcs-operation vcs-lock :lock)
(%define-vcs-operation vcs-unlock :unlock)
(%define-vcs-operation vcs-config :config)
(%define-vcs-operation vcs-help :help)
(%define-vcs-operation vcs-worktree :worktree)
(%define-vcs-operation vcs-submodule :submodule)
(%define-vcs-operation vcs-bundle :bundle)
(%define-vcs-operation vcs-maintenance :maintenance)
(%define-vcs-operation vcs-verify :verify)
