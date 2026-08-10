# Asynchronous tasks

Asynchronous commands return process-kit tasks. The task keeps the eventual
result, condition, event history, callback errors, and dropped-event count
available to the caller.

## Start and await

Use `run-vcs-async` for a raw command and `vcs-version-async` for a backend
version query:

```lisp
(let* ((task (vcs-kit:run-vcs-async repository
                                    "status"
                                    '("--porcelain")
                                    :timeout 5d0))
       (result-and-state
         (multiple-value-list
          (vcs-kit:await-vcs-task task :timeout 5d0))))
  result-and-state)
```

`await-vcs-task` returns two values: the process result and whether the task
completed before the wait timeout. A worker condition is re-signaled by the
underlying process-kit await operation.

The task accessors are `vcs-task-state`, `vcs-task-result`,
`vcs-task-condition`, and `vcs-task-events`.

## Cancellation

`cancel-vcs-task` requests cancellation on a running task. For operations that
need to share cancellation across multiple commands, create a
`vcs-cancellation-token` and pass it as `:cancellation-token`.

```lisp
(let ((token (vcs-kit:make-vcs-cancellation-token)))
  (vcs-kit:cancel-vcs token)
  (vcs-kit:vcs-cancellation-requested-p token))
```

## Event cursors

`next-vcs-event` reads the next event from a task with a cursor. Its result
preserves the process-kit event protocol, including `:event`, `:gap`,
`:terminal`, and `:timeout` outcomes. A callback that cannot be delivered is
recorded in `vcs-task-callback-errors`; events discarded because the consumer
falls behind are counted by `vcs-task-dropped-event-count`.

```lisp
(let* ((task (vcs-kit:run-vcs-async repository "status" '()))
       (step (vcs-kit:next-vcs-event task :timeout 1d0)))
  (case (process-kit:process-event-step-status step)
    (:event (process-kit:process-event-step-event step))
    (:terminal (vcs-kit:vcs-task-result task))
    (:timeout nil)))
```

For a task that may outlive the current request, inspect the task state after
the event loop and decide whether to await, cancel, or surface its condition.
