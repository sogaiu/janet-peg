(import ../janet-peg/zip-support :as s)

(def rng
  (math/rng (or (os/getenv "JUDGE_GEN_SEED")
                (os/cryptorand 8))))

(def animals
  [:ant :bee :cat :dog :ewe :fox :goat :hippo :ibis :jackal])

# butlast
(comment

  # non-empty sequences
  (def n # >= 1
    (->> (length animals)
         (math/rng-int rng)
         inc))

  (def some-friends
    (let [choices
          (->> animals
               (filter (fn [_]
                         (< (math/rng-uniform rng) 0.5))))]
      # ensure at least one element
      (if (pos? (length choices))
        choices
        [:fox])))

  (def one-less-friend
    (s/butlast some-friends))

  # result should have one less element
  (= (length one-less-friend)
     (dec (length some-friends)))
  # => true

  # all remaining elements should be the same and in the same order
  (all true?
       (map =
            one-less-friend some-friends))
  # => true

  # input and output type should match
  (= (type some-friends)
     (type one-less-friend))
  # => true

  )

# rest
(comment

  # non-empty sequences
  (def n # >= 1
    (->> (length animals)
         (math/rng-int rng)
         inc))

  (def some-friends
    (let [choices
          (->> animals
               (filter (fn [_]
                         (< (math/rng-uniform rng) 0.5))))]
      # ensure at least one element
      (if (pos? (length choices))
        choices
        [:fox])))

  (def one-less-friend
    (s/rest some-friends))

  # result should have one less element
  (= (length one-less-friend)
     (dec (length some-friends)))
  # => true

  # all remaining elements should be the same but shifted by one
  (all true?
       (map =
            one-less-friend
            (drop 1 some-friends)))
  # => true

  # input and output type should match
  (= (type some-friends)
     (type one-less-friend))
  # => true

  )

# tuple-push
(comment

  # non-empty sequences
  (def n # >= 1
    (->> (length animals)
         (math/rng-int rng)
         inc))

  (def some-friends
    (let [choices
          (->> animals
               (filter (fn [_]
                         (< (math/rng-uniform rng) 0.5))))]
      # ensure at least one element
      (if (pos? (length choices))
        choices
        [:fox])))

  (def one-more-friend
    (s/tuple-push some-friends :kangaroo))

  # result should have one more element
  (= (length one-more-friend)
     (inc (length some-friends)))
  # => true

  # except for new element, elements should be the same and in order
  (all true?
       (map =
            one-more-friend
            some-friends))
  # => true

  # result should be a tuple
  (= (type one-more-friend)
     :tuple)
  # => true

  )

# first-rest-maybe-all
(comment

  # non-empty sequences
  (def n # >= 1
    (->> (length animals)
         (math/rng-int rng)
         inc))

  (def some-friends
    (let [choices
          (->> animals
               (filter (fn [_]
                         (< (math/rng-uniform rng) 0.5))))]
      # ensure at least one element
      (if (pos? (length choices))
        choices
        [:fox])))

  (def [f r a]
    (s/first-rest-maybe-all some-friends))

  (deep= (get a 0)
         f)
  # => true

  # the length of `r` should be one less than that of `a`
  (= (inc (length r))
     (length a))
  # => true

  # `r` is `a` without its first element
  (all true?
       (map =
            r
            (drop 1 a)))
  # => true

  # the types of `a`, `r`, and the input should be the same
  (= (type a)
     (type r)
     (type some-friends))
  # => true

  )
