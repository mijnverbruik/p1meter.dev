defmodule LiveMeterWeb.HomeLive do
  use LiveMeterWeb, :live_view

  alias LiveMeter.SmartMeter
  alias LiveMeter.SmartMeter.{Readings, Telegrams}
  alias LiveMeterWeb.CodeHighlight

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

  attr :id, :string, required: true
  attr :number, :string, required: true
  attr :title, :string, required: true
  attr :live?, :boolean, default: false

  def section_heading(assigns) do
    ~H"""
    <div class="flex items-baseline gap-3 mb-5">
      <span class="font-mono text-xs font-semibold text-green-700 dark:text-[#7fff7f] tracking-widest">
        {@number}
      </span>
      <h2
        id={@id}
        class="text-lg font-bold font-mono uppercase tracking-tight m-0 text-neutral-900 dark:text-neutral-100 flex items-center gap-2.5"
      >
        {@title}
        <span :if={@live?} class="relative flex h-2.5 w-2.5" aria-hidden="true">
          <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75">
          </span>
          <span class="relative inline-flex rounded-full h-2.5 w-2.5 bg-green-500"></span>
        </span>
      </h2>
      <span class="flex-1 border-t border-dashed border-neutral-200 dark:border-neutral-800 self-center">
      </span>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :rounded, :string, default: "rounded-lg", doc: "rounding classes for the frame corners"
  attr :rest, :global
  slot :inner_block, required: true
  slot :actions

  def terminal_frame(assigns) do
    ~H"""
    <div
      class={[
        @rounded,
        "overflow-hidden border border-neutral-200 dark:border-neutral-800 shadow-lg shadow-neutral-900/5 dark:shadow-black/40 flex flex-col"
      ]}
      {@rest}
    >
      <div class="bg-neutral-800 dark:bg-neutral-900 px-4 py-2 flex items-center gap-2 border-b border-neutral-700/60 dark:border-neutral-800">
        <div class="flex gap-1.5" aria-hidden="true">
          <div class="w-3 h-3 rounded-full bg-red-500/80"></div>
          <div class="w-3 h-3 rounded-full bg-yellow-500/80"></div>
          <div class="w-3 h-3 rounded-full bg-green-500/80"></div>
        </div>
        <span class="text-neutral-500 text-xs font-mono ml-2">{@title}</span>
        <div :if={@actions != []} class="ml-auto flex items-center">
          {render_slot(@actions)}
        </div>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # Widths (in px) mimicking an EAN-style barcode, rendered as a single SVG.
  @barcode_bars [
    2,
    1,
    1,
    2,
    1,
    2,
    2,
    1,
    1,
    2,
    1,
    1,
    2,
    1,
    2,
    1,
    1,
    2,
    2,
    1,
    1,
    2,
    1,
    2,
    1,
    1,
    2,
    1,
    2,
    1,
    1,
    2
  ]

  def barcode(assigns) do
    {bars, width} =
      Enum.map_reduce(@barcode_bars, 0, fn bar_width, x ->
        {%{x: x, width: bar_width}, x + bar_width + 1}
      end)

    assigns = assign(assigns, bars: bars, width: width - 1)

    ~H"""
    <svg
      viewBox={"0 0 #{@width} 16"}
      class="h-4 fill-[#333]"
      preserveAspectRatio="none"
      style={"width: #{@width}px"}
      aria-hidden="true"
    >
      <rect :for={bar <- @bars} x={bar.x} y="0" width={bar.width} height="16" />
    </svg>
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

  @examples_dir Path.expand("../../../priv/examples", __DIR__)

  @external_resource Path.join(@examples_dir, "client.js")
  @external_resource Path.join(@examples_dir, "client.py")
  @external_resource Path.join(@examples_dir, "client.go")

  @developer_examples [
    %{
      id: "node",
      label: "Node.js",
      filename: "client.js",
      language: "JavaScript",
      source: File.read!(Path.join(@examples_dir, "client.js"))
    },
    %{
      id: "python",
      label: "Python",
      filename: "client.py",
      language: "Python",
      source: File.read!(Path.join(@examples_dir, "client.py"))
    },
    %{
      id: "go",
      label: "Go",
      filename: "client.go",
      language: "Go",
      source: File.read!(Path.join(@examples_dir, "client.go"))
    }
  ]

  @example_ids Enum.map(@developer_examples, & &1.id)

  @highlighted_examples Enum.map(@developer_examples, fn example ->
                          example
                          |> Map.put(
                            :code,
                            CodeHighlight.highlight(example.source, example.language)
                          )
                          |> Map.delete(:source)
                        end)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :ok = Telegrams.subscribe()
    end

    snapshot = latest_snapshot()

    {:ok,
     socket
     |> assign(:page_title, "p1meter.dev — Virtual P1 Simulator")
     |> assign(:is_connected, connected?(socket))
     |> assign(:current_index, 0)
     |> assign(:developer_examples, @highlighted_examples)
     |> assign(:current_example_id, hd(@example_ids))
     |> assign_snapshot(snapshot)}
  end

  @impl true
  def handle_event("cycle_reading", _params, socket) do
    {:noreply, cycle_current_reading(socket)}
  end

  def handle_event("select_example", %{"id" => id}, socket) when id in @example_ids do
    {:noreply, assign(socket, :current_example_id, id)}
  end

  def handle_event("select_example", _params, socket), do: {:noreply, socket}

  @impl true
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
      {telegram, telegram_string} when telegram != nil and telegram_string != nil ->
        %{payload: Readings.from_telegram(telegram), raw_telegram: telegram_string}

      _ ->
        %{payload: zero_payload(), raw_telegram: @sample_telegram}
    end
  end

  defp latest_telegram_snapshot do
    SmartMeter.latest_snapshot()
  catch
    :exit, {:noproc, _} -> nil
  end

  defp zero_payload do
    %{tariff: 1, readings: @zero_readings}
  end

  defp assign_snapshot(socket, %{payload: payload, raw_telegram: raw_telegram}) do
    socket
    |> assign(:raw_telegram, raw_telegram)
    |> assign_payload(payload)
  end

  defp assign_payload(socket, %{tariff: tariff, readings: []}),
    do: assign_payload(socket, %{tariff: tariff, readings: @zero_readings})

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
