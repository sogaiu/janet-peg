(import ./zipper :as z)

# XXX: brittle wrt whitespace and comment handling
(defn absorb-right
  [loc]
  (def t-node
    (-> loc
        z/right-skip-wsc
        z/node))
  #
  (-> loc
      (z/append-child [:whitespace " "])
      (z/append-child t-node)
      z/right-skip-wsc
      z/remove # next thing
      z/remove # outer whitespace
      z/up))

(comment

  (import ./rewrite :as r)

  (-> (absorb-right (-> "(+ 1 2) 3"
                        r/ast
                        z/zip
                        z/down))
      z/root
      r/code)
  # => "(+ 1 2 3)"

  )

# XXX: brittle wrt whitespace and comment handling
(defn eject-right
  [loc]
  (def t-node (-> loc
                  z/down
                  z/rightmost
                  z/node))
  #
  (-> loc
      (z/insert-right t-node)
      (z/insert-right [:whitespace " "])
      z/down
      z/rightmost
      z/remove
      z/remove
      z/up))

(comment

  (import ./rewrite :as r)

  (-> (eject-right (-> "(+ 1 2 :a)"
                        r/ast
                        z/zip
                        z/down))
      z/root
      r/code)
  # => "(+ 1 2) :a"

  )

(comment

  # wrap
  #   insert-left empty container before first thing to wrap
  #   for each thing to wrap, use insert-right to insert into new container
  #   delete each thing after now not-empty container that was inserted

  (def code "+ x 1")

  (def a-zip
    (-> code
        r/ast
        z/zip))

  # alt
  #   insert-left empty container before first thing to wrap
  #   absorb each item into container

  (-> a-zip
      z/down
      z/right
      (z/insert-left [:tuple])
      (z/insert-left [:whitespace " "])
      z/left
      z/left
      absorb-right
      absorb-right
      absorb-right
      # remove extra whitespace before head element
      z/down
      z/right
      z/remove
      z/root
      r/code)

  )

(comment

  # unwrap
  #   for each item in the container to unwrap, use insert-left
  #   to cause a copy to appear to the left of the container
  #   once all contained items have been "processed", delete the
  #   container

  # alt
  #   eject-right each child in container
  #   remove empty container at end

  )
