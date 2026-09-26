import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show AppLifecycleListener, AppLifecycleState;
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:ppdelistore/common/widgets/custom_snackbar_widget.dart';
import 'package:ppdelistore/features/printer/domain/models/printer_model.dart';
import 'package:ppdelistore/features/printer/domain/repositories/printer_repository_interface.dart';
import 'package:ppdelistore/features/printer/domain/services/printer_service.dart';
import 'package:ppdelistore/features/printer/helper/printer_helper.dart';
import 'package:ppdelistore/util/printer_logger.dart';

// =============================================================================
// Public enums
// =============================================================================

/// Visual status used by the UI to render a coloured indicator.
enum PrinterUiStatus {
  ready,
  connecting,
  connected,
  disconnected,
  bluetoothOff,
  permissionDenied,
  scanning,
  printing,
  printFailed,
}

/// Result of a [PrinterController.validateBluetooth] call. Whenever
/// [isReady] is false the [reason] contains a human-readable, translatable
/// explanation suitable for a SnackBar.
class BluetoothValidationResult {
  final bool isReady;
  final BluetoothValidationFailure? failure;
  final String? reason;
  const BluetoothValidationResult._({
    required this.isReady,
    this.failure,
    this.reason,
  });
  const BluetoothValidationResult.ok()
    : this._(isReady: true, failure: null, reason: null);
  const BluetoothValidationResult.fail(
    BluetoothValidationFailure failure,
    String reason,
  ) : this._(isReady: false, failure: failure, reason: reason);
}

/// The category of failure returned by [PrinterController.validateBluetooth].
enum BluetoothValidationFailure {
  bluetoothOff,
  permissionDenied,
  permissionPermanentlyDenied,
  unknown,
}

/// Result of a print attempt. Returned from the public print methods so that
/// callers (and tests) can branch on it.
class PrintResult {
  final bool success;
  final String? errorCode;
  final String? message;
  final PrinterModel? printer;
  const PrintResult.success(this.printer)
    : success = true,
      errorCode = null,
      message = null;
  const PrintResult.failure(this.errorCode, this.message)
    : success = false,
      printer = null;
}

/// Snapshot of the printer subsystem's health, suitable for the diagnostics
/// screen.
class PrinterDiagnosticsReport {
  final bool bluetoothSupported;
  final bool bluetoothEnabled;
  final bool permissionsGranted;
  final bool anyPermissionPermanentlyDenied;
  final int savedPrinterCount;
  final bool hasDefaultPrinter;
  final bool connectedToDefaultPrinter;
  final String? defaultPrinterMac;
  final String? defaultPrinterName;
  final String? lastConnectedMac;
  final int connectionAttemptsLast;
  final List<String> issues;
  final List<String> recommendations;

  const PrinterDiagnosticsReport({
    required this.bluetoothSupported,
    required this.bluetoothEnabled,
    required this.permissionsGranted,
    required this.anyPermissionPermanentlyDenied,
    required this.savedPrinterCount,
    required this.hasDefaultPrinter,
    required this.connectedToDefaultPrinter,
    required this.defaultPrinterMac,
    required this.defaultPrinterName,
    required this.lastConnectedMac,
    required this.connectionAttemptsLast,
    required this.issues,
    required this.recommendations,
  });
}

// =============================================================================
// Controller
// =============================================================================

/// Controller responsible for managing Bluetooth printers.
///
/// The class is **backward compatible**: every public method, field, and
/// enum value exposed by the previous version is preserved verbatim. New
/// functionality (validation, retry-with-backoff, deduplication, logging,
/// diagnostics) is added on top.
class PrinterController extends GetxController implements GetxService {
  static const String _tag = 'PrinterController';

  /// Maximum number of reconnection attempts before giving up.
  static const int maxReconnectAttempts = 3;

  /// Delay between reconnection attempts. Doubled after each failure.
  static const Duration initialReconnectDelay = Duration(milliseconds: 600);

  /// Cooldown after a successful print so we don't fire two prints in a row.
  static const Duration printCooldown = Duration(milliseconds: 250);

  /// Maximum number of write attempts (with reconnect in between) before
  /// giving up on a single print request. We retry after a forced
  /// disconnect+reconnect because the `print_bluetooth_thermal` plugin
  /// reports `false` on a stale socket that the OS still claims is open
  /// — a common problem on Star TSP100 / Xprinter XP-series hardware.
  static const int maxWriteAttempts = 2;

  final PrinterRepositoryInterface printerRepository;

  PrinterController({required this.printerRepository});

  // ---------------------------------------------------------------------------
  // Reactive state (kept for backwards compatibility)
  // ---------------------------------------------------------------------------

  /// All known printers (paired at the OS level + previously saved).
  final RxList<PrinterModel> printers = <PrinterModel>[].obs;

  /// The default printer (if any).
  final Rxn<PrinterModel> defaultPrinter = Rxn<PrinterModel>();

  /// Whether Bluetooth is enabled on the device.
  final RxBool bluetoothEnabled = false.obs;

  /// Whether the underlying scanner is currently looking for printers.
  final RxBool scanning = false.obs;

  /// Whether the controller is currently attempting to connect to a printer.
  final RxBool connecting = false.obs;

  /// Whether the controller is currently printing.
  final RxBool printing = false.obs;

  /// Whether the necessary runtime permissions have been granted.
  final RxBool permissionsGranted = false.obs;

  /// The MAC address of the printer that is currently connected at the OS
  /// level (used to compute per-printer connection status).
  final RxnString connectedMac = RxnString();

  // ---------------------------------------------------------------------------
  // New reactive state (additive, non-breaking)
  // ---------------------------------------------------------------------------

  /// Whether the user permanently denied one of the BT permissions. When
  /// true the UI should guide them to the system settings app.
  final RxBool permissionPermanentlyDenied = false.obs;

