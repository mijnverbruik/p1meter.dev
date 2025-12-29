defmodule LiveMeter.SmartMeter do
  use GenServer

  require Logger

  alias DSMR.{MBusDevice, Measurement, Telegram, Timestamp}
  alias LiveMeter.SmartMeter.Telegrams

  @default_name __MODULE__

  def start_link(opts) do
    name = Keyword.get(opts, :name, @default_name)

    if Keyword.get(opts, :enabled, true) do
      GenServer.start_link(__MODULE__, opts, name: name)
    else
      :ignore
    end
  end

  def stop(server \\ @default_name) do
    GenServer.stop(server)
  end

  def latest_telegram(server \\ @default_name) do
    GenServer.call(server, :latest_telegram)
  end

  def latest_telegram_string(server \\ @default_name) do
    GenServer.call(server, :latest_telegram_string)
  end

  @impl true
  def init(opts) do
    state = %{
      interval: Keyword.get(opts, :interval, 10_000),
      pubsub_topic: Keyword.get(opts, :pubsub_topic, Telegrams.topic()),
      virtual_time: Keyword.get(opts, :virtual_time, NaiveDateTime.utc_now()),
      electricity_delivered_1: Keyword.get(opts, :electricity_delivered_1, 1234.567),
      electricity_delivered_2: Keyword.get(opts, :electricity_delivered_2, 2345.678),
      electricity_returned_1: Keyword.get(opts, :electricity_returned_1, 123.456),
      electricity_returned_2: Keyword.get(opts, :electricity_returned_2, 234.567),
      gas_delivered: Keyword.get(opts, :gas_delivered, 987.654),
      latest_telegram: nil,
      latest_telegram_string: nil
    }

    state = put_latest_telegram(state)
    schedule_emission(state.interval)

    {:ok, state}
  end

  @impl true
  def handle_call(:latest_telegram, _from, state) do
    {:reply, state.latest_telegram, state}
  end

  def handle_call(:latest_telegram_string, _from, state) do
    {:reply, state.latest_telegram_string, state}
  end

  @impl true
  def handle_info(:emit_telegram, state) do
    state =
      state
      |> advance()
      |> put_latest_telegram()

    Telegrams.broadcast_telegram(
      state.latest_telegram,
      state.latest_telegram_string,
      state.pubsub_topic
    )

    Logger.debug("Emitted smart meter telegram for #{state.virtual_time}")
    schedule_emission(state.interval)

    {:noreply, state}
  end

  defp advance(state) do
    interval_seconds = div(state.interval, 1000)
    virtual_time = NaiveDateTime.add(state.virtual_time, interval_seconds, :second)
    hour = virtual_time.hour
    minute = virtual_time.minute
    time_of_day = (hour * 60 + minute) / (24 * 60)

    phase = (time_of_day - 0.75) * 2 * :math.pi()
    wave = (:math.cos(phase) + 1) / 2
    current_power = max(0.0, (0.2 + wave * 2.3) * noise_factor())
    energy_increment = current_power * (state.interval / 1000 / 3600)

    {delivered_1, delivered_2} =
      if night_tariff?(hour) do
        {state.electricity_delivered_1, state.electricity_delivered_2 + energy_increment}
      else
        {state.electricity_delivered_1 + energy_increment, state.electricity_delivered_2}
      end

    {current_returned, returned_1, returned_2} =
      if hour >= 10 and hour < 17 and :rand.uniform() < 0.3 do
        returned_power = :rand.uniform() * 1.5
        returned_increment = returned_power * (state.interval / 1000 / 3600)

        {returned_power, state.electricity_returned_1 + returned_increment,
         state.electricity_returned_2}
      else
        {0.0, state.electricity_returned_1, state.electricity_returned_2}
      end

    gas_increment = if minute == 0, do: 0.2, else: 0.0

    Map.merge(state, %{
      virtual_time: virtual_time,
      electricity_delivered_1: delivered_1,
      electricity_delivered_2: delivered_2,
      electricity_returned_1: returned_1,
      electricity_returned_2: returned_2,
      gas_delivered: state.gas_delivered + gas_increment,
      current_power: current_power,
      current_returned: current_returned
    })
  end

  defp put_latest_telegram(state) do
    telegram = build_telegram(state)
    checksum = checksum_for(telegram)
    telegram = %{telegram | checksum: checksum}
    telegram_string = Telegram.to_string(telegram)

    %{state | latest_telegram: telegram, latest_telegram_string: telegram_string}
  end

  defp build_telegram(state) do
    hour = state.virtual_time.hour

    %Telegram{
      header: "ISk5\\2MT382-1000",
      version: "50",
      measured_at: timestamp(state.virtual_time),
      equipment_id: "4530303437303030303037363330383137",
      electricity_delivered_1: measurement(state.electricity_delivered_1, "kWh"),
      electricity_delivered_2: measurement(state.electricity_delivered_2, "kWh"),
      electricity_returned_1: measurement(state.electricity_returned_1, "kWh"),
      electricity_returned_2: measurement(state.electricity_returned_2, "kWh"),
      electricity_tariff_indicator: if(night_tariff?(hour), do: "0002", else: "0001"),
      electricity_currently_delivered: measurement(Map.get(state, :current_power, 0.0), "kW"),
      electricity_currently_returned: measurement(Map.get(state, :current_returned, 0.0), "kW"),
      power_failures_count: "0",
      power_failures_long_count: "0",
      voltage_sags_l1_count: "0",
      voltage_swells_l1_count: "0",
      mbus_devices: [
        %MBusDevice{
          channel: 1,
          device_type: "003",
          equipment_id: "4730303339303031373434313430323137",
          last_reading_measured_at: timestamp(state.virtual_time),
          last_reading_value: measurement(state.gas_delivered, "m3")
        }
      ],
      checksum: "0000"
    }
  end

  defp checksum_for(%Telegram{} = telegram) do
    telegram
    |> Telegram.to_string()
    |> String.split("!", parts: 2)
    |> List.first()
    |> Kernel.<>("!")
    |> DSMR.CRC16.checksum()
  end

  defp measurement(value, unit) do
    %Measurement{value: Float.round(value, 3), unit: unit}
  end

  defp timestamp(virtual_time) do
    %Timestamp{value: virtual_time, dst: "W"}
  end

  defp night_tariff?(hour), do: hour >= 23 or hour < 7

  defp noise_factor, do: 1 + (:rand.uniform() * 0.2 - 0.1)

  defp schedule_emission(interval) do
    Process.send_after(self(), :emit_telegram, interval)
  end
end
