import 'package:flutter/material.dart';
import 'package:mini_mdm_installer/config/theme/app_theme.dart';
import 'package:mini_mdm_installer/core/models/ios_device_model.dart';
import 'package:mini_mdm_installer/src/providers/ios_device_provider.dart';
import 'package:mini_mdm_installer/src/screens/ipa_resign_screen.dart';
import 'package:mini_mdm_installer/src/screens/ios_installed_apps_screen.dart';
import 'package:mini_mdm_installer/src/widgets/empty_state_widget.dart';
import 'package:provider/provider.dart';

class IosDevicesScreen extends StatefulWidget {
  const IosDevicesScreen({super.key});

  @override
  State<IosDevicesScreen> createState() => _IosDevicesScreenState();
}

class _IosDevicesScreenState extends State<IosDevicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<IosDeviceProvider>();
      await provider.init();
      if (provider.devicectlAvailable) {
        await provider.scanDevices();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<IosDeviceProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              _TopBar(provider: provider),
              if (!provider.isMacOS) const _NotSupportedBanner(),
              if (provider.isMacOS && !provider.devicectlAvailable)
                const _DevicectlMissingBanner(),
              Expanded(child: _Body(provider: provider)),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final IosDeviceProvider provider;

  const _TopBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final canUse = provider.isMacOS && provider.devicectlAvailable;
    final canInstall =
        canUse && provider.hasSelection && provider.selectedIpaPath != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.blueGlow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.phone_iphone_rounded,
                  color: AppColors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IPA Manager',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'macOS + xcrun devicectl',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: canInstall && !provider.installing
                ? provider.installToSelected
                : null,
            icon: provider.installing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.background,
                    ),
                  )
                : const Icon(Icons.install_mobile_rounded, size: 18),
            label: Text(
              provider.installing
                  ? 'Installing...'
                  : 'Install (${provider.selectedDeviceIds.length})',
            ),
          ),
          const SizedBox(width: 8),
          _ActionsMenu(provider: provider, canUse: canUse),
        ],
      ),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  final IosDeviceProvider provider;
  final bool canUse;

  const _ActionsMenu({required this.provider, required this.canUse});

  @override
  Widget build(BuildContext context) {
    final disabled = provider.installing || provider.uninstalling;
    return PopupMenuButton<_IosAction>(
      tooltip: 'Actions',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
      color: AppColors.surface,
      onSelected: (action) async {
        switch (action) {
          case _IosAction.modes:
            Navigator.popUntil(context, (r) => r.isFirst);
            return;
          case _IosAction.reset:
            provider.resetAll();
            return;
          case _IosAction.selectAll:
            provider.selectAll(!provider.allSelected);
            return;
          case _IosAction.refresh:
            if (canUse && !provider.installing) {
              await provider.scanDevices();
            }
            return;
          case _IosAction.pickIpa:
            if (canUse && !provider.installing) {
              await provider.pickIpa();
            }
            return;
          case _IosAction.resign:
            if (!canUse) return;
            if (disabled) return;
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IpaResignScreen()),
            );
            return;
        }
      },
      itemBuilder: (_) {
        return [
          const PopupMenuItem(
            value: _IosAction.modes,
            child: _MenuRow(icon: Icons.apps_rounded, label: 'Modes'),
          ),
          PopupMenuItem(
            value: _IosAction.resign,
            enabled: canUse && !disabled,
            child: const _MenuRow(
              icon: Icons.verified_user_rounded,
              label: 'Resign IPA',
            ),
          ),
          PopupMenuItem(
            value: _IosAction.pickIpa,
            enabled: canUse && !provider.installing,
            child: const _MenuRow(
              icon: Icons.upload_file_rounded,
              label: 'Pick IPA',
            ),
          ),
          PopupMenuItem(
            value: _IosAction.refresh,
            enabled: canUse && !provider.installing,
            child: const _MenuRow(
              icon: Icons.refresh_rounded,
              label: 'Refresh',
            ),
          ),
          if (provider.devices.isNotEmpty)
            PopupMenuItem(
              value: _IosAction.selectAll,
              enabled: canUse && !provider.installing,
              child: _MenuRow(
                icon: provider.allSelected
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
                label: provider.allSelected ? 'Deselect all' : 'Select all',
              ),
            ),
          PopupMenuItem(
            value: _IosAction.reset,
            enabled: !disabled,
            child: const _MenuRow(
              icon: Icons.restart_alt_rounded,
              label: 'Reset',
            ),
          ),
        ];
      },
    );
  }
}

