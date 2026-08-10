(in-package #:vcs-kit)

(defun await-vcs-task (task &key (timeout +unspecified-timeout+))
  "Wait for a PROCESS-KIT task and return its two completion values.

The first value is the direct PROCESS-RESULT and the second says whether the
task completed before TIMEOUT.  Worker conditions are re-signaled by
PROCESS-KIT:AWAIT-PROCESS."
  (if (eq timeout +unspecified-timeout+)
      (process-kit:await-process task)
      (process-kit:await-process task :timeout timeout)))

(defun cancel-vcs-task (task)
  "Request cancellation of TASK and return the same process task."
  (process-kit:cancel-process task))

(defun vcs-task-state (task)
  "Return PROCESS-KIT's current state for TASK."
  (process-kit:task-state task))

(defun vcs-task-result (task)
  "Return the direct PROCESS-RESULT retained by TASK, when available."
  (process-kit:task-result task))

(defun vcs-task-condition (task)
  "Return the worker condition retained by TASK, when available."
  (process-kit:task-condition task))

(defun vcs-task-events (task)
  "Return PROCESS-KIT's retained event history for TASK."
  (process-kit:process-events task))

(defun next-vcs-event (task &key (cursor +unspecified-option+)
                                   (timeout +unspecified-timeout+))
  "Read the next event step from TASK.

The returned value is PROCESS-KIT's process-event-step, preserving its
`:EVENT`, `:GAP`, `:TERMINAL`, and `:TIMEOUT` statuses."
  (let ((options nil))
    (unless (eq cursor +unspecified-option+)
      (setf options (list* :cursor cursor options)))
    (unless (eq timeout +unspecified-timeout+)
      (setf options (list* :timeout timeout options)))
    (apply #'process-kit:next-process-event task options)))

(defun vcs-task-callback-errors (task)
  "Return callback errors retained by PROCESS-KIT for TASK."
  (process-kit:callback-errors task))

(defun vcs-task-dropped-event-count (task)
  "Return the number of events dropped from TASK's callback stream."
  (process-kit:dropped-event-count task))
