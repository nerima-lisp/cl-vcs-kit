(in-package #:vcs-kit)

(defun %directory-string (directory)
  (namestring (host-kit:ensure-directory-pathname directory)))

(defun %resolve-git-path (repository value)
  (let ((path (pathname value)))
    (if (host-kit:absolute-pathname-p path)
        (namestring path)
        (namestring
         (merge-pathnames path
                          (pathname (repository-directory repository)))))))

(defun make-repository (directory &key
                                   (executable "git")
                                   (default-timeout 30d0)
                                   (environment +unspecified-option+)
                                   git-directory
                                   common-directory
                                   bare-p)
  "Create a repository handle rooted at DIRECTORY.

The handle is passive: no filesystem or Git probe happens until
OPEN-REPOSITORY is called or an operation is run."
  (check-type directory (or string pathname))
  (check-type executable string)
  (check-type default-timeout (or null real))
  (%make-repository
   :directory (%directory-string directory)
   :git-directory git-directory
   :common-directory common-directory
   :bare-p bare-p
   :executable executable
   :default-timeout default-timeout
   :environment (if (eq environment +unspecified-option+)
                    :inherit
                    environment)))

(defun open-repository (directory &key
                                  (executable "git")
                                  (default-timeout 30d0)
                                  (environment +unspecified-option+))
  "Discover the Git repository containing DIRECTORY.

The returned handle contains absolute Git and common-directory paths and the
work-tree root when the repository is non-bare.  Git's own discovery rules
decide whether DIRECTORY belongs to a repository."
  (let* ((candidate (make-repository directory
                                      :executable executable
                                      :default-timeout default-timeout
                                      :environment environment))
         (bare-p (string= "true"
                          (%result-output
                           (run-git/checked
                            candidate "rev-parse"
                            '("--is-bare-repository")))))
         (git-directory
           (%resolve-git-path
            candidate
            (%result-output
             (run-git/checked candidate "rev-parse" '("--git-dir")))))
         (common-directory
           (%resolve-git-path
            candidate
            (%result-output
             (run-git/checked candidate "rev-parse"
                              '("--git-common-dir")))))
         (root (if bare-p
                   (repository-directory candidate)
                   (%result-output
                     (run-git/checked candidate "rev-parse"
                                     '("--show-toplevel"))))))
    (make-repository root
                     :executable executable
                     :default-timeout default-timeout
                     :environment environment
                     :git-directory git-directory
                     :common-directory common-directory
                     :bare-p bare-p)))

(defun git-init (directory &key
                           bare
                           initial-branch
                           template
                           (executable "git")
                           (default-timeout 30d0)
                           (environment +unspecified-option+)
                           (timeout +unspecified-timeout+)
                           (environment-update nil)
                           (input +unspecified-option+)
                           (output :capture)
                           (error-output :capture)
                           (result-type :string)
                           (external-format :utf-8)
                           (max-output-characters +unspecified-option+)
                           cancellation-token
                           (grace-period +unspecified-option+)
                           (drain-timeout-seconds +unspecified-option+)
                           (decoding-error-policy :replace))
  "Initialize a repository in DIRECTORY and return the Git result."
  (let* ((directory (%directory-string directory))
         (repository (make-repository directory
                                      :executable executable
                                      :default-timeout default-timeout
                                      :environment environment))
         (arguments nil))
    (ensure-directories-exist (pathname directory))
    (when bare
      (push "--bare" arguments))
    (when initial-branch
      (push "--initial-branch" arguments)
      (push initial-branch arguments))
    (when template
      (push "--template" arguments)
      (push template arguments))
    (run-git/checked repository "init" (nreverse arguments)
                     :timeout timeout
                     :environment-update environment-update
                     :input input
                     :output output
                     :error-output error-output
                     :result-type result-type
                     :external-format external-format
                     :max-output-characters max-output-characters
                     :cancellation-token cancellation-token
                     :grace-period grace-period
                     :drain-timeout-seconds drain-timeout-seconds
                     :decoding-error-policy decoding-error-policy)))

(defun git-clone (url directory &key
                                 bare
                                 branch
                                 depth
                                 recursive
                                 no-checkout
                                 arguments
                                 (executable "git")
                                 (timeout +unspecified-timeout+)
                                 (environment +unspecified-option+)
                                 (environment-update nil)
                                 (input +unspecified-option+)
                                 (output :capture)
                                 (error-output :capture)
                                 (result-type :string)
                                 (external-format :utf-8)
                                 (max-output-characters +unspecified-option+)
                                 cancellation-token
                                 (grace-period +unspecified-option+)
                                 (drain-timeout-seconds +unspecified-option+)
                                 (decoding-error-policy :replace))
  "Clone URL into DIRECTORY and return the Git result.

ARGUMENTS supplies additional Git clone options that are not represented by
the convenience keywords."
  (check-type url (or string pathname))
  (check-type arguments list)
  (let ((target (%directory-string directory))
        (options nil))
    (when bare
      (push "--bare" options))
    (when branch
      (push "--branch" options)
      (push branch options))
    (when depth
      (push "--depth" options)
      (push (princ-to-string depth) options))
    (when recursive
      (push "--recurse-submodules" options))
    (when no-checkout
      (push "--no-checkout" options))
    (run-git/checked nil "clone"
                     (append (nreverse options)
                             arguments
                             (list url target))
                     :executable executable
                     :timeout timeout
                     :environment environment
                     :environment-update environment-update
                     :directory
                     (namestring
                      (host-kit:parent-directory-pathname
                       (pathname target)))
                     :input input
                     :output output
                     :error-output error-output
                     :result-type result-type
                     :external-format external-format
                     :max-output-characters max-output-characters
                     :cancellation-token cancellation-token
                     :grace-period grace-period
                     :drain-timeout-seconds drain-timeout-seconds
                     :decoding-error-policy decoding-error-policy)))
