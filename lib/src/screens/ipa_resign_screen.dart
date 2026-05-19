import 'package:flutter/material.dart';
import 'package:mini_mdm_installer/config/theme/app_theme.dart';
import 'package:mini_mdm_installer/core/services/ipa_resign_service.dart';
import 'package:mini_mdm_installer/src/providers/ios_device_provider.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

class IpaResignScreen extends StatefulWidget {
  const IpaResignScreen({super.key});

  @override
  State<IpaResignScreen> createState() => _IpaResignScreenState();
}

class _IpaResignScreenState extends State<IpaResignScreen> {
  final _service = IpaResignService();
  final _bundleIdController = TextEditingController();
  final _logController = ScrollController();

  bool _loading = true;
  bool _running = false;

  String? _ipaPath;
  String? _outputPath;

  List<SigningIdentity> _identities = [];
  String? _selectedIdentityId;

  List<ProvisioningProfile> _profiles = [];
  String? _selectedMainProfilePath;
  final Map<String, String> _customProfileLabelByPath = {};

  List<String> _extensions = [];
  final Map<String, String?> _extensionProfilePathByName = {};

  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadIdentitiesAndProfiles();
    });
  }

  @override
  void dispose() {
    _bundleIdController.dispose();
    _logController.dispose();
    super.dispose();
  }

  void _log(String line) {
    setState(() {
      _logs.add(line);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_logController.hasClients) return;
      _logController.animateTo(
        _logController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadIdentitiesAndProfiles() async {
    setState(() {
      _loading = true;
    });
    try {
      final identities = await _service.listSigningIdentities();
      final profiles = await _service.listProvisioningProfiles();
      setState(() {
        _identities = identities;
        _profiles = profiles;
        _selectedIdentityId = identities.isNotEmpty
            ? identities.first.id
            : null;
      });
      _log('Loaded ${identities.length} signing identity(s)');
      _log('Loaded ${profiles.length} provisioning profile(s)');
    } catch (e) {
      _log(e.toString());
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pickIpa() async {
    final path = await _service.pickIpaPath();
    if (path == null) return;

    setState(() {
      _ipaPath = path;
      _outputPath = null;
      _extensions = [];
      _extensionProfilePathByName.clear();
    });

    _log('Selected IPA: ${p.basename(path)}');

    try {
      final extensions = await _service.listExtensionsInIpa(path);
      setState(() {
        _extensions = extensions;
        for (final ext in extensions) {
          _extensionProfilePathByName[ext] = null;
        }
      });
      if (extensions.isNotEmpty) {
        _log('Detected extensions: ${extensions.join(', ')}');
      }
    } catch (e) {
      _log(e.toString());
    }
  }

  Future<void> _pickMainProfile() async {
    final picked = await _service.pickProvisioningProfile();
    if (picked == null) return;
    setState(() {
      _selectedMainProfilePath = picked.path;
      _customProfileLabelByPath[picked.path] = picked.displayName;
    });
    _log(
      'Selected main profile: ${picked.displayName} (${p.basename(picked.path)})',
    );
  }

  Future<void> _pickExtensionProfile(String extName) async {
    final picked = await _service.pickProvisioningProfile();
    if (picked == null) return;
    setState(() {
      _extensionProfilePathByName[extName] = picked.path;
      _customProfileLabelByPath[picked.path] = picked.displayName;
    });
    _log(
      'Selected profile for $extName: ${picked.displayName} (${p.basename(picked.path)})',
    );
  }

  ProvisioningProfile? _profileByPath(String? path) {
    if (path == null) return null;
    for (final p0 in _profiles) {
      if (p0.path == path) return p0;
    }
    return null;
  }

  String _profileLabelForPath(String path) {
    final fromMac = _profileByPath(path);
    if (fromMac != null) return fromMac.displayName;
    final custom = _customProfileLabelByPath[path];
    if (custom != null && custom.trim().isNotEmpty) return custom;
    return p.basename(path);
  }

  List<String> _profilePathItems() {
    final ordered = <String>[];
    final seen = <String>{};

    for (final entry in _customProfileLabelByPath.keys) {
      if (seen.add(entry)) ordered.add(entry);
    }
    for (final prof in _profiles) {
      if (seen.add(prof.path)) ordered.add(prof.path);
    }
    return ordered;
  }

  SigningIdentity? _identityById(String? id) {
    if (id == null) return null;
    for (final i in _identities) {
      if (i.id == id) return i;
    }
    return null;
  }

  bool get _canRun =>
      !_running &&
      _ipaPath != null &&
      _selectedIdentityId != null &&
      _selectedMainProfilePath != null;

  Future<void> _runResign() async {
    final ipaPath = _ipaPath;
    final identityId = _selectedIdentityId;
    final mainProfilePath = _selectedMainProfilePath;
    if (ipaPath == null || identityId == null || mainProfilePath == null)
      return;

    final newBundleId = _bundleIdController.text.trim().isEmpty
        ? null
        : _bundleIdController.text.trim();

    final extProfiles = <String, String>{};
    for (final ext in _extensions) {
      final path = _extensionProfilePathByName[ext];
      if (path != null) extProfiles[ext] = path;
    }

    setState(() {
      _running = true;
      _outputPath = null;
    });

    _log('------------------------------');
    _log('Starting resign...');

    try {
      final outputPath = await _service.resignIpa(
        ipaPath: ipaPath,
        signingIdentityId: identityId,
        mainProvisioningProfilePath: mainProfilePath,
        extensionProvisioningProfileByExtensionName: extProfiles,
        newBundleId: newBundleId,
        onLog: _log,
      );

      setState(() {
        _outputPath = outputPath;
      });
      _log('Success: ${p.basename(outputPath)}');
    } catch (e) {
      _log(e.toString());
    } finally {
      setState(() {
        _running = false;
      });
    }
  }

  void _useSignedIpa({required bool close}) {
    final output = _outputPath;
    if (output == null) return;
    context.read<IosDeviceProvider>().setIpaPath(output);
    if (close) {
      Navigator.pop(context);
    } else {
      _log('Selected IPA for install: ${p.basename(output)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = _identityById(_selectedIdentityId);
    // final mainProfile = _profileByPath(_selectedMainProfilePath);
    final profileItems = _profilePathItems();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('IPA Resign'),
        actions: [
          TextButton(
            onPressed: _running ? null : () => setState(() => _logs.clear()),
            child: const Text('Clear log'),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Row(
        children: [
          Expanded(
            flex: 6,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _CardSection(
                  title: 'Inputs',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PickField(
                        label: 'IPA',
                        value: _ipaPath == null ? 'Not selected' : _ipaPath!,
                        actionLabel: 'Pick',
                        onAction: _running ? null : _pickIpa,
                      ),
                      const SizedBox(height: 12),
                      _DropdownString(
                        label: 'Certificate',
                        value: _selectedIdentityId,
                        items: _identities.map((i) => i.id).toList(),
                        itemLabel: (id) => _identityById(id)?.name ?? id,
                        onChanged: _running
                            ? null
                            : (v) => setState(() => _selectedIdentityId = v),
                      ),
                      if (identity != null) const SizedBox(height: 8),
                      if (identity != null) _HintRow(text: identity.name),
                      const SizedBox(height: 12),
                      _PickField(
                        label: 'Main profile',
                        value: _selectedMainProfilePath == null
                            ? 'Not selected'
                            : '${_profileLabelForPath(_selectedMainProfilePath!)} (${p.basename(_selectedMainProfilePath!)})',
                        actionLabel: 'Pick',
                        onAction: _running ? null : _pickMainProfile,
                      ),
                      const SizedBox(height: 12),
                      _DropdownString(
                        label: 'Or choose from Mac',
                        value: _selectedMainProfilePath,
                        items: profileItems,
                        itemLabel: (path) {
                          return '${_profileLabelForPath(path)} (${p.basename(path)})';
                        },
                        onChanged: _running
                            ? null
                            : (v) =>
                                  setState(() => _selectedMainProfilePath = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bundleIdController,
                        enabled: !_running,
                        decoration: const InputDecoration(
                          labelText: 'New Bundle ID (optional)',
                          hintText: 'com.company.app',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_extensions.isNotEmpty)
                  _CardSection(
                    title: 'Extensions',
                    child: Column(
                      children: _extensions.map((ext) {
                        final path = _extensionProfilePathByName[ext];
                        final prof = _profileByPath(path);
                        final label = path == null
                            ? 'Use main profile'
                            : '${prof?.displayName ?? "Custom"} (${p.basename(path)})';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ext,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceLight,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton(
                                    onPressed: _running
                                        ? null
                                        : () => _pickExtensionProfile(ext),
                                    child: const Text('Pick'),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton(
                                    onPressed: _running
                                        ? null
                                        : () => setState(
                                            () =>
                                                _extensionProfilePathByName[ext] =
                                                    null,
                                          ),
                                    child: const Text('Use main'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 14),
                if (_outputPath != null)
                  _CardSection(
                    title: 'Output',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _outputPath!,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: _running
                                  ? null
                                  : () => _useSignedIpa(close: false),
                              child: const Text('Use'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _running
                                  ? null
                                  : () => _useSignedIpa(close: true),
                              child: const Text('Use & Close'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (_loading) const SizedBox(height: 10),
                if (_loading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.blue,
                  ),
              ],
            ),
          ),
          Container(width: 1, color: AppColors.border),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Log',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _canRun ? _runResign : null,
                        child: _running
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.background,
                                ),
                              )
                            : const Text('Resign'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SingleChildScrollView(
                        controller: _logController,
                        child: Text(
                          _logs.isEmpty ? 'No logs yet.' : _logs.join('\n'),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            height: 1.35,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _CardSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// class _KeyValueRow extends StatelessWidget {
//   final String label;
//   final String value;
//   final String actionLabel;
//   final VoidCallback? onAction;

//   const _KeyValueRow({
//     required this.label,
//     required this.value,
//     required this.actionLabel,
//     required this.onAction,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(
//           width: 140,
//           child: Padding(
//             padding: const EdgeInsets.only(top: 12),
//             child: Text(
//               label,
//               style: const TextStyle(
//                 color: AppColors.textSecondary,
//                 fontSize: 12,
//               ),
//             ),
//           ),
//         ),
//         Expanded(
//           child: Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: AppColors.surfaceLight,
//               borderRadius: BorderRadius.circular(10),
//               border: Border.all(color: AppColors.border),
//             ),
//             child: Text(
//               value,
//               style: const TextStyle(
//                 color: AppColors.textPrimary,
//                 fontSize: 12,
//                 fontFamily: 'monospace',
//               ),
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ),
//         const SizedBox(width: 10),
//         SizedBox(
//           height: 42,
//           child: OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
//         ),
//       ],
//     );
//   }
// }

class _PickField extends StatelessWidget {
  final String label;
  final String value;
  final String actionLabel;
  final VoidCallback? onAction;

  const _PickField({
    required this.label,
    required this.value,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 42,
              child: OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DropdownString extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final String Function(String) itemLabel;
  final ValueChanged<String?>? onChanged;

  const _DropdownString({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final uniqueItems = <String>[];
    final seen = <String>{};
    for (final item in items) {
      if (seen.add(item)) uniqueItems.add(item);
    }
    final effectiveValue = value != null && uniqueItems.contains(value)
        ? value
        : null;

    return DropdownButtonFormField<String>(
      initialValue: effectiveValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: uniqueItems
          .map(
            (v) => DropdownMenuItem(
              value: v,
              child: Text(
                itemLabel(v),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _HintRow extends StatelessWidget {
  final String text;

  const _HintRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11.5,
          fontFamily: 'monospace',
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
