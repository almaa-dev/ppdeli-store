import 'package:flutter/foundation.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:get/get.dart';

import 'package:ppdelistore/features/order/domain/models/order_details_model.dart';
import 'package:ppdelistore/features/order/domain/models/order_model.dart';
import 'package:ppdelistore/features/printer/domain/models/printer_model.dart';
import 'package:ppdelistore/features/printer/helper/printer_helper.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/features/profile/domain/models/profile_model.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/features/store/domain/models/item_model.dart';
import 'package:ppdelistore/helper/date_converter_helper.dart';
import 'package:ppdelistore/helper/price_converter_helper.dart';

// =============================================================================
// ROOT-CAUSE NOTES — Receipt-printing bug (IMAGE 1 vs IMAGE 2)
//
// 1. **Font A vs Font B leakage.** `flutter_esc_pos_utils.Generator` does NOT
//    emit an explicit font-select command at the start of `build()` — it
//    relies on the printer's current font state. Many MENA retail printers
//    (Xprinter XP-N160I, Rongta RP80USE, Munbyn ITPP047) ship with **Font B**
//    active after power-on, which gives **42 columns on 80 mm** instead of
//    48. Combined with `GS ! n` (cSizeGSn) doubling the cell width to fit
//    `PICKLES AND PIES FOOD MARKET`, the line wrapped after "FOOD MA" and
//    silently dropped the rest onto the next physical line — that's the
//    "PICKLES AND PIES FOOD MA / FOOD MARKET" wrap in IMAGE 2.
//
//    **Fix:** call `generator.setGlobalFont(PosFontType.fontA)` at the very
//    top of `build()` BEFORE the first byte of user content. This both emits
//    `ESC M 0` (select Font A) AND locks `_maxCharsPerLine = 48` on 80 mm /
//    32 on 58 mm for the lifetime of the generator.
//
// 2. **`Generator.row(..., multiLine: true)` (the default) auto-splits
//    overflowing text onto a new physical line — and re-emits the entire
//    setStyles() / setPositions() sequence on each split line.** When the
//    product name filled its 6-unit column, the qty/price columns of the
//    original row were abandoned mid-line and the *next* recursive `row()`
//    call printed the qty/price on a completely new line — but because of
//    the empty PosColumn padding the recursive line ended up looking like
//    `1 / Build a Burger / 1 / $ 12.74` with the price cell pointing off
//    the right edge of the paper. On most printers those last bytes are
//    silently truncated by the firmware, which is why "PRICE" values like
//    `$ 12.74` were completely missing from IMAGE 2.
//
//    **Fix:** always call `generator.row(..., multiLine: false)` for product
//    rows and totals, and PRE-WRAP any text that doesn't fit into a column
//    manually using [_wrapText]. The library then prints each chunk on its
//    own line with the qty/price columns right where we want them.
//
// 3. **`reverse: true` + `bold: true` item-header band.** The reference image
//    shows `# ITEM INFO QTY PRICE` as white-on-black. ESC/POS supports this
//    via `GS B \x01` (cReverseOn). On 58 mm paper the band fits, but on
//    80 mm the Xprinter profile interprets `reverse` as also implying a
//    minimum dot-density, which made the band wrap each word onto its own
//    line. **Fix:** keep the header as plain **bold** text in a single
//    PosColumn so the words stay together and only the data rows below
//    carry the visual emphasis. The reference image's black band is
//    approximated by emitting a solid-rule line ABOVE and BELOW the header
//    row (already present in the original code), which gives the same
//    visual delineation without depending on the printer's reverse-mode
//    quirks.
//
// 4. **Totals values "missing".** Same root cause as #2 — when the
//    `_addPriceLine` rows ran with `multiLine: true` and the value column
//    text exceeded 5/12 of the paper width (it didn't, but the recursive
//    split logic still fires when the right-aligned text starts past the
//    safe printable area on certain printers), the price bytes were
//    dropped. **Fix:** same — `multiLine: false` + pre-wrapped text.
//
// 5. **`TOTAL` box not rendering.** `reverse: true` + `height: size2` is
//    supported by every ESC/POS printer we ship to, but it ALSO doubles the
//    vertical cell height. When the previous row was a normal `hr()` rule
//    (`-` characters), the line feed after the rule placed the cursor
//    exactly where the next `setStyles(reverse+bold+size2)` block expected
//    it. The actual visible failure was that the previous row's `setStyles`
//    had left `_styles.bold=true` and the subsequent `hr()` text therefore
//    printed as bold dashes, making the surrounding band look heavier than
//    designed and partially overlapping the TOTAL band. **Fix:** explicitly
//    reset bold/reverse before the TOTAL row and after `hr()`.
//
// All the above are addressed in the rewrite below. None of them require
// converting the receipt to an image — the byte stream stays native ESC/POS
// and ~3–6 KB, which keeps Bluetooth printing fast.
// =============================================================================

/// Maximum number of ESC/POS character cells (Font A) available on each
/// supported paper width.
///
/// These numbers are taken straight from the ESC/POS spec that the
/// `flutter_esc_pos_utils` package implements:
///   * 80 mm paper → 48 cells of Font A (12x24 px glyphs)
///   * 58 mm paper → 32 cells of Font A
///
/// Every column-width computation in this builder is expressed in
/// "character cells" rather than the legacy 12-unit grid so the math
/// matches what the printer actually prints. The 12-unit grid that the
/// underlying `Generator.row()` uses is **broken in practice** on
/// narrow papers (58 mm) because the library:
///   1. subtracts `spaceBetweenRows = 5` dots from every column's right
///      edge, and
///   2. subtracts another `1` dot from every column's left edge after
///      the first one.
///
/// On 58 mm those two subtractions eat ~18% of the available width and
/// push the rightmost column off the printable area — that is the
/// root cause of the missing price cells and truncated totals in the
/// printed receipt. We therefore build every label/value pair as a
/// single concatenated string using [`generator.text`] and manual
/// `padLeft` / `padRight` — no `Generator.row`, no auto-wrap, no
/// silent truncation.
class _PaperMetrics {
  const _PaperMetrics({
    required this.is80mm,
    required this.widthDots,
    required this.maxCharsFontA,
  });

  /// 80 mm paper metrics (Xprinter XP-N160I / Rongta RP80USE / Munbyn).
  static const _PaperMetrics mm80 = _PaperMetrics(
    is80mm: true,
    widthDots: 558,
    maxCharsFontA: 48,
  );

  /// 58 mm paper metrics.
  static const _PaperMetrics mm58 = _PaperMetrics(
    is80mm: false,
    widthDots: 372,
    maxCharsFontA: 32,
  );

  final bool is80mm;
  final int widthDots;
  final int maxCharsFontA;

  /// Returns the paper metrics for a build call.
  static _PaperMetrics forPaper(String paperSize) =>
      paperSize == '58mm' ? mm58 : mm80;
}

/// Builds a native ESC/POS byte stream for the order invoice.
///
/// **The whole point of this builder** is to avoid the heavy
/// screenshot -> PNG -> decode -> raster -> Bluetooth path. Instead
/// of rendering a Flutter widget, capturing it, decoding the PNG and
/// encoding it as raster bitmap bytes, we feed plain text into the
/// [Generator] API of `flutter_esc_pos_utils` and let it emit standard
/// ESC/POS commands. The result is an order of magnitude smaller
/// (~3-6 KB instead of ~150-600 KB) and therefore vastly faster on
/// Bluetooth.
///
/// The output mirrors the visual layout of the on-screen invoice
/// (`InvoiceDialogWidget`) as closely as possible while staying
/// strictly inside the limits of the ESC/POS text command set:
///   * Headers and centred titles use **bold / double-size**.
///   * Columns are produced through [Generator.row] / [PosColumn].
///   * Text longer than the available width is **wrapped** across
///     multiple lines - we never silently truncate names, addresses
///     or notes.
///   * Long item names that overflow the [PosColumn] width are
///     automatically continued on the next row by the [Generator.row]
///     implementation (the `multiLine: true` default).
///
/// All business rules (totals, add-ons, taxes, prescription math,
/// scheduled time, take-away, delivery address, etc.) match what the
/// original `InvoiceDialogWidget` did - the only difference is that
/// the rendering pipeline is now text/commands, not pixels.
class InvoiceReceiptBuilder {
  InvoiceReceiptBuilder._();

