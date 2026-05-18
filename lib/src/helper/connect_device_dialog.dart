import 'package:flutter/material.dart';
import 'package:mini_mdm_installer/config/theme/app_theme.dart';
import 'package:mini_mdm_installer/src/providers/device_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ConnectDeviceDialog extends StatefulWidget {
  final int initialTabIndex;

  const ConnectDeviceDialog({super.key, this.initialTabIndex = 0});

  @override
  State<ConnectDeviceDialog> createState() => _ConnectDeviceDialogState();
}

class _ConnectDeviceDialogState extends State<ConnectDeviceDialog> {
  late final DeviceProvider _provider;

  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '5555');
  final _ipFocus = FocusNode();

  final _pairIpController = TextEditingController();
  final _pairPortController = TextEditingController();
  final _pairCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _provider = context.read<DeviceProvider>();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _ipFocus.requestFocus(),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _ipFocus.dispose();
    _pairIpController.dispose();
    _pairPortController.dispose();
    _pairCodeController.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.cancelQrPairing();
    });
    super.dispose();
  }

  void _connect() {
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();
    if (ip.isEmpty) return;
    context.read<DeviceProvider>().connectToDevice(ip, port: port);
  }

  void _pairWithCode() {
    final ip = _pairIpController.text.trim();
    final port = _pairPortController.text.trim();
    final code = _pairCodeController.text.trim();
    if (ip.isEmpty || port.isEmpty || code.isEmpty) return;
    context.read<DeviceProvider>().pairWithCode(ip: ip, port: port, code: code);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, provider, _) {
        final isBusy = provider.isConnecting || provider.isPairing;
        return DefaultTabController(
          length: 3,
          initialIndex: widget.initialTabIndex,
          child: Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            child: SizedBox(
              width: 680,
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
                            color: AppColors.blueGlow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.developer_board_rounded,
                            color: AppColors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Wireless Debugging',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If the device is not paired yet, use Pair (QR or Code) first, then it will appear in Scan.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    const TabBar(
                      tabs: [
                        Tab(text: 'Connect'),
                        Tab(text: 'Pair Code'),
                        Tab(text: 'Pair QR'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 460,
                      child: TabBarView(
                        children: [
                          _ConnectTab(
                            ipController: _ipController,
                            portController: _portController,
                            ipFocus: _ipFocus,
                            isBusy: isBusy,
                            connectResult: provider.connectResult,
                            onConnect: _connect,
                          ),
                          _PairCodeTab(
                            ipController: _pairIpController,
                            portController: _pairPortController,
                            codeController: _pairCodeController,
                            isBusy: isBusy,
                            pairResult: provider.pairResult,
                            onPair: _pairWithCode,
                          ),
                          _PairQrTab(
                            isBusy: isBusy,
                            qrPayload: provider.qrPayload,
                            qrServiceName: provider.qrServiceName,
                            qrSecret: provider.qrSecret,
                            pairResult: provider.pairResult,
                            onStart: provider.startQrPairing,
                            onCancel: provider.cancelQrPairing,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConnectTab extends StatelessWidget {
  final TextEditingController ipController;
  final TextEditingController portController;
  final FocusNode ipFocus;
  final bool isBusy;
  final String? connectResult;
  final VoidCallback onConnect;

  const _ConnectTab({
    required this.ipController,
    required this.portController,
    required this.ipFocus,
    required this.isBusy,
    required this.connectResult,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('IP Address', style: _labelStyle),
        const SizedBox(height: 6),
        TextField(
          controller: ipController,
          focusNode: ipFocus,
          decoration: const InputDecoration(
            hintText: '192.168.1.100',
            prefixIcon: Icon(Icons.wifi, size: 18, color: AppColors.textMuted),
          ),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          onSubmitted: (_) => onConnect(),
        ),
        const SizedBox(height: 14),
        Text('Port', style: _labelStyle),
        const SizedBox(height: 6),
        TextField(
          controller: portController,
          decoration: const InputDecoration(
            hintText: '5555',
            prefixIcon: Icon(
              Icons.settings_ethernet_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          onSubmitted: (_) => onConnect(),
        ),
        const SizedBox(height: 16),
        if (connectResult != null) ...[
          _ResultBox(
            text: connectResult!,
            ok:
                connectResult!.contains('connected') ||
                connectResult!.contains('already'),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: isBusy ? null : onConnect,
                child: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : const Text('Connect'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  TextStyle get _labelStyle => const TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );
}

class _PairCodeTab extends StatelessWidget {
  final TextEditingController ipController;
  final TextEditingController portController;
  final TextEditingController codeController;
  final bool isBusy;
  final String? pairResult;
  final VoidCallback onPair;

  const _PairCodeTab({
    required this.ipController,
    required this.portController,
    required this.codeController,
    required this.isBusy,
    required this.pairResult,
    required this.onPair,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pairing IP Address', style: _labelStyle),
        const SizedBox(height: 6),
        TextField(
          controller: ipController,
          decoration: const InputDecoration(
            hintText: '192.168.1.100',
            prefixIcon: Icon(Icons.wifi, size: 18, color: AppColors.textMuted),
          ),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          onSubmitted: (_) => onPair(),
        ),
        const SizedBox(height: 14),
        Text('Pairing Port', style: _labelStyle),
        const SizedBox(height: 6),
        TextField(
          controller: portController,
          decoration: const InputDecoration(
            hintText: '37099',
            prefixIcon: Icon(
              Icons.settings_ethernet_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          onSubmitted: (_) => onPair(),
        ),
        const SizedBox(height: 14),
        Text('Pairing Code', style: _labelStyle),
        const SizedBox(height: 6),
        TextField(
          controller: codeController,
          decoration: const InputDecoration(
            hintText: '123456',
            prefixIcon: Icon(
              Icons.password_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          onSubmitted: (_) => onPair(),
        ),
        const SizedBox(height: 16),
        if (pairResult != null) ...[
          _ResultBox(
            text: pairResult!,
            ok: pairResult!.toLowerCase().contains('success'),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: isBusy ? null : onPair,
                child: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : const Text('Pair'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  TextStyle get _labelStyle => const TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );
}

class _PairQrTab extends StatelessWidget {
  final bool isBusy;
  final String? qrPayload;
  final String? qrServiceName;
  final String? qrSecret;
  final String? pairResult;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  const _PairQrTab({
    required this.isBusy,
    required this.qrPayload,
    required this.qrServiceName,
    required this.qrSecret,
    required this.pairResult,
    required this.onStart,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text(
          'Generate a QR code, then on the phone open Wireless debugging → Pair device with QR code and scan it.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (qrPayload != null) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: qrPayload!,
                version: QrVersions.auto,
                size: 240,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (qrServiceName != null && qrSecret != null)
            _MonoBox(text: 'S:$qrServiceName\nP:$qrSecret'),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No QR generated yet.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (pairResult != null) ...[
          _ResultBox(
            text: pairResult!,
            ok: pairResult!.toLowerCase().contains('success'),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isBusy ? null : onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: isBusy ? null : onStart,
                child: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.background,
                        ),
                      )
                    : const Text('Generate & Pair'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResultBox extends StatelessWidget {
  final String text;
  final bool ok;

  const _ResultBox({required this.text, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? AppColors.accentGlow : AppColors.redGlow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
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
