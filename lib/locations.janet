# bl - begin line
# bc - begin column
# bp - begin position
# el - end line
# ec - end column
# ep - end position
(defn make-attrs
  [& items]
  (zipcoll [:bl :bc :bp :el :ec :ep]
           items))

(defn atom-node
  [node-type peg-form]
  ~(cmt (capture (sequence (line) (column) (position)
                           ,peg-form
                           (line) (column) (position)))
        ,|[node-type (make-attrs ;(slice $& 0 -2)) (last $&)]))

(defn reader-macro-node
  [node-type sigil]
  ~(cmt (capture (sequence (line) (column) (position)
                           ,sigil
                           (any :non-form)
                           :form
                           (line) (column) (position)))
        ,|[node-type (make-attrs ;(slice $& 0 3) ;(slice $& -5 -2))
           ;(slice $& 3 -5)]))

(defn collection-node
  [node-type open-delim close-delim]
  ~(cmt
     (capture
       (sequence
         (line) (column) (position)
         ,open-delim
         (any :input)
         (choice ,close-delim
                 (error
                   (replace (sequence (line) (column) (position))
                            ,|(string/format
                                (string "line: %p column: %p position: %p "
                                        "missing %p for %p")
                                $0 $1 $2 close-delim node-type))))
         (line) (column) (position)))
     ,|[node-type (make-attrs ;(slice $& 0 3) ;(slice $& -5 -2))
        ;(slice $& 3 -5)]))

(def loc-grammar
  ~@{:main (sequence (line) (column) (position)
                     (some :input)
                     (line) (column) (position))
     #
     :input (choice :non-form
                    :form)
     #
     :non-form (choice :whitespace
                       :comment)
     #
     :whitespace ,(atom-node :whitespace
                             '(choice (some (set " \0\f\t\v"))
                                      (choice "\r\n"
                                              "\r"
                                              "\n")))
     # :whitespace
     # (cmt (capture (sequence (line) (column)
     #                         (choice (some (set " \0\f\t\v"))
     #                                 (choice "\r\n"
     #                                         "\r"
     #                                         "\n"))
     #                         (line) (column)))
     #      ,|[:whitespace (make-attrs ;(slice $& 0 -2)) (last $&)])
     #
     :comment ,(atom-node :comment
                          '(sequence "#"
                                     (any (if-not (set "\r\n") 1))))
     #
     :form (choice # reader macros
                   :fn
                   :quasiquote
                   :quote
                   :splice
                   :unquote
                   # collections
                   :array
                   :bracket-array
                   :tuple
                   :bracket-tuple
                   :table
                   :struct
                   # atoms
                   :number
                   :constant
                   :buffer
                   :string
                   :long-buffer
                   :long-string
                   :keyword
                   :symbol)
     #
     :fn ,(reader-macro-node :fn "|")
     # :fn (cmt (capture (sequence (line) (column)
     #                             "|"
     #                             (any :non-form)
     #                             :form
     #                             (line) (column)))
     #          ,|[:fn (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
     #             ;(slice $& 2 -4)])
     #
     :quasiquote ,(reader-macro-node :quasiquote "~")
     #
     :quote ,(reader-macro-node :quote "'")
     #
     :splice ,(reader-macro-node :splice ";")
     #
     :unquote ,(reader-macro-node :unquote ",")
     #
     :array ,(collection-node :array "@(" ")")
     # :array
     # (cmt
     #   (capture
     #     (sequence
     #       (line) (column)
     #       "@("
     #       (any :input)
     #       (choice ")"
     #               (error
     #                 (replace (sequence (line) (column))
     #                          ,|(string/format
     #                              "line: %p column: %p missing %p for %p"
     #                              $0 $1 ")" :array))))
     #       (line) (column)))
     #   ,|[:array (make-attrs ;(slice $& 0 2) ;(slice $& -4 -2))
     #      ;(slice $& 2 -4)])
     #
     :tuple ,(collection-node :tuple "(" ")")
     #
     :bracket-array ,(collection-node :bracket-array "@[" "]")
     #
     :bracket-tuple ,(collection-node :bracket-tuple "[" "]")
     #
     :table ,(collection-node :table "@{" "}")
     #
     :struct ,(collection-node :struct "{" "}")
     #
     :number ,(atom-node :number
                         ~(drop (sequence (cmt (capture (some :num-char))
                                               ,scan-number)
                                          (opt (sequence ":" (range "AZ" "az"))))))
     #
     :num-char (choice (range "09" "AZ" "az")
                       (set "&+-._"))
     #
     :constant ,(atom-node :constant
                           '(sequence (choice "false" "nil" "true")
                                      (not :name-char)))
     #
     :name-char (choice (range "09" "AZ" "az" "\x80\xFF")
                        (set "!$%&*+-./:<?=>@^_"))
     #
     :buffer ,(atom-node :buffer
                         '(sequence `@"`
                                    (any (choice :escape
                                                 (if-not "\"" 1)))
                                    `"`))
     #
     :escape (sequence "\\"
                       (choice (set `"'0?\abefnrtvz`)
                               (sequence "x" (2 :h))
                               (sequence "u" (4 :h))
                               (sequence "U" (6 :h))
                               (error (constant "bad escape"))))
     #
     :string ,(atom-node :string
                         '(sequence `"`
                                    (any (choice :escape
                                                 (if-not "\"" 1)))
                                    `"`))
     #
     :long-string ,(atom-node :long-string
                              :long-bytes)
     #
     :long-bytes {:main (drop (sequence :open
                                        (any (if-not :close 1))
                                        :close))
                  :open (capture :delim :n)
                  :delim (some "`")
                  :close (cmt (sequence (not (look -1 "`"))
                                        (backref :n)
                                        (capture (backmatch :n)))
                              ,=)}
     #
     :long-buffer ,(atom-node :long-buffer
                              '(sequence "@" :long-bytes))
     #
     :keyword ,(atom-node :keyword
                          '(sequence ":"
                                     (any :name-char)))
     #
     :symbol ,(atom-node :symbol
                         '(some :name-char))
     })

