class IosDevice {
  final String identifier;
  final String name;
  final String? platform;
  final String? osVersion;
  final String? udid;
  final String? pairingState;
  final String? transportType;
  final String? developerModeStatus;

  const IosDevice({
    required this.identifier,
    required this.name,
    this.platform,
    this.osVersion,
    this.udid,
    this.pairingState,
    this.transportType,
    this.developerModeStatus,
  });
}
