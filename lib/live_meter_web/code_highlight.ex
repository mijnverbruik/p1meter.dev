defmodule LiveMeterWeb.CodeHighlight do
  alias Makeup.Formatters.HTML.HTMLFormatter

  def javascript(source) when is_binary(source) do
    source
    |> MakeupSyntect.tokenize(language: "JavaScript")
    |> HTMLFormatter.format_inner_as_binary(highlight_tag: "span")
    |> Phoenix.HTML.raw()
  end
end
