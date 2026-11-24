# Usage

## What you can do with it

**Network**

- **See what the app sent.** List every recorded request with method, URL,
  status, duration and state (`complete`, `pending`, `failed`).
- **Filter by time.** Ask for the last `30s`, `5m`, `2h` or `1d`, or give exact
  ISO-8601 times with `since` and `until`.
- **Find failures.** Only errors (status ≥ 400 or connection errors such as
  `Connection refused`), or a status range such as 400–499.
- **Search by endpoint.** Filter by HTTP method and by a part of the URL.
- **Catch hanging calls.** List only the requests still waiting for a response.
- **Inspect one request in full.** Request and response headers, cookies,
  redirects, timing steps (connection, sent, waiting for the first byte, download)
  and the request and response bodies. JSON is pretty-printed, and long bodies are
  truncated.
- **Start from a clean list.** Clear the recorded requests before reproducing a flow.

**Frame performance**

- Count janky frames (build or raster time over the frame budget) and see
  which phase causes them.
- Build and raster time percentiles (avg, p50, p90, p99, max) and the slowest
  frames.
- Measure one interaction: read with `reset: true`, scroll or animate, read again.

**Memory**

- Heap used, capacity and external memory.
- Live instances and bytes per class, filtered by class name or library.
- Leak check: count a class, repeat a flow, count again.

**Live state**

- Evaluate any Dart expression in the app and get its `toString()`, for
  example a bloc state, a feature flag or the logged-in user.

Things you can ask the assistant:

- "Connect to DTD ws://127.0.0.1:61234/XyZ= and show the requests from the last 5 minutes."
- "Which requests failed?"
- "Show the body of the last POST to /auth/login."
- "Are any requests still pending?"
- "Clear the requests. I'm going to reproduce the bug now."
- "Compare what the app sent to /orders with what the server returned."
- "I'm scrolling the feed. Is it janky, and is it build or raster?"
- "Which classes from package:my_app use the most memory?"
- "Count ProductScreenState instances, I'll open and close the screen 5 times, then count again."
- "What does `getIt<AuthRepository>().currentUser` return?"

## Tools

| Tool | Parameters | Returns |
|---|---|---|
| `connect_app` | `vm_service_uri`: the `http://` URI printed by `flutter run`, or a `ws://` URI. `dtd_uri`: the DTD URI printed by `flutter run --print-dtd`. No arguments: the DTD URI from server start. | Connects and turns on HTTP and frame recording |
| `list_http_requests` | `since`, `until`, `method`, `url_contains`, `status_min`, `status_max`, `only_errors`, `only_pending`, `limit` (default 50) | Request summaries, newest first, plus the total number of matches |
| `get_http_request` | `id` (required), `include_bodies` (default `true`), `max_body_chars` (default 20000) | Full details of one request |
| `clear_http_requests` | none | Clears the recorded requests in the app |
| `get_frame_stats` | `since`, `until`, `target_fps` (default 60), `worst` (default 10), `reset` (default `false`) | Frame count, janky frames by phase, build/raster percentiles, slowest frames |
| `get_memory` | `class_contains`, `library_contains`, `sort_by` (`bytes` or `instances`), `top` (default 20), `gc` (default `true`) | Heap usage and live instances per class |
| `evaluate` | `expression` (required), `library_uri` (default: root library), `max_chars` (default 20000) | Result kind, class and value. |

## Server options

| Flag | Environment variable | Effect |
|---|---|---|
| `--vm-service-uri=...` | `VM_SERVICE_URI` | Connect to this app at start |
| `--dtd-uri=...` | `DTD_URI` | Connect to this DTD at start, and use it for `connect_app` with no arguments |

The VM service URI changes on every `flutter run`. The DTD URI stays the same
while the `flutter run` session or IDE that hosts it is running, so it is
usually easier to give it once in chat.

## Tips

- **Frame budget.** Set `target_fps` to the display's refresh rate (120 on
  ProMotion iPhones and many Android phones), or frames between 8 and 16 ms
  aren't counted as janky.
- **Profile mode.** Debug builds are much slower. Use `flutter run --profile`
  for frame numbers that match real devices.
- **Evaluation scope.** `evaluate` runs in the root library (`main.dart`) by
  default, so it sees that file's imports. Give `library_uri` to use another
  file's imports, such as `package:my_app/cart/cart_bloc.dart`.
