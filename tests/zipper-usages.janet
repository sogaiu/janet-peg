(import ../janet-peg/zipper :as z)
(import ../janet-peg/rewrite :as r)

# zip
(comment

  (def a-node
    @[:code
      [:tuple
       [:symbol "+"] [:whitespace " "]
       [:number "1"] [:whitespace " "]
       [:number "2"]]])

  (z/zip a-node)
  # =>
  [a-node nil]

  )

# node
(comment

  (def a-node
    @[:code
      [:tuple
       [:symbol "+"] [:whitespace " "]
       [:number "1"] [:whitespace " "]
       [:number "2"]]])

  (z/node (z/zip a-node))
  # =>
  a-node

  )

# has-children?
(comment

  (def a-node
    (r/ast "(+ 1 2)"))

  (z/has-children? a-node)
  # =>
  true

  (-> a-node
      z/zip
      z/down # [:tuple ...]
      z/node
      z/has-children?)
  # =>
  true

  (-> a-node
      z/zip-down
      z/down # [:symbol ...]
      z/node
      z/has-children?)
  # =>
  false

  )

# branch?
(comment

  (def a-zip
    (z/zip (r/ast "(min (+ 1 2) 9)")))

  (z/branch? a-zip)
  # =>
  true

  (-> a-zip
      z/down
      # [:tuple ...]
      z/branch?)
  # =>
  true

  (-> a-zip
      z/down
      z/down
      # [:symbol ...]
      z/branch?)
  # =>
  false

  (-> a-zip
      z/down
      z/down
      z/right-skip-wsc
      # [:tuple ...]
      z/branch?)
  # =>
  true

  )

# children
(comment

  (def code
    ``
    (do
      (print "hi")
      :smile)
    ``)

  (def a-zip
    (-> code
        r/ast
        z/zip-down))

  (-> a-zip
      z/children
      first)
  # =>
  [:symbol "do"]

  (-> a-zip
      z/down
      z/right-skip-wsc
      z/children
      first)
  # =>
  [:symbol "print"]

  )

# down
(comment

  (def code
    ``
    (do
      (print "hi")
      :smile)
    ``)

  (def a-zip
    (-> code
        r/ast
        z/zip))

  (-> a-zip
      z/down
      z/down
      z/node)
  # =>
  [:symbol "do"]

  (-> a-zip
      z/down
      z/down
      z/right-skip-wsc
      z/down
      z/node)
  # =>
  [:symbol "print"]

  (def b-zip
    (z/zip (r/ast "()")))

  (-> b-zip
      z/down
      z/down)
  # =>
  nil

  )

# zip-down
(comment

  (-> @[:code
        [:number "1"]]
      z/zip-down
      z/node)
  # =>
  [:number "1"]

  (def code
    ``
    (each i [1 2 3]
      (print i))
    ``)

  (-> code
      r/ast
      z/zip-down
      z/down
      z/right-skip-wsc
      z/right-skip-wsc
      z/down
      z/right-skip-wsc
      z/right-skip-wsc
      z/node)
  # =>
  [:number "3"]

  )

# state
(comment

  (def a-zip
    (z/zip-down (r/ast "(+ 0 7)")))

  (deep=
    #
    (-> a-zip
        z/state)
    #
    '@{:ls ()
       :pnodes (@[:code
                  (:tuple
                    (:symbol "+") (:whitespace " ")
                    (:number "0") (:whitespace " ")
                    (:number "7"))])
       :rs ()})
  # =>
  true

  (def b-zip
    (z/zip-down (r/ast "(++ i)")))

  (deep=
    #
    (-> b-zip
        z/down
        z/state)
    #
    '@{:ls ()
       :pnodes (@[:code
                  (:tuple
                    (:symbol "++") (:whitespace " ")
                    (:symbol "i"))]
                 (:tuple
                   (:symbol "++") (:whitespace " ")
                   (:symbol "i")))
       :pstate @{:ls ()
                 :pnodes (@[:code
                            (:tuple
                              (:symbol "++") (:whitespace " ")
                              (:symbol "i"))])
                 :rs ()}
       :rs ((:whitespace " ") (:symbol "i"))})
  # =>
  true

  )

# right
(comment

  (-> @[:code
        [:tuple
         [:number "1"] [:whitespace " "]
         [:number "2"]]]
      z/zip-down
      z/down
      z/right
      z/node)
  # =>
  [:whitespace " "]

  (-> (r/ast ":skip-me [1 2 3 5 8]")
      z/zip-down
      z/right
      z/right
      z/down
      z/right
      z/right
      z/right
      z/right
      z/right
      z/right
      z/right
      z/right
      z/node)
  # =>
  [:number "8"]

  )

