;;;; Canonical test entry point. `nix run .#test`, `checks.default`, and a
;;;; contributor typing `sbcl --script run-tests.lisp` all run this same file,
;;;; so whatever gates here gates everywhere.
;;;;
;;;; Coverage is a RATCHET, not an opt-in report. The library is always
;;;; compiled under sb-cover instrumentation and this script exits non-zero
;;;; when expression or branch coverage over src/ falls below the floors
;;;; below. A number that is only printed does not stop a regression; a number
;;;; that fails the build does. Instrumentation costs nothing measurable here
;;;; because the suite is dominated by subprocess round-trips rather than by
;;;; Lisp execution.
;;;;
;;;; The floors are the measurement at the time they were last raised, minus a
;;;; small margin. Lowering one is a deliberate act: edit the value and say in
;;;; a comment which change made previously-covered code unreachable. An
;;;; unexplained drop is the regression this gate exists to catch.

(require :asdf)
(asdf:load-system "cl-host-kit")

(defparameter +minimum-expression-coverage+ 93.5
  "Percentage floor for src/ expression coverage. Current measured ratchet is 93.5% after excluding declaration/data-only forms.")

(defparameter +minimum-branch-coverage+ 91.2
  "Percentage floor for src/ branch coverage. Current measured ratchet is 91.2% (469/514, rounded).")

(defun call-exported-function (package name &rest arguments)
  (let ((symbol (find-symbol name package)))
    (unless (and symbol (fboundp symbol))
      (error "Missing exported function ~A:~A" package name))
    (apply (symbol-function symbol) arguments)))

(defun script-directory ()
  (host-kit:pathname-directory-pathname
   (host-kit:ensure-pathname (or *load-pathname* *default-pathname-defaults*))))

(defun configure-local-source-registry (root)
  (asdf:initialize-source-registry
   `(:source-registry (:tree ,root) :inherit-configuration)))

(defun coverage-report-directory ()
  (let ((arguments (host-kit:command-line-arguments)))
    (loop for remaining on arguments
          when (string= (first remaining) "--coverage-report-directory")
            do (return
                 (host-kit:ensure-directory-pathname
                  (or (second remaining)
                      (error "--coverage-report-directory requires a value")))))))

(defun coverage-source-pathnames (root)
  (list (merge-pathnames "src/" root)))

(defun coverage-excluded-source-pathnames (root)
  "Exclude declaration/data-only files from the behavioral coverage denominator.

The package and export forms are loaded while the instrumented system is
compiled, before CL-WEAVE starts the test run.  They are still part of the
real system and are loaded by every test; counting their load-time forms as
runtime behavior would make a source-file split lower the ratchet without
changing the exercised library.  The backend catalog is likewise static data;
its values are consumed by the tested backend logic, but the top-level
DEFPARAMETER forms themselves run before the test suite starts."
  (mapcar (lambda (name) (merge-pathnames name root))
          '("src/package.lisp"
            "src/package-exports-core.lisp"
            "src/package-exports-git.lisp"
            "src/package-exports-vcs.lisp"
            "src/package-exports-ghq.lisp"
            "src/vcs-backend-data.lisp"
            "src/types.lisp")))

(defun coverage-policy-symbol ()
  (or (find-symbol "STORE-COVERAGE-DATA" "SB-COVER")
      (error "SB-COVER compiler policy is not available")))

(defun set-coverage-instrumentation (level)
  "Turn sb-cover instrumentation on or off for subsequent COMPILATION.
Instrumentation is a compile-time property, so this has no effect on code that
is already compiled -- the caller must force a recompile for it to take."
  (proclaim `(optimize (,(coverage-policy-symbol) ,level))))

(defun coverage-percentage (covered total)
  (if (zerop total)
      100.0
      (* 100.0 (/ covered total))))

(defun check-coverage-floor (kind actual minimum)
  (when (< actual minimum)
    (format *error-output*
            "~&Coverage regression: ~A ~,1F% is below the ~,1F% floor.~%"
            kind
            actual
            minimum)
    (host-kit:quit 1)))

