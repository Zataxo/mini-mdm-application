import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mini_mdm_installer/config/theme/app_theme.dart';
import 'package:mini_mdm_installer/src/providers/general_provider.dart';
import 'package:mini_mdm_installer/src/screens/devices_screen.dart';
import 'package:mini_mdm_installer/src/screens/ios_devices_screen.dart';
import 'package:provider/provider.dart';

class ModeSelectScreen extends StatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  State<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends State<ModeSelectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GeneralProvider>().initializeData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 940;

          if (isCompact) {
            return SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: const _ModeLeftPanel(isDesktop: false),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: const _ModeRightPanel(isDesktop: false),
                    ),
                  ],
                ),
              ),
            );
          }

          // Desktop Engine Viewport
          return Row(
            children: [
              Container(
                width: 320,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(right: BorderSide(color: AppColors.border)),
                ),
                child: const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 28, 24, 20),
                    child: _ModeLeftPanel(isDesktop: true),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: double.infinity,
                  color: AppColors.background,
                  child: const SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 32,
                        ),
                        child: _ModeRightPanel(isDesktop: true),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModeLeftPanel extends StatelessWidget {
  final bool isDesktop;

  const _ModeLeftPanel({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final content = [
      Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.devices_other_rounded,
              size: 20,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mini MDM',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Local deployment engine',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Text(
        'Install and manage Android APK + iOS IPA bundles over your local network effortlessly.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          height: 1.4,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: const [
          _Pill(label: 'Local-first'),
          _Pill(label: 'Wireless Debug'),
          _Pill(label: 'Batch Loops'),
        ],
      ),
      const SizedBox(height: 28),
      Text(
        'CAPABILITIES',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary.withValues(alpha: 0.6),
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          fontSize: 10,
        ),
      ),
      const SizedBox(height: 14),
      const _FeatureRow(
        icon: Icons.android_rounded,
        color: AppColors.accent,
        title: 'Android Subsystem',
        desc:
            'Wireless debugging protocols and APK automated background loops.',
      ),
      const _FeatureRow(
        icon: Icons.phone_iphone_rounded,
        color: AppColors.blue,
        title: 'iOS IPA Deployments',
        desc:
            'Direct interaction hooks built directly onto local core environments.',
      ),
      const _FeatureRow(
        icon: Icons.verified_user_rounded,
        color: AppColors.orange,
        title: 'Profile Resigner',
        desc:
            'Alter bundle parameters and inject active system profiles easily.',
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          const _HintBadge(
            icon: Icons.lock_outline_rounded,
            text: 'No cloud required',
          ),
          _HintBadge(
            icon: Icons.apple_rounded,
            text: Platform.isMacOS ? 'iOS Ready' : 'Mac Required',
          ),
        ],
      ),
    ];

    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...content,
          const SizedBox(height: 24),
          const _FooterBlock(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content,
            ),
          ),
        ),
        const Padding(padding: EdgeInsets.only(top: 16), child: _FooterBlock()),
      ],
    );
  }
}

class _ModeRightPanel extends StatelessWidget {
  final bool isDesktop;

