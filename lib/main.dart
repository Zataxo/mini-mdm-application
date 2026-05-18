// lib/main.dart

import 'package:flutter/material.dart';
import 'package:mini_mdm_installer/config/theme/app_theme.dart';
import 'package:mini_mdm_installer/src/providers/device_provider.dart';
import 'package:mini_mdm_installer/src/screens/devices_screen.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const AdbManagerApp());
}

class AdbManagerApp extends StatelessWidget {
  const AdbManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeviceProvider(),
      child: MaterialApp(
        title: 'ADB Manager',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const DevicesScreen(),
      ),
    );
  }
}
