(post-deps
 (import jg-chambers/phony-judge)
 (import path))

(declare-project
 :name "janet-peg-grammar"
 :url "https://github.com/sogaiu/janet-peg-grammar"
 :repo "git+https://github.com/sogaiu/janet-peg-grammar.git"
 :dependencies [
   # below here, just for project.janet
   "https://github.com/janet-lang/path.git"
   "https://github.com/sogaiu/jg-chambers.git"
 ])

(post-deps

 (def proj-root
   (os/cwd))

 (def src-root
   (path/join proj-root "janet-peg-grammar"))

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
        (phony-judge/execute proj-root src-root))

 (phony "judge" ["build"]
        (phony-judge/execute proj-root src-root))

)
