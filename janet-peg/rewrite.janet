(import ./grammar :prefix "")

(def jg-capture-ast
  # jg is a struct, need something mutable
  (let [jca (table ;(kvs jg))]
    # override things that need to be captured
    (each kwd [:buffer :comment :constant :keyword :long-buffer
               :long-string :number :string :symbol :whitespace]
      (put jca kwd
               ~(cmt (capture ,(in jca kwd))
                     ,|[kwd $])))
    (each kwd [:fn :quasiquote :quote :splice :unquote]
      (put jca kwd
               ~(cmt (capture ,(in jca kwd))
                     ,|[kwd ;(slice $& 0 -2)])))
    (each kwd [:array :bracket-array :bracket-tuple :table :tuple :struct]
      (put jca kwd
           (tuple # array needs to be converted
                  ;(put (array ;(in jca kwd))
                        2 ~(cmt (capture ,(get-in jca [kwd 2]))
                                ,|[kwd ;(slice $& 0 -2)])))))
    # tried using a table with a peg but had a problem, so use a struct
    (table/to-struct jca)))

(comment

  (peg/match jg-capture-ast "")
  # => nil

  (peg/match jg-capture-ast ".0")
  # => @[[:number ".0"]]

  (peg/match jg-capture-ast ".0a")
  # => @[[:symbol ".0a"]]

  (peg/match jg-capture-ast "foo:bar")
  # => @[[:symbol "foo:bar"]]

  (peg/match jg-capture-ast "@\"i am a buffer\"")
  # => @[[:buffer "@\"i am a buffer\""]]

  (peg/match jg-capture-ast "# hello")
  # => @[[:comment "# hello"]]

  (peg/match jg-capture-ast "nil")
  # => @[[:constant "nil"]]

  (peg/match jg-capture-ast "nil?")
  # => @[[:symbol "nil?"]]

  (peg/match jg-capture-ast "true")
  # => @[[:constant "true"]]

  (peg/match jg-capture-ast "true?")
  # => @[[:symbol "true?"]]

  (peg/match jg-capture-ast "false")
  # => @[[:constant "false"]]

  (peg/match jg-capture-ast "false?")
  # => @[[:symbol "false?"]]

  (peg/match jg-capture-ast ":a")
  # => @[[:keyword ":a"]]

  (peg/match jg-capture-ast "@``i am a long buffer``")
  # => @[[:long-buffer "@``i am a long buffer``"]]

  (peg/match jg-capture-ast "``hello``")
  # => @[[:long-string "``hello``"]]

  (peg/match jg-capture-ast "8")
  # => @[[:number "8"]]

  (peg/match jg-capture-ast "\"\\u0001\"")
  # => @[[:string "\"\\u0001\""]]

  (peg/match jg-capture-ast "a")
  # => @[[:symbol "a"]]

  (peg/match jg-capture-ast " ")
  # => @[[:whitespace " "]]

  (deep=
    #
    (peg/match jg-capture-ast "|(+ $ 2)")
    #
    '@[(:fn
         (:tuple
           (:symbol "+") (:whitespace " ")
           (:symbol "$") (:whitespace " ")
           (:number "2")))])
  # => true

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
  # => '@[(:bracket-array (:keyword ":a"))]

  (peg/match jg-capture-ast "[:a]")
  # => '@[(:bracket-tuple (:keyword ":a"))]

  (deep=
    #
    (peg/match jg-capture-ast "@{:a 1}")
    #
    '@[(:table
         (:keyword ":a") (:whitespace " ")
         (:number "1"))])
  # => true

  (deep=
    #
    (peg/match jg-capture-ast "{:a 1}")
    #
    '@[(:struct
         (:keyword ":a") (:whitespace " ")
         (:number "1"))])
  # => true

  (peg/match jg-capture-ast "(:a)")
  # => '@[(:tuple (:keyword ":a"))]

  (deep=
    #
    (peg/match jg-capture-ast "(def a 1)")
    #
    '@[[:tuple
        [:symbol "def"] [:whitespace " "]
        [:symbol "a"] [:whitespace " "]
        [:number "1"]]])
  # => true

  (deep=
    #
    (peg/match jg-capture-ast "(def a # hi\n 1)")
    #
    '@[(:tuple
         (:symbol "def") (:whitespace " ")
         (:symbol "a") (:whitespace " ")
         (:comment "# hi") (:whitespace "\n") (:whitespace " ")
         (:number "1"))])
  # => true

  )

(def jg-capture-top-level-ast
  # jg is a struct, need something mutable
  (let [jca (table ;(kvs jg-capture-ast))]
    (put jca
         :main ~(sequence :input (position)))
    # tried using a table with a peg but had a problem, so use a struct
    (table/to-struct jca)))

