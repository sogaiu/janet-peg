# based on code by corasaurus-hex

(import ./zip-support :as s)

(defn zip
  ``
  Returns a zipper location (zloc or z-location) for a tree
  representing Janet code.
  ``
  [tree]
  [tree nil])

(comment

  (zip @[:code [:number "8"]])
  # => '(@[:code (:number "8")] nil)

  )

(defn node
  "Returns the node at `zloc`."
  [zloc]
  (zloc 0))

(comment

  (node (zip @[:code [:number "8"]]))
  # => '@[:code (:number "8")]

  )

(defn has-children?
  ``
  Returns true if `node` can have children.
  Returns false if `node` cannot have children.
  ``
  [node]
  (when-let [[head] node]
    (truthy? (get {:code true
                   :fn true
                   :quasiquote true
                   :quote true
                   :splice true
                   :unquote true
                   :array true
                   :tuple true
                   :bracket-array true
                   :bracket-tuple true
                   :table true
                   :struct true}
                  head))))

(comment

  (has-children?
    [:tuple
     [:symbol "+"] [:whitespace " "]
     [:number "1"] [:whitespace " "]
     [:number "2"]])
  # => true

  (has-children? [:number "8"])
  # => false

  )

(defn branch?
  ``
  Returns true if the node at `zloc` is a branch.
  Returns false otherwise.
  ``
  [zloc]
  (let [the-node (node zloc)]
    (truthy? (and (indexed? the-node)
                  (not (empty? the-node))
                  (has-children? the-node)))))

(comment

  (branch?
    (zip @[:code
           [:tuple
            [:symbol "+"] [:whitespace " "]
            [:number "1"] [:whitespace " "]
            [:number "2"]]]))
  # => true

  )

(defn children
  ``
  Returns children for a branch node at `zloc`.
  Otherwise throws an error.
  ``
  [zloc]
  (if (branch? zloc)
    (slice (node zloc) 1)
    (error "Called `children` on a non-branch zloc")))

(comment

  (deep=
    #
    (children
      (zip @[:code
             [:tuple
              [:symbol "+"] [:whitespace " "]
              [:number "1"] [:whitespace " "]
              [:number "2"]]]))
    #
    '((:tuple
        [:symbol "+"] [:whitespace " "]
        (:number "1") (:whitespace " ")
        (:number "2"))))
  # => true

  )

(defn down
  ``
  Moves down the tree, returning the leftmost child z-location of
  `zloc`, or nil if there are no children.
  ``
  [zloc]
  (when (branch? zloc)
    (let [[node st] zloc
          [k rest-kids kids]
          (s/first-rest-maybe-all (children zloc))]
      (when kids
        [k
         @{:ls []
           :pnodes (if st
                     (s/tuple-push (st :pnodes) node)
                     [node])
           :pstate st
           :rs rest-kids}]))))

(comment

  (deep=
    #
    (-> @[:code
          [:tuple
           [:symbol "+"] [:whitespace " "]
           [:number "1"] [:whitespace " "]
           [:number "2"]]]
        zip
        down
        node)
    #
    '(:tuple
       (:symbol "+") (:whitespace " ")
       (:number "1") (:whitespace " ")
       (:number "2")))
  # => true

  (-> @[:code
        [:bracket-tuple
         [:number "1"] [:whitespace " "]
         [:number "2"]]]
      zip
      down
      down
      node)
  # => [:number "1"]

  )

(defn zip-down
  ``
  Convenience function that returns a zipper which has
  already had `down` called on it.
  ``
  [tree]
  (-> (zip tree)
      down))

(comment

  (import ./rewrite :as r)

  (deep=
    #
    (-> (r/ast "(+ 1 3)")
        zip-down
        node)
    #
    '(:tuple
       (:symbol "+") (:whitespace " ")
       (:number "1") (:whitespace " ")
       (:number "3")))
  # => true

  )

(defn state
  "Returns the state for `zloc`."
  [zloc]
  (zloc 1))

