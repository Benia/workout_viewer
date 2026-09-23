class WorkoutPoint {
  final DateTime? timestamp;
  final double elapsedSec;
  final double? hr;
  final double? speedMps;
  final double? elevationM;
  final double? distanceM;
  final double? powerW;
  final double? lat;
  final double? lon;

  const WorkoutPoint({
    this.timestamp,
    required this.elapsedSec,
    this.hr,
    this.speedMps,
    this.elevationM,
    this.distanceM,
    this.powerW,
    this.lat,
    this.lon,
  });

  /// Pace in min/km (null if speed too low).
  double? get paceMinPerKm {
    final s = speedMps;
    if (s == null || s < 0.3) return null;
    return (1000.0 / s) / 60.0;
  }
}

class WorkoutData {
  final String sourceName;
  final List<WorkoutPoint> points;

  const WorkoutData({required this.sourceName, required this.points});

  double get durationSec =>
      points.isEmpty ? 0 : points.last.elapsedSec - points.first.elapsedSec;

  double get totalDistanceM {
    if (points.isEmpty) return 0;
    final last = points.last.distanceM;
    if (last != null) return last;
    return 0;
  }

  bool get hasGps => points.any((p) => p.lat != null && p.lon != null);
  bool get hasPower => points.any((p) => p.powerW != null && p.powerW! > 0);
}
