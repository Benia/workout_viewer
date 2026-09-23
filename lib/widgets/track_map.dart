import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/series_processor.dart';

class TrackMap extends StatelessWidget {
  final ProcessedSeries series;
  final double? highlightElapsed;
  final double opacity;

  const TrackMap({
    super.key,
    required this.series,
    this.highlightElapsed,
    this.opacity = 0.55,
  });

  @override
  Widget build(BuildContext context) {
    final pts = <LatLng>[];
    for (var i = 0; i < series.length; i++) {
      final la = series.lat[i];
      final lo = series.lon[i];
      if (la != null && lo != null) pts.add(LatLng(la, lo));
    }
    if (pts.isEmpty) {
      return Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Text('Нет GPS в файле', style: TextStyle(color: Colors.black54)),
      );
    }

    LatLng? cursor;
    if (highlightElapsed != null) {
      final idx = series.indexNearTime(highlightElapsed!);
      final la = series.lat[idx];
      final lo = series.lon[idx];
      if (la != null && lo != null) cursor = LatLng(la, lo);
    }

    final bounds = LatLngBounds.fromPoints(pts);

    return Opacity(
      opacity: opacity,
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(28)),
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.workout.viewer',
          ),
          PolylineLayer(
            polylines: [
              Polyline(points: pts, color: const Color(0xFF1565C0), strokeWidth: 3.5),
            ],
          ),
          if (cursor != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: cursor,
                  width: 22,
                  height: 22,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFC0392B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
