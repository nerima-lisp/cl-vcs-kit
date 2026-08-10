(in-package #:vcs-kit)

(defun make-vcs-repository (directory &key
                              (backend :git)
                              executable
                              (default-timeout 30d0)
                              (environment +unspecified-option+))
  "Create a backend-neutral repository handle without probing the directory."
  (check-type default-timeout (or null real))
  (let* ((backend (find-vcs-backend backend))
         (directory (%directory-string directory))
         (environment
           (if (eq environment +unspecified-option+)
               :inherit
               environment)))
    (check-type executable (or null string))
    (check-type environment (or null list (member :inherit)))
    (%make-vcs-repository
     :directory directory
     :backend backend
     :executable (or executable (vcs-backend-executable backend))
     :default-timeout default-timeout
     :environment environment)))

(defun %vcs-backend-executable-works-p (backend directory executable
                                         timeout environment)
  "Return true when BACKEND's executable can run in DIRECTORY.

The probe is deliberately a version-like command with an empty stdin and
discarded output.  It validates the executable and working directory without
making detection depend on a backend-specific repository mutation."
  (handler-case
      (let ((result
              (run-vcs nil
                       (or (vcs-operation-command backend :version)
                           "--version")
                       nil
                       :executable (or executable
                                       (vcs-backend-executable backend))
                       :directory directory
                       :timeout timeout
                       :input ""
                       :environment environment
                       :output :capture
                       :error-output :capture
                       :result-type :string)))
        (process-success-p result))
    (vcs-error () nil)))

(defun %vcs-backend-marker-present-p (backend directory)
  "Return true when DIRECTORY has BACKEND's metadata marker.

In addition to the usual working-tree marker, recognize Git's bare
repository layout.  A bare repository has no .git directory, so marker-only
detection would otherwise miss a valid repository with HEAD, config,
objects, and refs at its root."
  (let ((directory (host-kit:ensure-directory-pathname directory)))
    (or (some (lambda (marker)
                (probe-file (merge-pathnames marker directory)))
              (vcs-backend-markers backend))
        (and (eql (vcs-backend-name backend) :git)
             (every (lambda (name)
                     (probe-file (merge-pathnames name directory)))
                    '("HEAD" "config" "objects/" "refs/"))))))

(defun detect-vcs-backend (directory &key
                                     candidates
                                     (validate-executable nil)
                                     (executable +unspecified-option+)
                                     (timeout +unspecified-timeout+)
                                     (environment +unspecified-option+))
  "Detect a backend from repository metadata in DIRECTORY, or return NIL.

When VALIDATE-EXECUTABLE is true, a metadata marker is accepted only after
the selected executable successfully runs its version command in DIRECTORY.
EXECUTABLE, TIMEOUT, and ENVIRONMENT control that optional probe; their
unspecified values use the backend default, the library default timeout, and
the inherited environment respectively."
  (unless (eq executable +unspecified-option+)
    (check-type executable (or null string)))
  (unless (eq timeout +unspecified-timeout+)
    (check-type timeout (or null real)))
  (unless (eq environment +unspecified-option+)
    (check-type environment (or null list (member :inherit))))
  (let* ((directory (%directory-string directory))
         (candidates (or candidates (available-vcs-backends)))
         (probe-timeout (if (eq timeout +unspecified-timeout+)
                            +default-vcs-timeout+
                            timeout))
         (probe-environment (if (eq environment +unspecified-option+)
                                :inherit
                                environment))
         (probe-executable (unless (eq executable +unspecified-option+)
                             executable)))
    (some
     (lambda (candidate)
       (let ((backend (find-vcs-backend candidate)))
         (when (and
                (%vcs-backend-marker-present-p backend directory)
                (or (not validate-executable)
                    (%vcs-backend-executable-works-p
                     backend directory probe-executable probe-timeout
                     probe-environment)))
           backend)))
     candidates)))

(defun open-vcs-repository (directory &key
                              backend
                              executable
                              (default-timeout 30d0)
                              (environment +unspecified-option+)
                              (validate-executable nil))
  "Open DIRECTORY using BACKEND, or detect its backend from metadata."
  (let* ((directory (%directory-string directory))
         (explicit-backend (and backend (find-vcs-backend backend)))
         (backend (or explicit-backend
                      (detect-vcs-backend
                       directory
                       :validate-executable validate-executable
                       :executable executable
                       :timeout default-timeout
                       :environment environment))))
    (unless backend
      (error 'vcs-backend-detection-error
             :backend nil
             :directory directory))
    (when (and validate-executable
               explicit-backend
               (not (%vcs-backend-executable-works-p
                     explicit-backend directory executable default-timeout
                     (if (eq environment +unspecified-option+)
                         :inherit
                         environment))))
      (error 'vcs-backend-detection-error
             :backend explicit-backend
             :directory directory))
    (make-vcs-repository directory
                         :backend backend
                         :executable executable
                         :default-timeout default-timeout
                         :environment environment)))

(defun %vcs-parent-directory-string (path)
  (let* ((pathname (host-kit:ensure-directory-pathname (pathname path)))
         (parent (host-kit:ensure-directory-pathname
                  (host-kit:parent-directory-pathname pathname)))
         (pathname-string (namestring pathname))
         (parent-string (namestring parent)))
    (unless (string= pathname-string parent-string)
      parent-string)))

(defun discover-vcs-repository (directory &key
                                  backend
                                  executable
                                  (default-timeout 30d0)
                                  (environment +unspecified-option+)
                                  candidates
                                  (validate-executable nil))
  "Find a repository at DIRECTORY or one of its ancestor directories.

When BACKEND is supplied, only DIRECTORY is used and no metadata probe is
performed.  With automatic detection, the returned repository directory is
the ancestor containing the backend marker."
  (let ((start (%directory-string directory)))
    (if backend
        (open-vcs-repository start
                             :backend backend
                             :executable executable
                             :default-timeout default-timeout
                             :environment environment
                             :validate-executable validate-executable)
        (loop
          for current = start then parent
          for parent = (%vcs-parent-directory-string current)
          for detected = (detect-vcs-backend current
                                             :candidates candidates
                                             :validate-executable
                                             validate-executable
                                             :executable executable
                                             :timeout default-timeout
                                             :environment environment)
          when detected
            do (return
                 (make-vcs-repository current
                                      :backend detected
                                      :executable executable
                                      :default-timeout default-timeout
                                      :environment environment))
          when (null parent)
            do (error 'vcs-backend-detection-error
                      :backend nil
                      :directory start)))))

(defun %vcs-effective-timeout (repository timeout)
  (if (eq timeout +unspecified-timeout+)
      (if repository
          (vcs-repository-default-timeout repository)
          +default-vcs-timeout+)
      timeout))

(defun %vcs-effective-environment (repository environment)
  (if (eq environment +unspecified-option+)
      (if repository
          (vcs-repository-environment repository)
          :inherit)
      environment))

(defun %vcs-effective-executable (repository executable)
  (or (unless (eq executable +unspecified-option+)
        executable)
      (and repository (vcs-repository-executable repository))
      "git"))

(defun %signal-vcs-failure (repository command arguments result)
  (cond
    ((process-result-timed-out-p result)
     (error 'vcs-command-timeout-error
            :repository repository
            :command command
            :arguments arguments
            :result result))
    ((process-result-cancelled-p result)
     (error 'vcs-command-cancelled-error
            :repository repository
            :command command
            :arguments arguments
            :result result))
    ((not (process-success-p result))
     (error 'vcs-command-exit-error
            :repository repository
            :command command
            :arguments arguments
            :result result
            :exit-code (process-result-exit-code result)))))
