# Structured observations

Structured readers turn common Git output into typed objects. Use them when
application code needs stable fields such as a path, branch name, object ID, or
line-count delta instead of parsing command output.

## Status and diffs

`vcs-status-structured` returns a `vcs-status-snapshot` and its status entries.
It supports controls for untracked files, ignored files, stash display,
renames, extra arguments, and execution options.

```lisp
(let ((snapshot (vcs-kit:vcs-status-structured repository)))
  (mapcar #'vcs-kit:vcs-status-entry-path
          (vcs-kit:vcs-status-snapshot-entries snapshot)))
```

`vcs-diff-entries` combines Git name-status and numstat information into
`vcs-diff-entry` objects:

```lisp
(dolist (entry (vcs-kit:vcs-diff-entries repository))
  (format t "~A +~D -~D~%"
          (vcs-kit:vcs-diff-entry-path entry)
          (vcs-kit:vcs-diff-entry-additions entry)
          (vcs-kit:vcs-diff-entry-deletions entry)))
```

The parser functions `parse-status`, `parse-name-status`, and `parse-numstat`
are available when an application needs to parse compatible output directly.

## References and repository state

For Git repositories, these readers return typed objects:

- `vcs-list-remotes` returns `vcs-remote` objects;
- `vcs-list-branches` returns `vcs-branch` objects;
- `vcs-list-tags` returns `vcs-tag` objects;
- `vcs-list-commits` returns `vcs-commit` objects;
- `vcs-list-stashes` returns `vcs-stash-entry` objects;
- `vcs-list-conflicts` returns `vcs-conflict` objects;
- `vcs-list-worktrees` returns `vcs-worktree` objects;
- `vcs-list-submodules` returns `vcs-submodule` objects.

Each reader accepts backend command `:arguments` and process
`:execution-options` where applicable. The result types and accessors are
exported from the `vcs-kit` package.

## Capability boundary

Structured support is distinct from normalized command support. Check
`vcs-backend-supports-structured-operation-p` before selecting a structured
operation for a dynamically chosen backend. The current built-in structured
readers are Git-defined; they do not silently reinterpret another backend's
output as Git data.

See [compatibility](../reference/compatibility.md) for the built-in
structured-operation map.
