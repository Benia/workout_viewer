import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/hr_zones.dart';
import '../services/series_processor.dart';

typedef TimeCallback = void Function(double elapsedSec);

class WorkoutChart extends StatefulWidget {
  final ProcessedSeries series;
  final HrZones zones;
  final bool showPower;
  final TimeCallback? onHoverTime;

  const WorkoutChart({
    super.key,
    required this.series,
    required this.zones,
    this.showPower = false,
    this.onHoverTime,
  });

  @override
  State<WorkoutChart> createState() => _WorkoutChartState();
}

class _WorkoutChartState extends State<WorkoutChart> {
  // visible time window
  late double _t0;
  late double _t1;
  double? _cursorT;

  @override
  void initState() {
    super.initState();
    _resetWindow();
  }

  @override
  void didUpdateWidget(covariant WorkoutChart old) {
    super.didUpdateWidget(old);
    if (old.series != widget.series) _resetWindow();
  }

  void _resetWindow() {
    final s = widget.series;
    _t0 = s.t.isEmpty ? 0 : s.t.first;
    _t1 = s.t.isEmpty ? 1 : s.t.last;
  }

  void _onScale(ScaleUpdateDetails d, Size size) {
    final span = _t1 - _t0;
    if (d.scale != 1.0) {
      final mid = (_t0 + _t1) / 2;
      final newSpan = (span / d.scale).clamp(30.0, widget.series.t.last - widget.series.t.first);
      _t0 = mid - newSpan / 2;
      _t1 = mid + newSpan / 2;
    }
    if (d.focalPointDelta.dx != 0) {
      final dt = -d.focalPointDelta.dx / size.width * span;
      _t0 += dt;
      _t1 += dt;
    }
    final minT = widget.series.t.first;
    final maxT = widget.series.t.last;
    if (_t0 < minT) {
      _t1 += minT - _t0;
      _t0 = minT;
    }
    if (_t1 > maxT) {
      _t0 -= _t1 - maxT;
      _t1 = maxT;
    }
    setState(() {});
  }

  void _onPointer(Offset local, Size size) {
    final t = _t0 + (local.dx / size.width) * (_t1 - _t0);
    setState(() => _cursorT = t.clamp(widget.series.t.first, widget.series.t.last));
    widget.onHoverTime?.call(_cursorT!);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      return GestureDetector(
        onScaleStart: (_) {},
        onScaleUpdate: (d) => _onScale(d, size),
        onTapDown: (d) => _onPointer(d.localPosition, size),
        onPanUpdate: (d) {
          // horizontal pan when single finger already handled in scale; also move cursor
          _onPointer(d.localPosition, size);
        },
        onDoubleTap: () => setState(_resetWindow),
        child: CustomPaint(
          size: size,
          painter: _ChartPainter(
            series: widget.series,
            zones: widget.zones,
            showPower: widget.showPower,
            t0: _t0,
            t1: _t1,
            cursorT: _cursorT,
          ),
        ),
      );
    });
  }
}

class _ChartPainter extends CustomPainter {
  final ProcessedSeries series;
  final HrZones zones;
  final bool showPower;
  final double t0, t1;
  final double? cursorT;

  _ChartPainter({
    required this.series,
    required this.zones,
    required this.showPower,
    required this.t0,
    required this.t1,
    this.cursorT,
  });

