# API reference map

The `vcs-kit` package exports the public API. The sections below group symbols
by purpose and document the intended call boundaries.

## Repository and detection

`repository`, `repository-p`, `make-repository`, `open-repository`,
`vcs-repository`, `vcs-repository-p`,
`make-vcs-repository`, `open-vcs-repository`, `discover-vcs-repository`, and
`detect-vcs-backend` form the handle and detection layer.

The Git handle exposes `repository-directory`, `repository-git-directory`,
`repository-common-directory`, `repository-bare-p`, `repository-executable`,
`repository-default-timeout`, and `repository-environment`. The
backend-neutral handle exposes `vcs-repository-directory`,
`vcs-repository-backend`, `vcs-repository-executable`,
`vcs-repository-default-timeout`, and `vcs-repository-environment`.

## Process execution

The raw Git entry points are `run-git`, `run-git-async`, `run-git/checked`,
`run-git/k`, `git-version`, and `git-version-async`. The raw GHQ entry points
are `run-ghq`, `run-ghq-async`, `run-ghq/checked`, `run-ghq/k`, `ghq-version`,
and `ghq-version-async`. The raw backend-neutral entry points are `run-vcs`,
`run-vcs-async`, `run-vcs/checked`, `run-vcs/k`, `vcs-version`, and
`vcs-version-async`. Normalized execution uses `run-vcs-operation`,
`run-vcs-operation-async`, `run-vcs-operation/k`, and the generated `vcs-*`
operation wrappers.

The suffixes mean the same thing in all three families. The bare name returns
the process result and signals a typed condition for a launch failure, an I/O
failure, a timeout, or a cancellation, but not for a non-zero exit status
unless `:check` is supplied. `/checked` drops any caller-supplied `:check` and
runs with checking on, so a returned result is always a success. `/k` runs the
checked form and dispatches to a success or failure continuation. `-async`
returns a task instead of a result.

`vcs-init` and `vcs-clone` sit outside that scheme. They create a repository
rather than act on one, so each takes a target directory and a `:backend`
designator in place of a repository handle.

The returned process result uses the accessors supplied by `cl-process-kit`,
including `process-result-exit-code`, `process-result-stdout`, and
`process-result-stderr`. These are re-exported from `cl-process-kit` rather
than defined here, and they carry that package's documentation, so
`(describe 'vcs-kit:process-result-stdout)` shows no docstring from this
system.

Every synchronous and asynchronous command emits a structured `log-kit`
event through `vcs-kit:*vcs-logger*`. The default logger is silent. Bind that
special variable to a `log-kit` logger with a handler when command telemetry is
needed; the event includes the executable, arguments, directory, and timeout.

Typed failures are grouped by family in [conditions](conditions.md).

!!! note "Documented deviation from the API standard"

    The org API standard caps required positional arguments at three. Four
    exported functions take more. This is an accepted exception, not an
    outstanding defect:

    | Function | Required positionals |
    | --- | --- |
    | `run-git/k` | 5: `repository subcommand arguments on-success on-failure` |
    | `run-vcs/k` | 5: `repository command arguments on-success on-failure` |
    | `run-vcs-operation/k` | 5: `repository operation arguments on-success on-failure` |
    | `run-ghq/k` | 4: `command arguments on-success on-failure` |

    The continuations stay positional to keep the call site consistent with the
    checked runner each of these wraps. `run-git/checked` and its siblings take
    execution options as a flat `&rest`, so naming the continuations would make
    the CPS entry points the only ones in the package whose options are passed
    in a different shape from the runner they delegate to, and converting a
    call between the two forms would mean rewrapping the options.

    That is a cost weighed against a benefit, not an impossibility. A lambda
    list of the form `(repository subcommand arguments &key on-success
    on-failure execution-options)` satisfies the cap and works — the package
    already passes forwarded options as a single `:execution-options` plist in
    its structured readers. The exception is recorded here because the trade
    is part of the public contract, and it can only be revisited in a release
    that is allowed to break callers.

## Git operations

The Git wrappers are thin argv builders over `run-git/checked`. They exist so
that a common call reads as a Lisp function rather than as a string of flags;
anything they do not cover is still reachable through `run-git`. The groups
match the export sections in `src/package-exports-git.lisp`.

Repository creation uses `git-init` and `git-clone`.