(comment

  (-> @[:code
        [:tuple
         [:number "1"] [:whitespace " "]
         [:number "2"]]]
      zip
      state)
  # => nil

  (deep=
    #
    (-> @[:code
          [:tuple
           [:number "1"] [:whitespace " "]
           [:number "2"]]]
        zip-down
        down
        state)
    #
    '@{:ls ()
       :pnodes (@[:code
                  (:tuple
                    (:number "1") (:whitespace " ")
                    (:number "2"))]
                 (:tuple
                   (:number "1") (:whitespace " ")
                   (:number "2")))
       :pstate @{:ls ()
                 :pnodes (@[:code
                            (:tuple
                              (:number "1") (:whitespace " ")
                              (:number "2"))])
                 :rs ()}
       :rs ((:whitespace " ") (:number "2"))})
  # => true

  )

(defn right
  ``
  Returns the z-location of the right sibling of the node
  at `zloc`, or nil if there is no such sibling.
  ``
  [zloc]
  (let [[node st] zloc
        {:ls ls :rs rs} (or st @{})
        [r rest-rs rs] (s/first-rest-maybe-all rs)]
    (when (and st rs)
      [r
       (merge st
              {:ls (s/tuple-push ls node)
               :rs rest-rs})])))

(comment

  (-> @[:code
        [:number "1"] [:whitespace "\n"]
        [:number "2"]]
      zip-down
      right
      right
      node)
  # => [:number "2"]

  )

(defn right-until
  ``
  Try to move right from `zloc`, calling `pred` for each
  right sibling.  If the `pred` call has a truthy result,
  return the corresponding right sibling.
  Otherwise, return nil.
  ``
  [zloc pred]
  (when-let [right-sib (right zloc)]
    (if (pred right-sib)
      right-sib
      (right-until right-sib pred))))

(comment

  (def r-node
    [:code
     [:tuple
      [:comment "# hi there"] [:whitespace "\n"]
      [:symbol "+"] [:whitespace " "]
      [:number "1"] [:whitespace " "]
      [:number "2"]]])

  (-> r-node
      zip-down
      down
      (right-until |(match (node $)
                      [:comment _]
                      false
                      #
                      [:whitespace _]
                      false
                      #
                      true))
      node)
  # => [:symbol "+"]

  )

# wsc == whitespace, comment
(defn right-skip-wsc
  ``
  Try to move right from `zloc`, skipping over whitespace
  and comment nodes. XXX
  ``
  [zloc]
  (right-until zloc
               |(match (node $)
                  [:whitespace _]
                  false
                  #
                  [:comment _]
                  false
                  #
                  true)))

(comment

  (import ./rewrite :as r)

  (-> (r/ast
        ``
        (# hi there
        + 1 2)
        ``)
      zip-down
      down
      right-skip-wsc
      node)
  # => [:symbol "+"]

  )

(defn left
  ``
  Returns the z-location of the left sibling of the node
  at `zloc`, or nil if there is no such sibling.
  ``
  [zloc]
  (let [[node st] zloc
        {:ls ls :rs rs} (or st @{})]
    (when (and st
               (indexed? ls)
               (not (empty? ls)))
      [(last ls)
       (merge st {:ls (s/butlast ls)
                  :rs [node ;rs]})])))

(comment

  (-> @[:code
        [:tuple
         [:number "1"] [:whitespace " "]
         [:number "2"]]]
      zip-down
      down
      right-skip-wsc
      left
      left
      node)
  # => [:number "1"]

  )

(defn left-until
  [zloc pred]
  (when-let [left-sib (left zloc)]
    (if (pred left-sib)
      left-sib
      (left-until left-sib pred))))

(comment

  (import ./rewrite :as r)

  (-> (r/ast
        ``
        (# hi there
        + 1 2)
        ``)
      zip-down
      down
      right-skip-wsc
      right-skip-wsc
      (left-until |(match (node $)
                      [:comment _]
                      false
                      #
                      [:whitespace _]
                      false
                      #
                      true))
      node)
  # => [:symbol "+"]

  )

