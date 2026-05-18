import 'package:flutter/material.dart';
import 'package:mini_mdm_installer/config/theme/app_theme.dart';
import 'package:mini_mdm_installer/core/models/ios_app_model.dart';
import 'package:mini_mdm_installer/src/providers/ios_device_provider.dart';
import 'package:mini_mdm_installer/src/widgets/empty_state_widget.dart';
import 'package:provider/provider.dart';

class IosInstalledAppsScreen extends StatefulWidget {
  final String deviceId;

  const IosInstalledAppsScreen({super.key, required this.deviceId});

  @override
  State<IosInstalledAppsScreen> createState() => _IosInstalledAppsScreenState();
}

class _IosInstalledAppsScreenState extends State<IosInstalledAppsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<IosDeviceProvider>();
      if (!provider.selectedDeviceIds.contains(widget.deviceId)) {
        provider.toggleDevice(widget.deviceId);
      }
      provider.loadInstalledApps(widget.deviceId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload(IosDeviceProvider provider) {
    provider.loadInstalledApps(widget.deviceId);
  }

  void _confirmUninstall(
    BuildContext context,
    IosDeviceProvider provider,
    String bundleId,
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
                bundleId,
                style: const TextStyle(
                  color: AppColors.blue,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Target: ${provider.selectedDeviceIds.isEmpty ? "no devices selected" : "${provider.selectedDeviceIds.length} selected device(s)"}',
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
            onPressed: provider.uninstalling
                ? null
                : () async {
                    Navigator.pop(context);
                    await provider.uninstallFromSelected(bundleId);
                    _reload(provider);
                  },
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<IosDeviceProvider>(
      builder: (context, provider, _) {
        final allApps = provider.installedApps;
        final filtered = allApps.where((a) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return a.name.toLowerCase().contains(q) ||
              a.bundleId.toLowerCase().contains(q);
        }).toList();

        final deviceName =
            provider.devices
                .where((d) => d.identifier == widget.deviceId)
                .firstOrNull
                ?.name ??
            widget.deviceId;

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
              Row(
                children: [
                  Text('All', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(width: 4),
                  Switch(
                    value: provider.includeAllApps,
                    onChanged: (v) => provider.loadInstalledApps(
                      widget.deviceId,
                      includeAllApps: v,
                    ),
                    activeThumbColor: AppColors.blue,
                    trackColor: WidgetStateProperty.resolveWith((s) {
                      return s.contains(WidgetState.selected)
                          ? AppColors.blueGlow
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
                onPressed: provider.loadingApps
                    ? null
                    : () => _reload(provider),
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: const InputDecoration(
                          hintText: 'Search apps...',
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
              Expanded(
                child: _AppsList(
                  provider: provider,
                  apps: filtered,
                  onUninstall: (bundleId) =>
                      _confirmUninstall(context, provider, bundleId),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AppsList extends StatelessWidget {
  final IosDeviceProvider provider;
  final List<IosApp> apps;
  final void Function(String bundleId) onUninstall;

  const _AppsList({
    required this.provider,
    required this.apps,
    required this.onUninstall,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.loadingApps) {
      return const Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.blue,
          ),
        ),
      );
    }

    if (provider.installedApps.isEmpty) {
      return const EmptyState(
        icon: Icons.apps_rounded,
        title: 'No apps found',
        subtitle: 'Refresh or enable "All" to include system apps.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: apps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final app = apps[index];
        final sub = [
          app.bundleId,
          if (app.version != null) 'v${app.version}',
          if (app.bundleVersion != null) '(${app.bundleVersion})',
        ].join(' ');

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.apps_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sub,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                onPressed: provider.uninstalling
                    ? null
                    : () => onUninstall(app.bundleId),
                child: provider.uninstalling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : const Text('Uninstall'),
              ),
            ],
          ),
        );
      },
    );
  }
}
