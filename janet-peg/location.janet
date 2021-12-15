# bl - begin line
# bc - begin column
# el - end line
# ec - end column
(defn make-attrs
  [& items]
  (zipcoll [:bl :bc :el :ec]
           items))

(def loc-grammar
  ~{:main (sequence (line) (column)
                    (some :input)
                    (line) (column))
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

  (get (peg/match loc-grammar " ") 2)
  # => '(:whitespace @{:bc 1 :bl 1 :ec 2 :el 1} " ")

  (get (peg/match loc-grammar "# hi there") 2)
  # => '(:comment @{:bc 1 :bl 1 :ec 11 :el 1} "# hi there")

  (get (peg/match loc-grammar "8.3") 2)
  # => '(:number @{:bc 1 :bl 1 :ec 4 :el 1} "8.3")

  (get (peg/match loc-grammar "printf") 2)
  # => '(:symbol @{:bc 1 :bl 1 :ec 7 :el 1} "printf")

  (get (peg/match loc-grammar ":smile") 2)
  # => '(:keyword @{:bc 1 :bl 1 :ec 7 :el 1} ":smile")

  (get (peg/match loc-grammar `"fun"`) 2)
  # => '(:string @{:bc 1 :bl 1 :ec 6 :el 1} "\"fun\"")

  (get (peg/match loc-grammar "``long-fun``") 2)
  # => '(:long-string @{:bc 1 :bl 1 :ec 13 :el 1} "``long-fun``")

  (get (peg/match loc-grammar "@``long-buffer-fun``") 2)
  # => '(:long-buffer @{:bc 1 :bl 1 :ec 21 :el 1} "@``long-buffer-fun``")

  (get (peg/match loc-grammar `@"a buffer"`) 2)
  # => '(:buffer @{:bc 1 :bl 1 :ec 12 :el 1} "@\"a buffer\"")

  (deep=
    #
    (get (peg/match loc-grammar "@[8]") 2)
    #
    '(:bracket-array @{:bc 1 :bl 1
                       :ec 5 :el 1}
                     (:number @{:bc 3 :bl 1
                                :ec 4 :el 1} "8")))
  # => true

  (deep=
    #
    (get (peg/match loc-grammar "@{:a 1}") 2)
    #
    '(:table @{:bc 1 :bl 1
               :ec 8 :el 1}
             (:keyword @{:bc 3 :bl 1
                         :ec 5 :el 1} ":a")
             (:whitespace @{:bc 5 :bl 1
                            :ec 6 :el 1} " ")
             (:number @{:bc 6 :bl 1
                        :ec 7 :el 1} "1")))
  # => true

  (deep=
    #
    (get (peg/match loc-grammar "~x") 2)
    #
    '(:quasiquote @{:bc 1 :bl 1
                    :ec 3 :el 1}
                  (:symbol @{:bc 2 :bl 1
                             :ec 3 :el 1} "x")))
  # => true

  )

(def loc-top-level-ast
  (let [ltla (table ;(kvs loc-grammar))]
    (put ltla
         :main ~(sequence (line) (column)
                          :input
                          (line) (column)))
    (table/to-struct ltla)))

(defn ast
  [src &opt start single]
  (default start 0)
  (if single
    (if-let [[bl bc tree el ec]
             (peg/match loc-top-level-ast src start)]
      @[:code (make-attrs bl bc el ec) tree]
      @[:code])
    (if-let [captures (peg/match loc-grammar src start)]
      (let [[bl bc] (slice captures 0 2)
            [el ec] (slice captures -3)
            trees (array/slice captures 2 -3)]
        (array/insert trees 0
                      :code (make-attrs bl bc el ec)))
      @[:code])))

(comment

  (deep=
    #
    (ast "(+ 1 1)")
    #
    '@[:code @{:bc 1 :bl 1
               :ec 8 :el 1}
       (:tuple @{:bc 1 :bl 1
                 :ec 8 :el 1}
               (:symbol @{:bc 2 :bl 1
                          :ec 3 :el 1} "+")
               (:whitespace @{:bc 3 :bl 1
                              :ec 4 :el 1} " ")
               (:number @{:bc 4 :bl 1
                          :ec 5 :el 1} "1")
               (:whitespace @{:bc 5 :bl 1
                              :ec 6 :el 1} " ")
               (:number @{:bc 6 :bl 1
                          :ec 7 :el 1} "1"))])
  # => true

  )