Observation covers `git-status`, `git-diff` with its `git-diff-stat`,
`git-diff-name-status` and `git-diff-numstat` variants, `git-log`, `git-show`,
`git-reflog`, `git-rev-list`, `git-rev-parse`, `git-for-each-ref`,
`git-merge-base`, `git-describe`, `git-blame`, `git-grep`, `git-ls-files`,
`git-ls-tree`, `git-cat-file`, and `git-ls-remote`. `git-status`, `git-diff`,
`git-diff-name-status` and `git-diff-numstat` have parsing counterparts under
[structured data](#structured-data); the rest return a process result.

Working-tree and history mutation covers `git-add` and its `git-stage` alias,
`git-commit`, `git-branch`, `git-switch`, `git-checkout`, `git-restore`,
`git-reset`, `git-rm`, `git-mv`, `git-clean`, `git-tag`, `git-update-ref`,
`git-merge`, `git-rebase`, `git-cherry-pick`, `git-revert`, `git-stash`,
`git-sparse-checkout`, and `git-rerere`.

Remotes, worktrees, submodules and maintenance cover `git-remote`,
`git-fetch`, `git-pull`, `git-push`, `git-worktree`, `git-submodule`,
`git-notes`, `git-bisect`, `git-archive`, `git-bundle`, `git-format-patch`,
`git-am`, `git-apply`, `git-maintenance`, `git-gc`, `git-prune`, `git-repack`,
and `git-fsck`.

Plumbing and object/index commands cover `git-config`, `git-hash-object`,
`git-commit-tree`, `git-write-tree`, `git-read-tree`, `git-update-index`,
`git-merge-tree`, `git-mktree`, `git-mktag`, `git-pack-objects`,
`git-index-pack`, `git-hook`, `git-replace`, `git-verify-commit`,
`git-verify-tag`, and `git-commit-graph`.

The full set is the `git-*` block of `src/package-exports-git.lisp`, which
covers the locally available Git command families. The names listed here are
the ones a caller reaches for first rather than the whole list.

## Backend registry

Use `make-vcs-backend`, `register-vcs-backend`,
`unregister-vcs-backend`, `available-vcs-backends`, and `find-vcs-backend` to
manage backend definitions. Inspect support and mappings with
`vcs-backend-supports-operation-p`,
`vcs-backend-supports-structured-operation-p`, `vcs-operation-info`, and
`vcs-operation-kind`.

## Structured data

Status and diff readers are `vcs-status-structured` and `vcs-diff-entries`.
Reference and repository-state readers are `vcs-list-remotes`,
`vcs-list-branches`, `vcs-list-tags`, `vcs-list-commits`,
`vcs-list-stashes`, `vcs-list-conflicts`, `vcs-list-worktrees`, and
`vcs-list-submodules`.

Their result types include `vcs-status-snapshot`, `vcs-status-entry`,
`vcs-diff-entry`, `vcs-remote`, `vcs-branch`, `vcs-tag`, `vcs-commit`,
`vcs-conflict`, `vcs-stash-entry`, `vcs-worktree`, and `vcs-submodule`.

## Async and cancellation

Task lifecycle symbols are `await-vcs-task`, `cancel-vcs-task`,
`vcs-task-state`, `vcs-task-result`, `vcs-task-condition`, `vcs-task-events`,
`next-vcs-event`, `vcs-task-callback-errors`, and
`vcs-task-dropped-event-count`. Shared cancellation uses
`vcs-cancellation-token`, `make-vcs-cancellation-token`, `cancel-vcs`, and
`vcs-cancellation-requested-p`.

## GHQ

Direct GHQ wrappers include `ghq-get`, `ghq-clone`, `ghq-list`, `ghq-roots`,
`ghq-root`, `ghq-path`, `ghq-rm`, `ghq-create`, `ghq-migrate`, and `ghq-help`.
Typed listings are `ghq-list-repositories` and
`ghq-list-root-entries`, with `ghq-repository-entry` and `ghq-root-entry`
accessors.

The source of truth for the complete export list is the
[`package-exports-core.lisp`](https://github.com/nerima-lisp/cl-vcs-kit/blob/main/src/package-exports-core.lisp),
[`package-exports-git.lisp`](https://github.com/nerima-lisp/cl-vcs-kit/blob/main/src/package-exports-git.lisp),
[`package-exports-vcs.lisp`](https://github.com/nerima-lisp/cl-vcs-kit/blob/main/src/package-exports-vcs.lisp),
and
[`package-exports-ghq.lisp`](https://github.com/nerima-lisp/cl-vcs-kit/blob/main/src/package-exports-ghq.lisp)
files; `src/package.lisp` itself only defines the package and its
`cl-process-kit` imports. The linked guides document argument boundaries and
return shapes for the most commonly used groups.
