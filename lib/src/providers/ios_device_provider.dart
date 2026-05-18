import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mini_mdm_installer/core/models/ios_app_model.dart';
import 'package:mini_mdm_installer/core/models/ios_device_model.dart';
import 'package:mini_mdm_installer/core/services/ios_devicectl_service.dart';

enum IosScanState { idle, scanning, done, error }

class IosOperationResult {
  final String deviceId;
  final String deviceName;
  final bool success;
  final String message;

  IosOperationResult({
    required this.deviceId,
    required this.deviceName,
    required this.success,
    required this.message,
  });
}

class IosDeviceProvider extends ChangeNotifier {
  final IosDevicectlService _svc = IosDevicectlService();

  bool _devicectlAvailable = false;
  IosScanState _scanState = IosScanState.idle;
  String? _scanError;
  List<IosDevice> _devices = [];

  Set<String> _selectedDeviceIds = {};

  String? _selectedIpaPath;
  bool _installing = false;
  List<IosOperationResult> _installResults = [];

  List<IosApp> _installedApps = [];
  bool _loadingApps = false;
  String? _appsForDeviceId;
  bool _includeAllApps = false;
  bool _uninstalling = false;
  List<IosOperationResult> _uninstallResults = [];

  bool get devicectlAvailable => _devicectlAvailable;
  IosScanState get scanState => _scanState;
  String? get scanError => _scanError;
  List<IosDevice> get devices => _devices;
  Set<String> get selectedDeviceIds => _selectedDeviceIds;
  List<IosDevice> get selectedDevices =>
      _devices.where((d) => _selectedDeviceIds.contains(d.identifier)).toList();
  bool get hasSelection => _selectedDeviceIds.isNotEmpty;
  bool get allSelected =>
      _devices.isNotEmpty && _selectedDeviceIds.length == _devices.length;

  String? get selectedIpaPath => _selectedIpaPath;
  bool get installing => _installing;
  List<IosOperationResult> get installResults => _installResults;

  List<IosApp> get installedApps => _installedApps;
  bool get loadingApps => _loadingApps;
  String? get appsForDeviceId => _appsForDeviceId;
  bool get includeAllApps => _includeAllApps;
  bool get uninstalling => _uninstalling;
  List<IosOperationResult> get uninstallResults => _uninstallResults;

  bool get isMacOS => Platform.isMacOS;

  Future<void> init() async {
    _devicectlAvailable = await _svc.isDevicectlAvailable();
    notifyListeners();
  }

  Future<void> scanDevices() async {
    _scanState = IosScanState.scanning;
    _scanError = null;
    notifyListeners();

    try {
      _devices = await _svc.listDevices();
      _selectedDeviceIds = _selectedDeviceIds
          .where((id) => _devices.any((d) => d.identifier == id))
          .toSet();
      _scanState = IosScanState.done;
    } catch (e) {
      _scanState = IosScanState.error;
      _scanError = e.toString();
    }

    notifyListeners();
  }

  void toggleDevice(String id) {
    if (_selectedDeviceIds.contains(id)) {
      _selectedDeviceIds = {..._selectedDeviceIds}..remove(id);
    } else {
      _selectedDeviceIds = {..._selectedDeviceIds}..add(id);
    }
    notifyListeners();
  }

  void selectAll(bool select) {
    if (select) {
      _selectedDeviceIds = _devices.map((d) => d.identifier).toSet();
    } else {
      _selectedDeviceIds = {};
    }
    notifyListeners();
  }

  Future<void> pickIpa() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ipa'],
      dialogTitle: 'Select IPA file',
    );

    final path = result?.files.single.path;
    if (path == null) return;
    if (!File(path).existsSync()) return;

    _selectedIpaPath = path;
    _installResults = [];
    notifyListeners();
  }

  Future<void> installToSelected() async {
    final deviceIds = _selectedDeviceIds.toList();
    final ipaPath = _selectedIpaPath;
    if (deviceIds.isEmpty || ipaPath == null) return;

    _installing = true;
    _installResults = [];
    notifyListeners();

    try {
      final results = <IosOperationResult>[];
      for (final id in deviceIds) {
        final deviceName = _devices
            .firstWhere(
              (d) => d.identifier == id,
              orElse: () => IosDevice(identifier: id, name: id),
            )
            .name;
        try {
          final out = await _svc.installApp(
            deviceIdentifier: id,
            ipaPath: ipaPath,
          );
          results.add(
            IosOperationResult(
              deviceId: id,
              deviceName: deviceName,
              success: true,
              message: out,
            ),
          );
        } catch (e) {
          results.add(
            IosOperationResult(
              deviceId: id,
              deviceName: deviceName,
              success: false,
              message: e.toString(),
            ),
          );
        }
      }
      _installResults = results;
    } finally {
      _installing = false;
      notifyListeners();
    }
  }

  Future<void> loadInstalledApps(
    String deviceId, {
    bool? includeAllApps,
  }) async {
    _loadingApps = true;
    _appsForDeviceId = deviceId;
    if (includeAllApps != null) _includeAllApps = includeAllApps;
    _installedApps = [];
    notifyListeners();

    try {
      _installedApps = await _svc.listInstalledApps(
        deviceId,
        includeAllApps: _includeAllApps,
      );
    } catch (_) {
      _installedApps = [];
    } finally {
      _loadingApps = false;
      notifyListeners();
    }
  }

  Future<void> uninstallFromSelected(String bundleId) async {
    final deviceIds = _selectedDeviceIds.toList();
    if (deviceIds.isEmpty) return;

    _uninstalling = true;
    _uninstallResults = [];
    notifyListeners();

    final results = <IosOperationResult>[];
    for (final id in deviceIds) {
      final deviceName = _devices
          .firstWhere(
            (d) => d.identifier == id,
            orElse: () => IosDevice(identifier: id, name: id),
          )
          .name;
      try {
        final out = await _svc.uninstallApp(
          deviceIdentifier: id,
          bundleId: bundleId,
        );
        results.add(
          IosOperationResult(
            deviceId: id,
            deviceName: deviceName,
            success: true,
            message: out,
          ),
        );
      } catch (e) {
        results.add(
          IosOperationResult(
            deviceId: id,
            deviceName: deviceName,
            success: false,
            message: e.toString(),
          ),
        );
      }
    }
    _uninstallResults = results;
    _uninstalling = false;
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

  void resetAll() {
    _selectedDeviceIds = {};
    _selectedIpaPath = null;
    _installResults = [];
    _installedApps = [];
    _appsForDeviceId = null;
    _uninstallResults = [];
    notifyListeners();
  }
}
