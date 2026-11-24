# Limitations

- **HTTP recording starts when the flag is set.** Requests made before the
  server connects, before the DevTools Network tab was opened, or before
  `HttpClient.enableTimelineLogging = true` runs in the app aren't captured.
- **Main isolate only.** Requests and memory from `compute()`, `Isolate.run`,
  background services or workmanager isolates aren't read.
- **Native `dart:io` only.** `package:http` (IOClient), Dio's default adapter
  and plain `HttpClient` are captured. Flutter **web**, `cupertino_http`,
  `cronet_http` and native SDKs with their own networking (Firebase, analytics
  and other platform-channel plugins) don't show up.
- **Debug and profile builds only.** Release builds have no VM service.
- **Keep the debug session attached.** The VM service URI is valid only while
  the app is running and attached, and it changes on every `flutter run`.
  The DTD URI is valid while the `flutter run` session or IDE hosting it runs.
- **DTD auto-connect picks one app.** With several apps registered, the
  assistant has to choose one by `vm_service_uri`.
- **Hot restart clears the recorded requests.**
- **The request list grows in memory** until `clear_http_requests` or a restart.
- **Frames are reported only while the UI changes.** A static screen produces
  no frames. Debug-mode frame times are much slower than profile or release.
- **Frame budget is not detected.** Give `target_fps` for 90/120 Hz displays.
- **Memory counts only Dart objects.** Native memory (images decoded by the
  engine, platform views) shows only as `external_mb`, if at all.
- **`evaluate` runs real code.** It can call methods and change app state. The
  tool asks the assistant to prefer read-only expressions, but nothing
  enforces it. Use test data, not real accounts.
- **Headers aren't redacted.** `Authorization` and `Cookie` values are returned
  as they are and end up in the assistant's context.
