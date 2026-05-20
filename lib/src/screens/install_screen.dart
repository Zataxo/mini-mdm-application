import 'package:flutter/material.dart';
import 'package:mini_mdm_installer/config/theme/app_theme.dart';
import 'package:mini_mdm_installer/src/helper/operation_result_dialog.dart';
import 'package:mini_mdm_installer/src/providers/device_provider.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path/path.dart' as p;

class InstallScreen extends StatelessWidget {
  const InstallScreen({super.key});

  Future<void> _pickApk(DeviceProvider provider) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
      dialogTitle: 'Select APK file',
    );
    if (result != null && result.files.single.path != null) {
      provider.setApkPath(result.files.single.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, provider, _) {
        // Show result dialog when done
        if (provider.installResults.isNotEmpty && !provider.isInstalling) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => OperationResultDialog(
                title: 'Install Results',
                results: provider.installResults,
                onClose: () {
                  provider.clearInstallResults();
                  Navigator.pop(context); // close dialog
                },
              ),
            );
          });
        }

        if (provider.dpmResults.isNotEmpty && !provider.isRunningDpm) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => OperationResultDialog(
                title: 'Device Policy Results',
                results: provider.dpmResults,
                onClose: () {
                  provider.clearDpmResults();
                  Navigator.pop(context);
                },
              ),
            );
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Install APK',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppColors.border),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Target devices summary
                _TargetDevicesCard(provider: provider),
                const SizedBox(height: 20),

                // APK picker
                _ApkPickerCard(
                  provider: provider,
                  onPick: () => _pickApk(provider),
                ),
                const SizedBox(height: 20),

                if (provider.selectedApkPath != null)
                  _DevicePolicyCard(provider: provider),
                if (provider.selectedApkPath != null)
                  const SizedBox(height: 20),

                // Install button
                if (provider.selectedApkPath != null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: provider.isInstalling
                          ? null
                          : provider.installToSelected,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: AppColors.accent,
                      ),
                      child: provider.isInstalling
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.background,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Installing...'),
                              ],
                            )
                          : Text(
                              'Install to ${provider.selectedDevices.length} device(s)',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ).animate().fadeIn().slideY(begin: 0.05),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DevicePolicyCard extends StatefulWidget {
  final DeviceProvider provider;

  const _DevicePolicyCard({required this.provider});

  @override
  State<_DevicePolicyCard> createState() => _DevicePolicyCardState();
}

class _DevicePolicyCardState extends State<_DevicePolicyCard> {
  final _componentController = TextEditingController();

  @override
  void dispose() {
    _componentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.admin_panel_settings_rounded,
                color: AppColors.orange,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'Device Policy (DPM)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Use these actions after installing (or when the app is already on device). Device owner actions may require a fresh device / no accounts.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _componentController,
            decoration: const InputDecoration(
              labelText: 'Device admin receiver component',
              hintText: 'com.example/.MyDeviceAdminReceiver',
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: provider.isRunningDpm
                      ? null
                      : provider.listDeviceOwnersSelected,
                  icon: const Icon(Icons.list_alt_rounded, size: 16),
                  label: const Text('List Owners'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: provider.isRunningDpm
                      ? null
                      : () => provider.setDeviceOwnerSelected(
                          _componentController.text,
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: AppColors.background,
                  ),
                  icon: provider.isRunningDpm
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : const Icon(Icons.verified_user_rounded, size: 16),
                  label: const Text('Set Device Owner'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: provider.isRunningDpm
                  ? null
                  : () => provider.removeActiveAdminSelected(
                      _componentController.text,
                    ),
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
              label: const Text('Remove Active Admin'),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }
}

// ─── Target Devices Card ──────────────────────────────────────────────────────

class _TargetDevicesCard extends StatelessWidget {
  final DeviceProvider provider;

  const _TargetDevicesCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.devices_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                'Target Devices',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentGlow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${provider.selectedDevices.length} selected',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...provider.selectedDevices.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.smartphone_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    d.displayName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    d.address,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontFamily: 'monospace',
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

// ─── APK Picker Card ─────────────────────────────────────────────────────────

class _ApkPickerCard extends StatelessWidget {
  final DeviceProvider provider;
  final VoidCallback onPick;

  const _ApkPickerCard({required this.provider, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final hasApk = provider.selectedApkPath != null;
    final fileName = hasApk ? p.basename(provider.selectedApkPath!) : null;

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: hasApk ? AppColors.accentGlow : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasApk ? AppColors.accent : AppColors.border,
            width: hasApk ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              hasApk ? Icons.install_mobile_rounded : Icons.upload_file_rounded,
              size: 40,
              color: hasApk ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              hasApk ? fileName! : 'Browse APK File',
              style: TextStyle(
                color: hasApk ? AppColors.accent : AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              hasApk
                  ? provider.selectedApkPath!
                  : 'Click to browse for an .apk file',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasApk) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Change File'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
