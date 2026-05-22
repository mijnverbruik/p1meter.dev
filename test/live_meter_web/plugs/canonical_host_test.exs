defmodule LiveMeterWeb.Plugs.CanonicalHostTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias LiveMeterWeb.Plugs.CanonicalHost

  @opts [
    canonical_host: "p1meter.dev",
    redirect_hosts: ["www.p1meter.dev", "p1meter-app.fly.dev"],
    canonical_host_redirect_status: 301
  ]

  test "redirects www host to the canonical host with path and query" do
    conn =
      :get
      |> conn("http://www.p1meter.dev/foo?bar=baz")
      |> CanonicalHost.call(@opts)

    assert conn.halted
    assert conn.status == 301
    assert get_resp_header(conn, "location") == ["https://p1meter.dev/foo?bar=baz"]
  end

  test "passes canonical host through" do
    conn =
      :get
      |> conn("http://p1meter.dev/")
      |> CanonicalHost.call(@opts)

    refute conn.halted
    assert conn.status == nil
    assert get_resp_header(conn, "location") == []
  end
end
