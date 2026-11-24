import 'package:dart_mcp/server.dart';

import '../connection/app_connection.dart';
import '../connection/dtd_discovery.dart';
import '../util/results.dart';
import 'tool_group.dart';

class ConnectTools implements ToolGroup {
  ConnectTools(this._app, this._dtd, {String? defaultDtdUri})
      : _defaultDtdUri = defaultDtdUri;

  final AppConnection _app;
  final DtdDiscovery _dtd;
  final String? _defaultDtdUri;

  @override
  List<(Tool, ToolHandler)> get tools => [(_connectTool, _connect)];

  final _connectTool = Tool(
    name: 'connect_app',
    description:
        'Connect to a running Dart/Flutter app and enable HTTP profiling. '
        'Give either vm_service_uri (the http:// URI printed by `flutter run` '
        '"A Dart VM Service on ... is available at: ...", or a ws:// URI) or '
        'dtd_uri (the Dart Tooling Daemon URI printed by '
        '`flutter run --print-dtd`, or copied from the IDE). With a DTD URI '
        'the app is found automatically and reconnected after it restarts. '
        'With no arguments, the DTD URI configured at server start is used. '
        'Only requests made after profiling is enabled are recorded.',
    inputSchema: Schema.object(
      properties: {
        'vm_service_uri': Schema.string(
          description: 'e.g. http://127.0.0.1:54321/AbCdEf=/',
        ),
        'dtd_uri': Schema.string(description: 'e.g. ws://127.0.0.1:61234/XyZ='),
      },
    ),
  );

  Future<CallToolResult> _connect(CallToolRequest request) async {
    final vmUri = request.nonEmptyString('vm_service_uri');
    final dtdUri = request.nonEmptyString('dtd_uri') ?? _defaultDtdUri;
    if (vmUri != null) {
      try {
        return textResult(await _app.connect(vmUri));
      } catch (e) {
        return errorResult('Could not connect to $vmUri: $e');
      }
    }
    if (dtdUri != null) {
      try {
        return textResult(await _dtd.connect(dtdUri));
      } catch (e) {
        return errorResult('Could not connect to DTD at $dtdUri: $e');
      }
    }
    return errorResult(
      'Give vm_service_uri (printed by `flutter run`) or dtd_uri (printed by '
      '`flutter run --print-dtd`).',
    );
  }
}
