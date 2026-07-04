defmodule LiveMeterWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias LiveMeterWeb.CoreComponents

  test "flash clears itself on click" do
    html = render_component(&CoreComponents.flash/1, kind: :info, flash: %{"info" => "Saved!"})

    assert html =~ "Saved!"
    assert html =~ "lv:clear-flash"
    assert html =~ "phx-click"
  end

  test "flash renders nothing without a message" do
    refute render_component(&CoreComponents.flash/1, kind: :info, flash: %{}) =~ "role=\"alert\""
  end
end
