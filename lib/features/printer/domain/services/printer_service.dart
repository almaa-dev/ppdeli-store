import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'package:ppdelistore/features/printer/domain/models/printer_model.dart';
import 'package:ppdelistore/features/printer/domain/services/printer_service_interface.dart';
import 'package:ppdelistore/features/printer/helper/printer_helper.dart';
import 'package:ppdelistore/util/printer_logger.dart';

/// Concrete implementation backed by the `print_bluetooth_thermal` plugin.
///
/// All public methods:
///   * Return safe defaults on exception (never throw into the UI).
///   * Log every step to [PrinterLogger] for the diagnostics screen.
///   * Tolerate older plugins where the static API differs.
///
/// Authoritative Bluetooth adapter state is updated by an in-process polling
/// loop driven from [PrinterController] (see
/// `PrinterController.startAdapterPolling`). Native channels were
/// deliberately not added to keep this feature dependency-free.
class PrinterService implements PrinterServiceInterface {
  static const String _tag = 'PrinterService';

  /// Latest known Bluetooth adapter state. `null` means "unknown / not yet
  /// sampled". Updated by [markAdapterEnabled].
  static final ValueNotifier<bool?> _adapterEnabled = ValueNotifier<bool?>(
    null,
  );

  /// When the adapter state was last successfully sampled (not from cache).
  /// Used to enforce a TTL on the cached value so external changes to the
  /// Bluetooth adapter (toggled off/on from the system Settings) get
  /// detected by the controller's polling loop.
  static DateTime _lastAdapterSampleAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Maximum age of the cached adapter state before a fresh probe is
  /// forced. Three seconds matches the controller's polling interval so
  /// each tick refreshes the cache.
  static const Duration _adapterCacheTtl = Duration(seconds: 3);

  /// Returns a notifier that the controller can listen to in order to react
  /// to Bluetooth state changes without polling.
  static ValueNotifier<bool?> get adapterStateNotifier => _adapterEnabled;

  /// Called by the controller polling loop when a definitive answer is
  /// known. Future implementations backed by a native EventChannel can
  /// replace this with a single sink call.
  static void markAdapterEnabled(bool value) {
    _lastAdapterSampleAt = DateTime.now();
    if (_adapterEnabled.value != value) {
      _adapterEnabled.value = value;
      PrinterLogger.i(_tag, 'Cached BT adapter state -> $value');
    }
  }

