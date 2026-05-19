import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class SigningIdentity {
  final String id;
  final String name;

  const SigningIdentity({required this.id, required this.name});
}

class ProvisioningProfile {
  final String path;
  final String displayName;

  const ProvisioningProfile({required this.path, required this.displayName});
}

typedef LogFn = void Function(String line);

class IpaResignService {
  Future<String?> pickIpaPath() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ipa'],
      dialogTitle: 'Select unsigned IPA',
    );
    return result?.files.single.path;
  }

  Future<ProvisioningProfile?> pickProvisioningProfile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mobileprovision'],
      dialogTitle: 'Select provisioning profile (.mobileprovision)',
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    if (!File(path).existsSync()) return null;
    final name = await _getProfileName(path);
    return ProvisioningProfile(path: path, displayName: name);
  }

  Future<List<SigningIdentity>> listSigningIdentities() async {
    final result = await Process.run('security', [
      'find-identity',
      '-p',
      'codesigning',
      '-v',
    ]);

    if (result.exitCode != 0) {
      throw Exception('Failed to list signing identities.');
    }

    final output = result.stdout.toString();
    final regex = RegExp(r'([A-F0-9]{40})\s+"([^"]+)"');
    final identities = <SigningIdentity>[];
    for (final m in regex.allMatches(output)) {
      identities.add(SigningIdentity(id: m.group(1)!, name: m.group(2)!));
    }
    return identities;
  }

  Future<List<ProvisioningProfile>> listProvisioningProfiles() async {
    final files = await _findAllProfiles();
    final profiles = <ProvisioningProfile>[];
    for (final f in files) {
      final name = await _getProfileName(f.path);
      profiles.add(ProvisioningProfile(path: f.path, displayName: name));
    }
    profiles.sort((a, b) => a.displayName.compareTo(b.displayName));
    return profiles;
  }

  Future<List<String>> listExtensionsInIpa(String ipaPath) async {
    final tmp = Directory.systemTemp.createTempSync('ipa-inspect-');
    try {
      final unzip = await Process.run('unzip', [
        '-q',
        '-o',
        ipaPath,
        '-d',
        tmp.path,
      ]);
      if (unzip.exitCode != 0) {
        final out = (unzip.stdout.toString() + unzip.stderr.toString()).trim();
        throw Exception(out.isEmpty ? 'Failed to unpack IPA.' : out);
      }

      final payloadDir = Directory(p.join(tmp.path, 'Payload'));
      if (!payloadDir.existsSync()) return [];
      final appDirs = payloadDir
          .listSync()
          .whereType<Directory>()
          .where((d) => p.extension(d.path).toLowerCase() == '.app')
          .toList();
      final appDir = appDirs.isEmpty ? null : appDirs.first;
      if (appDir == null) return [];
      final pluginsDir = Directory(p.join(appDir.path, 'PlugIns'));
      if (!pluginsDir.existsSync()) return [];
      final extensions = pluginsDir
          .listSync()
          .whereType<Directory>()
          .where((d) => p.extension(d.path).toLowerCase() == '.appex')
          .map((d) => p.basename(d.path))
          .toList();
      extensions.sort();
      return extensions;
    } finally {
      try {
        tmp.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  Future<String> resignIpa({
    required String ipaPath,
    required String signingIdentityId,
    required String mainProvisioningProfilePath,
    required Map<String, String> extensionProvisioningProfileByExtensionName,
    String? newBundleId,
    LogFn? onLog,
  }) async {
    void log(String s) => onLog?.call(s);

    log('Preparing...');
    final workDir = Directory.systemTemp.createTempSync('ipa-resign-');
    try {
      log('Extracting IPA...');
      final unzip = await Process.run('unzip', [
        '-q',
        '-o',
        ipaPath,
        '-d',
        workDir.path,
      ]);
      if (unzip.exitCode != 0) {
        final out = (unzip.stdout.toString() + unzip.stderr.toString()).trim();
        throw Exception(out.isEmpty ? 'Failed to extract IPA.' : out);
      }

      final payloadDir = Directory(p.join(workDir.path, 'Payload'));
      if (!payloadDir.existsSync()) {
        throw Exception('Invalid IPA: missing Payload directory.');
      }

      final appDirs = payloadDir
          .listSync()
          .whereType<Directory>()
          .where((d) => p.extension(d.path).toLowerCase() == '.app')
          .toList();
      final appDir = appDirs.isEmpty ? null : appDirs.first;
      if (appDir == null) {
        throw Exception('Invalid IPA: missing .app in Payload.');
      }

      if (newBundleId != null && newBundleId.isNotEmpty) {
        log('Updating Bundle ID...');
        final oldMainBundleId = await _readBundleId(appDir.path);
        await _tryUpdateBundleId(appDir.path, newBundleId);
        if (oldMainBundleId != null && oldMainBundleId.isNotEmpty) {
          await _tryUpdateExtensionBundleIds(
            appPath: appDir.path,
            oldMainBundleId: oldMainBundleId,
            newMainBundleId: newBundleId,
          );
        }
      }

      log('Signing frameworks...');
      await _signFrameworks(
        appDir.path,
        signingIdentityId: signingIdentityId,
        workDir: workDir.path,
      );

      log('Signing extensions...');
      await _signExtensions(
        appDir.path,
        signingIdentityId: signingIdentityId,
        workDir: workDir.path,
        mainProvisioningProfilePath: mainProvisioningProfilePath,
        extensionProvisioningProfileByExtensionName:
            extensionProvisioningProfileByExtensionName,
      );

      log('Signing main app...');
      await _signComponent(
        componentPath: appDir.path,
        signingIdentityId: signingIdentityId,
        workDir: workDir.path,
        provisioningProfilePath: mainProvisioningProfilePath,
      );

      final outputPath = ipaPath.replaceAll(
        RegExp(r'\.ipa$', caseSensitive: false),
        '-signed.ipa',
      );
      if (File(outputPath).existsSync()) {
        await File(outputPath).delete();
      }

      log('Repackaging...');
      final zip = await Process.run('zip', [
        '-qr',
        outputPath,
        'Payload',
      ], workingDirectory: workDir.path);
      if (zip.exitCode != 0) {
        final out = (zip.stdout.toString() + zip.stderr.toString()).trim();
        throw Exception(out.isEmpty ? 'Failed to create signed IPA.' : out);
      }

      log('Done: $outputPath');
      return outputPath;
    } finally {
      try {
        workDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> _tryUpdateBundleId(String appPath, String bundleId) async {
    final infoPlistPath = p.join(appPath, 'Info.plist');
    if (File(infoPlistPath).existsSync()) {
      await Process.run('/usr/libexec/PlistBuddy', [
        '-c',
        'Set :CFBundleIdentifier $bundleId',
        infoPlistPath,
      ]);
    }

    final projectPath = p.join(appPath, 'project.pbxproj');
    if (File(projectPath).existsSync()) {
      final content = await File(projectPath).readAsString();
      final updated = content.replaceAll(
        RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;'),
        'PRODUCT_BUNDLE_IDENTIFIER = $bundleId;',
      );
      await File(projectPath).writeAsString(updated);
    }
  }

  Future<String?> _readBundleId(String containerPath) async {
    final infoPlistPath = p.join(containerPath, 'Info.plist');
    if (!File(infoPlistPath).existsSync()) return null;
    final result = await Process.run('/usr/libexec/PlistBuddy', [
      '-c',
      'Print :CFBundleIdentifier',
      infoPlistPath,
    ]);
    if (result.exitCode != 0) return null;
    final out = result.stdout.toString().trim();
    if (out.isEmpty) return null;
    return out;
  }

  Future<void> _writeBundleId(String containerPath, String bundleId) async {
    final infoPlistPath = p.join(containerPath, 'Info.plist');
    if (!File(infoPlistPath).existsSync()) return;
    await Process.run('/usr/libexec/PlistBuddy', [
      '-c',
      'Set :CFBundleIdentifier $bundleId',
      infoPlistPath,
    ]);
  }

  Future<void> _tryUpdateExtensionBundleIds({
    required String appPath,
    required String oldMainBundleId,
    required String newMainBundleId,
  }) async {
    final pluginsDir = Directory(p.join(appPath, 'PlugIns'));
    if (!pluginsDir.existsSync()) return;

    final extensions = pluginsDir
        .listSync()
        .whereType<Directory>()
        .where((d) => p.extension(d.path).toLowerCase() == '.appex')
        .toList();

    for (final ext in extensions) {
      final oldExtBundleId = await _readBundleId(ext.path);
      if (oldExtBundleId == null || oldExtBundleId.isEmpty) continue;

      String suffix;
      if (oldExtBundleId.startsWith('$oldMainBundleId.')) {
        suffix = oldExtBundleId.substring(oldMainBundleId.length + 1);
      } else if (oldExtBundleId.contains('.')) {
        suffix = oldExtBundleId.split('.').last;
      } else {
        suffix = oldExtBundleId;
      }

      final newExtBundleId = '$newMainBundleId.$suffix';
      await _writeBundleId(ext.path, newExtBundleId);
    }
  }

  Future<void> _signFrameworks(
    String appPath, {
    required String signingIdentityId,
    required String workDir,
  }) async {
    final frameworksDir = Directory(p.join(appPath, 'Frameworks'));
    if (!frameworksDir.existsSync()) return;
    final items = frameworksDir
        .listSync()
        .whereType<FileSystemEntity>()
        .where(
          (e) => e.path.endsWith('.framework') || e.path.endsWith('.dylib'),
        )
        .toList();
    for (final item in items) {
      await _signComponent(
        componentPath: item.path,
        signingIdentityId: signingIdentityId,
        workDir: workDir,
      );
    }
  }

  Future<void> _signExtensions(
    String appPath, {
    required String signingIdentityId,
    required String workDir,
    required String mainProvisioningProfilePath,
    required Map<String, String> extensionProvisioningProfileByExtensionName,
  }) async {
    final pluginsDir = Directory(p.join(appPath, 'PlugIns'));
    if (!pluginsDir.existsSync()) return;
    final extensions = pluginsDir
        .listSync()
        .whereType<Directory>()
        .where((d) => p.extension(d.path).toLowerCase() == '.appex')
        .toList();
    for (final ext in extensions) {
      final name = p.basename(ext.path);
      final profilePath =
          extensionProvisioningProfileByExtensionName[name] ??
          mainProvisioningProfilePath;
      await _signComponent(
        componentPath: ext.path,
        signingIdentityId: signingIdentityId,
        workDir: workDir,
        provisioningProfilePath: profilePath,
      );
    }
  }

  Future<void> _signComponent({
    required String componentPath,
    required String signingIdentityId,
    required String workDir,
    String? provisioningProfilePath,
  }) async {
    final entitlementsPath = p.join(
      workDir,
      '${p.basename(componentPath)}.entitlements',
    );
    if (provisioningProfilePath != null) {
      await _extractEntitlements(provisioningProfilePath, entitlementsPath);
      final embeddedPath = p.join(componentPath, 'embedded.mobileprovision');
      await File(provisioningProfilePath).copy(embeddedPath);
    }

    final args = ['-f', '-s', signingIdentityId];
    if (File(entitlementsPath).existsSync()) {
      args.addAll(['--entitlements', entitlementsPath]);
    }
    args.add(componentPath);

    final result = await Process.run('codesign', args);
    if (result.exitCode != 0) {
      final err = result.stderr.toString().trim();
      throw Exception(
        err.isEmpty ? 'codesign failed for ${p.basename(componentPath)}' : err,
      );
    }
  }

  Future<void> _extractEntitlements(
    String profilePath,
    String outputPath,
  ) async {
    final result = await Process.run('security', [
      'cms',
      '-D',
      '-i',
      profilePath,
    ]);
    if (result.exitCode != 0) {
      throw Exception('Failed to extract entitlements from profile.');
    }
    final xml = result.stdout.toString();
    final entitlementsMatch = RegExp(
      r'<key>Entitlements</key>\s*<dict>(.*?)</dict>',
      dotAll: true,
    ).firstMatch(xml);
    if (entitlementsMatch == null) return;

    final entitlements =
        '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
${entitlementsMatch.group(1)}
</dict>
</plist>''';
    await File(outputPath).writeAsString(entitlements);
  }

  Future<List<File>> _findAllProfiles() async {
    final home = Platform.environment['HOME'] ?? '';
    final paths = [
      p.join(home, 'Library/Developer/Xcode/UserData/Provisioning Profiles'),
      p.join(home, 'Library/MobileDevice/Provisioning Profiles'),
    ];

    final allFiles = <File>[];
    for (final dirPath in paths) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      allFiles.addAll(
        dir.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.mobileprovision'),
        ),
      );
    }
    return allFiles;
  }

  Future<String> _getProfileName(String profilePath) async {
    try {
      final result = await Process.run('security', [
        'cms',
        '-D',
        '-i',
        profilePath,
      ]);
      if (result.exitCode != 0) return p.basename(profilePath);
      final xml = result.stdout.toString();
      final match = RegExp(
        r'<key>Name</key>\s*<string>([^<]+)</string>',
      ).firstMatch(xml);
      return match?.group(1) ?? p.basename(profilePath);
    } catch (_) {
      return p.basename(profilePath);
    }
  }
}
