(in-package #:vcs-kit/test)

(describe "protocol parsers"
  (it "preserves empty records while splitting NUL-delimited output"
    (expect (split-nul-records (%join-nul "a" "" "b"))
            :to-equal
            '("a" "" "b")))

  (it "treats empty command output as an empty snapshot"
    (expect (status-snapshot-entries (parse-status ""))
            :to-equal
            nil)
    (expect (parse-name-status "") :to-equal nil)
    (expect (parse-numstat "") :to-equal nil)
    (expect (vcs-kit::%split-tab-fields "") :to-equal '("")))

  (it "parses porcelain v2 status headers and entry variants"
    (let* ((text
             (%join-nul
              "# branch.head main"
              "# branch.upstream origin/main"
              "# branch.ab +2 -1"
              "# stash 3"
              "# branch.unmodeled value"
              "1 .M N... 100644 100644 100644 1111111 2222222 path.txt"
              "2 R. N... 100644 100644 100644 1111111 2222222 R100 new.txt"
              "old.txt"
              "u UU N... 100644 100644 100644 100644 aaa bbb ccc conflict.txt"
              "? new.txt"
              "! ignored.txt"))
           (snapshot (parse-status text))
           (entries (status-snapshot-entries snapshot)))
      (expect (status-snapshot-branch-head snapshot) :to-equal "main")
      (expect (status-snapshot-branch-upstream snapshot) :to-equal "origin/main")
      (expect (status-snapshot-ahead snapshot) :to-equal 2)
      (expect (status-snapshot-behind snapshot) :to-equal -1)
      (expect (status-snapshot-stash-count snapshot) :to-equal 3)
      (expect (length entries) :to-equal 5)
      (let ((ordinary (first entries))
            (rename (second entries))
            (unmerged (third entries))
            (untracked (fourth entries))
            (ignored (fifth entries)))
        (expect (status-entry-kind ordinary) :to-be :ordinary)
        (expect (status-entry-index-status ordinary) :to-equal ".")
        (expect (status-entry-worktree-status ordinary) :to-equal "M")
        (expect (status-entry-path ordinary) :to-equal "path.txt")
        (expect (status-entry-kind rename) :to-be :rename-or-copy)
        (expect (status-entry-score rename) :to-equal 100)
        (expect (status-entry-path rename) :to-equal "new.txt")
        (expect (status-entry-original-path rename) :to-equal "old.txt")
        (expect (status-entry-kind unmerged) :to-be :unmerged)
        (expect (status-entry-conflict-object-1 unmerged) :to-equal "aaa")
        (expect (status-entry-conflict-object-3 unmerged) :to-equal "ccc")
        (expect (status-entry-kind untracked) :to-be :untracked)
        (expect (status-entry-kind ignored) :to-be :ignored))))

  (it "parses name-status and numstat rename and copy records"
    (let ((name-status
            (parse-name-status
             (%join-nul "M" "file.txt" "R100" "old.txt" "new.txt")))
          (line-name-status
            (parse-name-status
             (format nil "M~Afile.txt~AR100~Aold.txt~Anew.txt"
                     #\Tab
                     #\Newline
                     #\Tab
                     #\Tab)))
          (copy-name-status
            (parse-name-status
             (format nil "C100~Aold.txt~Anew.txt~%"
                     #\Tab
                     #\Tab)))
          (numstat
            (parse-numstat
             (%join-nul
              (format nil "12~A3~Afile.txt" #\Tab #\Tab)
              (format nil "-~A-~Abinary.bin" #\Tab #\Tab))))
          (rename-numstat
            (parse-numstat
             (%join-nul
              (format nil "0~A0~A" #\Tab #\Tab)
              "old.txt"
              "new.txt")))
          (replacement-numstat
            (parse-numstat
             (%join-nul
              (format nil "1~A2~Aold.txt" #\Tab #\Tab)
              "new.txt"))))
      (expect (length name-status) :to-equal 2)
      (expect (name-status-entry-status (first name-status)) :to-equal "M")
      (expect (name-status-entry-path (second name-status)) :to-equal "new.txt")
      (expect (name-status-entry-original-path (second name-status))
              :to-equal
              "old.txt")
      (expect (length line-name-status) :to-equal 2)
      (expect (name-status-entry-original-path (second line-name-status))
              :to-equal
              "old.txt")
      (expect (name-status-entry-original-path (first copy-name-status))
              :to-equal
              "old.txt")
      (expect (numstat-entry-additions (first numstat)) :to-equal 12)
      (expect (numstat-entry-deletions (first numstat)) :to-equal 3)
      (expect (numstat-entry-binary-p (second numstat)) :to-be-truthy)
      (expect (numstat-entry-path (first rename-numstat)) :to-equal "new.txt")
      (expect (numstat-entry-original-path (first rename-numstat))
              :to-equal
              "old.txt")
      (expect (numstat-entry-additions (first replacement-numstat)) :to-equal 1)
      (expect (numstat-entry-deletions (first replacement-numstat)) :to-equal 2)
      (expect (numstat-entry-path (first replacement-numstat)) :to-equal "new.txt")
      (expect (numstat-entry-original-path (first replacement-numstat))
              :to-equal
              "old.txt")))

  (it "handles CRLF records, copy scores, and ambiguous numstat paths"
    (let* ((status
             (parse-status
              (%join-nul
               "2 C. N... 100644 100644 100644 1111111 2222222 C75 new.txt"
               "old.txt")))
           (copy (first (status-snapshot-entries status)))
           (name-status
             (parse-name-status
              (format nil "M~Afile.txt~A~A" #\Tab #\Return #\Newline)))
           (numstat
             (parse-numstat
              (format nil "1~A2~Afile.txt~A~A"
                      #\Tab #\Tab #\Return #\Newline)))
           (fallback
             (parse-numstat
              (%join-nul
               (format nil "1~A2~A" #\Tab #\Tab)
               "old.txt"
               (format nil "3~A4~Anew.txt" #\Tab #\Tab)))))
      (expect (status-entry-kind copy) :to-be :rename-or-copy)
      (expect (status-entry-score copy) :to-equal 75)
      (expect (name-status-entry-path (first name-status)) :to-equal "file.txt")
      (expect (numstat-entry-path (first numstat)) :to-equal "file.txt")
      (expect (numstat-entry-path (first fallback)) :to-equal "old.txt")
      (expect (numstat-entry-original-path (first fallback)) :to-be nil)
      (expect (numstat-entry-path (second fallback)) :to-equal "new.txt")))

  (it "signals a typed parse error for malformed records"
    (let ((condition
            (%expect-condition git-parse-error
              (parse-status (%join-nul "not-a-status-record")))))
      (expect (git-parse-error-format-name condition) :to-equal "status")
      (expect (git-parse-error-position condition) :to-equal 0)))

  (it "rejects malformed structured records"
    (dolist (record
              (list (%join-nul "# branch.ab nope -1")
                    (%join-nul "# branch.ab +1")
                    (%join-nul "1 .M")
                    (%join-nul
                     "2 R. N... 100644 100644 100644 1111111 2222222 X100 new.txt"
                     "old.txt")
                    (%join-nul "?")))
      (%expect-condition git-parse-error
        (parse-status record)))
    (%expect-condition git-parse-error
      (parse-name-status (%join-nul "Z" "file.txt")))
    (%expect-condition git-parse-error
      (parse-numstat (%join-nul "not-numstat"))))

  (it "rejects truncated and invalid protocol fields"
    (dolist (record
              (list (%join-nul "# branch.ab +1 nope")
                    (%join-nul "# stash nope")
                    (%join-nul "1 ... N... 100644 100644 100644 1111111 2222222 path.txt")
                    (%join-nul "2 R. N... 100644 100644 100644 1111111 2222222 R100 new.txt")
                    (%join-nul "2 R. N... 100644 100644 100644 1111111 2222222 Rfoo new.txt"
                               "old.txt")))
      (%expect-condition git-parse-error
        (parse-status record)))
    (dolist (record (list "M"
                          (format nil "R100~Aold.txt" #\Tab)
                          (format nil "M~Afile.txt~Aextra" #\Tab #\Tab)
                          (%join-nul "R100" "new.txt")))
      (%expect-condition git-parse-error
        (parse-name-status record)))
    (%expect-condition git-parse-error
      (parse-name-status (format nil "~A~Cfile.txt" #\Null #\Null)))
    (dolist (record (list (format nil "not~A2~Afile.txt" #\Tab #\Tab)
                          (%join-nul "new.txt")))
      (%expect-condition git-parse-error
        (parse-numstat record)))
    (%expect-condition git-parse-error
      (parse-status (%join-nul "" "1 .M N... 100644 100644 100644 1111111 2222222 path.txt")))
    (%expect-condition git-parse-error
      (parse-name-status (%join-nul "" "file.txt"))))

  (it "preserves CR only at the end of line records"
    (expect (vcs-kit::%split-line-records
             (format nil "first~C~%second~C" #\Return #\Return))
            :to-equal
            '("first" "second")))

  (it "parses fixed tab fields and reports missing fields"
    (multiple-value-bind (fields tail)
        (vcs-kit::%fixed-tab-fields-and-tail
         "numstat" (format nil "1~C2~Cpath~Cextra" #\Tab #\Tab #\Tab) 2 0)
      (expect fields :to-equal '("1" "2"))
      (expect tail :to-equal (format nil "path~Cextra" #\Tab)))
    (multiple-value-bind (fields tail)
        (vcs-kit::%fixed-tab-fields-and-tail-vector
         "numstat" (format nil "1~C2~Cpath" #\Tab #\Tab) 2 0)
      (expect (coerce fields 'list) :to-equal '("1" "2"))
      (expect tail :to-equal "path"))
    (dolist (record (list "1"
                          (format nil "1~C" #\Tab)
                          (format nil "1~C~Cpath" #\Tab #\Tab)))
      (%expect-condition git-parse-error
        (vcs-kit::%fixed-tab-fields-and-tail "numstat" record 2 0)))
    (dolist (record (list "1"
                          (format nil "1~C" #\Tab)
                          (format nil "1~C~Cpath" #\Tab #\Tab)))
      (%expect-condition git-parse-error
        (vcs-kit::%fixed-tab-fields-and-tail-vector "numstat" record 2 0))))

  (it-property "round-trips GHQ line-oriented output"
      ((lines (gen-list
               (gen-string :min-length 1 :max-length 8 :alphabet "abc")
               :max-length 5)))
    (expect (parse-ghq-lines
             (format nil "~{~A~^~%~}" lines))
            :to-equal
            lines))

  (it-property "round-trips non-empty Git NUL records"
      ((records (gen-list
                 (gen-string :min-length 1 :max-length 8 :alphabet "abc")
                 :min-length 1
                 :max-length 8)))
    (expect (split-nul-records
             (with-output-to-string (stream)
               (dolist (record records)
                 (write-string record stream)
                 (write-char #\Null stream))))
            :to-equal
            records)))