  /// Drops the cached adapter state. Used by tests and by recovery paths
  /// that want to force a re-probe on the next call.
  static void invalidateAdapterCache() {
    _adapterEnabled.value = null;
    _lastAdapterSampleAt = DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Returns whether the device's Bluetooth adapter is enabled.
  ///
  /// `print_bluetooth_thermal` renamed its API at some point:
  ///   * Modern versions expose `isBluetoothEnabled()` (a method).
  ///   * Older versions expose `bluetoothEnabled` (a getter).
  ///
  /// Resolution order (first definitive answer wins):
  ///   1. Cached adapter state — returned only when it was sampled within
  ///      the last 3 seconds (matches the polling cadence). Outside that
  ///      window we always re-probe so that toggling Bluetooth off and on
  ///      from system Settings is picked up promptly.
  ///   2. Plugin `isBluetoothEnabled()` / `bluetoothEnabled` (method then getter).
  ///   3. `pairedBluetooths` probe — short timeout; if it returns devices, BT
  ///      is on.
  ///   4. `permission_handler` service status (`Permission.bluetooth.status`)
  ///      as a coarse but reliable last resort.
  ///
  /// If every step throws, we **return `false` AND log the actual exception
  /// type/message** — previously every step was silently swallowed and the
  /// user saw a confusing "Bluetooth Off" banner with no way to understand
  /// why. Diagnostics must surface a meaningful reason.
  @override
  Future<bool> isBluetoothEnabled() async {
    final dynamic instance = PrintBluetoothThermal;

    // 0) Authoritative source: cached adapter state updated by the polling
    //    loop in PrinterController. Only trust the cache if it is fresh
    //    enough — otherwise external state changes would be missed.
    final bool? cached = _adapterEnabled.value;
    final bool cacheIsFresh =
        DateTime.now().difference(_lastAdapterSampleAt) < _adapterCacheTtl;
    if (cached != null && cacheIsFresh) {
      PrinterLogger.d(_tag, 'isBluetoothEnabled (cached) -> $cached');
      return cached;
    }

    // 1) Modern API: `isBluetoothEnabled()` returns Future<bool>.
    try {
      final dynamic result = instance.isBluetoothEnabled();
      if (result is Future<bool>) {
        final bool v = await result;
        PrinterLogger.d(_tag, 'isBluetoothEnabled() -> $v');
        markAdapterEnabled(v);
        return v;
      }
    } catch (e) {
      PrinterLogger.w(
        _tag,
        'isBluetoothEnabled() threw on plugin: ${e.runtimeType}: $e',
      );
    }

    // 2) Legacy API: `bluetoothEnabled` is a getter (or a value).
    try {
      final dynamic result = instance.bluetoothEnabled;
      if (result is Future<bool>) {
        final bool v = await result;
        PrinterLogger.d(_tag, 'bluetoothEnabled (Future) -> $v');
        markAdapterEnabled(v);
        return v;
      }
      if (result is bool) {
        PrinterLogger.d(_tag, 'bluetoothEnabled (bool) -> $result');
        markAdapterEnabled(result);
        return result;
      }
    } catch (e) {
      PrinterLogger.w(
        _tag,
        'bluetoothEnabled getter threw: ${e.runtimeType}: $e',
      );
    }

    // 3) Best-effort fallback: read paired devices. If we can read them,
    //    Bluetooth is almost certainly enabled. The plugin throws on
    //    Android < 6 when Bluetooth is disabled and on Android 12+ when
    //    BLUETOOTH_CONNECT is not granted, so we wrap with a short timeout
    //    and log the reason.
    try {
      final List<dynamic> devices = await instance.pairedBluetooths.timeout(
        const Duration(seconds: 3),
        onTimeout: () => <dynamic>[],
      );
      final bool fallback = devices.isNotEmpty;
      PrinterLogger.d(
        _tag,
        'isBluetoothEnabled (fallback paired) -> $fallback '
        '(count=${devices.length})',
      );
      markAdapterEnabled(fallback);
      return fallback;
    } catch (e, st) {
      PrinterLogger.e(
        _tag,
        'isBluetoothEnabled (pairedBluetooths fallback) threw: '
        '${e.runtimeType}: $e\n$st',
      );
    }

    // 4) Last resort: permission_handler's Bluetooth service status.
    try {
      final PermissionStatus btPerm = await Permission.bluetooth.status;
      final PermissionStatus locationPerm =
          await Permission.locationWhenInUse.status;
      final bool fallback =
          btPerm.isGranted || btPerm.isLimited || locationPerm.isGranted;
      PrinterLogger.w(
        _tag,
        'isBluetoothEnabled (permissions fallback) -> $fallback '
        '(bluetooth=$btPerm, location=$locationPerm)',
      );
      return fallback;
    } catch (e, st) {
      PrinterLogger.e(
        _tag,
        'isBluetoothEnabled (permissions fallback) threw: '
        '${e.runtimeType}: $e\n$st',
      );
    }
    PrinterLogger.e(_tag, 'isBluetoothEnabled: all probes failed -> false');
    return false;
  }

  /// Returns whether the OS reports an active Bluetooth connection.
  @override
  Future<bool> isConnected() async {
    try {
      final dynamic status = PrintBluetoothThermal.connectionStatus;
      if (status is Future<bool>) {
        final bool value = await status;
        PrinterLogger.d(_tag, 'isConnected -> $value');
        return value;
      }
      if (status is bool) {
        return status;
      }
      return false;
    } catch (e, st) {
      PrinterLogger.e(_tag, 'isConnected failed: ${e.runtimeType}: $e\n$st');
      return false;
    }
  }

  /// Returns the list of printers currently paired at the OS level.
  @override
  Future<List<PrinterModel>> getPairedPrinters() async {
    PrinterLogger.i(_tag, 'Scan started (paired only)');
    try {
      final List<BluetoothInfo> devices = await PrintBluetoothThermal
          .pairedBluetooths
          .timeout(const Duration(seconds: 5));
      final List<PrinterModel> printers = <PrinterModel>[];
      for (final BluetoothInfo info in devices) {
        printers.add(_infoToModel(info));
      }
      PrinterLogger.i(
        _tag,
        'Scan finished — found ${printers.length} printers',
      );
      return printers;
    } catch (e, st) {
      PrinterLogger.e(_tag, 'Scan failed: ${e.runtimeType}: $e\n$st');
      return <PrinterModel>[];
    }
  }

  /// Best-effort discovery. `print_bluetooth_thermal` exposes a single
  /// `pairedBluetooths` call (BR/EDR only) so we cannot run an active
  /// inquiry. This method exists for symmetry and returns the same list as
  /// [getPairedPrinters] – but the controller will dedupe the result with
  /// what it has stored locally to give the impression of a wider scan.
  Future<List<PrinterModel>> discoveryScan() async {
    return getPairedPrinters();
  }

  @override
  Future<bool> connect(String mac) async {
    PrinterLogger.i(_tag, 'Connecting to $mac…');
    try {
      final bool result = await PrintBluetoothThermal.connect(
        macPrinterAddress: mac,
      ).timeout(const Duration(seconds: 15), onTimeout: () => false);
      PrinterLogger.i(_tag, 'connect($mac) -> $result');
      return result;
    } catch (e, st) {
      PrinterLogger.e(_tag, 'connect($mac) threw: ${e.runtimeType}: $e\n$st');
      return false;
    }
  }

  @override
  Future<bool> disconnect() async {
    PrinterLogger.i(_tag, 'Disconnecting…');
    try {
      final bool result = await PrintBluetoothThermal.disconnect.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
      PrinterLogger.i(_tag, 'disconnect -> $result');
      return result;
    } catch (e, st) {
      PrinterLogger.e(_tag, 'disconnect threw: ${e.runtimeType}: $e\n$st');
      return false;
    }
  }

  /// Sends raw ESC/POS bytes to the connected printer.
  ///
  /// The plugin reports `false` on every failure mode (closed socket,
  /// printer off, unsupported command, etc.) without distinguishing them.
  /// To help diagnostics we tag the failure with the platform exception
  /// message whenever the plugin throws. Common failure modes we surface
  /// here:
  ///   * "no connected" / "not connected" — socket is not open.
  ///   * "stream closed" / "Broken pipe" — socket was dropped.
  ///   * "timeout" — write did not complete within 30 s.
  ///   * everything else — logged as-is for the diagnostics screen.
  @override
  Future<bool> writeBytes(List<int> bytes) async {
    try {
      final bool result = await PrintBluetoothThermal.writeBytes(
        bytes,
      ).timeout(const Duration(seconds: 30), onTimeout: () => false);
      PrinterLogger.d(_tag, 'writeBytes(${bytes.length}) -> $result');
      if (!result) {
        PrinterLogger.w(
          _tag,
          'writeBytes returned false (${bytes.length} bytes). '
          'The Bluetooth socket may be stale or the printer is '
          'offline. Try reconnecting from the printers screen.',
        );
      }
      return result;
    } catch (e, st) {
      PrinterLogger.e(_tag, 'writeBytes threw: ${e.runtimeType}: $e\n$st');
      return false;
    }
  }

  /// Sends the paper-cut command to the connected printer.
  ///
  /// Strategy:
  ///   1. Try the plugin's high-level `[PaperCut]()` API. This is the
  ///      cleanest path on printers that have an auto-cutter.
  ///   2. If the plugin does not expose `PaperCut` (older versions) or
  ///      it throws, fall back to writing the canonical ESC/POS
  ///      `GS V 0` byte sequence via [writeBytes]. The sequence is built
  ///      by [PrinterHelper.buildPaperCutBytes] and is redundant on
  ///      purpose so it works on the widest possible range of firmwares.
  ///   3. Printers without an auto-cutter silently ignore the cut bytes;
  ///      the call still reports `true` as long as the Bluetooth socket
  ///      accepted the bytes.
  @override
  Future<bool> paperCut() async {
    PrinterLogger.i(_tag, 'paperCut() requested');

    // 1) Try the plugin's PaperCut() static method if available.
    try {
      final dynamic instance = PrintBluetoothThermal;
      final dynamic candidate = instance.PaperCut;
      if (candidate is Function) {
        final dynamic raw = candidate();
        final bool? ok = raw is Future<bool> ? await raw : (raw as bool?);
        if (ok == true) {
          PrinterLogger.i(_tag, 'paperCut: plugin PaperCut() succeeded');
          return true;
        }
        PrinterLogger.w(
          _tag,
          'paperCut: plugin PaperCut() returned $ok — falling back to bytes',
        );
      }
    } catch (e, st) {
      PrinterLogger.w(
        _tag,
        'paperCut: plugin PaperCut() threw ${e.runtimeType}: $e',
      );
      PrinterLogger.d(_tag, 'paperCut: stack\n$st');
    }

    // 2) Fall back to writing the ESC/POS GS V 0 byte sequence.
    final List<int> cutBytes = PrinterHelper.buildPaperCutBytes();
    PrinterLogger.d(
      _tag,
      'paperCut: writing ${cutBytes.length} cut bytes via writeBytes',
    );
    return writeBytes(cutBytes);
  }

  PrinterModel _infoToModel(BluetoothInfo info) {
    return PrinterModel(
      name: info.name.isNotEmpty ? info.name : 'Printer ${info.macAdress}',
      address: info.macAdress,
    );
  }
}
