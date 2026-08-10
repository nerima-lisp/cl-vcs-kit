(in-package #:vcs-kit/test)

(describe "Git repository queries"
  (it "projects unmerged status entries as conflicts"
    (let ((repository (make-vcs-repository (host-kit:temporary-directory)
                                           :backend :git)))
      (with-replaced-function
          (vcs-kit::vcs-status-structured
           (lambda (called-repository &rest arguments)
             (declare (ignore called-repository arguments))
             (vcs-kit::%make-vcs-status-snapshot
              :entries (list
                        (vcs-kit::%make-vcs-status-entry
                         :kind :ordinary :path "clean.txt")
                        (vcs-kit::%make-vcs-status-entry
                         :kind :unmerged :path "conflict.txt"
                         :conflict-object-1 "base-object"
                         :conflict-object-2 "ours-object"
                         :conflict-object-3 "theirs-object")))))
        (let ((conflicts (vcs-list-conflicts repository)))
          (expect (length conflicts) :to-equal 1)
          (let ((conflict (first conflicts)))
            (expect (vcs-conflict-path conflict) :to-equal "conflict.txt")
            (expect (vcs-conflict-base conflict) :to-equal "base-object")
            (expect (vcs-conflict-ours conflict) :to-equal "ours-object")
            (expect (vcs-conflict-theirs conflict) :to-equal "theirs-object"))))))

  (it "rejects mismatched structured diff streams"
    (let ((repository (make-vcs-repository (host-kit:temporary-directory)
                                           :backend :git)))
      (with-replaced-function
          (vcs-kit::%vcs-structured-run
           (lambda (called-repository command arguments execution-options)
             (declare (ignore called-repository command execution-options))
             (if (member "--name-status" arguments :test #'string=)
                 (%fake-result :stdout (format nil "M~Cfile.txt~C" #\Null #\Null))
                 (%fake-result :stdout ""))))
        (%expect-condition error
          (vcs-diff-entries repository)))))

  (it "handles optional Git queries and rejects malformed history"
    (let ((repository (make-vcs-repository (host-kit:temporary-directory)
                                           :backend :git)))
      (with-replaced-function
          (vcs-kit::%vcs-structured-run
           (lambda (called-repository command arguments execution-options)
             (declare (ignore called-repository arguments execution-options))
             (cond
               ((string= command "remote")
                (%fake-result :stdout
                              (format nil "~%not-a-remote~%origin~Chttps://example.invalid/repo (fetch)~%"
                                      #\Tab)))
               ((string= command "config")
                (error 'vcs-command-exit-error :exit-code 1))
               (t (error "Unexpected fake structured command: ~A" command)))))
        (let ((remote (first (vcs-list-remotes repository))))
          (expect (vcs-remote-name remote) :to-equal "origin")
          (expect (vcs-remote-fetch-url remote) :to-equal "https://example.invalid/repo")
          (expect (vcs-remote-push-url remote) :to-be nil)
          (expect (vcs-remote-fetch-refspecs remote) :to-equal nil)
          (expect (vcs-remote-push-refspecs remote) :to-equal nil)))
      (with-replaced-function
          (vcs-kit::%vcs-structured-run
           (lambda (called-repository command arguments execution-options)
             (declare (ignore called-repository command arguments execution-options))
             (error 'vcs-command-exit-error :exit-code 2)))
        (let ((condition (%expect-condition vcs-command-exit-error
                           (vcs-list-remotes repository))))
          (expect (vcs-command-exit-error-exit-code condition) :to-equal 2)))
      (with-replaced-function
          (vcs-kit::%vcs-structured-run
           (lambda (called-repository command arguments execution-options)
             (declare (ignore called-repository arguments execution-options))
             (cond
               ((string= command "log") (%fake-result :stdout (%join-nul "only")))
               ((string= command "stash")
                (%fake-result :stdout (format nil "~%stash@{0}~Cmessage~%" #\Null)))
               (t (error "Unexpected fake structured command: ~A" command)))))
        (%expect-condition error (vcs-list-commits repository))
        (%expect-condition error (vcs-list-stashes repository)))))
  )
