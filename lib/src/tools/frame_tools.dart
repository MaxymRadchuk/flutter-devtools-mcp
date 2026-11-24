import 'package:dart_mcp/server.dart';

import '../connection/app_connection.dart';
import '../util/results.dart';
import '../util/time.dart';
import 'tool_group.dart';

class FrameTools implements ToolGroup {
  FrameTools(this._app);

  final AppConnection _app;

  @override
  List<(Tool, ToolHandler)> get tools => [(_frameStatsTool, _frameStats)];

  final _frameStatsTool = Tool(
    name: 'get_frame_stats',
    description:
        'Frame rendering stats recorded since connect_app: frame count, '
        'janky frames (build or raster time over the frame budget), '
        'build/raster time percentiles and the slowest frames. Times accept '
        'ISO-8601 or relative durations (30s, 5m). Debug builds are much '
        'slower than real devices; use `flutter run --profile` for numbers '
        'that reflect production.',
    inputSchema: Schema.object(
      properties: {
        'since': Schema.string(description: 'Only frames at/after this time.'),
        'until': Schema.string(description: 'Only frames at/before this time.'),
        'target_fps': Schema.int(
          description: 'Display refresh rate for the frame budget. Default 60.',
        ),
        'worst': Schema.int(
          description: 'Number of slowest frames to list. Default 10.',
        ),
        'reset': Schema.bool(
          description:
              'Clear the recorded frames after reading them. Default false.',
        ),
      },
    ),
  );

  CallToolResult _frameStats(CallToolRequest request) {
    final args = request.args;
    if (!_app.isConnected) return notConnectedResult();
    final DateTime? since;
    final DateTime? until;
    try {
      since = parseTime(args['since'] as String?);
      until = parseTime(args['until'] as String?);
    } on FormatException catch (e) {
      return errorResult(e.message);
    }
    final targetFps = args['target_fps'] as int? ?? 60;
    if (targetFps <= 0) return errorResult('target_fps must be positive');

    final summary = _app.frames.summarize(
      since: since,
      until: until,
      targetFps: targetFps.toDouble(),
      worst: args['worst'] as int? ?? 10,
    );
    if (args['reset'] as bool? ?? false) _app.frames.clear();
    if (summary['frames'] == 0) {
      return jsonResult({
        ...summary,
        'note': 'No frames recorded. Flutter reports frames only while the UI '
            'changes (scrolling, animations, rebuilds); interact with the '
            'app and ask again.',
      });
    }
    return jsonResult(summary);
  }
}
