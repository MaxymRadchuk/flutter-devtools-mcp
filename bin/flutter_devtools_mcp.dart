import 'dart:io' as io;

import 'package:dart_mcp/stdio.dart';
import 'package:flutter_devtools_mcp/flutter_devtools_mcp.dart';

/// Usage:
///   dart run flutter_devtools_mcp [--vm-service-uri=ws://127.0.0.1:PORT/TOKEN=/ws]
///                                 [--dtd-uri=ws://127.0.0.1:PORT/TOKEN=]
///
/// The URIs are optional; the assistant can also call `connect_app` later.
void main(List<String> args) {
  final env = io.Platform.environment;
  String? vmServiceUri;
  String? dtdUri;
  for (final arg in args) {
    if (arg.startsWith('--vm-service-uri=')) {
      vmServiceUri = arg.substring('--vm-service-uri='.length);
    } else if (arg.startsWith('--dtd-uri=')) {
      dtdUri = arg.substring('--dtd-uri='.length);
    }
  }
  vmServiceUri ??= env['VM_SERVICE_URI'];
  dtdUri ??= env['DTD_URI'];

  FlutterDevtoolsMcpServer(
    stdioChannel(input: io.stdin, output: io.stdout),
    initialVmServiceUri: vmServiceUri,
    initialDtdUri: dtdUri,
  );
}
