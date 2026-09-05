# Getting started

## Prerequisites

The ASDF system depends on `cl-process-kit`, `cl-host-kit`, and `cl-log-kit`.
Git is needed for Git-backed operations. GHQ commands additionally require the
`ghq` executable on the process path.

When working from this repository, the pinned Nix development shell supplies
the development tools:

```sh
nix develop
```

Run these checks:

```sh
nix run .#test
nix flake check
nix build .#docs
```

## Open a known repository

Use `open-vcs-repository` when the directory is known. It creates a
backend-neutral handle; automatic detection is used unless `:backend` is
provided explicitly.

```lisp
(let ((repository
        (vcs-kit:open-vcs-repository #p"/work/project/")))
  (vcs-kit:vcs-version :directory (vcs-kit:vcs-repository-directory repository))
  (vcs-kit:vcs-status repository "--short"))
```

`open-vcs-repository` does not need to probe the executable by default. Pass
`:validate-executable t` when opening should also validate a version-like
command.

## Discover from a path

`discover-vcs-repository` searches the supplied directory and its ancestors
for registered backend markers. An explicit backend limits the lookup to that
backend and the supplied directory.

```lisp
(let ((repository
        (vcs-kit:discover-vcs-repository #p"/work/project/src/")))
  (vcs-kit:vcs-status repository "--porcelain"))
```

If no registered backend is found, a typed backend detection condition is
signalled. See [compatibility](reference/compatibility.md) for the built-in
marker directories.

## Choose the result shape

The command wrappers return the process result from `cl-process-kit`:

```lisp
(let ((result (vcs-kit:vcs-status repository "--porcelain")))
  (values (vcs-kit:process-result-exit-code result)
          (vcs-kit:process-result-stdout result)))
```

For application logic that should not depend on Git's output format, use a
reader such as `vcs-status-structured` or `vcs-diff-entries`. See
[structured observations](guide/structured-observations.md) for their fields
and options.
