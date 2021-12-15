(import ../janet-peg/rewrite :prefix "")

# jg-capture-ast
(comment

  (peg/match jg-capture-ast ".0a")
  # => @[[:symbol ".0a"]]

  (peg/match jg-capture-ast "foo:bar")
  # => @[[:symbol "foo:bar"]]

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

  (peg/match jg-capture-ast "8")
  # => @[[:number "8"]]

  (peg/match jg-capture-ast "a")
  # => @[[:symbol "a"]]

  (peg/match jg-capture-ast " ")
  # => @[[:whitespace " "]]

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

# ast
(comment

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

# code
(comment

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
    [:string "\"a string\""])
  # => "\"a string\""

  (code
    [:symbol "non-descript-symbol"])
  # => "non-descript-symbol"

  (code
    [:whitespace "\n"])
  # => "\n"

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
    '@(:tuple
       (:keyword ":a") (:whitespace " ")
       (:keyword ":b")))
  # => "(:a :b)"

  )
