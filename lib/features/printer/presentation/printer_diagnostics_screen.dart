import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:ppdelistore/features/printer/presentation/printer_controller.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/printer_logger.dart';
import 'package:ppdelistore/util/styles.dart';

/// Screen that renders the [PrinterDiagnosticsReport] returned by
/// [PrinterController.runDiagnostics] together with the in-memory log buffer
/// produced by [PrinterLogger].
class PrinterDiagnosticsScreen extends StatefulWidget {
  const PrinterDiagnosticsScreen({super.key});

  @override
  State<PrinterDiagnosticsScreen> createState() =>
      _PrinterDiagnosticsScreenState();
}

class _PrinterDiagnosticsScreenState extends State<PrinterDiagnosticsScreen> {
  final PrinterController _controller = Get.find<PrinterController>();
  PrinterDiagnosticsReport? _report;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() => _running = true);
    final PrinterDiagnosticsReport report = await _controller.runDiagnostics();
    if (!mounted) return;
    setState(() {
      _report = report;
      _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<PrinterLogEntry> entries = PrinterLogger.entries.reversed
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('diagnostics_title'.tr),
        backgroundColor: Theme.of(context).cardColor,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _running ? null : _runDiagnostics,
            tooltip: 'diagnostics_rerun'.tr,
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _running
                ? null
                : () async {
                    await Get.find<PrinterController>().reconnectDefaultPrinter(
                      silent: false,
                    );
                    await _runDiagnostics();
                  },
            tooltip: 'diagnostics_force_reconnect'.tr,
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyReport,
            tooltip: 'diagnostics_copy'.tr,
          ),
        ],
      ),
      body: _running && _report == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _runDiagnostics,
              child: ListView(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                children: <Widget>[
                  if (_report != null) ..._reportSection(context, _report!),
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  _SectionTitle('diagnostics_log'.tr),
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: Dimensions.paddingSizeDefault,
                      ),
                      child: Text(
                        'diagnostics_no_log'.tr,
                        style: robotoRegular.copyWith(
                          color: Theme.of(context).disabledColor,
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault,
                        ),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.3),
                        ),
                      ),
                      padding: const EdgeInsets.all(
                        Dimensions.paddingSizeSmall,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: entries
                            .take(80)
                            .map((PrinterLogEntry e) => _LogTile(entry: e))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  List<Widget> _reportSection(
    BuildContext context,
    PrinterDiagnosticsReport r,
  ) {
    final List<Widget> rows = <Widget>[
      _StatusTile(
        label: 'diagnostic_bluetooth'.tr,
        value: r.bluetoothEnabled
            ? 'diagnostic_enabled'.tr
            : 'diagnostic_disabled'.tr,
        ok: r.bluetoothEnabled,
      ),
      _StatusTile(
        label: 'diagnostic_permissions'.tr,
        value: r.permissionsGranted
            ? 'diagnostic_granted'.tr
            : (r.anyPermissionPermanentlyDenied
                  ? 'diagnostic_permanently_denied'.tr
                  : 'diagnostic_missing'.tr),
        ok: r.permissionsGranted,
      ),
      _StatusTile(
        label: 'diagnostic_saved_printers'.tr,
        value: r.savedPrinterCount.toString(),
        ok: r.savedPrinterCount > 0,
      ),
      _StatusTile(
        label: 'diagnostic_default_printer'.tr,
        value: r.hasDefaultPrinter
            ? '${r.defaultPrinterName ?? ''} (${r.defaultPrinterMac ?? ''})'
            : 'diagnostic_none'.tr,
        ok: r.hasDefaultPrinter,
      ),
      _StatusTile(
        label: 'diagnostic_connection'.tr,
        value: r.connectedToDefaultPrinter
            ? 'connected'.tr
            : 'not_connected'.tr,
        ok: r.connectedToDefaultPrinter,
      ),
      _StatusTile(
        label: 'diagnostic_last_connected_mac'.tr,
        value: r.lastConnectedMac ?? '—',
        ok: r.lastConnectedMac != null,
      ),
      _StatusTile(
        label: 'diagnostic_reconnect_attempts'.tr,
        value: r.connectionAttemptsLast.toString(),
        ok: true,
      ),
    ];

    return <Widget>[
      _SectionTitle('diagnostics_summary'.tr),
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        ),
      ),
      const SizedBox(height: Dimensions.paddingSizeDefault),
      if (r.issues.isNotEmpty) ...<Widget>[
        _SectionTitle('diagnostics_issues'.tr),
        ...r.issues.map((String i) => _Bullet(text: i, ok: false)),
        const SizedBox(height: Dimensions.paddingSizeDefault),
      ],
      if (r.recommendations.isNotEmpty) ...<Widget>[
        _SectionTitle('diagnostics_recommendations'.tr),
        ...r.recommendations.map((String i) => _Bullet(text: i, ok: true)),
        const SizedBox(height: Dimensions.paddingSizeDefault),
      ],
    ];
  }

  void _copyReport() {
    if (_report == null) return;
    final StringBuffer sb = StringBuffer();
    sb.writeln('PRINTER DIAGNOSTICS REPORT');
    sb.writeln('============================');
    final PrinterDiagnosticsReport r = _report!;
    sb.writeln('Bluetooth enabled: ${r.bluetoothEnabled}');
    sb.writeln('Permissions granted: ${r.permissionsGranted}');
    sb.writeln(
      'Permissions permanently denied: ${r.anyPermissionPermanentlyDenied}',
    );
    sb.writeln('Saved printers: ${r.savedPrinterCount}');
    sb.writeln('Default printer: ${r.defaultPrinterName}');
    sb.writeln('Connected to default: ${r.connectedToDefaultPrinter}');
    sb.writeln('Last connected MAC: ${r.lastConnectedMac}');
    sb.writeln('');
    if (r.issues.isNotEmpty) {
      sb.writeln('Issues:');
      for (final String i in r.issues) {
        sb.writeln(' - $i');
      }
    }
    if (r.recommendations.isNotEmpty) {
      sb.writeln('Recommendations:');
      for (final String i in r.recommendations) {
        sb.writeln(' - $i');
      }
    }
    sb.writeln('');
    sb.writeln('--- LOG ---');
    for (final PrinterLogEntry e in PrinterLogger.entries) {
      sb.writeln(e.pretty);
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    Get.snackbar(
      'diagnostics_title'.tr,
      'diagnostics_copied'.tr,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeSmall,
      ),
      child: Text(
        text,
        style: robotoBold.copyWith(
          fontSize: Dimensions.fontSizeLarge,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String label;
  final String value;
  final bool ok;
  const _StatusTile({
    required this.label,
    required this.value,
    required this.ok,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeExtraSmall,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            ok ? Icons.check_circle : Icons.error_outline,
            color: ok ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: robotoMedium.copyWith(fontSize: 14)),
                Text(
                  value,
                  style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Theme.of(context).disabledColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  final bool ok;
  const _Bullet({required this.text, required this.ok});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 2,
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            ok ? Icons.tips_and_updates : Icons.warning_amber,
            color: ok ? Colors.amber : Colors.red,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final PrinterLogEntry entry;
  const _LogTile({required this.entry});
  @override
  Widget build(BuildContext context) {
    Color color;
    switch (entry.level) {
      case PrinterLogLevel.error:
        color = Colors.red;
        break;
      case PrinterLogLevel.warning:
        color = Colors.orange;
        break;
      case PrinterLogLevel.info:
        color = Theme.of(context).primaryColor;
        break;
      case PrinterLogLevel.debug:
        color = Theme.of(context).disabledColor;
        break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        entry.pretty,
        style: robotoRegular.copyWith(
          fontSize: 11,
          color: color,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
