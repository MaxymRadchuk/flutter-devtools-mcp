import 'dart:async';
import 'dart:io' as io;

import 'package:dtd/dtd.dart';

import '../util/results.dart';
import 'app_connection.dart';

class DtdDiscovery {
  DtdDiscovery(this._app);

  final AppConnection _app;

  DartToolingDaemon? _dtd;
  String? _dtdUri;
  StreamSubscription<DTDEvent>? _subscription;

  Future<String> connect(String rawDtdUri) async {
    final dtd = await _ensureConnected(rawDtdUri);
    final apps = (await dtd.getVmServices()).vmServicesInfos;
    if (apps.isEmpty) {
      return 'Connected to DTD. No running app is registered yet; the app '
          'is connected automatically when it starts.';
    }
    if (apps.length == 1) return _app.connect(apps.single.uri);

    final current = apps.where((a) => _app.isConnectedTo(a.uri)).firstOrNull;
    if (current != null) {
      return 'Already connected to ${current.name ?? current.uri}.';
    }
    final choices = [
      for (final a in apps) {'name': a.name, 'vm_service_uri': a.uri},
    ];
    return 'Several apps are running. Call connect_app with the '
        'vm_service_uri of one of them:\n${prettyJson(choices)}';
  }

  Future<DartToolingDaemon> _ensureConnected(String rawDtdUri) async {
    final existing = _dtd;
    if (existing != null && !existing.isClosed && _dtdUri == rawDtdUri) {
      return existing;
    }
    await _subscription?.cancel();
    await existing?.close();

    final dtd = await DartToolingDaemon.connect(Uri.parse(rawDtdUri.trim()));
    _subscription = dtd.onVmServiceUpdate().listen(_onVmServiceUpdate);
    await dtd.streamListen(ConnectedAppServiceConstants.serviceName);
    _dtd = dtd;
    _dtdUri = rawDtdUri;
    unawaited(
      dtd.done.then((_) {
        if (identical(_dtd, dtd)) {
          _dtd = null;
          _dtdUri = null;
        }
      }),
    );
    return dtd;
  }

  void _onVmServiceUpdate(DTDEvent event) {
    final uri = event.data['uri'] as String?;
    if (uri == null) return;
    switch (event.kind) {
      case ConnectedAppServiceConstants.vmServiceRegistered
          when !_app.isConnected:
        unawaited(
          _app.connect(uri).then(io.stderr.writeln).catchError((Object e) {
            io.stderr.writeln('Auto-connect to $uri failed: $e');
          }),
        );
      case ConnectedAppServiceConstants.vmServiceUnregistered
          when _app.isConnectedTo(uri):
        unawaited(_app.disconnect());
    }
  }
}
