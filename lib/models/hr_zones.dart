import 'package:flutter/material.dart';

/// User-editable absolute HR zones (bpm).
class HrZones {
  /// Upper bounds: Z1 < z1Max, Z2 z1Max–z2Max, ... Z5 > z4Max
  final int z1Max; // default 125
  final int z2Max; // 139
  final int z3Max; // 148
  final int z4Max; // 156

  const HrZones({
    this.z1Max = 125,
    this.z2Max = 139,
    this.z3Max = 148,
    this.z4Max = 156,
  });

  HrZones copyWith({int? z1Max, int? z2Max, int? z3Max, int? z4Max}) =>
      HrZones(
        z1Max: z1Max ?? this.z1Max,
        z2Max: z2Max ?? this.z2Max,
        z3Max: z3Max ?? this.z3Max,
        z4Max: z4Max ?? this.z4Max,
      );

  List<ZoneBand> get bands => [
        ZoneBand(0, z1Max, const Color(0xFFA8E6A1), 'Z1 <$z1Max'),
        ZoneBand(z1Max, z2Max, const Color(0xFFC5E17A), 'Z2 $z1Max–$z2Max'),
        ZoneBand(z2Max, z3Max, const Color(0xFFFFE566), 'Z3 $z2Max–$z3Max'),
        ZoneBand(z3Max, z4Max, const Color(0xFFFFB347), 'Z4 $z3Max–$z4Max'),
        ZoneBand(z4Max, 220, const Color(0xFFFF6B6B), 'Z5 >$z4Max'),
      ];

  Map<String, int> toJson() => {
        'z1Max': z1Max,
        'z2Max': z2Max,
        'z3Max': z3Max,
        'z4Max': z4Max,
      };

  factory HrZones.fromJson(Map<String, dynamic> j) => HrZones(
        z1Max: j['z1Max'] as int? ?? 125,
        z2Max: j['z2Max'] as int? ?? 139,
        z3Max: j['z3Max'] as int? ?? 148,
        z4Max: j['z4Max'] as int? ?? 156,
      );
}

class ZoneBand {
  final int low;
  final int high;
  final Color color;
  final String label;
  const ZoneBand(this.low, this.high, this.color, this.label);
}
