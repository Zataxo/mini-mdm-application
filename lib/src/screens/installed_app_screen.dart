import 'package:flutter/material.dart';
import 'package:mini_mdm_installer/config/theme/app_theme.dart';
import 'package:mini_mdm_installer/src/helper/operation_result_dialog.dart';
import 'package:mini_mdm_installer/src/providers/device_provider.dart';
import 'package:mini_mdm_installer/src/widgets/app_list_item_widget.dart';
import 'package:mini_mdm_installer/src/widgets/empty_state_widget.dart';
import 'package:provider/provider.dart';

class InstalledAppsScreen extends StatefulWidget {
  final String deviceSerial;

  const InstalledAppsScreen({super.key, required this.deviceSerial});

  @override
  State<InstalledAppsScreen> createState() => _InstalledAppsScreenState();
}

class _InstalledAppsScreenState extends State<InstalledAppsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSystem = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().loadInstalledApps(
        widget.deviceSerial,
        includeSystem: _showSystem,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload(DeviceProvider provider) {
    provider.loadInstalledApps(widget.deviceSerial, includeSystem: _showSystem);
  }

  void _confirmUninstall(
    BuildContext context,
    DeviceProvider provider,
    String packageName,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text(
          'Confirm Uninstall',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Uninstall this app from the selected devices?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                packageName,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Target: ${provider.selectedDevices.isEmpty ? "all devices" : "${provider.selectedDevices.length} selected device(s)"}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () async {
              Navigator.pop(context);
              await provider.uninstallFromSelected(packageName);
              if (context.mounted && provider.uninstallResults.isNotEmpty) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => OperationResultDialog(
                    title: 'Uninstall Results',
                    results: provider.uninstallResults,
                    onClose: () {
                      provider.clearUninstallResults();
                      Navigator.pop(context);
                      _reload(provider);
                    },
                  ),
                );
              }
            },
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, provider, _) {
        final allApps = provider.installedApps;
        final filtered = allApps.where((a) {
          if (_searchQuery.isEmpty) return true;
          return a.packageName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
        }).toList();

        // Get device name
        final device = provider.devices
            .where((d) => d.serial == widget.deviceSerial)
            .firstOrNull;
        final deviceName = device?.displayName ?? widget.deviceSerial;

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
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Installed Apps',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  deviceName,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            actions: [
              // System apps toggle
              Row(
                children: [
                  Text('System', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(width: 4),
                  Switch(
                    value: _showSystem,
                    onChanged: (v) {
                      setState(() => _showSystem = v);
                      provider.loadInstalledApps(
                        widget.deviceSerial,
                        includeSystem: v,
                      );
                    },
                    activeThumbColor: AppColors.accent,
                    trackColor: WidgetStateProperty.resolveWith((s) {
                      return s.contains(WidgetState.selected)
                          ? AppColors.accentDim
                          : AppColors.border;
                    }),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => _reload(provider),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppColors.border),
            ),
          ),
          body: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: const InputDecoration(
                          hintText: 'Search packages...',
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (allApps.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${filtered.length} apps',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // App list
              Expanded(child: _buildBody(context, provider, filtered)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    DeviceProvider provider,
    filteredApps,
  ) {
    if (provider.loadingApps) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading packages...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (filteredApps.isEmpty) {
      return EmptyState(
        icon: Icons.apps_rounded,
        title: _searchQuery.isNotEmpty
            ? 'No matches found'
            : 'No apps installed',
        subtitle: _searchQuery.isNotEmpty
            ? 'Try a different search term'
            : 'No third-party apps installed on this device',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: filteredApps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final app = filteredApps[index];
        return AppListItem(
          app: app,
          onUninstall: () =>
              _confirmUninstall(context, provider, app.packageName),
        );
      },
    );
  }
}
