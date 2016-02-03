defmodule Transform.Api.BasicTable do
  import Plug.Conn
  alias Transform.BasicTableServer

  @chunk_size 4

  def init(args), do: args

  def to_lines(bin) do
    bin
    |> String.split("\n")
    |> Enum.map(fn row -> String.split(row, ",") end)
  end

  def stream!(conn) do
    Stream.resource(
      fn -> read_body(conn, read_length: 1000) end, 
      fn 
        {:done, conn}      -> 
          {:halt, conn}
        {:ok, bin, conn}   -> 
          {to_lines(bin), {:done, conn}}
        {:more, bin, conn} -> 
          {to_lines(bin), read_body(conn, read_length: 1000)}
      end,
      fn conn -> conn end
    )
  end

  def call(conn, args) do

    dataset_id = conn.params["dataset_id"]

    upload = UUID.uuid4

    conn
    |> stream!
    |> Stream.chunk(@chunk_size)
    |> Stream.each(fn chunk -> 
      # notify the basic table service of a new chunk on upload 
      # for dataset_id
      BasicTableServer.push(dataset_id, upload, chunk)
    end)
    |> Stream.run

    send_resp(conn, 200, "neat thanks\n")
  end

end