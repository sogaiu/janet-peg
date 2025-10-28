(declare-project
 :name "janet-peg"
 :url "https://github.com/sogaiu/janet-peg"
 :repo "git+https://github.com/sogaiu/janet-peg.git")

(declare-source
  :prefix "janet-peg"
  :source @["lib"
            "init.janet"
            # XXX: backward-compatibility
            "lib/bounds.janet"
            "lib/extras.janet"
            "lib/grammar.janet"
            "lib/location.janet"
            "lib/rewrite.janet"])

