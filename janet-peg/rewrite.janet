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
  # =>
  nil

  (peg/match jg-capture-ast ".0")
  # =>
  @[[:number ".0"]]

  (peg/match jg-capture-ast "@\"i am a buffer\"")
  # =>
  @[[:buffer "@\"i am a buffer\""]]

  (peg/match jg-capture-ast "# hello")
  # =>
  @[[:comment "# hello"]]

  (peg/match jg-capture-ast ":a")
  # =>
  @[[:keyword ":a"]]

  (peg/match jg-capture-ast "@``i am a long buffer``")
  # =>
  @[[:long-buffer "@``i am a long buffer``"]]

  (peg/match jg-capture-ast "``hello``")
  # =>
  @[[:long-string "``hello``"]]

  (peg/match jg-capture-ast "\"\\u0001\"")
  # =>
  @[[:string "\"\\u0001\""]]

  (peg/match jg-capture-ast "|(+ $ 2)")
  # =>
  '@[(:fn
       (:tuple
         (:symbol "+") (:whitespace " ")
         (:symbol "$") (:whitespace " ")
         (:number "2")))]

  (peg/match jg-capture-ast "@{:a 1}")
  # =>
  '@[(:table
       (:keyword ":a") (:whitespace " ")
       (:number "1"))]

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

  (ast "(+ 1 1)")
  # =>
  '@[:code
     (:tuple
       (:symbol "+") (:whitespace " ")
       (:number "1") (:whitespace " ")
       (:number "1"))]

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
  # =>
  ""

  (code
    [:code
     [:buffer "@\"buffer me\""]])
  # =>
  `@"buffer me"`

  (code
    [:comment "# i am a comment"])
  # =>
  "# i am a comment"

  (code
    [:long-string "```longish string```"])
  # =>
  "```longish string```"

  (code
    '(:fn
       (:tuple
         (:symbol "-") (:whitespace " ")
         (:symbol "$") (:whitespace " ")
         (:number "8"))))
  # =>
  "|(- $ 8)"

  (code
    '(:array
       (:keyword ":a") (:whitespace " ")
       (:keyword ":b")))
  # =
  "@(:a :b)"

  (code
    '@(:struct
       (:keyword ":a") (:whitespace " ")
       (:number "1")))
  # =>
  "{:a 1}"

  )

(comment

  (def src "{:x  :y \n :z  [:a  :b    :c]}")

  (code (ast src))
  # =>
  src

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