  /// Coarse-grained controller status surfaced by [status].
  final Rx<PrinterUiStatus> _status = Rx<PrinterUiStatus>(
    PrinterUiStatus.disconnected,
  );

  /// Aggregate controller status. Updated whenever any underlying field
  /// changes so the UI can react to the overall state of the subsystem.
  PrinterUiStatus get status => _status.value;

  // ---------------------------------------------------------------------------
  // Internal dedup / race-condition guards
  // ---------------------------------------------------------------------------

  bool _scanningInFlight = false;
  bool _connectingInFlight = false;
  bool _printingInFlight = false;
  DateTime _lastPrintAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastScanAt = DateTime.fromMillisecondsSinceEpoch(0);

  // ---------------------------------------------------------------------------
  // BT adapter tracking - polling + lifecycle + cached state.
  // `print_bluetooth_thermal` does not expose a broadcast for adapter
  // state changes. We compensate by polling every 3 s and re-sampling
  // whenever the app comes back to the foreground.
  // ---------------------------------------------------------------------------
  Timer? _adapterPollTimer;
  VoidCallback? _adapterNotifListener;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void onInit() {
    super.onInit();
    _loadFromStorage();
    _recomputeStatus();
    _wireBluetoothAdapterTracking();
  }

  @override
  void onClose() {
    _adapterPollTimer?.cancel();
    _adapterPollTimer = null;
    if (_adapterNotifListener != null) {
      PrinterService.adapterStateNotifier.removeListener(
        _adapterNotifListener!,
      );
      _adapterNotifListener = null;
    }
    // `AppLifecycleListener` auto-disposes through `WidgetsBindingObserver`
    // on newer Flutter SDKs, so an explicit manual tear-down is not needed.
    super.onClose();
  }

