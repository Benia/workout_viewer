import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../models/workout_point.dart';

class WorkoutLoader {
  static Future<WorkoutData> load(String path) async {
    final ext = p.extension(path).toLowerCase();
    final name = p.basename(path);
    if (ext == '.csv') return _loadCsv(path, name);
    if (ext == '.gpx') return _loadGpx(path, name);
    if (ext == '.fit') {
      throw UnsupportedError(
        'FIT: пока откройте через экспорт CSV/GPX, '
        'или дождитесь встроенного FIT-парсера (в планах).',
      );
    }
    throw UnsupportedError('Формат $ext не поддерживается. CSV / GPX.');
  }

  static double? _toDouble(String? s) {
    if (s == null || s.isEmpty) return null;
    return double.tryParse(s.trim().replaceAll(',', '.'));
  }

  static Future<WorkoutData> _loadCsv(String path, String name) async {
    final text = await File(path).readAsString();
    final lines = const LineSplitter().convert(text);
    if (lines.isEmpty) throw StateError('Пустой CSV');

    final header = lines.first.split(';').length > 1
        ? lines.first.split(';')
        : lines.first.split(',');
    final sep = lines.first.contains(';') && !lines.first.contains(',') ? ';' : ',';
    final cols = header.map((h) => h.trim().replaceAll('"', '')).toList();

    int idx(String key) => cols.indexWhere((c) => c.toLowerCase() == key.toLowerCase());
    final iTs = idx('timestamp');
    final iHr = [idx('heart_rate'), idx('heartrate'), idx('hr')]
        .firstWhere((i) => i >= 0, orElse: () => -1);
    final iSp = [idx('enhanced_speed'), idx('speed')]
        .firstWhere((i) => i >= 0, orElse: () => -1);
    final iEl = [idx('enhanced_altitude'), idx('altitude'), idx('elevation')]
        .firstWhere((i) => i >= 0, orElse: () => -1);
    final iDi = idx('distance');
    final iPw = idx('power');
    final iLat = idx('position_lat');
    final iLon = idx('position_long');

    if (iHr < 0 && iSp < 0) {
      throw StateError('CSV: нет heart_rate / speed');
    }

    DateTime? t0;
    final points = <WorkoutPoint>[];
    for (var li = 1; li < lines.length; li++) {
      final line = lines[li].trim();
      if (line.isEmpty) continue;
      final parts = line.split(sep);
      DateTime? ts;
      if (iTs >= 0 && iTs < parts.length) {
        ts = DateTime.tryParse(parts[iTs].trim().replaceAll('"', ''));
      }
      t0 ??= ts;
      final elapsed = (ts != null && t0 != null)
          ? ts.difference(t0).inMilliseconds / 1000.0
          : points.length.toDouble();

      points.add(WorkoutPoint(
        timestamp: ts,
        elapsedSec: elapsed,
        hr: iHr >= 0 && iHr < parts.length ? _toDouble(parts[iHr]) : null,
        speedMps: iSp >= 0 && iSp < parts.length ? _toDouble(parts[iSp]) : null,
        elevationM: iEl >= 0 && iEl < parts.length ? _toDouble(parts[iEl]) : null,
        distanceM: iDi >= 0 && iDi < parts.length ? _toDouble(parts[iDi]) : null,
        powerW: iPw >= 0 && iPw < parts.length ? _toDouble(parts[iPw]) : null,
        lat: iLat >= 0 && iLat < parts.length ? _toDouble(parts[iLat]) : null,
        lon: iLon >= 0 && iLon < parts.length ? _toDouble(parts[iLon]) : null,
      ));
    }
    return WorkoutData(sourceName: name, points: points);
  }

  static Future<WorkoutData> _loadGpx(String path, String name) async {
    final text = await File(path).readAsString();
    final doc = XmlDocument.parse(text);
    final trkpts = doc.findAllElements('trkpt');
    final points = <WorkoutPoint>[];
    DateTime? t0;
    double cumDist = 0;
    double? prevLat, prevLon;

    for (final pt in trkpts) {
      final lat = double.tryParse(pt.getAttribute('lat') ?? '');
      final lon = double.tryParse(pt.getAttribute('lon') ?? '');
      double? ele;
      DateTime? ts;
      double? hr;

      for (final c in pt.childElements) {
        final tag = c.name.local;
        if (tag == 'ele') ele = double.tryParse(c.innerText);
        if (tag == 'time') ts = DateTime.tryParse(c.innerText);
        if (tag == 'extensions') {
          for (final e in c.descendants.whereType<XmlElement>()) {
            if (e.name.local == 'hr') hr = double.tryParse(e.innerText);
          }
        }
      }

      if (prevLat != null && prevLon != null && lat != null && lon != null) {
        cumDist += _haversineM(prevLat, prevLon, lat, lon);
      }
      prevLat = lat;
      prevLon = lon;
      t0 ??= ts;
      final elapsed = (ts != null && t0 != null)
          ? ts.difference(t0).inMilliseconds / 1000.0
          : points.length.toDouble();

      double? speed;
      if (points.isNotEmpty) {
        final dt = elapsed - points.last.elapsedSec;
        if (dt > 0 && prevLat != null) {
          final dd = cumDist - (points.last.distanceM ?? cumDist);
          speed = dd / dt;
        }
      }

      points.add(WorkoutPoint(
        timestamp: ts,
        elapsedSec: elapsed,
        hr: hr,
        speedMps: speed,
        elevationM: ele,
        distanceM: cumDist,
        lat: lat,
        lon: lon,
      ));
    }

    if (points.isEmpty) throw StateError('GPX: нет точек');
    return WorkoutData(sourceName: name, points: points);
  }

  static double _haversineM(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dp = (lat2 - lat1) * math.pi / 180;
    final dl = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }
}
