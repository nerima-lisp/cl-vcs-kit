# v0.3.0 release notes (draft)

## In-memory line diffs

`compute-line-diff` compares two strings and returns typed hunks, without
reading files or launching a process. Hunks record old and new ranges; lines
record their kind, text, and final-newline state. Optional paths label the
result. `compute-line-diff` includes three lines of context by default;
`format-unified-diff` renders those hunks with headers and
missing-final-newline markers. Path labels containing LF or CR signal a
`type-error` when computing or formatting a diff.

The search has a default edit-distance limit of 512 insertions plus deletions.
A replacement normally counts as two edits. Above the limit, the result has
status `:too-large`, no hunks, and no edit distance. This limit is deterministic
and does not depend on a wall-clock deadline. Callers must check the status
before formatting the result.

`bench/performance.lisp` compares limits 256, 512, and 1024 on three 20,000-line
fixtures: 100 evenly spaced replacements in unique text, the same number of
replacements in repetition-heavy text, and entirely different inputs.
The repeated fixture has 18,000 blank lines and 2,000 identical `repeat` lines;
100 of the latter become `changed`. Independent common-subsequence checks
prove that its shortest edit distance is 200.
The script checks the default limit's p95 against 100 ms for either
replacement case, 500 ms for
cutoff, and 32 MiB for the conservative peak heap bound. The bound includes
both input strings and all heap allocation during one call; it excludes the
already-loaded Lisp image. It is an upper bound, not a measurement of process
RSS. Each workload has two excluded warmups and 25 measured samples, with
rotating workload order and a full collection before each sample. Every
result is checked for the expected edit count or cutoff status. The p95 uses
the nearest rank, the 24th sorted observation out of 25; median, maximum,
allocation, and GC CPU time are also reported. Load information is captured
with an actual `uptime` invocation in the benchmark entry point.

The [development guide](development.md#line-diff-benchmark) gives the
benchmark command for the pinned environment. The local measurements below
used SBCL 2.6.8 on aarch64-darwin with manually registered dependencies,
including `cl-process-kit` 3.4.4, matching the Nix input's version.

The table below records only the local aarch64-darwin measurement. That
`bench/performance.lisp` run used a fresh
Lisp process and workspace FASLs compiled into an isolated directory.
The entry point captured load averages of 80.93, 149.77, and 122.15. At the
512-edit limit it produced:

| Workload | Median (ms) | p95 (ms) | Maximum (ms) | Heap upper bound (bytes) |
| --- | ---: | ---: | ---: | ---: |
| 100 replacements, unique lines | 7.360 | 11.688 | 18.450 | 7,673,600 |
| 100 replacements, repeated lines | 7.398 | 10.003 | 21.010 | 4,512,768 |
| Entirely different inputs | 12.139 | 17.730 | 22.199 | 8,170,400 |

The p95 and heap budgets passed. Maximum allocations were 6,001,232,
4,256,336, and 6,419,232 bytes respectively; measured GC CPU time was zero.
The standard runner did not collect GC counts. The 512-edit default supports
the 200-edit replacement fixtures while limiting the retained search history.
Active diagonal bands reduce that history's storage, but its growth remains
quadratic in the distance bound; the [API reference](../reference/api.md#in-memory-line-diffs)
describes the bound and the input-storage costs.

These measurements do not establish cross-platform performance. macOS CI
has not run because its runner update is pending; the local Darwin
measurement is not a macOS CI result.

The [API reference](../reference/api.md#in-memory-line-diffs) describes the
result accessors and line-number conventions.

## Dependencies and execution

The minimum supported `cl-process-kit` version rises from 3.4.1 to 3.4.4, and
the Nix input uses its v3.4.4 tag. Commit `f9476068`, unreleased since v0.2.1, forwards
`:poll-interval` from `run-vcs` through shared execution options to
`cl-process-kit`, including its validation.
