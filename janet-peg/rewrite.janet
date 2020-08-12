(import ./grammar :prefix "")

(def jg-capture-ast
  # jg is a struct, need something mutable
  (let [jca (table ;(kvs jg))]
    # override things that need to be captured
    (each kwd [:buffer :comment :constant :keyword :long_buffer
               :long_string :number :string :symbol :whitespace]
          (put jca kwd
               ~(cmt (capture ,(in jca kwd))
                     ,|[kwd $])))
    (each kwd [:fn :quasiquote :quote :splice :unquote]
          (put jca kwd
               ~(cmt (capture ,(in jca kwd))
                     ,|[kwd ;(slice $& 0 -2)])))
    (each kwd [:array :bracket_array :bracket_tuple :table :tuple :struct]
          (put jca kwd
               (tuple # array needs to be converted
                 ;(put (array ;(in jca kwd))
                       2 ~(cmt (capture ,(get-in jca [kwd 2]))
                               ,|[kwd ;(slice $& 0 -2)])))))
    # tried using a table with a peg but had a problem, so use a struct
    (table/to-struct jca)))

(comment

 (peg/match jg-capture-ast "@\"i am a buffer\"")
 # => @[[:buffer "@\"i am a buffer\""]]

 (peg/match jg-capture-ast "# hello")
 # => @[[:comment "# hello"]]

 (peg/match jg-capture-ast "nil")
 # => @[[:constant "nil"]]

 (peg/match jg-capture-ast ":a")
 # => @[[:keyword ":a"]]

 (peg/match jg-capture-ast "@``i am a long buffer``")
 # => @[[:long_buffer "@``i am a long buffer``"]]

 (peg/match jg-capture-ast "``hello``")
 # => @[[:long_string "``hello``"]]

 (peg/match jg-capture-ast "8")
 # => @[[:number "8"]]

 (peg/match jg-capture-ast "\"\\u0001\"")
 # => @[[:string "\"\\u0001\""]]

 (peg/match jg-capture-ast "a")
 # => @[[:symbol "a"]]

 (peg/match jg-capture-ast " ")
  # => @[[:whitespace " "]]

 (peg/match jg-capture-ast "|(+ $ 2)")
 ``
 '@[(:fn
     (:tuple
      (:symbol "+") (:whitespace " ")
      (:symbol "$") (:whitespace " ")
      (:number "2")))]
 ``

 (peg/match jg-capture-ast "~a")
 # => @[[:quasiquote [:symbol "a"]]]

 (peg/match jg-capture-ast "'a")
 # => @[[:quote [:symbol "a"]]]

 (peg/match jg-capture-ast ";a")
 # => @[[:splice [:symbol "a"]]]

 (peg/match jg-capture-ast ",a")
 # => @[[:unquote [:symbol "a"]]]

 (peg/match jg-capture-ast "@(:a)")
 # => '@[(:array (:keyword ":a"))]

 (peg/match jg-capture-ast "@[:a]")
 # => '@[(:bracket_array (:keyword ":a"))]

 (peg/match jg-capture-ast "[:a]")
 # => '@[(:bracket_tuple (:keyword ":a"))]

 (peg/match jg-capture-ast "@{:a 1}")
 ``
 '@[(:table
     (:keyword ":a") (:whitespace " ")
     (:number "1"))]
 ``

 (peg/match jg-capture-ast "{:a 1}")
 ``
 '@[(:struct
    (:keyword ":a") (:whitespace " ")
    (:number "1"))]
 ``

 (peg/match jg-capture-ast "(:a)")
 # => '@[(:tuple (:keyword ":a"))]

 (peg/match jg-capture-ast "(def a 1)")
 ``
 @[[:tuple
    [:symbol "def"] [:whitespace " "]
    [:symbol "a"] [:whitespace " "]
    [:number "1"]]]
 ``

 (peg/match jg-capture-ast "(def a # hi\n 1)")
 ``
 '@[(:tuple
     (:symbol "def") (:whitespace " ")
     (:symbol "a") (:whitespace " ")
     (:comment "# hi") (:whitespace "\n") (:whitespace " ")
     (:number "1"))]
 ``

 )

(defn ast
  [src]
  (array/insert
    (peg/match jg-capture-ast src)
    0 :code))

(comment

  (ast "(+ 1 1)")
  ``
  '@[:code
     (:tuple
      (:symbol "+") (:whitespace " ")
      (:number "1") (:whitespace " ")
      (:number "1"))]
  ``

  )

