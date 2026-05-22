defmodule LiveMeterWeb.Plugs.CanonicalHost do
  @moduledoc false

  import Plug.Conn

  @default_status 301

  def init(opts), do: opts

  def call(conn, opts) do
    config = Keyword.merge(config(), opts)
    canonical_host = Keyword.get(config, :canonical_host)
    redirect_hosts = Keyword.get(config, :redirect_hosts, [])

    if canonical_host && conn.host in redirect_hosts do
      conn
      |> put_resp_header("location", location(conn, canonical_host))
      |> send_resp(Keyword.get(config, :canonical_host_redirect_status, @default_status), "")
      |> halt()
    else
      conn
    end
  end

  defp config do
    :live_meter
    |> Application.get_env(LiveMeterWeb.Endpoint, [])
    |> Keyword.take([:canonical_host, :redirect_hosts, :canonical_host_redirect_status])
  end

  defp location(conn, canonical_host) do
    %URI{
      scheme: "https",
      host: canonical_host,
      path: conn.request_path,
      query: query_string(conn)
    }
    |> URI.to_string()
  end

  defp query_string(%{query_string: ""}), do: nil
  defp query_string(%{query_string: query_string}), do: query_string
end
