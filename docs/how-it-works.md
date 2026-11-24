# How it works

```
AI client (Claude Code / Cursor / Gemini / Copilot)
      │  MCP over stdio
      ▼
flutter-devtools-mcp  (this package, a Dart CLI)
      │  optional: Dart Tooling Daemon (DTD) → finds the app's VM service
      │  VM service protocol (WebSocket)
      ▼
your app started with `flutter run`
  ext.dart.io.getHttpProfile / getHttpProfileRequest / clearHttpProfile
  Extension stream (Flutter.Frame), getAllocationProfile, evaluate
```

DevTools doesn't do anything special here. It calls the same VM service
methods and dart:io service extensions, and this server calls them too.

## Connecting

- **VM service URI.** The server connects directly.
- **DTD URI.** The server connects to DTD, asks for the running apps
  (`ConnectedApp.getVmServices`) and connects to the app if there is exactly
  one. If there are several, it lists them and the assistant picks one by
  `vm_service_uri`. The server keeps listening to DTD: when the app stops
  (`VmServiceUnregistered`) it disconnects, and when an app starts
  (`VmServiceRegistered`) while nothing is connected, it connects to it.
- Connect calls run one at a time. A call for the app that is already
  connected returns without reconnecting, so recorded frames are kept.

The server picks the isolate that exposes `ext.dart.io.getHttpProfile`,
preferring `main`. It listens to the `Isolate` stream. After a hot restart it
switches to the new `main` isolate and turns HTTP recording on again.

## HTTP recording

`dart:io` records HTTP traffic only while `HttpClient.enableTimelineLogging` is
`true`. It is `false` by default, also in debug builds, and nothing is stored
while it is off.

- Connecting turns the flag on, so recording starts at connect.
- Opening the DevTools Network tab also turns it on. Requests since then are
  available.
- Setting the flag in `main()` records everything from app start
  (see [README](../README.md#2-add-to-your-flutter-app)).

Hot restart clears the list; hot reload keeps it.

## Frames

In debug and profile builds Flutter posts a `Flutter.Frame` event on the
`Extension` stream for every rendered frame, with build, raster and total
time in microseconds. The server keeps the last 20,000 frames in memory
and computes the stats when `get_frame_stats` is called. A frame is janky
when its build or raster time is over `1000 / target_fps` ms. A new
connection clears the recorded frames.

When the app runs under `flutter run`, the debugging proxy (DDS) replays
recent events to new listeners, so the first stats can include frames from
before the server connected.

## Memory

`get_memory` calls `getAllocationProfile` (with a full GC unless `gc` is
`false`) and reports heap usage plus live instances and bytes per class.

## Evaluate

`evaluate` calls the VM service `evaluate` in the scope of the root library
or `library_uri`. Non-primitive results are converted with a second
`toString()` evaluation. Breakpoints are disabled during evaluation.
Expression compilation is provided by `flutter run`.
