import 'package:ppdelistore/features/printer/domain/models/printer_model.dart';
import 'package:ppdelistore/features/printer/domain/services/printer_service_interface.dart';

/// Domain-facing contract for everything related to Bluetooth printers.
///
/// This abstraction lets the presentation layer (controllers, screens) work
/// with printers without knowing whether the data is stored locally or on
/// a remote server, and without knowing which Bluetooth plugin is being used.
abstract class PrinterRepositoryInterface {
  /// The raw Bluetooth service used for scanning, pairing and printing.
  PrinterServiceInterface get service;

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Returns the list of printers that have been paired and saved locally.
  List<PrinterModel> getSavedPrinters();

  /// Persists the supplied [printers] list to local storage.
  Future<void> savePrinters(List<PrinterModel> printers);

  /// Returns the default printer (if any).
  PrinterModel? getDefaultPrinter();

  /// Sets the supplied printer as default. Removes default from any
  /// previously-default printer.
  Future<void> setDefaultPrinter(PrinterModel printer);

  /// Removes any default printer setting.
  Future<void> clearDefaultPrinter();

  /// Returns the MAC address of the most-recently connected printer, if any.
  String? getLastConnectedAddress();

  /// Persists the MAC address of the most-recently connected printer.
  Future<void> setLastConnectedAddress(String mac);

  // ---------------------------------------------------------------------------
  // Bluetooth operations (delegate to the underlying service)
  // ---------------------------------------------------------------------------

  Future<bool> isBluetoothEnabled();
  Future<bool> isConnected();
  Future<List<PrinterModel>> scanPairedPrinters();
  Future<bool> connect(String mac);
  Future<bool> disconnect();

  // ---------------------------------------------------------------------------
  // Statistics
  // ---------------------------------------------------------------------------

  /// Increments the persistent connection counter for the printer with the
  /// supplied MAC. No-op if the printer is not stored.
  Future<void> incrementConnectionCount(String mac);

  /// Records the timestamp of the last successful print on the printer.
  Future<void> recordPrintSuccess(String mac);
}
