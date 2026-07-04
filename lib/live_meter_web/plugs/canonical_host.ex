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
      |> put_resp_header(
        "location",
        location(conn, canonical_host, Keyword.get(config, :url, []))
      )
      |> send_resp(Keyword.get(config, :canonical_host_redirect_status, @default_status), "")
      |> halt()
    else
      conn
    end
  end

  defp config do
    :live_meter
    |> Application.get_env(LiveMeterWeb.Endpoint, [])
    |> Keyword.take([:canonical_host, :redirect_hosts, :canonical_host_redirect_status, :url])
  end

  defp location(conn, canonical_host, url_config) do
    %URI{
      scheme: Keyword.get(url_config, :scheme, Atom.to_string(conn.scheme)),
      host: canonical_host,
      port: Keyword.get(url_config, :port, conn.port),
      path: conn.request_path,
      query: query_string(conn)
    }
    |> URI.to_string()
  end

  defp query_string(%{query_string: ""}), do: nil
  defp query_string(%{query_string: query_string}), do: query_string
end
