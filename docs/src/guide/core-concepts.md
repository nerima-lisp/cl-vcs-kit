# Core concepts

`cl-vcs-kit` has three related layers. Pick the narrowest layer that matches
the application boundary.

## Repository handles

`repository` is the Git-oriented handle used by the direct Git API.
`vcs-repository` is the backend-neutral handle used by detection, normalized
operations, and backend capability checks. Both hold a directory and
execution defaults; constructing a handle does not run a command.

The main constructors are:

- `make-repository` and `open-repository` for the Git-oriented API;
- `make-vcs-repository` for an explicit backend-neutral handle;
- `open-vcs-repository` for a handle in one directory;
- `discover-vcs-repository` for detection in a directory or its ancestors.

## Detection and backends

Backends are described by a name, executable, aliases, capabilities, command
mappings, structured operations, and marker paths. The built-in registry
contains Git, Mercurial, Subversion, Bazaar, Fossil, Darcs, and Pijul.

```lisp
(vcs-kit:available-vcs-backends)
(vcs-kit:find-vcs-backend :git)
(vcs-kit:vcs-backend-supports-operation-p :git :status)
```

The registry is extensible. A backend may expose normalized operations even
when its command names differ from Git's, and it may advertise only the
structured observations it can implement.

## Process results

Raw and normalized operations both preserve the process-kit result. This
means callers can inspect exit status, standard output, standard error, and
the original command outcome without re-running the command.

Commands are assembled as an executable plus an argument vector. A raw
operation can therefore pass Git options directly:

```lisp
(vcs-kit:run-vcs repository "status" '("--porcelain" "--branch")
                  :timeout 5d0)
```

The default VCS timeout is 30 seconds. Execution options also cover input,
environment updates, output limits, cancellation, process grace periods, and
decoding policy. See [operations](operations.md) for the option boundary.

## Choose an API layer

Use the Git-specific API when you need Git's full command surface. Use
backend-neutral normalized operations when the application can work with a
common operation vocabulary. Use structured observations when the application
needs typed data rather than a backend's text format.

The structured layer is narrower than the raw command layer:
the current readers are Git-defined and report that boundary through backend
capability metadata. [Compatibility](../reference/compatibility.md) lists the
current split.
