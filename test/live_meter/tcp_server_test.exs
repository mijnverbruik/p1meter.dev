defmodule LiveMeter.TCPServerTest do
  use ExUnit.Case, async: true

  alias LiveMeter.TCPClient
  alias LiveMeter.TCPServer
  alias LiveMeter.SmartMeter.Telegrams

  test "telegram lines preserve CRLF delimiters and blank lines" do
    telegram = "/TEST\r\n\r\n1-3:0.2.8(50)\r\n!0000\r\n"

    assert TCPClient.lines(telegram) == [
             "/TEST\r\n",
             "\r\n",
             "1-3:0.2.8(50)\r\n",
             "!0000\r\n"
           ]
  end

  test "PubSub telegrams are sent to clients connected in parallel" do
    name = unique_name("tcp-server")
    topic = unique_topic("tcp-server")
    start_tcp_server(name: name, port: 0, pubsub_topic: topic)

    port = TCPServer.port(name)
    clients = connect_clients(port, 3)
    telegram = "/TEST\r\n\r\n1-3:0.2.8(50)\r\n!0000\r\n"

    wait_until_client_count(name, 3)
    Telegrams.broadcast_telegram(nil, telegram, topic)

    for client <- clients do
      assert {:ok, ^telegram} = recv_until(client, telegram)
    end

    Enum.each(clients, &:gen_tcp.close/1)
  end

  test "PubSub telegrams are streamed line by line" do
    name = unique_name("tcp-server")
    topic = unique_topic("tcp-server")
    start_tcp_server(name: name, port: 0, pubsub_topic: topic, line_delay: 5)

    client = connect_client(TCPServer.port(name))
    telegram = "/TEST\r\n\r\n1-3:0.2.8(50)\r\n!0000\r\n"

    wait_until_client_count(name, 1)
    Telegrams.broadcast_telegram(nil, telegram, topic)

    for line <- TCPClient.lines(telegram) do
      assert {:ok, ^line} = :gen_tcp.recv(client, 0, 1_000)
    end

    :gen_tcp.close(client)
  end

  test "closing one client does not prevent other clients from receiving later broadcasts" do
    name = unique_name("tcp-server")
    topic = unique_topic("tcp-server")
    start_tcp_server(name: name, port: 0, pubsub_topic: topic)

    port = TCPServer.port(name)
    [closed_client, active_client] = connect_clients(port, 2)
    wait_until_client_count(name, 2)

    :gen_tcp.close(closed_client)

    first = "first\r\n"
    second = "second\r\n"

    Telegrams.broadcast_telegram(nil, first, topic)
    assert {:ok, ^first} = recv_until(active_client, first)

    Telegrams.broadcast_telegram(nil, second, topic)
    assert {:ok, ^second} = recv_until(active_client, second)

    :gen_tcp.close(active_client)
  end

  test "smart meter broadcasts generated telegrams through TCP server" do
    tcp_name = unique_name("tcp-server")
    meter_name = unique_name("smart-meter")
    topic = unique_topic("smart-meter")

    start_tcp_server(name: tcp_name, port: 0, pubsub_topic: topic)
    client = connect_client(TCPServer.port(tcp_name))

    start_supervised!(
      {LiveMeter.SmartMeter,
       name: meter_name, pubsub_topic: topic, interval: 10, virtual_time: ~N[2026-05-12 12:00:00]}
    )

    assert {:ok, telegram_string} = recv_until_telegram(client)
    assert {:ok, telegram} = DSMR.parse(telegram_string)
    assert telegram.version == "50"

    :gen_tcp.close(client)
  end

  test "rejects clients above the configured total client cap" do
    name = unique_name("tcp-server")
    topic = unique_topic("tcp-server")

    start_tcp_server(
      name: name,
      port: 0,
      pubsub_topic: topic,
      max_clients: 2,
      max_clients_per_ip: 10,
      accept_rate_limit: false
    )

    port = TCPServer.port(name)
    [first, second] = connect_clients(port, 2)
    rejected = connect_client(port)

    wait_until_client_count(name, 2)
    telegram = "limited\r\n"
    Telegrams.broadcast_telegram(nil, telegram, topic)

    assert {:ok, ^telegram} = recv_until(first, telegram)
    assert {:ok, ^telegram} = recv_until(second, telegram)
    assert_closed(rejected)

    Enum.each([first, second, rejected], &:gen_tcp.close/1)
  end

  test "rejects clients above the configured per-IP client cap" do
    name = unique_name("tcp-server")
    topic = unique_topic("tcp-server")

    start_tcp_server(
      name: name,
      port: 0,
      pubsub_topic: topic,
      max_clients: 10,
      max_clients_per_ip: 2,
      accept_rate_limit: false
    )

    port = TCPServer.port(name)
    [first, second] = connect_clients(port, 2)
    rejected = connect_client(port)

    wait_until_client_count(name, 2)
    telegram = "per-ip-limited\r\n"
    Telegrams.broadcast_telegram(nil, telegram, topic)

    assert {:ok, ^telegram} = recv_until(first, telegram)
    assert {:ok, ^telegram} = recv_until(second, telegram)
    assert_closed(rejected)

    Enum.each([first, second, rejected], &:gen_tcp.close/1)
  end

  test "rejects clients above the configured accept rate limit" do
    name = unique_name("tcp-server")
    topic = unique_topic("tcp-server")

    start_tcp_server(
      name: name,
      port: 0,
      pubsub_topic: topic,
      max_clients: 10,
      max_clients_per_ip: 10,
      accept_rate_limit: {1, 2},
      rate_limit_prefix: unique_name("tcp-accept")
    )

    port = TCPServer.port(name)
    [first, second] = connect_clients(port, 2)
    rejected = connect_client(port)

    wait_until_client_count(name, 2)
    telegram = "rate-limited\r\n"
    Telegrams.broadcast_telegram(nil, telegram, topic)

    assert {:ok, ^telegram} = recv_until(first, telegram)
    assert {:ok, ^telegram} = recv_until(second, telegram)
    assert_closed(rejected)

    Enum.each([first, second, rejected], &:gen_tcp.close/1)
  end

  defp connect_clients(port, count) do
    owner = self()

    1..count
    |> Task.async_stream(
      fn _ ->
        socket = connect_client(port)
        :ok = :gen_tcp.controlling_process(socket, owner)
        socket
      end,
      timeout: :infinity
    )
    |> Enum.map(fn {:ok, socket} -> socket end)
  end

  defp connect_client(port) do
    {:ok, socket} =
      :gen_tcp.connect(~c"localhost", port, [
        :binary,
        active: false,
        packet: :raw
      ])

    socket
  end

  defp start_tcp_server(opts) do
    start_supervised!({TCPServer, Keyword.put_new(opts, :line_delay, 0)})
  end

  defp recv_until(socket, expected) do
    recv_until(socket, expected, "")
  end

  defp recv_until(_socket, expected, received) when byte_size(received) >= byte_size(expected) do
    {:ok, received}
  end

  defp recv_until(socket, expected, received) do
    case :gen_tcp.recv(socket, 0, 1_000) do
      {:ok, chunk} -> recv_until(socket, expected, received <> chunk)
      error -> error
    end
  end

  defp recv_until_telegram(socket) do
    recv_until_telegram(socket, "")
  end

  defp recv_until_telegram(socket, received) do
    if Regex.match?(~r/![0-9A-F]{4}\r\n/s, received) do
      {:ok, received}
    else
      case :gen_tcp.recv(socket, 0, 1_000) do
        {:ok, chunk} -> recv_until_telegram(socket, received <> chunk)
        error -> error
      end
    end
  end

  defp wait_until_client_count(name, count) do
    state = :sys.get_state(name)

    if length(state.clients) >= count do
      state
    else
      receive do
      after
        10 -> wait_until_client_count(name, count)
      end
    end
  end

  defp assert_closed(socket) do
    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 1_000)
  end

  defp unique_name(prefix) do
    :"#{prefix}-#{System.unique_integer([:positive])}"
  end

  defp unique_topic(prefix) do
    "#{prefix}:#{System.unique_integer([:positive])}"
  end
end