# right-until
(comment

  (def code
    ``
    [1
     # a comment
     2]
    ``)

  (-> code
      r/ast
      z/zip-down
      z/down
      (z/right-until |(match (z/node $)
                      [:comment _]
                      false
                      #
                      [:whitespace _]
                      false
                      #
                      true))
      z/node)
  # =>
  [:number "2"]

  (def code
    ``
    :skip-me

    [1
     # a comment
     2]
    ``)

  (-> code
      r/ast
      z/zip-down
      (z/right-until |(match (z/node $)
                      [:comment _]
                      false
                      #
                      [:whitespace _]
                      false
                      #
                      true))
      z/down
      (z/right-until |(match (z/node $)
                      [:comment _]
                      false
                      #
                      [:whitespace _]
                      false
                      #
                      true))
      z/node)
  # =>
  [:number "2"]

  )

# right-skip-wsc
(comment

  (def code
    ``
    :skip-me

    [1
     # a comment
     2]
    ``)

  (-> code
      r/ast
      z/zip-down
      z/right-skip-wsc
      z/down
      z/right-skip-wsc
      z/node)
  # =>
  [:number "2"]

  (-> "(defn my-fn [] (+ x 1))"
      r/ast
      z/zip-down
      z/down
      z/right-skip-wsc
      z/right-skip-wsc
      # XXX: moving down into [] yields nil...
      (z/insert-child [:symbol "x"])
      z/root
      r/code)
  # =>
  "(defn my-fn [x] (+ x 1))"

  )

# left-until
(comment

  (-> (r/ast
        ``
        {:a "hey"
         :b "see"
         :c "spot"
         :x "sit"
         :y "!?"}
        ``)
      z/zip-down
      z/down
      z/rightmost
      (z/left-until |(match (z/node $)
                       [:string]
                       true))
      z/node)
  # =>
  [:string `"sit"`]

  )

# left-skip-wsc
(comment

  (-> (r/ast
        ``
        [:alice :bob
         :carol :dan
         :eve :frank
         :grace :heidi
         # fine comment
         :ivan :judy]
        ``)
      z/zip-down
      z/down
      z/rightmost
      z/left-skip-wsc
      z/left-skip-wsc
      z/node)
  # =>
  [:keyword ":heidi"]

  )

# make-node
(comment

  # users of make-node:
  #
  # * up
  # * remove
  # * append-child
  # * insert-child

  )

# up
(comment

  (def code
    ``
    (+ 3
       (/ 2 8))
    ``)

  (-> (r/ast code)
      z/zip-down
      z/down
      z/right-skip-wsc
      z/right-skip-wsc
      z/down
      z/right-skip-wsc
      z/up
      z/up
      z/up
      z/node
      r/code
      (= code))
  # =>
  true

  )

# root
(comment

  (def code
    ``
    (+ 1 2)
    ``)

  (-> code
      r/ast
      z/zip-down
      z/down
      z/right-skip-wsc
      z/right-skip-wsc
      z/root
      r/code
      (= code))
  # =>
  true

  )

# df-next, end?
(comment

  (def a-zip
    (-> "(+ 1 2)"
        r/ast
        z/zip))

  (-> a-zip
      z/df-next
      z/df-next
      z/node)
  # =>
  [:symbol "+"]

  (-> a-zip
      z/df-next
      z/df-next
      z/df-next
      z/node)
  # =>
  [:whitespace " "]

  (-> a-zip
      z/df-next
      z/df-next
      z/df-next
      z/df-next
      z/node)
  # =>
  [:number "1"]

  (-> a-zip
      z/df-next
      z/df-next
      z/df-next
      z/df-next
      z/df-next
      z/node)
  # =>
  [:whitespace " "]

  (-> a-zip
      z/df-next
      z/df-next
      z/df-next
      z/df-next
      z/df-next
      z/df-next
      z/df-next
      z/end?)
  # =>
  true

  )

# rightmost
(comment

  (-> "[1 2 3 5 8 13 21]"
      r/ast
      z/zip-down
      z/down
      z/rightmost
      z/node)
  # =>
  [:number "21"]

  (-> "(def m {:a 1 :b 2})"
      r/ast
      z/zip-down
      z/down
      z/rightmost
      z/down
      z/rightmost
      z/node)
  # =>
  [:number "2"]

  )

# replace
(comment

  (-> "(+ 1 (/ 2 3))"
      r/ast
      z/zip-down
      z/down
      z/rightmost
      z/down
      z/rightmost
      (z/replace [:number "8"])
      z/root
      r/code)
  # =>
  "(+ 1 (/ 2 8))"

  )

