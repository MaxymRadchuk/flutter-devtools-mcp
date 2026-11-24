import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:vm_service/vm_service.dart';

import '../connection/app_connection.dart';
import '../util/results.dart';
import '../util/time.dart';
import 'tool_group.dart';

class HttpTools implements ToolGroup {
  HttpTools(this._app);

  final AppConnection _app;

  @override
  List<(Tool, ToolHandler)> get tools => [
        (_listTool, _list),
        (_getTool, _get),
        (_clearTool, _clear),
      ];

  final _listTool = Tool(
    name: 'list_http_requests',
    description:
        'List recorded HTTP requests (summary only, no bodies). Filter by '
        'time period, method, URL, status code or errors. Times accept '
        'ISO-8601 (2026-11-23T14:00:00) or relative durations back from '
        'now (30s, 5m, 2h, 1d).',
    inputSchema: Schema.object(
      properties: {
        'since': Schema.string(
          description: 'Only requests started at/after this time.',
        ),
        'until': Schema.string(
          description: 'Only requests started at/before this time.',
        ),
        'method': Schema.string(description: 'GET, POST, ... (exact).'),
        'url_contains': Schema.string(
          description: 'Case-insensitive substring of the full URL.',
        ),
        'status_min': Schema.int(description: 'e.g. 400'),
        'status_max': Schema.int(description: 'e.g. 599'),
        'only_errors': Schema.bool(
          description:
              'Only failed requests: connection errors or status >= 400.',
        ),
        'only_pending': Schema.bool(description: 'Only in-flight requests.'),
        'limit': Schema.int(
          description: 'Max results, newest first. Default 50.',
        ),
      },
    ),
  );

  final _getTool = Tool(
    name: 'get_http_request',
    description:
        'Get full details of one request by id: headers, timings, events, '
        'and request/response bodies (decoded as UTF-8 text; JSON is '
        'pretty-printed).',
    inputSchema: Schema.object(
      properties: {
        'id': Schema.string(description: 'Request id from list_http_requests.'),
        'include_bodies': Schema.bool(description: 'Default true.'),
        'max_body_chars': Schema.int(
          description: 'Truncate each body to this length. Default 20000.',
        ),
      },
      required: ['id'],
    ),
  );

  final _clearTool = Tool(
    name: 'clear_http_requests',
    description: 'Clear all recorded HTTP requests in the app.',
    inputSchema: Schema.object(properties: {}),
  );

  Future<CallToolResult> _list(CallToolRequest request) {
    final args = request.args;
    return withApp(_app, (service, isolateId) async {
      final DateTime? since;
      final DateTime? until;
      try {
        since = parseTime(args['since'] as String?);
        until = parseTime(args['until'] as String?);
      } on FormatException catch (e) {
        return errorResult(e.message);
      }

      final method = (args['method'] as String?)?.toUpperCase();
      final urlContains = (args['url_contains'] as String?)?.toLowerCase();
      final statusMin = args['status_min'] as int?;
      final statusMax = args['status_max'] as int?;
      final onlyErrors = args['only_errors'] as bool? ?? false;
      final onlyPending = args['only_pending'] as bool? ?? false;
      final limit = args['limit'] as int? ?? 50;

      // `updatedSince` narrows server-side; exact start-time filter below.
      final profile = await service.getHttpProfile(
        isolateId,
        updatedSince: since,
      );

      final matches = profile.requests.where((r) {
        if (since != null && r.startTime.isBefore(since)) return false;
        if (until != null && r.startTime.isAfter(until)) return false;
        if (method != null && r.method.toUpperCase() != method) return false;
        if (urlContains != null &&
            !r.uri.toString().toLowerCase().contains(urlContains)) {
          return false;
        }
        final status = r.response?.statusCode;
        if (statusMin != null && (status == null || status < statusMin)) {
          return false;
        }
        if (statusMax != null && (status == null || status > statusMax)) {
          return false;
        }
        if (onlyErrors && !_isFailed(r)) return false;
        if (onlyPending && (r.isResponseComplete || _isFailed(r))) {
          return false;
        }
        return true;
      }).toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

      final shown = matches.take(limit).map(_summary).toList();
      return jsonResult({
        'total_matching': matches.length,
        'returned': shown.length,
        'requests': shown,
      });
    });
  }

  Future<CallToolResult> _get(CallToolRequest request) async {
    final args = request.args;
    final id = args['id'] as String?;
    if (id == null) return errorResult('id is required');
    final includeBodies = args['include_bodies'] as bool? ?? true;
    final maxChars = args['max_body_chars'] as int? ?? 20000;

    return withApp(_app, (service, isolateId) async {
      final HttpProfileRequest r;
      try {
        r = await service.getHttpProfileRequest(isolateId, id);
      } on RPCError catch (e) {
        return errorResult('No request with id "$id" (${e.message})');
      }

      final req = r.request;
      final res = r.response;
      return jsonResult({
        ..._summary(r),
        'request': req == null
            ? null
            : req.hasError
                ? {'error': req.error}
                : {
                    'headers': req.headers,
                    'content_length': req.contentLength,
                    'cookies': req.cookies,
                    'follow_redirects': req.followRedirects,
                  },
        'response': res == null
            ? null
            : {
                'status_code': res.statusCode,
                'reason_phrase': res.reasonPhrase,
                'headers': res.headers,
                'content_length': res.contentLength,
                'redirects': res.redirects,
                'error': res.error,
                'start_time': res.startTime?.toIso8601String(),
                'end_time': res.endTime?.toIso8601String(),
              },
        'events': [
          for (final e in r.events)
            {'event': e.event, 'time': e.timestamp.toIso8601String()},
        ],
        if (includeBodies) ...{
          'request_body': _decodeBody(r.requestBody, maxChars),
          'response_body': _decodeBody(r.responseBody, maxChars),
        },
      });
    });
  }

  Future<CallToolResult> _clear(CallToolRequest request) =>
      withApp(_app, (service, isolateId) async {
        await service.clearHttpProfile(isolateId);
        return textResult('HTTP profile cleared.');
      });

  static Map<String, Object?> _summary(HttpProfileRequestRef r) {
    final failed = _isFailed(r);
    final end = r.isResponseComplete || failed
        ? r.response?.endTime ?? r.endTime
        : null;
    return {
      'id': r.id,
      'method': r.method,
      'url': r.uri.toString(),
      'status': r.response?.statusCode,
      'start_time': r.startTime.toIso8601String(),
      'duration_ms': end?.difference(r.startTime).inMilliseconds,
      'state': failed
          ? 'failed'
          : r.isResponseComplete
              ? 'complete'
              : 'pending',
      if (r.request?.error case final e?) 'request_error': e,
      if (r.response?.error case final e?) 'response_error': e,
    };
  }

  static bool _isFailed(HttpProfileRequestRef r) =>
      (r.request?.hasError ?? false) ||
      (r.response?.hasError ?? false) ||
      (r.response?.statusCode ?? 0) >= 400;

  static Object? _decodeBody(List<int>? bytes, int maxChars) {
    if (bytes == null || bytes.isEmpty) return null;
    var text = utf8.decode(bytes, allowMalformed: true);
    try {
      text = prettyJson(jsonDecode(text));
    } on FormatException {
      // Not JSON; keep as text.
    }
    if (text.length > maxChars) {
      return '${text.substring(0, maxChars)}\n... [truncated, '
          '${text.length} chars total]';
    }
    return text;
  }
}
