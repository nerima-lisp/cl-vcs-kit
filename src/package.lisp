(defpackage #:vcs-kit
  (:use #:cl)
  (:import-from #:process-kit
                #:process-result
                #:process-result-program
                #:process-result-arguments
                #:process-result-pid
                #:process-result-status
                #:process-result-duration-seconds
                #:process-result-exit-code
                #:process-result-stdout
                #:process-result-stderr
                #:process-result-timed-out-p
                #:process-result-cancelled-p
                #:process-result-signal
                #:process-result-stdout-truncated-p
                #:process-result-stderr-truncated-p
                #:process-success-p)
)
