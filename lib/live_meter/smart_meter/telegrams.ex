defmodule LiveMeter.SmartMeter.Telegrams do
  @moduledoc false

  @pubsub LiveMeter.PubSub
  @topic "smart_meter:telegrams"
  @event :smart_meter_telegram

  def topic, do: @topic

  def event, do: @event

  def subscribe(topic \\ @topic) do
    Phoenix.PubSub.subscribe(@pubsub, topic)
  end

  def broadcast_telegram(telegram, telegram_string, topic \\ @topic)
      when is_binary(telegram_string) do
    Phoenix.PubSub.broadcast(@pubsub, topic, {@event, telegram, telegram_string})
  end
end
