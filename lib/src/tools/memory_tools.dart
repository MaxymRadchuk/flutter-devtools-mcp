import 'package:dart_mcp/server.dart';
import 'package:vm_service/vm_service.dart';

import '../connection/app_connection.dart';
import '../util/results.dart';
import 'tool_group.dart';

class MemoryTools implements ToolGroup {
  MemoryTools(this._app);

  final AppConnection _app;

  @override
  List<(Tool, ToolHandler)> get tools => [(_memoryTool, _memory)];

  final _memoryTool = Tool(
    name: 'get_memory',
    description:
        'Heap usage of the app isolate and live instance counts per class, '
        'largest first. Filter by class or library to check for leaks: read '
        'the count, repeat the flow (open and close a screen), read it '
        'again. Runs a full garbage collection first unless gc is false.',
    inputSchema: Schema.object(
      properties: {
        'class_contains': Schema.string(
          description: 'Case-insensitive substring of the class name.',
        ),
        'library_contains': Schema.string(
          description: 'Case-insensitive substring of the library URI, e.g. '
              'package:my_app/.',
        ),
        'sort_by': Schema.string(
          description: '"bytes" (default) or "instances".',
        ),
        'top': Schema.int(description: 'Max classes to return. Default 20.'),
        'gc': Schema.bool(
          description: 'Collect garbage before counting. Default true.',
        ),
      },
    ),
  );

  Future<CallToolResult> _memory(CallToolRequest request) {
    final args = request.args;
    final classContains = (args['class_contains'] as String?)?.toLowerCase();
    final libraryContains =
        (args['library_contains'] as String?)?.toLowerCase();
    final sortByInstances = args['sort_by'] == 'instances';
    final top = args['top'] as int? ?? 20;
    final gc = args['gc'] as bool? ?? true;

    return withApp(_app, (service, isolateId) async {
      final profile = await service.getAllocationProfile(isolateId, gc: gc);
      final usage = profile.memoryUsage;

      final classes = (profile.members ?? const <ClassHeapStats>[]).where((c) {
        if ((c.instancesCurrent ?? 0) == 0) return false;
        final name = c.classRef?.name?.toLowerCase() ?? '';
        final library = c.classRef?.library?.uri?.toLowerCase() ?? '';
        if (classContains != null && !name.contains(classContains)) {
          return false;
        }
        if (libraryContains != null && !library.contains(libraryContains)) {
          return false;
        }
        return true;
      }).toList();
      int sortKey(ClassHeapStats c) =>
          sortByInstances ? c.instancesCurrent ?? 0 : c.bytesCurrent ?? 0;
      classes.sort((a, b) => sortKey(b).compareTo(sortKey(a)));

      return jsonResult({
        'heap': {
          'used_mb': _mb(usage?.heapUsage),
          'capacity_mb': _mb(usage?.heapCapacity),
          'external_mb': _mb(usage?.externalUsage),
        },
        'garbage_collected': gc,
        'total_matching_classes': classes.length,
        'classes': [
          for (final c in classes.take(top))
            {
              'class': c.classRef?.name,
              'library': c.classRef?.library?.uri,
              'instances': c.instancesCurrent,
              'bytes': c.bytesCurrent,
            },
        ],
      });
    });
  }

  static double? _mb(int? bytes) => bytes == null
      ? null
      : double.parse((bytes / (1024 * 1024)).toStringAsFixed(1));
}
