defmodule TransformChannelTest do
  use Phoenix.ChannelTest
  use Phoenix.ConnTest
  use ExUnit.Case
  use Plug.Test
  import TestHelpers
  alias Transform.Router
  alias Phoenix.Socket.Message

  @endpoint Transform.Endpoint
  @opts Router.init([])

  @headers [
    {"Content-Type", "text/plain"}
  ]

  defp make_socket() do
    channel_name = "transform:ffff-ffff"

    {:ok, _, socket} = socket("unused", %{})
    |> subscribe_and_join(
      Transform.Channels.Transform, channel_name, %{}
    )

    @endpoint.subscribe(self(), channel_name)

    socket
  end

  # helper to receive the `expr` n times, and evaluate
  # to the body given the expr in the receive match
  defmacro receive_n(count, expr, body) do
    quote do
      Enum.reduce(1..unquote(count), [], fn i, acc ->
        receive do
          unquote(expr) ->
            [unquote(body[:do]) | acc]
        after 200 ->
          raise RuntimeError, message: "receive timeout on #{i}"
        end
      end)
      |> Enum.reverse
    end
  end

  defp chunk_size do
    Application.get_env(:transform, :basic_table)[:chunk_size]
  end


  test "can post a csv and get some progress back" do
    sock = make_socket

    body = fixture!("911-10k.csv") |> Enum.into("")

    res = conn
    |> put_req_header("content-type", "text/plain")
    |> post("/api/basictable/ffff-ffff", body)


    #10k rows with 512 rows per row is 20 chunks.
    expected = trunc(Float.ceil(10_000 / chunk_size))

    # we should get 20 progress messages
    receive_n expected, %Message{
      event: "dataset:progress",
      payload: %{stage: "transform"} = p} do
      :ok
    end

    # we should also get 20 extraction messages
    receive_n expected, %Message{
      event: "dataset:progress",
      payload: %{stage: "extract"} = p} do
      p
    end

  end

  test "can post a csv and then change the transform to re-run the job" do
    sock = make_socket

    body = fixture!("911-10k.csv") |> Enum.into("")

    res = conn
    |> put_req_header("content-type", "text/plain")
    |> post("/api/basictable/ffff-ffff", body)

    expected = trunc(Float.ceil(10_000 / chunk_size))
    receive_n (expected * 2), %Message{event: "dataset:progress"}, do: :ok

    transforms = %{"transforms" => []}
    ref = push sock, "transform", transforms

    assert_reply ref, :ok, %{}

    # should only get progress messages for the transform
    # stage and not the extraction stage bc they're already
    # extracted
    receive_n expected, %Message{
      event: "dataset:progress",
      payload: %{stage: "transform"}
    }, do: :ok

    # assert that there aren't any more progress messages
    # in the queue, there should be exactly `expected`
    result = receive do
      %Message{
        event: "dataset:progress",
        payload: %{stage: "transform"}
      } -> :error
    after 0 -> :ok
    end

    assert result == :ok
  end

end