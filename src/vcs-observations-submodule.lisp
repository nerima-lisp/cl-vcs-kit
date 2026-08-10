;;;; Structured backend-neutral observations: submodules.

(in-package #:vcs-kit)

(defun %vcs-submodule-line (line)
  (let* ((marker (subseq line 0 1))
         (rest (string-left-trim '(#\Space #\Tab) (subseq line 1)))
         (separator (position-if (lambda (character)
                                   (member character '(#\Space #\Tab)))
                                 rest)))
    (unless separator
      (error "Malformed Git submodule output: ~S." line))
    (let* ((head (subseq rest 0 separator))
           (path-and-description
             (string-left-trim '(#\Space #\Tab)
                               (subseq rest separator)))
           (description-start (search " (" path-and-description :from-end t))
           (path (if (and description-start
                          (char= (char path-and-description
                                       (1- (length path-and-description)))
                                 #\)))
                     (subseq path-and-description 0 description-start)
                     path-and-description)))
      (%make-vcs-submodule
       :path path
       :name nil
       :url nil
       :head head
       :index nil
       :worktree-status marker))))

(defun %vcs-submodule-configuration (line)
  "Parse one Git submodule path configuration line."
  (let ((separator (position-if #'%whitespace-character-p line)))
    (when separator
      (let* ((key (subseq line 0 separator))
             (path (string-left-trim '(#\Space #\Tab)
                                     (subseq line (1+ separator))))
             (prefix "submodule.")
             (suffix ".path"))
        (when (and (%starts-with-p prefix key)
                   (%ends-with-p suffix key)
                   (> (length key)
                      (+ (length prefix) (length suffix))))
          (cons path
                (subseq key
                        (length prefix)
                        (- (length key)
                           (length suffix)))))))))

(defun %vcs-submodule-configurations (repository execution-options)
  "Return ((PATH . NAME) ...) from Git submodule configuration."
  (let ((lines
          (or (%vcs-optional-config-lines
               repository
               (list "--file" ".gitmodules"
                     "--get-regexp" "^submodule\\..*\\.path$")
               execution-options)
              (%vcs-optional-config-lines
               repository
               (list "--get-regexp" "^submodule\\..*\\.path$")
               execution-options))))
    (loop for line in lines
          for configuration = (%vcs-submodule-configuration line)
          when configuration
            collect configuration)))

(defun %vcs-submodule-url (repository name execution-options)
  (let ((key (format nil "submodule.~A.url" name)))
    (or (%vcs-config-value repository
                           (list "--file" ".gitmodules" "--get" key)
                           execution-options)
        (%vcs-config-value repository (list "--get" key)
                           execution-options))))

(defun %vcs-submodule-index (repository path execution-options)
  (let* ((lines (%vcs-optional-command-lines
                 repository "ls-files" (list "--stage" "--" path)
                 execution-options))
         (fields (and lines (%split-whitespace-fields (first lines)))))
    (second fields)))

(defun vcs-list-submodules (repository &key
                                         (arguments nil)
                                         (execution-options nil))
  "Return Git submodules from the recursive status format."
  (%vcs-git-repository repository :submodules)
  (check-type arguments list)
  (let ((result (%vcs-structured-run
                repository "submodule"
                (append (list "status" "--recursive") arguments)
                execution-options)))
    (let ((configurations (%vcs-submodule-configurations repository
                                                          execution-options)))
      (loop for line in (%split-line-records (%vcs-structured-output result))
            unless (string= line "")
              collect
                (let* ((submodule (%vcs-submodule-line line))
                       (configuration
                         (find (vcs-submodule-path submodule) configurations
                               :key #'car :test #'string=))
                       (name (cdr configuration)))
                  (setf (vcs-submodule-name submodule) name
                        (vcs-submodule-url submodule)
                        (and name (%vcs-submodule-url repository name
                                                       execution-options))
                        (vcs-submodule-index submodule)
                        (%vcs-submodule-index repository
                                              (vcs-submodule-path submodule)
                                              execution-options))
                  submodule)))))
