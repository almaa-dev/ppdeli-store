import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import 'package:ppdelistore/features/printer/domain/models/printer_model.dart';
import 'package:ppdelistore/features/order/domain/models/order_details_model.dart';
import 'package:ppdelistore/features/order/domain/models/order_model.dart';
import 'package:ppdelistore/features/printer/helper/invoice_receipt_builder.dart';

/// Helper utility for building ESC/POS byte streams and rendering test pages.
///
/// **The capability profile is the single most important decision this
/// helper makes.** `flutter_esc_pos_utils` exposes a curated bundle of
/// command switches per printer brand. Sending the wrong one causes the
/// printer to silently drop the bytes — the Bluetooth socket reports
/// success but nothing prints. We therefore:
///   1. Honour the operator's manual selection on [PrinterModel.capabilityProfile].
///   2. Fall back to a name/MAC-based heuristic for `auto` profiles.
///   3. As a last resort, use the most-compatible `default` profile.
///
/// Note: as of `flutter_esc_pos_utils` 1.0.1 the only first-party profiles
/// shipped in `resources/capabilities.json` are `default`, `XP-N160I`,
/// `RP80USE`, `SUNMI`, `TP806L` and `ITPP047`. Everything else falls back
/// to `default`, which targets the canonical ESC/POS command set. Star
/// Micronics TSP100/TSP143 printers are ESC/POS-compatible when set to
/// "ESC/POS emulation" mode at the printer (the default mode for many
/// TSP100 units). The `default` profile works correctly in that mode.
class PrinterHelper {
  PrinterHelper._();

  /// Default paper size for new printers.
  static const String defaultPaperSize = '80mm';

  /// Logical pixel width used when rendering an invoice for **printing**.
  ///
  /// The invoice is rendered off-screen inside a `SizedBox` whose width
  /// matches exactly these constants. Because the captured image is later
  /// resampled to the printer's full paper width (500 px for 80 mm), the
  /// borders of the invoice black box reach exactly the left/right edges of
  /// the paper — no white margins remain.
  static const double buildDimensions80mm = 284.0;
  static const double buildDimensions58mm = 189.0;

  /// Map from the brand-agnostic [PrinterCapabilityProfile] enum to the
  /// profile names recognised by `flutter_esc_pos_utils` 1.0.1.
  static const Map<PrinterCapabilityProfile, String> _profileNames =
      <PrinterCapabilityProfile, String>{
        PrinterCapabilityProfile.auto: 'default',
        PrinterCapabilityProfile.star: 'default',
        PrinterCapabilityProfile.starRaster: 'default',
        PrinterCapabilityProfile.epson: 'default',
        PrinterCapabilityProfile.xprinter58: 'XP-N160I',
        PrinterCapabilityProfile.xprinter80: 'XP-N160I',
      };

  /// Brand hints detected from a printer's name or MAC. The detection is
  /// intentionally case-insensitive and matches against the common
  /// prefixes shipped by each manufacturer:
  ///
  ///   - **Xprinter** — `XP-`, `XP_`, `xprinter`
  ///   - **Rongta** — `RP`, `Rongta`, `RP80`
  ///   - **Sunmi** — `SUNMI`
  ///   - **HPRT** — `TP806`, `TP80`, `HPRT`
  ///   - **Munbyn** — `ITPP`, `Munbyn`
  ///   - **Star Micronics** — `TSP`, `SM-`, `SP-`, `TUP`, `BSC10`, `FVP10`,
  ///     `star` (ESC/POS emulation mode)
  static PrinterCapabilityProfile detectProfile({
    required String printerName,
    required String macAddress,
  }) {
    final String needle = '$printerName $macAddress'.toLowerCase();

    // Xprinter — has a dedicated profile in flutter_esc_pos_utils 1.0.1.
    if (_matchesAny(needle, <String>['xp-', 'xp_', 'xprinter'])) {
      return PrinterCapabilityProfile.xprinter80;
    }

    // Rongta — has a dedicated profile.
    if (_matchesAny(needle, <String>['rp80', 'rongta', 'rp-', 'rp_'])) {
      return PrinterCapabilityProfile.auto;
    }

    // Sunmi — has a dedicated profile.
    if (_matchesAny(needle, <String>['sunmi'])) {
      return PrinterCapabilityProfile.auto;
    }

    // HPRT — has a dedicated profile.
    if (_matchesAny(needle, <String>['tp806', 'tp80', 'hprt'])) {
      return PrinterCapabilityProfile.auto;
    }

    // Munbyn — has a dedicated profile.
    if (_matchesAny(needle, <String>['itpp', 'munbyn'])) {
      return PrinterCapabilityProfile.auto;
    }

    // Star Micronics (ESC/POS emulation), Epson, Bixolon, Citizen, generic
    // ESC/POS devices — all use the `default` profile in 1.0.1.
    return PrinterCapabilityProfile.auto;
  }

