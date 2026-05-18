enum DeviceStatus { online, offline, unauthorized, connecting }

class DeviceModel {
  final String serial;
  final String ip;
  final String port;
  DeviceStatus status;
  String? model;
  String? androidVersion;
  String? manufacturer;
  bool isSelected;

  DeviceModel({
    required this.serial,
    required this.ip,
    required this.port,
    this.status = DeviceStatus.online,
    this.model,
    this.androidVersion,
    this.manufacturer,
    this.isSelected = false,
  });

  String get displayName => model ?? serial;
  String get address {
    if (ip.isEmpty || port.isEmpty) return serial;
    return '$ip:$port';
  }

  String get statusLabel {
    switch (status) {
      case DeviceStatus.online:
        return 'Online';
      case DeviceStatus.offline:
        return 'Offline';
      case DeviceStatus.unauthorized:
        return 'Unauthorized';
      case DeviceStatus.connecting:
        return 'Connecting...';
    }
  }

  DeviceModel copyWith({
    String? serial,
    String? ip,
    String? port,
    DeviceStatus? status,
    String? model,
    String? androidVersion,
    String? manufacturer,
    bool? isSelected,
  }) {
    return DeviceModel(
      serial: serial ?? this.serial,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      status: status ?? this.status,
      model: model ?? this.model,
      androidVersion: androidVersion ?? this.androidVersion,
      manufacturer: manufacturer ?? this.manufacturer,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
