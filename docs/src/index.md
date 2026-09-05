# cl-vcs-kit

`cl-vcs-kit` provides Common Lisp interfaces for Git, GHQ, and additional
version-control backends registered through one backend-neutral API. It keeps
the raw process result available while also providing typed repository,
status, diff, reference, worktree, and submodule observations.

## Status

The package includes:

- direct Git and GHQ command wrappers;
- automatic repository discovery through backend marker directories;
- backend registration, capability inspection, and operation mappings;
- structured Git observations for status, diffs, references, conflicts,
  worktrees, and submodules;
- synchronous and asynchronous process tasks with cancellation and event
  cursors.

## Guides

- [Getting started](getting-started.md) — installation and the first
  backend-neutral call.
- [Core concepts](guide/core-concepts.md) — repository handles, detection, and
  process results.
- [Operations](guide/operations.md) — raw commands, normalized operations, and
  custom backends.
- [Structured observations](guide/structured-observations.md) — typed results
  for common Git queries.
- [Asynchronous tasks](guide/async.md) — cancellation and event delivery.
- [GHQ](guide/ghq.md) — repository discovery and GHQ management.

The [reference section](reference/api.md) lists the public API. [Compatibility]
(reference/compatibility.md) defines the boundary between backend-neutral and
Git-defined features.

## Minimal example

```lisp
(asdf:load-system "cl-vcs-kit")

(let ((repository
        (vcs-kit:open-vcs-repository #p"/work/project/")))
  (vcs-kit:process-result-stdout
   (vcs-kit:vcs-status repository "--porcelain")))
```

The operation wrappers return the process-kit result object. Use the
structured readers when the application needs typed observations instead of
parsing command output itself.

## Nix workflow

Development and documentation commands:

```sh
nix develop
nix run .#test
nix flake check
nix build .#docs
```

See [development](project/development.md) for the local MkDocs command and
the verification boundaries of each entry point.