(defn code*
  [an-ast buf]
  (case (first an-ast)
    :code
    (each elt (drop 2 an-ast)
      (code* elt buf))
    #
    :buffer
    (buffer/push-string buf (in an-ast 2))
    :comment
    (buffer/push-string buf (in an-ast 2))
    :constant
    (buffer/push-string buf (in an-ast 2))
    :keyword
    (buffer/push-string buf (in an-ast 2))
    :long-buffer
    (buffer/push-string buf (in an-ast 2))
    :long-string
    (buffer/push-string buf (in an-ast 2))
    :number
    (buffer/push-string buf (in an-ast 2))
    :string
    (buffer/push-string buf (in an-ast 2))
    :symbol
    (buffer/push-string buf (in an-ast 2))
    :whitespace
    (buffer/push-string buf (in an-ast 2))
    #
    :array
    (do
      (buffer/push-string buf "@(")
      (each elt (drop 2 an-ast)
        (code* elt buf))
      (buffer/push-string buf ")"))
    :bracket-array
    (do
      (buffer/push-string buf "@[")
      (each elt (drop 2 an-ast)
        (code* elt buf))
      (buffer/push-string buf "]"))
    :bracket-tuple
    (do
      (buffer/push-string buf "[")
      (each elt (drop 2 an-ast)
        (code* elt buf))
      (buffer/push-string buf "]"))
    :tuple
    (do
      (buffer/push-string buf "(")
      (each elt (drop 2 an-ast)
        (code* elt buf))
      (buffer/push-string buf ")"))
    :struct
    (do
      (buffer/push-string buf "{")
      (each elt (drop 2 an-ast)
        (code* elt buf))
      (buffer/push-string buf "}"))
    :table
    (do
      (buffer/push-string buf "@{")
      (each elt (drop 2 an-ast)
        (code* elt buf))
      (buffer/push-string buf "}"))
    #
    :fn
    (do
      (buffer/push-string buf "|")
      (each elt (drop 2 an-ast)
        (code* elt buf)))
    :quasiquote
    (do
      (buffer/push-string buf "~")
      (each elt (drop 2 an-ast)
        (code* elt buf)))
    :quote
    (do
      (buffer/push-string buf "'")
      (each elt (drop 2 an-ast)
        (code* elt buf)))
    :splice
    (do
      (buffer/push-string buf ";")
      (each elt (drop 2 an-ast)
        (code* elt buf)))
    :unquote
    (do
      (buffer/push-string buf ",")
      (each elt (drop 2 an-ast)
        (code* elt buf)))
    ))

(defn code
  [an-ast]
  (let [buf @""]
    (code* an-ast buf)
    # XXX: leave as buffer?
    (string buf)))

(comment

  (code
    [:code])
  # => ""

  (code
    '(:whitespace @{:bc 1 :bl 1
                    :ec 2 :el 1} " "))
  # => " "


  (code
    '(:buffer @{:bc 1 :bl 1
                :ec 12 :el 1} "@\"a buffer\""))
  # => "@\"a buffer\""

  (code
    '@[:code @{:bc 1 :bl 1
               :ec 8 :el 1}
       (:tuple @{:bc 1 :bl 1
                 :ec 8 :el 1}
               (:symbol @{:bc 2 :bl 1
                          :ec 3 :el 1} "+")
               (:whitespace @{:bc 3 :bl 1
                              :ec 4 :el 1} " ")
               (:number @{:bc 4 :bl 1
                          :ec 5 :el 1} "1")
               (:whitespace @{:bc 5 :bl 1
                              :ec 6 :el 1} " ")
               (:number @{:bc 6 :bl 1
                          :ec 7 :el 1} "1"))])
  # => "(+ 1 1)"

  )

(comment

  (let [src "{:x  :y \n :z  [:a  :b    :c]}"]
    (deep= (code (ast src))
           src))
  # => true

  )

(comment

  (comment

    (let [src (slurp (string (os/getenv "HOME")
                             "/src/janet/src/boot/boot.janet"))]
      (= (string src)
         (code (ast src))))

    )

  )
