# Conditions

Every condition this package signals is a subtype of `vcs-error`, itself a
subtype of `cl:error`. The type named in a `handler-case` clause decides which
failures are caught. The inheritance is stated explicitly below.

Three families sit under the root and do not overlap. Which one you handle
follows from the entry point you call, not the backend that happens to run:
`git-error` from `run-git` and everything built on it, `ghq-error` from
`run-ghq` and the `ghq-*` wrappers, and `vcs-command-error` from `run-vcs`,
`run-vcs-operation`, the generated `vcs-*` wrappers, and the structured
readers — including when the selected backend is Git. Reaching Git through
`run-vcs` therefore yields `vcs-command-exit-error`, never `git-exit-error`.

## Hierarchy

```text
cl:error
  vcs-error
    vcs-argument-error
    git-parse-error
    git-error
      git-exit-error
      git-timeout-error
      git-cancelled-error
      git-launch-error
      git-io-error
    ghq-error
      ghq-exit-error
      ghq-timeout-error
      ghq-cancelled-error
      ghq-launch-error
      ghq-io-error
    vcs-command-error
      vcs-command-exit-error
      vcs-command-timeout-error
      vcs-command-cancelled-error
      vcs-command-launch-error
      vcs-command-io-error
    vcs-backend-error
      vcs-unknown-backend-error
      vcs-backend-registration-error
      vcs-backend-detection-error
      vcs-unsupported-operation-error
```

Two placements the names do not suggest: `vcs-argument-error` and
`git-parse-error` descend from `vcs-error` directly, not from `git-error`, so a
handler catching only `git-error` misses a rejected argument and a malformed
Git record even though both arise while using the Git API. The five interior
types are never signalled themselves; they exist so one clause can cover a
whole family.

## Retained process results

