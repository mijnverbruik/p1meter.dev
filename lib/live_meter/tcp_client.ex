defmodule LiveMeter.TCPClient do
  use GenServer

  require Logger

  @default_line_delay {:baud, 115_200}

  def start(socket, opts) do
    GenServer.start(__MODULE__, {socket, opts})
  end

  def activate(client) do
    GenServer.cast(client, :activate)
  end

  def stream(client, telegram_string) when is_binary(telegram_string) do
    GenServer.cast(client, {:stream, telegram_string})
  end

  def lines(telegram_string) when is_binary(telegram_string) do
    split_lines(telegram_string, [])
  end

  @impl true
  def init({socket, opts}) do
    {:ok, %{socket: socket, line_delay: Keyword.get(opts, :line_delay, @default_line_delay)}}
  end

  @impl true
  def handle_cast(:activate, state) do
    :ok = :inet.setopts(state.socket, active: :once)
    {:noreply, state}
  end

  def handle_cast({:stream, telegram_string}, state) do
    case stream_lines(state.socket, lines(telegram_string), state.line_delay) do
      :ok ->
        {:noreply, state}

      {:error, reason} ->
        Logger.debug("Removing disconnected smart meter TCP client: #{inspect(reason)}")
        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_info({:tcp, socket, _data}, %{socket: socket} = state) do
    :inet.setopts(socket, active: :once)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, socket, reason}, %{socket: socket} = state) do
    Logger.debug("Removing errored smart meter TCP client: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, state) do
    :gen_tcp.close(state.socket)
    :ok
  end

  defp stream_lines(_socket, [], _line_delay), do: :ok

  defp stream_lines(socket, [line | remaining], line_delay) do
    case :gen_tcp.send(socket, line) do
      :ok ->
        sleep(line_delay, line)
        stream_lines(socket, remaining, line_delay)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp sleep(0, _line), do: :ok

  defp sleep({:baud, baud_rate}, line) when is_integer(baud_rate) and baud_rate > 0 do
    line
    |> byte_size()
    |> Kernel.*(10_000)
    |> ceil_div(baud_rate)
    |> max(1)
    |> Process.sleep()
  end

  defp sleep(delay, _line) when is_integer(delay) and delay > 0 do
    Process.sleep(delay)
  end

  defp split_lines("", []), do: []
  defp split_lines("", acc), do: Enum.reverse(acc)

  defp split_lines(telegram_string, acc) do
    case :binary.match(telegram_string, "\r\n") do
      {index, 2} ->
        line_size = index + 2
        <<line::binary-size(line_size), rest::binary>> = telegram_string
        split_lines(rest, [line | acc])

      :nomatch ->
        Enum.reverse([telegram_string | acc])
    end
  end

  defp ceil_div(dividend, divisor) do
    div(dividend + divisor - 1, divisor)
  end
end
