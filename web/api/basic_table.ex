defmodule Transform.Api.BasicTable do
  import Plug.Conn
  alias Transform.Repo
  alias Transform.Job
  import Ecto.Query

  def init(args), do: args

  def chunk_size do
    Application.get_env(:transform, :basic_table)[:chunk_size]
  end

  def parse_chunk(bin) do
    bin
    |> String.split("\n")
    |> Enum.map(fn row -> String.split(row, ",") end)
  end

  def stream!(conn) do
    Stream.resource(
      fn -> read_body(conn, read_length: 1000) end,
      fn
        {:done, conn}      -> {:halt, conn}
        {:ok, bin, conn}   -> {[bin], {:done, conn}}
        {:more, bin, conn} -> {[bin], read_body(conn, read_length: 1000)}
      end,
      fn conn -> conn end
    )
  end


  defp basic_table_for(job, columns) do
    {:ok, bt} = Repo.insert(%Transform.BasicTable{
      meta: %{columns: columns}, job_id: job.id
    })
    IO.puts "insert basic table #{job.id}"
    bt
  end

  def call(conn, args) do
    IO.inspect conn.params
    dataset_id = conn.params["dataset_id"]

    case Repo.insert(%Transform.Upload{}) do
      {:ok, upload} ->
        conn
        |> stream!
        |> Stream.transform("", fn el, acc ->
          # hehe
          tok = String.split(acc <> el, "\n")
          last = List.last(tok)
          {Enum.take(tok, length(tok) - 1), acc <> last}
        end)
        |> CSV.decode
        |> Stream.chunk(chunk_size, chunk_size, [])
        |> Stream.transform(nil, fn
          [columns | rows], nil ->
            unclaimed_jobs = from j in Job,
              where: j.dataset == ^dataset_id,
              order_by: [desc: j.updated_at],
              select: j

            {job, basic_table} = case Repo.all(unclaimed_jobs) do
              [job | _] -> {job, basic_table_for(job, columns)}
              _ ->
                # Job doesn't exist yet, so make an empty one
                # and use it to make the basic table
                {:ok, job} = Repo.insert(%Job{
                  dataset: dataset_id
                })
                {job, basic_table_for(job, columns)}
            end
            Transform.BasicTable.Worker.push(job, basic_table, 0, rows)
            {[], {job, basic_table, 1}}
          chunk, {job, basic_table, chunk_num} ->
            Transform.BasicTable.Worker.push(job, basic_table, chunk_num, chunk)
            {[], {job, basic_table, chunk_num + 1}}
          end)
        |> Stream.run

        send_resp(conn, 200, "neat thanks\n")
      {:error, reason} ->
        send_resp(conn, 400, "something went wrong #{reason}")
    end


  end

end