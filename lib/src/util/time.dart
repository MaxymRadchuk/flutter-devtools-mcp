final _relative = RegExp(r'^(\d+)\s*(s|m|h|d)$');

DateTime? parseTime(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final trimmed = value.trim();
  final match = _relative.firstMatch(trimmed.toLowerCase());
  if (match != null) {
    final n = int.parse(match.group(1)!);
    final duration = switch (match.group(2)) {
      's' => Duration(seconds: n),
      'm' => Duration(minutes: n),
      'h' => Duration(hours: n),
      _ => Duration(days: n),
    };
    return DateTime.now().subtract(duration);
  }
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) {
    throw FormatException(
      'Bad time "$value". Use ISO-8601 or 30s / 5m / 2h / 1d.',
    );
  }
  return parsed;
}
