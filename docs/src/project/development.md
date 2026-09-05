# Development

## Nix entry points

Use the pinned development shell for local work:

```sh
nix develop
```

The repository exposes these checks and artifacts:

```sh
nix run .#test
nix flake check
nix build .#docs
```

`nix build .#docs` evaluates the MkDocs site from `docs/mkdocs.yml` and
`docs/src/`. The docs configuration uses `strict: true`, so a missing nav
entry, broken page reference, or configuration warning fails the build.

When MkDocs Material is available outside the flake, the equivalent direct
command is:

```sh
mkdocs build --strict \
  --config-file docs/mkdocs.yml \
  --site-dir /tmp/cl-vcs-kit-site/
```

## Tests and the coverage ratchet

`nix develop --command sbcl --script run-tests.lisp` is the reproducible test
entry point, and it always measures coverage. There is no opt-in flag: the script compiles the library with
sb-cover instrumentation, runs the suite, measures expression and branch
coverage over `src/`, prints both, and exits non-zero when either falls below
a floor recorded in `run-tests.lisp`.

Coverage is therefore a gate rather than a report. `nix run .#test`,
`nix flake check`, and a direct `sbcl --script run-tests.lisp` with the required
ASDF dependencies registered all run this one script, so CI enforces the same
floor a contributor sees locally, and a change that lowers coverage fails the
check even when every test passes.

The floors live in `run-tests.lisp` as `+minimum-expression-coverage+` and
`+minimum-branch-coverage+`. The script prints the measured result for each
run, so the current baseline is not duplicated here. The floors
are ratcheted to the measured baseline; any future decrease must be accompanied
by a test or an explicit reduction justified by the change.

Package declaration/export files and the static backend catalog are loaded
before CL-WEAVE starts the suite, so they are excluded from the behavioral
denominator. Their definitions remain part of the built system, and the
backend data is exercised through the backend logic that consumes it.

Two details of how the measurement is scoped are worth knowing before you read
a result. Instrumentation is switched off again after the library is compiled
and before the suite is, so the figures describe `src/` and not `t/`. And a
recorded total of zero fails the run instead of reporting a vacuous 100%,
which is what you get if the library loaded from stale FASLs or sb-cover was
unavailable.

One flag remains. `--coverage-report-directory <dir>` additionally writes an
sb-cover HTML report to `<dir>`:

```sh
nix develop --command sbcl --script run-tests.lisp --coverage-report-directory /tmp/cl-vcs-kit-coverage
```

When a change genuinely and justifiably lowers coverage, edit the floor in
`run-tests.lisp` with care and leave a comment naming the change that made
previously-covered code unreachable. Do not widen a floor to turn a red run
green: a floor without a recorded reason stops being a ratchet, and an
unexplained drop is exactly the regression this gate exists to catch. This
matches the discipline `cl-process-kit` uses in its own `run-tests.lisp`,
where every floor change carries its reasoning at the constant.

## Source and documentation changes

The package source is under `src/`, tests are under `t/`, and documentation
source is under `docs/src/`. Every documentation page is listed in
`docs/mkdocs.yml` so strict builds catch pages that were added but not placed
in navigation.

The concise package overview stays in [README.md](https://github.com/nerima-lisp/cl-vcs-kit/blob/main/README.md). Detailed
usage and API boundaries belong in the docs site, with links between related
pages kept relative so the same source works locally and when published.

## Verification expectations

For a documentation change, run the strict MkDocs build and verify that the
generated `index.html` is non-empty.

For a source change, run the full `sbcl --script run-tests.lisp`. A narrower
test selection tells you nothing about the coverage gate, since the floor is
measured over the whole suite: a subset run can pass while the gate fails.
Keep external executable requirements explicit when a check cannot run in the
local environment.

See [getting started](../getting-started.md) for the user-facing setup path.