(defn left-skip-wsc
  [zloc]
  (left-until zloc
               |(match (node $)
                  [:whitespace _]
                  false
                  #
                  [:comment _]
                  false
                  #
                  true)))

(comment

  (import ./rewrite :as r)

  (-> (r/ast
        ``
        (# hi there
        + 1 2)
        ``)
      zip-down
      down
      right-skip-wsc
      right-skip-wsc
      left-skip-wsc
      node)
  # => [:symbol "+"]

  )

# XXX: doesn't use `zloc` parameter
(defn make-node
  ``
  Returns a branch node, given `node` and `children`.
  ``
  [zloc node children]
  [(first node) ;children])

(comment

  (def r-node
    [:code
     [:tuple
      [:number "1"] [:whitespace " "]
      [:number "2"]]])

  (deep=
    #
    (make-node (zip r-node)
               r-node [[:tuple
                        [:symbol "+"] [:whitespace " "]
                        [:number "1"] [:whitespace " "]
                        [:number "2"]]])
    #
    '[:code
      [:tuple
       [:symbol "+"] [:whitespace " "]
       [:number "1"] [:whitespace " "]
       [:number "2"]]])
  # => true

  )

(defn up
  ``
  Moves up the tree, returning the parent z-location of `zloc`,
  or nil if at the root z-location.
  ``
  [zloc]
  (let [[node st] zloc
        {:ls ls
         :pnodes pnodes
         :pstate pstate
         :rs rs
         :changed? changed?}
        (or st @{})]
    (when pnodes
      (let [pnode (last pnodes)]
        (if changed?
          [(make-node zloc pnode [;ls node ;rs])
           (and pstate (merge pstate {:changed? true}))]
          [pnode pstate])))))

(comment

  (def code-node
    @[:code
      [:tuple
       [:number "1"] [:whitespace " "]
       [:number "2"]]])

  (deep= code-node
         (-> code-node
             zip-down
             up
             node))
  # => true

  (deep= (zip code-node)
         (-> code-node
             zip-down
             up))
  # => true

  (deep= (zip code-node)
         (-> code-node
             zip-down
             down
             right-skip-wsc
             up
             up))
  # => true

  )

# XXX: only used by `root` and `df-next`?
(defn end?
  "Returns true if `zloc` represents the end of a depth-first walk."
  [zloc]
  (= :end (state zloc)))

(defn root
  ``
  Moves all the way up the tree for `zloc` and returns the node at
  the root z-location.
  ``
  [zloc]
  (if (end? zloc)
    (node zloc)
    (if-let [p (up zloc)]
      (root p)
      (node zloc))))

(comment

  (def r-node
    [:code
     [:tuple
      [:symbol "+"] [:whitespace " "]
      [:number "1"] [:whitespace " "]
      [:number "2"]]])

  (deep=
    #
    r-node
    #
    (-> r-node
        zip-down
        down
        right-skip-wsc
        left
        left
        root))
  # => true

  )

(defn df-next
  ``
  Moves to the next z-location, depth-first.  When the end is
  reached, returns a special z-location detectable via `end?`.
  Does not move if already at the end.
  ``
  [zloc]
  (defn recur
    [a-zloc]
    (if (up a-zloc)
      (or (right (up a-zloc))
          (recur (up a-zloc)))
      [(node a-zloc) :end]))
  (if (end? zloc)
    zloc
    (or (and (branch? zloc) (down zloc))
        (right zloc)
        (recur zloc))))

(comment

  (def r-node
    [:code
     [:tuple
      [:symbol "+"] [:whitespace " "]
      [:number "1"] [:whitespace " "]
      [:number "2"]]])

  (def r-zip
    (zip r-node))

  (deep=
    #
    (-> (df-next r-zip)
        node)
    #
    '(:tuple
       (:symbol "+") (:whitespace " ")
       (:number "1") (:whitespace " ")
       (:number "2")))
  # => true

  )