  /// Wires the periodic adapter poll, the cached-state notifier and the
  /// app-lifecycle observer.
  void _wireBluetoothAdapterTracking() {
    // 1) Notifier listener - react to external state updates.
    _adapterNotifListener = () {
      final bool? cached = PrinterService.adapterStateNotifier.value;
      if (cached == null || cached == bluetoothEnabled.value) {
        return;
      }
      _applyAdapterState(cached);
    };
    PrinterService.adapterStateNotifier.addListener(_adapterNotifListener!);

    // 2) App-lifecycle observer - refresh when returning from Settings.
    //    Kept alive for the controller's lifetime; the framework disposes
    //    it automatically when the app shuts down.
    AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.resumed) {
          PrinterLogger.d(_tag, 'App resumed -> re-sampling BT state');
          _sampleAdapterState();
        }
      },
    );

    // 3) Periodic poll every 3 s. The poll always re-probes because the
    //    TTL on the cached value matches this cadence (see
    //    [PrinterService.isBluetoothEnabled]).
    _adapterPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _sampleAdapterState(),
    );
  }

  /// Forcefully re-probes the Bluetooth adapter state.
  Future<void> _sampleAdapterState() async {
    try {
      final bool value = await printerRepository.isBluetoothEnabled();
      PrinterService.markAdapterEnabled(value);
      _applyAdapterState(value);
    } catch (e, st) {
      PrinterLogger.w(_tag, '_sampleAdapterState threw', e, st);
    }
  }

  /// Updates the reactive bluetoothEnabled flag and triggers aggregate
  /// status recompute when state actually changes. Also kicks off an
  /// auto-reconnect when the adapter was off and is now on.
  void _applyAdapterState(bool value) {
    if (bluetoothEnabled.value == value) {
      return;
    }
    PrinterLogger.i(
      _tag,
      'BT adapter transition: ${bluetoothEnabled.value} -> $value',
    );
    bluetoothEnabled.value = value;
    _recomputeStatus();
    if (value && defaultPrinter.value != null) {
      PrinterLogger.i(
        _tag,
        'BT restored - silent auto-reconnect to ${defaultPrinter.value!.address}',
      );
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        reconnectDefaultPrinter(silent: true);
      });
    } else if (!value) {
      connectedMac.value = null;
      _syncPrinterConnectionFlags();
    }
  }

  /// Public hook so screens can force-refresh (e.g. after returning from
  /// system Settings).
  Future<void> refreshAdapterNow() => _sampleAdapterState();

  /// Opens the system Bluetooth settings page so the user can toggle the
  /// adapter. Falls back to app settings if the platform can't deep-link.
  Future<void> openBluetoothSettings() async {
    try {
      // `permission_handler` does not expose a Bluetooth-specific deep
      // link on Android, so we open app settings which always lists the
      // "Bluetooth" entry under "Connected devices".
      await openAppSettings();
      PrinterLogger.i(_tag, 'Opened app settings (Bluetooth page)');
    } catch (e, st) {
      PrinterLogger.w(_tag, 'openBluetoothSettings threw', e, st);
    }
  }

  /// Loads printers from SharedPreferences. Does not touch Bluetooth.
  void _loadFromStorage() {
    final List<PrinterModel> saved = printerRepository.getSavedPrinters();
    printers.assignAll(saved);
    defaultPrinter.value = printerRepository.getDefaultPrinter();
  }

  /// Initial bootstrap called from `main.dart` once the app is ready.
  Future<void> initialize() async {
    PrinterLogger.i(_tag, 'initialize()');
    await refreshStatus();
    try {
      await requestPermissions();
    } catch (e, st) {
      PrinterLogger.w(_tag, 'requestPermissions during init failed', e);
      debugPrintStack(stackTrace: st);
    }
    // Only attempt to auto-connect if a default printer is configured.
    final PrinterModel? def = defaultPrinter.value;
    if (def != null) {
      await reconnectDefaultPrinter(silent: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Asks the user for the runtime permissions required to use Bluetooth
  /// printers. On Android 12+ this includes BLUETOOTH_SCAN and
  /// BLUETOOTH_CONNECT, while on older versions ACCESS_FINE_LOCATION is
  /// required for Bluetooth scanning.
  Future<bool> requestPermissions() async {
    try {
      final List<Permission> needed = <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.locationWhenInUse,
        Permission.location,
      ];
      final Map<Permission, PermissionStatus> statuses = await needed.request();
      final bool granted = statuses.values.any(
        (PermissionStatus s) =>
            s == PermissionStatus.granted ||
            s == PermissionStatus.limited ||
            s == PermissionStatus.provisional,
      );
      final bool anyPermanentlyDenied = statuses.values.any(
        (PermissionStatus s) => s == PermissionStatus.permanentlyDenied,
      );
      permissionsGranted.value = granted;
      permissionPermanentlyDenied.value = anyPermanentlyDenied;
      PrinterLogger.i(
        _tag,
        'requestPermissions -> granted=$granted permanentlyDenied=$anyPermanentlyDenied',
      );
      _recomputeStatus();
      return granted;
    } catch (e, st) {
      PrinterLogger.e(_tag, 'requestPermissions threw', e);
      debugPrintStack(stackTrace: st);
      permissionsGranted.value = false;
      _recomputeStatus();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Bluetooth validation
  // ---------------------------------------------------------------------------

  /// Returns true only when the printer subsystem is fully ready to use.
  ///
  /// This performs a full check of:
  ///   1. Bluetooth adapter is enabled.
  ///   2. At least one of the relevant runtime permissions is granted.
  ///   3. The user did not permanently deny the permissions.
  Future<BluetoothValidationResult> validateBluetooth() async {
    PrinterLogger.i(_tag, 'validateBluetooth()');
    // Permissions first — if the user has never granted them we want to
    // request them transparently before declaring failure.
    if (!permissionsGranted.value) {
      final bool granted = await requestPermissions();
      if (!granted) {
        // Either permanently denied or just rejected. Distinguish them so
        // the UI can guide the user to system settings.
        if (permissionPermanentlyDenied.value) {
          return BluetoothValidationResult.fail(
            BluetoothValidationFailure.permissionPermanentlyDenied,
            'permission_permanently_denied'.tr,
          );
        }
        return BluetoothValidationResult.fail(
          BluetoothValidationFailure.permissionDenied,
          'bluetooth_permission_required'.tr,
        );
      }
    }
    bluetoothEnabled.value = await printerRepository.isBluetoothEnabled();
    if (!bluetoothEnabled.value) {
      // `.tr` is an extension method, so it cannot live inside a `const`
      // expression — we have to drop the `const` for this branch only.
      return BluetoothValidationResult.fail(
        BluetoothValidationFailure.bluetoothOff,
        'bluetooth_is_disabled'.tr,
      );
    }
    PrinterLogger.i(_tag, 'validateBluetooth -> OK');
    return const BluetoothValidationResult.ok();
  }

  // ---------------------------------------------------------------------------
  // Status refresh
  // ---------------------------------------------------------------------------

  /// Refreshes [bluetoothEnabled] and the connection status of every
  /// printer currently in [printers].
  /// **Fix #2 (paired-but-plugin-disconnected):** the previous
  /// implementation forced `connectedMac.value = null` whenever the
  /// plugin's `connectionStatus` returned false, even though Android
  /// often already has a healthy Bluetooth socket to the default
  /// printer — the plugin just lost track of it after a reboot,
  /// Bluetooth toggle, or simply because the user opened the app
  /// without first opening the Printer screen. This produced the
  /// "red Disconnected" badge while the receipt was actually printable.
  ///
  /// The new path: when the plugin says "disconnected" but Bluetooth is
  /// on **and** the default printer appears in the OS-level paired
  /// list, we issue a real `connect(...)` call to resynchronise the
  /// plugin's internal state, then update `connectedMac.value` based on
  /// the actual outcome. Only when no such reconciliation is possible
  /// do we fall back to `null`.
  Future<void> refreshStatus() async {
    PrinterLogger.d(_tag, 'refreshStatus()');
    bluetoothEnabled.value = await printerRepository.isBluetoothEnabled();
    final bool connected = await printerRepository.isConnected();
    if (connected) {
      final PrinterModel? def = defaultPrinter.value;
      if (def != null) {
        connectedMac.value = def.address;
      } else {
        connectedMac.value = printerRepository.getLastConnectedAddress();
      }
    } else if (bluetoothEnabled.value && defaultPrinter.value != null) {
      // Plugin says disconnected but BT is on and we have a saved
      // default — try to reconcile against the OS-level paired list.
      final PrinterModel def = defaultPrinter.value!;
      try {
        final List<PrinterModel> paired =
            await printerRepository.scanPairedPrinters();
        final bool isPairedOnSystem = paired.any(
          (PrinterModel p) =>
              p.address.toUpperCase() == def.address.toUpperCase(),
        );
        if (isPairedOnSystem) {
          PrinterLogger.i(
            _tag,
            'plugin disconnected but printer is paired on system — '
            're-establishing connection to ${def.address}',
          );
          final bool reconnected =
              await printerRepository.connect(def.address);
          connectedMac.value = reconnected ? def.address : null;
        } else {
          PrinterLogger.d(
            _tag,
            'plugin disconnected and printer not in paired list — '
            'leaving connectedMac=null',
          );
          connectedMac.value = null;
        }
      } catch (e, st) {
        PrinterLogger.w(_tag, 'paired-list reconciliation threw', e, st);
        connectedMac.value = null;
      }
    } else {
      connectedMac.value = null;
    }
    _syncPrinterConnectionFlags();
    _recomputeStatus();
  }

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  /// Scans the OS-level paired Bluetooth devices and merges them with the
  /// printers already known to the app.
  ///
  /// The method is **idempotent within 500 ms**: calling it twice in quick
  /// succession is a no-op. This prevents double-scan races when the user
  /// double-taps the scan button.
  Future<void> scanPrinters() async {
    if (_scanningInFlight) {
      PrinterLogger.d(_tag, 'scanPrinters skipped — already in flight');
      return;
    }
    if (scanning.value) {
      PrinterLogger.d(_tag, 'scanPrinters skipped — scanning flag is true');
      return;
    }
    final DateTime now = DateTime.now();
    if (now.difference(_lastScanAt) < const Duration(milliseconds: 500)) {
      PrinterLogger.d(_tag, 'scanPrinters skipped — debounced');
      return;
    }
    _scanningInFlight = true;
    scanning.value = true;
    _recomputeStatus();
    try {
      _lastScanAt = now;
      PrinterLogger.i(_tag, 'scanPrinters: validating…');
      final BluetoothValidationResult validation = await validateBluetooth();
      if (!validation.isReady) {
        final String reason = validation.reason ?? 'bluetooth_unavailable'.tr;
        PrinterLogger.w(_tag, 'scan aborted: $reason');
        if (validation.failure != BluetoothValidationFailure.permissionDenied &&
            validation.failure !=
                BluetoothValidationFailure.permissionPermanentlyDenied) {
          // Don't spam the user with a SnackBar for permissions — they
          // just saw the system dialog.
          _safeShowSnack(reason, isError: true);
        }
        return;
      }
      PrinterLogger.i(_tag, 'scanPrinters: fetching paired list');
      final List<PrinterModel> rawPaired = await printerRepository
          .scanPairedPrinters();
      // We dedupe by MAC address (case-insensitive), merge with already
      // known printers (preserving the user's settings) and sort.
      final List<PrinterModel> merged = _dedupeAndMerge(rawPaired);
      final List<PrinterModel> sorted = _sortForDisplay(merged);
      printers.assignAll(sorted);
      await printerRepository.savePrinters(printers.toList());
      PrinterLogger.i(
        _tag,
        'scanPrinters: merged list has ${printers.length} printers',
      );
      await refreshStatus();
    } catch (e, st) {
      PrinterLogger.e(_tag, 'scanPrinters failed', e);
      debugPrintStack(stackTrace: st);
      _safeShowSnack('scan_failed'.tr, isError: true);
    } finally {
      scanning.value = false;
      _scanningInFlight = false;
      _recomputeStatus();
    }
  }

  /// Deduplicate incoming devices by MAC (case-insensitive) while keeping
  /// the user-configured fields (`isDefault`, `paper size`, counters) of
  /// previously known printers.
  List<PrinterModel> _dedupeAndMerge(List<PrinterModel> incoming) {
    final Map<String, PrinterModel> byMac = <String, PrinterModel>{};
    for (final PrinterModel p in printers) {
      byMac[p.address.toUpperCase()] = p;
    }
    for (final PrinterModel p in incoming) {
      final String key = p.address.toUpperCase();
      if (byMac.containsKey(key)) {
        final PrinterModel existing = byMac[key]!;
        byMac[key] = existing.copyWith(name: p.name);
      } else {
        byMac[key] = p;
      }
    }
    return byMac.values.toList();
  }

  /// Sort printers for display: connected first, then default, then by
  /// name alphabetically.
  List<PrinterModel> _sortForDisplay(List<PrinterModel> list) {
    final List<PrinterModel> copy = List<PrinterModel>.from(list);
    copy.sort((PrinterModel a, PrinterModel b) {
      if (a.isConnected != b.isConnected) {
        return a.isConnected ? -1 : 1;
      }
      if (a.isDefault != b.isDefault) {
        return a.isDefault ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return copy;
  }

  // ---------------------------------------------------------------------------
  // Manual entry
  // ---------------------------------------------------------------------------

  /// Adds a printer manually by MAC address. Useful for devices that are
  /// already paired at the OS level but didn't show up in [scanPrinters].
  Future<PrinterModel?> addPrinterManually({
    required String mac,
    String? name,
    String paperSize = PrinterHelper.defaultPaperSize,
  }) async {
    final String trimmed = mac.trim();
    if (trimmed.isEmpty) {
      _safeShowSnack('mac_address_required'.tr, isError: true);
      return null;
    }
    if (!_looksLikeMac(trimmed)) {
      _safeShowSnack('invalid_mac_address'.tr, isError: true);
      return null;
    }
    final BluetoothValidationResult validation = await validateBluetooth();
    if (!validation.isReady) {
      _safeShowSnack(
        validation.reason ?? 'bluetooth_permission_required'.tr,
        isError: true,
      );
      return null;
    }
    final PrinterModel printer = PrinterModel(
      name: (name == null || name.trim().isEmpty)
          ? 'Printer ${trimmed.substring(trimmed.length - 5)}'
          : name.trim(),
      address: trimmed.toUpperCase(),
      printerType: paperSize,
    );
    _upsertPrinter(printer);
    await _persistCurrentPrinters();
    PrinterLogger.i(
      _tag,
      'Added printer manually: ${printer.name} (${printer.address})',
    );
    _safeShowSnack('printer_added'.tr, isError: false);
    return printer;
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  /// Removes a printer from the saved list. If it was the default printer,
  /// the next printer (if any) becomes the default.
  Future<void> removePrinter(PrinterModel printer) async {
    PrinterLogger.i(_tag, 'removePrinter: ${printer.address}');
    final bool wasDefault =
        printer.isDefault || (defaultPrinter.value?.address == printer.address);
    final List<PrinterModel> updated = printers
        .where((PrinterModel p) => p.address != printer.address)
        .toList();
    printers.assignAll(updated);
    await printerRepository.savePrinters(updated);

    if (wasDefault) {
      if (updated.isNotEmpty) {
        await setDefaultPrinter(updated.first);
      } else {
        defaultPrinter.value = null;
        await printerRepository.clearDefaultPrinter();
      }
      if (connectedMac.value == printer.address) {
        await disconnectPrinter();
      }
    }
    _safeShowSnack('printer_removed'.tr, isError: false);
    _recomputeStatus();
  }

  /// Connects to [printer]. Saves the printer locally (if new), updates the
  /// last-connected timestamp and persists the connection.
  Future<bool> connectPrinter(PrinterModel printer) async {
    if (_connectingInFlight || connecting.value) {
      PrinterLogger.d(_tag, 'connectPrinter skipped — already in flight');
      return false;
    }
    _connectingInFlight = true;
    connecting.value = true;
    _recomputeStatus();
    try {
      PrinterLogger.i(_tag, 'connectPrinter: validating ${printer.address}');
      final BluetoothValidationResult validation = await validateBluetooth();
      if (!validation.isReady) {
        _safeShowSnack(
          validation.reason ?? 'bluetooth_unavailable'.tr,
          isError: true,
        );
        return false;
      }
      final bool result = await printerRepository.connect(printer.address);
      if (result) {
        connectedMac.value = printer.address;
        // Preserve the isDefault flag of the existing entry (if any) so a
        // auto-reconnect triggered by setDefaultPrinter does not flip the
        // isDefault back to false.
        final PrinterModel existing = printers.firstWhere(
          (PrinterModel p) => p.address == printer.address,
          orElse: () => printer,
        );
        final PrinterModel updated = existing.copyWith(
          isConnected: true,
          lastConnected: DateTime.now().toIso8601String(),
          connectionCount: existing.connectionCount + 1,
        );
        _upsertPrinter(updated);
        await printerRepository.setLastConnectedAddress(printer.address);
        await printerRepository.incrementConnectionCount(printer.address);
        await _persistCurrentPrinters();
        PrinterLogger.i(
          _tag,
          'connectPrinter: connected to ${printer.address}',
        );
        _safeShowSnack('connected_successfully'.tr, isError: false);
        _syncPrinterConnectionFlags();
        _recomputeStatus();
        return true;
      } else {
        PrinterLogger.w(_tag, 'connectPrinter: connection refused by plugin');
        _safeShowSnack('connection_failed'.tr, isError: true);
        return false;
      }
    } catch (e, st) {
      PrinterLogger.e(_tag, 'connectPrinter threw', e);
      debugPrintStack(stackTrace: st);
      _safeShowSnack('connection_failed'.tr, isError: true);
      return false;
    } finally {
      connecting.value = false;
      _connectingInFlight = false;
      _recomputeStatus();
    }
  }

  /// Disconnects the currently connected printer (if any).
  Future<bool> disconnectPrinter() async {
    if (_connectingInFlight) {
      return false;
    }
    _connectingInFlight = true;
    connecting.value = true;
    _recomputeStatus();
    try {
      final bool result = await printerRepository.disconnect();
      if (result) {
        connectedMac.value = null;
        _syncPrinterConnectionFlags();
        PrinterLogger.i(_tag, 'disconnectPrinter: disconnected');
        _safeShowSnack('disconnected_successfully'.tr, isError: false);
      } else {
        PrinterLogger.w(_tag, 'disconnectPrinter: plugin reported failure');
        _safeShowSnack('disconnect_failed'.tr, isError: true);
      }
      _recomputeStatus();
      return result;
    } catch (e, st) {
      PrinterLogger.e(_tag, 'disconnectPrinter threw', e);
      debugPrintStack(stackTrace: st);
      _safeShowSnack('disconnect_failed'.tr, isError: true);
      return false;
    } finally {
      connecting.value = false;
      _connectingInFlight = false;
      _recomputeStatus();
    }
  }

  /// Marks [printer] as the default printer. Removes the default flag from
  /// every other printer so that only one printer is default at any time.
  /// Triggers an automatic reconnection.
  Future<void> setDefaultPrinter(PrinterModel printer) async {
    if (printers.isEmpty) {
      return;
    }
    PrinterLogger.i(_tag, 'setDefaultPrinter: ${printer.address}');
    final List<PrinterModel> updated = printers.map((PrinterModel p) {
      return p.copyWith(isDefault: p.address == printer.address);
    }).toList();
    printers.assignAll(updated);
    defaultPrinter.value = printer.copyWith(isDefault: true);
    await printerRepository.setDefaultPrinter(defaultPrinter.value!);
    _safeShowSnack('default_printer_updated'.tr, isError: false);
    _recomputeStatus();
    // Auto-reconnect per spec.
    await connectPrinter(printer);
  }

  /// Updates the [paperSize] ('58mm' or '80mm') for [printer].
  Future<void> setPrinterPaperSize(
    PrinterModel printer,
    String paperSize,
  ) async {
    PrinterLogger.d(
      _tag,
      'setPrinterPaperSize: ${printer.address} -> $paperSize',
    );
    final List<PrinterModel> updated = printers.map((PrinterModel p) {
      if (p.address == printer.address) {
        return p.copyWith(printerType: paperSize);
      }
      return p;
    }).toList();
    printers.assignAll(updated);
    final PrinterModel? def = defaultPrinter.value;
    if (def != null && def.address == printer.address) {
      defaultPrinter.value = def.copyWith(printerType: paperSize);
    }
    await _persistCurrentPrinters();
  }

  // ---------------------------------------------------------------------------
  // Reconnect with retry
  // ---------------------------------------------------------------------------

  /// Attempts to reconnect to the default printer, retrying on failure.
  ///
  /// Returns `true` if the connection is eventually established, `false`
  /// otherwise.
  Future<bool> reconnectDefaultPrinter({bool silent = false}) async {
    final PrinterModel? def = defaultPrinter.value;
    if (def == null) {
      PrinterLogger.d(_tag, 'reconnectDefaultPrinter: no default printer');
      return false;
    }
    // Already connected? Nothing to do.
    final bool alreadyConnected = await printerRepository.isConnected();
    if (alreadyConnected) {
      connectedMac.value = def.address;
      _syncPrinterConnectionFlags();
      PrinterLogger.d(
        _tag,
        'reconnectDefaultPrinter: already connected to ${def.address}',
      );
      _recomputeStatus();
      return true;
    }

    PrinterLogger.i(_tag, 'reconnectDefaultPrinter: starting retries');
    Duration delay = initialReconnectDelay;
    for (int attempt = 1; attempt <= maxReconnectAttempts; attempt++) {
      final bool ok = await _attemptReconnect(def, attempt);
      if (ok) {
        PrinterLogger.i(
          _tag,
          'reconnectDefaultPrinter: succeeded on attempt $attempt',
        );
        if (!silent) {
          _safeShowSnack('connected_successfully'.tr, isError: false);
        }
        _recomputeStatus();
        return true;
      }
      if (attempt < maxReconnectAttempts) {
        PrinterLogger.w(
          _tag,
          'reconnect attempt $attempt failed — retrying in ${delay.inMilliseconds}ms',
        );
        await Future<void>.delayed(delay);
        delay *= 2;
      }
    }
    PrinterLogger.w(_tag, 'reconnectDefaultPrinter: all attempts failed');
    if (!silent) {
      _safeShowSnack('reconnect_failed'.tr, isError: true);
    }
    _recomputeStatus();
    return false;
  }

  Future<bool> _attemptReconnect(PrinterModel def, int attempt) async {
    try {
      final BluetoothValidationResult validation = await validateBluetooth();
      if (!validation.isReady) {
        PrinterLogger.w(_tag, 'reconnect attempt $attempt: validation failed');
        return false;
      }
      final bool ok = await printerRepository.connect(def.address);
      if (ok) {
        connectedMac.value = def.address;
        _syncPrinterConnectionFlags();
        await printerRepository.setLastConnectedAddress(def.address);
        await printerRepository.incrementConnectionCount(def.address);
        // Preserve the isDefault flag from the existing entry.
        final PrinterModel existing = printers.firstWhere(
          (PrinterModel p) => p.address == def.address,
          orElse: () => def,
        );
        final PrinterModel updated = existing.copyWith(
          isConnected: true,
          lastConnected: DateTime.now().toIso8601String(),
          connectionCount: existing.connectionCount + 1,
        );
        _upsertPrinter(updated);
        await _persistCurrentPrinters();
        return true;
      }
      return false;
    } catch (e, st) {
      PrinterLogger.e(_tag, 'reconnect attempt $attempt threw', e);
      debugPrintStack(stackTrace: st);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  /// Persists the supplied printers list to SharedPreferences.
  Future<void> savePrinter(List<PrinterModel> printersToSave) async {
    await printerRepository.savePrinters(printersToSave);
    printers.assignAll(printersToSave);
  }

  /// Public wrapper used by the UI to persist the current [printers] list.
  Future<void> loadSavedPrinter() async {
    _loadFromStorage();
    await refreshStatus();
  }

  // ---------------------------------------------------------------------------
  // Printing
  // ---------------------------------------------------------------------------

  /// Prints the test receipt on the supplied printer.
  ///
  /// The cut command is appended inside the ticket bytes by
  /// [PrinterHelper.buildTestReceiptBytes] so the printer tears off the
  /// paper automatically as soon as the write completes.
  Future<bool> printTest({PrinterModel? printer}) async {
    final PrinterModel? target = printer ?? defaultPrinter.value;
    if (target == null) {
      _safeShowSnack('no_default_printer'.tr, isError: true);
      return false;
    }
    return _printWithTicket(
      target,
      (PrinterModel p) => PrinterHelper.buildTestReceiptBytes(printer: p),
    );
  }

  /// Prints an arbitrary invoice for [printer].
  Future<bool> printInvoiceForPrinter(
    PrinterModel printer, {
    required Future<List<int>> Function(PrinterModel printer) ticketBuilder,
  }) {
    return _printWithTicket(printer, ticketBuilder);
  }

  /// High-level helper used by the order/invoice flow.
  Future<bool> printInvoice({
    required Future<List<int>> Function(PrinterModel printer) ticketBuilder,
  }) async {
    final PrinterModel? def = defaultPrinter.value;
    if (def == null) {
      _safeShowSnack('no_default_printer'.tr, isError: true);
      return false;
    }
    return _printWithTicket(def, ticketBuilder);
  }

  /// The core print path. Validates Bluetooth, ensures a healthy
  /// connection, builds the ticket and writes it with up to
  /// [maxWriteAttempts] retries.
  ///
  /// **Why the retry loop:** Star TSP100 / Xprinter XP-series and similar
  /// mobile receipt printers keep their Bluetooth socket open even when
  /// the printer itself is offline or sleeping. The plugin reports
  /// `connectionStatus == true` but every subsequent `writeBytes` returns
  /// `false`. Forcing a disconnect+reconnect before each attempt reliably
  /// recovers from this state.
  ///
  /// **Paper cut:** every ticket built by [PrinterHelper.buildImageBytes]
  /// and [PrinterHelper.buildTestReceiptBytes] already terminates with the
  /// ESC/POS cut sequence (`GS V 0`), so the receipt is automatically
  /// torn off the roll when the write succeeds. The cut fires **exactly
  /// once** per print — no additional cut calls are made here so the
  /// printer does not double-cut.
  Future<bool> _printWithTicket(
    PrinterModel printer,
    Future<List<int>> Function(PrinterModel) ticketBuilder,
  ) async {
    if (_printingInFlight || printing.value) {
      PrinterLogger.d(_tag, 'print skipped — already in flight');
      return false;
    }
    final DateTime now = DateTime.now();
    if (now.difference(_lastPrintAt) < printCooldown) {
      PrinterLogger.d(_tag, 'print skipped — cooldown active');
      return false;
    }
    _printingInFlight = true;
    printing.value = true;
    _recomputeStatus();
    try {
      _lastPrintAt = now;
      PrinterLogger.i(_tag, 'print: validating for ${printer.address}');
      final BluetoothValidationResult validation = await validateBluetooth();
      if (!validation.isReady) {
        if (validation.failure == BluetoothValidationFailure.bluetoothOff) {
          _showBluetoothOffCta();
        } else {
          _safeShowSnack(
            validation.reason ?? 'bluetooth_unavailable'.tr,
            isError: true,
          );
        }
        return false;
      }
      final List<int> ticket = await ticketBuilder(printer);
      if (ticket.isEmpty) {
        PrinterLogger.w(_tag, 'print: ticket builder returned empty bytes');
        _safeShowSnack('print_failed'.tr, isError: true);
        return false;
      }

      // Retry loop: each iteration force-reconnects to the printer and
      // tries to write the ticket once.
      for (int attempt = 1; attempt <= maxWriteAttempts; attempt++) {
        PrinterLogger.i(_tag, 'print: attempt $attempt/$maxWriteAttempts');
        final bool prepared = await _ensureConnectionForPrint(printer);
        if (!prepared) {
          if (attempt >= maxWriteAttempts) {
            PrinterLogger.w(
              _tag,
              'print: could not establish a healthy connection after '
              '$maxWriteAttempts attempts',
            );
            _safeShowSnack('print_failed'.tr, isError: true);
            return false;
          }
          continue;
        }
        PrinterLogger.i(
          _tag,
          'print: sending ${ticket.length} bytes to ${printer.address}',
        );
        final bool sent = await printerRepository.service.writeBytes(ticket);
        if (sent) {
          await printerRepository.recordPrintSuccess(printer.address);
          _safeShowSnack('print_succeeded'.tr, isError: false);
          PrinterLogger.i(_tag, 'print: success on attempt $attempt');
          _recomputeStatus();
          return true;
        }
        PrinterLogger.w(
          _tag,
          'print: writeBytes returned false on attempt $attempt',
        );
        // Drop the stale socket before the next iteration so the next
        // reconnect starts from a clean slate.
        try {
          await printerRepository.disconnect();
        } catch (e, st) {
          PrinterLogger.w(_tag, 'inter-attempt disconnect threw', e);
          debugPrintStack(stackTrace: st);
        }
      }

      _safeShowSnack('print_failed'.tr, isError: true);
      PrinterLogger.w(
        _tag,
        'print: exhausted $maxWriteAttempts attempts without success',
      );
      _recomputeStatus();
      return false;
    } catch (e, st) {
      PrinterLogger.e(_tag, 'print threw', e);
      debugPrintStack(stackTrace: st);
      _safeShowSnack('print_failed'.tr, isError: true);
      _recomputeStatus();
      return false;
    } finally {
      printing.value = false;
      _printingInFlight = false;
    }
  }

  /// Ensures the printer is in a state where the next [writeBytes] call
  /// is likely to succeed. Returns `true` when the printer is connected and
  /// `connectedMac.value` matches [printer.address].
  ///
  /// Strategy:
  ///   1. If the OS already reports an active connection AND our cached
  ///      [connectedMac] matches, trust the plugin — no extra round trip.
  ///   2. Otherwise force a disconnect + reconnect. Many printers
  ///      (especially the TSP100 family) report "connected" for stale
  ///      sockets; reconnecting guarantees a fresh socket.
  Future<bool> _ensureConnectionForPrint(PrinterModel printer) async {
    final bool connected = await printerRepository.isConnected();
    if (connected && connectedMac.value == printer.address) {
      PrinterLogger.d(
        _tag,
        '_ensureConnectionForPrint: trusting existing connection',
      );
      return true;
    }
    PrinterLogger.i(
      _tag,
      '_ensureConnectionForPrint: forcing reconnect (was '
      'connected=$connected, mac=${connectedMac.value})',
    );
    // Drop any stale socket before opening a fresh one.
    try {
      await printerRepository.disconnect();
    } catch (e, st) {
      PrinterLogger.w(_tag, 'pre-print disconnect threw', e);
      debugPrintStack(stackTrace: st);
    }
    final bool reconnected = await connectPrinter(printer);
    if (!reconnected) {
      PrinterLogger.w(
        _tag,
        '_ensureConnectionForPrint: reconnect failed for ${printer.address}',
      );
      return false;
    }
    return connectedMac.value == printer.address;
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  /// Runs a comprehensive diagnostics pass and returns a structured report
  /// suitable for display in a dedicated screen.
  Future<PrinterDiagnosticsReport> runDiagnostics() async {
    PrinterLogger.i(_tag, 'runDiagnostics()');
    final List<String> issues = <String>[];
    final List<String> recommendations = <String>[];

    final bool btOn = await printerRepository.isBluetoothEnabled();
    final bool perms = permissionsGranted.value;
    final bool permDenied = permissionPermanentlyDenied.value;
    final List<PrinterModel> saved = printerRepository.getSavedPrinters();
    final PrinterModel? def = printerRepository.getDefaultPrinter();
    final bool conn = await printerRepository.isConnected();

    if (!btOn) {
      issues.add('diagnostic_bt_off'.tr);
      recommendations.add('diagnostic_recommendation_enable_bt'.tr);
    }
    if (!perms) {
      issues.add('diagnostic_perm_missing'.tr);
      if (permDenied) {
        recommendations.add('diagnostic_recommendation_open_settings'.tr);
      } else {
        recommendations.add('diagnostic_recommendation_grant_perms'.tr);
      }
    }
    if (saved.isEmpty) {
      issues.add('diagnostic_no_printers'.tr);
      recommendations.add('diagnostic_recommendation_pair_printer'.tr);
    }
    if (saved.isNotEmpty && def == null) {
      issues.add('diagnostic_no_default'.tr);
      recommendations.add('diagnostic_recommendation_set_default'.tr);
    }
    if (def != null && !conn) {
      issues.add('diagnostic_default_disconnected'.tr);
      recommendations.add('diagnostic_recommendation_reconnect'.tr);
    }
    return PrinterDiagnosticsReport(
      bluetoothSupported: true,
      bluetoothEnabled: btOn,
      permissionsGranted: perms,
      anyPermissionPermanentlyDenied: permDenied,
      savedPrinterCount: saved.length,
      hasDefaultPrinter: def != null,
      connectedToDefaultPrinter:
          def != null && connectedMac.value == def.address && conn,
      defaultPrinterMac: def?.address,
      defaultPrinterName: def?.name,
      lastConnectedMac: printerRepository.getLastConnectedAddress(),
      connectionAttemptsLast: maxReconnectAttempts,
      issues: issues,
      recommendations: recommendations,
    );
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  /// Returns the visual status for [printer]. This is the **per-printer**
  /// status used by the card UI.
  PrinterUiStatus getUiStatus(PrinterModel printer) {
    if (!permissionsGranted.value) {
      return permissionPermanentlyDenied.value
          ? PrinterUiStatus.permissionDenied
          : PrinterUiStatus.permissionDenied;
    }
    if (!bluetoothEnabled.value) {
      return PrinterUiStatus.bluetoothOff;
    }
    if (scanning.value) {
      return PrinterUiStatus.scanning;
    }
    if (connecting.value && connectedMac.value == printer.address) {
      return PrinterUiStatus.connecting;
    }
    if (connectedMac.value == printer.address) {
      return PrinterUiStatus.connected;
    }
    return PrinterUiStatus.disconnected;
  }

  /// Returns the default printer if any, otherwise null.
  PrinterModel? getDefault() => defaultPrinter.value;

  /// Used by the legacy invoice print screen to expose the connected
  /// printer's MAC address.
  String? getConnectedMac() => connectedMac.value;

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _upsertPrinter(PrinterModel printer) {
    final List<PrinterModel> updated = <PrinterModel>[];
    bool found = false;
    for (final PrinterModel p in printers) {
      if (p.address == printer.address) {
        updated.add(printer);
        found = true;
      } else {
        updated.add(p);
      }
    }
    if (!found) {
      updated.add(printer);
    }
    printers.assignAll(_sortForDisplay(updated));
  }

  Future<void> _persistCurrentPrinters() async {
    await printerRepository.savePrinters(printers.toList());
  }

  void _syncPrinterConnectionFlags() {
    final String? mac = connectedMac.value;
    final List<PrinterModel> updated = printers.map((PrinterModel p) {
      return p.copyWith(isConnected: mac != null && p.address == mac);
    }).toList();
    printers.assignAll(updated);
  }

  /// Loose MAC address validator. Accepts "AA:BB:CC:DD:EE:FF" or
  /// "AA-BB-CC-DD-EE-FF" formats.
  bool _looksLikeMac(String value) {
    final RegExp re = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$');
    return re.hasMatch(value);
  }

  /// Recompute the aggregate [status] field whenever any of the underlying
  /// reactive variables change.
  void _recomputeStatus() {
    PrinterUiStatus next;
    if (!permissionsGranted.value || permissionPermanentlyDenied.value) {
      next = PrinterUiStatus.permissionDenied;
    } else if (printing.value) {
      next = PrinterUiStatus.printing;
    } else if (scanning.value) {
      next = PrinterUiStatus.scanning;
    } else if (connecting.value) {
      next = PrinterUiStatus.connecting;
    } else if (!bluetoothEnabled.value) {
      next = PrinterUiStatus.bluetoothOff;
    } else if (connectedMac.value != null) {
      next = PrinterUiStatus.connected;
    } else if (defaultPrinter.value != null) {
      next = PrinterUiStatus.disconnected;
    } else {
      next = PrinterUiStatus.ready;
    }
    if (_status.value != next) {
      _status.value = next;
    }
  }

  /// Show a clear CTA SnackBar when a print fails because Bluetooth is
  /// off. Lets the user know to turn Bluetooth on. (Tapping the snackbar
  /// does not currently deep-link to settings; the in-screen "Turn on
  /// Bluetooth" button remains the primary CTA.)
  void _showBluetoothOffCta() {
    if (Get.context == null || Get.overlayContext == null) {
      return;
    }
    try {
      showCustomSnackBar('bluetooth_is_disabled_cta'.tr, isError: true);
    } catch (e) {
      PrinterLogger.w(_tag, 'BT-off CTA SnackBar failed: $e');
    }
  }

  /// Show a SnackBar but swallow exceptions (including async ones) when no
  /// context is available (e.g. during app init or in tests).
  void _safeShowSnack(String message, {required bool isError}) {
    // Skip if there is no overlay available yet (very early in the
    // lifecycle, or running under `Get.testMode` in unit tests).
    if (Get.context == null || Get.overlayContext == null) {
      PrinterLogger.d(_tag, 'Skipping SnackBar (no overlay): $message');
      return;
    }
    try {
      showCustomSnackBar(message, isError: isError);
    } catch (e, st) {
      PrinterLogger.w(_tag, 'SnackBar failed: $message');
      debugPrintStack(stackTrace: st);
    }
  }
}
