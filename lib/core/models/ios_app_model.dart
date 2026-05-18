class IosApp {
  final String name;
  final String bundleId;
  final String? version;
  final String? bundleVersion;
  final bool? removable;
  final bool? builtByDeveloper;

  const IosApp({
    required this.name,
    required this.bundleId,
    this.version,
    this.bundleVersion,
    this.removable,
    this.builtByDeveloper,
  });
}

