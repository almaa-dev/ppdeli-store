import 'package:ppdelistore/features/printer/domain/models/printer_model.dart';

/// Connection status reported by the underlying Bluetooth subsystem.
enum PrinterConnectionStatus {
  connected,
  disconnected,
  connecting,
  bluetoothOff,
}

/// Abstraction over the raw Bluetooth thermal printer library
/// ([PrintBluetoothThermal]) so the rest of the app does not need to
/// know about the underlying platform plugin.
abstract class PrinterServiceInterface {
  /// Whether the device's Bluetooth adapter is currently enabled.
  Future<bool> isBluetoothEnabled();

  /// Whether the device is currently connected to a Bluetooth printer.
  Future<bool> isConnected();

  /// Returns a list of all printers that have been paired at the OS level.
  Future<List<PrinterModel>> getPairedPrinters();

  /// Connects to a printer using its [mac] address.
  Future<bool> connect(String mac);

  /// Disconnects the currently connected printer, if any.
  Future<bool> disconnect();

  /// Sends raw bytes to the connected printer.
  Future<bool> writeBytes(List<int> bytes);

  /// Issues a paper-cut command to the connected printer.
  ///
  /// Implementations should use the plugin's `[PaperCut]()` API when
  /// available and fall back to writing the canonical ESC/POS
  /// `GS V 0` byte sequence via [writeBytes] otherwise. The method must
  /// be safe to call on any printer — devices without an auto-cutter
  /// should silently ignore the command and the call should report
  /// `true` as long as the bytes were accepted by the Bluetooth socket.
  ///
  /// Used by the vendor-side invoice workflow so the printed receipt is
  /// automatically torn off the roll after the print completes.
  /// See `PrinterHelper.buildPaperCutBytes` for the byte sequence.
  Future<bool> paperCut();
}

class PrinterServiceInterfaceException implements Exception {
  final String message;
  PrinterServiceInterfaceException(this.message);
  @override
  String toString() => 'PrinterServiceInterfaceException: $message';
}