(comment

  (get (peg/match loc-grammar " ") 3)
  # =>
  [:whitespace @{:bl 1 :el 1 :bc 1 :bp 0 :ec 2 :ep 1} " "]

  (get (peg/match loc-grammar "true?") 3)
  # =>
  [:symbol @{:bl 1 :el 1 :bc 1 :bp 0 :ec 6 :ep 5} "true?"]

  (get (peg/match loc-grammar "nil?") 3)
  # =>
  [:symbol @{:bl 1 :el 1 :bc 1 :bp 0 :ec 5 :ep 4} "nil?"]

  (get (peg/match loc-grammar "false?") 3)
  # =>
  [:symbol @{:bl 1 :el 1 :bc 1 :bp 0 :ec 7 :ep 6} "false?"]

  (get (peg/match loc-grammar "# hi there") 3)
  # =>
  [:comment @{:bl 1 :el 1 :bc 1 :bp 0 :ec 11 :ep 10} "# hi there"]

  (get (peg/match loc-grammar "1_000_000") 3)
  # =>
  [:number @{:bl 1 :el 1 :bc 1 :bp 0 :ec 10 :ep 9} "1_000_000"]

  (get (peg/match loc-grammar "8.3") 3)
  # =>
  [:number @{:bl 1 :el 1 :bc 1 :bp 0 :ec 4 :ep 3} "8.3"]

  (get (peg/match loc-grammar "1e2") 3)
  # =>
  [:number @{:bl 1 :el 1 :bc 1 :ep 3 :bp 0 :ec 4} "1e2"]

  (get (peg/match loc-grammar "0xfe") 3)
  # =>
  [:number @{:bl 1 :el 1 :bc 1 :ep 4 :bp 0 :ec 5} "0xfe"]

  (get (peg/match loc-grammar "2r01") 3)
  # =>
  [:number @{:bl 1 :el 1 :bc 1 :ep 4 :bp 0 :ec 5} "2r01"]

  (get (peg/match loc-grammar "3r101&01") 3)
  # =>
  [:number @{:bl 1 :el 1 :bc 1 :ep 8 :bp 0 :ec 9} "3r101&01"]

  (get (peg/match loc-grammar "2:u") 3)
  # =>
  [:number @{:bl 1 :el 1 :bc 1 :ep 3 :bp 0 :ec 4} "2:u"]

  (get (peg/match loc-grammar "-8:s") 3)
  # =>
  [:number @{:bl 1 :el 1 :bc 1 :ep 4 :bp 0 :ec 5} "-8:s"]

  (get (peg/match loc-grammar "1e2:n") 3)
  # =>
  [:number @{:bl 1 :el 1 :bc 1 :ep 5 :bp 0 :ec 6} "1e2:n"]

  (get (peg/match loc-grammar "printf") 3)
  # =>
  [:symbol @{:bl 1 :el 1 :bc 1 :ep 6 :bp 0 :ec 7} "printf"]

  (get (peg/match loc-grammar ":smile") 3)
  # =>
  [:keyword @{:bl 1 :el 1 :bc 1 :ep 6 :bp 0 :ec 7} ":smile"]

  (get (peg/match loc-grammar `"fun"`) 3)
  # =>
  [:string @{:bl 1 :el 1 :bc 1 :ep 5 :bp 0 :ec 6} "\"fun\""]

  (get (peg/match loc-grammar "``long-fun``") 3)
  # =>
  [:long-string @{:bl 1 :el 1 :bc 1 :ep 12 :bp 0 :ec 13} "``long-fun``"]

  (get (peg/match loc-grammar "@``long-buffer-fun``") 3)
  # =>
  [:long-buffer
   @{:bl 1 :el 1 :bc 1 :bp 0 :ec 21 :ep 20}
   "@``long-buffer-fun``"]

  (get (peg/match loc-grammar `@"a buffer"`) 3)
  # =>
  [:buffer @{:bl 1 :el 1 :bc 1 :ep 11 :bp 0 :ec 12} "@\"a buffer\""]

  (get (peg/match loc-grammar "@[8]") 3)
  # =>
  [:bracket-array @{:bl 1 :el 1 :bc 1 :ep 4 :bp 0 :ec 5}
   [:number @{:bl 1 :el 1 :bc 3 :ep 3 :bp 2 :ec 4} "8"]]

  (get (peg/match loc-grammar "@{:a 1}") 3)
  # =>
  [:table @{:bl 1 :el 1 :bc 1 :ep 7 :bp 0 :ec 8}
   [:keyword @{:bl 1 :el 1 :bc 3 :ep 4 :bp 2 :ec 5} ":a"]
   [:whitespace @{:bl 1 :el 1 :bc 5 :ep 5 :bp 4 :ec 6} " "]
   [:number @{:bl 1 :el 1 :bc 6 :ep 6 :bp 5 :ec 7} "1"]]

  (get (peg/match loc-grammar "~x") 3)
  # =>
  [:quasiquote @{:bl 1 :el 1 :bc 1 :ep 2 :bp 0 :ec 3}
   [:symbol @{:bl 1 :el 1 :bc 2 :ep 2 :bp 1 :ec 3} "x"]]

  (get (peg/match loc-grammar "' '[:a :b]") 3)
  # =>
  [:quote @{:bl 1 :el 1 :bc 1 :ep 10 :bp 0 :ec 11}
   [:whitespace @{:bl 1 :el 1 :bc 2 :ep 2 :bp 1 :ec 3} " "]
   [:quote @{:bl 1 :el 1 :bc 3 :ep 10 :bp 2 :ec 11}
    [:bracket-tuple @{:bl 1 :el 1 :bc 4 :ep 10 :bp 3 :ec 11}
     [:keyword @{:bl 1 :el 1 :bc 5 :ep 6 :bp 4 :ec 7} ":a"]
     [:whitespace @{:bl 1 :el 1 :bc 7 :ep 7 :bp 6 :ec 8} " "]
     [:keyword @{:bl 1 :el 1 :bc 8 :ep 9 :bp 7 :ec 10} ":b"]]]]

  )

