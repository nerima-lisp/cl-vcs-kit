;;;; Backend-neutral VCS protocol

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

(defun %vcs-backend-command (backend operation)
  (let ((entry (assoc (%vcs-keyword operation)
                      (vcs-backend-commands backend))))
    (when entry
      (let ((command (cdr entry)))
        (if (functionp command)
            (funcall command backend (%vcs-keyword operation))
            command)))))

(defvar *vcs-backends* nil)

(defun available-vcs-backends ()
  "Return the currently registered backend descriptors."
  (copy-list *vcs-backends*))

(defun find-vcs-backend (designator)
  "Find a backend by name, alias, or return a backend object unchanged."
  (if (vcs-backend-p designator)
      designator
      (let ((name (%vcs-keyword designator)))
        (or (find-if
             (lambda (backend)
               (or (eql name (vcs-backend-name backend))
                   (member name (vcs-backend-aliases backend))))
             *vcs-backends*)
            (error 'vcs-unknown-backend-error
                   :backend nil
                   :designator designator
                   :known-backends
                   (mapcar #'vcs-backend-name *vcs-backends*))))))

(defun %vcs-backend-designators (backend)
  (cons (vcs-backend-name backend)
        (vcs-backend-aliases backend)))

(defun %vcs-duplicate-designator (designators)
  (loop for tail on designators
        for designator = (car tail)
        when (member designator (cdr tail))
          return designator))

(defun register-vcs-backend (backend &key (replace t))
  "Register BACKEND and return it.

When REPLACE is true, a backend with the same name is replaced.  Every name
and alias must be unique among the registered descriptors; a collision
signals VCS-BACKEND-REGISTRATION-ERROR."
  (check-type backend vcs-backend)
  (let* ((name (vcs-backend-name backend))
         (existing
           (find-if (lambda (candidate)
                      (eql name (vcs-backend-name candidate)))
                    *vcs-backends*))
         (remaining
           (if (and replace existing)
               (remove existing *vcs-backends* :test #'eq)
               *vcs-backends*)))
    (when (and existing (not replace))
      (error 'vcs-backend-registration-error
             :backend existing
             :designator name
             :conflicting-backend existing))
    (let ((duplicate (%vcs-duplicate-designator
                      (%vcs-backend-designators backend))))
      (when duplicate
        (error 'vcs-backend-registration-error
               :backend backend
               :designator duplicate
               :conflicting-backend backend)))
    (dolist (designator (%vcs-backend-designators backend))
      (let ((conflicting
              (find-if
               (lambda (candidate)
                (member designator (%vcs-backend-designators candidate)))
               remaining)))
        (when conflicting
          (error 'vcs-backend-registration-error
                 :backend conflicting
                 :designator designator
                 :conflicting-backend conflicting))))
    (setf *vcs-backends* (cons backend remaining))
    backend))

(defun unregister-vcs-backend (designator)
  "Remove and return a registered backend, or signal an unknown-backend error."
  (let* ((backend (find-vcs-backend designator))
         (name (vcs-backend-name backend)))
    (setf *vcs-backends*
          (remove-if (lambda (candidate)
                       (eql name (vcs-backend-name candidate)))
                     *vcs-backends*))
    backend))

(defun vcs-backend-supports-operation-p (backend operation)
  "True when BACKEND declares OPERATION among its capabilities.

BACKEND is a descriptor or a name/alias designator resolved through
FIND-VCS-BACKEND, and OPERATION is a keyword, symbol, or string.  A declared
capability means the backend carries a command mapping for OPERATION; it says
nothing about whether the executable is installed or the operation would
succeed.

Signals VCS-UNKNOWN-BACKEND-ERROR when BACKEND names no registered backend,
and VCS-ARGUMENT-ERROR when BACKEND or OPERATION is not a keyword, symbol, or
string."
  (let ((backend (find-vcs-backend backend)))
    (not (null (member (%vcs-keyword operation)
                       (vcs-backend-capabilities backend))))))

(defun vcs-supported-operations (backend)
  (copy-list (vcs-backend-capabilities (find-vcs-backend backend))))

(defun vcs-backend-supports-structured-operation-p (backend operation)
  "Return true when BACKEND implements semantic OPERATION observations."
  (let ((backend (find-vcs-backend backend)))
    (not (null (member (%vcs-keyword operation)
                       (vcs-backend-structured-operations backend))))))

(defun vcs-structured-operations (backend)
  "Return semantic observations implemented by BACKEND."
  (copy-list
   (vcs-backend-structured-operations (find-vcs-backend backend))))

(defun vcs-operation-command (backend operation)
  "Return the backend command for OPERATION, or NIL when unsupported."
  (let ((backend (find-vcs-backend backend)))
    (when (vcs-backend-supports-operation-p backend operation)
      (%vcs-backend-command backend operation))))

(defun %vcs-default-operation-kind (operation command)
  (if (and (stringp command)
           (string= (string-downcase (symbol-name (%vcs-keyword operation)))
                    command))
      :exact
      :alias))

(defun vcs-operation-info (backend operation)
  "Return effective command metadata for OPERATION, or NIL when unsupported."
  (let* ((backend (find-vcs-backend backend))
         (operation (%vcs-keyword operation)))
    (when (vcs-backend-supports-operation-p backend operation)
      (let ((command (%vcs-backend-command backend operation)))
        (when command
          (%make-vcs-operation-info
           :operation operation
           :command command
           :mapping-kind
           (or (cdr (assoc operation
                          (vcs-backend-operation-kinds backend)))
               (%vcs-default-operation-kind operation command))))))))

(defun vcs-operation-kind (backend operation)
  "Return the effective mapping classification for OPERATION, or NIL."
  (let ((info (vcs-operation-info backend operation)))
    (when info
      (vcs-operation-info-mapping-kind info))))
