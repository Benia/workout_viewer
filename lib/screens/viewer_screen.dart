import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/hr_zones.dart';
import '../models/workout_point.dart';
import '../services/series_processor.dart';
import '../services/settings_store.dart';
import '../services/workout_loader.dart';
import '../widgets/track_map.dart';
import '../widgets/workout_chart.dart';
import 'zones_screen.dart';

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  WorkoutData? _data;
  ProcessedSeries? _series;
  HrZones _zones = const HrZones();
  bool _showPower = false;
  bool _showMap = true;
  double? _hoverT;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final z = await SettingsStore.loadZones();
    final p = await SettingsStore.loadShowPower();
    setState(() {
      _zones = z;
      _showPower = p;
    });
  }

  Future<void> _openFile() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'gpx', 'fit'],
        withData: false,
      );
      if (res == null || res.files.isEmpty || res.files.single.path == null) {
        setState(() => _loading = false);
        return;
      }
      final path = res.files.single.path!;
      final data = await WorkoutLoader.load(path);
      final series = SeriesProcessor.process(data);
      setState(() {
        _data = data;
        _series = series;
        _hoverT = null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _editZones() async {
    final r = await Navigator.push<HrZones>(
      context,
      MaterialPageRoute(builder: (_) => ZonesScreen(initial: _zones)),
    );
    if (r != null) setState(() => _zones = r);
  }

  Future<void> _togglePower(bool v) async {
    setState(() => _showPower = v);
    await SettingsStore.saveShowPower(v);
  }

  @override
  Widget build(BuildContext context) {
    final series = _series;
    final hasGps = series != null &&
        series.lat.any((e) => e != null) &&
        series.lon.any((e) => e != null);

    return Scaffold(
      backgroundColor: const Color(0xFFE8E6E3),
      appBar: AppBar(
        title: Text(_data?.sourceName ?? 'Workout Viewer'),
        actions: [
          IconButton(
            tooltip: 'Зоны пульса',
            icon: const Icon(Icons.favorite),
            onPressed: _editZones,
          ),
          IconButton(
            tooltip: 'Карта',
            icon: Icon(_showMap ? Icons.map : Icons.map_outlined),
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          IconButton(
            tooltip: 'Открыть файл',
            icon: const Icon(Icons.folder_open),
            onPressed: _openFile,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : series == null
              ? _Empty(onOpen: _openFile, error: _error)
              : Column(
                  children: [
                    if (_showMap && hasGps)
                      SizedBox(
                        height: MediaQuery.of(context).orientation == Orientation.landscape
                            ? MediaQuery.of(context).size.height * 0.35
                            : 180,
                        child: TrackMap(
                          series: series,
                          highlightElapsed: _hoverT,
                          opacity: 0.85,
                        ),
                      ),
                    Expanded(
                      child: WorkoutChart(
                        series: series,
                        zones: _zones,
                        showPower: _showPower && (_data?.hasPower ?? false),
                        onHoverTime: (t) => setState(() => _hoverT = t),
                      ),
                    ),
                    _BottomBar(
                      showPower: _showPower,
                      powerAvailable: _data?.hasPower ?? false,
                      onPower: _togglePower,
                      data: _data,
                    ),
                  ],
                ),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onOpen;
  final String? error;
  const _Empty({required this.onOpen, this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timeline, size: 64, color: Colors.black38),
            const SizedBox(height: 12),
            const Text(
              'Откройте CSV или GPX тренировки.\n'
              'Зум — щипок, прокрутка — жест, двойной тап — вся тренировка.\n'
              'Палец по графику → точка на карте.',
              textAlign: TextAlign.center,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.folder_open),
              label: const Text('Открыть файл'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool showPower;
  final bool powerAvailable;
  final ValueChanged<bool> onPower;
  final WorkoutData? data;

  const _BottomBar({
    required this.showPower,
    required this.powerAvailable,
    required this.onPower,
    this.data,
  });

  @override
  Widget build(BuildContext context) {
    final d = data;
    String summary = '';
    if (d != null) {
      final km = (d.totalDistanceM / 1000).toStringAsFixed(2).replaceAll('.', ',');
      final min = (d.durationSec / 60).toStringAsFixed(0);
      summary = '$km км · $min мин';
    }
    return Material(
      elevation: 4,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(summary, style: const TextStyle(fontWeight: FontWeight.w600))),
              if (powerAvailable)
                Row(
                  children: [
                    const Text('Мощность'),
                    Switch(value: showPower, onChanged: onPower),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
