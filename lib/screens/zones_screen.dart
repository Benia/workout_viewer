import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/hr_zones.dart';
import '../services/settings_store.dart';

class ZonesScreen extends StatefulWidget {
  final HrZones initial;
  const ZonesScreen({super.key, required this.initial});

  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  late final TextEditingController z1;
  late final TextEditingController z2;
  late final TextEditingController z3;
  late final TextEditingController z4;

  @override
  void initState() {
    super.initState();
    z1 = TextEditingController(text: '${widget.initial.z1Max}');
    z2 = TextEditingController(text: '${widget.initial.z2Max}');
    z3 = TextEditingController(text: '${widget.initial.z3Max}');
    z4 = TextEditingController(text: '${widget.initial.z4Max}');
  }

  @override
  void dispose() {
    z1.dispose();
    z2.dispose();
    z3.dispose();
    z4.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final zones = HrZones(
      z1Max: int.tryParse(z1.text) ?? 125,
      z2Max: int.tryParse(z2.text) ?? 139,
      z3Max: int.tryParse(z3.text) ?? 148,
      z4Max: int.tryParse(z4.text) ?? 156,
    );
    await SettingsStore.saveZones(zones);
    if (mounted) Navigator.pop(context, zones);
  }

  Widget _field(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Зоны пульса')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Верхние границы зон (уд/мин):', style: TextStyle(fontSize: 15)),
          const SizedBox(height: 8),
          _field('Z1 до (не включая верх Z2)', z1),
          _field('Z2 до', z2),
          _field('Z3 до', z3),
          _field('Z4 до (выше = Z5)', z4),
          const SizedBox(height: 12),
          Text(
            'Z1 < ${z1.text.isEmpty ? "…" : z1.text}\n'
            'Z2 ${z1.text}–${z2.text}\n'
            'Z3 ${z2.text}–${z3.text}\n'
            'Z4 ${z3.text}–${z4.text}\n'
            'Z5 > ${z4.text}',
            style: const TextStyle(height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Сохранить')),
        ],
      ),
    );
  }
}
