(import ../janet-peg/zip-support :as s)

(def rng
  (math/rng (or (os/getenv "JUDGE_GEN_SEED")
                (os/cryptorand 8))))

(def animals
  [:ant :bee :cat :dog :ewe :fox :goat :hippo :ibis :jackal])

(comment

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

  (= (length one-less-friend)
     (dec (length some-friends)))
  # => true

  (all true?
       (map =
            one-less-friend some-friends))
  # => true

  (= (type some-friends)
     (type one-less-friend))
  # => true

  )

(comment

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

  (= (length one-less-friend)
     (dec (length some-friends)))
  # => true

  (all true?
       (map =
            one-less-friend
            (drop 1 some-friends)))
  # => true

  (= (type some-friends)
     (type one-less-friend))
  # => true

  )

(comment

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

  (= (length one-more-friend)
     (inc (length some-friends)))
  # => true

  (all true?
       (map =
            one-more-friend
            some-friends))
  # => true

  (= (type one-more-friend)
     :tuple)
  # => true

  )

(comment

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

  (def result
    (s/first-rest-maybe-all some-friends))

  (def [f r a] result)

  (deep= (get a 0)
         f)
  # => true

  (= (inc (length r))
     (length a))
  # => true

  (all true?
       (map =
            r
            (drop 1 a)))
  # => true

  (= (type a)
     (type r)
     (type some-friends))
  # => true

  )
