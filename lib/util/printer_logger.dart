import 'package:flutter/foundation.dart';

/// Severity levels for printer-related log messages.
enum PrinterLogLevel { debug, info, warning, error }

/// Lightweight structured logger for the printer subsystem.
///
/// We keep our own logger (rather than using a third-party package) so that
/// the printer module has zero additional dependencies. In release builds
/// the messages are silenced unless [verbose] is true.
class PrinterLogger {
  PrinterLogger._();

  /// When true, log messages are printed in release mode too.
  static bool verbose = kDebugMode;

  /// Optional sink that downstream code (e.g. a "Diagnostics" screen) can
  /// subscribe to in order to display a rolling log of recent events.
  static final List<PrinterLogEntry> _buffer = <PrinterLogEntry>[];

  /// Maximum number of entries kept in the in-memory buffer.
  static const int _bufferSize = 200;

  /// Returns a snapshot of the most recent log entries.
  static List<PrinterLogEntry> get entries =>
      List<PrinterLogEntry>.unmodifiable(_buffer);

  /// Clears the in-memory log buffer.
  static void clear() => _buffer.clear();

  static void d(String tag, String message, [Object? error, StackTrace? st]) =>
      _log(PrinterLogLevel.debug, tag, message, error, st);

  static void i(String tag, String message, [Object? error, StackTrace? st]) =>
      _log(PrinterLogLevel.info, tag, message, error, st);

  static void w(String tag, String message, [Object? error, StackTrace? st]) =>
      _log(PrinterLogLevel.warning, tag, message, error, st);

  static void e(String tag, String message, [Object? error, StackTrace? st]) =>
      _log(PrinterLogLevel.error, tag, message, error, st);

  static void _log(
    PrinterLogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final PrinterLogEntry entry = PrinterLogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
    );
    _buffer.add(entry);
    if (_buffer.length > _bufferSize) {
      _buffer.removeRange(0, _buffer.length - _bufferSize);
    }

    if (!verbose) {
      return;
    }
    final String levelLabel = level.name.toUpperCase().padRight(7);
    final String line =
        '[$levelLabel] ${entry.timestamp.toIso8601String()} [$tag] $message';
    if (level == PrinterLogLevel.error || level == PrinterLogLevel.warning) {
      // ignore: avoid_print
      debugPrint(line);
      if (error != null) {
        // ignore: avoid_print
        debugPrint('  ↳ $error');
      }
      if (stackTrace != null) {
        // ignore: avoid_print
        debugPrint(stackTrace.toString());
      }
    } else {
      // ignore: avoid_print
      debugPrint(line);
    }
  }
}

/// Single immutable log entry.
class PrinterLogEntry {
  final DateTime timestamp;
  final PrinterLogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  const PrinterLogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  String get levelLabel => level.name.toUpperCase();

  /// One-line, human-readable representation suitable for the diagnostics
  /// screen.
  String get pretty {
    final String hh = timestamp.hour.toString().padLeft(2, '0');
    final String mm = timestamp.minute.toString().padLeft(2, '0');
    final String ss = timestamp.second.toString().padLeft(2, '0');
    final String head = '[$hh:$mm:$ss] [$levelLabel]';
    final String tail = error == null ? '' : ' — $error';
    return '$head $message$tail';
  }
}
