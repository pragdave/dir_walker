defmodule DirWalkerTest do
  use ExUnit.Case


  test "basic traversal works" do
    test_files = ["test/dir/a.txt", "test/dir/b.txt", "test/dir/badlink", "test/dir/c/d/f.txt", "test/dir/goodlink"]
    {:ok, walker} = DirWalker.start_link("test/dir")
    files = DirWalker.next(walker, 99)
    assert length(files) == 5
    assert Enum.sort(files) == Enum.sort(test_files)
  end                 

  # Travis CI returns files in different order.
  test "traversal in chunks works" do
    test_files = ["test/dir/a.txt", "test/dir/b.txt", "test/dir/badlink", "test/dir/c/d/f.txt", "test/dir/goodlink"]
    {:ok, walker} = DirWalker.start_link("test/dir")
    
    found_files = for _path <- test_files do
                    files = DirWalker.next(walker)
                    assert length(files) == 1
                    filename = Enum.at(files,0)
                    assert Enum.member?(test_files,filename)
                    filename
                  end |> Enum.into([])
    assert DirWalker.next(walker) == nil
    assert Enum.sort(found_files) == Enum.sort(test_files)
  end     

  test "returns only matching names if requested" do
    test_files = [ "test/dir/a.txt","test/dir/badlink", "test/dir/c/d/f.txt" ]
    {:ok, walker} = DirWalker.start_link("test/dir", matching: ~r(a|f))
    for _path <- test_files do
      files = DirWalker.next(walker)
      assert length(files) == 1
      filename = Enum.at(files,0)
      assert Enum.member?(test_files,filename)
    end
    assert DirWalker.next(walker) == nil
  end

  test "matching names works with different matching order " do
    test_files = [ "test/dir/b.txt","test/dir/badlink" ]
    {:ok, walker} = DirWalker.start_link("test/dir", matching: ~r(b))
    found_files = for _path <- test_files do
                      files = DirWalker.next(walker)
                      assert length(files) == 1
                      filename = Enum.at(files,0)
                      assert Enum.member?(test_files,filename)
                      filename
                   end |> Enum.into([])

    assert DirWalker.next(walker) == nil
    assert Enum.sort(found_files) == Enum.sort(test_files)
  end

  test "returns both matching names and stats if asked to " do
    test_types = [ :regular , :symlink ]
    test_files = [ "test/dir/a.txt","test/dir/badlink", "test/dir/c/d/f.txt" ]
    {:ok, walker} = DirWalker.start_link("test/dir", 
                                         matching: ~r(a|f), 
                                         include_stat: true)
    for _path <- test_files do
      [{filename, fstat}] = DirWalker.next(walker)
      assert Enum.member?(test_types,fstat.type)  
      assert Enum.member?(test_files,filename)
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
    test_files = ["test/dir/c/d/f.txt", "test/dir/c/d/e", "test/dir/c/d"]
    {:ok, walker} = DirWalker.start_link("test/dir/c/d", include_dir_names: true)
    files = DirWalker.next(walker, 99)
    assert length(files) == 3
    assert  Enum.sort(test_files) == Enum.sort(files)
  end

  test "returns directory names and stats if asked to" do
    test_files = ["test/dir/c/d/f.txt", "test/dir/c/d/e", "test/dir/c/d"]
    {:ok, walker} = DirWalker.start_link("test/dir/c/d", 
                                         include_stat:      true,
                                         include_dir_names: true)
    files = DirWalker.next(walker, 99)
    assert length(files) == 3
    assert  [{file1, s1 = %File.Stat{}}, 
             {file2, s2 = %File.Stat{}},
             {file3, s3 = %File.Stat{}}] = files
    found_files = [file1,file2,file3]
    found_stats = [s1,s2,s3]
    assert Enum.sort(found_files) == Enum.sort(test_files)
    should_be_dir = Enum.at(found_stats,Enum.find_index(found_files, fn(x) -> x == "test/dir/c/d/e" end))
    should_be_file = Enum.at(found_stats,Enum.find_index(found_files, fn(x) -> x == "test/dir/c/d/f.txt" end))
    assert should_be_file.type == :regular
    assert should_be_dir.type == :directory
  end

  test "returns symlink as file type with include_stat option" do
    {:ok, walker} = DirWalker.start_link("test/dirlink", 
                                         include_stat:      true)
    [{"test/dirlink", stat }] = DirWalker.next(walker)
    assert stat.type == :symlink
  end 

  test "follows symlinks without include_stat option" do
    test_files = ["test/dirlink/a.txt", "test/dirlink/b.txt", "test/dirlink/badlink", "test/dirlink/c/d/f.txt", "test/dirlink/goodlink"]
    {:ok, walker} = DirWalker.start_link("test/dirlink")
    files = DirWalker.next(walker, 99)
    assert length(files) == 5
    assert Enum.sort(files) == Enum.sort(test_files)
  end 

  test "stop method works" do 
   {:ok, walker} = DirWalker.start_link("test/dir")
   assert DirWalker.stop(walker) == :ok 
   refute Process.alive?(walker)
  end             

  # Travis CI returns files in different order.
  test "stream method works" do
    test_files = ["test/dir/a.txt", "test/dir/b.txt", "test/dir/badlink","test/dir/c/d/f.txt", "test/dir/goodlink"]
    dirw = DirWalker.stream("test/dir") 
    file = Enum.take(dirw,1)
    assert length(file) == 1
    filename = Enum.at(file,0)
    assert Enum.member?(test_files,filename) 
  end 

  test "stream method completes" do 
    test_files = ["test/dir/a.txt", "test/dir/b.txt", "test/dir/badlink", "test/dir/c/d/f.txt", "test/dir/goodlink"]
    dirw = DirWalker.stream("test/dir")
    files = Enum.into(dirw,[])
    assert Enum.sort(files) == Enum.sort(test_files)
  end 

  test "stream method takes options" do 
    paths = [ "test/dir/a.txt", "test/dir/c/d/f.txt", "test/dir/badlink" ]
    dirw = DirWalker.stream("test/dir", matching: ~r(a|f))
    files = Enum.into(dirw,[])
    assert Enum.sort(files) == Enum.sort(paths)
  end 

end