enum _IosAction { modes, resign, pickIpa, refresh, selectAll, reset }

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: AppColors.textPrimary)),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  final IosDeviceProvider provider;

  const _Body({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (!provider.isMacOS) {
      return const EmptyState(
        icon: Icons.block_rounded,
        title: 'iOS not supported here',
        subtitle: 'IPA install requires macOS and Xcode Command Line Tools.',
      );
    }

    if (!provider.devicectlAvailable) {
      return const EmptyState(
        icon: Icons.construction_rounded,
        title: 'devicectl not found',
        subtitle:
            'Install Xcode Command Line Tools (xcode-select --install) and make sure xcrun works.',
      );
    }

    if (provider.scanState == IosScanState.idle) {
      return EmptyState(
        icon: Icons.cable_rounded,
        title: 'No devices scanned yet',
        subtitle:
            'Connect an iPhone/iPad (USB or paired over network),\nthen click Refresh.',
        actionLabel: 'Refresh',
        onAction: provider.scanDevices,
      );
    }

    if (provider.scanState == IosScanState.scanning) {
      return const Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      );
    }

    if (provider.scanState == IosScanState.error) {
      return EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Scan failed',
        subtitle: provider.scanError ?? 'Unknown error',
        actionLabel: 'Retry',
        onAction: provider.scanDevices,
      );
    }

    if (provider.devices.isEmpty) {
      return const EmptyState(
        icon: Icons.phonelink_off_rounded,
        title: 'No devices found',
        subtitle:
            'Unlock the device, trust this Mac, and enable Developer Mode if prompted.',
      );
    }

    return Column(
      children: [
        if (provider.selectedIpaPath != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _InfoBar(
              icon: Icons.file_present_rounded,
              text: provider.selectedIpaPath!,
            ),
          ),
        if (provider.installResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: _CollapsibleLogBar(
              icon: provider.installResults.every((r) => r.success)
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              title: 'Install log',
              text: provider.installResults
                  .map((r) => '${r.deviceName}: ${r.message}')
                  .join('\n'),
              onClear: provider.clearInstallResults,
            ),
          ),
        if (provider.uninstallResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: _CollapsibleLogBar(
              icon: provider.uninstallResults.every((r) => r.success)
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              title: 'Uninstall log',
              text: provider.uninstallResults
                  .map((r) => '${r.deviceName}: ${r.message}')
                  .join('\n'),
              onClear: provider.clearUninstallResults,
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: provider.devices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final device = provider.devices[index];
              return _IosDeviceCard(
                device: device,
                selected: provider.selectedDeviceIds.contains(
                  device.identifier,
                ),
                onToggle: () => provider.toggleDevice(device.identifier),
                onViewApps: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: provider,
                      child: IosInstalledAppsScreen(
                        deviceId: device.identifier,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _IosDeviceCard extends StatelessWidget {
  final IosDevice device;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onViewApps;

  const _IosDeviceCard({
    required this.device,
    required this.selected,
    required this.onToggle,
    required this.onViewApps,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.blueGlow : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.blue : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (_) => onToggle(),
              activeColor: AppColors.blue,
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.phone_iphone_rounded,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (device.platform != null) device.platform,
                      if (device.osVersion != null) 'iOS ${device.osVersion}',
                      if (device.transportType != null) device.transportType,
                      if (device.pairingState != null) device.pairingState,
                      if (device.developerModeStatus != null)
                        'devmode:${device.developerModeStatus}',
                    ].whereType<String>().join(' · '),
                    style: Theme.of(context).textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: onViewApps, child: const Text('Apps')),
          ],
        ),
      ),
    );
  }
}

class _InfoBar extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBar({required this.icon, required this.text});

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsibleLogBar extends StatefulWidget {
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? onClear;

  const _CollapsibleLogBar({
    required this.icon,
    required this.title,
    required this.text,
    this.onClear,
  });

  @override
  State<_CollapsibleLogBar> createState() => _CollapsibleLogBarState();
}

class _CollapsibleLogBarState extends State<_CollapsibleLogBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final lines = widget.text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final summary = lines.isEmpty ? widget.text : lines.first;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(widget.icon, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${lines.length} line(s)',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _expanded ? widget.text : summary,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11.5,
                            height: 1.35,
                            fontFamily: 'monospace',
                          ),
                          maxLines: _expanded ? 20 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (widget.onClear != null)
                    IconButton(
                      onPressed: widget.onClear,
                      icon: const Icon(Icons.clear_rounded),
                      color: AppColors.textSecondary,
                      tooltip: 'Clear',
                    ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
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

class _NotSupportedBanner extends StatelessWidget {
  const _NotSupportedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: AppColors.orange.withOpacity(0.1),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'IPA install only works on macOS.',
              style: TextStyle(color: AppColors.orange, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _DevicectlMissingBanner extends StatelessWidget {
  const _DevicectlMissingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: AppColors.orange.withOpacity(0.1),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.orange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'xcrun devicectl not found. Install Xcode Command Line Tools.',
              style: TextStyle(color: AppColors.orange, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
