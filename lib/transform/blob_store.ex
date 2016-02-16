defmodule Transform.BlobStore do

  defp write!(kind, ds_id, chunk) do
    relative = "#{kind}/#{ds_id}_chunk_#{UUID.uuid4}.csv"

    encoded = chunk
    |> CSV.encode
    |> Enum.join

    :erlcloud.put_object(Application.get_env(:transform, :blobs)[:bucket], relative, encoded)

    relative
  end

  def write_basic_table_chunk!(ds_id, chunk) do
    write!("basic_table", ds_id, chunk)
  end

  def write_transformed_chunk!(ds_id, chunk) do
    write!("transformed", ds_id, chunk)
  end

  def read!(relative) do
    :erlcloud.get_object(Application.get_env(:transform, :blobs)[:bucket], relative)
  end

end