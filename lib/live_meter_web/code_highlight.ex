defmodule LiveMeterWeb.CodeHighlight do
  alias Makeup.Formatters.HTML.HTMLFormatter

  def highlight(source, language) when is_binary(source) do
    source
    |> MakeupSyntect.tokenize(language: language)
    |> HTMLFormatter.format_inner_as_binary(highlight_tag: "span")
    |> Phoenix.HTML.raw()
  end
end