  static const hrColor = Color(0xFFC0392B);
  static const paceColor = Color(0xFF1565C0);
  static const powerColor = Color(0xFF6A1B9A);
  static const minuteColor = Color(0xFF7A756C);

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2) return;
    final plot = Rect.fromLTWH(48, 12, size.width - 96, size.height - 56);

    // background
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE8E6E3));
    canvas.drawRect(plot, Paint()..color = const Color(0xFFF0EEEB));

    // HR zones fill
    const hrMin = 80.0, hrMax = 180.0;
    double yHr(double hr) =>
        plot.bottom - ((hr - hrMin) / (hrMax - hrMin)).clamp(0.0, 1.0) * plot.height;

    for (final z in zones.bands) {
      final y1 = yHr(z.high.toDouble());
      final y2 = yHr(z.low.toDouble());
      canvas.drawRect(
        Rect.fromLTRB(plot.left, y1, plot.right, y2),
        Paint()..color = z.color.withOpacity(0.22),
      );
    }
    // thin zone borders (color of upper zone, soft)
    for (final z in zones.bands.skip(1)) {
      final y = yHr(z.low.toDouble());
      canvas.drawLine(
        Offset(plot.left, y),
        Offset(plot.right, y),
        Paint()
          ..color = z.color.withOpacity(0.55)
          ..strokeWidth = 0.7,
      );
    }

    double xT(double t) => plot.left + ((t - t0) / (t1 - t0)).clamp(0.0, 1.0) * plot.width;

    // minute lines
    final m0 = (t0 / 60).ceil() * 60;
    for (var m = m0; m <= t1; m += 60) {
      final x = xT(m.toDouble());
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = minuteColor.withOpacity(0.45)
          ..strokeWidth = 1.2,
      );
    }

    // elevation soft fill (mapped into lower HR band area)
    final eleMin = series.ele.reduce(math.min);
    final eleMax = series.ele.reduce(math.max);
    final elePath = Path();
    var started = false;
    for (var i = 0; i < series.length; i++) {
      final t = series.t[i];
      if (t < t0 || t > t1) continue;
      final n = (eleMax > eleMin) ? (series.ele[i] - eleMin) / (eleMax - eleMin) : 0.0;
      final y = plot.bottom - 8 - n * (plot.height * 0.22);
      final x = xT(t);
      if (!started) {
        elePath.moveTo(x, plot.bottom);
        elePath.lineTo(x, y);
        started = true;
      } else {
        elePath.lineTo(x, y);
      }
    }
    if (started) {
      elePath.lineTo(xT(math.min(t1, series.t.last)), plot.bottom);
      elePath.close();
      canvas.drawPath(elePath, Paint()..color = const Color(0xFF4A7C59).withOpacity(0.28));
    }

    // HR line
    final hrPath = Path();
    started = false;
    for (var i = 0; i < series.length; i++) {
      final t = series.t[i];
      if (t < t0 || t > t1) continue;
      final x = xT(t);
      final y = yHr(series.hr[i]);
      if (!started) {
        hrPath.moveTo(x, y);
        started = true;
      } else {
        hrPath.lineTo(x, y);
      }
    }
    canvas.drawPath(
      hrPath,
      Paint()
        ..color = hrColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );

    // Pace axis (inverted: lower pace at top)
    double paceLo = 4, paceHi = 12;
    final finitePace = series.paceMin.where((v) => v.isFinite).toList();
    if (finitePace.isNotEmpty) {
      paceLo = finitePace.reduce(math.min) - 1;
      paceHi = finitePace.reduce(math.max) + 1;
    }
    double yPace(double p) =>
        plot.top + ((p - paceLo) / (paceHi - paceLo)).clamp(0.0, 1.0) * plot.height;

    final pacePath = Path();
    started = false;
    for (var i = 0; i < series.length; i++) {
      final t = series.t[i];
      final p = series.paceMin[i];
      if (t < t0 || t > t1 || !p.isFinite) continue;
      final x = xT(t);
      final y = yPace(p);
      if (!started) {
        pacePath.moveTo(x, y);
        started = true;
      } else {
        pacePath.lineTo(x, y);
      }
    }
    canvas.drawPath(
      pacePath,
      Paint()
        ..color = paceColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );

    // optional power
    if (showPower) {
      final pw = series.power;
      final vals = pw.whereType<double>().where((v) => v > 0).toList();
      if (vals.isNotEmpty) {
        final pMin = vals.reduce(math.min);
        final pMax = vals.reduce(math.max);
        final path = Path();
        var st = false;
        for (var i = 0; i < series.length; i++) {
          final t = series.t[i];
          final v = pw[i];
          if (t < t0 || t > t1 || v == null) continue;
          final yn = pMax > pMin ? (v - pMin) / (pMax - pMin) : 0.5;
          final y = plot.bottom - yn * plot.height * 0.85;
          final x = xT(t);
          if (!st) {
            path.moveTo(x, y);
            st = true;
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = powerColor.withOpacity(0.7)
            ..strokeWidth = 1.4
            ..style = PaintingStyle.stroke,
        );
      }
    }

    // cursor
    if (cursorT != null) {
      final x = xT(cursorT!);
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = Colors.black54
          ..strokeWidth = 1.0,
      );
      final idx = series.indexNearTime(cursorT!);
      final hrV = series.hr[idx];
      final tp = TextPainter(
        text: TextSpan(
          text: '${hrV.round()}  ${_fmtPace(series.paceMin[idx])}\n'
              '${_fmtHms(cursorT!)}  ${_fmtKm(series.dist[idx])}',
          style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final bx = (x + 8).clamp(plot.left, plot.right - tp.width - 8);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, plot.top + 4, tp.width + 10, tp.height + 6),
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, Paint()..color = Colors.white.withOpacity(0.92));
      tp.paint(canvas, Offset(bx + 5, plot.top + 7));
    }

    // axes labels
    _drawText(canvas, 'уд/мин', Offset(4, plot.top), hrColor, 10);
    _drawText(canvas, 'темп', Offset(size.width - 40, plot.top), paceColor, 10);

    // time ticks bottom
    final step = _niceTimeStep(t1 - t0);
    final tStart = (t0 / step).ceil() * step;
    for (var t = tStart; t <= t1; t += step) {
      final x = xT(t.toDouble());
      canvas.drawLine(Offset(x, plot.bottom), Offset(x, plot.bottom + 4),
          Paint()..color = Colors.black54);
      _drawText(canvas, _fmtHms(t.toDouble()), Offset(x - 16, plot.bottom + 6), Colors.black87, 9,
          bold: true);
    }

    // distance ticks (km) further below
    final d0 = _distAt(t0);
    final d1 = _distAt(t1);
    final dStep = 0.1;
    var dk = (d0 / dStep).ceil() * dStep;
    while (dk <= d1 + 1e-6) {
      final t = _timeAtDist(dk * 1000);
      if (t != null && t >= t0 && t <= t1) {
        final x = xT(t);
        _drawText(
          canvas,
          dk.toStringAsFixed(1).replaceAll('.', ','),
          Offset(x - 10, size.height - 16),
          Colors.black87,
          9,
          bold: true,
        );
      }
      dk += dStep;
    }
    _drawText(canvas, 'км', Offset(plot.left, size.height - 16), Colors.black54, 9);
  }

  double _distAt(double t) {
    final i = series.indexNearTime(t);
    return series.dist[i] / 1000.0;
  }

  double? _timeAtDist(double meters) {
    for (var i = 1; i < series.length; i++) {
      if (series.dist[i] >= meters) {
        final a = series.dist[i - 1];
        final b = series.dist[i];
        if (b <= a) return series.t[i];
        final u = (meters - a) / (b - a);
        return series.t[i - 1] + u * (series.t[i] - series.t[i - 1]);
      }
    }
    return null;
  }

  static double _niceTimeStep(double span) {
    if (span < 120) return 10;
    if (span < 600) return 30;
    if (span < 1800) return 60;
    return 120;
  }

  static String _fmtHms(double s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60 ~/ 1;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  static String _fmtPace(double p) {
    if (!p.isFinite) return '–';
    final mins = p.floor();
    final secs = ((p - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  static String _fmtKm(double m) =>
      '${(m / 1000).toStringAsFixed(2).replaceAll('.', ',')} км';

  static void _drawText(Canvas c, String s, Offset o, Color color, double size,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.series != series ||
      old.t0 != t0 ||
      old.t1 != t1 ||
      old.cursorT != cursorT ||
      old.zones != zones ||
      old.showPower != showPower;
}
