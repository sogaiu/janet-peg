(def jg
  ~{:main (any :input)
    #
    :input (choice :non_form
                   :form)
    #
    :non_form (choice :whitespace
                      :comment)
    #
    :whitespace (set " \0\f\n\r\t\v")
    #
    :comment (sequence "#"
                       (any (if-not (set "\r\n") 1)))
    #
    :form (choice :reader_macro
                  :collection
                  :literal)
    #
    :reader_macro (choice :fn
                          :quasiquote
                          :quote
                          :splice
                          :unquote)
    #
    :fn (sequence "|"
                  (any :non_form)
                  :form)
    #
    :quasiquote (sequence "~"
                          (any :non_form)
                          :form)
    #
    :quote (sequence "'"
                     (any :non_form)
                     :form)
    #
    :splice (sequence ";"
                      (any :non_form)
                      :form)
    #
    :unquote (sequence ","
                       (any :non_form)
                       :form)
    #
    :literal (choice :number
                     :constant
                     :buffer
                     :string
                     :long_buffer
                     :long_string
                     :keyword
                     :symbol)
    #
    :collection (choice :array
                        :bracket_array
                        :tuple
                        :bracket_tuple
                        :table
                        :struct)
    #
    :number (drop (cmt
                   (capture (some :name_char))
                   ,scan-number))
    #
    :name_char (choice (range "09" "AZ" "az" "\x80\xFF")
                       (set "!$%&*+-./:<?=>@^_"))
    #
    :constant (choice "false" "nil" "true")
    #
    :buffer (sequence "@\""
                      (any (choice :escape
                                   (if-not "\"" 1)))
                      "\"")
    #
    :escape (sequence "\\"
                      (choice (set "0efnrtvz\"\\")
                              (sequence "x" [2 :hex])
                              (sequence "u" [4 :d])
                              (sequence "U" [6 :d])
                              (error (constant "bad escape"))))
    #
    :hex (range "09" "af" "AF")
    #
    :string (sequence "\""
                      (any (choice :escape
                                   (if-not "\"" 1)))
                      "\"")
    #
    :long_string :long_bytes
    #
    :long_bytes {:main (drop (sequence :open
                                       (any (if-not :close 1))
                                       :close))
                 :open (capture :delim :n)
                 :delim (some "`")
                 :close (cmt (sequence (not (look -1 "`"))
                                       (backref :n)
                                       (capture :delim))
                             ,=)}
    #
    :long_buffer (sequence "@"
                           :long_bytes)
    #
    :keyword (sequence ":"
                       (any :name_char))
    #
    :symbol (some :name_char)
    #
    :array (sequence "@("
                      (any :input)
                      (choice ")"
                              (error "")))
    #
    :tuple (sequence "("
                      (any :input)
                      (choice ")"
                              (error "")))
    #
    :bracket_array (sequence "@["
                             (any :input)
                             (choice "]"
                                     (error "")))
    #
    :bracket_tuple (sequence "["
                             (any :input)
                             (choice "]"
                                     (error "")))
    :table (sequence "@{"
                      (any :input)
                      (choice "}"
                              (error "")))
    #
    :struct (sequence "{"
                      (any :input)
                      (choice "}"
                              (error "")))
    })

(comment

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
 # ! "match error in range (6:6)"

 (peg/match jg "(def a # hi 1)")
 # ! "match error in range (14:14)"

 (peg/match jg "\"\\u001\"")
 # ! "bad escape"

 )
