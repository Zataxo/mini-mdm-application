import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mini_mdm_installer/config/theme/app_theme.dart';
import 'package:mini_mdm_installer/core/models/device_model.dart';

class DeviceCard extends StatelessWidget {
  final DeviceModel device;
  final VoidCallback onToggleSelect;
  final VoidCallback? onDisconnect;
  final VoidCallback? onViewApps;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onToggleSelect,
    this.onDisconnect,
    this.onViewApps,
  });

  Color get _statusColor {
    switch (device.status) {
      case DeviceStatus.online:
        return AppColors.accent;
      case DeviceStatus.offline:
        return AppColors.textMuted;
      case DeviceStatus.unauthorized:
        return AppColors.orange;
      case DeviceStatus.connecting:
        return AppColors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = device.status == DeviceStatus.online;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: device.isSelected ? AppColors.accentGlow : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: device.isSelected ? AppColors.accent : AppColors.border,
          width: device.isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: isOnline ? onToggleSelect : null,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.accentGlow,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Checkbox
              _SelectionIndicator(
                isSelected: device.isSelected,
                isOnline: isOnline,
              ),
              const SizedBox(width: 14),

              // Device icon
              _DeviceIcon(status: device.status, statusColor: _statusColor),
              const SizedBox(width: 14),

              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            device.displayName,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(
                          label: device.statusLabel,
                          color: _statusColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.wifi, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          device.address,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        if (device.manufacturer != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            '${device.manufacturer}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                        if (device.androidVersion != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.android,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Android ${device.androidVersion}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              if (isOnline) ...[
                _ActionButton(
                  icon: Icons.apps_rounded,
                  tooltip: 'View Installed Apps',
                  color: AppColors.blue,
                  onTap: onViewApps,
                ),
                const SizedBox(width: 4),
              ],
              _ActionButton(
                icon: Icons.link_off_rounded,
                tooltip: 'Disconnect',
                color: AppColors.red,
                onTap: onDisconnect,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.03, duration: 300.ms);
  }
}

class _SelectionIndicator extends StatelessWidget {
  final bool isSelected;
  final bool isOnline;

  const _SelectionIndicator({required this.isSelected, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    if (!isOnline) {
      return const SizedBox(width: 24);
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? AppColors.accent : AppColors.textMuted,
          width: 1.5,
        ),
      ),
      child: isSelected
          ? const Icon(
              Icons.check_rounded,
              size: 14,
              color: AppColors.background,
            )
          : null,
    );
  }
}

class _DeviceIcon extends StatelessWidget {
  final DeviceStatus status;
  final Color statusColor;

  const _DeviceIcon({required this.status, required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.smartphone_rounded,
            color: AppColors.textSecondary,
            size: 22,
          ),
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 2),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