(defun enforce-coverage-floors (root)
  (let* ((source-pathnames (coverage-source-pathnames root))
         (excluded-pathnames (coverage-excluded-source-pathnames root))
         (statistics (call-exported-function
                      :cl-weave "COVERAGE-STATISTICS"
                      :include-pathnames source-pathnames
                      :exclude-pathnames excluded-pathnames))
         (expression-covered (getf statistics :expression-covered))
         (expression-total (getf statistics :expression-total))
         (branch-covered (getf statistics :branch-covered))
         (branch-total (getf statistics :branch-total))
         (expression-percentage
           (coverage-percentage expression-covered expression-total))
         (branch-percentage
           (coverage-percentage branch-covered branch-total)))
    ;; An empty or stale pathname set means the filter itself was wrong. Do
    ;; not let the coverage reporter turn that into a vacuous success.
    (when (or (null source-pathnames)
              (some (lambda (pathname)
                      (not (probe-file pathname)))
                    source-pathnames))
      (format *error-output*
              "~&Coverage source pathnames are empty or missing.~%")
      (host-kit:quit 1))
    ;; A zero total means instrumentation never took: the library loaded from
    ;; stale FASLs, or the include-pathname filter matched nothing because the
    ;; root resolved differently than expected. Every percentage would then be
    ;; a vacuous 100%, so refuse rather than pass. SB-COVER being absent cannot
    ;; reach here -- REQUIRE-COVERAGE-SUPPORT below fails first.
    (when (or (zerop expression-total) (zerop branch-total))
      (format *error-output*
              "~&No coverage was recorded for src/; instrumentation did not take.~%")
      (host-kit:quit 1))
    (format t
            "~&~%Coverage (src/):~%  expression ~,1F% (~D/~D)~%  branch     ~,1F% (~D/~D)~%"
            expression-percentage
            expression-covered
            expression-total
            branch-percentage
            branch-covered
            branch-total)
    (check-coverage-floor :expression
                          expression-percentage
                          +minimum-expression-coverage+)
    (check-coverage-floor :branch
                          branch-percentage
                          +minimum-branch-coverage+)))

(defun redirect-this-systems-fasls (root)
  "Send FASLs compiled from ROOT to a scratch directory instead of the shared cache.
Instrumentation is a property of the compiled code, so without this every run
leaves instrumented FASLs in ~/.cache/common-lisp and the next plain
`(asdf:load-system \"cl-vcs-kit\")' in any REPL silently loads an instrumented
library. Only ROOT is redirected; :INHERIT-CONFIGURATION keeps the dependency
FASLs where the surrounding environment put them, which is what lets the Nix
build go on reusing its prebuilt store paths."
  (asdf:initialize-output-translations
   `(:output-translations
     (,root (,(merge-pathnames "cl-vcs-kit-coverage-fasl/"
                               (host-kit:temporary-directory))
             :implementation))
     :inherit-configuration)))

(defun set-per-test-timeout (milliseconds)
  "Bound every test's run time to MILLISECONDS.
CL-WEAVE:*DEFAULT-TIMEOUT-MS* is NIL by default, so without this a deadlocked
test hangs until the flake's whole-suite timeout kills the process, which names
no test. A per-test bound fails the one test that hung and says which."
  (let ((symbol (find-symbol "*DEFAULT-TIMEOUT-MS*" :cl-weave)))
    (unless symbol (error "CL-WEAVE timeout variable is unavailable."))
    (setf (symbol-value symbol) milliseconds)))

(let ((root (script-directory)))
  (configure-local-source-registry root)
  (asdf:load-system "cl-weave")
  (call-exported-function :cl-weave "REQUIRE-COVERAGE-SUPPORT")
  (set-per-test-timeout 30000)
  (redirect-this-systems-fasls root)
  ;; Instrument, force a recompile of this library alone so the instrumentation
  ;; actually applies, then restore the default before the suite is compiled so
  ;; the report measures src/ rather than t/.
  (set-coverage-instrumentation 3)
  (asdf:load-system "cl-vcs-kit" :force t)
  (set-coverage-instrumentation 0)
  (asdf:load-system "cl-vcs-kit/test")
  (call-exported-function :vcs-kit/test
                    "RUN-TESTS"
                    :coverage t
                    :coverage-report-directory (coverage-report-directory))
  (enforce-coverage-floors root)
  (host-kit:quit 0))
