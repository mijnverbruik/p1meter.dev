defmodule LiveMeter.RateLimit do
  use Hammer, backend: :ets, algorithm: :token_bucket
end
