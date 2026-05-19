defmodule LiveMeterWeb.HomeLive do
  use LiveMeterWeb, :live_view

  alias LiveMeter.SmartMeter
  alias LiveMeter.SmartMeter.{Readings, Telegrams}

  attr :active?, :boolean, required: true
  attr :label, :string, required: true

  def tariff_indicator(assigns) do
    ~H"""
    <div class={["flex items-center gap-1", if(@active?, do: "opacity-100", else: "opacity-30")]}>
      <div class={[
        "w-1.5 h-1.5 rounded-full",
        if(@active?,
          do: "bg-[#7fff7f] shadow-[0_0_4px_rgba(127,255,127,0.8)]",
          else: "bg-[#3a5f3a]"
        )
      ]}>
      </div>
      <span class="text-[10px] font-bold">{@label}</span>
    </div>
    """
  end

  attr :active?, :boolean, required: true

  def reading_dot(assigns) do
    ~H"""
    <div class={[
      "w-1.5 h-1.5 rounded-full transition-colors",
      if(@active?, do: "bg-[#7fff7f]", else: "bg-[#3a5f3a]")
    ]}>
    </div>
    """
  end

  attr :connected?, :boolean, required: true

  def connection_light(assigns) do
    ~H"""
    <div class={[
      "w-2 h-2 rounded-full",
      if(@connected?,
        do: "bg-green-500 shadow-[0_0_6px_rgba(34,197,94,0.8)]",
        else: "bg-[#333]"
      )
    ]}>
    </div>
    """
  end

  @zero_readings [
    %{
      description: "Electricity delivered T1",
      obis: "1-0:1.8.1",
      value: "000000.000",
      unit: "kWh"
    },
    %{
      description: "Electricity delivered T2",
      obis: "1-0:1.8.2",
      value: "000000.000",
      unit: "kWh"
    },
    %{
      description: "Electricity returned T1",
      obis: "1-0:2.8.1",
      value: "000000.000",
      unit: "kWh"
    },
    %{
      description: "Electricity returned T2",
      obis: "1-0:2.8.2",
      value: "000000.000",
      unit: "kWh"
    },
    %{description: "Current power usage", obis: "1-0:1.7.0", value: "00.000", unit: "kW"},
    %{description: "Current power return", obis: "1-0:2.7.0", value: "00.000", unit: "kW"},
    %{description: "Gas delivered", obis: "0-1:24.2.1", value: "00000.000", unit: "m³"}
  ]

  @sample_telegram """
  /XMX5XMXABCE000012345

  1-3:0.2.8(50)
  0-0:1.0.0(231026153022S)
  0-0:96.1.1(4530303130343435363738393031323334353637383930313233)
  1-0:1.8.1(000123.456*kWh)
  1-0:1.8.2(000123.456*kWh)
  1-0:2.8.1(000000.000*kWh)
  1-0:2.8.2(000000.000*kWh)
  0-0:96.14.0(0002)
  1-0:1.7.0(00.453*kW)
  1-0:2.7.0(00.000*kW)
  !A1B2
  """

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :ok = Telegrams.subscribe()
    end

    snapshot = latest_snapshot()

    {:ok,
     socket
     |> assign(:page_title, "Home")
     |> assign(:is_connected, connected?(socket))
     |> assign(:current_index, 0)
     |> assign_snapshot(snapshot)}
  end

  @impl true
  def handle_event("cycle_reading", _params, socket) do
    {:noreply, cycle_current_reading(socket)}
  end

  @impl true
  def handle_info({:smart_meter_telegram, nil, telegram_string}, socket) do
    {:noreply, assign(socket, :raw_telegram, telegram_string)}
  end

  def handle_info({:smart_meter_telegram, telegram, telegram_string}, socket) do
    {:noreply,
     socket
     |> assign_snapshot(%{
       payload: Readings.from_telegram(telegram),
       raw_telegram: telegram_string
     })}
  end

  defp latest_snapshot do
    case latest_telegram_snapshot() do
      {telegram, telegram_string} ->
        %{payload: Readings.from_telegram(telegram), raw_telegram: telegram_string}

      nil ->
        %{payload: zero_payload(), raw_telegram: @sample_telegram}
    end
  end

  defp latest_telegram_snapshot do
    {SmartMeter.latest_telegram(), SmartMeter.latest_telegram_string()}
  catch
    :exit, _reason -> nil
  end

  defp zero_payload do
    %{tariff: 1, readings: @zero_readings}
  end

  defp assign_snapshot(socket, %{payload: payload, raw_telegram: raw_telegram}) do
    socket
    |> assign(:raw_telegram, raw_telegram)
    |> assign_payload(payload)
  end

  defp assign_payload(socket, %{tariff: tariff, readings: readings}) do
    current_index = bounded_index(Map.get(socket.assigns, :current_index, 0), readings)

    socket
    |> assign(:current_tariff, tariff)
    |> assign(:meter_readings, readings)
    |> assign_current_reading(current_index)
  end

  defp cycle_current_reading(%{assigns: %{meter_readings: []}} = socket), do: socket

  defp cycle_current_reading(socket) do
    reading_count = length(socket.assigns.meter_readings)
    current_index = rem(socket.assigns.current_index + 1, reading_count)

    assign_current_reading(socket, current_index)
  end

  defp assign_current_reading(socket, current_index) do
    socket
    |> assign(:current_index, current_index)
    |> assign(:current_reading, Enum.at(socket.assigns.meter_readings, current_index))
  end

  defp bounded_index(_current_index, []), do: 0
  defp bounded_index(current_index, readings), do: min(current_index, length(readings) - 1)
end
