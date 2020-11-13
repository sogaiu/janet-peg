(def jg
  ~{:main (some :input)
    #
    :input (choice :non-form
                   :form)
    #
    :non-form (choice :whitespace
                      :comment)
    #
    :whitespace (set " \0\f\n\r\t\v")
    #
    :comment (sequence "#"
                       (any (if-not (set "\r\n") 1)))
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
    :fn (sequence "|"
                  (any :non-form)
                  :form)
    #
    :quasiquote (sequence "~"
                          (any :non-form)
                          :form)
    #
    :quote (sequence "'"
                     (any :non-form)
                     :form)
    #
    :splice (sequence ";"
                      (any :non-form)
                      :form)
    #
    :unquote (sequence ","
                       (any :non-form)
                       :form)
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
    :number (drop (cmt
                   (capture (some :name-char))
                   ,scan-number))
    #
    :name-char (choice (range "09" "AZ" "az" "\x80\xFF")
                       (set "!$%&*+-./:<?=>@^_"))
    #
    :constant (sequence (choice "false" "nil" "true")
                        (not :name-char))
    #
    :buffer (sequence "@\""
                      (any (choice :escape
                                   (if-not "\"" 1)))
                      "\"")
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
    :string (sequence "\""
                      (any (choice :escape
                                   (if-not "\"" 1)))
                      "\"")
    #
    :long-string :long-bytes
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
    :long-buffer (sequence "@"
                           :long-bytes)
    #
    :keyword (sequence ":"
                       (any :name-char))
    #
    :symbol (some :name-char)
    #
    :array (sequence "@("
                      (any :input)
                      (choice ")"
                              (error (constant "missing )"))))
    #
    :tuple (sequence "("
                      (any :input)
                      (choice ")"
                              (error (constant "missing )"))))
    #
    :bracket-array (sequence "@["
                             (any :input)
                             (choice "]"
                                     (error (constant "missing ]"))))
    #
    :bracket-tuple (sequence "["
                             (any :input)
                             (choice "]"
                                     (error (constant "missing ]"))))
    :table (sequence "@{"
                      (any :input)
                      (choice "}"
                              (error (constant "missing }"))))
    #
    :struct (sequence "{"
                      (any :input)
                      (choice "}"
                              (error (constant "missing }"))))
    })

(comment

  (peg/match jg "")
  # => nil

  (peg/match jg "@\"i am a buffer\"")
  # => @[]

  (peg/match jg "# hello")
  # => @[]

  (peg/match jg "nil")
  # => @[]

  (peg/match jg ":a")
  # => @[]

  (peg/match jg "@``i am a long buffer``")
  # => @[]

  (peg/match jg "``hello``")
  # => @[]

  (peg/match jg "8")
  # => @[]
 
  (peg/match jg "-2.0")
  # => @[]

  (peg/match jg "\"\\u0001\"")
  # => @[]

  (peg/match jg "a")
  # => @[]

  (peg/match jg " ")
  # => @[]

  (peg/match jg "|(+ $ 2)")
  # => @[]

  (peg/match jg "~a")
  # => @[]

  (peg/match jg "'a")
  # => @[]

  (peg/match jg ";a")
  # => @[]

  (peg/match jg ",a")
  # => @[]

  (peg/match jg "@(:a)")
  # => @[]

  (peg/match jg "@[:a]")
  # => @[]

  (peg/match jg "[:a]")
  # => @[]

  (peg/match jg "[1 2]")
  # => @[]

  (peg/match jg "@{:a 1}")
  # => @[]

  (peg/match jg "{:a 1}")
  # => @[]

  (peg/match jg "(:a)")
  # => @[]

  (peg/match jg "(def a 1)")
  # => @[]

  (peg/match jg "[:a :b] 1")
  # => @[]

  (peg/match jg "[:a :b)")
  # ! "missing ]"

  (peg/match jg "(def a # hi 1)")
  # ! "missing )"

  (peg/match jg "\"\\u001\"")
  # ! "bad escape"

 )
