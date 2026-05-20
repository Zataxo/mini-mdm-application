import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:mini_mdm_installer/core/models/app_model.dart';
import 'package:mini_mdm_installer/core/models/device_model.dart';
import 'package:mini_mdm_installer/core/services/adb_service.dart';

enum ScanState { idle, scanning, done, error }

class OperationResult {
  final String serial;
  final String deviceName;
  final bool success;
  final String message;

  OperationResult({
    required this.serial,
    required this.deviceName,
    required this.success,
    required this.message,
  });
}

class DeviceProvider extends ChangeNotifier {
  final AdbService _adb = AdbService();

  List<DeviceModel> _devices = [];
  ScanState _scanState = ScanState.idle;
  String? _scanError;
  bool _adbAvailable = false;

  // Install state
  String? _selectedApkPath;
  bool _isInstalling = false;
  List<OperationResult> _installResults = [];

  // Uninstall state
  List<AppModel> _installedApps = [];
  bool _loadingApps = false;
  String? _appsForSerial;
  bool _isUninstalling = false;
  List<OperationResult> _uninstallResults = [];

  // Connect dialog state
  bool _isConnecting = false;
  String? _connectResult;

  // Pairing state
  bool _isPairing = false;
  String? _pairResult;
  String? _qrPayload;
  String? _qrServiceName;
  String? _qrSecret;
  int _qrSession = 0;

  // ─── Getters ────────────────────────────────────────────────────────────────

  List<DeviceModel> get devices => _devices;
  List<DeviceModel> get selectedDevices =>
      _devices.where((d) => d.isSelected).toList();
  List<DeviceModel> get onlineDevices =>
      _devices.where((d) => d.status == DeviceStatus.online).toList();
  ScanState get scanState => _scanState;
  String? get scanError => _scanError;
  bool get adbAvailable => _adbAvailable;
  String get resolvedAdbPath => _adb.adbPath;
  String? get customAdbPath => _adb.customAdbPath;
  bool get hasSelection => _devices.any((d) => d.isSelected);
  bool get allSelected =>
      _devices.isNotEmpty && _devices.every((d) => d.isSelected);

  String? get selectedApkPath => _selectedApkPath;
  bool get isInstalling => _isInstalling;
  List<OperationResult> get installResults => _installResults;

  List<AppModel> get installedApps => _installedApps;
  bool get loadingApps => _loadingApps;
  String? get appsForSerial => _appsForSerial;
  bool get isUninstalling => _isUninstalling;
  List<OperationResult> get uninstallResults => _uninstallResults;

  bool get isConnecting => _isConnecting;
  String? get connectResult => _connectResult;

  bool get isPairing => _isPairing;
  String? get pairResult => _pairResult;
  String? get qrPayload => _qrPayload;
  String? get qrServiceName => _qrServiceName;
  String? get qrSecret => _qrSecret;

