defmodule DirWalker do

  require Logger

  use GenServer

  def start_link(list_of_paths) when is_list(list_of_paths) do
    GenServer.start_link(__MODULE__, list_of_paths)
  end

  def start_link(path) when is_binary(path), do: start_link([path])


  @doc """
  Return the next _n_ files from the lists of files, recursing into
  directories if necessary. Return `nil` when there are no files
  to return. (If there are fewer than _n_ files remaining, just those
  files are returned, and `nil` will be returned on the next call.

  ## Example

        iex> {:ok,d} = DirWalker.start_link "."
        {:ok, #PID<0.83.0>}
        iex> DirWalker.next(d)                 
        ["./.gitignore"]
        iex> DirWalker.next(d)
        ["./_build/dev/lib/dir_walter/.compile.elixir"]
        iex> DirWalker.next(d, 3)
        ["./_build/dev/lib/dir_walter/ebin/Elixir.DirWalker.beam",
         "./_build/dev/lib/dir_walter/ebin/dir_walter.app",
         "./_build/dev/lib/dir_walter/.compile.lock"]
        iex> 
  """
  def next(iterator, n \\ 1) do
    GenServer.call(iterator, { :get_next, n })
  end

  @doc """
   Stops the DirWalker
  """
  def stop(server) do
    GenServer.call(server, :stop)
  end

  @doc """
  Implement a stream interface that will return a lazy enumerable. 

  ## Example

    iex> first_file = DirWalker.stream( "/") |> Enum.take(1)
  """

  def stream(path_list) do
    Stream.resource(fn -> DirWalker.start_link(path_list) end,
                    fn(dirw) -> 
                      case DirWalker.next(dirw,1) do
                        data when is_list(data) -> {data, dirw }
                        _ -> {:halt, dirw}
                      end
                    end,
                    fn(dirw) -> DirWalker.stop(dirw) end 
      )
  end 

  ##################
  # Implementation #
  ##################

  def handle_call({:get_next, _n}, _from, []) do
    { :reply, nil, []}
  end

  def handle_call({:get_next, n}, _from, path_list) do
    {result, new_path_list} = first_n(path_list, n, _result=[])
    { :reply, result, new_path_list }
  end

  def handle_call(:stop, from, state) do
      GenServer.reply(from, :ok )
      {:stop, :normal, state}
  end


  # If the first element is a list, then it represents a 
  # nested directory listing. We keep it as a list rather
  # than flatten it in order to keep performance up.

  defp first_n([ [] | rest ], n, result)  do
    first_n(rest, n, result)
  end
      
  defp first_n([ [first] | rest ], n, result)  do
    first_n([ first | rest ], n, result)
  end
      
  defp first_n([ [first | nested] | rest ], n, result)  do
    first_n([ first | [ nested | rest ] ], n, result)
  end

  # Otherwise just a path as the first entry

  defp first_n(path_list, 0, result), do: {result, path_list}
  defp first_n([], _n, result),       do: {result, []}

  defp first_n([ path | rest ], n, result) do
    Logger.info(inspect(path))
     unless path, do: raise "nil"
    cond do
    File.dir?(path) ->
      first_n([files_in(path) | rest], n, result)
    File.regular?(path) ->
      first_n(rest, n-1, [ path | result ])
    true ->
      first_n(rest, n-1, [ result ])
    end
  end

  defp files_in(path) do
    path
    |> :file.list_dir
    |> ignore_error(path)
    |> Enum.map(fn(rel) -> Path.join(path, rel) end)
  end

  def ignore_error({:error, type}, path) do
    Logger.info("Ignore folder #{path} (#{type})")
    []
  end

  def ignore_error({:ok, list}, _path), do: list


end
