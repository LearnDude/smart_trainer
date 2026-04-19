import 'package:flutter/foundation.dart';

@immutable
class UserSettings {
  const UserSettings({
    required this.ftp,
    required this.vt1,
    required this.vt2,
    required this.maxHr,
  });

  final int ftp;
  final int vt1;
  final int vt2;
  final int maxHr;

  bool get isConfigured => ftp > 0;

  UserSettings copyWith({int? ftp, int? vt1, int? vt2, int? maxHr}) {
    return UserSettings(
      ftp: ftp ?? this.ftp,
      vt1: vt1 ?? this.vt1,
      vt2: vt2 ?? this.vt2,
      maxHr: maxHr ?? this.maxHr,
    );
  }

  Map<String, dynamic> toJson() => {
    'ftp': ftp,
    'vt1': vt1,
    'vt2': vt2,
    'maxHr': maxHr,
  };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
    ftp: json['ftp'] as int? ?? 0,
    vt1: json['vt1'] as int? ?? 0,
    vt2: json['vt2'] as int? ?? 0,
    maxHr: json['maxHr'] as int? ?? 0,
  );

  static const empty = UserSettings(ftp: 0, vt1: 0, vt2: 0, maxHr: 0);
}
