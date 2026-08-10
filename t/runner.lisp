(in-package #:vcs-kit/test)

(defun %test-project-root ()
  (asdf:system-source-directory (asdf:find-system "cl-vcs-kit")))

(defun %coverage-source-pathnames ()
  (list (merge-pathnames "src/" (%test-project-root))))

(defun %coverage-excluded-source-pathnames ()
  (let ((root (%test-project-root)))
    (mapcar (lambda (name) (merge-pathnames name root))
            '("src/package.lisp"
              "src/package-exports-core.lisp"
              "src/package-exports-git.lisp"
              "src/package-exports-vcs.lisp"
              "src/package-exports-ghq.lisp"
              "src/vcs-backend-data.lisp"))))

(defun run-tests (&key coverage coverage-report-directory)
  (when (and coverage (not (coverage-support-available-p)))
    (error "Coverage support is unavailable in this Lisp implementation"))
  (when (and coverage-report-directory (not coverage))
    (error "A coverage report directory requires coverage to be enabled"))
  (unless (run-all :reporter :spec
                   :pass-with-no-tests nil
                   :coverage coverage
                   :coverage-report-directory coverage-report-directory
                   :coverage-include-pathnames
                   (when coverage (%coverage-source-pathnames))
                   :coverage-exclude-pathnames
                   (when coverage (%coverage-excluded-source-pathnames)))
    (error "vcs-kit/test suite failed"))
  ;; Coverage is measured here but reported and gated by run-tests.lisp, which
  ;; is the canonical entry point and owns the ratchet floors.
  (format t "~&vcs-kit/test: successful completion~%")
  t)