(defn ast
  [src &opt start single]
  (default start 0)
  (if single
    (if-let [[tree position]
             (peg/match jg-capture-top-level-ast src start)]
      [@[:code tree] position]
      [@[:code] nil])
    (if-let [tree (peg/match jg-capture-ast src start)]
      (array/insert tree 0 :code)
      @[:code])))

(comment

  (deep=
    #
    (ast "(+ 1 1)")
    #
    '@[:code
       (:tuple
         (:symbol "+") (:whitespace " ")
         (:number "1") (:whitespace " ")
         (:number "1"))])
  # => true

  (def src
    ``
    (+ 1 1)

    (/ 2 3)
    ``)

  (deep=
    #
    (ast src 0 :single)
    #
    '(@[:code
        (:tuple
          (:symbol "+") (:whitespace " ")
          (:number "1") (:whitespace " ")
          (:number "1"))]
       7))
  # => true

  (deep=
    #
    (ast src 7 :single)
    #
    '(@[:code
        (:whitespace "\n")]
       8))
  # => true

  (deep=
    #
    (ast src 8 :single)
    #
    '(@[:code
        (:whitespace "\n")]
       9))
  # => true

  (deep=
    #
    (ast src 9 :single)
    #
    '(@[:code
        (:tuple
          (:symbol "/") (:whitespace " ")
          (:number "2") (:whitespace " ")
          (:number "3"))]
       16))
  # => true

  (ast "")
  # => @[:code]

  )

(defn code*
  [an-ast buf]
  (case (first an-ast)
    :code
    (each elt (drop 1 an-ast)
      (code* elt buf))
    #
    :buffer
    (buffer/push-string buf (in an-ast 1))
    :comment
    (buffer/push-string buf (in an-ast 1))
    :constant
    (buffer/push-string buf (in an-ast 1))
    :keyword
    (buffer/push-string buf (in an-ast 1))
    :long-buffer
    (buffer/push-string buf (in an-ast 1))
    :long-string
    (buffer/push-string buf (in an-ast 1))
    :number
    (buffer/push-string buf (in an-ast 1))
    :string
    (buffer/push-string buf (in an-ast 1))
    :symbol
    (buffer/push-string buf (in an-ast 1))
    :whitespace
    (buffer/push-string buf (in an-ast 1))
    #
    :array
    (do
      (buffer/push-string buf "@(")
      (each elt (drop 1 an-ast)
        (code* elt buf))
      (buffer/push-string buf ")"))
    :bracket-array
    (do
      (buffer/push-string buf "@[")
      (each elt (drop 1 an-ast)
        (code* elt buf))
      (buffer/push-string buf "]"))
    :bracket-tuple
    (do
      (buffer/push-string buf "[")
      (each elt (drop 1 an-ast)
        (code* elt buf))
      (buffer/push-string buf "]"))
    :tuple
    (do
      (buffer/push-string buf "(")
      (each elt (drop 1 an-ast)
        (code* elt buf))
      (buffer/push-string buf ")"))
    :struct
    (do
      (buffer/push-string buf "{")
      (each elt (drop 1 an-ast)
        (code* elt buf))
      (buffer/push-string buf "}"))
    :table
    (do
      (buffer/push-string buf "@{")
      (each elt (drop 1 an-ast)
        (code* elt buf))
      (buffer/push-string buf "}"))
    #
    :fn
    (do
      (buffer/push-string buf "|")
      (each elt (drop 1 an-ast)
        (code* elt buf)))
    :quasiquote
    (do
      (buffer/push-string buf "~")
      (each elt (drop 1 an-ast)
        (code* elt buf)))
    :quote
    (do
      (buffer/push-string buf "'")
      (each elt (drop 1 an-ast)
        (code* elt buf)))
    :splice
    (do
      (buffer/push-string buf ";")
      (each elt (drop 1 an-ast)
        (code* elt buf)))
    :unquote
    (do
      (buffer/push-string buf ",")
      (each elt (drop 1 an-ast)
        (code* elt buf)))
    ))

(defn code
  [an-ast]
  (let [buf @""]
    (code* an-ast buf)
    (string buf)))

(comment

  (code
    [:code])
  # => ""

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
    [:long-buffer "@```looooong buffer```"])
  # => "@```looooong buffer```"

  (code
    [:long-string "```longish string```"])
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
    '(:bracket-array
       (:keyword ":a") (:whitespace " ")
       (:keyword ":b")))
  # => "@[:a :b]"

  (code
    '@(:bracket-tuple
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

    # 33 ms per
    (let [start (os/time)]
      (each i (range 1000)
        (let [src
              (slurp (string (os/getenv "HOME")
                             "/src/janet/src/boot/boot.janet"))]
          (= src
             (code (ast src)))))
      (print (- (os/time) start)))

    )

  )