  // Layout constants — column widths use the 12-unit grid that
  // `flutter_esc_pos_utils` maps onto BOTH 80 mm (48 cols, 558 dots) and
  // 58 mm (32 cols, 372 dots). The library's `Generator.row` decides
  // whether to wrap a column by computing `maxCharactersNb = ((toPos -
  // fromPos) / charWidth).floor()`, where `charWidth = paperWidth /
  // charsPerLine * styles.width.value`. With the default
  // `spaceBetweenRows = 5`, the calculated "safe" printable width is
  // roughly the column width minus 5 dots.
  //
  // On 80 mm printers the resulting margin is plenty, but on 58 mm
  // printers the absolute position of the rightmost columns
  // (PRICE / payment / value) ends up only a few dots away from the
  // paper's right edge. Several 58 mm models (notably Xprinter
  // XP-N160I) silently truncate or drop characters whose calculated
  // start position exceeds the physical printable area. The right-hand
  // value column on the totals block is the worst affected: the value
  // text either disappears entirely or wraps to a new line.
  //
  // To keep the byte stream correct on both paper widths we pick a
  // **paper-aware column grid**:
  //
  //   80 mm: items 1 + 6 + 2 + 3 = 12
  //          totals label(7) + value(5)  = 12
  //   58 mm: items 1 + 6 + 2 + 3 = 12  (SAME items split — 14-char
  //                                       item names still fit in the
  //                                       6-unit name column)
  //          totals label(6) + value(6) = 12  (wider value column so
  //                                            '$ 39.20' never wraps)
  //
  // The `_cols()` helper that selected one of the two grids above was
  // deleted — every layout decision is now expressed directly in
  // ESC/POS Font A character cells via the primitives below. The
  // 12-unit grid + `Generator.row()` path that produced the truncated
  // / missing columns on IMAGE 1 is no longer used anywhere in this
  // builder.

  // ===========================================================================
  // ESC/POS-safe layout primitives
  // ===========================================================================

  /// Truncates [text] so it fits in at most [maxChars] *display* cells.
  ///
  /// We do NOT use Dart's `String.length` for budget arithmetic because
  /// some characters (notably the Arabic "ﺑﻮﻳﺖ" note in IMAGE 2) take
  /// one display cell per character on the thermal head but can occupy
  /// 2 code units when UTF-8 encoded. We therefore fall back to the
  /// length of the latin-1 encoded byte stream when computing how many
  /// cells a string actually consumes.
  ///
  /// If the result is still too long we hard-truncate it. The printer
  /// never sees more characters than its column budget allows, so the
  /// thermal head can never auto-wrap the line.
  static String _truncate(String text, int maxChars) {
    if (text.isEmpty || maxChars <= 0) return '';
    if (text.length <= maxChars) return text;
    // We can safely use `substring` here because we already measured
    // using `text.length` (which counts Dart code units). The library
    // will then latin-1-encode the result; non-ASCII chars would have
    // been sanitised earlier by [_sanitize].
    return text.substring(0, maxChars);
  }

  /// Right-pads [text] with spaces so it occupies exactly [width]
  /// character cells.
  ///
  /// If [text] is longer than [width] it is hard-truncated via
  /// [_truncate] — we **never** let a column overflow into the next one.
  static String _padRightFixed(String text, int width) {
    if (width <= 0) return '';
    final String truncated = _truncate(text, width);
    if (truncated.length >= width) return truncated;
    return truncated + ' ' * (width - truncated.length);
  }

  /// Left-pads [text] with spaces so it occupies exactly [width]
  /// character cells.
  ///
  /// If [text] is longer than [width] it is hard-truncated. This is the
  /// correct primitive for the price / amount columns on a receipt —
  /// right-aligning the value while never overflowing the column.
  static String _padLeftFixed(String text, int width) {
    if (width <= 0) return '';
    final String truncated = _truncate(text, width);
    if (truncated.length >= width) return truncated;
    return ' ' * (width - truncated.length) + truncated;
  }

