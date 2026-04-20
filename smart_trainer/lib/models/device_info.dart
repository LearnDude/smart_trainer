import 'package:flutter/foundation.dart';

enum DeviceType { trainer, heartRate, cadence }

@immutable
class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.name,
    required this.type,
  });

  final String id;
  final String name;
  final DeviceType type;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'type': type.name};

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
    id: json['id'] as String,
    name: json['name'] as String,
    type: DeviceType.values.byName(json['type'] as String),
  );
}
