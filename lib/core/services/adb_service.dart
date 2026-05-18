import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/device_model.dart';
import '../models/app_model.dart';

class MdnsServiceInfo {
  final String name;
  final String type;
  final String ip;
  final String port;

  const MdnsServiceInfo({
    required this.name,
    required this.type,
    required this.ip,
    required this.port,
  });

  String get address => '$ip:$port';
}

class AdbService {
  static const String _defaultPort = '5555';
  String? _customAdbPath;

  String get adbPath {
    final custom = _customAdbPath;
    if (custom != null && custom.trim().isNotEmpty) {
      return custom.trim();
    }

    final env = Platform.environment;
    final sdkRoot = env['ANDROID_SDK_ROOT'] ?? env['ANDROID_HOME'];

    if (Platform.isMacOS) {
      final home = env['HOME'];
      final candidates = <String>[
        if (sdkRoot != null) p.join(sdkRoot, 'platform-tools', 'adb'),
        if (home != null)
          p.join(home, 'Library', 'Android', 'sdk', 'platform-tools', 'adb'),
      ];

      for (final c in candidates) {
        if (File(c).existsSync()) return c;
      }
      return 'adb';
    }

    if (Platform.isWindows) {
      final localAppData = env['LOCALAPPDATA'];
      final userProfile = env['USERPROFILE'];

      final candidates = <String>[
        if (sdkRoot != null) p.join(sdkRoot, 'platform-tools', 'adb.exe'),
        if (localAppData != null)
          p.join(localAppData, 'Android', 'Sdk', 'platform-tools', 'adb.exe'),
        if (userProfile != null)
          p.join(
            userProfile,
            'AppData',
            'Local',
            'Android',
            'Sdk',
            'platform-tools',
            'adb.exe',
          ),
      ];

      for (final c in candidates) {
        if (File(c).existsSync()) return c;
      }
      return 'adb';
    }

    if (Platform.isLinux) {
      final home = env['HOME'];
      final candidates = <String>[
        if (sdkRoot != null) p.join(sdkRoot, 'platform-tools', 'adb'),
        if (home != null)
          p.join(home, 'Android', 'Sdk', 'platform-tools', 'adb'),
        if (home != null)
          p.join(home, 'Android', 'sdk', 'platform-tools', 'adb'),
      ];

      for (final c in candidates) {
        if (File(c).existsSync()) return c;
      }
      return 'adb';
    }

    // Fallback for other platforms or if PATH is working
    return 'adb';
  }

  String? get customAdbPath => _customAdbPath;

