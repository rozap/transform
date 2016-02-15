defmodule Transform.BlobStore do
  defp write!(kind, ds_id, chunk) do
    relative = "#{kind}/#{ds_id}_chunk_#{UUID.uuid4}.csv"
    absolute = Application.get_env(:transform, :blobs)[:path]
    |> Path.join(relative)

    device = File.open!(absolute, [:write])

    chunk
    |> CSV.encode
    |> Enum.each(fn line -> IO.binwrite(device, line) end)

    File.close(device)

    relative
  end

  def write_basic_table_chunk!(ds_id, chunk) do
    write!("basic_table", ds_id, chunk)
  end

  def write_transformed_chunk!(ds_id, chunk) do
    write!("transformed", ds_id, chunk)
  end

  def read!(relative) do
    Application.get_env(:transform, :blobs)[:path]
    |> Path.join(relative)
    |> File.stream!
  end

end