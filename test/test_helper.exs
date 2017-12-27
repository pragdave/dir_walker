defmodule DirWalker.TestHelper do
  import ExUnit.Assertions

  def assert_list_equal(actual, expected) do
    import Enum, only: [ sort: 1 ]
    assert length(actual) == length(expected)
    assert sort(actual)   == sort(expected)
  end
end

ExUnit.start()
