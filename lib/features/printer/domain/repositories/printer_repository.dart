import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ppdelistore/features/printer/domain/models/printer_model.dart';
import 'package:ppdelistore/features/printer/domain/repositories/printer_repository_interface.dart';
import 'package:ppdelistore/features/printer/domain/services/printer_service.dart';
import 'package:ppdelistore/features/printer/domain/services/printer_service_interface.dart';
import 'package:ppdelistore/util/printer_logger.dart';

/// Concrete repository that stores printers in [SharedPreferences] and
/// delegates Bluetooth I/O to a [PrinterServiceInterface].
class PrinterRepository implements PrinterRepositoryInterface {
  final SharedPreferences sharedPreferences;
  final PrinterServiceInterface _service;

  /// Keys used in SharedPreferences.
  static const String _pairedPrintersKey = 'paired_printers';
  static const String _defaultPrinterKey = 'default_printer_mac';
  static const String _lastConnectedPrinterKey = 'last_connected_printer';

  static const String _tag = 'PrinterRepository';

  PrinterRepository({
    required this.sharedPreferences,
    PrinterServiceInterface? service,
  }) : _service = service ?? PrinterService();

  @override
  PrinterServiceInterface get service => _service;

  // ---------------------------------------------------------------------------
  // Persistence — printers
  // ---------------------------------------------------------------------------

  @override
  List<PrinterModel> getSavedPrinters() {
    final List<String> rawList =
        sharedPreferences.getStringList(_pairedPrintersKey) ?? <String>[];
    final List<PrinterModel> printers = <PrinterModel>[];
    for (final String raw in rawList) {
      try {
        printers.add(PrinterModel.decode(raw));
      } catch (_) {
        // Skip corrupted entries.
        PrinterLogger.w(_tag, 'Skipping corrupted printer entry');
      }
    }
    return printers;
  }

  @override
  Future<void> savePrinters(List<PrinterModel> printers) async {
    final List<String> encoded = printers
        .map((PrinterModel p) => p.encode())
        .toList();
    await sharedPreferences.setStringList(_pairedPrintersKey, encoded);
    PrinterLogger.d(_tag, 'Saved ${printers.length} printers');
  }

  // ---------------------------------------------------------------------------
  // Default printer
  // ---------------------------------------------------------------------------

  @override
  PrinterModel? getDefaultPrinter() {
    final String? mac = sharedPreferences.getString(_defaultPrinterKey);
    if (mac == null || mac.isEmpty) {
      return null;
    }
    final List<PrinterModel> printers = getSavedPrinters();
    for (final PrinterModel p in printers) {
      if (p.address == mac) {
        return p;
      }
    }
    PrinterLogger.w(
      _tag,
      'Default printer MAC $mac set but not found in saved list',
    );
    return null;
  }

  @override
  Future<void> setDefaultPrinter(PrinterModel printer) async {
    final List<PrinterModel> printers = getSavedPrinters();
    final List<PrinterModel> updated = <PrinterModel>[];
    for (final PrinterModel p in printers) {
      updated.add(p.copyWith(isDefault: p.address == printer.address));
    }
    await savePrinters(updated);
    await sharedPreferences.setString(_defaultPrinterKey, printer.address);
    PrinterLogger.i(_tag, 'Default printer set to ${printer.address}');
  }

  @override
  Future<void> clearDefaultPrinter() async {
    final List<PrinterModel> printers = getSavedPrinters();
    final List<PrinterModel> updated = printers
        .map((PrinterModel p) => p.copyWith(isDefault: false))
        .toList();
    await savePrinters(updated);
    await sharedPreferences.remove(_defaultPrinterKey);
    PrinterLogger.i(_tag, 'Default printer cleared');
  }

  // ---------------------------------------------------------------------------
  // Last-connected MAC
  // ---------------------------------------------------------------------------

  @override
  String? getLastConnectedAddress() {
    final String? raw = sharedPreferences.getString(_lastConnectedPrinterKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
      return map['mac']?.toString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setLastConnectedAddress(String mac) async {
    final Map<String, dynamic> data = <String, dynamic>{
      'mac': mac,
      'connectedAt': DateTime.now().toIso8601String(),
    };
    await sharedPreferences.setString(
      _lastConnectedPrinterKey,
      jsonEncode(data),
    );
  }

  /// Increments [PrinterModel.connectionCount] for the printer identified
  /// by [mac] and persists the change. No-op if [mac] is not stored.
  @override
  Future<void> incrementConnectionCount(String mac) async {
    final List<PrinterModel> printers = getSavedPrinters();
    bool changed = false;
    final List<PrinterModel> updated = printers.map((PrinterModel p) {
      if (p.address == mac) {
        changed = true;
        return p.copyWith(connectionCount: p.connectionCount + 1);
      }
      return p;
    }).toList();
    if (changed) {
      await savePrinters(updated);
    }
  }

  /// Stores the timestamp of the last successful print.
  @override
  Future<void> recordPrintSuccess(String mac) async {
    final List<PrinterModel> printers = getSavedPrinters();
    final List<PrinterModel> updated = printers.map((PrinterModel p) {
      if (p.address == mac) {
        return p.copyWith(lastPrintSuccess: DateTime.now().toIso8601String());
      }
      return p;
    }).toList();
    await savePrinters(updated);
  }

  // ---------------------------------------------------------------------------
  // Bluetooth operations (delegated)
  // ---------------------------------------------------------------------------

  @override
  Future<bool> isBluetoothEnabled() => _service.isBluetoothEnabled();

  @override
  Future<bool> isConnected() => _service.isConnected();

  @override
  Future<List<PrinterModel>> scanPairedPrinters() =>
      _service.getPairedPrinters();

  @override
  Future<bool> connect(String mac) => _service.connect(mac);

  @override
  Future<bool> disconnect() => _service.disconnect();
}