(def loc-top-level-ast
  (put (table ;(kvs loc-grammar))
       :main ~(sequence (line) (column) (position)
                        :input
                        (line) (column) (position))))

(defn par
  [src &opt start single]
  (default start 0)
  (if single
    (if-let [[bl bc bp tree el ec ep]
             (peg/match loc-top-level-ast src start)]
      @[:code (make-attrs bl bc bp el ec ep) tree]
      @[:code])
    (if-let [captures (peg/match loc-grammar src start)]
      (let [[bl bc bp] (slice captures 0 3)
            [el ec ep] (slice captures -4)
            trees (array/slice captures 3 -4)]
        (array/insert trees 0
                      :code (make-attrs bl bc bp el ec ep)))
      @[:code])))

# XXX: backward compatibility
(def ast par)

(comment

  (par "(+ 1 1)")
  # =>
  @[:code @{:bl 1 :el 1 :bc 1 :ep 7 :bp 0 :ec 8}
    [:tuple @{:bl 1 :el 1 :bc 1 :ep 7 :bp 0 :ec 8}
     [:symbol @{:bl 1 :el 1 :bc 2 :ep 2 :bp 1 :ec 3} "+"]
     [:whitespace @{:bl 1 :el 1 :bc 3 :ep 3 :bp 2 :ec 4} " "]
     [:number @{:bl 1 :el 1 :bc 4 :ep 4 :bp 3 :ec 5} "1"]
     [:whitespace @{:bl 1 :el 1 :bc 5 :ep 5 :bp 4 :ec 6} " "]
     [:number @{:bl 1 :el 1 :bc 6 :ep 6 :bp 5 :ec 7} "1"]]]

  )

