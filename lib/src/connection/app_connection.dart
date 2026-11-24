import 'dart:async';
import 'dart:io' as io;

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import '../recording/frame_recorder.dart';
import '../util/vm_uri.dart';

class AppConnection {
  static const _httpProfileRpc = 'ext.dart.io.getHttpProfile';

  final frames = FrameRecorder();

  VmService? _service;
  String? _isolateId;
  String? _wsUri;
  final _subscriptions = <StreamSubscription<Event>>[];
  Future<void> _queue = Future.value();

  VmService? get service => _service;
  String? get isolateId => _isolateId;
  bool get isConnected => _service != null;

  bool isConnectedTo(String rawUri) =>
      _wsUri != null && toWebSocketUri(rawUri) == _wsUri;

  Future<String> connect(String rawUri) {
    final result = _queue.then((_) => _connectNow(rawUri));
    _queue = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> disconnect() async {
    final service = _service;
    _service = null;
    _isolateId = null;
    _wsUri = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await service?.dispose();
  }

  Future<String> _connectNow(String rawUri) async {
    final wsUri = toWebSocketUri(rawUri);
    if (_service != null && _wsUri == wsUri) {
      return 'Already connected (isolate $_isolateId).';
    }
    await disconnect();

    final service = await vmServiceConnectUri(wsUri);
    final isolateId = await _findHttpIsolate(service);
    if (isolateId == null) {
      await service.dispose();
      throw StateError(
        'No isolate exposes HTTP profiling. Is this a web build? '
        '(Only native dart:io apps are supported.)',
      );
    }

    // Recording only starts once timeline logging is on (DevTools does this
    // when you open the Network tab).
    await service.httpEnableTimelineLogging(isolateId, true);

    frames.clear();
    _subscriptions
      ..add(service.onIsolateEvent.listen((e) => _onIsolateEvent(service, e)))
      ..add(service.onExtensionEvent.listen(_onExtensionEvent));
    await service.streamListen(EventStreams.kIsolate);
    await service.streamListen(EventStreams.kExtension);

    _service = service;
    _isolateId = isolateId;
    _wsUri = wsUri;
    unawaited(
      service.onDone.then((_) {
        if (identical(_service, service)) unawaited(disconnect());
      }),
    );
    return 'Connected (isolate $isolateId). HTTP and frame recording enabled.';
  }

  // Pick the isolate that has the dart:io HTTP extensions (prefer "main").
  static Future<String?> _findHttpIsolate(VmService service) async {
    final vm = await service.getVM();
    String? isolateId;
    for (final ref in vm.isolates ?? <IsolateRef>[]) {
      final isolate = await service.getIsolate(ref.id!);
      final rpcs = isolate.extensionRPCs ?? const <String>[];
      if (rpcs.contains(_httpProfileRpc)) {
        isolateId = ref.id;
        if (ref.name == 'main') break;
      }
    }
    return isolateId;
  }

  void _onIsolateEvent(VmService service, Event event) {
    if (!identical(service, _service)) return;
    final ref = event.isolate;
    final id = ref?.id;
    if (id == null) return;
    if (event.kind == EventKind.kIsolateExit && id == _isolateId) {
      _isolateId = null;
    } else if (event.kind == EventKind.kServiceExtensionAdded &&
        event.extensionRPC == _httpProfileRpc &&
        (_isolateId == null || ref!.name == 'main')) {
      _isolateId = id;
      unawaited(_enableHttpLogging(service, id));
    }
  }

  static Future<void> _enableHttpLogging(VmService service, String id) async {
    try {
      await service.httpEnableTimelineLogging(id, true);
    } catch (e) {
      io.stderr.writeln('Could not enable HTTP recording on $id: $e');
    }
  }

  void _onExtensionEvent(Event event) {
    if (event.extensionKind != 'Flutter.Frame') return;
    final data = event.extensionData?.data;
    if (data == null) return;
    final timestamp = event.timestamp;
    frames.addFlutterFrameEvent(
      data,
      timestamp == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }
}
