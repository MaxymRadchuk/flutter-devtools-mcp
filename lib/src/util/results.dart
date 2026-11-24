import 'dart:convert';

import 'package:dart_mcp/server.dart';

const _prettyJson = JsonEncoder.withIndent('  ');

CallToolResult textResult(String text) =>
    CallToolResult(content: [TextContent(text: text)]);

CallToolResult jsonResult(Object? data) =>
    CallToolResult(content: [TextContent(text: _prettyJson.convert(data))]);

CallToolResult errorResult(String text) =>
    CallToolResult(content: [TextContent(text: text)], isError: true);

String prettyJson(Object? data) => _prettyJson.convert(data);
