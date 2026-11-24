/// Converts `http://host:port/token=/` to `ws://host:port/token=/ws`.
String toWebSocketUri(String raw) {
  var uri = Uri.parse(raw.trim());
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    uri = uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws');
  }
  var path = uri.path;
  if (!path.endsWith('/ws')) {
    path = path.endsWith('/') ? '${path}ws' : '$path/ws';
  }
  return uri.replace(path: path).toString();
}
