import 'package:flutter/material.dart';
import 'package:mini_mdm_installer/config/theme/app_theme.dart';
import 'package:mini_mdm_installer/core/models/device_model.dart';
import 'package:mini_mdm_installer/src/helper/connect_device_dialog.dart';
import 'package:mini_mdm_installer/src/providers/device_provider.dart';
import 'package:mini_mdm_installer/src/screens/install_screen.dart';
import 'package:mini_mdm_installer/src/screens/installed_app_screen.dart';
import 'package:mini_mdm_installer/src/widgets/device_card_widget.dart';
import 'package:mini_mdm_installer/src/widgets/empty_state_widget.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  bool _adbDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAdb();
    });
  }

  Future<void> _initAdb() async {
    final provider = context.read<DeviceProvider>();
    await provider.init();
    if (!_adbDialogShown && mounted && !provider.adbAvailable) {
      _adbDialogShown = true;
      _showAdbLocateDialog();
    }
  }

  void _showConnectDialog() {
    showDialog(
      context: context,
      builder: (_) => const ConnectDeviceDialog(initialTabIndex: 0),
    );
  }

  void _showPairDialog() {
    showDialog(
      context: context,
      builder: (_) => const ConnectDeviceDialog(initialTabIndex: 2),
    );
  }

  void _showAdbLocateDialog() {
    showDialog(context: context, builder: (_) => const _AdbLocateDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              _TopBar(
                provider: provider,
                onConnect: _showConnectDialog,
                onPair: _showPairDialog,
              ),
              if (!provider.adbAvailable) _AdbWarningBanner(provider: provider),
              Expanded(
                child: _DeviceListArea(
                  provider: provider,
                  onPair: _showPairDialog,
                ),
              ),
              if (provider.hasSelection)
                _SelectionActionBar(provider: provider),
            ],
          ),
        );
      },
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final DeviceProvider provider;
  final VoidCallback onConnect;
  final VoidCallback onPair;

  const _TopBar({
    required this.provider,
    required this.onConnect,
    required this.onPair,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Logo area
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accentGlow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.developer_board_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mini MDM Installer',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Wireless Device Manager',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Device count badge
          if (provider.devices.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '${provider.onlineDevices.length} online · ${provider.devices.length} total',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),

          // Select All toggle
          if (provider.devices.isNotEmpty)
            _OutlineChip(
              label: provider.allSelected ? 'Deselect All' : 'Select All',
              icon: provider.allSelected
                  ? Icons.deselect_rounded
                  : Icons.select_all_rounded,
              onTap: () => provider.selectAll(!provider.allSelected),
            ),
          const SizedBox(width: 8),

          // Scan button
          _OutlineChip(
            label: provider.scanState == ScanState.scanning
                ? 'Scanning...'
                : 'Scan',
            icon: Icons.wifi_find_rounded,
            loading: provider.scanState == ScanState.scanning,
            onTap: provider.scanState == ScanState.scanning
                ? null
                : provider.scanDevices,
          ),
          const SizedBox(width: 8),

          _OutlineChip(
            label: 'Pair',
            icon: Icons.qr_code_rounded,
            onTap: onPair,
          ),
          const SizedBox(width: 8),

          // Connect button
          ElevatedButton.icon(
            onPressed: onConnect,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

// ─── Device List Area ─────────────────────────────────────────────────────────

class _DeviceListArea extends StatelessWidget {
  final DeviceProvider provider;
  final VoidCallback? onPair;

  const _DeviceListArea({required this.provider, this.onPair});

  @override
  Widget build(BuildContext context) {
    if (provider.scanState == ScanState.idle) {
      return EmptyState(
        icon: Icons.wifi_find_rounded,
        title: 'No devices scanned yet',
        subtitle:
            'Click Pair to pair a device (QR or code),\nthen Scan to list devices.',
        actionLabel: 'Pair Device',
        onAction: onPair,
      );
    }

    if (provider.scanState == ScanState.scanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ).animate(onPlay: (c) => c.repeat()).rotate(duration: 1.5.seconds),
            const SizedBox(height: 16),
            Text(
              'Scanning for devices...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (provider.scanState == ScanState.error) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Scan failed',
        subtitle: provider.scanError ?? 'Unknown error occurred',
        actionLabel: 'Retry',
        onAction: provider.scanDevices,
      );
    }

    if (provider.devices.isEmpty) {
      return EmptyState(
        icon: Icons.phonelink_off_rounded,
        title: 'No wireless devices found',
        subtitle:
            'Pair the device first (QR or code), then Scan.\n(Settings → Developer Options → Wireless debugging)',
        actionLabel: 'Pair Device',
        onAction: onPair,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: provider.devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final device = provider.devices[index];
        return DeviceCard(
          device: device,
          onToggleSelect: () => provider.toggleDevice(device.serial),
          onDisconnect: () => provider.disconnectDevice(device.serial),
          onViewApps: device.status == DeviceStatus.online
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: provider,
                      child: InstalledAppsScreen(deviceSerial: device.serial),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

// ─── Selection Action Bar ─────────────────────────────────────────────────────

class _SelectionActionBar extends StatelessWidget {
  final DeviceProvider provider;

  const _SelectionActionBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentGlow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${provider.selectedDevices.length} selected',
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => provider.selectAll(false),
            icon: const Icon(Icons.deselect_rounded, size: 16),
            label: const Text('Clear'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: provider,
                  child: const InstallScreen(),
                ),
              ),
            ),
            icon: const Icon(Icons.install_mobile_rounded, size: 18),
            label: Text(
              'Install APK to ${provider.selectedDevices.length} device(s)',
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 1, end: 0, duration: 200.ms);
  }
}

// ─── ADB Warning Banner ───────────────────────────────────────────────────────

class _AdbWarningBanner extends StatelessWidget {
  final DeviceProvider provider;

  const _AdbWarningBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: AppColors.orange.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AppColors.orange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              provider.customAdbPath == null
                  ? 'adb not found. Install Android SDK Platform-Tools or locate adb manually.'
                  : 'Custom adb path is set but not working. Locate adb again.',
              style: const TextStyle(color: AppColors.orange, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const _AdbLocateDialog(),
            ),
            child: const Text('Locate'),
          ),
        ],
      ),
    );
  }
}

