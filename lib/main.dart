// lib/main.dart

import 'package:flutter/material.dart';
import 'package:mini_mdm_installer/config/theme/app_theme.dart';
import 'package:mini_mdm_installer/root_app.dart';
import 'package:mini_mdm_installer/src/providers/device_provider.dart';
import 'package:mini_mdm_installer/src/providers/ios_device_provider.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const AdbManagerApp());
}

class AdbManagerApp extends StatelessWidget {
  const AdbManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => IosDeviceProvider()),
      ],
      child: MaterialApp(
        title: 'MDM Installer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const ModeSelectScreen(),
      ),
    );
  }
}
