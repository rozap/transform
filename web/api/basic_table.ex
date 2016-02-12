defmodule Transform.Api.BasicTable do
  import Plug.Conn
  alias Transform.Repo


  @chunk_size 1024

  def init(args), do: args

  def chunk_size, do: @chunk_size

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


  def call(conn, args) do

    dataset_id = conn.params["dataset_id"]

    case Repo.insert(%Transform.Upload{dataset: dataset_id}) do
      {:ok, upload} ->
        conn
        |> stream!
        |> Stream.transform("", fn el, acc ->
          tok = String.split(acc <> el, "\n")
          last = List.last(tok)

          {Enum.take(tok, length(tok) - 1), acc <> last}
        end)
        |> CSV.decode
        |> Stream.chunk(@chunk_size, @chunk_size, [])
        |> Stream.transform(nil,
          fn [columns | rows], nil ->
              case Repo.insert(%Transform.BasicTable{meta: %{columns: columns}, upload_id: upload.id}) do
                {:ok, bt} ->
                  Transform.BasicTable.Worker.push(dataset_id, bt, {0, rows})
                  {[], {bt, 1}}
                {:error, reason} -> {:halt, reason}
              end
            chunk, {basic_table, chunk_num} ->
              Transform.BasicTable.Worker.push(dataset_id, basic_table, {chunk_num, chunk})
              {[], {basic_table, chunk_num + 1}}
          end)
        |> Stream.run

        send_resp(conn, 200, "neat thanks\n")

      {:error, reason} ->
        send_resp(conn, 400, "something went wrong #{reason}")
    end


  end

end