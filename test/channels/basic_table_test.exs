defmodule BasicTableTest do
  use Phoenix.ChannelTest
  use ExUnit.Case
  import TestHelpers
  @endpoint Transform.Endpoint

  # defp make_socket() do
  #   channel_name = "basictable:ffff-ffff"

  #   {:ok, _, socket} = socket("unused", %{})
  #   |> subscribe_and_join(
  #     Transform.Channels.BasicTable, channel_name, %{}
  #   )

  #   @endpoint.subscribe(self(), channel_name)

  #   socket
  # end


  test "can do a thing" do
    # sock = make_socket

    # fixture!("test.csv")
    # |> Stream.chunk(2)
    # |> Stream.each(fn chunk -> 
    #   push(sock, "chunk", chunk)
    # end)
    # |> Stream.run

    # receive do
    #   _ -> :ok
    # after 100 -> :ok
    # end
    
    # assert_broadcast()

  end
end