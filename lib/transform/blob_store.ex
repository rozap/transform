# defmodule Transform.BlobStore do

#   defp write!(kind, ds_id, chunk) do
#     relative = "#{kind}/#{ds_id}_chunk_#{UUID.uuid4}.csv"

#     encoded = chunk
#     |> CSV.encode
#     |> Enum.join

#     :erlcloud_s3.put_object(
#       to_char_list(Application.get_env(:transform, :blobs)[:bucket]),
#       to_char_list(relative),
#       encoded
#     )

#     relative
#   end

#   def write_basic_table_chunk!(ds_id, chunk) do
#     write!("basic_table", ds_id, chunk)
#   end

#   def write_transformed_chunk!(ds_id, chunk) do
#     write!("transformed", ds_id, chunk)
#   end

#   def read!(relative) do
#     :erlcloud_s3.get_object(
#       to_char_list(Application.get_env(:transform, :blobs)[:bucket]),
#       to_char_list(relative)
#     )[:content]
#     |> String.split("\n")
#   end

# end

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