(defn rightmost
  ``
  Returns the z-location of the rightmost sibling of the node at
  `zloc`, or the current node's z-location if there are none to the
  right.
  ``
  [zloc]
  (let [[node st] zloc
        {:ls ls :rs rs} (or st @{})]
    (if (and st
             (indexed? rs)
             (not (empty? rs)))
      [(last rs)
       (merge st {:ls (s/tuple-push ls node ;(s/butlast rs))
                  :rs []})]
      zloc)))

(comment

  (-> [:code
       [:tuple
        [:symbol "+"] [:whitespace " "]
        [:number "1"] [:whitespace " "]
        [:number "2"]]]
      zip-down
      down
      rightmost
      node)
  # => [:number "2"]

  (import ./rewrite :as r)

  (-> "(+ 1 (/ 2 3))"
      r/ast
      zip-down
      down
      right-skip-wsc
      right-skip-wsc
      down
      rightmost
      node)
  # => [:number "3"]

  )

(defn replace
  "Replaces existing node at `zloc` with `node`, without moving."
  [zloc node]
  (let [[_ st] zloc
        st (or st @{})]
    [node
     (merge st {:changed? true})]))

(comment

  (import ./rewrite :as r)

  (-> [:code
       [:tuple
        [:symbol "+"] [:whitespace " "]
        [:number "1"] [:whitespace " "]
        [:number "2"]]]
      zip-down
      down
      (replace [:symbol "-"])
      root
      r/code)
  # => "(- 1 2)"

  )

(defn edit
  "Replaces the node at `zloc` with the value of `(f node args)`."
  [zloc f & args]
  (replace zloc
           (apply f (node zloc) args)))

(comment

  (import ./rewrite :as r)

  (-> [:code
       [:tuple
        [:symbol "+"] [:whitespace " "]
        [:number "1"] [:whitespace " "]
        [:number "2"]]]
      zip-down
      down
      right-skip-wsc
      (edit |(match $
               [:number num-str]
               [:number (-> num-str
                            scan-number
                            inc
                            string)]))
      root
      r/code)
  # => "(+ 2 2)"

  )

(defn search
  ``
  Successively call `pred` on z-locations starting at `zloc`
  in depth-first order.  If a call to `pred` returns a
  truthy value, return the corresponding z-location.
  Otherwise, return nil.
  ``
  [zloc pred]
  (when-let [next-zloc (df-next zloc)]
    (if (pred next-zloc)
      next-zloc
      (search next-zloc pred))))

(comment

  (import ./rewrite :as r)

  (def r-node
    [:code
     [:tuple
      [:symbol "+"] [:whitespace " "]
      [:number "1"] [:whitespace " "]
      [:number "2"]]])

  (-> r-node
      zip
      (search |(match (node $)
                 [:symbol "+"]
                 true))
      right-skip-wsc
      node)
  # => [:number "1"]

  )

(defn remove
  [zloc]
  ``
  Removes the node at `zloc`, returning the z-location that would have
  preceded it in a depth-first walk.
  Throws an error if called at the root z-location.
  ``
  [zloc]
  (let [[node st] zloc
        {:ls ls
         :pnodes pnodes
         :pstate pstate
         :rs rs}
        (or st @{})]
    #
    (defn recur
      [a-zloc]
      (if-let [child (and (branch? a-zloc) (down a-zloc))]
        (recur (rightmost child))
        a-zloc))
    #
    (if st
      (if (pos? (length ls))
        (recur [(last ls)
                (merge st {:ls (s/butlast ls)
                           :changed? true})])
        [(make-node zloc (last pnodes) rs)
         (and pstate (merge pstate {:changed? true}))])
      (error "Called `remove` at root"))))

(comment

  (import ./rewrite :as r)

  (-> [:code
       [:tuple
        [:symbol "+"] [:whitespace " "]
        [:number "1"] [:whitespace " "]
        [:number "2"] [:whitespace " "]
        [:number "3"]]]
      zip-down
      down
      rightmost
      remove
      remove
      root
      r/code)
  # => "(+ 1 2)"

  )

