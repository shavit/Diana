defmodule VideoChat.IncomingStream do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    incoming_port = Application.get_env(:video_chat, :incoming_port)
    IO.puts "---> Listening on port #{incoming_port} for incoming stream"

    {:ok, _socket} = :gen_udp.open(incoming_port, [:binary,
      {:active, true}, {:buffer, 4096}
      ])
  end

  # Incoming streaming data from the webcam.
  def handle_info({:udp, _socket, _ip, _port, data}, state) do
    # IO.inspect "---> Received #{byte_size(data)} bytes from #{_port}"
    IO.inspect "---> Received #{byte_size(data)} bytes"
    message = parse_message(data)
    IO.inspect write_data(message.channel, message.data)

    # Write to the bucket
    VideoChat.EncodingBucket.add data
    VideoChat.EncodingBucket.push data

    {:noreply, state}
  end

  def handle_info({_, _socket}, state) do
    {:noreply, state}
  end

  defp write_data(channel, data) do
    File.write("tmp/picture-#{channel}.jpg", data)
  end

  # Optional format
  defp parse_message(message) do
    # channel: 001
    # resolution: 1 | 2 | 3 | 4
    # size: 4000
    # data: binary
    <<
      channel :: little-unsigned-integer-size(32),
      resolution :: little-unsigned-integer-size(8),
      size :: size(32),
      data :: binary
    >> = message

    IO.inspect "Channel #{channel} (#{<<channel>>})"
    IO.inspect "Resolution #{resolution}"
    IO.inspect "Size #{size}"

    %{
      channel: channel,
      resolution: resolution,
      size: size,
      data: data
    }
  end
end
