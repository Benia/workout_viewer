import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/hr_zones.dart';

class SettingsStore {
  static const _kZones = 'hr_zones';
  static const _kShowPower = 'show_power';

  static Future<HrZones> loadZones() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kZones);
    if (s == null) return const HrZones();
    try {
      return HrZones.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return const HrZones();
    }
  }

  static Future<void> saveZones(HrZones z) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kZones, jsonEncode(z.toJson()));
  }

  static Future<bool> loadShowPower() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kShowPower) ?? false;
  }

  static Future<void> saveShowPower(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kShowPower, v);
  }
}
