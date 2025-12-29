defmodule LiveMeter.SmartMeter.Readings do
  @moduledoc false

  alias DSMR.{MBusDevice, Measurement, Telegram, Timestamp}

  def from_telegram(%Telegram{} = telegram) do
    %{
      measured_at: timestamp_value(telegram.measured_at),
      tariff: tariff(telegram.electricity_tariff_indicator),
      readings:
        [
          reading(
            "Electricity delivered T1",
            "1-0:1.8.1",
            telegram.electricity_delivered_1,
            integer_digits: 6
          ),
          reading(
            "Electricity delivered T2",
            "1-0:1.8.2",
            telegram.electricity_delivered_2,
            integer_digits: 6
          ),
          reading(
            "Electricity returned T1",
            "1-0:2.8.1",
            telegram.electricity_returned_1,
            integer_digits: 6
          ),
          reading(
            "Electricity returned T2",
            "1-0:2.8.2",
            telegram.electricity_returned_2,
            integer_digits: 6
          ),
          reading(
            "Current power usage",
            "1-0:1.7.0",
            telegram.electricity_currently_delivered,
            integer_digits: 2
          ),
          reading(
            "Current power return",
            "1-0:2.7.0",
            telegram.electricity_currently_returned,
            integer_digits: 2
          ),
          gas_reading(telegram.mbus_devices)
        ]
        |> Enum.reject(&is_nil/1)
    }
  end

  defp reading(description, obis, %Measurement{} = measurement, opts) do
    %{
      description: description,
      obis: obis,
      value: format_value(measurement.value, opts),
      unit: display_unit(measurement.unit)
    }
  end

  defp reading(_description, _obis, _measurement, _opts), do: nil

  defp gas_reading([%MBusDevice{last_reading_value: %Measurement{} = measurement} | _]) do
    reading("Gas delivered", "0-1:24.2.1", measurement, integer_digits: 5)
  end

  defp gas_reading(_devices), do: nil

  defp format_value(value, opts) when is_number(value) do
    decimals = Keyword.get(opts, :decimals, 3)
    integer_digits = Keyword.fetch!(opts, :integer_digits)
    value = :erlang.float_to_binary(value / 1, decimals: decimals)
    [integer, fractional] = String.split(value, ".", parts: 2)

    String.pad_leading(integer, integer_digits, "0") <> "." <> fractional
  end

  defp display_unit("m3"), do: "m³"
  defp display_unit(unit), do: unit

  defp tariff("0002"), do: 2
  defp tariff(_tariff), do: 1

  defp timestamp_value(%Timestamp{value: %NaiveDateTime{} = value}) do
    NaiveDateTime.to_iso8601(value)
  end

  defp timestamp_value(%Timestamp{value: value}), do: value
  defp timestamp_value(_timestamp), do: nil
end
