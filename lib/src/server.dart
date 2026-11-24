import 'dart:async';
import 'dart:io' as io;

import 'package:dart_mcp/server.dart';

import 'connection/app_connection.dart';
import 'connection/dtd_discovery.dart';
import 'tools/connect_tools.dart';
import 'tools/evaluate_tools.dart';
import 'tools/frame_tools.dart';
import 'tools/http_tools.dart';
import 'tools/memory_tools.dart';
import 'tools/tool_group.dart';

/// MCP server exposing a running Dart/Flutter app to AI assistants.
///
/// This uses the same VM service APIs as DevTools: the dart:io HTTP profiler
/// (`ext.dart.io.getHttpProfile`, ...), `Flutter.Frame` events, allocation
/// profiles and expression evaluation.
base class FlutterDevtoolsMcpServer extends MCPServer with ToolsSupport {
  FlutterDevtoolsMcpServer(
    super.channel, {
    String? initialVmServiceUri,
    String? initialDtdUri,
  }) : super.fromStreamChannel(
          implementation: Implementation(
            name: 'flutter-devtools-mcp',
            version: '0.2.0',
          ),
          instructions:
              'Inspect a running Dart/Flutter app: HTTP requests, frame '
              'performance, memory and live state via evaluate. '
              'Call connect_app first (unless already connected) with the VM '
              'service URI printed by `flutter run`, or with a Dart Tooling '
              'Daemon (DTD) URI, which also reconnects automatically when the '
              'app is restarted. Then use list_http_requests / '
              'get_http_request for network traffic, get_frame_stats for jank, '
              'get_memory for heap usage and instance counts, and evaluate for '
              'live state.',
        ) {
    final app = AppConnection();
    final dtd = DtdDiscovery(app);
    final groups = <ToolGroup>[
      ConnectTools(app, dtd, defaultDtdUri: initialDtdUri),
      HttpTools(app),
      FrameTools(app),
      MemoryTools(app),
      EvaluateTools(app),
    ];
    for (final group in groups) {
      for (final (tool, handler) in group.tools) {
        registerTool(tool, handler);
      }
    }

    final initial = initialVmServiceUri != null
        ? app.connect(initialVmServiceUri)
        : initialDtdUri != null
            ? dtd.connect(initialDtdUri)
            : null;
    if (initial != null) {
      unawaited(
        initial.then(io.stderr.writeln).catchError((Object e) {
          io.stderr.writeln('Initial connect failed: $e');
        }),
      );
    }
  }
}