(defn code*
  [ast buf]
  (case (first ast)
    :code
    (each elt (drop 1 ast)
          (code* elt buf))
    #
    :buffer
    (buffer/push-string buf (in ast 1))
    :comment
    (buffer/push-string buf (in ast 1))
    :constant
    (buffer/push-string buf (in ast 1))
    :keyword
    (buffer/push-string buf (in ast 1))
    :long_buffer
    (buffer/push-string buf (in ast 1))
    :long_string
    (buffer/push-string buf (in ast 1))
    :number
    (buffer/push-string buf (in ast 1))
    :string
    (buffer/push-string buf (in ast 1))
    :symbol
    (buffer/push-string buf (in ast 1))
    :whitespace
    (buffer/push-string buf (in ast 1))
    #
    :array
    (do
      (buffer/push-string buf "@(")
      (each elt (drop 1 ast)
            (code* elt buf))
      (buffer/push-string buf ")"))
    :bracket_array
    (do
      (buffer/push-string buf "@[")
      (each elt (drop 1 ast)
            (code* elt buf))
      (buffer/push-string buf "]"))
    :bracket_tuple
    (do
      (buffer/push-string buf "[")
      (each elt (drop 1 ast)
            (code* elt buf))
      (buffer/push-string buf "]"))
    :tuple
    (do
      (buffer/push-string buf "(")
      (each elt (drop 1 ast)
            (code* elt buf))
      (buffer/push-string buf ")"))
    :struct
    (do
      (buffer/push-string buf "{")
      (each elt (drop 1 ast)
            (code* elt buf))
      (buffer/push-string buf "}"))
    :table
    (do
      (buffer/push-string buf "@{")
      (each elt (drop 1 ast)
            (code* elt buf))
      (buffer/push-string buf "}"))
    #
    :fn
    (do
      (buffer/push-string buf "|")
      (each elt (drop 1 ast)
            (code* elt buf)))
    :quasiquote
    (do
      (buffer/push-string buf "~")
      (each elt (drop 1 ast)
            (code* elt buf)))
    :quote
    (do
      (buffer/push-string buf "'")
      (each elt (drop 1 ast)
            (code* elt buf)))
    :splice
    (do
      (buffer/push-string buf ";")
      (each elt (drop 1 ast)
            (code* elt buf)))
    :unquote
    (do
      (buffer/push-string buf ",")
      (each elt (drop 1 ast)
            (code* elt buf)))
    ))

(defn code
  [ast]
  (let [buf @""]
    (code* ast buf)
    (string buf)))

(comment

  (code
    [:code
     [:buffer "@\"buffer me\""]])
  # => "@\"buffer me\""

  (code
    [:comment "# i am a comment"])
  # => "# i am a comment"

  (code
    [:constant "true"])
  # => "true"

  (code
    [:keyword ":x"])
  # => ":x"

  (code
    [:long_buffer "@```looooong buffer```"])
  # => "@```looooong buffer```"

  (code
    [:long_string "```longish string```"])
  # => "```longish string```"

  (code
    [:string "\"a string\""])
  # => "\"a string\""

  (code
    [:symbol "non-descript-symbol"])
  # => "non-descript-symbol"

  (code
    [:whitespace "\n"])
  # => "\n"

  (code
    '(:fn
      (:tuple
       (:symbol "-") (:whitespace " ")
       (:symbol "$") (:whitespace " ")
       (:number "8"))))
  # => "|(- $ 8)"

  (code
    '(:quasiquote
      (:tuple
       (:symbol "/") (:whitespace " ")
       (:number "1") (:whitespace " ")
       (:symbol "a"))))
  # => "~(/ 1 a)"

  (code
    '(:quote
      (:tuple
       (:symbol "*") (:whitespace " ")
       (:number "0") (:whitespace " ")
       (:symbol "x"))))
  # => "'(* 0 x)"

  (code
    '(:splice
      (:tuple
       (:keyword ":a") (:whitespace " ")
       (:keyword ":b"))))
  # => ";(:a :b)"

  (code
    '(:unquote
      (:symbol "a")))
  # => ",a"

  (code
    '(:array
      (:keyword ":a") (:whitespace " ")
      (:keyword ":b")))
  # = "@(:a :b)"

  (code
    '(:bracket_array
      (:keyword ":a") (:whitespace " ")
      (:keyword ":b")))
  # => "@[:a :b]"

  (code
    '@(:bracket_tuple
       (:keyword ":a") (:whitespace " ")
       (:keyword ":b")))
  # => "[:a :b]"

  (code
    '@(:table
       (:keyword ":a") (:whitespace " ")
       (:number "1")))
  # => "@{:a 1}"

  (code
    '@(:struct
       (:keyword ":a") (:whitespace " ")
       (:number "1")))
  # => "{:a 1}"

  (code
    '@(:tuple
       (:keyword ":a") (:whitespace " ")
       (:keyword ":b")))
  # => "(:a :b)"

  )

(comment

  (comment

    (let [src (slurp (string (os/getenv "HOME")
                       "/src/janet/src/boot/boot.janet"))]
      (= (string src)
        (code (ast src))))

    # 33 ms per
    (let [start (os/time)]
      (each i (range 1000)
            (let [src
                  (slurp (string (os/getenv "HOME")
                           "/src/janet/src/boot/boot.janet"))]
              (= src
                (code (ast src)))))
      (print (- (os/time) start)))

    # replace all underscores in keywords with dashes
    (let [src (slurp (string (os/getenv "HOME")
                       "/src/janet-peg/janet-peg/rewrite.janet"))
          nodes (ast src)]
      (print
        (code
          (postwalk |(if (and (= (type $) :tuple)
                           (= (first $) :keyword)
                           (string/find "_" (in $ 1)))
                       (tuple ;(let [arr (array ;$)]
                                 (put arr 1
                                   (string/replace-all "_" "-" (in $ 1)))))
                       $)
            nodes))))

    )

  )
