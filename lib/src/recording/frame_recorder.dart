import 'dart:collection';

class FrameSample {
  FrameSample({
    required this.number,
    required this.time,
    required this.buildMicros,
    required this.rasterMicros,
    required this.elapsedMicros,
  });

  final int number;
  final DateTime time;
  final int buildMicros;
  final int rasterMicros;
  final int elapsedMicros;

  Map<String, Object?> toJson() => {
        'number': number,
        'time': time.toIso8601String(),
        'build_ms': _ms(buildMicros),
        'raster_ms': _ms(rasterMicros),
        'total_ms': _ms(elapsedMicros),
      };
}

class FrameRecorder {
  FrameRecorder({this.capacity = 20000});

  final int capacity;
  final _frames = ListQueue<FrameSample>();

  int get length => _frames.length;

  void clear() => _frames.clear();

  void addFlutterFrameEvent(Map<String, dynamic> data, DateTime time) {
    final number = data['number'];
    final build = data['build'];
    final raster = data['raster'];
    final elapsed = data['elapsed'];
    if (number is! num || build is! num || raster is! num) return;
    _frames.addLast(
      FrameSample(
        number: number.toInt(),
        time: time,
        buildMicros: build.toInt(),
        rasterMicros: raster.toInt(),
        elapsedMicros: elapsed is num ? elapsed.toInt() : 0,
      ),
    );
    while (_frames.length > capacity) {
      _frames.removeFirst();
    }
  }

  Map<String, Object?> summarize({
    DateTime? since,
    DateTime? until,
    required double targetFps,
    required int worst,
  }) {
    final frames = _frames.where((f) {
      if (since != null && f.time.isBefore(since)) return false;
      if (until != null && f.time.isAfter(until)) return false;
      return true;
    }).toList();

    final budgetMicros = (1000000 / targetFps).round();
    bool isJanky(FrameSample f) =>
        f.buildMicros > budgetMicros || f.rasterMicros > budgetMicros;

    final janky = frames.where(isJanky).toList();
    final worstFrames = [...frames]..sort(
        (a, b) => _slowestPhase(b).compareTo(_slowestPhase(a)),
      );

    return {
      'frames': frames.length,
      'from': frames.isEmpty ? null : frames.first.time.toIso8601String(),
      'to': frames.isEmpty ? null : frames.last.time.toIso8601String(),
      'frame_budget_ms': _ms(budgetMicros),
      'janky_frames': janky.length,
      'janky_percent': frames.isEmpty
          ? 0
          : double.parse(
              (janky.length * 100 / frames.length).toStringAsFixed(1)),
      'janky_by_phase': {
        'build': frames.where((f) => f.buildMicros > budgetMicros).length,
        'raster': frames.where((f) => f.rasterMicros > budgetMicros).length,
      },
      'build_ms': _stats(frames.map((f) => f.buildMicros)),
      'raster_ms': _stats(frames.map((f) => f.rasterMicros)),
      'worst_frames': worstFrames.take(worst).map((f) => f.toJson()).toList(),
    };
  }

  static int _slowestPhase(FrameSample f) =>
      f.buildMicros > f.rasterMicros ? f.buildMicros : f.rasterMicros;

  static Map<String, Object?>? _stats(Iterable<int> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return null;
    double percentile(double p) =>
        _ms(sorted[((p / 100) * (sorted.length - 1)).round()]);
    final sum = sorted.fold<int>(0, (a, b) => a + b);
    return {
      'avg': _ms(sum ~/ sorted.length),
      'p50': percentile(50),
      'p90': percentile(90),
      'p99': percentile(99),
      'max': _ms(sorted.last),
    };
  }
}

double _ms(int micros) => double.parse((micros / 1000).toStringAsFixed(2));
