import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:mini_mdm_installer/core/models/ios_app_model.dart';
import 'package:mini_mdm_installer/core/models/ios_device_model.dart';

class IosDevicectlService {
  Future<bool> isDevicectlAvailable() async {
    if (!Platform.isMacOS) return false;
    final result = await Process.run('xcrun', ['--find', 'devicectl']);
    return result.exitCode == 0;
  }

  Future<List<IosDevice>> listDevices() async {
    final tmpDir = Directory.systemTemp.createTempSync('devicectl-');
    final outPath = p.join(tmpDir.path, 'devices.json');

    final result = await Process.run('xcrun', [
      'devicectl',
      'list',
      'devices',
      '-v',
      '--json-output',
      outPath,
    ]);

    if (result.exitCode != 0) {
      final out = (result.stdout.toString() + result.stderr.toString()).trim();
      throw Exception(out.isEmpty ? 'devicectl failed' : out);
    }

    final jsonStr = await File(outPath).readAsString();
    final decoded = jsonDecode(jsonStr);

    dynamic devicesJson;
    if (decoded is Map<String, dynamic>) {
      final resultObj = decoded['result'];
      if (resultObj is Map<String, dynamic>) {
        devicesJson = resultObj['devices'];
      }
    }
    if (devicesJson is! List) return [];

    final devices = <IosDevice>[];
    for (final item in devicesJson) {
      if (item is! Map) continue;
      final m = item.cast<String, dynamic>();

      final identifier = (m['identifier'] as String?)?.trim();
      if (identifier == null || identifier.isEmpty) continue;

      final hardware = (m['hardwareProperties'] as Map?)
          ?.cast<String, dynamic>();
      final props = (m['deviceProperties'] as Map?)?.cast<String, dynamic>();
      final conn = (m['connectionProperties'] as Map?)?.cast<String, dynamic>();

      final name = (props?['name'] as String?)?.trim();
      final marketingName = (hardware?['marketingName'] as String?)?.trim();
      final platform = (hardware?['platform'] as String?)?.trim();
      final osVersion = (props?['osVersionNumber'] as String?)?.trim();
      final udid = (hardware?['udid'] as String?)?.trim();

      final pairingState = (conn?['pairingState'] as String?)?.trim();
      final transportType = (conn?['transportType'] as String?)?.trim();
      final developerMode = (props?['developerModeStatus'] as String?)?.trim();

      devices.add(
        IosDevice(
          identifier: identifier,
          name: name ?? marketingName ?? identifier,
          platform: platform,
          osVersion: osVersion,
          udid: udid,
          pairingState: pairingState,
          transportType: transportType,
          developerModeStatus: developerMode,
        ),
      );
    }

    devices.sort((a, b) => a.name.compareTo(b.name));
    return devices;
  }

  Future<String> installApp({
    required String deviceIdentifier,
    required String ipaPath,
  }) async {
    var installPath = ipaPath;
    Directory? tempDir;

    if (p.extension(ipaPath).toLowerCase() == '.ipa') {
      tempDir = Directory.systemTemp.createTempSync('ipa-unpack-');
      final unzip = await Process.run('unzip', [
        '-q',
        '-o',
        ipaPath,
        '-d',
        tempDir.path,
      ]);
      if (unzip.exitCode != 0) {
        final out = (unzip.stdout.toString() + unzip.stderr.toString()).trim();
        throw Exception(out.isEmpty ? 'Failed to unpack IPA.' : out);
      }

      final payloadDir = Directory(p.join(tempDir.path, 'Payload'));
      if (!payloadDir.existsSync()) {
        throw Exception('Invalid IPA: missing Payload directory.');
      }

      final appDirs = payloadDir
          .listSync()
          .whereType<Directory>()
          .where((d) => p.extension(d.path).toLowerCase() == '.app')
          .toList();
      if (appDirs.isEmpty) {
        throw Exception('Invalid IPA: missing .app in Payload.');
      }
      final appDir = appDirs.first;
      installPath = appDir.path;
    }

    final result = await Process.run('xcrun', [
      'devicectl',
      'device',
      'install',
      'app',
      '--device',
      deviceIdentifier,
      installPath,
    ]);

    final out = (result.stdout.toString() + result.stderr.toString()).trim();
    if (result.exitCode != 0) {
      throw Exception(out.isEmpty ? 'Install failed' : out);
    }
    if (tempDir != null) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
    return out.isEmpty ? 'Installed successfully.' : out;
  }

  Future<List<IosApp>> listInstalledApps(
    String deviceIdentifier, {
    bool includeAllApps = false,
  }) async {
    final tmpDir = Directory.systemTemp.createTempSync('devicectl-apps-');
    final outPath = p.join(tmpDir.path, 'apps.json');

    final args = [
      'devicectl',
      'device',
      'info',
      'apps',
      '--device',
      deviceIdentifier,
      '--json-output',
      outPath,
      if (includeAllApps) '--include-all-apps' else '--include-removable-apps',
    ];
    final result = await Process.run('xcrun', args);
    if (result.exitCode != 0) {
      final out = (result.stdout.toString() + result.stderr.toString()).trim();
      throw Exception(out.isEmpty ? 'Failed to list apps.' : out);
    }

    final jsonStr = await File(outPath).readAsString();
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonStr);
    } catch (_) {
      return [];
    } finally {
      try {
        tmpDir.deleteSync(recursive: true);
      } catch (_) {}
    }

    dynamic appsJson;
    if (decoded is Map<String, dynamic>) {
      final resultObj = decoded['result'];
      if (resultObj is Map<String, dynamic>) {
        appsJson = resultObj['apps'];
      }
    }
    if (appsJson is! List) return [];

    final apps = <IosApp>[];
    for (final item in appsJson) {
      if (item is! Map) continue;
      final m = item.cast<String, dynamic>();
      final bundleId = (m['bundleIdentifier'] as String?)?.trim();
      final name = (m['name'] as String?)?.trim();
      if (bundleId == null || bundleId.isEmpty) continue;
      apps.add(
        IosApp(
          bundleId: bundleId,
          name: (name == null || name.isEmpty) ? bundleId : name,
          version: (m['version'] as String?)?.trim(),
          bundleVersion: (m['bundleVersion'] as String?)?.trim(),
          removable: m['removable'] as bool?,
          builtByDeveloper: m['builtByDeveloper'] as bool?,
        ),
      );
    }

    apps.sort((a, b) => a.name.compareTo(b.name));
    return apps;
  }

  Future<String> uninstallApp({
    required String deviceIdentifier,
    required String bundleId,
  }) async {
    final result = await Process.run('xcrun', [
      'devicectl',
      'device',
      'uninstall',
      'app',
      '--device',
      deviceIdentifier,
      bundleId,
    ]);

    final out = (result.stdout.toString() + result.stderr.toString()).trim();
    if (result.exitCode != 0) {
      throw Exception(out.isEmpty ? 'Uninstall failed' : out);
    }
    return out.isEmpty ? 'Uninstalled successfully.' : out;
  }
}
