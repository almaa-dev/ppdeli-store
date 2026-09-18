// Unit tests for the printer subsystem.
//
// These tests cover the critical paths of the printer feature and run
// without needing a real Bluetooth adapter or the print_bluetooth_thermal
// plugin (the service is mocked). Run with `flutter test`.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/features/printer/domain/models/printer_model.dart';
import 'package:ppdelistore/features/printer/domain/repositories/printer_repository_interface.dart';
import 'package:ppdelistore/features/printer/domain/services/printer_service.dart';
import 'package:ppdelistore/features/printer/domain/services/printer_service_interface.dart';
import 'package:ppdelistore/features/printer/helper/printer_helper.dart';
import 'package:ppdelistore/features/printer/presentation/printer_controller.dart';
import 'package:ppdelistore/util/printer_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeService implements PrinterServiceInterface {
  bool _connected = false;
  int writeCalls = 0;
  int cutCalls = 0;
  List<int>? lastBytes;
  List<int>? lastCutBytes;

  @override
  Future<bool> isBluetoothEnabled() async => true;

  @override
  Future<bool> isConnected() async => _connected;

  @override
  Future<List<PrinterModel>> getPairedPrinters() async =>
      const <PrinterModel>[];

  @override
  Future<bool> connect(String mac) async {
    _connected = true;
    return true;
  }

  @override
  Future<bool> disconnect() async {
    _connected = false;
    return true;
  }

  @override
  Future<bool> writeBytes(List<int> bytes) async {
    writeCalls++;
    lastBytes = bytes;
    return bytes.isNotEmpty;
  }

  @override
  Future<bool> paperCut() async {
    cutCalls++;
    lastCutBytes = PrinterHelper.buildPaperCutBytes();
    if (kDebugMode) {
      print(
        'paperCut invoked: last 5 bytes = '
        '${lastCutBytes!.sublist(lastCutBytes!.length - 5)}',
      );
    }
    return true;
  }

  void setConnected(bool v) => _connected = v;
}

class _FakeRepo implements PrinterRepositoryInterface {
  final List<PrinterModel> _saved;
  // Cache the service so the controller and the test see the same
  // instance — otherwise every call to `service` returns a fresh
  // _FakeService whose counters are never observed by the test.
  final _FakeService _service = _FakeService();
  PrinterModel? _default;
  String? _lastMac;
  bool _btEnabled = true;
  // ignore: unused_field
  bool _connected = false;
  bool connectResult = true;
  bool isBluetoothDisabled = false;

  _FakeRepo({List<PrinterModel>? saved})
    : _saved = List<PrinterModel>.from(saved ?? const <PrinterModel>[]) {
    for (final PrinterModel p in _saved) {
      if (p.isDefault) {
        _default = p;
        break;
      }
    }
  }

  @override
  PrinterServiceInterface get service => _service;

  @override
  List<PrinterModel> getSavedPrinters() => List<PrinterModel>.from(_saved);

  @override
  Future<void> savePrinters(List<PrinterModel> printers) async {
    _saved
      ..clear()
      ..addAll(printers);
  }

  @override
  PrinterModel? getDefaultPrinter() {
    if (_default == null) return null;
    for (final PrinterModel p in _saved) {
      if (p.address == _default!.address) return p;
    }
    return null;
  }

  @override
  Future<void> setDefaultPrinter(PrinterModel printer) async {
    _default = printer;
    for (int i = 0; i < _saved.length; i++) {
      _saved[i] = _saved[i].copyWith(
        isDefault: _saved[i].address == printer.address,
      );
    }
  }

  @override
  Future<void> clearDefaultPrinter() async {
    _default = null;
    for (int i = 0; i < _saved.length; i++) {
      _saved[i] = _saved[i].copyWith(isDefault: false);
    }
  }

  @override
  String? getLastConnectedAddress() => _lastMac;

  @override
  Future<void> setLastConnectedAddress(String mac) async {
    _lastMac = mac;
  }

  @override
  Future<bool> isBluetoothEnabled() async => !isBluetoothDisabled && _btEnabled;

  @override
  Future<bool> isConnected() async => _service._connected;

  @override
  Future<List<PrinterModel>> scanPairedPrinters() async =>
      List<PrinterModel>.from(_saved);

  @override
  Future<bool> connect(String mac) async {
    final bool exists = _saved.any((PrinterModel p) => p.address == mac);
    final bool v = connectResult && exists;
    _connected = v;
    _service.setConnected(v);
    return v;
  }