The failing command result remains attached to its condition, so reporting it
does not discard what the command produced. See
[process results](../guide/core-concepts.md#process-results).
Retention is not uniform within a family, though. The `result` slot exists on
all five subtypes of each command family, but only the three outcome
conditions carry a value, because the other two are signalled before any
result exists. `vcs-argument-error`, `git-parse-error`, and the
`vcs-backend-error` subtypes have no result slot at all.

| Condition | `result` reader returns | Also available |
| --- | --- | --- |
| `git-exit-error`, `ghq-exit-error`, `vcs-command-exit-error` | the `process-result` | exit code reader |
| `git-timeout-error`, `ghq-timeout-error`, `vcs-command-timeout-error` | the `process-result` | output captured before the deadline |
| `git-cancelled-error`, `ghq-cancelled-error`, `vcs-command-cancelled-error` | the `process-result` | output captured before cancellation |
| `git-launch-error`, `ghq-launch-error`, `vcs-command-launch-error` | `nil` | `cause`, `directory` |
| `git-io-error`, `ghq-io-error`, `vcs-command-io-error` | `nil` | `cause`, `directory`, `stream` |

Where a result is retained, reach it through the family reader
(`git-error-result`, `ghq-error-result`, `vcs-command-error-result`) and then
through the `cl-process-kit` accessors such as `process-result-exit-code`,
`process-result-stdout`, and `process-result-stderr`. Where no result is
retained, the underlying `cl-process-kit` condition is on the `cause` reader,
so the operating-system level detail stays reachable.

## Root and argument conditions

### `vcs-error`

Subtype of `cl:error`, with no slots and no readers. Catch it to handle any
failure this package signals. `with-vcs-result` routes a `vcs-error` to the
`on-failure` continuation of every `/k` entry point. The optional executable
probe used during backend detection treats any `vcs-error` as an unusable
backend and returns `nil`.

### `vcs-argument-error`

Subtype of `vcs-error`. Readers: `vcs-argument-error-argument`,
`vcs-argument-error-position` (`nil` when the argument is not positional), and
`vcs-argument-error-reason`. Signalled before any process starts, so no
process result exists. Every situation is argument validation, shared by the
Git, GHQ, and backend-neutral entry points. Validation covers a command
argument that is `nil`
or contains a NUL character; a subcommand that is neither a non-`nil` string
nor a symbol; an executable that is not a non-empty string; a backend
designator that is not a keyword, symbol, or string, which any entry point
taking `:backend` can raise; an operation argument list that is not a proper
list, distinct from the `:execution-options` plist below; an `:environment`
or `:environment-update` value that is not `:inherit`, `nil`, a list of
`KEY=VALUE` strings, or an alist of unique string keys; an
`:execution-options` value that is not a proper keyword plist, or that sets a
parser-owned key (`:output`, `:error-output`, `:result-type`, `:check`) on a
structured reader; and GHQ text output requested with anything other than
`:output :capture` and `:result-type :string`.

## Git conditions

`git-error` and its five subtypes share the slots below, so every reader here
is available on each subtype. The family is signalled by `run-git`,
`run-git-async`, `run-git/checked`, `run-git/k`, and every `git-*` wrapper,
since the wrappers route through `run-git/checked`.

| Reader | Contents |
| --- | --- |
| `git-error-repository` | the `repository` handle, or `nil` for a repository-less call such as `git-version` |
| `git-error-command` | the Git subcommand, as a string |
| `git-error-arguments` | the argument list, as strings |
| `git-error-result` | the `process-result`, or `nil` |
| `git-error-cause` | the underlying `cl-process-kit` condition, or `nil` |
| `git-error-directory` | the working directory, or `nil` |

### `git-error`

Subtype of `vcs-error`. Never signalled directly; catch it to handle any Git
process failure in one clause. It does not cover `git-parse-error` or
`vcs-argument-error`.

### `git-exit-error`

Subtype of `git-error`, adding `git-exit-error-exit-code`. Signalled when a
Git process finishes with a non-zero exit status and neither timed out nor was
cancelled. This is the only one of the five that `:check` gates: `run-git`
with `:check nil` returns the unsuccessful result instead of signalling, while
`run-git/checked` and the `git-*` wrappers always check. Retains the process
result.

### `git-timeout-error`

Subtype of `git-error`, with no additional readers. Signalled when the process
exceeded its timeout, which is the repository's `repository-default-timeout`
or the `:timeout` given to the call. Signalled regardless of `:check`, because
a timed-out result is not the result the caller asked for. Retains the process
result, including whatever output was captured before the deadline.

### `git-cancelled-error`

Subtype of `git-error`, with no additional readers. Signalled when the process
was stopped through a cancellation token, and like a timeout this happens
regardless of `:check`. Retains the process result. See
[cancellation](../guide/async.md#cancellation) for the token lifecycle.

### `git-launch-error`

Subtype of `git-error`, with no additional readers. Signalled when Git could
not be started at all, because the executable is missing or not executable, or
because the working directory cannot be used. It wraps the `cl-process-kit`
launch condition, which stays on `git-error-cause`, and `run-git-async`
signals it too, at start time. No process result exists.

### `git-io-error`

Subtype of `git-error`, adding `git-io-error-stream`, which names the stream
that failed. Signalled when reading from or writing to the process failed
after it started, wrapping the `cl-process-kit` I/O condition on
`git-error-cause`. The synchronous `run-git` performs this translation; an
asynchronous task reports a later I/O failure through the task. No process
result exists.

### `git-parse-error`

Subtype of `vcs-error`, not of `git-error`. Readers:
`git-parse-error-format-name` (`"status"`, `"name-status"`, or `"numstat"`),
`git-parse-error-record` (the record that could not be read), and
`git-parse-error-position` (the record index, or `nil`). Signalled by
`parse-status`, `parse-name-status`, `parse-numstat`, and the structured
readers built on them, when Git's machine-readable output does not match the
expected shape. The command itself succeeded, which is why there is no result
slot: the offending text is on `git-parse-error-record`. See
[structured observations](../guide/structured-observations.md).

## GHQ conditions

`ghq-error` and its five subtypes mirror the Git family with one difference:
there is no repository slot, because GHQ operates on its own root rather than
on a repository handle. The readers are `ghq-error-command`,
`ghq-error-arguments`, `ghq-error-result`, `ghq-error-cause`, and
`ghq-error-directory`, each holding what its Git counterpart holds. The family
is signalled by `run-ghq`, `run-ghq-async`, `run-ghq/checked`, `run-ghq/k`,
and every `ghq-*` wrapper. See [GHQ](../guide/ghq.md#direct-operations).

### `ghq-error`

Subtype of `vcs-error`. Never signalled directly; catch it to handle any GHQ
process failure in one clause.

### `ghq-exit-error`

Subtype of `ghq-error`, adding `ghq-exit-error-exit-code`. Signalled when GHQ
exits non-zero without timing out or being cancelled. Gated by `:check` on
`run-ghq`; the `ghq-*` wrappers and `ghq-version` always check, because they
call `run-ghq/checked`. Retains the process result.

### `ghq-timeout-error`

Subtype of `ghq-error`, with no additional readers. Signalled when the GHQ
process exceeded its timeout, regardless of `:check`. Retains the result.

### `ghq-cancelled-error`

Subtype of `ghq-error`, no additional readers. Signalled when the GHQ process
was stopped through a cancellation token, regardless of `:check`. Retains the
result.

### `ghq-launch-error`

Subtype of `ghq-error`, with no additional readers. Signalled when the `ghq`
executable could not be started, from both `run-ghq` and `run-ghq-async`, with
the `cl-process-kit` launch condition on `ghq-error-cause`. Because GHQ is an
optional external executable, this is the condition to expect on a machine
where it is not installed. No process result exists.

### `ghq-io-error`

Subtype of `ghq-error`, adding `ghq-io-error-stream`. Signalled when I/O with
a started GHQ process failed, from the synchronous `run-ghq`, with the
`cl-process-kit` I/O condition on `ghq-error-cause`. No process result exists.

## Backend-neutral command conditions

`vcs-command-error` and its five subtypes carry the failures of the
backend-neutral API. Handle these, not the Git family, when you call
`run-vcs`, `run-vcs-operation`, a generated `vcs-*` wrapper, or a structured
reader, whichever backend is selected.

The readers are `vcs-command-error-repository` (a `vcs-repository` handle, or
`nil`), `vcs-command-error-command`, `vcs-command-error-arguments`,
`vcs-command-error-result`, `vcs-command-error-cause`, and
`vcs-command-error-directory`. Unlike the Git family,
`vcs-command-error-command` is not normalized to a string before the condition
is built: `run-vcs` accepts a list of command fragments and the condition
reports what you passed. See
[raw commands](../guide/operations.md#raw-commands).

### `vcs-command-error`

Subtype of `vcs-error`. Never signalled directly; catch it to handle any
backend-neutral command failure in one clause.

### `vcs-command-exit-error`

Subtype of `vcs-command-error`, adding `vcs-command-exit-error-exit-code`,
which is `nil` when the process produced no exit status. Signalled when the
backend process exits non-zero without timing out or being cancelled. Gated by
`:check` on `run-vcs`; `run-vcs/checked`, `run-vcs-operation`, the `vcs-*`
wrappers, and the structured readers always check. Retains the process result.
Those readers depend on this type being distinguishable: for the Git queries
that use exit status one to mean "no match", they catch
`vcs-command-exit-error`, read the exit code, and re-signal anything that is
not a one.

### `vcs-command-timeout-error`

Subtype of `vcs-command-error`, with no additional readers. Signalled when the
backend process exceeded its timeout, which is the handle's
`vcs-repository-default-timeout` or the `:timeout` given to the call.
Signalled regardless of `:check`. Retains the process result.

### `vcs-command-cancelled-error`

Subtype of `vcs-command-error`, no additional readers. Signalled when the
backend process was stopped through a cancellation token, regardless of
`:check`. Retains the result.

### `vcs-command-launch-error`

Subtype of `vcs-command-error`, with no additional readers. Signalled when the
backend executable could not be started, from both `run-vcs` and
`run-vcs-async`, with the `cl-process-kit` launch condition on
`vcs-command-error-cause`. No process result exists.

### `vcs-command-io-error`

Subtype of `vcs-command-error`, adding `vcs-command-io-error-stream`.
Signalled when I/O with a started backend process failed, from `run-vcs` and
from `run-vcs-async` at start time, with the `cl-process-kit` I/O condition on
`vcs-command-error-cause`. No process result exists.

## Backend registry and capability conditions

`vcs-backend-error` covers failures of backend selection rather than of a
process, so none of these types has a result slot: no command was run. All
four subtypes inherit `vcs-backend-error-backend`, which holds the backend
descriptor the failure concerns, or `nil` when no descriptor was identified.

### `vcs-backend-error`

Subtype of `vcs-error`. Reader: `vcs-backend-error-backend`. Never signalled
directly; catch it to handle any registry or capability failure in one clause.

### `vcs-unknown-backend-error`

Subtype of `vcs-backend-error`, adding `vcs-unknown-backend-error-designator`
and `vcs-unknown-backend-error-known-backends`. Signalled by
`find-vcs-backend` when a designator matches no registered name and no
registered alias, and therefore by every entry point that resolves a
designator. Take that as the rule, because any function accepting a `:backend`
or candidate designator joins the set as soon as it is added: the constructors
`make-vcs-repository`, `open-vcs-repository`, and `discover-vcs-repository`;
`unregister-vcs-backend`; the standalone commands `vcs-version`,
`vcs-version-async`, `vcs-init`, and `vcs-clone`; `detect-vcs-backend`, for a
`:candidates` entry naming no registered backend; and every capability query,
`vcs-backend-supports-operation-p` and `vcs-supported-operations` along with
`vcs-backend-supports-structured-operation-p`, `vcs-structured-operations`,
and the `vcs-operation-command`, `-info`, and `-kind` group.
`vcs-backend-error-backend` is `nil` here, since the point of the condition is
that no descriptor was found.

### `vcs-backend-registration-error`

Subtype of `vcs-backend-error`, adding
`vcs-backend-registration-error-designator` and
`vcs-backend-registration-error-conflicting-backend`. Signalled by
`register-vcs-backend` in three situations: a backend with the same name is
already registered and `:replace nil` was given; the backend's own name and
aliases contain a duplicate; or one of its names or aliases is already claimed
by another registered descriptor. The designator that collided is on the
designator reader. See
[register a backend](../guide/operations.md#register-a-backend).

### `vcs-backend-detection-error`

Subtype of `vcs-backend-error`, adding
`vcs-backend-detection-error-directory`. Signalled by `open-vcs-repository`
when no backend marker is present in the directory, by `open-vcs-repository`
when an explicit backend was given with `:validate-executable t` and its
executable probe failed, and by `discover-vcs-repository` when neither the
starting directory nor any ancestor holds a marker. Those cases are
distinguishable through `vcs-backend-error-backend`: it is `nil` when
detection found nothing, and holds the requested descriptor when a named
backend failed its probe. The marker paths are listed in
[compatibility](compatibility.md#built-in-backend-detection).
`detect-vcs-backend` does not signal this condition: it returns `nil` when it
probes the registered backends and none matches. It does signal
`vcs-unknown-backend-error` when a `:candidates` entry names no registered
backend, because it resolves each candidate through `find-vcs-backend` before
probing for that backend's marker.

### `vcs-unsupported-operation-error`

Subtype of `vcs-backend-error`, adding
`vcs-unsupported-operation-error-repository`,
`vcs-unsupported-operation-error-operation`, and
`vcs-unsupported-operation-error-capabilities`. Signalled in two places:
`run-vcs-operation`, `run-vcs-operation-async`, `run-vcs-operation/k`, and the
generated `vcs-*` wrappers signal it when the selected backend declares no
command mapping for the requested operation, and the structured readers signal
it when the repository's backend is not Git or when the Git backend does not
declare that structured operation. The capabilities reader gives the backend's
declared operation set, so a handler can report what the backend does support.
To avoid the condition, test first with `vcs-backend-supports-operation-p` or
`vcs-backend-supports-structured-operation-p`. Both resolve their backend
argument through `find-vcs-backend`, so the pre-check itself signals
`vcs-unknown-backend-error` for a designator that is not registered, instead
of returning `nil`. Pass a descriptor you already hold, or a backend read from
a repository handle, and the pre-check cannot signal; where the designator
comes from outside, handle `vcs-unknown-backend-error` around the pre-check
too. See
[the capability boundary](../guide/structured-observations.md#capability-boundary).

## Handling patterns

Handle one family per entry point. A Git-specific call needs the Git family
plus the two types that sit outside it:

```lisp
(handler-case
    (vcs-kit:run-git repository "status" '("--porcelain") :check t)
  (vcs-kit:git-exit-error (condition)
    (values :failed
            (vcs-kit:git-exit-error-exit-code condition)
            (vcs-kit:process-result-stderr
             (vcs-kit:git-error-result condition))))
  (vcs-kit:git-error (condition)
    (values :unavailable (vcs-kit:git-error-cause condition)))
  (vcs-kit:vcs-argument-error (condition)
    (values :rejected (vcs-kit:vcs-argument-error-reason condition))))
```

Clause order matters: `git-exit-error` must precede `git-error`, and the
`git-error` clause here absorbs the timeout, cancellation, launch, and I/O
cases. Reading the result is safe only in the first clause, because the other
four may carry `nil` there. A backend-neutral call instead needs the command
family and, when the backend is chosen at run time, the capability conditions:

```lisp
(handler-case
    (vcs-kit:vcs-status repository "--porcelain")
  (vcs-kit:vcs-unsupported-operation-error (condition)
    (values :unsupported
            (vcs-kit:vcs-unsupported-operation-error-capabilities condition)))
  (vcs-kit:vcs-command-error (condition)
    (values :failed (vcs-kit:vcs-command-error-command condition))))
```

For a single failure continuation instead of a handler, the `/k` entry points
`run-git/k`, `run-ghq/k`, `run-vcs/k`, and `run-vcs-operation/k` call your
failure callback with any `vcs-error`, so the family grouping above applies
unchanged. The complete export list, including every reader named here, is in
[the API reference](api.md).
