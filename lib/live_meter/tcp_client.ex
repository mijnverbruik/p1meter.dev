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
    {:ok,
     %{
       socket: socket,
       line_delay: Keyword.get(opts, :line_delay, @default_line_delay),
       remaining: [],
       next: nil
     }}
  end

  @impl true
  def handle_cast(:activate, state) do
    :ok = :inet.setopts(state.socket, active: :once)
    {:noreply, state}
  end

  def handle_cast({:stream, telegram_string}, %{remaining: []} = state) do
    send(self(), :send_line)
    {:noreply, %{state | remaining: lines(telegram_string)}}
  end

  # A slow client can fall behind the emission rate; only the latest telegram
  # matters, so a pending telegram is replaced by the newest one.
  def handle_cast({:stream, telegram_string}, state) do
    {:noreply, %{state | next: lines(telegram_string)}}
  end

  @impl true
  def handle_info(:send_line, %{remaining: []} = state), do: {:noreply, state}

  def handle_info(:send_line, %{remaining: [line | rest]} = state) do
    case :gen_tcp.send(state.socket, line) do
      :ok ->
        state = advance_stream(%{state | remaining: rest})

        if state.remaining != [] do
          Process.send_after(self(), :send_line, delay_for(state.line_delay, line))
        end

        {:noreply, state}

      {:error, reason} ->
        Logger.debug("Removing disconnected smart meter TCP client: #{inspect(reason)}")
        {:stop, :normal, state}
    end
  end

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

  defp advance_stream(%{remaining: [], next: next} = state) when next != nil do
    %{state | remaining: next, next: nil}
  end

  defp advance_stream(state), do: state

  defp delay_for(0, _line), do: 0

  defp delay_for({:baud, baud_rate}, line) when is_integer(baud_rate) and baud_rate > 0 do
    line
    |> byte_size()
    |> Kernel.*(10_000)
    |> ceil_div(baud_rate)
    |> max(1)
  end

  defp delay_for(delay, _line) when is_integer(delay) and delay > 0 do
    delay
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
