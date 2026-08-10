;;;; VCS backend descriptor construction

(in-package #:vcs-kit)

(defun %vcs-keyword (designator)
  (cond
    ((keywordp designator) designator)
    ((symbolp designator)
     (intern (string-upcase (symbol-name designator)) :keyword))
    ((stringp designator)
     (intern (string-upcase designator) :keyword))
    (t
     (error 'vcs-argument-error
            :argument designator
            :reason "a VCS designator must be a keyword, symbol, or string"))))

(defun %normalize-vcs-command (command)
  (cond
    ((or (stringp command) (symbolp command))
     (%subcommand-string command))
    ((functionp command) command)
    ((and (listp command) command)
     (%argument-strings command))
    (t
     (error "Invalid VCS command designator: ~S" command))))

(defun %vcs-command-entry-value (entry)
  (let ((tail (cdr entry)))
    (if (and (consp tail) (null (cdr tail)))
        (car tail)
        tail)))

(defun %vcs-mapping-kind (kind)
  (let ((kind (%vcs-keyword kind)))
    (unless (member kind '(:exact :alias :approximate :native))
      (error "Invalid VCS operation mapping kind: ~S" kind))
    kind))

(defun %normalize-vcs-operation-kinds (operation-kinds)
  (let ((normalized
          (mapcar
           (lambda (entry)
             (unless (consp entry)
               (error "Invalid VCS operation mapping entry: ~S" entry))
             (cons (%vcs-keyword (car entry))
                   (%vcs-mapping-kind (%vcs-command-entry-value entry))))
           operation-kinds)))
    (when (/= (length normalized)
              (length (remove-duplicates normalized :key #'car)))
      (error "Duplicate VCS operation mapping entry"))
    normalized))

(defun make-vcs-backend (&key
                           (name :custom)
                           (executable "")
                           (aliases nil)
                           (capabilities nil)
                           (commands nil)
                           (operation-kinds nil)
                           (structured-operations nil)
                           (markers nil))
  "Create a backend descriptor suitable for REGISTER-VCS-BACKEND.

COMMANDS is an alist whose keys are operation names and whose values are
command strings, argument lists, or functions receiving the backend and
operation name.  This keeps backend-specific syntax explicit while allowing
the common operation functions to share one process boundary.  MARKERS is a
list of repository metadata file or directory names used by automatic
backend detection.  OPERATION-KINDS optionally classifies mappings as
`:exact`, `:alias`, `:approximate`, or `:native`; unspecified mappings are
classified from their command spelling.  STRUCTURED-OPERATIONS names
semantic observations implemented by the common layer rather than raw
command mappings."
  (check-type executable string)
  (check-type aliases list)
  (check-type capabilities list)
  (check-type commands list)
  (check-type operation-kinds list)
  (check-type structured-operations list)
  (check-type markers list)
  (let* ((normalized-name (%vcs-keyword name))
         (normalized-aliases
           (mapcar #'%vcs-keyword aliases))
         (normalized-commands
           (mapcar
            (lambda (entry)
              (unless (consp entry)
                (error "Invalid VCS command entry: ~S" entry))
              (cons (%vcs-keyword (car entry))
                    (%normalize-vcs-command
                     (%vcs-command-entry-value entry))))
            commands))
         (normalized-capabilities
           (remove-duplicates
            (mapcar #'%vcs-keyword
                    (or capabilities
                        (mapcar #'car normalized-commands)))))
         (normalized-operation-kinds
           (%normalize-vcs-operation-kinds operation-kinds))
         (normalized-structured-operations
           (remove-duplicates
            (mapcar #'%vcs-keyword structured-operations)))
         (normalized-markers
           (mapcar (lambda (marker)
                     (etypecase marker
                       (string marker)
                       (pathname (namestring marker))))
                   markers)))
    (when (/= (length normalized-commands)
              (length (remove-duplicates normalized-commands
                                          :key #'car)))
      (error "Duplicate VCS command entry"))
    (dolist (operation normalized-capabilities)
      (unless (assoc operation normalized-commands)
        (error "VCS capability ~S has no command mapping" operation)))
    (dolist (entry normalized-operation-kinds)
      (unless (member (car entry) normalized-capabilities)
        (error "VCS operation mapping ~S is not a declared capability"
               (car entry))))
    (%make-vcs-backend
     :name normalized-name
     :executable executable
     :aliases normalized-aliases
     :capabilities normalized-capabilities
     :commands normalized-commands
     :operation-kinds normalized-operation-kinds
     :structured-operations normalized-structured-operations
     :markers normalized-markers)))
