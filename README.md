# cl-vcs-kit

[![CI](https://github.com/nerima-lisp/cl-vcs-kit/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nerima-lisp/cl-vcs-kit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-MkDocs%20Material-3f51b5)](https://nerima-lisp.github.io/cl-vcs-kit/)

`cl-vcs-kit` gives Common Lisp typed, non-shell interfaces to Git, GHQ, and
other version-control systems, targeting SBCL. Arguments go straight to the
executable as argv rather than through a shell, so nothing has to be quoted or
escaped; output comes back as structured results instead of strings the caller
re-parses; and failures signal conditions that keep the underlying command
result attached. A backend-neutral layer maps a common operation vocabulary
onto Git, Mercurial, Subversion, Bazaar, Fossil, Darcs, and Pijul without
pretending they share semantics. Its runtime dependencies are the org's
[`cl-process-kit`](https://github.com/nerima-lisp/cl-process-kit),
[`cl-host-kit`](https://github.com/nerima-lisp/cl-host-kit), and
[`cl-log-kit`](https://github.com/nerima-lisp/cl-log-kit); protocol parsers stay
local to the formats they implement.

Full documentation is published at <https://nerima-lisp.github.io/cl-vcs-kit/>.
The source for that site lives in [docs/src/](docs/src/).

## Quick Start

```lisp
(asdf:load-system "cl-vcs-kit")

;; Git, typed: a porcelain-v2 status parsed into a snapshot struct.
(let ((status (vcs-kit:git-status (vcs-kit:open-repository #p"/work/project/"))))
  (mapcar #'vcs-kit:status-entry-path
          (vcs-kit:status-snapshot-entries status)))
;; => the path of every changed file, as a list of strings

;; The same repository through the backend-neutral layer, which resolves
;; whichever VCS actually owns the directory.
(let ((repository (vcs-kit:open-vcs-repository #p"/work/project/")))
  (vcs-kit:process-result-stdout
   (vcs-kit:vcs-status repository "--porcelain")))
```

Use `discover-vcs-repository` instead when the starting directory may be nested
somewhere inside a working tree.

## Install

```nix
# flake.nix
inputs.cl-vcs-kit = {
  url = "github:nerima-lisp/cl-vcs-kit/v0.2.0";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Pin a release tag rather than following the default branch.

For a local checkout, make it and its dependencies visible to the Common Lisp
source registry, then `(asdf:load-system "cl-vcs-kit")`. The runtime
dependencies are `cl-process-kit`, `cl-host-kit`, and `cl-log-kit`; the test
system adds `cl-weave`. Host-facing pathname, temporary-directory, and
command-line operations are provided by `cl-host-kit`, keeping the library's
runtime surface independent of ASDF's `uiop` utilities. The flake also supplies
the native `git` and `ghq` executables the development checks need.

## Documentation

- [Core concepts](https://nerima-lisp.github.io/cl-vcs-kit/guide/core-concepts/)
  — repository handles, the backend registry, and the three layers.
- [Operations](https://nerima-lisp.github.io/cl-vcs-kit/guide/operations/)
  — the common operation vocabulary, capability checks, and how each mapping is
  classified as exact, alias, approximate, or native.
- [Structured observations](https://nerima-lisp.github.io/cl-vcs-kit/guide/structured-observations/)
  — typed results for status, diffs, refs, worktrees, and submodules.
- [API reference](https://nerima-lisp.github.io/cl-vcs-kit/reference/api/)
  — the exported surface grouped by concern, with the condition hierarchy.

[Asynchronous tasks](https://nerima-lisp.github.io/cl-vcs-kit/guide/async/) and
[GHQ](https://nerima-lisp.github.io/cl-vcs-kit/guide/ghq/) have their own guide
pages.

## Development

```sh
nix develop          # SBCL with CL_SOURCE_REGISTRY already set
nix run .#test       # run the test suite
nix flake check      # tests + formatting + docs, the same gate CI uses
nix build .#docs     # build the documentation site
nix fmt              # format Nix sources (treefmt)
```

Tests live in `t/` and run under
[cl-weave](https://github.com/nerima-lisp/cl-weave), the org's test framework.
The suite creates temporary repositories for Git integration coverage, and
skips the GHQ executable test when GHQ is not installed. The reproducible
checkout command is:

```sh
nix develop --command sbcl --script run-tests.lisp
```

A direct `sbcl --script run-tests.lisp` invocation also works when the runtime
dependencies and `cl-weave` are already installed and registered with ASDF; it
is not a dependency installation step.

Coverage is always measured and gated by the suite itself; pass
`--coverage-report-directory /tmp/cl-vcs-kit-coverage/` to also write an HTML
report. See
[Development](https://nerima-lisp.github.io/cl-vcs-kit/project/development/) for
the coverage floor and the release process.

## Contributing

See the org-wide
[CONTRIBUTING](https://github.com/nerima-lisp/.github/blob/main/CONTRIBUTING.md)
guide and the
[package standard](https://github.com/nerima-lisp/.github/blob/main/PACKAGE_STANDARD.md).

## Support

See [SUPPORT](https://github.com/nerima-lisp/.github/blob/main/SUPPORT.md).
Report vulnerabilities through
[private GitHub security advisories](https://github.com/nerima-lisp/cl-vcs-kit/security/advisories/new),
not a public issue.

## License

MIT. See [LICENSE](LICENSE).
