defmodule DirWalkerTest do
  use ExUnit.Case
  import DirWalker.TestHelper
  
  test "basic traversal works" do
    {:ok, walker} = DirWalker.start_link("test/dir")
    files = DirWalker.next(walker, 99)
    assert_list_equal(files, [ "test/dir/c/d/f.txt", "test/dir/b.txt", "test/dir/a.txt" ])
  end                 


  test "traversal in chunks works" do
    {:ok, walker} = DirWalker.start_link("test/dir")
    contents = [ "test/dir/a.txt", "test/dir/b.txt", "test/dir/c/d/f.txt" ]
    
    files =
      DirWalker.next(walker) ++
      DirWalker.next(walker) ++
      DirWalker.next(walker) 

    assert_list_equal(files, contents)
    assert DirWalker.next(walker) == nil
  end     

  test "returns only matching names if requested" do
    {:ok, walker} = DirWalker.start_link("test/dir", matching: ~r(a|f))
    for path <- [ "test/dir/a.txt", "test/dir/c/d/f.txt" ] do
      files = DirWalker.next(walker)
      assert_list_equal(files, [ path ])
    end

    assert DirWalker.next(walker) == nil
  end
  
  test "returns stat if asked to" do
    {:ok, walker} = DirWalker.start_link("test/dir/c", include_stat: true)
    files = DirWalker.next(walker, 99)
    assert length(files) == 1
    assert [ {"test/dir/c/d/f.txt", %File.Stat{}} ] = files
  end

  test "returns directory names if asked to" do
    {:ok, walker} = DirWalker.start_link("test/dir/c/d", include_dir_names: true)
    files = DirWalker.next(walker, 99)
    assert length(files) == 2
    assert  ["test/dir/c/d/f.txt", "test/dir/c/d"] = files
  end

  test "returns directory names and stats if asked to" do
    {:ok, walker} = DirWalker.start_link("test/dir/c/d", 
                                         include_stat:      true,
                                         include_dir_names: true)
    files = DirWalker.next(walker, 99)
    assert length(files) == 2
    assert  [{"test/dir/c/d/f.txt", s1 = %File.Stat{}}, 
             {"test/dir/c/d",       s3 = %File.Stat{}}] = files
    assert s1.type == :regular
    assert s3.type == :directory
  end

  test "stop method works" do 
   {:ok, walker} = DirWalker.start_link("test/dir")
   assert DirWalker.stop(walker) == :ok 
   refute Process.alive?(walker)
  end             

  test "stream method works" do
      dirw = DirWalker.stream("test/dir") 
      file =  Enum.take(dirw, 1)
      assert length(file) == 1
      assert hd(file) in [ "test/dir/a.txt", "test/dir/b.txt"] 
  end 

  test "stream method completes" do 
     paths = [ "test/dir/a.txt", "test/dir/b.txt", "test/dir/c/d/f.txt" ]
     dirw = DirWalker.stream("test/dir")
     files = Enum.into(dirw,[])
     assert Enum.sort(files) == Enum.sort(paths)
  end 

end