  // ─── Init ───────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _adbAvailable = await _adb.isAdbAvailable();
    notifyListeners();
  }

  Future<void> locateAdbExecutable() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      dialogTitle: 'Select adb executable',
    );
    final path = result?.files.single.path;
    if (path == null) return;

    final file = File(path);
    if (!file.existsSync()) return;

    _adb.setCustomAdbPath(path);
    await init();
  }

  Future<void> clearCustomAdbExecutable() async {
    _adb.setCustomAdbPath(null);
    await init();
  }

  // ─── Device Actions ─────────────────────────────────────────────────────────

  Future<void> scanDevices() async {
    _scanState = ScanState.scanning;
    _scanError = null;
    notifyListeners();

    try {
      final selectedBySerial = <String, bool>{
        for (final d in _devices) d.serial: d.isSelected,
      };
      final scanned = await _adb.scanWirelessDevices();
      _devices = scanned
          .map(
            (d) => d.copyWith(isSelected: selectedBySerial[d.serial] ?? false),
          )
          .toList();
      _scanState = ScanState.done;
    } catch (e) {
      _scanError = e.toString();
      _scanState = ScanState.error;
    }
    notifyListeners();
  }

  Future<void> connectToDevice(String ip, {String port = '5555'}) async {
    _isConnecting = true;
    _connectResult = null;
    notifyListeners();

    _connectResult = await _adb.connectDevice(ip, port: port);
    _isConnecting = false;
    notifyListeners();

    // Refresh list after connect
    await scanDevices();
  }

  Future<void> pairWithCode({
    required String ip,
    required String port,
    required String code,
  }) async {
    _isPairing = true;
    _pairResult = null;
    notifyListeners();

    try {
      final pairOut = await _adb.pairDevice(ip, port, code);
      final connectOut = await _connectMdnsConnectServicesForIp(ip);
      _pairResult = [
        if (pairOut.isNotEmpty) pairOut,
        if (connectOut.isNotEmpty) connectOut,
      ].join('\n');
    } catch (e) {
      _pairResult = e.toString();
    }

    _isPairing = false;
    notifyListeners();
    await scanDevices();
  }

  Future<String> _connectMdnsConnectServicesForIp(String ip) async {
    final services = await _adb.listMdnsServices();
    final connectable = services
        .where((s) => s.type.contains('_adb-tls-connect._tcp') && s.ip == ip)
        .toList();
    if (connectable.isEmpty) return '';

    final results = <String>[];
    for (final svc in connectable) {
      final res = await _adb.connectDevice(svc.ip, port: svc.port);
      results.add('${svc.address} → $res');
    }
    return results.join('\n');
  }

  String _randomDigits(int len) {
    final r = Random.secure();
    final buf = StringBuffer();
    for (int i = 0; i < len; i++) {
      buf.write(r.nextInt(10));
    }
    return buf.toString();
  }

  String _randomStudioName() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random.secure();
    final buf = StringBuffer('studio-');
    for (int i = 0; i < 10; i++) {
      buf.write(chars[r.nextInt(chars.length)]);
    }
    return buf.toString();
  }

  Future<void> startQrPairing() async {
    final session = ++_qrSession;
    _qrServiceName = _randomStudioName();
    _qrSecret = _randomDigits(10);
    _qrPayload = 'WIFI:T:ADB;S:$_qrServiceName;P:$_qrSecret;;';
    _isPairing = true;
    _pairResult = null;
    notifyListeners();

    final deadline = DateTime.now().add(const Duration(seconds: 75));
    try {
      while (DateTime.now().isBefore(deadline) && session == _qrSession) {
        final services = await _adb.listMdnsServices();
        final pairing = services.where(
          (s) =>
              s.type.contains('_adb-tls-pairing._tcp') &&
              s.name == _qrServiceName,
        );
        final match = pairing.isEmpty ? null : pairing.first;
        if (match != null) {
          final pairOut = await _adb.pairDevice(
            match.ip,
            match.port,
            _qrSecret!,
          );
          final connectOut = await _connectMdnsConnectServicesForIp(match.ip);
          _pairResult = [
            if (pairOut.isNotEmpty) pairOut,
            if (connectOut.isNotEmpty) connectOut,
          ].join('\n');
          break;
        }

        await Future.delayed(const Duration(milliseconds: 800));
      }

      if (session == _qrSession && _pairResult == null) {
        _pairResult = 'Timeout waiting for device to scan QR code.';
      }
    } catch (e) {
      if (session == _qrSession) _pairResult = e.toString();
    }

    if (session == _qrSession) {
      _isPairing = false;
      notifyListeners();
      await scanDevices();
    }
  }

  void cancelQrPairing() {
    _qrSession++;
    var changed = false;
    if (_isPairing) {
      _isPairing = false;
      changed = true;
    }
    if (_pairResult != null) {
      _pairResult = null;
      changed = true;
    }
    if (_qrPayload != null) {
      _qrPayload = null;
      changed = true;
    }
    if (_qrServiceName != null) {
      _qrServiceName = null;
      changed = true;
    }
    if (_qrSecret != null) {
      _qrSecret = null;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<void> disconnectDevice(String serial) async {
    await _adb.disconnectDevice(serial);
    await scanDevices();
  }

  void toggleDevice(String serial) {
    _devices = _devices.map((d) {
      if (d.serial == serial) return d.copyWith(isSelected: !d.isSelected);
      return d;
    }).toList();
    notifyListeners();
  }

  void selectAll(bool select) {
    _devices = _devices.map((d) => d.copyWith(isSelected: select)).toList();
    notifyListeners();
  }

  // ─── Install ────────────────────────────────────────────────────────────────

  void setApkPath(String? path) {
    _selectedApkPath = path;
    _installResults = [];
    notifyListeners();
  }

  bool _isRunningDpm = false;
  bool get isRunningDpm => _isRunningDpm;

  List<OperationResult> _dpmResults = [];
  List<OperationResult> get dpmResults => _dpmResults;

  Future<void> listDeviceOwnersSelected() async {
    if (selectedDevices.isEmpty) return;

    _isRunningDpm = true;
    _dpmResults = [];
    notifyListeners();

    final serials = selectedDevices.map((d) => d.serial).toList();
    final results = await _adb.dpmListOwnersMany(serials);

    _dpmResults = results.entries.map((e) {
      final device = _devices.firstWhere(
        (d) => d.serial == e.key,
        orElse: () => DeviceModel(serial: e.key, ip: e.key, port: ''),
      );
      return OperationResult(
        serial: e.key,
        deviceName: device.displayName,
        success: e.value.$1,
        message: e.value.$2,
      );
    }).toList();

    _isRunningDpm = false;
    notifyListeners();
  }

  Future<void> setDeviceOwnerSelected(String component) async {
    if (selectedDevices.isEmpty) return;
    final trimmed = component.trim();
    if (trimmed.isEmpty) return;

    _isRunningDpm = true;
    _dpmResults = [];
    notifyListeners();

    final serials = selectedDevices.map((d) => d.serial).toList();
    final results = await _adb.dpmSetDeviceOwnerMany(serials, trimmed);

    _dpmResults = results.entries.map((e) {
      final device = _devices.firstWhere(
        (d) => d.serial == e.key,
        orElse: () => DeviceModel(serial: e.key, ip: e.key, port: ''),
      );
      return OperationResult(
        serial: e.key,
        deviceName: device.displayName,
        success: e.value.$1,
        message: e.value.$2,
      );
    }).toList();

    _isRunningDpm = false;
    notifyListeners();
  }

  Future<void> removeActiveAdminSelected(String component) async {
    if (selectedDevices.isEmpty) return;
    final trimmed = component.trim();
    if (trimmed.isEmpty) return;

    _isRunningDpm = true;
    _dpmResults = [];
    notifyListeners();

    final serials = selectedDevices.map((d) => d.serial).toList();
    final results = await _adb.dpmRemoveActiveAdminMany(serials, trimmed);

    _dpmResults = results.entries.map((e) {
      final device = _devices.firstWhere(
        (d) => d.serial == e.key,
        orElse: () => DeviceModel(serial: e.key, ip: e.key, port: ''),
      );
      return OperationResult(
        serial: e.key,
        deviceName: device.displayName,
        success: e.value.$1,
        message: e.value.$2,
      );
    }).toList();

    _isRunningDpm = false;
    notifyListeners();
  }

  Future<void> installToSelected() async {
    if (_selectedApkPath == null || selectedDevices.isEmpty) return;

    _isInstalling = true;
    _installResults = [];
    notifyListeners();

    final serials = selectedDevices.map((d) => d.serial).toList();
    final results = await _adb.installApkToMany(serials, _selectedApkPath!);

    _installResults = results.entries.map((e) {
      final device = _devices.firstWhere(
        (d) => d.serial == e.key,
        orElse: () => DeviceModel(serial: e.key, ip: e.key, port: ''),
      );
      return OperationResult(
        serial: e.key,
        deviceName: device.displayName,
        success: e.value.$1,
        message: e.value.$2,
      );
    }).toList();

    _isInstalling = false;
    notifyListeners();
  }

  // ─── Installed Apps ─────────────────────────────────────────────────────────

  Future<void> loadInstalledApps(
    String serial, {
    bool includeSystem = false,
  }) async {
    _loadingApps = true;
    _appsForSerial = serial;
    _installedApps = [];
    notifyListeners();

    _installedApps = await _adb.listInstalledApps(
      serial,
      includeSystem: includeSystem,
    );
    _loadingApps = false;
    notifyListeners();
  }

  Future<void> uninstallFromSelected(String packageName) async {
    if (selectedDevices.isEmpty) return;

    _isUninstalling = true;
    _uninstallResults = [];
    notifyListeners();

    final serials = selectedDevices.map((d) => d.serial).toList();
    final results = await _adb.uninstallFromMany(serials, packageName);

    _uninstallResults = results.entries.map((e) {
      final device = _devices.firstWhere(
        (d) => d.serial == e.key,
        orElse: () => DeviceModel(serial: e.key, ip: e.key, port: ''),
      );
      return OperationResult(
        serial: e.key,
        deviceName: device.displayName,
        success: e.value.$1,
        message: e.value.$2,
      );
    }).toList();

    _isUninstalling = false;
    notifyListeners();
  }

  void clearInstallResults() {
    _installResults = [];
    notifyListeners();
  }

  void clearUninstallResults() {
    _uninstallResults = [];
    notifyListeners();
  }

  void clearDpmResults() {
    _dpmResults = [];
    notifyListeners();
  }
}
