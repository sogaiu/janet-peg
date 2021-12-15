# bl - begin line
# bc - begin column
# el - end line
# ec - end column
(defn make-attrs
  [& items]
  (zipcoll [:bl :bc :el :ec]
           items))

(def loc-grammar
  ~{:main (some :input)
    #
    :input (choice :non-form
                   :form)
    #
    :non-form (choice :whitespace
                      :comment)
    #
    :whitespace
    (cmt (capture (sequence (line) (column)
                            (choice (some (set " \0\f\t\v"))
                                    (choice "\r\n"
                                            "\r"
                                            "\n"))
                            (line) (column)))
         ,|[:whitespace (make-attrs ;(slice $& 0 -2)) (last $&)])
    #
    :comment
    (cmt (sequence (line) (column)
                   (capture (sequence "#"
                                      (any (if-not (set "\r\n") 1))))
                   (line) (column))
         ,|[:comment (make-attrs $0 $1 $3 $4) $2])
    #
    :form (choice :reader-macro
                  :collection
                  :literal)
    #
    :reader-macro (choice :fn
                          :quasiquote
                          :quote
                          :splice
                          :unquote)
    #
    :fn
    (cmt (capture (sequence (line) (column)
                            "|"
                            (any :non-form)
                            :form
                            (line) (column)))
         # $& is the remaining arguments
         ,|[:fn (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
            ;(slice $& 2 -4)])
    #
    :quasiquote
    (cmt (capture (sequence (line) (column)
                            "~"
                            (any :non-form)
                            :form
                            (line) (column)))
         ,|[:quasiquote (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
            ;(slice $& 2 -4)])
    #
    :quote
    (cmt (capture (sequence (line) (column)
                            "'"
                            (any :non-form)
                            :form
                            (line) (column)))
         ,|[:quote (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
            ;(slice $& 2 -4)])
    #
    :splice
    (cmt (capture (sequence (line) (column)
                            ";"
                            (any :non-form)
                            :form
                            (line) (column)))
         ,|[:splice (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
            ;(slice $& 2 -4)])
    #
    :unquote
    (cmt (capture (sequence (line) (column)
                            ","
                            (any :non-form)
                            :form
                            (line) (column)))
         ,|[:unquote (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
            ;(slice $& 2 -4)])
    #
    :literal (choice :number
                     :constant
                     :buffer
                     :string
                     :long-buffer
                     :long-string
                     :keyword
                     :symbol)
    #
    :collection (choice :array
                        :bracket-array
                        :tuple
                        :bracket-tuple
                        :table
                        :struct)
    #
    :number
    (cmt (capture (sequence (line) (column)
                            (drop (cmt
                                    (capture (some :name-char))
                                    ,scan-number))
                            (line) (column)))
         ,|[:number (make-attrs ;(slice $& 0 -2)) (last $&)])
    #
    :name-char (choice (range "09" "AZ" "az" "\x80\xFF")
                       (set "!$%&*+-./:<?=>@^_"))
    #
    :constant
    (cmt (capture (sequence (line) (column)
                            (choice "false" "nil" "true")
                            (line) (column)
                            (not :name-char)))
         ,|[:constant (make-attrs ;(slice $& 0 -2)) (last $&)])
    #
    :buffer
    (cmt (sequence (line) (column)
                   (capture (sequence "@\""
                                      (any (choice :escape
                                                   (if-not "\"" 1)))
                                      "\""))
                   (line) (column))
         ,|[:buffer (make-attrs $0 $1 $3 $4) $2])
    #
    :escape (sequence "\\"
                      (choice (set "0efnrtvz\"\\")
                              (sequence "x" [2 :hex])
                              (sequence "u" [4 :hex])
                              (sequence "U" [6 :hex])
                              (error (constant "bad escape"))))
    #
    :hex (range "09" "af" "AF")
    #
    :string
    (cmt (sequence (line) (column)
                   (capture (sequence "\""
                                      (any (choice :escape
                                                   (if-not "\"" 1)))
                                      "\""))
                   (line) (column))
         ,|[:string (make-attrs $0 $1 $3 $4) $2])
    #
    :long-string
    (cmt (capture (sequence (line) (column)
                            :long-bytes
                            (line) (column)))
         ,|[:long-string (make-attrs ;(slice $& 0 -2)) (last $&)])
    #
    :long-bytes {:main (drop (sequence :open
                                       (any (if-not :close 1))
                                       :close))
                 :open (capture :delim :n)
                 :delim (some "`")
                 :close (cmt (sequence (not (look -1 "`"))
                                       (backref :n)
                                       (capture :delim))
                             ,=)}
    #
    :long-buffer
    (cmt (sequence (line) (column)
                   (capture (sequence "@" :long-bytes))
                   (line) (column))
         ,|[:long-buffer (make-attrs $0 $1 $3 $4) $2])
    #
    :keyword
    (cmt (capture (sequence (line) (column)
                            ":"
                            (any :name-char)
                            (line) (column)))
         ,|[:keyword (make-attrs ;(slice $& 0 -2)) (last $&)])
    #
    :symbol
    (cmt (capture (sequence (line) (column)
                            (some :name-char)
                            (line) (column)))
         ,|[:symbol (make-attrs ;(slice $& 0 -2)) (last $&)])
    #
    :array
    (cmt (capture (sequence (line) (column)
                            "@("
                            (any :input)
                            (choice ")"
                                    (error (constant "missing )")))
                            (line) (column)))
        ,|[:array (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
           ;(slice $& 2 -4)])
    #
    :tuple
    (cmt (capture (sequence (line) (column)
                            "("
                            (any :input)
                            (choice ")"
                                    (error (constant "missing )")))
                            (line) (column)))
         ,|[:tuple (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
            ;(slice $& 2 -4)])
    #
    :bracket-array
    (cmt (capture (sequence (line) (column)
                            "@["
                            (any :input)
                            (choice "]"
                                    (error (constant "missing ]")))
                            (line) (column)))
         ,|[:bracket-array (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
            ;(slice $& 2 -4)])
    #
    :bracket-tuple
    (cmt (capture (sequence (line) (column)
                            "["
                            (any :input)
                            (choice "]"
                                    (error (constant "missing ]")))
                            (line) (column)))
         ,|[:bracket-tuple (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
            ;(slice $& 2 -4)])
    #
    :table
    (cmt (capture (sequence (line) (column)
                            "@{"
                            (any :input)
                            (choice "}"
                                    (error (constant "missing }")))
                            (line) (column)))
         ,|[:table (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
            ;(slice $& 2 -4)])
    #
    :struct
    (cmt (capture (sequence (line) (column)
                            "{"
                            (any :input)
                            (choice "}"
                                    (error (constant "missing }")))
                            (line) (column)))
         ,|[:struct (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
            ;(slice $& 2 -4)])
    })

(comment

  (peg/match loc-grammar " ")
  # => '@[(:whitespace @{:bc 1 :bl 1 :ec 2 :el 1} " ")]

  (peg/match loc-grammar "# hi there")
  # => '@[(:comment @{:bc 1 :bl 1 :ec 11 :el 1} "# hi there")]

  (peg/match loc-grammar "8.3")
  # => '@[(:number @{:bc 1 :bl 1 :ec 4 :el 1} "8.3")]

  (peg/match loc-grammar "printf")
  # => '@[(:symbol @{:bc 1 :bl 1 :ec 7 :el 1} "printf")]

  (peg/match loc-grammar ":smile")
  # => '@[(:keyword @{:bc 1 :bl 1 :ec 7 :el 1} ":smile")]

  (peg/match loc-grammar `"fun"`)
  # => '@[(:string @{:bc 1 :bl 1 :ec 6 :el 1} "\"fun\"")]

  (peg/match loc-grammar "``long-fun``")
  # => '@[(:long-string @{:bc 1 :bl 1 :ec 13 :el 1} "``long-fun``")]

  (peg/match loc-grammar "@``long-buffer-fun``")
  # => '@[(:long-buffer @{:bc 1 :bl 1 :ec 21 :el 1} "@``long-buffer-fun``")]

  (peg/match loc-grammar `@"a buffer"`)
  # => '@[(:buffer @{:bc 1 :bl 1 :ec 12 :el 1} "@\"a buffer\"")]

  (deep=
    #
    (peg/match loc-grammar "@[8]")
    #
    '@[(:bracket-array @{:bc 1 :bl 1
                         :ec 5 :el 1}
                       (:number @{:bc 3 :bl 1
                                  :ec 4 :el 1} "8"))])
  # => true

  (deep=
    #
    (peg/match loc-grammar "@{:a 1}")
    #
    '@[(:table @{:bc 1 :bl 1
                 :ec 8 :el 1}
               (:keyword @{:bc 3 :bl 1
                           :ec 5 :el 1} ":a")
               (:whitespace @{:bc 5 :bl 1
                              :ec 6 :el 1} " ")
               (:number @{:bc 6 :bl 1
                          :ec 7 :el 1} "1"))])
  # => true

  (deep=
    #
    (peg/match loc-grammar "~x")
    #
    '@[(:quasiquote @{:bc 1 :bl 1
                      :ec 3 :el 1}
                    (:symbol @{:bc 2 :bl 1
                               :ec 3 :el 1} "x"))])
  # => true

  )