  const _ModeRightPanel({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final cardGrid = [
      _ModeCard(
        title: 'Android (APK)',
        icon: Icons.android_rounded,
        iconColor: AppColors.accent,
        badgeText: 'ADB',
        features: const [
          'ADB Pipeline Scans',
          'Wireless QR Pairing',
          'Silent Batch Installs',
        ],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DevicesScreen()),
        ),
      ),
      _ModeCard(
        title: 'iOS Target (IPA)',
        icon: Icons.phone_iphone_rounded,
        iconColor: AppColors.blue,
        disabled: !Platform.isMacOS,
        badgeText: Platform.isMacOS ? 'NATIVE' : 'DISABLED',
        features: const [
          'xcrun Operations',
          'Bundle Extraction',
          'Live Device Logging',
        ],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IosDevicesScreen()),
        ),
      ),
    ];

    // Diagnostic Metrics Layout Blocks
    final metricsColumn = Column(
      children: [
        Selector<GeneralProvider, String>(
          selector: (_, prov) => prov.localIp,
          builder: (context, ip, _) => _MetricTile(
            icon: Icons.wifi_tethering_rounded,
            title: 'Local Gateway IP',
            value: ip,
          ),
        ),
        const SizedBox(height: 10),
        Selector<GeneralProvider, String>(
          selector: (_, prov) => prov.publicIp,
          builder: (context, ip, _) => _MetricTile(
            icon: Icons.language_rounded,
            title: 'Public Dynamic WAN',
            value: ip,
          ),
        ),
        const SizedBox(height: 10),
        const _MetricTile(
          icon: Icons.developer_board_rounded,
          title: 'Host Architecture',
          value: 'Native Engine Link',
        ),
      ],
    );

    Widget diagnosticSection;
    if (isDesktop) {
      diagnosticSection = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 4, child: metricsColumn),
            const SizedBox(width: 14),
            const Expanded(flex: 5, child: _ConsoleLogViewport()),
          ],
        ),
      );
    } else {
      diagnosticSection = Column(
        children: [
          metricsColumn,
          const SizedBox(height: 14),
          const _ConsoleLogViewport(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'Select Operations Core',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const Spacer(),

            IconButton(
              tooltip: 'Refresh Core Diagnostics',
              splashRadius: 20,
              hoverColor: AppColors.surfaceLight,
              onPressed: () =>
                  context.read<GeneralProvider>().refreshDiagnostics(),
              icon: const Icon(
                Icons.sync_rounded,
                size: 18,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Initialize a target ecosystem architecture below.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cardGrid[0]),
              const SizedBox(width: 14),
              Expanded(child: cardGrid[1]),
            ],
          )
        else ...[
          cardGrid[0],
          const SizedBox(height: 12),
          cardGrid[1],
        ],
        const SizedBox(height: 28),

        Text(
          'ENGINE ENVIRONMENT DIAGNOSTICS',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.6),
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 12),
        diagnosticSection,
        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.terminal_rounded,
                size: 14,
                color: AppColors.blue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Environment: Active automated deployment paths rely directly on initialized system tools config loops.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsoleLogViewport extends StatelessWidget {
  const _ConsoleLogViewport();

  @override
  Widget build(BuildContext context) {
    final logs = context.select<GeneralProvider, List<String>>(
      (p) => p.initLogs,
    );
    final platformLabel = context.select<GeneralProvider, String>(
      (p) => p.platformLabel,
    );
    final adbOk = context.select<GeneralProvider, bool?>((p) => p.adbAvailable);
    final xcodeOk = context.select<GeneralProvider, bool?>(
      (p) => p.xcodeCltAvailable,
    );
    final devicectlOk = context.select<GeneralProvider, bool?>(
      (p) => p.devicectlAvailable,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Initialization Monitor',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(label: platformLabel, status: true),
              _StatusChip(label: 'ADB', status: adbOk),
              if (Platform.isMacOS)
                _StatusChip(label: 'Xcode CLT', status: xcodeOk),
              if (Platform.isMacOS)
                _StatusChip(label: 'devicectl', status: devicectlOk),
            ],
          ),
          const SizedBox(height: 10),
          if (logs.isEmpty)
            const Text(
              'Initializing...',
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 10,
                color: AppColors.textSecondary,
                height: 1.2,
              ),
            )
          else
            ...logs.map(
              (log) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  log,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    height: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool? status;

  const _StatusChip({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final text = status == null ? '...' : (status == true ? 'OK' : 'Missing');
    final color = status == null
        ? AppColors.textSecondary
        : (status == true ? AppColors.accent : AppColors.red);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  desc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final String badgeText;
  final List<String> features;
  final VoidCallback onTap;
  final bool disabled;

  const _ModeCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.badgeText,
    required this.features,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 175,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: disabled
              ? AppColors.border.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: disabled
                              ? AppColors.surfaceLight.withValues(alpha: 0.5)
                              : iconColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: disabled
                              ? AppColors.textSecondary.withValues(alpha: 0.4)
                              : iconColor,
                          size: 18,
                        ),
                      ),
                      _CardBadge(text: badgeText, isDisabled: disabled),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: disabled
                          ? AppColors.textSecondary.withValues(alpha: 0.6)
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...features.map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.5,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.8,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardBadge extends StatelessWidget {
  final String text;
  final bool isDisabled;

  const _CardBadge({required this.text, required this.isDisabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isDisabled
            ? AppColors.border.withValues(alpha: 0.4)
            : AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: isDisabled
              ? AppColors.textSecondary.withValues(alpha: 0.8)
              : AppColors.accent,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _HintBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HintBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterBlock extends StatelessWidget {
  const _FooterBlock();

  @override
  Widget build(BuildContext context) {
    const currentYear = 2026;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Selector<GeneralProvider, String?>(
          selector: (context, provider) => provider.appVersion,
          builder: (context, version, child) {
            if (version == null) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Version : $version',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          '© $currentYear Mini MDM Installer. All rights reserved.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            fontSize: 10,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}
