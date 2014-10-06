DirWalker
=========

DirWalker lazily traverses one or more directory trees, depth first, 
returning successive file names.

Initialize the walker using

    {:ok, walker} = DirWalker.start_link(path, [, options ]) # or [path, path...]

Then return the next `n` path names using

    paths = DirWalker.next(walker [, n \\ 1])

Successive calls to `next` will return successive file names, until
all file names have been returned. 

These methods have also been wrapped into a Stream resource. 

    paths = DirWalker.stream(path [, options]) # or [path,path...]

`options` is a map containing zero or more of:

* `include_stat: true`

  Return tuples containing both the file name and the `File.Stat`
  structure for each file. This does not incur a performance penalty
  but obviously can use more memory.

* `include_dir_names: true`

  Include the names of directories that are traversed (normally just the names
  of regular files are returned). Note that the order is such that directory names
  will typically be returned after the names of files in those directories.
  
