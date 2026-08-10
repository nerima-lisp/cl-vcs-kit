# GHQ

GHQ manages repositories under configured roots. `cl-vcs-kit` exposes both
direct GHQ command wrappers and typed listing helpers.

## Direct operations

`ghq-get` and `ghq-clone` accept a repository specification plus GHQ options
such as `:update`, `:ssh`, `:shallow`, `:branch`, and `:no-recursive`. The
command wrappers preserve the same process execution controls as VCS
operations.

```lisp
(vcs-kit:ghq-get "github.com/nerima-lisp/cl-vcs-kit"
                 :update t
                 :timeout 30d0)

(vcs-kit:ghq-list :query "nerima-lisp" :full-path t)
```

`ghq-path` resolves a repository specification to its first full path, while
`ghq-roots` and `ghq-root` inspect configured roots. Management wrappers also
include `ghq-rm`, `ghq-create`, `ghq-migrate`, and `ghq-help`.

## Typed listings

Use `ghq-list-repositories` when an application needs a record rather than
GHQ's text output:

```lisp
(dolist (entry (vcs-kit:ghq-list-repositories :query "cl-"))
  (format t "~A => ~A (~A)~%"
          (vcs-kit:ghq-repository-entry-specification entry)
          (vcs-kit:ghq-repository-entry-path entry)
          (vcs-kit:ghq-repository-entry-backend entry)))
```

`ghq-list-root-entries` returns typed root records. These helpers do not
replace GHQ's configuration or discovery rules; they expose the command
results as Common Lisp data.

GHQ is an external executable. If it is absent from the process path, GHQ
operations fail at execution time while the Git and backend-neutral APIs
remain independently usable.

See [core concepts](core-concepts.md) for the relationship between a GHQ
path and a VCS repository handle.
