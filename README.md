# flutter-devtools-mcp

An MCP server that lets AI assistants inspect a running Flutter/Dart app:
HTTP requests (the DevTools **Network** tab), frame performance, memory, and
live app state.

## What you can do

- **Network.** List requests by time, method, URL, status or errors, find
  pending calls, and read full headers, timings and bodies of one request.
- **Frame performance.** Janky frames, build and raster time percentiles,
  and the slowest frames.
- **Memory.** Heap usage and live instance counts per class, to check for
  leaks (open and close a screen, compare the counts).
- **Live state.** Evaluate a Dart expression in the running app,
  such as `getIt<CartBloc>().state`.
- **Auto-connect.** Give a Dart Tooling Daemon (DTD) URI once. The server
  finds the running app and reconnects when you run it again.

Things you can ask the assistant:

- "Which requests failed in the last 5 minutes?"
- "Show the body of the last POST to /auth/login."
- "I'm scrolling the feed now. Is it janky? Is it build or raster?"
- "How many ProductScreenState instances are alive? I'll open and close the screen 5 times, then check again."
- "What is the cart bloc's state right now?"

See [docs/usage.md](docs/usage.md) for every tool and parameter.

## 1. Install

Requires the Dart SDK 3.6 or later (the one bundled with Flutter works).

```sh
dart pub global activate --source git https://github.com/MaxymRadchuk/flutter-devtools-mcp.git
```

This puts `flutter-devtools-mcp` on your `PATH`. If the command isn't found,
add `~/.pub-cache/bin` to your `PATH`. Run the same command again to update.

From a local clone instead:

```sh
cd flutter-devtools-mcp
dart pub get
dart pub global activate --source path .
```

Register it with your client:

**Claude Code** (`-s user` enables it in every project)
```sh
claude mcp add -s user flutter-devtools -- flutter-devtools-mcp
```

**Per project** (`.mcp.json` in the Flutter app's repository, offered to
everyone who opens it in Claude Code)
```json
{
  "mcpServers": {
    "flutter-devtools": { "command": "flutter-devtools-mcp" }
  }
}
```

**Cursor / Gemini CLI / others** (`mcpServers` in the client's settings)
```json
{
  "mcpServers": {
    "flutter-devtools": { "command": "flutter-devtools-mcp" }
  }
}
```

## 2. Add to your Flutter app

Optional, but needed to see requests made before the assistant connects
(for example, startup calls). Put this on the first line of `main()`:

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';

void main() {
  if (kDebugMode) HttpClient.enableTimelineLogging = true;
  runApp(const MyApp());
}
```

Without it, only requests made after the server connects are recorded.

## 3. Use

1. Run the app (not web):
   ```sh
   flutter run --print-dtd
   ```
2. Ask the assistant to connect with one of the printed URIs:
   - "Connect to DTD ws://127.0.0.1:61234/XyZ=" from
     `The Dart Tooling Daemon is available at: ...`. It reconnects
     automatically after you stop and run the app again.
   - or "Connect to http://127.0.0.1:54321/AbCd=/" from
     `A Dart VM Service on <device> is available at: ...`. This one changes
     on every run.
3. Ask about the app.

Use `flutter run --profile` for frame numbers that reflect real devices.

## Docs

- [Usage and tools](docs/usage.md)
- [How it works](docs/how-it-works.md)
- [Limitations](docs/limitations.md)
- [Development](docs/development.md)
