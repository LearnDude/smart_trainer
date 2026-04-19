import 'package:flutter/foundation.dart';

@immutable
class UserSettings {
  const UserSettings({
    required this.ftp,
    required this.vt1,
    required this.vt2,
    required this.maxHr,
    this.customPowerZones,
    this.customHrZones,
  });

  final int ftp;
  final int vt1;
  final int vt2;
  final int maxHr;

  /// 6 upper bounds in watts (zones 1–6); zone 7 is open-ended.
  /// Null means use FTP-based Coggan defaults.
  final List<int>? customPowerZones;

  /// 4 upper bounds in bpm (zones 1–4); zone 5 is open-ended.
  /// Null means use max-HR-based defaults.
  final List<int>? customHrZones;

  bool get isConfigured => ftp > 0;

  List<int> get powerZoneUpperBounds {
    if (customPowerZones != null && customPowerZones!.length == 6) {
      return customPowerZones!;
    }
    return [
      (ftp * 0.55).round(),
      (ftp * 0.75).round(),
      (ftp * 0.90).round(),
      (ftp * 1.05).round(),
      (ftp * 1.20).round(),
      (ftp * 1.50).round(),
    ];
  }

  List<int> get hrZoneUpperBounds {
    if (customHrZones != null && customHrZones!.length == 4) {
      return customHrZones!;
    }
    return [
      (maxHr * 0.60).round(),
      (maxHr * 0.70).round(),
      (maxHr * 0.80).round(),
      (maxHr * 0.90).round(),
    ];
  }

  UserSettings copyWith({
    int? ftp,
    int? vt1,
    int? vt2,
    int? maxHr,
    List<int>? customPowerZones,
    List<int>? customHrZones,
  }) {
    return UserSettings(
      ftp: ftp ?? this.ftp,
      vt1: vt1 ?? this.vt1,
      vt2: vt2 ?? this.vt2,
      maxHr: maxHr ?? this.maxHr,
      customPowerZones: customPowerZones ?? this.customPowerZones,
      customHrZones: customHrZones ?? this.customHrZones,
    );
  }

  Map<String, dynamic> toJson() => {
    'ftp': ftp,
    'vt1': vt1,
    'vt2': vt2,
    'maxHr': maxHr,
    if (customPowerZones != null) 'customPowerZones': customPowerZones,
    if (customHrZones != null) 'customHrZones': customHrZones,
  };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
    ftp: json['ftp'] as int? ?? 0,
    vt1: json['vt1'] as int? ?? 0,
    vt2: json['vt2'] as int? ?? 0,
    maxHr: json['maxHr'] as int? ?? 0,
    customPowerZones:
        (json['customPowerZones'] as List<dynamic>?)?.map((e) => e as int).toList(),
    customHrZones:
        (json['customHrZones'] as List<dynamic>?)?.map((e) => e as int).toList(),
  );

  static const empty = UserSettings(ftp: 0, vt1: 0, vt2: 0, maxHr: 0);
}
