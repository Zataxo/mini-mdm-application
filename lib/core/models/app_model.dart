class AppModel {
  final String packageName;
  final String? appName;
  final String? versionName;
  final String? versionCode;
  final bool isSystemApp;

  AppModel({
    required this.packageName,
    this.appName,
    this.versionName,
    this.versionCode,
    this.isSystemApp = false,
  });

  String get displayName => appName ?? packageName;
}
