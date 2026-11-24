import 'dart:async';

import 'package:dart_mcp/server.dart';
import 'package:vm_service/vm_service.dart';

import '../connection/app_connection.dart';
import '../util/results.dart';

typedef ToolHandler = FutureOr<CallToolResult> Function(CallToolRequest);

abstract interface class ToolGroup {
  List<(Tool, ToolHandler)> get tools;
}

CallToolResult notConnectedResult() => errorResult(
      'Not connected. Call connect_app with the VM service URI from '
      '`flutter run`, or with a DTD URI, first.',
    );

Future<CallToolResult> withApp(
  AppConnection app,
  Future<CallToolResult> Function(VmService service, String isolateId) body,
) async {
  final service = app.service;
  final isolateId = app.isolateId;
  if (service == null) return notConnectedResult();
  if (isolateId == null) {
    return errorResult(
      'The app isolate is restarting (hot restart). Try again in a moment.',
    );
  }
  try {
    return await body(service, isolateId);
  } catch (e) {
    return errorResult('VM service call failed: $e');
  }
}

extension ToolArguments on CallToolRequest {
  Map<String, Object?> get args => arguments ?? const {};

  String? nonEmptyString(String name) {
    final value = (args[name] as String?)?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
