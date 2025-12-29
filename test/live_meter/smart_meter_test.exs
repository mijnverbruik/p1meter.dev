defmodule LiveMeter.SmartMeterTest do
  use ExUnit.Case, async: true

  alias LiveMeter.SmartMeter
  alias LiveMeter.SmartMeter.{Readings, Telegrams}

  test "latest_telegram_string returns a parseable DSMR telegram with a valid checksum" do
    name = unique_name("smart-meter")

    start_supervised!(
      {SmartMeter, name: name, interval: 60_000, virtual_time: ~N[2026-05-12 12:00:00]}
    )

    telegram_string = SmartMeter.latest_telegram_string(name)

    assert {:ok, telegram} = DSMR.parse(telegram_string)
    assert telegram.version == "50"
    assert telegram.electricity_currently_delivered.value == 0.0
  end

  test "restarting the smart meter resets virtual time and counters to configured defaults" do
    name = unique_name("smart-meter")
    virtual_time = ~N[2026-05-12 12:00:00]

    spec =
      {SmartMeter,
       name: name, interval: 60_000, virtual_time: virtual_time, electricity_delivered_1: 10.0}

    pid = start_supervised!(spec)
    ref = Process.monitor(pid)

    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

    wait_until_registered(name)
    telegram = SmartMeter.latest_telegram(name)

    assert telegram.measured_at.value == virtual_time
    assert telegram.electricity_delivered_1.value == 10.0
  end

  test "emitted telegrams are published to PubSub" do
    name = unique_name("smart-meter")
    topic = unique_topic("smart-meter")

    :ok = Telegrams.subscribe(topic)

    start_supervised!(
      {SmartMeter,
       name: name, interval: 10, pubsub_topic: topic, virtual_time: ~N[2026-05-12 12:00:00]}
    )

    assert_receive {:smart_meter_telegram, telegram, telegram_string}, 1_000
    assert {:ok, parsed_telegram} = DSMR.parse(telegram_string)
    assert parsed_telegram.measured_at == telegram.measured_at
    assert telegram.version == "50"
  end

  test "emitted telegrams advance virtual time by the interval" do
    name = unique_name("smart-meter")
    topic = unique_topic("smart-meter")

    :ok = Telegrams.subscribe(topic)

    start_supervised!(
      {SmartMeter,
       name: name, interval: 10_000, pubsub_topic: topic, virtual_time: ~N[2026-05-12 12:00:00]}
    )

    send(Process.whereis(name), :emit_telegram)

    assert_receive {:smart_meter_telegram, telegram, _telegram_string}, 1_000
    assert telegram.measured_at.value == ~N[2026-05-12 12:00:10]
  end

  test "readings formats a telegram for the meter display" do
    name = unique_name("smart-meter")

    start_supervised!(
      {SmartMeter,
       name: name,
       interval: 60_000,
       virtual_time: ~N[2026-05-12 23:00:00],
       electricity_delivered_1: 10.0,
       electricity_delivered_2: 20.0,
       electricity_returned_1: 1.0,
       electricity_returned_2: 2.0,
       gas_delivered: 30.0}
    )

    payload = name |> SmartMeter.latest_telegram() |> Readings.from_telegram()

    assert payload.tariff == 2
    assert payload.measured_at == "2026-05-12T23:00:00"

    assert %{value: "000010.000", unit: "kWh"} =
             Enum.find(payload.readings, &(&1.obis == "1-0:1.8.1"))

    assert %{value: "00030.000", unit: "m³"} =
             Enum.find(payload.readings, &(&1.obis == "0-1:24.2.1"))
  end

  defp wait_until_registered(name) do
    case Process.whereis(name) do
      nil ->
        receive do
        after
          10 -> wait_until_registered(name)
        end

      pid ->
        _ = :sys.get_state(pid)
        pid
    end
  end

  defp unique_name(prefix) do
    :"#{prefix}-#{System.unique_integer([:positive])}"
  end

  defp unique_topic(prefix) do
    "#{prefix}:#{System.unique_integer([:positive])}"
  end
end