(defn append-child
  ``
  Appends `item` as the rightmost child of the node at `zloc`,
  without moving.
  ``
  [zloc item]
  (replace zloc
           (make-node zloc
                      (node zloc)
                      [;(children zloc) item])))

(comment

  (import ./rewrite :as r)

  (-> [:code
       [:tuple
        [:symbol "+"] [:whitespace " "]
        [:number "1"] [:whitespace " "]
        [:number "2"]]]
      zip-down
      (append-child [:whitespace " "])
      (append-child [:number "3"])
      root
      r/code)
  # => "(+ 1 2 3)"

  )

(defn insert-right
  ``
  Inserts `item` as the right sibling of the node at `zloc`,
  without moving.
  Throws an error if called at the root z-location.
  ``
  [zloc item]
  (let [[node st] zloc
        {:rs rs} (or st @{})]
    (if st
      [node
       (merge st {:rs [item ;rs]
                  :changed? true})]
      (error "Called `insert-right` at root"))))

(comment

  (import ./rewrite :as r)

  (-> [:code
       [:tuple
        [:symbol "+"] [:whitespace " "]
        [:number "1"]]]
      zip-down
      down
      rightmost
      (insert-right [:whitespace " "])
      right
      (insert-right [:number "2"])
      root
      r/code)
  # => "(+ 1 2)"

  )

(defn insert-left
  ``
  Inserts `item` as the left sibling of the node at `zloc`,
  without moving.
  Throws an error if called at the root z-location.
  ``
  [zloc item]
  (let [[node st] zloc
        {:ls ls} (or st @{})]
    (if st
      [node
       (merge st {:ls (s/tuple-push ls item)
                  :changed? true})]
      (error "Called `insert-left` at root"))))

(comment

  (import ./rewrite :as r)

  (-> [:code
       [:tuple
        [:symbol "+"] [:whitespace " "]
        [:number "1"]]]
      zip-down
      down
      rightmost
      (insert-left [:number "2"])
      (insert-left [:whitespace " "])
      root
      r/code)
  # => "(+ 2 1)"

  )

# XXX: haven't yet had a use for things below here

(defn lefts
  "Returns the siblings to the left of `zloc`."
  [zloc]
  (if-let [st (state zloc)
           ls (st :ls)]
    ls
    []))

(comment

  (-> [:code
       [:tuple
        [:symbol "+"] [:whitespace " "]
        [:number "1"]]]
      zip-down
      down
      rightmost
      lefts)
  # => [[:symbol "+"] [:whitespace " "]]

  (import ./rewrite :as r)

  (-> "(+ 1 2)"
      r/ast
      zip-down
      down
      lefts)
  # => []

  (deep=
    #
    (-> "(+ (- 8 1) 2)"
        r/ast
        zip-down
        down
        right-skip-wsc
        down
        rightmost # 1
        lefts)
    #
    '[(:symbol "-") (:whitespace " ")
      (:number "8") (:whitespace " ")])
  # => true

  )

(defn rights
  "Returns the siblings to the right of `zloc`."
  [zloc]
  (when-let [st (state zloc)]
    (st :rs)))

(comment

  (-> [:code
       [:tuple
        [:symbol "+"] [:whitespace " "]
        [:number "1"]]]
      zip-down
      down
      rights)
  # => [[:whitespace " "] [:number "1"]]

  (import ./rewrite :as r)

  (-> "(+ 1 2)"
      r/ast
      zip-down
      down
      rightmost
      rights)
  # => []

  (deep=
    #
    (-> "(+ (- 8 1) 2)"
        r/ast
        zip-down
        down
        right-skip-wsc
        down
        rights)
    #
    '[(:whitespace " ")
      (:number "8") (:whitespace " ")
      (:number "1")])
  # => true

  )