  @override
  Future<bool> disconnect() async {
    _connected = false;
    _service.setConnected(false);
    return true;
  }

  @override
  Future<void> incrementConnectionCount(String mac) async {
    for (int i = 0; i < _saved.length; i++) {
      if (_saved[i].address == mac) {
        _saved[i] = _saved[i].copyWith(
          connectionCount: _saved[i].connectionCount + 1,
        );
        break;
      }
    }
  }

  @override
  Future<void> recordPrintSuccess(String mac) async {
    final String ts = DateTime.now().toIso8601String();
    for (int i = 0; i < _saved.length; i++) {
      if (_saved[i].address == mac) {
        _saved[i] = _saved[i].copyWith(lastPrintSuccess: ts);
        break;
      }
    }
  }

  // Test helpers
  void setBluetooth(bool v) {
    isBluetoothDisabled = !v;
    _btEnabled = v;
  }

  void setConnected(bool v) {
    _connected = v;
    _service.setConnected(v);
  }

  void setConnectResult(bool v) => connectResult = v;
}

PrinterModel _mk(
  String name,
  String mac, {
  bool isDefault = false,
  int connectionCount = 0,
  String paperSize = '80mm',
  PrinterCapabilityProfile capabilityProfile = PrinterCapabilityProfile.auto,
}) => PrinterModel(
  name: name,
  address: mac,
  isDefault: isDefault,
  printerType: paperSize,
  connectionCount: connectionCount,
  capabilityProfile: capabilityProfile,
);

/// A service that lets us dictate whether writeBytes succeeds or fails on
/// each call so we can drive the retry loop deterministically.
class _CountingService implements PrinterServiceInterface {
  bool _connected = false;
  int writeCalls = 0;
  int cutCalls = 0;
  final List<bool> results;

  _CountingService(this.results);

  @override
  Future<bool> isBluetoothEnabled() async => true;

  @override
  Future<bool> isConnected() async => _connected;

  @override
  Future<List<PrinterModel>> getPairedPrinters() async =>
      const <PrinterModel>[];

  @override
  Future<bool> connect(String mac) async {
    _connected = true;
    return true;
  }

  @override
  Future<bool> disconnect() async {
    _connected = false;
    return true;
  }

  @override
  Future<bool> writeBytes(List<int> bytes) async {
    writeCalls++;
    if (writeCalls <= results.length) {
      return results[writeCalls - 1];
    }
    return true;
  }

  @override
  Future<bool> paperCut() async {
    cutCalls++;
    return true;
  }
}

/// A repository that exposes a counting service so the retry path in
/// `_printWithTicket` can be exercised.
class _CountingRepo implements PrinterRepositoryInterface {
  final _CountingService svc;
  final List<PrinterModel> _saved;
  PrinterModel? _default;
  String? _lastMac;

  _CountingRepo(this.svc, {List<PrinterModel>? saved})
    : _saved = List<PrinterModel>.from(saved ?? const <PrinterModel>[]) {
    for (final PrinterModel p in _saved) {
      if (p.isDefault) {
        _default = p;
        break;
      }
    }
  }

  @override
  PrinterServiceInterface get service => svc;

  @override
  List<PrinterModel> getSavedPrinters() => List<PrinterModel>.from(_saved);

  @override
  Future<void> savePrinters(List<PrinterModel> printers) async {}

  @override
  PrinterModel? getDefaultPrinter() => _default;

  @override
  Future<void> setDefaultPrinter(PrinterModel printer) async {
    _default = printer;
  }

  @override
  Future<void> clearDefaultPrinter() async {
    _default = null;
  }

  @override
  String? getLastConnectedAddress() => _lastMac;

  @override
  Future<void> setLastConnectedAddress(String mac) async {
    _lastMac = mac;
  }

  @override
  Future<bool> isBluetoothEnabled() async => true;

  @override
  Future<bool> isConnected() async => svc._connected;

  @override
  Future<List<PrinterModel>> scanPairedPrinters() async =>
      List<PrinterModel>.from(_saved);

  @override
  Future<bool> connect(String mac) async => svc.connect(mac);

  @override
  Future<bool> disconnect() async => svc.disconnect();

  @override
  Future<void> incrementConnectionCount(String mac) async {}