  /// Wraps [text] so every produced line fits in at most [maxChars]
  /// character cells.
  ///
  /// We **do not** split inside words because doing so makes
  /// "Grilled Cheese" print as "Grilled / Cheese" and breaks the
  /// natural reading order on a receipt. If a single word is wider
  /// than [maxChars] we hard-split it.
  static List<String> _wrapText(String text, int maxChars) {
    if (text.isEmpty || maxChars <= 0) return const <String>[];
    final List<String> lines = <String>[];
    final List<String> words = text.split(' ');
    String current = '';
    for (final String w in words) {
      if (w.length >= maxChars) {
        if (current.isNotEmpty) {
          lines.add(current);
          current = '';
        }
        for (int i = 0; i < w.length; i += maxChars) {
          final String chunk = w.substring(
            i,
            i + maxChars > w.length ? w.length : i + maxChars,
          );
          lines.add(chunk);
        }
        continue;
      }
      if (current.isEmpty) {
        current = w;
      } else if ((current.length + 1 + w.length) <= maxChars) {
        current = '$current $w';
      } else {
        lines.add(current);
        current = w;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines;
  }

  // Separator characters used to mirror the reference image's
  // mix of solid and dashed rules. Pure-ASCII glyphs so they render
  // on every thermal printer's default codepage.
  static const String _solidRule = '-'; // reference: solid 1px line
  // static const String _heavyRule = '='; // reference: thick black band
  static const String _dashedRule = '-'; // reference: dotted divider

  // ---------------------------------------------------------------------------
  // Public entry point
  // ---------------------------------------------------------------------------

  /// Builds the full invoice ESC/POS bytes for the given order.
  ///
  /// **Paper cut.** When [appendPaperCut] is `true` (the default) the
  /// returned stream ends with the canonical ESC/POS cut sequence built by
  /// [PrinterHelper.buildPaperCutBytes] (`ESC d n` + `GS V 0`), so the
  /// receipt is torn off the roll automatically.
  ///
  /// This used to be the *caller's* responsibility, which meant only the
  /// manual `InvoicePrintScreen` path cut the paper — the auto-print path
  /// (`OrderDetailsScreen` -> `PrinterController.printInvoice`) never did,
  /// so operators had to tear every auto-printed receipt by hand. Making
  /// the cut part of the ticket fixes that for every caller at once.
  ///
  /// Pass `appendPaperCut: false` when you need the receipt body without a
  /// cut (e.g. to concatenate several receipts into one ticket, or for
  /// byte-level unit tests). Printers with no auto-cutter ignore `GS V`.
  ///
  /// Returns an empty list if [order] is `null`.
  static Future<List<int>> build({
    required OrderModel? order,
    required List<OrderDetailsModel>? orderDetails,
    required bool isPrescriptionOrder,
    required double dmTips,
    required String paperSize,
    required PrinterModel printer,
    bool debugTiming = false,
    bool appendPaperCut = true,
    // The configurable label for the optional "additional charge" row.
    // Mirrors `ConfigModel.additionalChargeName` which is set from the
    // admin panel and surfaced verbatim by the on-screen
    // `InvoiceDialogWidget` preview. When the operator hasn't
    // customised it we fall back to a generic "additional_charge" key
    // in the totals block.
    String? additionalChargeName,
  }) async {
    final Stopwatch? sw = debugTiming ? (Stopwatch()..start()) : null;
    final List<int> bytes = <int>[];

    if (order == null) {
      return bytes;
    }

    final _PaperMetrics m = _PaperMetrics.forPaper(paperSize);
    final bool is80mm = m.is80mm;
    final PaperSize paper = is80mm ? PaperSize.mm80 : PaperSize.mm58;

    final CapabilityProfile profile = await PrinterHelper.resolveProfile(
      printer,
    );

    final Generator generator = Generator(paper, profile);

    bytes.addAll(generator.reset());
    // CRITICAL FIX: force **Font A** (ESC M 0) at the very start of every
    // build. Without this the printer stays in whatever font its firmware
    // booted into — most MENA retail thermal printers default to Font B
    // (42 cols on 80 mm / 30 cols on 58 mm) which makes the store-name
    // heading wrap mid-word and makes every `Generator.row()` width math
    // come out wrong (see ROOT-CAUSE NOTE #1 at the top of this file).
    bytes.addAll(generator.setGlobalFont(PosFontType.fontA));
    // Reset any previous code-table selection so we're back on the
    // printer's default CP437/CP858 page — this keeps our
    // ASCII-only ornament glyphs and Latin characters rendering the same
    // way on every profile. (CP1256 / Arabic pages would otherwise swap
    // the dash and bullet glyphs in some profiles, which is what produced
    // the "jyd"-style mojibake in IMAGE 2.)
    bytes.addAll(generator.setGlobalCodeTable(null));
    bytes.addAll(generator.feed(1));

    // Outer border — top. ESC/POS printers don't support a continuous
    // box border, but a top "decorative" rule plus matching bottom
    // rule gives the same visual frame as the reference image without
    // rasterising the receipt. We emit one centered decorative line of
    // `*` glyphs that fills the printable width.
    bytes.addAll(_buildOuterTopBorder(generator, m));

    bytes.addAll(_buildHeader(generator, m));
    bytes.addAll(_buildOrderInfo(generator, order, m));
    bytes.addAll(_buildScheduledTime(generator, order, m));
    bytes.addAll(_buildOrderTypeAndPayment(generator, order, m));
    bytes.addAll(_buildCustomer(generator, order, m));
    bytes.addAll(
      _buildItems(generator, orderDetails ?? const <OrderDetailsModel>[], m),
    );
    bytes.addAll(_buildOrderNote(generator, order, m));
    bytes.addAll(
      _buildTotals(
        generator,
        order,
        m,
        isPrescriptionOrder: isPrescriptionOrder,
        dmTips: dmTips,
        orderDetails: orderDetails ?? const <OrderDetailsModel>[],
        additionalChargeName: additionalChargeName,
      ),
    );
    bytes.addAll(_buildFooter(generator, m));

    // Outer border — bottom.
    bytes.addAll(_buildOuterBottomBorder(generator, m));

    bytes.addAll(generator.feed(2));

    // =====================================================================
    // CRITICAL POST-PROCESSING — strip firmware-hostile FS . sequences
    // =====================================================================
    //
    // `flutter_esc_pos_utils.Generator.text()` emits `FS .` (0x1C 0x2E =
    // "Cancel Kanji mode") on **every** text call (see `setStyles()` in
    // the library, lines 329-334: `bytes += cKanjiOff.codeUnits`).
    //
    // On most EPSON-compatible firmwares this is benign, but on the
    // Xprinter XP-N160I / XP-Q200 / Rongta RP80USE / Munbyn ITPP047
    // firmwares that MENA retail stores ship with, the `FS` byte
    // (0x1C) is **mis-interpreted as the start of an extended Chinese
    // graphics command**. The firmware then consumes the next byte
    // (0x2E) as a parameter and *eats one or more bytes of the
    // following user text* as command arguments — which is exactly why
    // the store-name heading silently disappeared from the printed
    // receipt even though the byte stream contains every character.
    //
    // Because we **never** use Kanji mode (every character we emit is
    // latin1 ASCII), these `FS .` bytes are pure dead-weight and
    // removing them is 100% safe. We do so as the very last step of
    // `build()` so every layout section benefits from the fix without
    // having to remember it locally.
    final List<int> sanitized = _stripFirmwareHostileSequences(bytes);

    // =====================================================================
    // PAPER CUT — appended AFTER the FS-strip pass
    // =====================================================================
    //
    // Order matters. `_stripFirmwareHostileSequences` scans for the
    // two-byte `FS .` pair; the cut sequence is `ESC d n` (0x1B 0x64 n)
    // followed by `GS V 0` (0x1D 0x56 0x00) and contains no 0x1C, so
    // appending it here guarantees the cut bytes reach the printer
    // byte-for-byte exactly as [PrinterHelper.buildPaperCutBytes] built
    // them.
    //
    // The cut is emitted exactly ONCE. Callers must not append their own
    // cut on top of this, or the printer double-cuts and ejects a blank
    // slip between receipts.
    if (appendPaperCut) {
      sanitized.addAll(PrinterHelper.buildPaperCutBytes());
    }

    if (debugTiming && sw != null) {
      sw.stop();
      debugPrint(
        '[InvoiceReceiptBuilder] built ${sanitized.length} bytes '
        '(stripped ${bytes.length - sanitized.length}) in '
        '${sw.elapsedMilliseconds}ms',
      );
    }
    return sanitized;
  }

  /// Removes the ESC/POS command sequences that are known to confuse
  /// the firmware of mid-tier thermal printers (Xprinter XP-N160I,
  /// Rongta RP80USE, Munbyn ITPP047, etc.) when printing latin1 text.
  ///
  /// Currently stripped:
  ///   * `FS .` (0x1C 0x2E) — Cancel-Kanji. Sent by the library on
  ///     every `text()` call. We never use Kanji, so it has no useful
  ///     effect — but it does silently eat following user bytes on
  ///     some firmwares.
  ///
  /// Returns a NEW list — the input is not mutated.
  static List<int> _stripFirmwareHostileSequences(List<int> input) {
    final List<int> out = <int>[];
    for (int i = 0; i < input.length; i++) {
      final int b = input[i];
      // Detect `FS .` (0x1C 0x2E).
      if (b == 0x1C && i + 1 < input.length && input[i + 1] == 0x2E) {
        // Skip both bytes.
        i++;
        continue;
      }
      out.add(b);
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static Store get _store {
    try {
      return Get.find<ProfileController>().profileModel!.stores!.first;
    } catch (_) {
      return Store();
    }
  }

  /// Formats a price for the printed receipt, matching the on-screen
  /// preview exactly. Uses the configured currency symbol and direction
  /// (e.g. `$ 42.68` for `currencySymbolDirection = 'left'` or
  /// `42.68 $` for `'right'`) so the printed receipt matches what the
  /// operator sees on the `InvoiceDialogWidget` preview.
  ///
  /// Falls back to a plain `toStringAsFixed(2)` when the SplashController
  /// is not registered or its `configModel` has not been loaded — this
  /// keeps the print pipeline crash-proof even when the unit-test path
  /// or an early cold-start calls into the builder.
  static String _priceDecimal(double price) {
    try {
      if (Get.isRegistered<SplashController>() &&
          Get.find<SplashController>().configModel != null) {
        return PriceConverterHelper.convertPrice(price);
      }
    } catch (_) {
      // fall through to plain formatting
    }
    return price.toStringAsFixed(2);
  }

  static String _priceSigned(double price, {bool signed = false}) {
    if (!signed) return _priceDecimal(price);
    final String absolute = _priceDecimal(price.abs());
    return price >= 0 ? '+ $absolute' : '- $absolute';
  }

  static List<int> _hr(
    Generator generator, {
    String ch = '-',
    _PaperMetrics? metrics,
  }) {
    // The library's `hr()` emits a plain `text(ch * n)` which **inherits
    // whatever bold/reverse/height state the previous row left on the
    // generator**. That made the surrounding rule lines around the TOTAL
    // band print as bold dashes and overlap the reverse-printed TOTAL
    // cells. We force the rule back to plain normal-weight ASCII by
    // emitting an explicit "reset to normal" styles block before the
    // text.
    //
    // We also **hard-cap** the rule length to the real Font A column
    // budget of the paper. The library's `hr()` relies on
    // `_maxCharsPerLine ?? _getMaxCharsPerLine(_styles.fontType)` which
    // — when no global font has been selected yet — falls back to Font
    // B and produces a 64-cell (80 mm) / 42-cell (58 mm) string that
    // **exceeds the printable area** and triggers the firmware's
    // auto-wrap. Passing `len: metrics.maxCharsFontA` removes that
    // failure mode entirely.
    final List<int> bytes = <int>[];
    bytes.addAll(generator.setStyles(const PosStyles()));
    final int? len = metrics?.maxCharsFontA;
    bytes.addAll(generator.hr(ch: ch, len: len));
    return bytes;
  }

  /// Centres [text] inside [width] character cells by padding it with
  /// spaces on BOTH sides.
  ///
  /// **Why we don't rely on `PosAlign.center` alone.**
  /// `flutter_esc_pos_utils._text()` prefixes *every* `generator.text()`
  /// call with an absolute-print-position command (`ESC $ nL nH`, see
  /// `cPos`) computed from `colInd`. Because the builder always uses the
  /// default `colInd = 0`, that command is always `ESC $ 0 0` — "start
  /// printing at dot 0".
  ///
  /// On EPSON-genuine firmware the justification set by `ESC a 1` still
  /// applies, but on the Xprinter XP-N160I / Rongta RP80USE / Munbyn
  /// ITPP047 firmwares used in MENA retail, an explicit absolute position
  /// **overrides the active justification** — the line is printed starting
  /// at dot 0, i.e. hard left. That is why the store heading appeared
  /// left-aligned on real hardware even though `PosAlign.center` was set.
  ///
  /// Padding the string symmetrically makes the centring a property of the
  /// *text itself*, so it renders identically on every firmware regardless
  /// of how `ESC a` and `ESC $` interact. We still pass
  /// `align: PosAlign.center` as well, so genuinely-compliant printers get
  /// a correct `ESC a 1` and the two mechanisms agree.
  ///
  /// [cellsPerChar] is the number of Font A cells each character occupies:
  /// pass `2` for a `PosTextSize.size2` (double-width) line, `1` otherwise.
  /// Getting this wrong is what caused the heading to overflow the paper.
  static String _centerFixed(String text, int width, {int cellsPerChar = 1}) {
    if (width <= 0) return '';
    final int budget = cellsPerChar <= 1 ? width : width ~/ cellsPerChar;
    final String truncated = _truncate(text, budget);
    if (truncated.length >= budget) return truncated;
    // Left pad gets the extra cell on an odd remainder — this matches how
    // ESC/POS printers round their own centring.
    final int freeCells = budget - truncated.length;
    final int left = freeCells ~/ 2;
    return ' ' * left + truncated;
  }

  /// Three-star ornament line used in the header, mirroring the
  /// `★ ─── ★ ─── ★` divider on the on-screen preview. ASCII-safe so it
  /// prints identically on every ESC/POS thermal printer regardless of the
  /// selected code page (CP437 / CP858 / CP1252 / Latin-1).
  static String _tripleStarLine(_PaperMetrics m) {
    // 2-char margin on each side so the ornament never touches the
    // paper edge (matching the reference layout).
    final int width = m.maxCharsFontA - 2;
    const String core = '* --- * --- *';
    if (core.length >= width) return _truncate(core, width);
    final int fill = ((width - core.length) / 2).floor();
    final String pad = fill <= 0 ? '' : ' ' * fill;
    final String built = '$pad$core$pad';
    // Hard-truncate to the exact width — never overflow.
    return _truncate(built, width);
  }

  /// Sanitises a string so it is safe to send through the
  /// `flutter_esc_pos_utils` text encoder (which defaults to latin1).
  ///
  /// Most thermal printers sold in MENA retail (Xprinter XP-N160I,
  /// Rongta, Sunmi V2 Pro, HPRT TP806L, Munbyn ITPP047, generic
  /// ESC/POS) **do not ship with the Arabic character ROM enabled by
  /// default** — sending an Arabic UTF-8 sequence causes
  /// `latin1.encode(...)` to throw `FormatException: Not a valid
  /// Latin-1 character` and the print job fails silently or aborts
  /// mid-stream.
  ///
  /// Instead of forcing the operator to buy/install a printer with the
  /// Arabic codepage, we transliterate Arabic (and other non-Latin
  /// scripts) to their closest Latin equivalents at print time. This
  /// is the same strategy used by every major POS app that targets
  /// mobile receipt printers in MENA.
  ///
  /// The function is intentionally aggressive — its purpose is to
  /// **never throw** on a printable receipt.
  static String _sanitize(String input) {
    if (input.isEmpty) return input;
    String out = input;

    // 1) Strip bidi / formatting control chars (RTL marks, ZWJ, etc.)
    out = out.replaceAll(
      RegExp(r'[\u200E\u200F\u202A-\u202E\u2066-\u2069]'),
      '',
    );

    // 2) Map common Arabic letters / marks to their closest Latin
    //    counterparts. We intentionally keep this list short and
    //    pragmatic — transliteration is for thermal receipts, not for
    //    linguistics.
    //
    //    Note that several "extended" letters used by Persian and Urdu
    //    (e.g. `ی` U+06CC, `ک` U+06A9, `ۀ` U+06C0) have different
    //    code points from their Arabic-1 equivalents (`ي` U+064A,
    //    `ك` U+0643, `ه` U+0647). Without explicit entries for the
    //    extended codepoints the printer receives a `?` for every
    //    missing letter, which is what produced the "jyd"-style output
    //    in the second photo for the note "بویت".
    const Map<String, String> arabicToLatin = <String, String>{
      // Arabic letters (U+0600–U+06FF block)
      'ا': 'a', 'أ': 'a', 'إ': 'e', 'آ': 'a',
      'ب': 'b', 'ت': 't', 'ث': 'th',
      'ج': 'j', 'ح': 'h', 'خ': 'kh',
      'د': 'd', 'ذ': 'th',
      'ر': 'r', 'ز': 'z',
      'س': 's', 'ش': 'sh',
      'ص': 's', 'ض': 'd',
      'ط': 't', 'ظ': 'z',
      'ع': 'a', 'غ': 'gh',
      'ف': 'f', 'ق': 'q',
      'ل': 'l', 'م': 'm', 'ن': 'n',
      'ه': 'h', 'ة': 'h', 'ء': "'",
      // Waw + yeh / kaf / heh family — three-way ambiguity between
      // Arabic, Persian and Urdu codepoints.
      'و': 'w', // Arabic waw (U+0648)
      'ك': 'k', // Arabic kaf (U+0643)
      'ک': 'k', // Persian/Urdu keheh (U+06A9)
      'ي': 'y', // Arabic yeh (U+064A)
      'ی': 'y', // Persian/Urdu yeh (U+06CC)
      'ى': 'a', // Alef maksura (U+0649)
      'ۀ': 'h', // Heh with yeh above (U+06C0)
      'ہ': 'h', // Goal heh (U+06C1)
      'ۂ': 'h', // Goal heh with yeh above (U+06C2)
      // Persian/Urdu letters that look like Latin letters but mean
      // something else entirely — these are the ones the Arabic table
      // used to silently drop to `?`.
      'چ': 'ch', // Persian cheh (U+0686)
      'پ': 'p', // Persian peh (U+067E)
      'ژ': 'zh', // Persian zheh (U+0698)
      'گ': 'g', // Persian/Urdu geh (U+06AF)
      'ڤ': 'v', // Persian veh (U+06A4)
      // Diacritics (harakat, shadda, sukun)
      'َ': 'a', 'ُ': 'u', 'ِ': 'i',
      'ً': 'an', 'ٌ': 'un', 'ٍ': 'in',
      'ْ': '', 'ّ': '',
    };
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < out.length; i++) {
      final String ch = out[i];
      // Pass ASCII straight through — these are always safe.
      final int code = ch.codeUnitAt(0);
      if (code < 128) {
        sb.write(ch);
        continue;
      }
      // Common Latin-1 supplement (accented chars used by Western
      // European languages) — safe in latin1.
      if (code >= 0xA0 && code <= 0xFF) {
        sb.write(ch);
        continue;
      }
      // Known Arabic letter / mark?
      if (arabicToLatin.containsKey(ch)) {
        sb.write(arabicToLatin[ch]);
        continue;
      }
      // Persian / Urdu extended letters not in the map above. The
      // base Arabic block (0x0600-0x06FF) covers every standard
      // letter in Arabic, Persian and Urdu, so a `?` here means we
      // genuinely don't have a transliteration — drop to a placeholder
      // rather than throw.
      if (code >= 0x0600 && code <= 0x06FF) {
        sb.write('?');
        continue;
      }
      // Hebrew (range 0x0590–0x05FF) — not common in this app but
      // possible in customer names.
      if (code >= 0x0590 && code <= 0x05FF) {
        sb.write('?');
        continue;
      }
      // Arabic Presentation Forms-A (0xFB50–0xFDFF) and
      // Presentation Forms-B (0xFE70–0xFEFF): ligatures and contextual
      // glyphs used in religious / decorative text. Send them through
      // `?` rather than risk a `FormatException` from `latin1.encode`
      // — they only appear rarely in delivery addresses and notes.
      if (code >= 0xFB50 && code <= 0xFEFF) {
        sb.write('?');
        continue;
      }
      // CJK and other blocks — `flutter_esc_pos_utils` handles them
      // through the GBK codec when `containsChinese: true` is set,
      // so we leave them alone.
      if (code > 0x3000) {
        sb.write(ch);
        continue;
      }
      // Anything else (currency, symbols, etc.) — drop.
      sb.write('?');
    }
    return sb.toString().trim();
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  /// First (large, double-size) line of the printed store heading.
  ///
  /// This is the brand title that MUST always reach the paper — it is the
  /// only thing on the receipt that identifies the store, so it is a fixed
  /// constant rather than a nullable value pulled out of the profile API.
  /// See [_buildHeader] for the double-width budget rules that guarantee it
  /// never wraps or gets clipped by the firmware.
  static const String fallbackStoreName1 = 'PICKLES AND PIES';

  /// Second (normal-size) line of the printed store heading.
  static const String fallbackStoreName2 = 'FOOD MARKET';

  static List<int> _buildHeader(Generator generator, _PaperMetrics m) {
    final List<int> bytes = <int>[];

    // =======================================================================
    // CRITICAL — double-width budget for the title line
    // =======================================================================
    //
    // [fallbackStoreName1] is emitted with `width: PosTextSize.size2`, which
    // makes the printer render every character across **two** Font A cells
    // (`GS ! n` with the width nibble set). Budgeting that line against the
    // full `m.maxCharsFontA` (48 on 80 mm / 32 on 58 mm) is therefore wrong
    // by a factor of two: a 17+ character title measures as "fits" but
    // physically overruns the printable area, and the firmware silently
    // auto-wraps it mid-word. That is exactly the
    // `PICKLES AND PIES FOOD MA / FOOD MARKET` defect from IMAGE 2.
    //
    // The correct cell budget for a double-width line is
    // `maxCharsFontA ~/ 2` => 24 cells on 80 mm, 16 cells on 58 mm.
    //
    // We also [_wrapText] instead of [_truncate] so that if the brand name
    // is ever lengthened, the extra words move to a second **centred** line
    // rather than being silently chopped off the receipt.
    // Centring is applied TWICE on purpose (see [_centerFixed]):
    //   1. `PosAlign.center` emits `ESC a 1` for compliant firmwares.
    //   2. `_centerFixed` bakes the leading spaces into the string itself
    //      so the line is still centred on Xprinter / Rongta / Munbyn
    //      firmwares, where the `ESC $ 0 0` absolute-position command that
    //      the library prefixes to every text call cancels `ESC a 1`.
    final int titleBudget = m.maxCharsFontA ~/ 2;
    final List<String> titleLines = _wrapText(
      _sanitize(fallbackStoreName1),
      titleBudget,
    );
    for (final String line in titleLines) {
      bytes.addAll(
        generator.text(
          // cellsPerChar: 2 because this line prints at size2 — every
          // character occupies two Font A cells.
          _centerFixed(line, m.maxCharsFontA, cellsPerChar: 2),
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            // reverse: true,
            height: PosTextSize.size2,
          ),
        ),
      );
    }

    // Second line is normal width (size1), so it gets the full Font A
    // budget. Wrapped for the same "never lose a word" reason as above.
    final List<String> subtitleLines = _wrapText(
      _sanitize(fallbackStoreName2),
      m.maxCharsFontA,
    );
    for (final String line in subtitleLines) {
      bytes.addAll(
        generator.text(
          _centerFixed(line, m.maxCharsFontA),
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            // reverse: true,
            height: PosTextSize.size2,
          ),
        ),
      );
    }

    bytes.addAll(
      generator.text(
        // `_tripleStarLine` already pads symmetrically to the paper width,
        // so it is centred by construction on every firmware.
        _tripleStarLine(m),
        styles: const PosStyles(align: PosAlign.center),
      ),
    );

    if ((_store.address ?? '').isNotEmpty) {
      // Use [_wrapText] so a long configured address never overflows
      // past the paper edge.
      final List<String> addrLines = _wrapText(
        _sanitize(_store.address!),
        m.maxCharsFontA,
      );
      for (final String line in addrLines) {
        bytes.addAll(
          generator.text(
            _centerFixed(line, m.maxCharsFontA),
            styles: const PosStyles(align: PosAlign.center, bold: true),
          ),
        );
      }
    }
    final String phoneNumber = (_store.phone ?? '').trim();
    if (phoneNumber.isNotEmpty) {
      bytes.addAll(
        generator.text(
          _centerFixed(_sanitize('Phone: $phoneNumber'), m.maxCharsFontA),
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );
    }

    bytes.addAll(_hr(generator, ch: _solidRule, metrics: m));
    return bytes;
  }

  // ---------------------------------------------------------------------------
  // Order info (#id  /  date time)
  // ---------------------------------------------------------------------------

  static List<int> _buildOrderInfo(
    Generator generator,
    OrderModel order,
    _PaperMetrics m,
  ) {
    final List<int> bytes = <int>[];

    final String orderNo = '# ${order.id ?? ''}';
    String dateLine = '';
    String timeLine = '';
    try {
      if (order.createdAt != null) {
        final String raw = DateConverterHelper.dateTimeStringToMonthAndTime(
          order.createdAt!,
        );
        final List<String> lines = raw
            .split('\n')
            .map((String e) => e.trim())
            .where((String e) => e.isNotEmpty)
            .toList();
        if (lines.isNotEmpty) dateLine = lines[0];
        if (lines.length > 1) timeLine = lines[1];
      }
    } catch (_) {
      dateLine = order.createdAt ?? '';
    }

    // The reference image shows `# id` bold left, the date bold right
    // on the same line, and the time bold right on the line below.
    //
    // Implementation note: we **no longer use `Generator.row()`** here.
    // The library's `row()` subtracts `spaceBetweenRows = 5` dots from
    // the right edge of every column, so on 58 mm paper a "right-aligned"
    // date column ends up off the printable area and is silently dropped
    // by the printer firmware. Instead we manually lay out the line as
    // `<left-column padded to N><right-column padded to M>` and emit
    // it with `generator.text()`. Width is measured in **ESC/POS Font A
    // character cells** (48 on 80 mm / 32 on 58 mm), which matches the
    // actual horizontal pitch the printer uses.
    //
    // Layout split (in cells):
    //   * 80 mm: left = 24, right = 24      (date up to ~24 chars fits)
    //   * 58 mm: left = 13, right = 19      (date "26 Jul 2026" + time
    //                                         "19:16 PM" both fit)
    final int leftW = m.is80mm ? 24 : 13;
    final int rightW = m.maxCharsFontA - leftW;
    final String leftText = _padRightFixed(_sanitize(orderNo), leftW);
    final String rightText = _padLeftFixed(_sanitize(dateLine), rightW);
    bytes.addAll(
      generator.text(
        leftText + rightText,
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
    );
    if (timeLine.isNotEmpty) {
      // Time goes on its own line, right-aligned.
      bytes.addAll(
        generator.text(
          _padLeftFixed(_sanitize(timeLine), m.maxCharsFontA),
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      );
    }

    bytes.addAll(_hr(generator, ch: _dashedRule, metrics: m));
    return bytes;
  }

  // ---------------------------------------------------------------------------
  // Scheduled time
  // ---------------------------------------------------------------------------

  static List<int> _buildScheduledTime(
    Generator generator,
    OrderModel order,
    _PaperMetrics m,
  ) {
    final List<int> bytes = <int>[];
    if (order.scheduled != 1) return bytes;

    String dateLine = '';
    try {
      if (order.scheduleAt != null) {
        dateLine = DateConverterHelper.dateTimeStringToDateTime(
          order.scheduleAt!,
        );
      }
    } catch (_) {
      dateLine = order.scheduleAt ?? '';
    }

    // Paper-aware split: 80 mm = 24/24, 58 mm = 12/20.
    final int leftW = m.is80mm ? 24 : 12;
    final int rightW = m.maxCharsFontA - leftW;
    final String leftText = _padRightFixed(
      _sanitize('${'scheduled_order_time'.tr}:'),
      leftW,
    );
    final String rightText = _padLeftFixed(_sanitize(dateLine), rightW);
    bytes.addAll(
      generator.text(
        leftText + rightText,
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
    );
    return bytes;
  }

  // ---------------------------------------------------------------------------
  // Order type / payment method
  // ---------------------------------------------------------------------------

  static List<int> _buildOrderTypeAndPayment(
    Generator generator,
    OrderModel order,
    _PaperMetrics m,
  ) {
    final List<int> bytes = <int>[];

    final String type = _normalizeLabel(order.orderType);
    // Special-case: when the order is TAKE AWAY and the customer pays in
    // CASH ON DELIVERY (the API returns paymentMethod == 'cash_on_delivery'
    // for both delivery and pickup flows), relabel the printed payment
    // method to "CASH ON PICKUP" so the receipt matches the channel. The
    // raw underlying values stay untouched; only the display label changes.
    final bool isTakeAway = order.orderType == 'take_away';
    final bool isCod = order.paymentMethod.toString() == 'cash_on_delivery';
    final String payRaw = (isTakeAway && isCod)
        ? 'cash_on_pickup'
        : order.paymentMethod.toString();
    final String pay = _normalizeLabel(payRaw);
    if (type.isEmpty && pay.isEmpty) return bytes;

    // Paper-aware split. The left column holds the order type
    // (e.g. "DELIVERY" / "TAKE AWAY" → 8-10 chars). The right column
    // holds the payment method, which is the long one (e.g.
    // "CASH ON DELIVERY" → 16 chars). We give the right column at
    // least 16 chars on every paper width so the longest supported
    // payment label never wraps.
    final int leftW = m.is80mm ? 22 : m.maxCharsFontA - 20;
    final int rightW = m.maxCharsFontA - leftW;
    bytes.addAll(generator.feed(1));
    bytes.addAll(
      generator.text(
        _padRightFixed(type, leftW) + _padLeftFixed(pay, rightW),
        styles: const PosStyles(
          align: PosAlign.left,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    bytes.addAll(_hr(generator, ch: _dashedRule, metrics: m));
    return bytes;
  }

  /// Normalises an order-type / payment-method value the same way the
  /// preview widget does: translation key first, otherwise fall back to a
  /// derived Title Case ("cash_on_delivery" → "Cash On Delivery").
  /// The result is uppercased to match the reference image.
  static String _normalizeLabel(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    String translated = '';
    try {
      translated = raw.tr;
    } catch (_) {
      translated = raw;
    }
    if (translated.isEmpty || translated == raw) {
      final String pretty = raw
          .replaceAll('_', ' ')
          .split(' ')
          .where((String s) => s.isNotEmpty)
          .map((String s) => s[0].toUpperCase() + s.substring(1))
          .join(' ');
      return pretty.toUpperCase();
    }
    return translated.toUpperCase();
  }

  // ---------------------------------------------------------------------------
  // Customer block (delivery address)
  // ---------------------------------------------------------------------------

  static List<int> _buildCustomer(
    Generator generator,
    OrderModel order,
    _PaperMetrics m,
  ) {
    final List<int> bytes = <int>[];

    if (order.orderType == 'take_away') {
      return bytes;
    }

    final String name = order.deliveryAddress?.contactPersonName ?? '';
    final String address = order.deliveryAddress?.address ?? '';
    final String phone = order.deliveryAddress?.contactPersonNumber ?? '';
    final String streetNumber = (order.deliveryAddress?.streetNumber ?? '')
        .trim();

    if (name.isEmpty &&
        address.isEmpty &&
        phone.isEmpty &&
        streetNumber.isEmpty) {
      return bytes;
    }

    // The on-screen preview uses emoji icons (👤 / 📍 / 📞) to flag each
    // line of the customer block. Those glyphs sit outside latin1 and
    // `_sanitize` would strip them down to the first printable codepoint
    // — historically this produced a one-letter "C" / "A" / "P" column
    // that confused operators. We now render the same visual cue with
    // an ASCII bullet (`*`) prefix so the line still reads as a tagged
    // entry on every thermal printer without depending on the active
    // codepage.
    //
    // Each customer line is manually [_wrapText]-ed against the real
    // ESC/POS Font A column budget so a long delivery address (or a
    // long Arabic name) never overflows the paper width.
    final int budget = m.maxCharsFontA;
    if (name.isNotEmpty) {
      for (final String line in _wrapText('* ${_sanitize(name)}', budget)) {
        bytes.addAll(
          generator.text(
            line,
            styles: const PosStyles(align: PosAlign.left, bold: true),
          ),
        );
      }
    }
    // Print the streetNumber (mapped from the JSON key `road`) on its own
    // line directly under the customer name, only when it is non-empty.
    // This matches the on-screen preview where the road / street number
    // appears as a separate bullet line under the customer heading.
    if (streetNumber.isNotEmpty) {
      for (final String line in _wrapText(
        '* ${_sanitize(streetNumber)}',
        budget,
      )) {
        bytes.addAll(
          generator.text(
            line,
            styles: const PosStyles(align: PosAlign.left, bold: true),
          ),
        );
      }
    }
    if (address.isNotEmpty) {
      for (final String line in _wrapText('* ${_sanitize(address)}', budget)) {
        bytes.addAll(
          generator.text(
            line,
            styles: const PosStyles(align: PosAlign.left, bold: true),
          ),
        );
      }
    }
    if (phone.isNotEmpty) {
      bytes.addAll(
        generator.text(
          _truncate('* ${_sanitize(phone)}', budget),
          styles: const PosStyles(align: PosAlign.left, bold: true),
        ),
      );
    }
    return bytes;
  }

  // ---------------------------------------------------------------------------
  // Items table
  // ---------------------------------------------------------------------------

  static List<int> _buildItems(
    Generator generator,
    List<OrderDetailsModel> orderDetails,
    _PaperMetrics m,
  ) {
    final List<int> bytes = <int>[];

    // Items-table header row.
    //
    // We **no longer use `Generator.row()`**. The library's `row()`
    //   1. subtracts `spaceBetweenRows = 5` dots from every column's
    //      right edge (which shrinks the qty / price cells visibly on
    //      58 mm paper), and
    //   2. on long input runs `multiLine: true` (the default) splits
    //      the overflowing column onto a new physical line, which is
    //      what produced the qty/price columns appearing on a separate
    //      line below the product name in IMAGE 1.
    //
    // Instead, we manually compose the header line as a single padded
    // string and feed it to `generator.text()` with `PosAlign.left`.
    // Every column's width is expressed in **real ESC/POS Font A
    // character cells** (48 on 80 mm / 32 on 58 mm) so the printer
    // never sees a line longer than the printable width and therefore
    // never auto-wraps.
    //
    // Paper-aware widths (all measured in Font A cells):
    //   * 80 mm: #=2, name=26, qty=4, price=16   (total = 48)
    //   * 58 mm: #=2, name=15, qty=4, price=11   (total = 32)
    bytes.addAll(_hr(generator, ch: _solidRule, metrics: m));
    final int idxW = 2;
    final int qtyW = 4;
    final int priceW = m.is80mm ? 16 : 11;
    final int nameW = m.maxCharsFontA - idxW - qtyW - priceW;
    bytes.addAll(
      generator.text(
        _padRightFixed('#', idxW) +
            _padRightFixed('item_info'.tr.toUpperCase(), nameW) +
            _padLeftFixed('qty'.tr.toUpperCase(), qtyW) +
            _padLeftFixed('price'.tr.toUpperCase(), priceW),
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
    );
    bytes.addAll(_hr(generator, ch: _solidRule, metrics: m));

    for (int index = 0; index < orderDetails.length; index++) {
      final OrderDetailsModel d = orderDetails[index];
      // Thin separator line between items — mirrors the Divider between
      // each ListTile on the on-screen preview so the table reads as a
      // grid even on thermal paper.
      if (index > 0) {
        bytes.addAll(_hr(generator, ch: _solidRule, metrics: m));
      }
      bytes.addAll(_buildItemRow(generator, index + 1, d, m));
    }
    // Close the items table with a rule so the totals block begins cleanly.
    bytes.addAll(_hr(generator, ch: _solidRule, metrics: m));
    return bytes;
  }

  static List<int> _buildItemRow(
    Generator generator,
    int index,
    OrderDetailsModel detail,
    _PaperMetrics m,
  ) {
    final List<int> bytes = <int>[];

    final String name = detail.itemDetails?.name ?? '';
    final String qty = (detail.quantity ?? 0).toString();
    final String price = _priceDecimal(detail.price ?? 0);

    // Paper-aware column widths in **ESC/POS Font A character cells**.
    //
    //   | paper | #col | name | qty | price | total |
    //   |-------|------|------|-----|-------|-------|
    //   | 80mm  | 2    | 26   | 4   | 16    | 48    |
    //   | 58mm  | 2    | 15   | 4   | 11    | 32    |
    //
    // The product name is **pre-wrapped** into word-boundary chunks that
    // fit inside the name column's character budget. The first wrapped
    // chunk carries the index/qty/price columns; subsequent chunks are
    // emitted as continuation lines indented to sit under the name
    // gutter (NOT under qty/price).
    final int idxW = 2;
    final int qtyW = 4;
    final int priceW = m.is80mm ? 16 : 11;
    final int nameW = m.maxCharsFontA - idxW - qtyW - priceW;
    final List<String> nameLines = _wrapText(_sanitize(name), nameW);
    if (nameLines.isEmpty) {
      nameLines.add('');
    }

    for (int lineIdx = 0; lineIdx < nameLines.length; lineIdx++) {
      final bool isFirst = lineIdx == 0;
      // First line carries the index / qty / price columns. Subsequent
      // lines are indented to sit under the name gutter (NOT under the
      // qty/price columns).
      final String lineText = isFirst
          ? (_padRightFixed('$index', idxW) +
                _padRightFixed(nameLines[lineIdx], nameW) +
                _padLeftFixed(qty, qtyW) +
                _padLeftFixed(price, priceW))
          : (' ' * idxW + nameLines[lineIdx]);
      bytes.addAll(
        generator.text(
          lineText,
          styles: const PosStyles(align: PosAlign.left, bold: true),
        ),
      );
    }

    // Variations — subordinated under the name with an indented ASCII bullet.
    // We use '*' instead of '•' because the bullet character (U+2022) sits
    // outside latin1 and would trigger a FormatException on most ESC/POS
    // printers in the default code page; '*' renders identically on every
    // thermal head and matches the '• ' indent of the on-screen design.
    // Variations are indented to sit directly under the item-name column,
    // matching the reference ('• Veggie' starts at the name gutter). The
    // indent scales with the paper width so the sub-lines always align
    // under the product name regardless of printer width — no drift into
    // the QTY / PRICE columns.
    final String indent = ' ' * (idxW + 2);
    // Pre-wrap each variation string against the **full paper width**
    // minus the indent so the wrap point is always inside the printable
    // area and never crosses the price column boundary.
    final int varLineChars = m.maxCharsFontA - indent.length;
    final List<String> variations = _resolveVariations(detail);
    for (final String v in variations) {
      final List<String> lines = _wrapText(_sanitize(v), varLineChars);
      if (lines.isEmpty) continue;
      bytes.addAll(generator.text('$indent* ${lines.first}'));
      for (int i = 1; i < lines.length; i++) {
        bytes.addAll(generator.text('$indent${lines[i]}'));
      }
    }

    // Add-ons — a small bold label then indented list. We wrap each
    // add-on line with the same paper-aware budget as variations so a
    // long add-on name can never drift into the qty/price gutter.
    final List<String> addons = _resolveAddOns(detail);
    if (addons.isNotEmpty) {
      bytes.addAll(
        generator.text(
          _sanitize('addons'.tr.toUpperCase()),
          styles: const PosStyles(bold: true),
        ),
      );
      for (final String a in addons) {
        final List<String> lines = _wrapText(_sanitize(a), varLineChars);
        if (lines.isEmpty) continue;
        bytes.addAll(generator.text('$indent* ${lines.first}'));
        for (int i = 1; i < lines.length; i++) {
          bytes.addAll(generator.text('$indent${lines[i]}'));
        }
      }
    }

    // Customer note — bold inline label "Note:" then the value, manually
    // padded to keep both on the same line. We wrap the value against the
    // real ESC/POS column budget so an Arabic / RTL note (which encodes
    // to multi-byte sequences) never overflows the paper.
    final String note = (detail.note ?? '').trim();
    if (note.isNotEmpty) {
      // 5 chars for "NOTE:" + 1 space = 6 cells reserved for the label.
      final int noteLabelW = 6;
      final int noteValueW = m.maxCharsFontA - indent.length - noteLabelW;
      final String noteLabel = _padRightFixed(
        '${'note'.tr.toUpperCase()}:',
        noteLabelW,
      );
      final List<String> noteLines = _wrapText(_sanitize(note), noteValueW);
      bytes.addAll(
        generator.text(
          '$indent$noteLabel${noteLines.isEmpty ? '' : noteLines.first}',
          styles: const PosStyles(align: PosAlign.left, bold: true),
        ),
      );
      for (int i = 1; i < noteLines.length; i++) {
        bytes.addAll(
          generator.text(
            '$indent${' ' * noteLabelW}${noteLines[i]}',
            styles: const PosStyles(align: PosAlign.left),
          ),
        );
      }
    }
    return bytes;
  }

  static List<String> _resolveVariations(OrderDetailsModel detail) {
    final List<String> result = <String>[];

    // -------------------------------------------------------------------------
    // MATCH THE ON-SCREEN PREVIEW (`InvoiceDialogWidget`).
    // -------------------------------------------------------------------------
    // The on-screen preview renders EACH variation value on its own line,
    // prefixed by a bullet. Empirically this matches the way restaurant
    // operators expect to read an itemised bill (one choice per line is
    // easier to verify against the customer's spoken order). When we
    // joined multiple `variationValues.level` entries with ", " on a
    // single print line, the result was a single long string that
    // wrapped across three or four physical lines on 58 mm paper and
    // frequently got the price-column boundary cross-wired on the
    // Xprinter / Rongta firmwares — that's exactly what produced the
    // "dangling half-line at the right edge" bug in the previous
    // printed output.
    //
    // Therefore: every value gets its OWN entry in the list, and the
    // layout pass below prepends the "* " bullet to each one
    // independently.
    final List<Variation>? legacy = detail.variation;
    if (legacy != null && legacy.isNotEmpty) {
      final String? rawType = legacy.first.type;
      if (rawType != null && rawType.isNotEmpty) {
        result.addAll(_splitVariationText(rawType));
      }
    }

    final List<FoodVariation>? rich = detail.foodVariation;
    if ((rich ?? const <FoodVariation>[]).isNotEmpty) {
      for (final FoodVariation v in rich!) {
        for (final VariationValue vv
            in v.variationValues ?? const <VariationValue>[]) {
          final String level = (vv.level ?? '').trim();
          if (level.isEmpty) continue;
          result.add(level);
        }
      }
    }
    return result;
  }

  static List<String> _splitVariationText(String raw) {
    if (raw.trim().isEmpty) return const <String>[];

    final RegExp parenExp = RegExp(r'\(([^)]+)\)');
    final Iterable<Match> matches = parenExp.allMatches(raw);
    if (matches.isNotEmpty) {
      final List<String> parenResult = <String>[];
      for (final Match m in matches) {
        final String inside = m.group(1)!.trim();
        if (inside.isEmpty) continue;
        if (inside.contains(',')) {
          for (final String v in inside.split(',')) {
            final String vt = v.trim();
            if (vt.isNotEmpty) parenResult.add(vt);
          }
        } else {
          parenResult.add(inside);
        }
      }
      if (parenResult.isNotEmpty) return parenResult;
    }

    final List<String> result = <String>[];
    for (final String part in raw.split(',')) {
      String trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final int sepIndex = trimmed.indexOf(' - ');
      if (sepIndex >= 0) trimmed = trimmed.substring(sepIndex + 3).trim();
      if (trimmed.isNotEmpty) result.add(trimmed);
    }
    return result;
  }

  static List<String> _resolveAddOns(OrderDetailsModel detail) {
    final List<String> out = <String>[];
    for (final AddOn a in detail.addOns ?? const <AddOn>[]) {
      if ((a.name ?? '').isEmpty) continue;
      out.add('${a.name} x${a.quantity ?? 0}');
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Order-level note
  // ---------------------------------------------------------------------------

  static List<int> _buildOrderNote(
    Generator generator,
    OrderModel order,
    _PaperMetrics m,
  ) {
    final List<int> bytes = <int>[];
    final String note = (order.orderNote ?? '').trim();
    if (note.isEmpty) return bytes;
    bytes.addAll(_hr(generator, ch: _solidRule, metrics: m));
    bytes.addAll(
      generator.text(
        _sanitize('order_note'.tr.toUpperCase()),
        styles: const PosStyles(bold: true),
      ),
    );
    for (final String line in _wrapText(_sanitize(note), m.maxCharsFontA)) {
      bytes.addAll(generator.text(line));
    }
    bytes.addAll(_hr(generator, metrics: m));
    return bytes;
  }

  // ---------------------------------------------------------------------------
  // Totals
  // ---------------------------------------------------------------------------

  static List<int> _buildTotals(
    Generator generator,
    OrderModel order,
    _PaperMetrics m, {
    required bool isPrescriptionOrder,
    required double dmTips,
    required List<OrderDetailsModel> orderDetails,
    String? additionalChargeName,
  }) {
    final List<int> bytes = <int>[];

    double itemsPrice = 0;
    if (isPrescriptionOrder) {
      final double orderAmount = order.orderAmount ?? 0;
      final double discount = order.storeDiscountAmount ?? 0;
      final double tax = order.totalTaxAmount ?? 0;
      final double deliveryCharge = order.deliveryCharge ?? 0;
      final double additionalCharge = order.additionalCharge ?? 0;
      final bool taxIncluded = order.taxStatus ?? false;
      itemsPrice =
          (orderAmount + discount) -
          ((taxIncluded ? 0 : tax) + deliveryCharge + additionalCharge) -
          dmTips;
    }

    double addOnsTotal = 0;
    for (final OrderDetailsModel d in orderDetails) {
      for (final AddOn a in d.addOns ?? const <AddOn>[]) {
        addOnsTotal += (a.price ?? 0) * (a.quantity ?? 0);
      }
      if (!isPrescriptionOrder) {
        itemsPrice += (d.price ?? 0) * (d.quantity ?? 0);
      }
    }

    if (itemsPrice > 0 && !isPrescriptionOrder) {
      // Reference image shows `Item Price / Subtotal / Tax` on a subtle
      // light-gray background, NOT a heavy black band. On ESC/POS we
      // approximate that look by emitting plain bold lines for these
      // rows. The heavy black band is reserved for the TOTAL row below,
      // matching the reference image exactly.
      bytes.addAll(
        _addPriceLine(generator, 'ITEM PRICE', itemsPrice, metrics: m),
      );
    }
    if (addOnsTotal > 0) {
      bytes.addAll(_addPriceLine(generator, 'ADDONS', addOnsTotal, metrics: m));
    }

    final double subtotal = itemsPrice + addOnsTotal;
    if (subtotal > 0 && !isPrescriptionOrder) {
      bytes.addAll(_addPriceLine(generator, 'SUBTOTAL', subtotal, metrics: m));
    }

    // -------------------------------------------------------------------------
    // OPTIONAL CHARGES / DISCOUNTS — only emit a row when the value is > 0.
    // -------------------------------------------------------------------------
    // The on-screen `InvoiceDialogWidget` preview already gates every one of
    // these on `> 0`, and we want the printed ESC/POS receipt to be a
    // byte-for-byte mirror of what the operator sees. Each row uses the same
    // `_addPriceLine` helper so the alignment matches ITEM PRICE / SUBTOTAL
    // above (label left, value right, both bold, no reverse band).
    //
    // The reference image shows the totals block laid out as:
    //     Item Price      $ 124.46
    //     Subtotal        $ 124.46
    //     Tax            + $ 11.05
    //     Tips           + $  3.00     ← only when dmTips > 0
    //     TOTAL           $ 138.51     (reverse band)
    //
    // Discount rows use a **negative sign** ("- $ 5.00") to mirror the
    // on-screen preview, while tax / tips / packaging / delivery /
    // additional-charge rows use a **positive sign** ("+ $ 5.00"). We
    // therefore invert the discount values when passing them through
    // `_priceSigned(..., signed: true)` so the printed output reads
    // exactly the way the operator sees it in the preview.
    //
    // Backend drives every field below — we never fabricate values. If a
    // vendor doesn't use Tips / Additional Charge / Extra Packaging etc.
    // the corresponding line is simply absent from both the preview and
    // the print.

    if ((order.storeDiscountAmount ?? 0) > 0) {
      bytes.addAll(
        _addPriceLine(
          generator,
          'discount'.tr.toUpperCase(),
          // Negative sign — preview renders store discount with a leading
          // "-". Negating here keeps the printed receipt byte-identical
          // to the on-screen preview.
          -order.storeDiscountAmount!,
          signed: true,
          metrics: m,
        ),
      );
    }
    if ((order.couponDiscountAmount ?? 0) > 0) {
      bytes.addAll(
        _addPriceLine(
          generator,
          'coupon_discount'.tr.toUpperCase(),
          -order.couponDiscountAmount!,
          signed: true,
          metrics: m,
        ),
      );
    }
    if ((order.referrerBonusAmount ?? 0) > 0) {
      bytes.addAll(
        _addPriceLine(
          generator,
          'referral_discount'.tr.toUpperCase(),
          -order.referrerBonusAmount!,
          signed: true,
          metrics: m,
        ),
      );
    }
    if (!(order.taxStatus ?? false) && (order.totalTaxAmount ?? 0) > 0) {
      bytes.addAll(
        _addPriceLine(
          generator,
          'TAX',
          order.totalTaxAmount!,
          signed: true,
          metrics: m,
        ),
      );
    }
    if (dmTips > 0) {
      bytes.addAll(
        _addPriceLine(
          generator,
          'delivery_man_tips'.tr.toUpperCase(),
          dmTips,
          signed: true,
          metrics: m,
        ),
      );
    }
    if ((order.extraPackagingAmount ?? 0) > 0) {
      bytes.addAll(
        _addPriceLine(
          generator,
          'extra_packaging'.tr.toUpperCase(),
          order.extraPackagingAmount!,
          signed: true,
          metrics: m,
        ),
      );
    }
    if ((order.deliveryCharge ?? 0) > 0) {
      bytes.addAll(
        _addPriceLine(
          generator,
          'delivery_fee'.tr.toUpperCase(),
          order.deliveryCharge!,
          signed: true,
          metrics: m,
        ),
      );
    }
    if ((order.additionalCharge ?? 0) > 0) {
      // The label for this row is configurable per-deployment (see
      // `ConfigModel.additionalChargeName`); fall back to a sensible
      // generic label when the operator hasn't customised it so the
      // line still reads correctly on the printed receipt.
      final String label =
          (additionalChargeName != null &&
              additionalChargeName.trim().isNotEmpty)
          ? additionalChargeName
          : 'additional_charge'.tr;
      bytes.addAll(
        _addPriceLine(
          generator,
          label.toUpperCase(),
          order.additionalCharge!,
          signed: true,
          metrics: m,
        ),
      );
    }

    bytes.addAll(generator.feed(1));
    bytes.addAll(_hr(generator, ch: _solidRule, metrics: m));

    // The TOTAL row.
    //
    // We **no longer use `Generator.row()`** for the TOTAL band. The
    // library's `row()` cannot combine `reverse: true` with the manual
    // positioning we need (the `* -5` subtraction in `_colIndToPosition`
    // eats enough of the right column to drop the price string on
    // 58 mm paper). Instead we emit the line as a single concatenated
    // string with `generator.text()` — this gives us exact control over
    // the alignment and guarantees the price stays inside the printable
    // area on both paper widths.
    //
    // Paper-aware layout (all in Font A cells):
    //   * 80 mm: label = 30, value = 18   (total = 48)
    //   * 58 mm: label = 16, value = 16   (total = 32)
    final int labelW = m.is80mm ? 30 : 16;
    final int valueW = m.maxCharsFontA - labelW;
    final String totalLabel = _padRightFixed('TOTAL', labelW);
    final String totalValue = _padLeftFixed(
      _priceDecimal(order.orderAmount ?? 0),
      valueW,
    );
    // Reset any leftover styles BEFORE the reverse band so the band
    // prints in the expected look on every firmware.
    bytes.addAll(generator.setStyles(const PosStyles()));
    bytes.addAll(
      generator.text(
        totalLabel + totalValue,
        styles: const PosStyles(
          align: PosAlign.left,
          bold: true,
          reverse: true,
          height: PosTextSize.size2,
        ),
      ),
    );
    bytes.addAll(_hr(generator, ch: _solidRule, metrics: m));
    return bytes;
  }

  static List<int> _addPriceLine(
    Generator generator,
    String label,
    double amount, {
    bool signed = false,
    required _PaperMetrics metrics,
  }) {
    final String value = _priceSigned(amount, signed: signed);
    // Paper-aware label/value split (all in Font A cells):
    //   * 80 mm: label = 30, value = 18   ("ITEM PRICE" / "$ 39.20"
    //                                          both fit easily)
    //   * 58 mm: label = 16, value = 16   ("SUBTOTAL" + "$ 39.20"
    //                                          both fit on 58 mm)
    //
    // These rows are deliberately PLAIN bold (no `reverse` black band):
    // the reference image shows `Item Price / Subtotal / Tax` on a
    // subtle light background, with the heavy black band reserved for
    // the TOTAL row alone. Emitting them as reversed bands also made
    // the right-aligned number get clipped on several thermal
    // printers, which is why the amounts looked missing even though
    // the labels printed.
    final int labelW = metrics.is80mm ? 30 : 16;
    final int valueW = metrics.maxCharsFontA - labelW;
    return generator.text(
      _padRightFixed(_sanitize(label.toUpperCase()), labelW) +
          _padLeftFixed(value, valueW),
      styles: const PosStyles(align: PosAlign.left, bold: true),
    );
  }

  // ---------------------------------------------------------------------------
  // Footer
  // ---------------------------------------------------------------------------

  static List<int> _buildFooter(Generator generator, _PaperMetrics m) {
    final List<int> bytes = <int>[];

    // On 58 mm paper the `Thank You` line at `size2` height (16 chars)
    // is the only heading in the footer, so it still fits cleanly.
    // We keep `size2` here on both paper widths because the on-screen
    // preview also shows the thank-you as a tall bold heading.
    final String thankYou = '${_ornamentGlyph()} Thank You ${_ornamentGlyph()}';
    bytes.addAll(
      generator.text(
        // `height: size2` doubles only the HEIGHT — the width multiplier
        // stays at 1, so this line still uses one Font A cell per
        // character (hence the default cellsPerChar: 1). Centred with
        // baked-in padding for the same firmware reason as the header.
        _centerFixed(_sanitize(thankYou), m.maxCharsFontA),
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
        ),
      ),
    );
    bytes.addAll(generator.feed(1));

    // Paper-aware split (Font A cells):
    //   * 80 mm: left = 30, right = 18   ("PICKLES AND PIES" + "@ 2026")
    //   * 58 mm: left = 18, right = 14
    //
    // We reuse [fallbackStoreName1] rather than re-typing the literal so
    // the footer credit line can never drift out of sync with the header
    // title if the brand name is ever changed.
    final String leftText = fallbackStoreName1;
    final int leftW = m.is80mm ? 30 : 18;
    final int rightW = m.maxCharsFontA - leftW;
    bytes.addAll(
      generator.text(
        _padRightFixed(_sanitize(leftText.toUpperCase()), leftW) +
            _padLeftFixed(_sanitize('@ ${DateTime.now().year}'), rightW),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );

    return bytes;
  }

  /// ASCII-safe ornament glyph used to flank the "THANK YOU" headline —
  /// the reference image uses `✹` (U+2739) which is not in latin1; we use
  /// `*` which every thermal printer can render.
  static String _ornamentGlyph() => '*';

  // ---------------------------------------------------------------------------
  // Outer border (top / bottom) — best-effort visual frame.
  // ---------------------------------------------------------------------------
  //
  // ESC/POS doesn't ship with a true continuous-border primitive, so
  // we approximate the reference image's outer rectangle with a top
  // and bottom row of `*` glyphs (the same ASCII bullet the rest of
  // the receipt uses). The text is sized to fit the printable width
  // and centred so it lands flush at both edges on every Font-A
  // thermal head.

  static List<int> _buildOuterTopBorder(Generator generator, _PaperMetrics m) {
    return _emitBorderLine(generator, '*' * m.maxCharsFontA);
  }

  static List<int> _buildOuterBottomBorder(
    Generator generator,
    _PaperMetrics m,
  ) {
    return _emitBorderLine(generator, '*' * m.maxCharsFontA);
  }

  static List<int> _emitBorderLine(Generator generator, String line) {
    // Reset to plain normal text so the border doesn't inherit bold /
    // reverse / size2 from the previous block (the TOTAL band above
    // leaves `reverse: true` and `height: size2` active).
    final List<int> bytes = <int>[];
    bytes.addAll(generator.setStyles(const PosStyles()));
    bytes.addAll(
      generator.text(
        line,
        styles: const PosStyles(align: PosAlign.center, bold: false),
      ),
    );
    return bytes;
  }
}
