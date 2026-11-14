# v0.3.0 release notes (draft)

## In-memory line diffs

`compute-line-diff` compares two strings and returns typed hunks, without
reading files or launching a process. Hunks record old and new ranges; lines
record their kind, text, and final-newline state. Optional paths label the
result. `compute-line-diff` includes three lines of context by default;
`format-unified-diff` renders those hunks with headers and
missing-final-newline markers.

The search has a default edit-distance limit of 512 insertions plus deletions.
A replacement normally counts as two edits. Above the limit, the result has
status `:too-large`, no hunks, and no edit distance. This limit is deterministic
and does not depend on a wall-clock deadline. Callers must check the status
before formatting the result.

`bench/performance.lisp` compares limits 256, 512, and 1024 on two 20,000-line
fixtures: 100 evenly spaced line replacements and entirely different inputs.
It checks the default limit's p95 against 100 ms for replacements, 500 ms for
cutoff, and 32 MiB for the conservative peak heap bound. The bound includes
both input strings and all heap allocation during one call; it excludes the
already-loaded Lisp image. It is an upper bound, not a measurement of process
RSS. Each workload has two excluded warmups and 25 measured samples, with
alternating workload order and a full collection before each sample. Every
result is checked for the expected edit count or cutoff status. The p95 uses
the nearest rank, the 24th sorted observation out of 25; median, maximum,
allocation, and GC CPU time are also reported. Load information is captured
with `uptime` alongside local measurements.

The [development guide](development.md#line-diff-benchmark) gives the
benchmark command for the pinned environment. The local measurements below
used SBCL 2.6.8 on aarch64-darwin with manually registered dependencies,
substituting `cl-process-kit` 3.4.4 for the pinned input.

The final `bench/performance.lisp` run produced these results at the 512-edit
limit:

| Workload | Median (ms) | p95 (ms) | Maximum (ms) | Heap upper bound (bytes) |
| --- | ---: | ---: | ---: | ---: |
| 100 replacements | 8.626 | 67.525 | 137.779 | 10,645,632 |
| Entirely different inputs | 15.014 | 102.759 | 107.345 | 13,006,752 |

Both p95 budgets and the heap budget passed. The measured calls allocated at
most 8,973,264 and 11,255,584 bytes respectively; GC CPU time was zero for
both workloads. GC counts are unavailable because asynchronous SBCL hook
delivery cannot assign collections to individual calls reliably. Captured
load averages are retained with the benchmark log.

The 1024-edit candidate's cutoff p95 was 233.671 ms and its heap upper bound
was 29,770,400 bytes. The 512-edit default leaves room above the 200-edit
replacement fixture while using a smaller search and memory bound. An earlier
15-sample run failed a maximum-time check at 142.087 ms; that failure is
retained in the validation record. Release validation uses 25 samples and the
same p95 gate on Linux and aarch64-darwin: replacement time at most 100 ms,
cutoff time at most 500 ms, and the conservative peak heap bound at most
32 MiB. The local result does not establish the target CI results.

The [API reference](../reference/api.md#in-memory-line-diffs) describes the
result accessors and line-number conventions.

## Previously unreleased change

Commit `f9476068` forwards `:poll-interval` from `run-vcs` through shared
execution options to `cl-process-kit`, including its validation. It also pins
the Nix `cl-process-kit` input to commit
`76ca1348286c63817d49d711a13c40f1e3109403`. This commit was on main after
v0.2.1 and is included in this release.