  @override
  Future<void> recordPrintSuccess(String mac) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PrinterLogger.clear();
    PrinterLogger.verbose = false;
    // Silence the SnackBar widget which needs a navigator.
    Get.testMode = true;
    // Reset the static BT adapter cache so tests do not leak state.
    PrinterService.invalidateAdapterCache();
  });

  tearDown(() {
    Get.reset();
    PrinterService.invalidateAdapterCache();
  });

  group('PrinterModel', () {
    test('encodes and decodes round-trip', () {
      final PrinterModel p = _mk('XP-58', '00:11:22:33:44:55', isDefault: true);
      final String encoded = p.encode();
      final PrinterModel decoded = PrinterModel.decode(encoded);
      expect(decoded.name, p.name);
      expect(decoded.address, p.address);
      expect(decoded.isDefault, isTrue);
      expect(decoded.printerType, '80mm');
      expect(decoded.capabilityProfile, PrinterCapabilityProfile.auto);
    });

    test('decode throws on empty input', () {
      expect(() => PrinterModel.decode(''), throwsA(isA<FormatException>()));
    });

    test('copyWith preserves fields not overridden', () {
      final PrinterModel p = _mk('A', 'AA:BB:CC:DD:EE:01');
      final PrinterModel p2 = p.copyWith(name: 'B');
      expect(p2.name, 'B');
      expect(p2.address, p.address);
    });

    test('copyWith increments connectionCount independently', () {
      final PrinterModel p = _mk('A', 'AA:BB:CC:DD:EE:01', connectionCount: 3);
      final PrinterModel p2 = p.copyWith(connectionCount: 4);
      expect(p.connectionCount, 3);
      expect(p2.connectionCount, 4);
    });

    test('copyWith supports capabilityProfile', () {
      final PrinterModel p = _mk('TSP100', 'AA:BB:CC:DD:EE:01');
      final PrinterModel p2 = p.copyWith(
        capabilityProfile: PrinterCapabilityProfile.star,
      );
      expect(p2.capabilityProfile, PrinterCapabilityProfile.star);
      expect(p.capabilityProfile, PrinterCapabilityProfile.auto);
    });

    test('persists capabilityProfile through JSON round-trip', () {
      final PrinterModel p = PrinterModel(
        name: 'TSP100',
        address: 'AA:BB:CC:DD:EE:01',
        capabilityProfile: PrinterCapabilityProfile.star,
      );
      final String json = p.encode();
      expect(json.contains('star'), isTrue);
      final PrinterModel back = PrinterModel.decode(json);
      expect(back.capabilityProfile, PrinterCapabilityProfile.star);
    });

    test('unknown capabilityProfile id falls back to auto', () {
      final String raw = jsonEncode(<String, Object>{
        'name': 'X',
        'address': 'AA:BB:CC:DD:EE:FF',
        'printerType': '80mm',
        'capabilityProfile': 'unknown_profile',
        'isDefault': false,
        'connectionCount': 0,
      });
      final PrinterModel back = PrinterModel.decode(raw);
      expect(back.capabilityProfile, PrinterCapabilityProfile.auto);
    });

    test('all PrinterCapabilityProfile enum values have stable ids', () {
      for (final PrinterCapabilityProfile p
          in PrinterCapabilityProfile.values) {
        expect(p.id, isNotEmpty);
        expect(
          PrinterCapabilityProfileX.fromId(p.id),
          p,
          reason: 'round-trip failed for $p',
        );
      }
    });
  });

  group('PrinterHelper.detectProfile', () {
    test('detects Xprinter from common prefixes', () {
      expect(
        PrinterHelper.detectProfile(
          printerName: 'XP-58',
          macAddress: '00:11:22:33:44:55',
        ),
        PrinterCapabilityProfile.xprinter80,
      );
      expect(
        PrinterHelper.detectProfile(
          printerName: 'XP_80',
          macAddress: '00:11:22:33:44:55',
        ),
        PrinterCapabilityProfile.xprinter80,
      );
      expect(
        PrinterHelper.detectProfile(
          printerName: 'Xprinter XP-Q200',
          macAddress: '00:11:22:33:44:55',
        ),
        PrinterCapabilityProfile.xprinter80,
      );
    });

    test('detects Sunmi from name', () {
      expect(
        PrinterHelper.detectProfile(
          printerName: 'SUNMI V2',
          macAddress: '00:11:22:33:44:55',
        ),
        PrinterCapabilityProfile.auto,
      );
    });

    test('falls back to auto (default profile) for unknown brands', () {
      expect(
        PrinterHelper.detectProfile(
          printerName: 'TSP100-G0065',
          macAddress: '00:11:62:17:56:A9',
        ),
        PrinterCapabilityProfile.auto,
      );
    });
  });

  group('PrinterHelper.buildPaperCutBytes', () {
    test('starts with ESC d 2 (feed 2 lines)', () {
      final List<int> bytes = PrinterHelper.buildPaperCutBytes();
      expect(bytes.length, greaterThan(0));
      // ESC d 2 → 0x1B 0x64 0x02
      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x64);
      expect(bytes[2], 0x02);
    });

    test('contains the canonical GS V 0 full cut', () {
      final List<int> bytes = PrinterHelper.buildPaperCutBytes();
      final List<int> needle = <int>[0x1D, 0x56, 0x00];
      bool found = false;
      for (int i = 0; i + needle.length <= bytes.length; i++) {
        if (bytes[i] == needle[0] &&
            bytes[i + 1] == needle[1] &&
            bytes[i + 2] == needle[2]) {
          found = true;
          break;
        }
      }
      expect(found, isTrue, reason: 'GS V 0 sequence not found in cut bytes');
    });

    test(
      'contains exactly one cut command (no duplicate GS V 0 sequences)',
      () {
        final List<int> bytes = PrinterHelper.buildPaperCutBytes();
        final List<int> needle = <int>[0x1D, 0x56, 0x00];
        int count = 0;
        for (int i = 0; i + needle.length <= bytes.length; i++) {
          if (bytes[i] == needle[0] &&
              bytes[i + 1] == needle[1] &&
              bytes[i + 2] == needle[2]) {
            count++;
          }
        }
        expect(count, 1, reason: 'buildPaperCutBytes must cut exactly once');
      },
    );

    test('honours a custom feed line count', () {
      final List<int> bytes = PrinterHelper.buildPaperCutBytes(feedLines: 7);
      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x64);
      expect(bytes[2], 0x07);
    });

    test('is idempotent — every invocation returns the same byte sequence', () {
      final List<int> a = PrinterHelper.buildPaperCutBytes();
      final List<int> b = PrinterHelper.buildPaperCutBytes();
      expect(a, equals(b));
    });

    test('total byte length is exactly 6 (ESC d N + GS V 0)', () {
      final List<int> bytes = PrinterHelper.buildPaperCutBytes();
      expect(bytes.length, 6);
    });
  });

  group('PrinterController.scanPrinters', () {
    test('keeps existing user-configured fields when re-scanning', () async {
      final _FakeRepo repo = _FakeRepo(
        saved: <PrinterModel>[
          _mk(
            'XP-58',
            'AA:BB:CC:DD:EE:01',
            isDefault: true,
            connectionCount: 2,
          ),
        ],
      );
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      await c.scanPrinters();
      expect(repo.getSavedPrinters(), hasLength(1));
      expect(repo.getSavedPrinters().first.isDefault, isTrue);
      expect(repo.getSavedPrinters().first.connectionCount, 2);
    });

    test('skips scan when already in flight', () async {
      final _FakeRepo repo = _FakeRepo();
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      final Future<void> a = c.scanPrinters();
      final Future<void> b = c.scanPrinters();
      await Future.wait(<Future<void>>[a, b]);
      expect(c.scanning.value, isFalse);
    });

    test('rejects scan when Bluetooth is off', () async {
      final _FakeRepo repo = _FakeRepo();
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      repo.setBluetooth(false);
      await c.scanPrinters();
      expect(c.bluetoothEnabled.value, isFalse);
      expect(repo.getSavedPrinters(), isEmpty);
    });

    test('rejects scan when permissions are not granted', () async {
      final _FakeRepo repo = _FakeRepo();
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = false;
      c.permissionPermanentlyDenied.value = true;
      await c.scanPrinters();
      expect(repo.getSavedPrinters(), isEmpty);
    });
  });

  group('PrinterController.setDefaultPrinter', () {
    test('only one printer is default at a time', () async {
      final _FakeRepo repo = _FakeRepo(
        saved: <PrinterModel>[
          _mk('A', 'AA:AA:AA:AA:AA:01', isDefault: true),
          _mk('B', 'AA:AA:AA:AA:AA:02'),
          _mk('C', 'AA:AA:AA:AA:AA:03'),
        ],
      );
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      await c.setDefaultPrinter(_mk('C', 'AA:AA:AA:AA:AA:03'));
      expect(repo.getDefaultPrinter()?.address, 'AA:AA:AA:AA:AA:03');
      int defaults = repo
          .getSavedPrinters()
          .where((PrinterModel p) => p.isDefault)
          .length;
      expect(defaults, 1);
    });

    test('removing default promotes another printer', () async {
      final _FakeRepo repo = _FakeRepo(
        saved: <PrinterModel>[
          _mk('A', 'AA:AA:AA:AA:AA:01', isDefault: true),
          _mk('B', 'AA:AA:AA:AA:AA:02'),
        ],
      );
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      await c.removePrinter(_mk('A', 'AA:AA:AA:AA:AA:01'));
      expect(repo.getDefaultPrinter()?.address, 'AA:AA:AA:AA:AA:02');
    });
  });

  group('PrinterController.reconnectDefaultPrinter', () {
    test('returns false when there is no default printer', () async {
      final _FakeRepo repo = _FakeRepo();
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      await repo.clearDefaultPrinter();
      c.defaultPrinter.value = null;
      final bool ok = await c.reconnectDefaultPrinter();
      expect(ok, isFalse);
    });

    test('returns true if already connected', () async {
      final _FakeRepo repo = _FakeRepo(
        saved: <PrinterModel>[_mk('A', 'AA:AA:AA:AA:AA:01', isDefault: true)],
      );
      repo.setConnected(true);
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      final bool ok = await c.reconnectDefaultPrinter();
      expect(ok, isTrue);
    });

    test('tries up to maxReconnectAttempts on failure', () async {
      final _FakeRepo repo = _FakeRepo(
        saved: <PrinterModel>[_mk('A', 'AA:AA:AA:AA:AA:01', isDefault: true)],
      );
      repo.setConnected(false);
      repo.setConnectResult(false);
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      final DateTime t0 = DateTime.now();
      final bool ok = await c.reconnectDefaultPrinter();
      final Duration elapsed = DateTime.now().difference(t0);
      expect(ok, isFalse);
      expect(elapsed.inMilliseconds >= 600, isTrue);
    });
  });

  group('PrinterController.printTest', () {
    test('returns false when no default printer', () async {
      final _FakeRepo repo = _FakeRepo();
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      await repo.clearDefaultPrinter();
      c.defaultPrinter.value = null;
      final bool ok = await c.printTest();
      expect(ok, isFalse);
    });

    test('returns true when connected and a default printer exists', () async {
      final _FakeRepo repo = _FakeRepo(
        saved: <PrinterModel>[_mk('A', 'AA:AA:AA:AA:AA:01', isDefault: true)],
      );
      repo.setConnected(true);
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      final bool ok = await c.printTest();
      expect(ok, isTrue);
      final List<PrinterModel> saved = repo.getSavedPrinters();
      expect(saved.first.lastPrintSuccess, isNotNull);
    });

    test(
      'writes the ticket bytes that contain the cut command exactly once',
      () async {
        final _FakeRepo repo = _FakeRepo(
          saved: <PrinterModel>[_mk('A', 'AA:AA:AA:AA:AA:01', isDefault: true)],
        );
        repo.setConnected(true);
        final PrinterController c = PrinterController(printerRepository: repo);
        c.loadSavedPrinter();
        c.permissionsGranted.value = true;
        final bool ok = await c.printTest();
        expect(ok, isTrue);
        final _FakeService svc = repo.service as _FakeService;
        // Exactly one write call (no separate cut call).
        expect(svc.writeCalls, 1);
        expect(svc.cutCalls, 0);
        // The ticket that was written contains the cut bytes.
        final List<int> bytes = svc.lastBytes!;
        final List<int> needle = <int>[0x1D, 0x56, 0x00];
        int count = 0;
        for (int i = 0; i + needle.length <= bytes.length; i++) {
          if (bytes[i] == needle[0] &&
              bytes[i + 1] == needle[1] &&
              bytes[i + 2] == needle[2]) {
            count++;
          }
        }
        expect(
          count,
          1,
          reason: 'Ticket must contain exactly one GS V 0 cut sequence',
        );
      },
    );
  });

  group('PrinterController._printWithTicket retry', () {
    test(
      'retries on first failure and succeeds on the second attempt',
      () async {
        final _CountingService svc = _CountingService(<bool>[false, true]);
        final _CountingRepo repo = _CountingRepo(
          svc,
          saved: <PrinterModel>[_mk('A', 'AA:AA:AA:AA:AA:01', isDefault: true)],
        );
        final PrinterController c = PrinterController(printerRepository: repo);
        c.loadSavedPrinter();
        c.permissionsGranted.value = true;
        final bool ok = await c.printTest();
        expect(ok, isTrue);
        expect(svc.writeCalls >= 2, isTrue);
        // Even on retry, the cut is part of the ticket (no separate cut).
        expect(svc.cutCalls, 0);
      },
    );

    test('returns false after exhausting maxWriteAttempts', () async {
      final _CountingService svc = _CountingService(
        List<bool>.filled(PrinterController.maxWriteAttempts, false),
      );
      final _CountingRepo repo = _CountingRepo(
        svc,
        saved: <PrinterModel>[_mk('A', 'AA:AA:AA:AA:AA:01', isDefault: true)],
      );
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      final bool ok = await c.printTest();
      expect(ok, isFalse);
      expect(svc.writeCalls, PrinterController.maxWriteAttempts);
      expect(svc.cutCalls, 0);
    });
  });

  group('PrinterController.addPrinterManually', () {
    test('rejects invalid MAC format', () async {
      final _FakeRepo repo = _FakeRepo();
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      final PrinterModel? added = await c.addPrinterManually(mac: 'not-a-mac');
      expect(added, isNull);
      expect(repo.getSavedPrinters(), isEmpty);
    });

    test('accepts a valid MAC and stores the printer', () async {
      final _FakeRepo repo = _FakeRepo();
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      final PrinterModel? added = await c.addPrinterManually(
        mac: 'AA:BB:CC:DD:EE:99',
        name: 'Receipt Printer',
      );
      expect(added, isNotNull);
      expect(added!.address, 'AA:BB:CC:DD:EE:99');
      expect(repo.getSavedPrinters(), hasLength(1));
    });
  });

  group('PrinterController.setPrinterPaperSize', () {
    test('persists paper-size change for the matching printer', () async {
      final _FakeRepo repo = _FakeRepo(
        saved: <PrinterModel>[_mk('A', 'AA:AA:AA:AA:AA:01', paperSize: '80mm')],
      );
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      await c.setPrinterPaperSize(
        _mk('A', 'AA:AA:AA:AA:AA:01', paperSize: '80mm'),
        '58mm',
      );
      expect(repo.getSavedPrinters().first.printerType, '58mm');
    });
  });

  group('PrinterController.validateBluetooth', () {
    test('returns ok when permissions are granted and BT is on', () async {
      final _FakeRepo repo = _FakeRepo();
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      repo.setBluetooth(true);
      final BluetoothValidationResult r = await c.validateBluetooth();
      expect(r.isReady, isTrue);
    });

    test('returns failure with bluetoothOff when adapter is off', () async {
      final _FakeRepo repo = _FakeRepo();
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      repo.setBluetooth(false);
      final BluetoothValidationResult r = await c.validateBluetooth();
      expect(r.isReady, isFalse);
      expect(r.failure, BluetoothValidationFailure.bluetoothOff);
    });
  });

  group('PrinterController.runDiagnostics', () {
    test('reports issues when nothing is configured', () async {
      final _FakeRepo repo = _FakeRepo();
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = false;
      c.permissionPermanentlyDenied.value = true;
      repo.setBluetooth(true);
      final PrinterDiagnosticsReport r = await c.runDiagnostics();
      expect(r.savedPrinterCount, 0);
      expect(r.hasDefaultPrinter, isFalse);
      expect(r.issues.any((String i) => i.contains('perm')), isTrue);
      expect(r.issues.any((String i) => i.contains('printer')), isTrue);
    });

    test('reports no issues when everything is fine', () async {
      final _FakeRepo repo = _FakeRepo(
        saved: <PrinterModel>[_mk('A', 'AA:AA:AA:AA:AA:01', isDefault: true)],
      );
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      repo.setBluetooth(true);
      repo.setConnected(true);
      final PrinterDiagnosticsReport r = await c.runDiagnostics();
      expect(r.issues, isEmpty);
      expect(r.recommendations, isEmpty);
    });
  });

  group('PrinterController.getUiStatus', () {
    test('returns permissionDenied when no permission', () {
      final _FakeRepo repo = _FakeRepo(
        saved: <PrinterModel>[_mk('A', 'AA:AA:AA:AA:AA:01')],
      );
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = false;
      expect(
        c.getUiStatus(_mk('A', 'AA:AA:AA:AA:AA:01')),
        PrinterUiStatus.permissionDenied,
      );
    });

    test('returns bluetoothOff when BT is off', () {
      final _FakeRepo repo = _FakeRepo(
        saved: <PrinterModel>[_mk('A', 'AA:AA:AA:AA:AA:01')],
      );
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      c.bluetoothEnabled.value = false;
      expect(
        c.getUiStatus(_mk('A', 'AA:AA:AA:AA:AA:01')),
        PrinterUiStatus.bluetoothOff,
      );
    });

    test('returns connected when the printer is the active MAC', () {
      final _FakeRepo repo = _FakeRepo(
        saved: <PrinterModel>[_mk('A', 'AA:AA:AA:AA:AA:01')],
      );
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      c.bluetoothEnabled.value = true;
      c.connectedMac.value = 'AA:AA:AA:AA:AA:01';
      expect(
        c.getUiStatus(_mk('A', 'AA:AA:AA:AA:AA:01')),
        PrinterUiStatus.connected,
      );
    });

    test('returns disconnected for an unrelated printer', () {
      final _FakeRepo repo = _FakeRepo(
        saved: <PrinterModel>[_mk('A', 'AA:AA:AA:AA:AA:01')],
      );
      final PrinterController c = PrinterController(printerRepository: repo);
      c.loadSavedPrinter();
      c.permissionsGranted.value = true;
      c.bluetoothEnabled.value = true;
      c.connectedMac.value = 'FF:FF:FF:FF:FF:FF';
      expect(
        c.getUiStatus(_mk('A', 'AA:AA:AA:AA:AA:01')),
        PrinterUiStatus.disconnected,
      );
    });
  });

  group('PrinterService adapter cache TTL', () {
    test('markAdapterEnabled updates the cached value', () {
      PrinterService.markAdapterEnabled(true);
      final ValueNotifier<bool?> notifier = PrinterService.adapterStateNotifier;
      expect(notifier.value, isTrue);
    });

    test('invalidateAdapterCache clears the cached value', () {
      PrinterService.markAdapterEnabled(true);
      PrinterService.invalidateAdapterCache();
      final ValueNotifier<bool?> notifier = PrinterService.adapterStateNotifier;
      expect(notifier.value, isNull);
    });

    test(
      'isBluetoothEnabled can be called on an instance without throwing',
      () async {
        final PrinterService svc = PrinterService();
        final bool v = await svc.isBluetoothEnabled();
        expect(v, isA<bool>());
      },
    );
  });

  group('PrinterLogger', () {
    test('keeps the most recent entries and clears the buffer', () {
      PrinterLogger.i('Tag', 'one');
      PrinterLogger.w('Tag', 'two', Exception('boom'));
      PrinterLogger.e('Tag', 'three', StateError('x'));
      expect(PrinterLogger.entries.length, 3);
      final PrinterLogEntry last = PrinterLogger.entries.last;
      expect(last.level, PrinterLogLevel.error);
      expect(last.error, isA<StateError>());
      PrinterLogger.clear();
      expect(PrinterLogger.entries, isEmpty);
    });

    test('exposes a pretty string suitable for diagnostics UI', () {
      PrinterLogger.i('X', 'hello');
      final PrinterLogEntry e = PrinterLogger.entries.last;
      expect(e.pretty, contains('hello'));
      expect(e.pretty, contains('INFO'));
    });
  });

  group('JSON round-trip', () {
    test('survives encoding/decoding with all fields', () {
      final PrinterModel p = PrinterModel(
        name: 'XP-58',
        address: 'AA:BB:CC:DD:EE:FF',
        printerType: '58mm',
        capabilityProfile: PrinterCapabilityProfile.xprinter58,
        isDefault: true,
        lastConnected: '2026-07-13T10:00:00.000',
        lastPrintSuccess: '2026-07-13T10:05:00.000',
        connectionCount: 7,
      );
      final PrinterModel round = PrinterModel.decode(jsonEncode(p.toJson()));
      expect(round.connectionCount, 7);
      expect(round.lastPrintSuccess, '2026-07-13T10:05:00.000');
      expect(round.printerType, '58mm');
      expect(round.capabilityProfile, PrinterCapabilityProfile.xprinter58);
    });
  });
}
