(import ../janet-peg/zip-support :as s)

(comment

  (s/butlast [])
  # => nil

  (s/butlast @[])
  # => nil

  (s/butlast [:a :b :c])
  # => [:a :b]

  (s/butlast @[:a])
  # => @[]

  )

(comment

  (s/rest [])
  # => nil

  (s/rest @[])
  # => nil

  (s/rest [:a])
  # => []

  (s/rest [:a :b])
  # => [:b]

  (s/rest @[:a :b])
  # => @[:b]

  (s/rest @[:a :b :c])
  # => @[:b :c]

  )

(comment

  (s/tuple-push [:a] :b :c)
  # => [:a :b :c]

  (s/tuple-push [] :a)
  # => [:a]

  )

(comment

  (s/first-rest-maybe-all [:a])
  # => [:a [] [:a]]

  (s/first-rest-maybe-all @[:a :b])
  # => [:a @[:b] @[:a :b]]

  )
