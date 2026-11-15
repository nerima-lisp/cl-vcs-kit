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

The search compares integer line tokens. One shared table assigns matching
text the same ID across both inputs, with final-newline state encoded in the
token. Hunks retain the original text and the public API is unchanged.

`bench/performance.lisp` compares limits 512, 256, and 1024 on five 20,000-line
fixtures: 100 evenly spaced replacements in unique text, the same number of
replacements in repetition-heavy text, 100 or 256 replacements in initially
blank text, and entirely different inputs.
The repeated fixture has 18,000 blank lines and 2,000 identical `repeat` lines;
100 of the latter become `changed`. Independent common-subsequence checks
prove that its shortest edit distance is 200. In the all-blank fixtures,
each replacement introduces a sentinel absent from the original. Removing
those sentinels supplies a longest common subsequence, independently proving
shortest distances of 200 and 512. The latter fixture returns `:too-large`
at limit 256 and distance 512 at limits 512 and 1024.
The script checks the default limit's p95 against 100 ms for every
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
benchmark command for the pinned environment.

### Consumer CI measurements

[loom probe CI run 43669681392](https://github.com/nerima-lisp/loom/actions/runs/43669681392)
measured the integer-token implementation inside the loom editor's Lisp image
on x86_64-linux and aarch64-darwin. Both normal and coverage-instrumented
images used the 512-edit limit, two warmups, and 25 measured samples per
workload. The table reports p95 elapsed time in milliseconds:

| Workload | Linux normal | Linux coverage | macOS normal | macOS coverage |
| --- | ---: | ---: | ---: | ---: |
| 100 replacements, unique lines | 19.000 | 20.001 | 31.534 | 26.322 |
| 100 replacements, repeated lines | 14.000 | 14.000 | 16.228 | 16.185 |
| 100 replacements, initially blank | 12.000 | 12.000 | 13.892 | 13.873 |
| 256 replacements, initially blank | 18.000 | 19.000 | 49.491 | 25.541 |
| Entirely different inputs | 24.000 | 23.000 | 32.385 | 28.071 |

All four image/platform combinations passed the 100 ms replacement and
500 ms cutoff budgets. The largest conservative heap upper bound was
9,815,488 bytes, below 32 MiB. The consumer runner did not supply `uptime`;
the logs explicitly mark it uncollected. The kit's own CI runs an Ubuntu Nix
flake check and has no benchmark job.

### High-load local reference measurements

Local measurements used SBCL 2.6.8 on aarch64-darwin with manually registered
dependencies, including `cl-process-kit` 3.4.4, matching the Nix input's version.
The integer-token `bench/performance.lisp` run recorded load averages of
97.81, 88.22, and 85.84, approximately 90. At the 512-edit limit, each row
contains 25 measured samples after two warmups:

| Workload | Median (ms) | p95 (ms) | Maximum (ms) | Heap upper bound (bytes) |
| --- | ---: | ---: | ---: | ---: |
| 100 replacements, unique lines | 60.233 | 178.286 | 282.794 | 9,310,368 |
| 100 replacements, repeated lines | 12.007 | 78.155 | 93.813 | 6,171,808 |
| 100 replacements, initially blank | 7.891 | 122.046 | 151.471 | 5,913,984 |
| 256 replacements, initially blank | 53.243 | 284.686 | 529.750 | 7,307,696 |
| Entirely different inputs | 139.796 | 255.042 | 269.301 | 9,689,792 |

The unique-line and both initially blank workloads exceeded the 100 ms p95
budget, so the script exited nonzero before testing the diagnostic limits.
The cutoff and all heap budgets passed. Maximum allocations, in table order,
were 7,638,000, 5,915,376, 5,751,152, 7,140,496, and 7,938,624 bytes;
measured GC CPU time was zero. The standard runner did not collect GC counts.

A separate diagnostic made one call per initially blank workload on the same
integer-token implementation, at load averages 111.86, 97.79, and 90.37.
For 100 and 256 replacements, wall/CPU times were 9.056/7.649 ms and
14.930/14.142 ms; allocations were 5,688,304 and 6,567,952 bytes.
Both calls recorded zero collections and zero GC CPU time. Native collection
counts agreed with the synchronous GC log and epoch state; idle and forced-GC
controls validated the counter. These two diagnostic calls do not establish
the cause of the local timing variation.

The earlier development string-comparison implementation also ran locally
with the same 25-sample protocol and load averages of 89.06, 89.93, and 90.23:

| Initially blank workload | Median (ms) | p95 (ms) | Maximum (ms) |
| --- | ---: | ---: | ---: |
| 100 replacements | 5.541 | 23.436 | 61.352 |
| 256 replacements | 28.495 | 146.230 | 213.558 |

The local failures remain reference observations under high load; the
consumer CI measurements above provide the release performance evidence.
Separate runs do not establish a speedup. The 512-edit default supports all
replacement fixtures while limiting the retained search history.
Active diagonal bands reduce that history's storage, but its growth remains
quadratic in the distance bound; the [API reference](../reference/api.md#in-memory-line-diffs)
describes the bound and the input-storage costs.

The [API reference](../reference/api.md#in-memory-line-diffs) describes the
result accessors and line-number conventions.

## Dependencies and execution

The minimum supported `cl-process-kit` version rises from 3.4.1 to 3.4.4, and
the Nix input uses its v3.4.4 tag. Commit `f9476068`, unreleased since v0.2.1, forwards
`:poll-interval` from `run-vcs` through shared execution options to
`cl-process-kit`, including its validation.
