defmodule DirWalker do

  @moduledoc Path.join([__DIR__, "../README.md"]) |> File.read!

  require Logger

  use GenServer

  def start_link(path, opts \\ %{})

  def start_link(list_of_paths, opts) when is_list(list_of_paths) do
    mappers = setup_mappers(opts)
    GenServer.start_link(__MODULE__, {list_of_paths, mappers})
  end

  def start_link(path, opts) when is_binary(path) do
    start_link([path], opts)
  end

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

    iex> first_file = DirWalker.stream("/") |> Enum.take(1)

  """

  def stream(path_list, opts \\ %{}) do
    Stream.resource( fn ->
                      {:ok, dirw} = DirWalker.start_link(path_list,opts)
                      dirw
                    end ,
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

  def init(path_list) do
    { :ok, path_list }
  end
  
  def handle_call({:get_next, _n}, _from, state = {[], _}) do
    { :reply, nil, state}
  end

  def handle_call({:get_next, n}, _from, {path_list, mappers}) do
    {result, new_path_list} = first_n(path_list, n, mappers, _result=[])
    return_result =
      case {result, new_path_list} do
        {[], []} -> nil
        _        -> result
      end
    { :reply, return_result, {new_path_list, mappers} }
  end

  def handle_call(:stop, from, state) do
      GenServer.reply(from, :ok )
      {:stop, :normal, state}
  end


  # If the first element is a list, then it represents a
  # nested directory listing. We keep it as a list rather
  # than flatten it in order to keep performance up.

  defp first_n([ [] | rest ], n, mappers, result)  do
    first_n(rest, n, mappers, result)
  end

  defp first_n([ [first] | rest ], n, mappers, result)  do
    first_n([ first | rest ], n, mappers, result)
  end

  defp first_n([ [first | nested] | rest ], n, mappers, result)  do
    first_n([ first | [ nested | rest ] ], n, mappers, result)
  end

  # Otherwise just a path as the first entry

  defp first_n(path_list, 0, _mappers, result), do: {result, path_list}
  defp first_n([], _n, _mappers, result),       do: {result, []}

  defp first_n([ path | rest ], n, mappers, result) do
    # Should figure out a way to pass this in.
    time_opts = [time: :posix]

    # File.stat! blows up on dangling symlink, until File.lstat! is in elixir
    # add this workaround.
    lstat = :file.read_link_info(path, time_opts)
    stat =
      case lstat do
        {:ok , fileinfo } ->File.Stat.from_record(fileinfo)
        {:error, reason} ->
          raise File.Error, reason: reason, action: "read file stats", path: path
      end

    case stat.type do
    :directory ->
      first_n([files_in(path) | rest],
              n,
              mappers,
              mappers.include_dir_names.(mappers.include_stat.(path, stat), result))

    :regular ->
      handle_regular_file(path,stat,rest,n,mappers,result)
    :symlink ->
      if(include_stat?(mappers)) do
        handle_regular_file(path,stat,rest,n,mappers,result)
      else
        handle_symlink(path,time_opts,rest,n,mappers,result)
      end
    true ->
      first_n(rest, n, mappers, result)
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

  # Notes on symlinks.
  #A symlink can be either
  #
  # A file
  #
  # A directory
  #
  # A dangling link
  #
  # Without any options, DirWalker returns a list of all the "files" in the paths.
  # For symlinks using File.stat! works on options 1,2 and blows up on 3.
  # file:read_link_info doesn't blow up on any of these, but requires the user to deal
  # with symlinks in some fashion.

  # I think the "right" thing to do is emulate the current behaviour, if the user
  # does not specify any options. If they specify :include_stat, then the code should
  # simply return a list and it's up to the user to deal.

  # It also might make sense to add an :ignore_symlinks, option.#

  defp handle_symlink(path,time_opts,rest,n,mappers,result) do
    rstat = File.stat(path,time_opts)
    case rstat do
    {:ok , rstat } ->
        handle_existing_symlink(path,rstat,rest,n,mappers,result)
    {:error, :enoent } ->
       Logger.info("Dangling symlink found: #{path}")
       handle_regular_file(path,rstat,rest,n,mappers,result)
    {:error, reason} ->
       Logger.info("Stat failed on #{path} with #{reason}")
       { result, [] }
    end
  end

  # This emulates existing behaviour, but does not return just the symlink
  # when include_stat is set.
  defp handle_existing_symlink(path,stat,rest,n,mappers,result) do
    case stat.type do
      :directory ->
        first_n([files_in(path) | rest],
              n,
              mappers,
              mappers.include_dir_names.(mappers.include_stat.(path, stat), result))
      :regular ->
        handle_regular_file(path,stat,rest,n,mappers,result)
      true ->
        first_n(rest, n-1, mappers, [ result ])
    end

  end

  # Extract this into function since we need it multiple places.
  defp handle_regular_file(path,stat,rest,n,mappers,result) do
    if mappers.matching.(path) do
      first_n(rest, n-1, mappers, [ mappers.include_stat.(path, stat) | result ])
    else
      first_n(rest, n, mappers, result)
    end
  end

  defp include_stat?(mappers) do
    mappers.include_stat.(:a, :b) == {:a, :b}
  end

  defp setup_mappers(opts) do
    %{
      include_stat:
        one_of(opts[:include_stat],
               fn (path, _stat) -> path end,
               fn (path, stat)  -> {path, stat} end),

      include_dir_names:
        one_of(opts[:include_dir_names],
               fn (_path, result) -> result end,
               fn (path, result)  -> [ path | result ] end),
      matching:
        one_of(!!opts[:matching],
             fn _path -> true end,
             fn path  -> String.match?(path, opts[:matching]) end),
    }
  end

  defp one_of(bool, _if_false, if_true) when bool, do: if_true
  defp one_of(_bool, if_false, _if_true),          do: if_false
end
