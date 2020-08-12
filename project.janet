(import ./janet-peg/vendor/path)

(declare-project
 :name "janet-peg"
 :url "https://github.com/sogaiu/janet-peg"
 :repo "git+https://github.com/sogaiu/janet-peg.git")

(def proj-root
  (os/cwd))

(def src-root
  (path/join proj-root "janet-peg"))

(declare-source
 :source [(path/join src-root "grammar.janet")])

(phony "netrepl" []
       (os/execute
        ["janet" "-e" (string "(os/cd \"" src-root "\")"
                              "(import spork/netrepl)"
                              "(netrepl/server)")] :p))

# XXX: the following can be used to arrange for the overriding of the
#      "test" phony target -- thanks to rduplain and bakpakin
(put (dyn :rules) "test" nil)
(phony "test" ["build"]
       (os/execute ["jg-verdict"
                    "-p" proj-root
                    "-s" src-root] :p))

(phony "judge" ["build"]
       (os/execute ["jg-verdict"
                    "-p" proj-root
                    "-s" src-root] :p))