class _AdbLocateDialog extends StatefulWidget {
  const _AdbLocateDialog();

  @override
  State<_AdbLocateDialog> createState() => _AdbLocateDialogState();
}

class _AdbLocateDialogState extends State<_AdbLocateDialog> {
  bool _locating = false;

  Future<void> _locate(DeviceProvider provider) async {
    setState(() => _locating = true);
    await provider.locateAdbExecutable();
    if (mounted) setState(() => _locating = false);
    if (mounted && provider.adbAvailable) Navigator.pop(context);
  }

  Future<void> _clear(DeviceProvider provider) async {
    setState(() => _locating = true);
    await provider.clearCustomAdbExecutable();
    if (mounted) setState(() => _locating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, provider, _) {
        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: SizedBox(
            width: 520,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.orange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'ADB Not Found',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Select the adb executable (Android SDK Platform-Tools). After selecting, the app will retry automatically.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text('Current resolved adb', style: _labelStyle),
                  const SizedBox(height: 6),
                  _MonoBox(text: provider.resolvedAdbPath),
                  if (provider.customAdbPath != null) ...[
                    const SizedBox(height: 12),
                    Text('Custom adb path', style: _labelStyle),
                    const SizedBox(height: 6),
                    _MonoBox(text: provider.customAdbPath!),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (provider.customAdbPath != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _locating
                                ? null
                                : () => _clear(provider),
                            child: const Text('Clear Custom Path'),
                          ),
                        )
                      else
                        const Spacer(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _locating ? null : () => _locate(provider),
                          icon: _locating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.background,
                                  ),
                                )
                              : const Icon(Icons.folder_open_rounded, size: 18),
                          label: Text(_locating ? 'Locating...' : 'Locate ADB'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TextStyle get _labelStyle => const TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );
}

class _MonoBox extends StatelessWidget {
  final String text;

  const _MonoBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ─── Outline Chip ─────────────────────────────────────────────────────────────

class _OutlineChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  const _OutlineChip({
    required this.label,
    required this.icon,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textSecondary,
                ),
              )
            else
              Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
