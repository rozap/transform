# defmodule Transform.BlobStore do

#   @config [
#     s3_follow_redirect: true
#   ]

#   defp write!(kind, ds_id, chunk) do
#     relative = "#{kind}/#{ds_id}_chunk_#{UUID.uuid4}"

#     :erlcloud_s3.put_object(
#       to_char_list(Application.get_env(:transform, :blobs)[:bucket]),
#       to_char_list(relative),
#       :erlang.term_to_binary(chunk),
#       @config
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
#       to_char_list(relative),
#       @config
#     )[:content]
#     |> :erlang.binary_to_term
#   end

# end

defmodule Transform.BlobStore do
  defp write!(kind, ds_id, chunk) do
    relative = "#{kind}/#{ds_id}_chunk_#{UUID.uuid4}.csv"
    absolute = Application.get_env(:transform, :blobs)[:path]
    |> Path.join(relative)

    device = File.open!(absolute, [:write])
    IO.binwrite(device, :erlang.term_to_binary(chunk))
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
    |> File.read!
    |> :erlang.binary_to_term

  end

end