# edit
(comment

  (-> "(+ 1 1)"
      r/ast
      z/zip-down
      z/down
      (z/edit |(match $
                 [:symbol "+"]
                 [:symbol "-"]))
      z/right-skip-wsc
      (z/edit |(match $
                 [:number num-str]
                 (-> "(/ 2 3)"
                     r/ast
                     z/zip-down
                     z/node)))
      z/root
      r/code)
  # =>
  "(- (/ 2 3) 1)"

  )

# search
(comment

  (-> "(+ 1 2)"
      r/ast
      z/zip
      (z/search |(match (z/node $)
                   [:number "1"]
                   true))
      (z/edit |(match $
                 [:number num-str]
                 [:number (-> num-str
                              scan-number
                              inc
                              string)]))
      z/root
      r/code)
  # =>
  "(+ 2 2)"

  )

# remove
(comment

  (-> "(def a b 1)"
      r/ast
      z/zip
      (z/search |(match (z/node $)
                   [:symbol "b"]
                   true))
      z/remove
      z/remove
      z/root
      r/code)
  # =>
  "(def a 1)"

  (try
    (-> "1"
        r/ast
        z/zip
        z/remove)
    ([e] e))
  # =>
  "Called `remove` at root"

  )

# append-child
(comment

  (-> "(def d {:a 1})"
      r/ast
      z/zip-down
      z/down
      z/rightmost
      (z/append-child [:whitespace " "])
      (z/append-child [:keyword ":b"])
      (z/append-child [:whitespace " "])
      (z/append-child [:number "2"])
      z/root
      r/code)
  # =>
  "(def d {:a 1 :b 2})"

  )

# insert-right
(comment

  (-> "(defn my-fn [x] (+ x y))"
      r/ast
      z/zip-down
      z/down
      (z/search |(match (z/node $)
                   [:bracket-tuple [:symbol "x"]]
                   true))
      z/down
      (z/insert-right [:symbol "y"])
      (z/insert-right [:whitespace " "])
      z/root
      r/code)
  # =>
  "(defn my-fn [x y] (+ x y))"

  (try
    (-> "(+ 1 3)"
        r/ast
        z/zip
        (z/insert-right [:keyword ":oops"]))
    ([e] e))
  # =>
  "Called `insert-right` at root"

  )

# insert-left
(comment

  (-> "(a 1)"
      r/ast
      z/zip-down
      z/down
      (z/insert-left [:symbol "def"])
      (z/insert-left [:whitespace " "])
      z/root
      r/code)
  # =>
  "(def a 1)"

  (try
    (-> "(/ 8 9)"
        r/ast
        z/zip
        (z/insert-left [:keyword ":oops"]))
    ([e] e))
  # =>
  "Called `insert-left` at root"

  )

# lefts
(comment

  (deep=
    #
    (-> "(+ (- 8 1) 2)"
        r/ast
        z/zip-down
        z/down
        z/right-skip-wsc
        z/down
        z/rightmost # 1
        z/lefts)
    #
    '[(:symbol "-") (:whitespace " ")
      (:number "8") (:whitespace " ")])
  # =>
  true

  )

# rights
(comment

  (-> "(+ (- 8 1) 2)"
      r/ast
      z/zip-down
      z/down
      z/right-skip-wsc
      z/down
      z/rights)
  # =>
  '[(:whitespace " ")
    (:number "8") (:whitespace " ")
    (:number "1")]

  )

# leftmost
(comment

  (-> "(+ 1 2)"
      r/ast
      z/zip-down
      z/down
      z/rightmost
      z/leftmost
      z/node)
  # =>
  [:symbol "+"]

  (-> "(+ (* 8 9) 2)"
      r/ast
      z/zip-down
      z/down
      z/right-skip-wsc
      z/down
      z/leftmost
      z/node)
  # =>
  [:symbol "*"]

  )

# path
(comment

  (-> "(+ (/ 3 8) 2)"
      r/ast
      z/zip-down
      z/down
      z/right-skip-wsc
      z/down
      z/path)
  # =>
  '(@[:code
      (:tuple
        (:symbol "+") (:whitespace " ")
        (:tuple
          (:symbol "/") (:whitespace " ")
          (:number "3") (:whitespace " ")
          (:number "8"))
        (:whitespace " ") (:number "2"))]
     (:tuple
       (:symbol "+") (:whitespace " ")
       (:tuple
         (:symbol "/") (:whitespace " ")
         (:number "3") (:whitespace " ")
         (:number "8"))
       (:whitespace " ") (:number "2"))
     (:tuple
       (:symbol "/") (:whitespace " ")
       (:number "3") (:whitespace " ")
       (:number "8")))

  )
