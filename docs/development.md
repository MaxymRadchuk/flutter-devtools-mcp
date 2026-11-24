# Development

```sh
dart analyze
npx @modelcontextprotocol/inspector dart run bin/flutter_devtools_mcp.dart
```

The inspector opens a web page where you can call `connect_app` with a VM
service or DTD URI, then the other tools, and see the raw output.

## Code layout

```text
bin/flutter_devtools_mcp.dart      CLI flags and env vars → server
lib/src/server.dart                registers the tool groups, initial connect
lib/src/connection/
  app_connection.dart              VM service connection, isolate tracking, event streams
  dtd_discovery.dart               finds apps through DTD, auto-connect / disconnect
lib/src/recording/
  frame_recorder.dart              Flutter.Frame buffer and jank stats
lib/src/tools/
  tool_group.dart                  ToolGroup interface, withApp guard, argument helpers
  connect_tools.dart               connect_app
  http_tools.dart                  list_http_requests, get_http_request, clear_http_requests
  frame_tools.dart                 get_frame_stats
  memory_tools.dart                get_memory
  evaluate_tools.dart              evaluate
lib/src/util/                      result builders, time parsing, VM service URI conversion
```

To add a tool, create a `ToolGroup` in `lib/src/tools/` and add it to the
list in `server.dart`.

## Ideas

- App logs from any running app (`Logging`, `Stdout`, `Stderr` streams).
- Navigation history from `Flutter.Navigation` events, and requests grouped
  by screen.
- WebSocket and socket traffic (`ext.dart.io.socketProfilingEnabled`,
  `getSocketProfile`).
- `wait_for_request(url_contains, timeout)` for "trigger the flow, then inspect"
  workflows.
- Redact the `Authorization` and `Cookie` headers by default.
- Read HTTP profiles and memory from all isolates, not only `main`.
- Layout details for one widget (`ext.flutter.inspector.getLayoutExplorerNode`).
- Detect the display refresh rate for the frame budget.