(defn gen*
  [an-ast buf]
  (case (first an-ast)
    :code
    (each elt (drop 2 an-ast)
      (gen* elt buf))
    #
    :buffer
    (buffer/push-string buf (in an-ast 2))
    :comment
    (buffer/push-string buf (in an-ast 2))
    :constant
    (buffer/push-string buf (in an-ast 2))
    :keyword
    (buffer/push-string buf (in an-ast 2))
    :long-buffer
    (buffer/push-string buf (in an-ast 2))
    :long-string
    (buffer/push-string buf (in an-ast 2))
    :number
    (buffer/push-string buf (in an-ast 2))
    :string
    (buffer/push-string buf (in an-ast 2))
    :symbol
    (buffer/push-string buf (in an-ast 2))
    :whitespace
    (buffer/push-string buf (in an-ast 2))
    #
    :array
    (do
      (buffer/push-string buf "@(")
      (each elt (drop 2 an-ast)
        (gen* elt buf))
      (buffer/push-string buf ")"))
    :bracket-array
    (do
      (buffer/push-string buf "@[")
      (each elt (drop 2 an-ast)
        (gen* elt buf))
      (buffer/push-string buf "]"))
    :bracket-tuple
    (do
      (buffer/push-string buf "[")
      (each elt (drop 2 an-ast)
        (gen* elt buf))
      (buffer/push-string buf "]"))
    :tuple
    (do
      (buffer/push-string buf "(")
      (each elt (drop 2 an-ast)
        (gen* elt buf))
      (buffer/push-string buf ")"))
    :struct
    (do
      (buffer/push-string buf "{")
      (each elt (drop 2 an-ast)
        (gen* elt buf))
      (buffer/push-string buf "}"))
    :table
    (do
      (buffer/push-string buf "@{")
      (each elt (drop 2 an-ast)
        (gen* elt buf))
      (buffer/push-string buf "}"))
    #
    :fn
    (do
      (buffer/push-string buf "|")
      (each elt (drop 2 an-ast)
        (gen* elt buf)))
    :quasiquote
    (do
      (buffer/push-string buf "~")
      (each elt (drop 2 an-ast)
        (gen* elt buf)))
    :quote
    (do
      (buffer/push-string buf "'")
      (each elt (drop 2 an-ast)
        (gen* elt buf)))
    :splice
    (do
      (buffer/push-string buf ";")
      (each elt (drop 2 an-ast)
        (gen* elt buf)))
    :unquote
    (do
      (buffer/push-string buf ",")
      (each elt (drop 2 an-ast)
        (gen* elt buf)))
    ))

(defn gen
  [an-ast]
  (let [buf @""]
    (gen* an-ast buf)
    # XXX: leave as buffer?
    (string buf)))

# XXX: backward compatibility
(def code gen)

(comment

  (gen [:code])
  # =>
  ""

  (gen [:whitespace @{:bc 1 :bl 1 :bp 0
                      :ec 2 :el 1 :ep 1} " "])
  # =>
  " "

  (gen [:buffer @{:bc 1 :bl 1 :bp 0
                  :ec 12 :el 1 :ep 11} "@\"a buffer\""])
  # =>
  `@"a buffer"`

  (gen @[:code @{:bc 1 :bl 1 :bp 0
                 :ec 8 :el 1 :ep 7}
         [:tuple @{:bc 1 :bl 1 :bp 0
                   :ec 8 :el 1 :ep 7}
                 [:symbol @{:bc 2 :bl 1 :bp 1
                            :ec 3 :el 1 :ep 2} "+"]
                 [:whitespace @{:bc 3 :bl 1 :bp 2
                                :ec 4 :el 1 :ep 3} " "]
                 [:number @{:bc 4 :bl 1 :bp 3
                            :ec 5 :el 1 :ep 4} "1"]
                 [:whitespace @{:bc 5 :bl 1 :bp 4
                                :ec 6 :el 1 :ep 5} " "]
                 [:number @{:bc 6 :bl 1 :bp 5
                            :ec 7 :el 1 :ep 6} "1"]]])
  # =>
  "(+ 1 1)"

  )

(comment

  (def src "{:x  :y \n :z  [:a  :b    :c]}")

  (gen (par src))
  # =>
  src

  )

(comment

  (comment

    (let [src (slurp (string (os/getenv "HOME")
                             "/src/janet/src/boot/boot.janet"))]
      (= (string src)
         (gen (par src))))

    )

  )
