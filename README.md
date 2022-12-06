# janet-peg

Some code for parsing and rendering as Janet source code

## Usage Examples

Basic Parsing and Rendering
```janet
(import janet-peg/rewrite)

# parse code string
(rewrite/ast "(+ 1 1)")
# =>
'@[:code
   (:tuple
     (:symbol "+") (:whitespace " ")
     (:number "1") (:whitespace " ")
     (:number "1"))]

# render as string
(rewrite/code
  '@(:struct
     (:keyword ":a") (:whitespace " ")
     (:number "1")))
# =>
"{:a 1}"

# roundtrip
(def src "{:x  :y \n :z  [:a  :b    :c]}")

(rewrite/code (rewrite/ast src))
# =>
src
```

With Location Info
```janet
(import janet-peg/location)

# parse code string
(location/ast "(+ 1 1)")
# =>
'@[:code @{:bc 1 :bl 1
           :ec 8 :el 1}
   (:tuple @{:bc 1 :bl 1
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
                      :ec 7 :el 1} "1"))]

# render as string
(location/code
  '@[:code @{:bc 1 :bl 1
             :ec 8 :el 1}
     (:tuple @{:bc 1 :bl 1
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
# =>
"(+ 1 1)"

# roundtrip
(def src "{:x  :y \n :z  [:a  :b    :c]}")

(location/code (location/ast src))
# =>
src
```
