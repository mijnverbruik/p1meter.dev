defmodule LiveMeterWeb.HomeLiveTest do
  use LiveMeterWeb.ConnCase

  import Phoenix.LiveViewTest

  alias LiveMeter.SmartMeter
  alias LiveMeter.SmartMeter.Telegrams

  test "renders the landing page and meter shell", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ "Virtual Smart Meter P1 Simulator"
    assert html =~ "Electricity delivered T1"
    assert html =~ "000000.000"
  end

  test "cycles through meter readings", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert view |> element("#cycle-meter-reading") |> render_click() =~
             "Electricity delivered T2"
  end

  test "updates meter display and raw telegram from broadcasts", %{conn: conn} do
    name = unique_name("smart-meter")

    start_supervised!(
      {SmartMeter,
       name: name,
       interval: 60_000,
       virtual_time: ~N[2026-05-12 23:00:00],
       electricity_delivered_1: 10.0}
    )

    {:ok, view, _html} = live(conn, ~p"/")

    telegram = SmartMeter.latest_telegram(name)
    raw_telegram = SmartMeter.latest_telegram_string(name)

    delivered_line =
      raw_telegram
      |> String.split("\n")
      |> Enum.find(&String.contains?(&1, "1-0:1.8.1"))
      |> String.trim()

    :ok = Telegrams.broadcast_telegram(telegram, raw_telegram)

    html = render(view)

    assert html =~ "000010.000"
    assert html =~ "/ISk5\\2MT382-1000"
    assert html =~ delivered_line
  end

  defp unique_name(prefix) do
    :"#{prefix}-#{System.unique_integer([:positive])}"
  end
end
