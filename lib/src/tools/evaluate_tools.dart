import 'package:dart_mcp/server.dart';
import 'package:vm_service/vm_service.dart';

import '../connection/app_connection.dart';
import '../util/results.dart';
import 'tool_group.dart';

class EvaluateTools implements ToolGroup {
  EvaluateTools(this._app);

  final AppConnection _app;

  static const _primitiveKinds = {
    InstanceKind.kNull,
    InstanceKind.kBool,
    InstanceKind.kInt,
    InstanceKind.kDouble,
    InstanceKind.kString,
  };

  static const _collectionKinds = {
    InstanceKind.kList,
    InstanceKind.kMap,
    InstanceKind.kSet,
    InstanceKind.kString,
  };

  @override
  List<(Tool, ToolHandler)> get tools => [(_evaluateTool, _evaluate)];

  final _evaluateTool = Tool(
    name: 'evaluate',
    description: 'Evaluate a Dart expression in the running app and return the '
        'result (toString() for objects). Runs in the scope of the root '
        'library, or of library_uri. The expression can call methods and '
        'change app state, so prefer read-only expressions.',
    inputSchema: Schema.object(
      properties: {
        'expression': Schema.string(
          description: 'e.g. getIt<CartBloc>().state',
        ),
        'library_uri': Schema.string(
          description:
              'Library to evaluate in, e.g. package:my_app/cart/cart_bloc.dart. '
              'Default: the root library (main.dart).',
        ),
        'max_chars': Schema.int(
          description: 'Truncate the result to this length. Default 20000.',
        ),
      },
      required: ['expression'],
    ),
  );

  Future<CallToolResult> _evaluate(CallToolRequest request) async {
    final expression = request.nonEmptyString('expression');
    if (expression == null) return errorResult('expression is required');
    final libraryUri = request.nonEmptyString('library_uri');
    final maxChars = request.args['max_chars'] as int? ?? 20000;

    return withApp(_app, (service, isolateId) async {
      final isolate = await service.getIsolate(isolateId);
      final String? targetId;
      if (libraryUri == null) {
        targetId = isolate.rootLib?.id;
      } else {
        targetId = isolate.libraries
            ?.where((l) => l.uri == libraryUri)
            .firstOrNull
            ?.id;
        if (targetId == null) {
          return errorResult('Library $libraryUri not found.');
        }
      }
      if (targetId == null) {
        return errorResult('The isolate has no root library.');
      }

      final Response result;
      try {
        result = await service.evaluate(
          isolateId,
          targetId,
          expression,
          disableBreakpoints: true,
        );
      } on RPCError catch (e) {
        return errorResult('Evaluation failed: ${e.details ?? e.message}');
      }
      return _describe(service, isolateId, result, maxChars);
    });
  }

  static Future<CallToolResult> _describe(
    VmService service,
    String isolateId,
    Response result,
    int maxChars,
  ) async {
    if (result is ErrorRef) return errorResult('Threw: ${result.message}');
    if (result is Sentinel) {
      return errorResult('No value: ${result.valueAsString ?? result.kind}');
    }
    if (result is! InstanceRef) {
      return errorResult('Unexpected result: $result');
    }

    final text = await _readableValue(service, isolateId, result, maxChars);
    return jsonResult({
      'kind': result.kind,
      'class': result.classRef?.name,
      if (_collectionKinds.contains(result.kind)) 'length': result.length,
      'value': text,
    });
  }

  static Future<String?> _readableValue(
    VmService service,
    String isolateId,
    InstanceRef result,
    int maxChars,
  ) async {
    var instance = result;
    if (!_primitiveKinds.contains(instance.kind)) {
      final asString = await service.evaluate(
        isolateId,
        instance.id!,
        'toString()',
        disableBreakpoints: true,
      );
      if (asString is InstanceRef) instance = asString;
    }
    var text = instance.valueAsString;
    if ((instance.valueAsStringIsTruncated ?? false) && instance.id != null) {
      final full = await service.getObject(
        isolateId,
        instance.id!,
        count: maxChars,
      );
      if (full is Instance) text = full.valueAsString ?? text;
    }
    if (text != null && text.length > maxChars) {
      text = '${text.substring(0, maxChars)}\n... [truncated]';
    }
    return text;
  }
}
