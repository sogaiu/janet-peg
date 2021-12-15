(import ../janet-peg/location :prefix "")

# loc-grammar
(comment

  (peg/match loc-grammar "true")
  # => '@[(:constant @{:bc 1 :bl 1 :ec 5 :el 1} "true")]

  (deep=
    #
    (peg/match loc-grammar "(+ 1 1)")
    #
    '@[(:tuple @{:bc 1 :bl 1
                 :ec 8 :el 1}
               (:symbol @{:bc 2 :bl 1
                          :ec 3 :el 1} "+")
               (:whitespace @{:bc 3 :bl 1
                              :ec 4 :el 1} " ")
               (:number @{:bc 4 :bl 1
                          :ec 5 :el 1} "1")
               (:whitespace @{:bc 5 :bl 1
                              :ec 6 :el 1} " ")
               (:number @{:bc 6 :bl 1
                          :ec 7 :el 1} "1"))])
  # => true

  (deep=
    #
    (peg/match loc-grammar "|(+ $ 1)")
    #
    '@[(:fn @{:bc 1 :bl 1
              :ec 9 :el 1}
            (:tuple @{:bc 2 :bl 1
                      :ec 9 :el 1}
                    (:symbol @{:bc 3 :bl 1
                               :ec 4 :el 1} "+")
                    (:whitespace @{:bc 4 :bl 1
                                   :ec 5 :el 1} " ")
                    (:symbol @{:bc 5 :bl 1
                               :ec 6 :el 1} "$")
                    (:whitespace @{:bc 6 :bl 1
                                   :ec 7 :el 1} " ")
                    (:number @{:bc 7 :bl 1
                               :ec 8 :el 1} "1")))])
  # => true

  (deep=
    #
    (peg/match loc-grammar "@(1 2)")
    #
    '@[(:array @{:bc 1 :bl 1
                 :ec 7 :el 1}
               (:number @{:bc 3 :bl 1
                          :ec 4 :el 1} "1")
               (:whitespace @{:bc 4 :bl 1
                              :ec 5 :el 1} " ")
               (:number @{:bc 5 :bl 1
                          :ec 6 :el 1} "2"))])
  # => true

  (deep=
    #
    (peg/match loc-grammar "{:x :y}")
    #
    '@[(:struct @{:bc 1 :bl 1
                  :ec 8 :el 1}
                (:keyword @{:bc 2 :bl 1
                            :ec 4 :el 1} ":x")
                (:whitespace @{:bc 4 :bl 1
                               :ec 5 :el 1} " ")
                (:keyword @{:bc 5 :bl 1
                            :ec 7 :el 1} ":y"))])
  # => true

  (deep=
    #
    (peg/match loc-grammar "'z")
    #
    '@[(:quote @{:bc 1 :bl 1
                 :ec 3 :el 1}
               (:symbol @{:bc 2 :bl 1
                          :ec 3 :el 1} "z"))])
  # => true

  (deep=
    #
    (peg/match loc-grammar ";w")
    #
    '@[(:splice @{:bc 1 :bl 1
                  :ec 3 :el 1}
                (:symbol @{:bc 2 :bl 1
                           :ec 3 :el 1} "w"))])
  # => true

  (deep=
    #
    (peg/match loc-grammar ",a")
    #
    '@[(:unquote @{:bc 1 :bl 1
                   :ec 3 :el 1}
                 (:symbol @{:bc 2 :bl 1
                            :ec 3 :el 1} "a"))])
  # => true

  )
