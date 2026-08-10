(in-package #:vcs-kit/test)

(describe "generated backend operation properties"
  (it-property "preserves generated backend operation metadata"
      ((spec (gen-tuple
              (gen-map (lambda (name)
                         (intern (string-upcase name) :keyword))
                       (gen-string :min-length 1
                                   :max-length 8
                                   :alphabet "abc"))
              (gen-map (lambda (name)
                         (concatenate 'string "generated-" name))
                       (gen-string :min-length 1
                                   :max-length 8
                                   :alphabet "abc")))))
    (destructuring-bind (operation command) spec
      (let* ((backend (make-vcs-backend
                       :name :generated-backend
                       :commands (list (cons operation command))))
             (info (vcs-operation-info backend operation)))
        (expect (vcs-backend-supports-operation-p backend operation)
                :to-be-truthy)
        (expect (vcs-supported-operations backend)
                :to-equal (list operation))
        (expect (vcs-operation-command backend operation)
                :to-equal command)
        (expect (vcs-operation-info-mapping-kind info)
                :to-equal :alias)))))
