defmodule DirWalkerTest do
  use ExUnit.Case

  test "basic traversal works" do
    {:ok, walker} = DirWalker.start_link("test/dir")
    files = DirWalker.next(walker, 99)
    assert length(files) == 3
    assert files == [ "test/dir/c/d/f.txt", "test/dir/b.txt", "test/dir/a.txt" ]
  end                 


  test "traversal in chunks works" do
    {:ok, walker} = DirWalker.start_link("test/dir")
    for path <- [ "test/dir/a.txt", "test/dir/b.txt", "test/dir/c/d/f.txt" ] do
      files = DirWalker.next(walker)
      assert length(files) == 1
      assert files == [ path ]
    end

    assert DirWalker.next(walker) == nil
  end                 

end
