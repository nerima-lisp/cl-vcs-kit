(defpackage #:vcs-kit/test
  (:use #:cl #:vcs-kit)
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from
   #:cl-weave
   #:expect
   #:expect-not
   #:it
   #:it-property
   #:it-skip-if
   #:gen-list
   #:gen-string
   #:with-continuation-result
   #:with-replaced-function
   #:coverage-support-available-p
   #:run-all)
  (:export #:run-tests))

(in-package #:vcs-kit/test)
