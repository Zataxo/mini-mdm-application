// ignore_for_file: unused_field

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mini_mdm_installer/core/services/adb_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class GeneralProvider extends ChangeNotifier {
  final List<String> _initLogs = [];
  List<String> get initLogs => List.unmodifiable(_initLogs);

  bool _initialized = false;

  String? _appVersion;
  String? get appVersion => _appVersion;

  String _localIp = 'Detecting...';
  String get localIp => _localIp;

  String _publicIp = 'Checking WAN...';
  String get publicIp => _publicIp;

  String get platformLabel {
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return Platform.operatingSystem;
  }

  bool? _adbAvailable;
  bool? get adbAvailable => _adbAvailable;

  bool? _xcodeCltAvailable;
  bool? get xcodeCltAvailable => _xcodeCltAvailable;

  bool? _devicectlAvailable;
  bool? get devicectlAvailable => _devicectlAvailable;

  Future<void> initializeData() async {
    if (_initialized) return;
    _initialized = true;

    _initLogs.clear();
    _pushLog('[SYSTEM] Platform: $platformLabel');

    await Future.wait([
      detectAppVersion(),
      detectNetworkInterfaces(),
      detectToolchain(),
    ]);
  }

  Future<void> refreshDiagnostics() async {
    _clearLogs();
    _pushLog('[ACTION] Refresh diagnostics');

    await Future.wait([detectNetworkInterfaces(), detectToolchain()]);
  }

  Future<void> detectAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final buildNo = packageInfo.buildNumber;
    _appVersion = "${packageInfo.version} Build : $buildNo";
    notifyListeners();
  }

  Future<void> detectNetworkInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        _localIp = interfaces.first.addresses.first.address;
      } else {
        _localIp = 'Unavailable';
      }
    } catch (_) {
      _localIp = 'Error locating LAN';
    }
    notifyListeners();

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(
        Uri.parse('https://api.ipify.org?format=json'),
      );
      final response = await request.close();

      if (response.statusCode == HttpStatus.ok) {
        final data = await response.transform(utf8.decoder).join();
        final jsonMap = jsonDecode(data) as Map<String, dynamic>;
        _publicIp = jsonMap['ip'] ?? 'Unknown WAN';
      } else {
        _publicIp = 'No Route (Offline)';
      }
    } catch (_) {
      _publicIp = 'Offline / External Firewall';
    }
    notifyListeners();
  }

  Future<void> detectToolchain() async {
    final adb = AdbService();
    try {
      _adbAvailable = await adb.isAdbAvailable();
    } catch (_) {
      _adbAvailable = false;
    }
    _pushLog(
      '[CHECK] ADB: ${_adbAvailable == true ? "Available" : "Not found"}',
    );

    if (!Platform.isMacOS) {
      _xcodeCltAvailable = null;
      _devicectlAvailable = null;
      notifyListeners();
      return;
    }

    try {
      final r = await Process.run('xcode-select', ['-p']);
      _xcodeCltAvailable = r.exitCode == 0;
    } catch (_) {
      _xcodeCltAvailable = false;
    }
    _pushLog(
      '[CHECK] Xcode CLT: ${_xcodeCltAvailable == true ? "Available" : "Not found"}',
    );

    try {
      final r = await Process.run('xcrun', ['--find', 'devicectl']);
      _devicectlAvailable = r.exitCode == 0;
    } catch (_) {
      _devicectlAvailable = false;
    }
    _pushLog(
      '[CHECK] devicectl: ${_devicectlAvailable == true ? "Available" : "Not found"}',
    );

    notifyListeners();
  }

  void _pushLog(String line) {
    _initLogs.add(line);
    notifyListeners();
  }

  void _clearLogs() {
    _initLogs.clear();
    notifyListeners();
  }
}
