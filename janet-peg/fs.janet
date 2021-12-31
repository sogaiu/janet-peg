(import ./vendor/path)

(defn is-dir?
  [path]
  (when-let [path path
             stat (os/lstat path)]
    (= :directory (stat :mode))))

(comment

  (comment

    (is-dir? (os/getenv "HOME"))

    )

 )

(defn is-file?
  [path]
  (when-let [path path
             stat (os/lstat path)]
    (= :file (stat :mode))))

(comment

  (comment

    (is-file? (path/join (os/getenv "HOME") ".bashrc"))

    )

  (comment

    (is-file? (path/join (os/getenv "HOME") ".config/nvim/init.vim"))

    )

 )

(defn visit-files
  [path a-fn]
  (when (is-dir? path)
    (each thing (os/dir path)
      (def thing-path
        (path/join path thing))
      (cond
        (is-file? thing-path)
        (a-fn thing-path)
        #
        (is-dir? thing-path)
        (visit-files thing-path a-fn)))))

(comment

  (comment

    (visit-files (path/join (os/getenv "HOME")
                   "src/hpkgs/")
      |(eprint $))

    )

  (path/ext "./fs.janet")
  # =>
  ".janet"

  (comment

    (import ./rewrite)

    (visit-files (path/join (os/getenv "HOME")
                            "src/janet-repositories")
                 |(when (= (path/ext $) ".janet")
                    (let [src (slurp $)]
                      (when (not= (string src)
                                  (rewrite/code (rewrite/ast src)))
                        (eprint $)))))

    )

 )
