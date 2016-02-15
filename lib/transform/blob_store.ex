defmodule Transform.BlobStore do
  defp write!(kind, ds_id, chunk) do
    path = "/tmp/#{kind}/#{ds_id}_chunk_#{UUID.uuid4}.csv"
    device = File.open!(path, [:write])

    chunk
    |> CSV.encode
    |> Enum.each(fn line -> IO.binwrite(device, line) end)

    File.close(device)
    path
  end

  def write_basic_table_chunk!(ds_id, chunk) do
    write!("basic_table", ds_id, chunk)
  end

  def write_transformed_chunk!(ds_id, chunk) do
    write!("transformed", ds_id, chunk)
  end

end