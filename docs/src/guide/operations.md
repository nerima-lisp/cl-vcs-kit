# Operations and custom backends

## Raw commands

`run-vcs` accepts a backend-neutral repository, a command name, and an
argument list. It returns a process result and signals typed failures for
invalid repository or backend state.

```lisp
(vcs-kit:run-vcs repository
                 "status"
                 '("--porcelain" "--branch")
                 :timeout 5d0)
```

Use `run-vcs-async` for a task, `run-vcs/checked` when a non-zero exit should
be signaled, and `run-vcs/k` when the result should be returned in a compact
multiple-value form. `vcs-version` and `vcs-version-async` provide the same
execution controls for a backend's version command.

## Normalized operations

`run-vcs-operation` resolves an operation through the selected backend's
mapping and then executes it. The generated wrappers are convenient names for
the same operation family:

```lisp
(vcs-kit:vcs-status repository "--short")
(vcs-kit:vcs-log repository "--oneline" "-5")
(vcs-kit:vcs-commit repository "-m" "message")
```

Execution options are separated from command arguments with a final
`:execution-options` marker:

```lisp
(vcs-kit:vcs-status repository
                    "--porcelain"
                    :execution-options '(:timeout 5d0
                                         :max-output-characters 100000))
```

The value after the marker must be a proper keyword plist. Without the marker,
all arguments are passed to the backend command as command arguments.

The operation mapping kind is available through
`vcs-operation-kind`. The kinds are `:exact`, `:alias`, `:approximate`, and
`:native`; `vcs-operation-info` exposes the rest of the mapping metadata.

## Register a backend

Register a backend with `make-vcs-backend` and add it to the process-wide
registry:

```lisp
(vcs-kit:register-vcs-backend
 (vcs-kit:make-vcs-backend
  :name :example
  :executable "example-vcs"
  :aliases '(:ex)
  :capabilities '(:status :commit)
  :commands '((:status . "status")
              (:commit . "commit")
              (:version . "version"))
  :markers '(".example")))
```

Command mappings may be strings, symbols, argument lists, or functions. The
backend definition validates duplicate names and capability mappings before
registration. `unregister-vcs-backend` removes a registered backend when an
application owns the registry lifecycle.

## Operation coverage

The normalized operation vocabulary includes status, diff, history, content,
staging, commits, branches, tags, synchronization, merge/rebase/reset/revert,
stash, remotes, worktrees, submodules, bundles, maintenance, and verification.
Backends can expose only the subset they support; inspect
`vcs-backend-supports-operation-p` before selecting a normalized operation.
