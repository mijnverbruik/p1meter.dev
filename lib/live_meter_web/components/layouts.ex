defmodule LiveMeterWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use LiveMeterWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto my-16 px-4">
      <header class="text-center">
        <h1 class="text-3xl md:text-4xl font-bold tracking-tight text-neutral-900 mb-2">
          p1meter<span class="text-neutral-400">.dev</span>
        </h1>
        <p class="text-neutral-500 font-mono text-sm">
          Virtual P1 Simulator
        </p>
      </header>

      <main class="mt-24">
        {render_slot(@inner_block)}
      </main>

      <footer class="mt-24 pt-8 border-t border-neutral-100 flex flex-col md:flex-row justify-between items-center gap-4 px-4">
        <p class="text-neutral-400 text-[10px] md:text-xs font-mono order-2 md:order-1">
          Copyright &copy; 2025 —
          <a
            href="https://robinvdvleuten.nl"
            class="text-neutral-400 hover:text-neutral-700 transition-colors"
          >
            Robin van der Vleuten
          </a>
        </p>
        <a
          href="https://github.com/mijnverbruik/p1meter.dev"
          class="text-neutral-400 hover:text-neutral-700 transition-colors inline-flex items-center gap-2 group order-1 md:order-2"
          aria-label="View source on GitHub"
        >
          <span class="text-[10px] md:text-xs tracking-wider">
            View Source
          </span>
          <svg
            viewBox="0 0 24 24"
            class="w-4 h-4 fill-current transition-transform group-hover:scale-110"
            aria-hidden="true"
          >
            <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405 1.02 0 2.04.135 3 .405 2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.285 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z" />
          </svg>
        </a>
      </footer>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end
end
