# Compatibility

## Built-in backend detection

The built-in backend metadata uses these marker paths:

| Backend | Marker paths |
| --- | --- |
| Git | `.git` |
| Mercurial | `.hg` |
| Subversion | `.svn` |
| Bazaar | `.bzr` |
| Fossil | `.fslckout`, `_FOSSIL_` |
| Darcs | `.darcs` |
| Pijul | `.pijul` |

Detection checks the selected directory and, for
`discover-vcs-repository`, its ancestors. Executable validation is optional
and can be requested with `:validate-executable t`.

## Operation mapping kinds

The backend-neutral operation layer records how a backend implements an
operation:

| Kind | Meaning |
| --- | --- |
| `:exact` | The backend has a direct operation mapping. |
| `:alias` | The mapping uses an alternate command or operation name. |
| `:approximate` | The mapping is the closest supported backend behavior, not an exact semantic match. |
| `:native` | The operation is specific to the backend's native feature set. |

Inspect the kind before relying on semantics that are stronger than a common
operation name.

## Structured observations

The current structured readers are Git-defined. They cover status, diffs,
remotes, branches, tags, commits, stashes, conflicts, worktrees, and
submodules. Backend-neutral code should check
`vcs-backend-supports-structured-operation-p` before invoking one of these
readers on a dynamically selected backend.

## Executable and platform boundaries

Git and GHQ are external executables; their installation and version are not
managed by the ASDF system. GHQ is only needed for GHQ operations. The Nix
flake declares `x86_64-linux` and `aarch64-darwin` systems for the project
outputs; the direct ASDF API is not limited to those systems when its Lisp and
external executable dependencies are available.

The library preserves process results and typed conditions rather than
silently translating unsupported behavior. See [core concepts](../guide/core-concepts.md)
and [operations](../guide/operations.md) for the selection rules.
