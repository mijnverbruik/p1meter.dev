defmodule LiveMeter.TCPServer do
  use GenServer

  require Logger

  alias LiveMeter.TCPClient
  alias LiveMeter.SmartMeter.Telegrams

  @default_name __MODULE__
  @default_accept_rate_limit {1, 20}
  @default_line_delay {:baud, 115_200}

  def start_link(opts) do
    name = Keyword.get(opts, :name, @default_name)

    if Keyword.get(opts, :enabled, true) do
      GenServer.start_link(__MODULE__, opts, name: name)
    else
      :ignore
    end
  end

  def broadcast(server \\ @default_name, telegram_string) when is_binary(telegram_string) do
    topic = GenServer.call(server, :pubsub_topic)
    Telegrams.broadcast_telegram(nil, telegram_string, topic)
  end

  def port(server \\ @default_name) do
    GenServer.call(server, :port)
  end

  @impl true
  def init(opts) do
    port = Keyword.get(opts, :port, 8080)
    pubsub_topic = Keyword.get(opts, :pubsub_topic, Telegrams.topic())
    max_clients = Keyword.get(opts, :max_clients, 100)
    max_clients_per_ip = Keyword.get(opts, :max_clients_per_ip, 5)
    accept_rate_limit = Keyword.get(opts, :accept_rate_limit, @default_accept_rate_limit)
    listen_backlog = Keyword.get(opts, :listen_backlog, 128)
    rate_limit_prefix = Keyword.get(opts, :rate_limit_prefix, :tcp_accept)
    line_delay = Keyword.get(opts, :line_delay, @default_line_delay)

    {:ok, listen_socket} =
      :gen_tcp.listen(port, [
        :binary,
        active: false,
        backlog: listen_backlog,
        reuseaddr: true,
        packet: :raw
      ])

    {:ok, actual_port} = :inet.port(listen_socket)
    server = self()
    {:ok, acceptor} = Task.start_link(fn -> accept_loop(server, listen_socket) end)

    Logger.info("Smart meter TCP server listening on port #{actual_port}")
    :ok = Telegrams.subscribe(pubsub_topic)

    {:ok,
     %{
       listen_socket: listen_socket,
       port: actual_port,
       pubsub_topic: pubsub_topic,
       acceptor: acceptor,
       max_clients: max_clients,
       max_clients_per_ip: max_clients_per_ip,
       accept_rate_limit: accept_rate_limit,
       rate_limit_prefix: rate_limit_prefix,
       line_delay: line_delay,
       clients: []
     }}
  end

  @impl true
  def handle_call(:port, _from, state) do
    {:reply, state.port, state}
  end

  def handle_call(:pubsub_topic, _from, state) do
    {:reply, state.pubsub_topic, state}
  end

  @impl true
  def handle_cast({:client_connected, client_socket}, state) do
    case peer_ip(client_socket) do
      {:ok, peer_ip} ->
        connect_client(client_socket, peer_ip, state)

      {:error, reason} ->
        Logger.debug("Rejecting smart meter TCP client without peer IP: #{inspect(reason)}")
        :gen_tcp.close(client_socket)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:smart_meter_telegram, _telegram, telegram_string}, state) do
    Enum.each(state.clients, fn client ->
      TCPClient.stream(client.pid, telegram_string)
    end)

    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {:noreply, remove_client(state, ref)}
  end

  def handle_info(message, state) do
    Logger.debug("Ignoring unexpected smart meter TCP server message: #{inspect(message)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    Enum.each(state.clients, fn client -> GenServer.stop(client.pid) end)
    :gen_tcp.close(state.listen_socket)
    :ok
  end

  defp connect_client(client_socket, peer_ip, state) do
    with :ok <- check_accept_rate(peer_ip, state),
         :ok <- check_client_capacity(peer_ip, state) do
      {:ok, client_pid} = TCPClient.start(client_socket, line_delay: state.line_delay)
      :ok = :gen_tcp.controlling_process(client_socket, client_pid)
      ref = Process.monitor(client_pid)
      TCPClient.activate(client_pid)
      Logger.debug("Smart meter TCP client connected: #{inspect(client_socket)}")

      client = %{socket: client_socket, peer_ip: peer_ip, pid: client_pid, ref: ref}
      {:noreply, %{state | clients: [client | state.clients]}}
    else
      {:error, reason} ->
        Logger.debug("Rejecting smart meter TCP client: #{inspect(reason)}")
        :gen_tcp.close(client_socket)
        {:noreply, state}
    end
  end

  defp check_accept_rate(_peer_ip, %{accept_rate_limit: false}), do: :ok

  defp check_accept_rate(peer_ip, state) do
    {refill_rate, capacity} = state.accept_rate_limit
    bucket = {state.rate_limit_prefix, peer_ip}

    case LiveMeter.RateLimit.hit(bucket, refill_rate, capacity) do
      {:allow, _count} -> :ok
      {:deny, _retry_after} -> {:error, :accept_rate_limited}
    end
  end

  defp check_client_capacity(peer_ip, state) do
    cond do
      length(state.clients) >= state.max_clients ->
        {:error, :max_clients_reached}

      client_count_for_ip(state.clients, peer_ip) >= state.max_clients_per_ip ->
        {:error, :max_clients_per_ip_reached}

      true ->
        :ok
    end
  end

  defp client_count_for_ip(clients, peer_ip) do
    Enum.count(clients, fn client -> client.peer_ip == peer_ip end)
  end

  defp remove_client(state, ref) do
    clients = Enum.reject(state.clients, fn client -> client.ref == ref end)
    %{state | clients: clients}
  end

  defp peer_ip(client_socket) do
    case :inet.peername(client_socket) do
      {:ok, {peer_ip, _port}} -> {:ok, peer_ip}
      {:error, reason} -> {:error, reason}
    end
  end

  defp accept_loop(server, listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, client_socket} ->
        case :gen_tcp.controlling_process(client_socket, server) do
          :ok ->
            GenServer.cast(server, {:client_connected, client_socket})

          {:error, reason} ->
            Logger.debug("Rejecting smart meter TCP client: #{inspect(reason)}")
            :gen_tcp.close(client_socket)
        end

        accept_loop(server, listen_socket)

      {:error, :closed} ->
        :ok

      {:error, reason} ->
        Logger.warning("Smart meter TCP accept failed: #{inspect(reason)}")
        accept_loop(server, listen_socket)
    end
  end
end
