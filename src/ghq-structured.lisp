(in-package #:vcs-kit)

;; GHQ prints paths, not portable repository identities. Keep the two pieces
;; separate at the public boundary and derive the identity relative to the
;; deepest configured root. Scan path components directly so this hot path
;; does not construct tokenizer and token objects for every component.

(defun %ghq-normalize-root (root)
  (if (and (> (length root) 1)
           (char= (char root (1- (length root))) #\/))
      (string-right-trim "/" root)
      root))

(defun %ghq-root-prefix-normalized-p (root path)
  (and (>= (length path) (length root))
       (string= root path :end2 (length root))
       (or (string= root "/")
           (= (length path) (length root))
           (char= (char path (length root)) #\/))))

(defun %ghq-root-prefix-p (root path)
  (%ghq-root-prefix-normalized-p (%ghq-normalize-root root) path))

(defun %ghq-relative-path-normalized (path normalized-roots)
  (let ((root (loop with deepest = nil
                    for candidate in normalized-roots
                    when (%ghq-root-prefix-normalized-p candidate path)
                      do (when (or (null deepest)
                                   (> (length candidate) (length deepest)))
                           (setf deepest candidate))
                    finally (return deepest))))
    (if root
        (if (= (length path) (length root))
            ""
            (subseq path (if (string= root "/")
                             (length root)
                             (1+ (length root)))))
        path)))

(defun %ghq-relative-path (path roots)
  (%ghq-relative-path-normalized
   path
   (mapcar #'%ghq-normalize-root roots)))

(defun %ghq-path-components (path)
  (let ((components nil)
        (length (length path))
        (start 0))
    (loop while (< start length)
          do (let ((end (or (position #\/ path :start start)
                            length)))
               (when (> end start)
                 (push (subseq path start end) components))
               (if (= end length)
                   (return)
                   (setf start (1+ end)))))
    (nreverse components)))

(defun %ghq-repository-specification-normalized (path normalized-roots)
  (format nil "~{~A~^/~}"
          (%ghq-path-components
           (%ghq-relative-path-normalized path normalized-roots))))

(defun %ghq-repository-specification (path roots)
  (%ghq-repository-specification-normalized
   path
   (mapcar #'%ghq-normalize-root roots)))

(defun ghq-list-repositories (&key query exact vcs unique bare
                                    (arguments nil)
                                    (root-arguments nil)
                                    (executable "ghq")
                                    (timeout +unspecified-timeout+)
                                    (environment +unspecified-option+)
                                    (environment-update nil)
                                    directory
                                    (input +unspecified-option+)
                                    (output :capture)
                                    (error-output :capture)
                                    (result-type :string)
                                    (external-format :utf-8)
                                    (max-output-characters
                                      +unspecified-option+)
                                    cancellation-token
                                    (grace-period +unspecified-option+)
                                    (drain-timeout-seconds
                                      +unspecified-option+)
                                    (decoding-error-policy :replace))
  "List GHQ repositories as structured identity/path entries.

The returned SPECIFICATION is relative to the deepest matching GHQ root.
ROOT-ARGUMENTS is passed only to the root query; ARGUMENTS is passed only to
the repository query."
  (check-type root-arguments list)
  (let* ((paths
           (ghq-list :query query
                     :exact exact
                     :full-path t
                     :vcs vcs
                     :unique unique
                     :bare bare
                     :arguments arguments
                     :executable executable
                     :timeout timeout
                     :environment environment
                     :environment-update environment-update
                     :directory directory
                     :input input
                     :output output
                     :error-output error-output
                     :result-type result-type
                     :external-format external-format
                     :max-output-characters max-output-characters
                     :cancellation-token cancellation-token
                     :grace-period grace-period
                     :drain-timeout-seconds drain-timeout-seconds
                     :decoding-error-policy decoding-error-policy))
          (roots
            (ghq-roots :all t
                       :arguments root-arguments
                       :executable executable
                       :timeout timeout
                       :environment environment
                       :environment-update environment-update
                       :directory directory
                       :input input
                       :output output
                       :error-output error-output
                       :result-type result-type
                       :external-format external-format
                       :max-output-characters max-output-characters
                       :cancellation-token cancellation-token
                       :grace-period grace-period
                       :drain-timeout-seconds drain-timeout-seconds
                       :decoding-error-policy decoding-error-policy))
          (normalized-roots (mapcar #'%ghq-normalize-root roots)))
    (mapcar (lambda (path)
              (make-ghq-repository-entry
               :specification
               (%ghq-repository-specification-normalized path normalized-roots)
               :path path
               :backend vcs))
            paths)))

(defun ghq-list-root-entries (&key (arguments nil)
                                   (executable "ghq")
                                   (timeout +unspecified-timeout+)
                                   (environment +unspecified-option+)
                                   (environment-update nil)
                                   directory
                                   (input +unspecified-option+)
                                   (output :capture)
                                   (error-output :capture)
                                   (result-type :string)
                                   (external-format :utf-8)
                                   (max-output-characters +unspecified-option+)
                                   cancellation-token
                                   (grace-period +unspecified-option+)
                                   (drain-timeout-seconds
                                     +unspecified-option+)
                                   (decoding-error-policy :replace))
  "List GHQ roots as entries with the first root marked primary."
  (loop for path in (ghq-roots :all t
                               :arguments arguments
                               :executable executable
                               :timeout timeout
                               :environment environment
                               :environment-update environment-update
                               :directory directory
                               :input input
                               :output output
                               :error-output error-output
                               :result-type result-type
                               :external-format external-format
                               :max-output-characters max-output-characters
                               :cancellation-token cancellation-token
                               :grace-period grace-period
                               :drain-timeout-seconds drain-timeout-seconds
                               :decoding-error-policy decoding-error-policy)
        for primary-p = t then nil
        collect (make-ghq-root-entry :path path :primary-p primary-p)))