  /// Resolves the [CapabilityProfile] for a given [PrinterModel].
  ///
  /// Order of precedence:
  ///   1. The explicit operator override on the model.
  ///   2. Auto-detection from the name/MAC.
  ///   3. Hard-coded `default` fallback (most compatible for the
  ///      printer families in the field today).
  static Future<CapabilityProfile> resolveProfile(PrinterModel printer) async {
    final PrinterCapabilityProfile id =
        printer.capabilityProfile == PrinterCapabilityProfile.auto
        ? detectProfile(printerName: printer.name, macAddress: printer.address)
        : printer.capabilityProfile;

    final String profileName = _profileNames[id] ?? 'default';
    return CapabilityProfile.load(name: profileName);
  }

  static bool _matchesAny(String haystack, List<String> needles) {
    for (final String n in needles) {
      if (haystack.contains(n)) {
        return true;
      }
    }
    return false;
  }

  /// Generates the raw ESC/POS bytes for the "Test Printer" receipt.
  ///
  /// The capability profile is selected from [PrinterModel.capabilityProfile]
  /// (or auto-detected if it's [PrinterCapabilityProfile.auto]) so the
  /// resulting bytes are always compatible with the printer's command set.
  static Future<List<int>> buildTestReceiptBytes({
    required PrinterModel printer,
  }) async {
    final bool is58mm = printer.printerType == '58mm';
    final PaperSize paperSize = is58mm ? PaperSize.mm58 : PaperSize.mm80;

    // Use dashes that match the actual paper width so the dividers are
    // visually consistent across 58mm and 80mm receipts.
    final String divider = is58mm
        ? '--------------------------------'
        : '------------------------------------------';

    final CapabilityProfile profile = await resolveProfile(printer);
    final Generator generator = Generator(paperSize, profile);

    final List<int> bytes = <int>[];

    final String dateLine = DateFormat('dd/MM/yyyy').format(DateTime.now());

    // Initialize the printer (ESC @) - clears any leftover formatting state
    // from a previous session. Some printers (notably Star TSP100) silently
    // ignore bytes until they have been initialised.
    bytes.addAll(generator.reset());

    bytes.addAll(generator.feed(1));
    bytes.addAll(
      generator.text(divider, styles: const PosStyles(align: PosAlign.center)),
    );
    bytes.addAll(
      generator.text(
        'TEST PRINTER',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    bytes.addAll(
      generator.text(divider, styles: const PosStyles(align: PosAlign.center)),
    );
    bytes.addAll(generator.feed(1));
    bytes.addAll(
      generator.text(
        'Bluetooth Connected',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(generator.feed(1));
    bytes.addAll(
      generator.text(
        'Printer Name',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        printer.name,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(generator.feed(1));
    bytes.addAll(
      generator.text(dateLine, styles: const PosStyles(align: PosAlign.center)),
    );
    bytes.addAll(generator.feed(1));
    bytes.addAll(
      generator.text(divider, styles: const PosStyles(align: PosAlign.center)),
    );
    bytes.addAll(generator.feed(3));
    bytes.addAll(buildPaperCutBytes());
    return bytes;
  }

  /// Encodes the supplied image bytes into ESC/POS raster bytes using the
  /// supplied paper size. Useful for screenshot-based invoice printing.
  static Future<List<int>> buildImageBytes({
    required Uint8List image,
    required String paperSize,
  }) async {
    final PaperSize paper = paperSize == '58mm'
        ? PaperSize.mm58
        : PaperSize.mm80;
    final img.Image? decoded = img.decodeImage(image);
    if (decoded == null) {
      return <int>[];
    }
    final img.Image resized = img.copyResize(
      decoded,
      width: paper == PaperSize.mm80 ? 500 : 365,
    );
    // Image rendering uses the generic `default` profile which produces
    // standard ESC/POS raster commands (GS v 0) compatible with the vast
    // majority of mobile receipt printers (Star TSP100, Epson TM-T88,
    // Xprinter, Rongta, etc.).
    final CapabilityProfile profile = await CapabilityProfile.load();
    final Generator generator = Generator(paper, profile);
    final List<int> bytes = <int>[];
    bytes.addAll(generator.reset());
    bytes.addAll(generator.image(resized));
    bytes.addAll(generator.feed(2));
    bytes.addAll(buildPaperCutBytes());
    return bytes;
  }

  /// Loads an asset image and converts it to ESC/POS bytes (e.g. for
  /// printing a logo on the test page).
  static Future<List<int>?> loadAssetImageBytes(String path) async {
    try {
      final ByteData data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Encodes a printer to a JSON map with a stable schema.
  static String encodePrinter(PrinterModel printer) =>
      jsonEncode(printer.toJson());

  /// Decodes a printer from a JSON string.
  static PrinterModel? decodePrinter(String raw) {
    try {
      return PrinterModel.decode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Builds the native ESC/POS byte stream for a complete order invoice.
  ///
  /// **This is the entry point used by the print flow.** Compared to the
  /// legacy [buildImageBytes] path, it does **not** require a PNG capture
  /// or any image decoding - it walks the [OrderModel] and the
  /// [OrderDetailsModel] list directly and emits plain text commands
  /// through [InvoiceReceiptBuilder].
  ///
  /// The same [PrinterCapabilityProfile] selection used by
  /// [buildTestReceiptBytes] is honoured here so Xprinter XP-N160I,
  /// Rongta, Sunmi, HPRT TP806L, Munbyn ITPP047, Star, Epson and generic
  /// ESC/POS printers all receive the correct command set.
  ///
  /// **The returned ticket already ends with a paper cut** (see
  /// [InvoiceReceiptBuilder.build] and [buildPaperCutBytes]). Callers must
  /// therefore NOT append [buildPaperCutBytes] again — doing so makes the
  /// printer cut twice and eject a blank slip. Pass
  /// `appendPaperCut: false` if you need the receipt body without a cut.
  static Future<List<int>> buildInvoiceBytes({
    required OrderModel? order,
    required List<OrderDetailsModel>? orderDetails,
    required bool isPrescriptionOrder,
    required double dmTips,
    required String paperSize,
    required PrinterModel printer,
    bool debugTiming = false,
    bool appendPaperCut = true,
    // Configurable label for the optional "Additional Charge" row in
    // the totals block. Mirrors `ConfigModel.additionalChargeName` and
    // the on-screen `InvoiceDialogWidget` preview — when non-null and
    // non-empty the label is emitted verbatim above the charge value;
    // otherwise the builder falls back to a generic key.
    String? additionalChargeName,
  }) {
    return InvoiceReceiptBuilder.build(
      order: order,
      orderDetails: orderDetails,
      isPrescriptionOrder: isPrescriptionOrder,
      dmTips: dmTips,
      paperSize: paperSize,
      printer: printer,
      debugTiming: debugTiming,
      appendPaperCut: appendPaperCut,
      additionalChargeName: additionalChargeName,
    );
  }

  static const int _preCutFeedLines = 2;

  /// Canonical ESC/POS paper-cut sequence.
  ///
  /// Bytes: `ESC d n` (feed [feedLines] lines so the printed content
  /// clears the cutter blade) followed by `GS V 0` (full cut).
  ///
  /// The feed is essential: without it the cutter slices through the last
  /// few printed lines because the print head sits several millimetres
  /// above the blade on every thermal mechanism.
  ///
  /// Printers with no auto-cutter silently ignore `GS V`.
  static List<int> buildPaperCutBytes({int feedLines = _preCutFeedLines}) {
    return <int>[0x1B, 0x64, feedLines & 0xFF, 0x1D, 0x56, 0x00];
  }
}