  void setCustomAdbPath(String? path) {
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _customAdbPath = null;
      return;
    }
    _customAdbPath = trimmed;
  }

  String get _adbExecutable {
    final path = adbPath;
    if (path == 'adb') return path;
    if (File(path).existsSync()) return path;
    return 'adb';
  }

  // ─── Device Discovery ───────────────────────────────────────────────────────
  String _deviceKey(String serial) {
    if (serial.startsWith('adb-') && serial.contains('._adb-tls-')) {
      final rest = serial.substring(4);
      final dash = rest.indexOf('-');
      final dot = rest.indexOf('.');
      final cut = (dash != -1) ? dash : ((dot != -1) ? dot : rest.length);
      final key = rest.substring(0, cut);
      if (key.isNotEmpty) return key;
    }
    return serial;
  }

  int _deviceRank(DeviceModel d) {
    int statusRank;
    switch (d.status) {
      case DeviceStatus.online:
        statusRank = 3;
        break;
      case DeviceStatus.unauthorized:
        statusRank = 2;
        break;
      case DeviceStatus.offline:
        statusRank = 1;
        break;
      case DeviceStatus.connecting:
        statusRank = 0;
        break;
    }

    final serial = d.serial;
    final isMdnsConnect = serial.contains('._adb-tls-connect._tcp');
    final isIpPort = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}:\d+$').hasMatch(serial);
    final connRank = isMdnsConnect ? 3 : (isIpPort ? 2 : 1);

    return connRank * 10 + statusRank;
  }

  Future<List<MdnsServiceInfo>> listMdnsServices() async {
    final result = await _run([_adbExecutable, 'mdns', 'services']);
    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      final stdout = result.stdout.toString().trim();
      throw Exception(stderr.isNotEmpty ? stderr : stdout);
    }

    final lines = result.stdout.toString().split(RegExp(r'\r?\n'));
    final services = <MdnsServiceInfo>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('List of discovered mdns services')) continue;

      final match = RegExp(r'^(\S+)\s+(\S+)\s+(\S+)$').firstMatch(trimmed);
      if (match == null) continue;

      final name = match.group(1)!;
      final type = match.group(2)!;
      final hostPort = match.group(3)!.split(':');
      if (hostPort.length != 2) continue;
      services.add(
        MdnsServiceInfo(
          name: name,
          type: type,
          ip: hostPort[0],
          port: hostPort[1],
        ),
      );
    }

    services.sort((a, b) {
      final t = a.type.compareTo(b.type);
      if (t != 0) return t;
      return a.name.compareTo(b.name);
    });
    return services;
  }

  Future<String> pairDevice(String ip, String port, String pairingCode) async {
    final result = await _run([
      _adbExecutable,
      'pair',
      '$ip:$port',
      pairingCode,
    ]);
    final out = (result.stdout.toString() + result.stderr.toString()).trim();
    return out;
  }

  Future<List<DeviceModel>> scanWirelessDevices() async {
    final result = await _run([_adbExecutable, 'devices', '-l']);
    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      if (result.exitCode == -1 && stderr.isNotEmpty) {
        throw Exception(stderr);
      }
      return [];
    }

    final lines = result.stdout.toString().split(RegExp(r'\r?\n'));
    final devices = <DeviceModel>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('List of devices attached')) continue;
      if (trimmed.startsWith('* daemon')) continue;

      final match = RegExp(r'^(\S+)\s+(\S+)').firstMatch(trimmed);
      if (match == null) continue;

      final serial = match.group(1)!;
      final statusStr = match.group(2)!;

      String ip = serial;
      String port = '';
      final ipPortMatch = RegExp(
        r'^(\d{1,3}(?:\.\d{1,3}){3}):(\d+)$',
      ).firstMatch(serial);
      if (ipPortMatch != null) {
        ip = ipPortMatch.group(1)!;
        port = ipPortMatch.group(2)!;
      }

      DeviceStatus status;
      switch (statusStr) {
        case 'device':
          status = DeviceStatus.online;
          break;
        case 'offline':
          status = DeviceStatus.offline;
          break;
        case 'unauthorized':
          status = DeviceStatus.unauthorized;
          break;
        default:
          status = DeviceStatus.offline;
      }

      final device = DeviceModel(
        serial: serial,
        ip: ip,
        port: port,
        status: status,
      );
      devices.add(device);
    }

    final keys = await Future.wait(
      devices.map((d) async {
        if (d.status == DeviceStatus.online ||
            d.status == DeviceStatus.unauthorized) {
          final serialNo = await _getProp(d.serial, 'ro.serialno');
          if (serialNo != null && serialNo.trim().isNotEmpty) {
            return serialNo.trim();
          }
        }
        return _deviceKey(d.serial);
      }),
    );

    final byKey = <String, DeviceModel>{};
    for (int i = 0; i < devices.length; i++) {
      final d = devices[i];
      final key = keys[i];
      final existing = byKey[key];
      if (existing == null || _deviceRank(d) > _deviceRank(existing)) {
        byKey[key] = d;
      }
    }

    final uniqueDevices = byKey.values.toList();

    // Enrich with device info
    for (int i = 0; i < uniqueDevices.length; i++) {
      if (uniqueDevices[i].status == DeviceStatus.online) {
        uniqueDevices[i] = await _enrichDeviceInfo(uniqueDevices[i]);
      }
    }

    return uniqueDevices;
  }

  /// Connects to a device via TCP/IP.
  Future<String> connectDevice(String ip, {String port = _defaultPort}) async {
    final result = await _run([_adbExecutable, 'connect', '$ip:$port']);
    return result.stdout.toString().trim();
  }

  /// Disconnects a device.
  Future<String> disconnectDevice(String serial) async {
    final result = await _run([_adbExecutable, 'disconnect', serial]);
    return result.stdout.toString().trim();
  }

  // ─── Device Info ────────────────────────────────────────────────────────────

  Future<DeviceModel> _enrichDeviceInfo(DeviceModel device) async {
    final model = await _getProp(device.serial, 'ro.product.model');
    final manufacturer = await _getProp(
      device.serial,
      'ro.product.manufacturer',
    );
    final androidVersion = await _getProp(
      device.serial,
      'ro.build.version.release',
    );

    return device.copyWith(
      model: model,
      manufacturer: manufacturer,
      androidVersion: androidVersion,
    );
  }

  Future<String?> _getProp(String serial, String prop) async {
    final result = await _run([
      _adbExecutable,
      '-s',
      serial,
      'shell',
      'getprop',
      prop,
    ]);
    if (result.exitCode != 0) return null;
    final val = result.stdout.toString().trim();
    return val.isEmpty ? null : val;
  }

  // ─── APK Install ────────────────────────────────────────────────────────────

  /// Installs an APK on one device. Returns (success, message).
  Future<(bool, String)> installApk(String serial, String apkPath) async {
    final result = await _run([
      _adbExecutable,
      '-s',
      serial,
      'install',
      '-r',
      apkPath,
    ]);
    final out = result.stdout.toString() + result.stderr.toString();
    final success = out.contains('Success');
    return (success, out.trim());
  }

  /// Installs an APK on multiple devices concurrently.
  /// Returns a map of serial → (success, message).
  Future<Map<String, (bool, String)>> installApkToMany(
    List<String> serials,
    String apkPath,
  ) async {
    final futures = serials.map((s) async {
      final res = await installApk(s, apkPath);
      return MapEntry(s, res);
    });
    final entries = await Future.wait(futures);
    return Map.fromEntries(entries);
  }

  // ─── App Listing ────────────────────────────────────────────────────────────

  /// Lists all installed packages on a device.
  Future<List<AppModel>> listInstalledApps(
    String serial, {
    bool includeSystem = false,
  }) async {
    final args = [
      _adbExecutable,
      '-s',
      serial,
      'shell',
      'pm',
      'list',
      'packages',
    ];
    if (!includeSystem) args.add('-3'); // third-party only
    final result = await _run(args);
    if (result.exitCode != 0) return [];

    final lines = result.stdout.toString().split('\n');
    final apps = <AppModel>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('package:')) {
        final pkg = trimmed.replaceFirst('package:', '').trim();
        if (pkg.isNotEmpty) {
          apps.add(AppModel(packageName: pkg, isSystemApp: includeSystem));
        }
      }
    }
    apps.sort((a, b) => a.packageName.compareTo(b.packageName));
    return apps;
  }

  // ─── App Uninstall ──────────────────────────────────────────────────────────

  /// Uninstalls a package from one device.
  Future<(bool, String)> uninstallApp(String serial, String packageName) async {
    final result = await _run([
      _adbExecutable,
      '-s',
      serial,
      'shell',
      'pm',
      'uninstall',
      packageName,
    ]);
    final out = result.stdout.toString() + result.stderr.toString();
    final success = out.contains('Success');
    return (success, out.trim());
  }

  /// Uninstalls a package from multiple devices concurrently.
  Future<Map<String, (bool, String)>> uninstallFromMany(
    List<String> serials,
    String packageName,
  ) async {
    final futures = serials.map((s) async {
      final res = await uninstallApp(s, packageName);
      return MapEntry(s, res);
    });
    final entries = await Future.wait(futures);
    return Map.fromEntries(entries);
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Future<ProcessResult> _run(List<String> cmd) async {
    try {
      return await Process.run(cmd.first, cmd.skip(1).toList());
    } catch (e) {
      return ProcessResult(0, -1, '', e.toString());
    }
  }

  /// Check if adb is available in PATH.
  // Future<bool> isAdbAvailable() async {
  //   try {
  //     final result = await _run([adbPath, 'version']);
  //     return result.exitCode == 0;
  //   } catch (_) {
  //     return false;
  //   }
  // }

  Future<bool> isAdbAvailable() async {
    final result = await _run([_adbExecutable, 'version']);
    return result.exitCode == 0;
  }
}
