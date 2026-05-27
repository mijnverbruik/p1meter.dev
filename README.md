# p1meter.dev

p1meter.dev is a [Phoenix LiveView](https://www.phoenixframework.org/) application that provides a virtual smart meter
P1 port. It simulates DSMR 5.0 telegrams and streams them over raw TCP, so you can
build and test energy monitoring software without a physical Dutch or Belgian
smart meter nearby.

The web interface shows a live smart meter preview, while the TCP endpoint emits
the same telegram data that a P1 reader would receive.

## Quick start

Install dependencies, build the assets and start server:

```sh
mix setup
mix phx.server
```

Visit the local web UI:

```text
http://localhost:4000
```

Connect to the local TCP stream:

```sh
nc localhost 8080
```

## Development

Run the test suite:

```sh
mix test
```

Run the full project check before committing:

```sh
mix precommit
```

This project uses Phoenix 1.8, LiveView, Tailwind CSS, Bandit, and the `dsmr`
library for DSMR telegram data structures and formatting.

## Architecture

- `LiveMeter.SmartMeter` generates simulated DSMR telegrams.
- `LiveMeter.TCPServer` listens for TCP clients and broadcasts telegrams.
- `LiveMeter.TCPClient` streams telegram lines with a baud-style delay.
- `LiveMeterWeb.HomeLive` renders the live smart meter preview.

## Deployment

The application can be deployed Docker container.

- HTTP traffic is served by Phoenix on port `4000`.
- The TCP stream is exposed on port `8080`.
- Production requires `SECRET_KEY_BASE`.
- The canonical host defaults to `p1meter.dev`.
- Metrics are exposed at `/metrics` on port `9568`.

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/mijnverbruik/p1meter.dev/issues)
- Fix bugs and [submit pull requests](https://github.com/mijnverbruik/p1meter.dev/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

## License

Copyright (C) Robin van der Vleuten

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