(defn leftmost
  ``
  Returns the z-location of the leftmost sibling of the node at `zloc`,
  or the current node's z-location if there are no siblings to the left.
  ``
  [zloc]
  (let [[node st] zloc
        {:ls ls :rs rs} (or st @{})]
    (if (and st
             (indexed? ls)
             (not (empty? ls)))
      [(first ls)
       (merge st {:ls []
                  :rs [;(s/rest ls) node ;rs]})]
      zloc)))

(comment

  (import ./rewrite :as r)

  (-> "(+ 1 2)"
      r/ast
      zip-down
      down
      leftmost
      node)
  # => [:symbol "+"]

  (-> "(+ 1 2)"
      r/ast
      zip-down
      down
      rightmost
      leftmost
      node)
  # => [:symbol "+"]

  (-> "(+ (* 8 9) 2)"
      r/ast
      zip-down
      down
      right-skip-wsc
      down
      leftmost
      node)
  # => [:symbol "*"]

  )

(defn path
  "Returns the path of nodes that lead to `zloc` from the root node."
  [zloc]
  (when-let [st (state zloc)]
    (st :pnodes)))

(comment

  (import ./rewrite :as r)

  (-> "(+ 1 2)"
      r/ast
      zip
      path)
  # => nil

  (deep=
    #
    (-> "(+ 1 2)"
        r/ast
        zip-down
        path)
    #
    '(@[:code
        (:tuple
          (:symbol "+") (:whitespace " ")
          (:number "1") (:whitespace " ")
          (:number "2"))]))
  # => true

  (deep=
    #
    (-> "(+ (/ 3 8) 2)"
        r/ast
        zip-down
        down
        right-skip-wsc
        down
        path)
    #
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
         (:number "8"))))
  # => true

  )

(defn insert-child
  ``
  Inserts `item` as the leftmost child of the node at `zloc`,
  without moving.
  ``
  [zloc item]
  (replace zloc
           (make-node zloc
                      (node zloc)
                      [item ;(children zloc)])))

(comment

  (import ./rewrite :as r)

  (-> [:code
       [:tuple
        [:whitespace " "]
        [:number "1"] [:whitespace " "]
        [:number "2"]]]
      zip-down
      (insert-child [:symbol "+"])
      root
      r/code)
  # => "(+ 1 2)"

  (-> "(1 2)"
      r/ast
      zip-down
      (insert-child [:whitespace " "])
      (insert-child [:symbol "/"])
      root
      r/code)
  # => "(/ 1 2)"

  )

(defn df-prev
  ``
  Moves to the previous z-location in the hierarchy, depth-first.
  If already at the root, returns nil.
  ``
  [zloc]
  #
  (defn recur
    [a-zloc]
    (if-let [child (and (branch? a-zloc)
                        (down a-zloc))]
      (recur (rightmost child))
      a-zloc))
  #
  (if-let [left-loc (left zloc)]
    (recur left-loc)
    (up zloc)))

(comment

  (import ./rewrite :as r)

  (def c-ast
    (r/ast "(+ 1 (- 2 8))"))

  (deep=
    #
    c-ast
    #
    '@[:code
       [:tuple
        [:symbol "+"] [:whitespace " "]
        [:number "1"] [:whitespace " "]
        [:tuple
         [:symbol "-"] [:whitespace " "]
         [:number "2"] [:whitespace " "]
         [:number "8"]]]])
  # => true

  (def x-zip
    (zip-down c-ast))

  (-> x-zip
      down
      right
      df-prev
      node)
  # => [:symbol "+"]

  (-> x-zip
      down
      right-skip-wsc
      df-prev
      node)
  # => [:whitespace " "]

  (deep=
    #
    (-> x-zip
        down
        right-skip-wsc
        right-skip-wsc
        down
        df-prev
        node)
    #
    '(:tuple
       (:symbol "-") (:whitespace " ")
       (:number "2") (:whitespace " ")
       (:number "8")))
    # => true

  (-> x-zip
      down
      right-skip-wsc
      right-skip-wsc
      down
      df-prev
      df-prev
      node)
  # => [:whitespace " "]

  )
