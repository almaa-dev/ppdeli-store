import 'dart:convert';

/// ESC/POS capability profile identifiers persisted on a [PrinterModel].
///
/// Each profile is a curated bundle of ESC/POS command switches that matches
/// a specific printer brand. Sending the wrong profile causes the printer to
/// silently ignore the bytes — the Bluetooth socket stays open and the
/// plugin reports success, but nothing is printed. This is the #1 cause of
/// "Print Test does nothing" reports.
///
/// We expose the profile as a stable string (`auto`, `star`, `star_raster`,
/// `epson`, `xprinter_58`, `xprinter_80`) so the value survives JSON
/// round-trips without coupling the persistence layer to the
/// `flutter_esc_pos_utils` enum layout.
enum PrinterCapabilityProfile {
  auto,
  star,
  starRaster,
  epson,
  xprinter58,
  xprinter80,
}

extension PrinterCapabilityProfileX on PrinterCapabilityProfile {
  /// Stable, JSON-safe identifier.
  String get id {
    switch (this) {
      case PrinterCapabilityProfile.auto:
        return 'auto';
      case PrinterCapabilityProfile.star:
        return 'star';
      case PrinterCapabilityProfile.starRaster:
        return 'star_raster';
      case PrinterCapabilityProfile.epson:
        return 'epson';
      case PrinterCapabilityProfile.xprinter58:
        return 'xprinter_58';
      case PrinterCapabilityProfile.xprinter80:
        return 'xprinter_80';
    }
  }

  /// Inverse of [id]. Returns [PrinterCapabilityProfile.auto] for unknown
  /// values so older persisted records keep working.
  static PrinterCapabilityProfile fromId(String? raw) {
    switch (raw) {
      case 'star':
        return PrinterCapabilityProfile.star;
      case 'star_raster':
        return PrinterCapabilityProfile.starRaster;
      case 'epson':
        return PrinterCapabilityProfile.epson;
      case 'xprinter_58':
        return PrinterCapabilityProfile.xprinter58;
      case 'xprinter_80':
        return PrinterCapabilityProfile.xprinter80;
      case 'auto':
      default:
        return PrinterCapabilityProfile.auto;
    }
  }
}

/// Represents a Bluetooth thermal printer that can be paired with the device.
class PrinterModel {
  /// Display name of the printer (e.g. "XP-58").
  String name;

  /// MAC address of the printer (e.g. "00:11:22:33:44:55").
  String address;

  /// Paper size type (58mm or 80mm).
  String printerType;

  /// ESC/POS capability profile (see [PrinterCapabilityProfile]).
  ///
  /// Defaults to [PrinterCapabilityProfile.auto] which makes the controller
  /// pick a profile by inspecting the printer's name and MAC. This auto
  /// detection catches the most common brands (Star, Epson, Xprinter) so the
  /// user does not have to configure anything manually.
  PrinterCapabilityProfile capabilityProfile;

  /// Whether this printer is currently the default printer.
  bool isDefault;

  /// ISO-8601 timestamp of the last successful connection.
  String? lastConnected;

  /// ISO-8601 timestamp of the last successful print.
  String? lastPrintSuccess;

  /// Number of successful connections ever established with this printer.
  /// Used by the diagnostics screen.
  int connectionCount;

  /// Whether the printer is currently connected (this is a runtime value,
  /// not persisted). It is computed by the controller based on the
  /// underlying Bluetooth connection status.
  bool isConnected;

  PrinterModel({
    required this.name,
    required this.address,
    this.printerType = '80mm',
    this.capabilityProfile = PrinterCapabilityProfile.auto,
    this.isDefault = false,
    this.lastConnected,
    this.lastPrintSuccess,
    this.connectionCount = 0,
    this.isConnected = false,
  });

  /// Returns the printer as a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'printerType': printerType,
      'capabilityProfile': capabilityProfile.id,
      'isDefault': isDefault,
      'lastConnected': lastConnected,
      'lastPrintSuccess': lastPrintSuccess,
      'connectionCount': connectionCount,
    };
  }

  /// Re-hydrates a [PrinterModel] from a previously stored JSON map.
  factory PrinterModel.fromJson(Map<String, dynamic> json) {
    return PrinterModel(
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      printerType: (json['printerType'] ?? '80mm').toString(),
      capabilityProfile: PrinterCapabilityProfileX.fromId(
        json['capabilityProfile']?.toString(),
      ),
      isDefault: json['isDefault'] == true,
      lastConnected: json['lastConnected']?.toString(),
      lastPrintSuccess: json['lastPrintSuccess']?.toString(),
      connectionCount: (json['connectionCount'] is int)
          ? json['connectionCount'] as int
          : int.tryParse(json['connectionCount']?.toString() ?? '0') ?? 0,
    );
  }

  /// Encodes the printer to a JSON string used for SharedPreferences.
  String encode() => jsonEncode(toJson());

  /// Decodes the printer from a JSON string used for SharedPreferences.
  factory PrinterModel.decode(String source) {
    if (source.isEmpty) {
      throw const FormatException('Empty printer source');
    }
    return PrinterModel.fromJson(jsonDecode(source) as Map<String, dynamic>);
  }

  PrinterModel copyWith({
    String? name,
    String? address,
    String? printerType,
    PrinterCapabilityProfile? capabilityProfile,
    bool? isDefault,
    String? lastConnected,
    String? lastPrintSuccess,
    int? connectionCount,
    bool? isConnected,
  }) {
    return PrinterModel(
      name: name ?? this.name,
      address: address ?? this.address,
      printerType: printerType ?? this.printerType,
      capabilityProfile: capabilityProfile ?? this.capabilityProfile,
      isDefault: isDefault ?? this.isDefault,
      lastConnected: lastConnected ?? this.lastConnected,
      lastPrintSuccess: lastPrintSuccess ?? this.lastPrintSuccess,
      connectionCount: connectionCount ?? this.connectionCount,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}
