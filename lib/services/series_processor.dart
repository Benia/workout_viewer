import 'dart:math' as math;

import '../models/workout_point.dart';

/// Smoothed series ready for painting.
class ProcessedSeries {
  final List<double> t;
  final List<double> hr;
  final List<double> paceMin; // may contain NaN
  final List<double> ele;
  final List<double> dist;
  final List<double?> power;
  final List<double?> lat;
  final List<double?> lon;

  ProcessedSeries({
    required this.t,
    required this.hr,
    required this.paceMin,
    required this.ele,
    required this.dist,
    required this.power,
    required this.lat,
    required this.lon,
  });

  int get length => t.length;

  int indexNearTime(double elapsed) {
    if (t.isEmpty) return 0;
    var best = 0;
    var bestD = (t[0] - elapsed).abs();
    for (var i = 1; i < t.length; i++) {
      final d = (t[i] - elapsed).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }
}

class SeriesProcessor {
  /// Rolling mean + light exponential smooth (approx. of gaussian used in Python).
  static List<double> smooth(List<double?> raw, {int roll = 15, double alpha = 0.15}) {
    final n = raw.length;
    final filled = List<double>.filled(n, 0);
    double? last;
    for (var i = 0; i < n; i++) {
      final v = raw[i];
      if (v != null && !v.isNaN) {
        last = v;
        filled[i] = v;
      } else if (last != null) {
        filled[i] = last;
      }
    }
    for (var i = n - 1; i >= 0; i--) {
      if (raw[i] == null || raw[i]!.isNaN) {
        // back-fill from the right if still zero chain at start
      }
    }
    // forward fill zeros at start
    final firstValid = filled.indexWhere((v) => v != 0);
    if (firstValid > 0) {
      for (var i = 0; i < firstValid; i++) {
        filled[i] = filled[firstValid];
      }
    }

    final rolled = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final a = math.max(0, i - roll ~/ 2);
      final b = math.min(n, i + roll ~/ 2 + 1);
      var s = 0.0;
      for (var j = a; j < b; j++) {
        s += filled[j];
      }
      rolled[i] = s / (b - a);
    }

    // exponential pass
    final out = List<double>.from(rolled);
    for (var i = 1; i < n; i++) {
      out[i] = alpha * rolled[i] + (1 - alpha) * out[i - 1];
    }
    for (var i = n - 2; i >= 0; i--) {
      out[i] = alpha * out[i] + (1 - alpha) * out[i + 1];
    }
    return out;
  }

  static ProcessedSeries process(WorkoutData data) {
    final pts = data.points;
    final n = pts.length;
    final t = pts.map((p) => p.elapsedSec).toList();
    final hrRaw = pts.map((p) => p.hr).toList();
    final eleRaw = pts.map((p) => p.elevationM).toList();
    final distRaw = pts.map((p) => p.distanceM).toList();
    final paceRaw = pts.map((p) {
      final pace = p.paceMinPerKm;
      if (pace == null) return null;
      return pace.clamp(3.0, 20.0);
    }).toList();

    final hr = smooth(hrRaw, roll: 15, alpha: 0.12);
    final ele = smooth(eleRaw, roll: 11, alpha: 0.1);
    final pace = smooth(paceRaw, roll: 21, alpha: 0.08);

    // distance: prefer device cumulative, else leave as interpolated
    final dist = List<double>.filled(n, 0);
    double lastD = 0;
    for (var i = 0; i < n; i++) {
      final d = distRaw[i];
      if (d != null) {
        lastD = d;
        dist[i] = d;
      } else {
        dist[i] = lastD;
      }
    }

    return ProcessedSeries(
      t: t,
      hr: hr,
      paceMin: pace,
      ele: ele,
      dist: dist,
      power: pts.map((p) => p.powerW).toList(),
      lat: pts.map((p) => p.lat).toList(),
      lon: pts.map((p) => p.lon).toList(),
    );
  }
}
