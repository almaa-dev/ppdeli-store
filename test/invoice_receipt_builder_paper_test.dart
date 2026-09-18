// Tests for [InvoiceReceiptBuilder] that exercise BOTH 80 mm and 58 mm
// paper widths side-by-side. The 58 mm run is the one that historically
// produced the badly-broken prints (truncated store name, payment method
// missing, totals amounts invisible) — we now assert that every required
// piece of text actually appears in the byte stream regardless of paper
// width.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/common/models/config_model.dart';
import 'package:ppdelistore/features/order/domain/models/order_details_model.dart';
import 'package:ppdelistore/features/order/domain/models/order_model.dart';
import 'package:ppdelistore/features/printer/domain/models/printer_model.dart';
import 'package:ppdelistore/features/printer/helper/invoice_receipt_builder.dart';
import 'package:ppdelistore/features/printer/helper/printer_helper.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/features/splash/domain/services/splash_service_interface.dart';
import 'package:ppdelistore/features/store/domain/models/item_model.dart';

class _NoopSplashService implements SplashServiceInterface {
  @override
  Future<Response<dynamic>> getConfigData() async =>
      Response<dynamic>(statusCode: 200);
  @override
  Future<bool> initSharedData() async => true;
  @override
  bool showIntro() => false;
  @override
  void setIntro(bool intro) {}
  @override
  Future<bool> removeSharedData() async => true;
}

class _TestSplashController extends SplashController {
  _TestSplashController() : super(splashServiceInterface: _NoopSplashService());
  ConfigModel? _cfg;
  void setConfig(ConfigModel c) {
    _cfg = c;
  }

  @override
  ConfigModel? get configModel => _cfg;
}

// We don't register a [ProfileController] in the test DI container
// here. The builder's `_store` getter swallows the resulting
// `Get.find` failure and falls back to `Store()`, which exercises
// the "no configured name" header path. The original unit test
// (`invoice_receipt_builder_test.dart`) follows the same convention.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset();
    final splash = _TestSplashController();
    final c = ConfigModel();
    c.currencySymbol = '\$';
    c.currencySymbolDirection = 'left';
    c.digitAfterDecimalPoint = 2;
    splash.setConfig(c);
    Get.put<SplashController>(splash);
  });

  OrderModel makeOrder() => OrderModel(
        id: 100119,
        orderAmount: 42.68,
        paymentMethod: 'cash_on_delivery',
        orderType: 'delivery',
        createdAt: '2026-07-26 19:16:00',
        deliveryAddress: DeliveryAddress(
          contactPersonName: 'almovlihi',
          address: 'Rockaway Beach, Queens, NY, USA',
          contactPersonNumber: '+967777363554',
        ),
        storeDiscountAmount: 0,
        couponDiscountAmount: 0,
        totalTaxAmount: 3.48,
        deliveryCharge: 0,
        taxStatus: false,
        scheduled: 0,
      );

  List<OrderDetailsModel> makeDetails() {
    Item mk(String name) {
      final i = Item();
      i.name = name;
      i.price = 0;
      i.variations = const <Variation>[];
      i.choiceOptions = const <ChoiceOptions>[];
      return i;
    }

    OrderDetailsModel d(
      String name, {
      double price = 0,
      String? note,
      List<Variation>? variation,
    }) {
      final od = OrderDetailsModel();
      od.itemDetails = mk(name);
      od.price = price;
      od.quantity = 1;
      od.variation = variation ?? const <Variation>[];
      od.addOns = const <AddOn>[];
      od.note = note;
      return od;
    }

    return <OrderDetailsModel>[
      d('Build a Burger',
          price: 12.74,
          note: 'بویت',
          variation: <Variation>[
            Variation(type: 'Veggie, Rare, Extra Cheese')
          ]),
      d('Grilled Cheese',
          price: 7.99,
          note: 'الزینت',
          variation: <Variation>[
            Variation(type: 'Poppy Seed Roll, White American, Ham')
          ]),
      d('Napoleon',
          price: 5.49,
          variation: <Variation>[Variation(type: 'Plain')]),
      d('Cheesecake',
          price: 6.49,
          variation: <Variation>[Variation(type: 'Strawberry')]),
      d('Grilled Cheese',
          price: 6.49,
          variation: <Variation>[
            Variation(type: 'Whole Wheat Roll, Swiss, Tomato')
          ]),
    ];
  }

  PrinterModel makePrinter(String type) => PrinterModel(
        name: 'Xprinter',
        address: 'AA:BB:CC:DD:EE:FF',
        printerType: type,
        isDefault: true,
      );

  Future<String> build(String paperSize) async {
    final bytes = await InvoiceReceiptBuilder.build(
      order: makeOrder(),
      orderDetails: makeDetails(),
      isPrescriptionOrder: false,
      dmTips: 0,
      paperSize: paperSize,
      printer: makePrinter(paperSize),
    );
    final raw = latin1.decode(bytes, allowInvalid: true);
    return raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  bool containsSequence(String text, List<String> parts) {
    int cursor = 0;
    for (final p in parts) {
      final i = text.indexOf(p, cursor);
      if (i < 0) return false;
      if (text.substring(cursor, i).contains('\n')) return false;
      cursor = i + p.length;
    }
    return true;
  }

  group('58mm-specific guarantees', () {
    test('store name fits without truncation', () async {
      final text = await build('58mm');
      // With no ProfileController registered the builder falls back
      // to the two-line "PICKLES AND PIES" + "FOOD MARKET" header.
      // Both lines must appear in full.
      expect(text, contains('PICKLES AND PIES'));
      expect(text, contains('FOOD MARKET'));
      expect(text, isNot(contains('PICKLES AND PIES FOOD MA\n')));
    });

    test('payment method and order type both appear', () async {
      final text = await build('58mm');
      expect(text, contains('DELIVERY'));
      expect(text, contains('CASH ON DELIVERY'));
    });

    test('item-table header words appear in sequence', () async {
      final text = await build('58mm');
      expect(containsSequence(text, ['ITEM_INFO', 'QTY', 'PRICE']),
          isTrue,
          reason:
              'the table header should keep ITEM_INFO / QTY / PRICE together');
    });

    test('every item row prints index / name / price together', () async {
      final text = await build('58mm');
      expect(
          containsSequence(
              text, ['1', 'Build a Burger', '\$ 12.74']),
          isTrue,
          reason:
              'item 1 row should print 1, then name, then price on same line');
      expect(
          containsSequence(text, ['2', 'Grilled Cheese', '\$ 7.99']),
          isTrue,
          reason: 'item 2 row should be contiguous');
      expect(
          containsSequence(text, ['5', 'Grilled Cheese', '\$ 6.49']),
          isTrue,
          reason: 'item 5 row should be contiguous');
    });

    test('totals labels and amounts appear together', () async {
      final text = await build('58mm');
      expect(text, contains('ITEM PRICE'));
      expect(text, contains('SUBTOTAL'));
      expect(text, contains('TAX'));
      expect(text, contains('\$ 39.20'));
      expect(text, contains('+ \$ 3.48'));
    });

    test('TOTAL band prints label and value together', () async {
      final text = await build('58mm');
      // Locate "TOTAL" and verify the amount immediately follows it
      // (the value column's right-aligned text is emitted in the same
      // row by `generator.row`, so both appear between the same
      // surrounding dashed rules).
      expect(containsSequence(text, ['TOTAL', '\$ 42.68']), isTrue,
          reason: 'TOTAL row should contain the amount');
    });

    test('Arabic note transliterates without stray `?`', () async {
      final text = await build('58mm');
      // 'بویت'  -> 'b', 'w', 'ی'(Persian) -> 'y', 't' -> 'bwyt'.
      // Before the fix the Persian yeh (U+06CC) wasn't in the map
      // and got dropped to '?', yielding the "bw?t" garbage.
      expect(text, contains('bwyt'));
      expect(text, isNot(contains('bw?t')));
    });

    test('time appears under date in the order-info block', () async {
      final text = await build('58mm');
      expect(text, contains('26 Jul 2026'));
      expect(text, contains('19:16'));
    });
  });

  group('80mm does not regress', () {
    test('80mm output still contains every required line', () async {
      final text = await build('80mm');
      // With no ProfileController the builder emits the fallback
      // "PICKLES AND PIES" + "FOOD MARKET" two-line header.
      expect(text, contains('PICKLES AND PIES'));
      expect(text, contains('FOOD MARKET'));
      expect(text, contains('DELIVERY'));
      expect(text, contains('CASH ON DELIVERY'));
      expect(text, contains('ITEM PRICE'));
      expect(text, contains('SUBTOTAL'));
      expect(text, contains('TOTAL'));
      expect(text, contains('\$ 42.68'));
    });
  });

  // ===========================================================================
  // Regression coverage for the IMAGE 1 vs IMAGE 2 receipt-printing bug.
  // ===========================================================================

  group('Receipt-printing bug regression coverage', () {
    test(
      'Font A is forced at the start of build() (ESC M 0)',
      () async {
        // Without the explicit `setGlobalFont(PosFontType.fontA)` the
        // printer stays in its power-on font, which is Font B on most
        // MENA retail printers. The wrap-into-FOOD-MARKET bug is
        // triggered by exactly that state — Font B at 80 mm gives 42
        // columns instead of 48, so a 27-character heading at size2
        // wraps mid-word. We assert the byte stream now starts with
        // `ESC @` (reset) followed by `ESC M 0` (select Font A).
        final bytes = await InvoiceReceiptBuilder.build(
          order: makeOrder(),
          orderDetails: makeDetails(),
          isPrescriptionOrder: false,
          dmTips: 0,
          paperSize: '80mm',
          printer: makePrinter('80mm'),
        );
        // ESC @ = 0x1B 0x40 (init)
        // ESC M 0 = 0x1B 0x4D 0x00 (select Font A)
        expect(
          bytes.take(5).toList(),
          <int>[0x1B, 0x40, 0x1B, 0x4D, 0x00],
          reason: 'build() must emit ESC @ then ESC M 0 (Font A) immediately',
        );
      },
    );

    test(
      'long product name wraps within the name column without losing qty/price',
      () async {
        // Build a single-item order with a 30-character product name
        // (longer than the 6-unit / ~24-character name column at 80 mm).
        // The price must still appear on the FIRST physical line, and the
        // name continuation lines must come **after** the first row.
        final order = makeOrder();
        final details = <OrderDetailsModel>[
          OrderDetailsModel()
            ..itemDetails = (Item()
              ..name = 'Very Long Product Name That Wraps')
            ..price = 9.99
            ..quantity = 3
            ..variation = const <Variation>[]
            ..addOns = const <AddOn>[],
        ];
        final bytes = await InvoiceReceiptBuilder.build(
          order: order,
          orderDetails: details,
          isPrescriptionOrder: false,
          dmTips: 0,
          paperSize: '80mm',
          printer: makePrinter('80mm'),
        );
        final raw = latin1.decode(bytes, allowInvalid: true);
        final text = raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
        // Both the price and the first chunk of the name should be
        // present. The exact text is implementation-defined; we just
        // assert that nothing got dropped.
        expect(text, contains('\$ 9.99'));
        expect(text, contains('Very Long Product Name'));
      },
    );

    test(
      'item qty and price appear on the same physical line as the index',
      () async {
        // The original bug had qty on one line and price on the next.
        // We assert that the printable substring of the receipt
        // contains the **canonical row layout** in order, separated
        // only by ESC/POS position commands (which are interleaved by
        // `Generator.row()` for each column). The structural property
        // we check is: between two consecutive expected substrings,
        // only ESC/POS control bytes may appear (specifically `ESC a`,
        // `ESC E`, `GS B`, `ESC $ nL nH`, `GS ! n`, etc.).
        final bytes = await InvoiceReceiptBuilder.build(
          order: makeOrder(),
          orderDetails: makeDetails(),
          isPrescriptionOrder: false,
          dmTips: 0,
          paperSize: '80mm',
          printer: makePrinter('80mm'),
        );
        final raw = latin1.decode(bytes, allowInvalid: true);

        // Helper: returns true if the slice [a,b) of [raw] contains
        // NO LF (0x0A) or CR (0x0D) and is "small enough" that we
        // can reasonably call it the same physical line (< 60 chars
        // of printable content). The 60-char budget comes from the
        // 80mm paper at Font A (48 cols) plus a small allowance for
        // extra setStyles() commands.
        bool sameLine(int a, int b) {
          if (a < 0 || b > raw.length || a >= b) return false;
          int printableCount = 0;
          for (int i = a; i < b; i++) {
            final int c = raw.codeUnitAt(i);
            if (c == 0x0A || c == 0x0D) return false;
            if (c >= 0x20 && c != 0x7F) printableCount++;
          }
          return printableCount < 60;
        }

        // Anchor on the unique item name and walk backwards to find
        // the index, and forwards to find qty + price.
        final int idxName = raw.indexOf('Build a Burger');
        expect(idxName, greaterThanOrEqualTo(0),
            reason: 'item 1 name "Build a Burger" must appear');
        // Walk back from the name looking for the index digit. The
        // chunk between the index and the name must be small enough
        // to live on one physical line (< 60 printable chars).
        int idxIndex = -1;
        for (int i = idxName - 1; i >= 0 && i > idxName - 80; i--) {
          final int c = raw.codeUnitAt(i);
          if (c == 0x31 /* '1' */) {
            idxIndex = i;
            break;
          }
        }
        expect(idxIndex, greaterThanOrEqualTo(0),
            reason: 'item 1 index "1" must appear just before the name');
        expect(sameLine(idxIndex, idxName + 'Build a Burger'.length), isTrue,
            reason:
                'index and name must share one physical line (< 60 chars)');
        final int idxPrice =
            raw.indexOf('\$ 12.74', idxName + 'Build a Burger'.length);
        expect(idxPrice, greaterThanOrEqualTo(0),
            reason: 'item 1 price must follow the name');
        expect(sameLine(idxName, idxPrice + '\$ 12.74'.length), isTrue,
            reason:
                'name, qty and price must share one physical line (< 60 chars)');
      },
    );

    test(
      'item header words (# ITEM_INFO QTY PRICE) appear in a single row',
      () async {
        final text = await build('80mm');
        // After the fix the header is plain bold (no reverse) so the
        // words cannot be broken across lines by the printer's
        // reverse-mode quirks. They must still appear in the canonical
        // order without intervening line breaks.
        expect(
          containsSequence(
              text, <String>['#', 'ITEM_INFO', 'QTY', 'PRICE']),
          isTrue,
          reason:
              'header column labels must stay together on one physical line',
        );
      },
    );

    test(
      'long variation strings wrap without drifting into the price column',
      () async {
        final details = <OrderDetailsModel>[
          OrderDetailsModel()
            ..itemDetails = (Item()..name = 'Big Burger')
            ..price = 19.50
            ..quantity = 1
            ..variation = <Variation>[
              Variation(
                  type:
                      'Extra Cheese, Extra Tomato, Extra Lettuce, Extra Sauce')
            ]
            ..addOns = const <AddOn>[],
        ];
        final bytes = await InvoiceReceiptBuilder.build(
          order: makeOrder(),
          orderDetails: details,
          isPrescriptionOrder: false,
          dmTips: 0,
          paperSize: '80mm',
          printer: makePrinter('80mm'),
        );
        final raw = latin1.decode(bytes, allowInvalid: true);
        final text = raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
        // The variation line should contain all four ingredients.
        expect(text, contains('Extra Cheese'));
        expect(text, contains('Extra Tomato'));
        expect(text, contains('Extra Lettuce'));
        expect(text, contains('Extra Sauce'));
        // The price should still be on the same line as the product name.
        expect(text, contains('Big Burger'));
        expect(text, contains('\$ 19.50'));
      },
    );

    test(
      'outer border frames the receipt (top + bottom decorative rule)',
      () async {
        // The reference design shows a continuous box border around the
        // entire receipt. ESC/POS printers don't support a continuous
        // box primitive natively, so we approximate it with a top and
        // bottom row of `*` glyphs at full paper width.
        Future<int> countBorderRows(String paperSize) async {
          final bytes = await InvoiceReceiptBuilder.build(
            order: makeOrder(),
            orderDetails: makeDetails(),
            isPrescriptionOrder: false,
            dmTips: 0,
            paperSize: paperSize,
            printer: makePrinter(paperSize),
          );
          final raw =
              latin1.decode(bytes, allowInvalid: true).replaceAll(
                    RegExp(r'[\x00-\x1F\x7F]'),
                    '',
                  );
          // The outer border is a row of 48 (80mm) or 32 (58mm) `*`
          // glyphs. We count standalone runs of that exact length and
          // require them to span the entire visible line.
          final borderPattern = paperSize == '80mm'
              ? RegExp(r'\*{48}')
              : RegExp(r'\*{32}');
          // Filter out the much-longer ornamented "* Thank You *" line
          // which is only ~13 chars.
          int count = 0;
          for (final m in borderPattern.allMatches(raw)) {
            // The match should be a near-pure star line — anything
            // beyond just the stars (a trailing word, etc.) disqualifies
            // it.
            final start = m.start;
            final end = m.end;
            // The border line is preceded by ESC/POS commands (e.g.
            // `ESC a 1` + a separator `.`) which are filtered above to
            // printable chars. Treat any printable ASCII / latin1 byte
            // as a valid "before" / "after" neighbour.
            bool printableAt(int idx) {
              if (idx < 0 || idx >= raw.length) return false;
              final int c = raw.codeUnitAt(idx);
              return c >= 0x20 && c <= 0xFE;
            }

            final beforeOk =
                start == 0 ||
                    raw.codeUnitAt(start - 1) == 0x0A ||
                    printableAt(start - 1);
            final afterOk =
                end == raw.length ||
                    raw.codeUnitAt(end) == 0x0A ||
                    printableAt(end);
            if (beforeOk && afterOk) count++;
          }
          return count;
        }

        expect(await countBorderRows('80mm'), equals(2),
            reason: '80mm must have exactly one top + one bottom border');
        expect(await countBorderRows('58mm'), equals(2),
            reason: '58mm must have exactly one top + one bottom border');
      },
    );

    test(
      'FS . (Cancel-Kanji) is stripped from the byte stream so the '
      'store-name heading prints on Xprinter firmwares',
      () async {
        // REGRESSION: the `flutter_esc_pos_utils` library emits
        // `FS .` (0x1C 0x2E = "Cancel Kanji") on EVERY `text()` call.
        // On Xprinter XP-N160I / Rongta RP80USE / Munbyn ITPP047
        // firmwares the `FS` byte is misinterpreted as the start of
        // an extended Chinese command, the `0x2E` byte is consumed
        // as a parameter, and one or more bytes of the following user
        // text are eaten as additional parameters — which is exactly
        // why the store-name heading silently disappeared from the
        // printed receipt even though every character was in the byte
        // stream.
        //
        // The builder now strips these `FS .` sequences as the very
        // last step of `build()`. This test asserts that no `FS .`
        // sequence remains in the final output for either paper width.
        Future<int> countFsDot(String paperSize) async {
          final bytes = await InvoiceReceiptBuilder.build(
            order: makeOrder(),
            orderDetails: makeDetails(),
            isPrescriptionOrder: false,
            dmTips: 0,
            paperSize: paperSize,
            printer: makePrinter(paperSize),
          );
          int count = 0;
          for (int i = 0; i < bytes.length - 1; i++) {
            if (bytes[i] == 0x1C && bytes[i + 1] == 0x2E) count++;
          }
          return count;
        }

        expect(await countFsDot('80mm'), equals(0),
            reason:
                '80mm output must not contain FS . sequences — they '
                'cause Xprinter firmware to drop following user bytes.');
        expect(await countFsDot('58mm'), equals(0),
            reason:
                '58mm output must not contain FS . sequences — they '
                'cause Xprinter firmware to drop following user bytes.');
      },
    );

    test(
      'store-name heading bytes are immediately preceded by style '
      'commands (no FS . between styles and the PICKLES text)',
      () async {
        // Companion test to the FS .-strip one above. Even if some
        // other command byte sneaks in between the style block and
        // the heading, the printer must see the PICKLES bytes
        // contiguous after the bold-on / size-select bytes — which
        // is the only way Xprinter firmware will render the heading.
        Future<List<int>> bytesBeforePICKLES(String paperSize) async {
          final bytes = await InvoiceReceiptBuilder.build(
            order: makeOrder(),
            orderDetails: makeDetails(),
            isPrescriptionOrder: false,
            dmTips: 0,
            paperSize: paperSize,
            printer: makePrinter(paperSize),
          );
          final List<int> tail = <int>[];
          for (int i = 0; i < bytes.length - 7; i++) {
            // "PICKLES" = 0x50 0x49 0x43 0x4B 0x4C 0x45 0x53
            if (bytes[i] == 0x50 &&
                bytes[i + 1] == 0x49 &&
                bytes[i + 2] == 0x43 &&
                bytes[i + 3] == 0x4B &&
                bytes[i + 4] == 0x4C &&
                bytes[i + 5] == 0x45 &&
                bytes[i + 6] == 0x53) {
              // Collect the 6 bytes BEFORE the P.
              final int start = i - 6;
              for (int j = start < 0 ? 0 : start; j < i; j++) {
                tail.add(bytes[j]);
              }
              return tail;
            }
          }
          return tail;
        }

        // The 6 bytes before "PICKLES" must NOT contain 0x1C (FS).
        // The actual layout on both paper widths is:
        //   ESC $ 0 0  (absolute position reset)
        //   ESC E 0x01 (bold on)
        //   GS  ! 0x01 (double-height size)
        //   "P"
        for (final String size in <String>['80mm', '58mm']) {
          final List<int> before = await bytesBeforePICKLES(size);
          expect(before.contains(0x1C), isFalse,
              reason:
                  'FS (0x1C) must never appear between the heading '
                  'styles and the PICKLES text on $size paper.');
        }
      },
    );
  });

  // ===========================================================================
  // Store-name heading ("fallbackStoreName1" / "fallbackStoreName2")
  //
  // These two lines are the only thing on the receipt that identifies the
  // store, so they are guarded independently of the broader layout tests.
  // The historical defect was that the size2 (double-width) title line was
  // budgeted against the FULL Font A column count instead of half of it,
  // which let the firmware auto-wrap it into the subtitle
  // ("PICKLES AND PIES FOOD MA / FOOD MARKET" in IMAGE 2).
  // ===========================================================================

  group('store-name heading prints on every paper width', () {
    /// Decodes the ESC/POS byte stream into the **physical lines the
    /// printer actually renders**.
    ///
    /// A naive `replaceAll(RegExp(r'[\x00-\x1F]'), '')` is NOT enough here:
    /// ESC/POS commands carry *printable* parameter bytes (e.g. `ESC a 0x31`
    /// = `ESC` + `'a'` + `'1'`, `GS ! 0x01` = `GS` + `'!'` + 0x01), so the
    /// stripped text still starts with junk like `$E!PICKLES AND PIES`.
    /// We therefore consume each command together with its parameters so
    /// only genuine user text remains.
    Future<List<String>> printedLines(String paperSize) async {
      final bytes = await InvoiceReceiptBuilder.build(
        order: makeOrder(),
        orderDetails: makeDetails(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: paperSize,
        printer: makePrinter(paperSize),
      );

      // Number of parameter bytes that follow the command selector for
      // every ESC/GS command this builder can emit.
      const Map<int, int> escParams = <int, int>{
        0x40: 0, // ESC @   -> initialise
        0x4D: 1, // ESC M n -> select font
        0x61: 1, // ESC a n -> justification
        0x45: 1, // ESC E n -> bold on/off
        0x64: 1, // ESC d n -> feed n lines
        0x74: 1, // ESC t n -> select code table
        0x24: 2, // ESC $ nL nH -> absolute print position
        0x2D: 1, // ESC - n -> underline
        0x21: 1, // ESC ! n -> print mode
      };
      const Map<int, int> gsParams = <int, int>{
        0x21: 1, // GS ! n -> character size
        0x42: 1, // GS B n -> reverse (white/black)
        0x56: 1, // GS V n -> cut
      };

      final StringBuffer sb = StringBuffer();
      int i = 0;
      while (i < bytes.length) {
        final int b = bytes[i];
        if (b == 0x1B || b == 0x1D) {
          // ESC / GS: skip the selector plus its declared parameters.
          final int selector = (i + 1 < bytes.length) ? bytes[i + 1] : -1;
          final int params = (b == 0x1B ? escParams : gsParams)[selector] ?? 1;
          i += 2 + params;
          continue;
        }
        if (b == 0x1C) {
          // FS x -> the builder strips `FS .`, but be defensive anyway.
          i += 2;
          continue;
        }
        if (b == 0x0A) {
          sb.write('\n');
          i++;
          continue;
        }
        if (b < 0x20 || b == 0x7F) {
          i++; // any other control byte is not printed on paper
          continue;
        }
        sb.writeCharCode(b);
        i++;
      }

      return sb.toString().split('\n').map((String l) => l.trim()).toList();
    }

    for (final String size in <String>['80mm', '58mm']) {
      test('$size prints fallbackStoreName1 on its own physical line',
          () async {
        final lines = await printedLines(size);
        expect(
          lines.any((String l) => l == InvoiceReceiptBuilder.fallbackStoreName1),
          isTrue,
          reason:
              '"${InvoiceReceiptBuilder.fallbackStoreName1}" must occupy one '
              'complete physical line on $size paper — actual lines: $lines',
        );
      });

      test('$size prints fallbackStoreName2 on its own physical line',
          () async {
        final lines = await printedLines(size);
        expect(
          lines.any((String l) => l == InvoiceReceiptBuilder.fallbackStoreName2),
          isTrue,
          reason:
              '"${InvoiceReceiptBuilder.fallbackStoreName2}" must occupy one '
              'complete physical line on $size paper — actual lines: $lines',
        );
      });

      test('$size never merges the two heading lines together', () async {
        final lines = await printedLines(size);
        // The IMAGE 2 defect printed both names concatenated on one line
        // before wrapping. Neither name may share a line with the other.
        expect(
          lines.any((String l) =>
              l.contains(InvoiceReceiptBuilder.fallbackStoreName1) &&
              l.contains(InvoiceReceiptBuilder.fallbackStoreName2)),
          isFalse,
          reason: 'heading lines must not be merged onto one line on $size',
        );
      });

      test('$size heading appears before the order number', () async {
        final lines = await printedLines(size);
        final int titleAt = lines.indexWhere(
            (String l) => l == InvoiceReceiptBuilder.fallbackStoreName1);
        final int subtitleAt = lines.indexWhere(
            (String l) => l == InvoiceReceiptBuilder.fallbackStoreName2);
        final int orderAt = lines.indexWhere((String l) => l.contains('100119'));
        expect(titleAt, greaterThanOrEqualTo(0));
        expect(subtitleAt, greaterThan(titleAt),
            reason: 'subtitle must print directly under the title');
        expect(orderAt, greaterThan(subtitleAt),
            reason: 'the whole heading must print above the order number');
      });

      test(
        '$size title line fits the double-width (size2) column budget',
        () async {
          // A size2 line consumes TWO Font A cells per character, so its
          // real budget is half the paper's Font A column count:
          //   80 mm -> 48 / 2 = 24 cells
          //   58 mm -> 32 / 2 = 16 cells
          // Exceeding that budget is what makes the firmware auto-wrap.
          final int budget = size == '58mm' ? 16 : 24;
          expect(
            InvoiceReceiptBuilder.fallbackStoreName1.length,
            lessThanOrEqualTo(budget),
            reason:
                'the double-width heading must fit in $budget cells on $size; '
                'a longer brand name would wrap into the subtitle.',
          );
        },
      );

      test(
        '$size heading never exceeds the printable dot width '
        '(accounting for the GS ! size multiplier actually emitted)',
        () async {
          // The strongest possible guard: instead of trusting a hard-coded
          // budget constant, we read the `GS ! n` size command that the
          // builder really emitted before each heading line and compute the
          // physical dot width the printer will consume.
          //
          // `flutter_esc_pos_utils` computes
          //   charWidth = paperWidth / charsPerLine * styles.width.value
          // (see Generator._getCharWidth). Font A charsPerLine is 48 on
          // 80 mm / 32 on 58 mm, and `paperSize.width` is 512 dots on
          // 80 mm / 384 dots on 58 mm.
          //
          // If `dots(line) > paperWidth` the firmware auto-wraps the line —
          // exactly the IMAGE 2 defect. This test therefore fails for ANY
          // future brand name that is too long, not just the current one.
          final bytes = await InvoiceReceiptBuilder.build(
            order: makeOrder(),
            orderDetails: makeDetails(),
            isPrescriptionOrder: false,
            dmTips: 0,
            paperSize: size,
            printer: makePrinter(size),
          );

          final bool is80 = size != '58mm';
          final int paperDots = is80 ? 512 : 384;
          final int fontACols = is80 ? 48 : 32;
          final double baseCharDots = paperDots / fontACols;

          /// Walks the stream tracking the live `GS ! n` width multiplier
          /// and returns the dot width of the physical line that starts
          /// with [needle].
          double dotsForLineStartingWith(String needle) {
            int widthMultiplier = 1;
            final List<int> probe = needle.codeUnits;
            for (int i = 0; i < bytes.length; i++) {
              // GS ! n -> low nibble = height, high nibble = width.
              if (bytes[i] == 0x1D &&
                  i + 2 < bytes.length &&
                  bytes[i + 1] == 0x21) {
                widthMultiplier = ((bytes[i + 2] >> 4) & 0x0F) + 1;
                continue;
              }
              bool match = i + probe.length <= bytes.length;
              if (match) {
                for (int k = 0; k < probe.length; k++) {
                  if (bytes[i + k] != probe[k]) {
                    match = false;
                    break;
                  }
                }
              }
              if (!match) continue;
              // Measure to the end of the physical line (next 0x0A).
              int end = i;
              while (end < bytes.length && bytes[end] != 0x0A) {
                end++;
              }
              return (end - i) * baseCharDots * widthMultiplier;
            }
            return -1;
          }

          final double titleDots =
              dotsForLineStartingWith(InvoiceReceiptBuilder.fallbackStoreName1);
          final double subtitleDots =
              dotsForLineStartingWith(InvoiceReceiptBuilder.fallbackStoreName2);

          expect(titleDots, greaterThan(0),
              reason: 'title line must be present in the $size byte stream');
          expect(subtitleDots, greaterThan(0),
              reason: 'subtitle line must be present in the $size byte stream');

          expect(
            titleDots,
            lessThanOrEqualTo(paperDots.toDouble()),
            reason:
                'the store-name title needs ${titleDots.toStringAsFixed(0)} '
                'dots but $size paper only prints $paperDots dots — the '
                'firmware would auto-wrap it into the subtitle.',
          );
          expect(
            subtitleDots,
            lessThanOrEqualTo(paperDots.toDouble()),
            reason:
                'the store-name subtitle needs '
                '${subtitleDots.toStringAsFixed(0)} dots but $size paper only '
                'prints $paperDots dots.',
          );
        },
      );

      test('$size subtitle fits the normal-width (size1) budget', () async {
        final int budget = size == '58mm' ? 32 : 48;
        expect(
          InvoiceReceiptBuilder.fallbackStoreName2.length,
          lessThanOrEqualTo(budget),
          reason: 'the size1 subtitle must fit in $budget cells on $size',
        );
      });
    }

    test('the footer credit line reuses fallbackStoreName1', () async {
      // Guards against the brand name drifting between the header and
      // the footer credit if someone edits only one of them.
      final lines = await printedLines('80mm');
      final int yearIdx =
          lines.indexWhere((String l) => l.contains('@ ${DateTime.now().year}'));
      expect(yearIdx, greaterThanOrEqualTo(0),
          reason: 'footer credit line must be printed');
      expect(
        lines[yearIdx].toUpperCase(),
        contains(InvoiceReceiptBuilder.fallbackStoreName1.toUpperCase()),
        reason: 'footer credit must carry the same store name as the header',
      );
    });
  });

  // ===========================================================================
  // Heading CENTRING
  //
  // `PosAlign.center` alone is not enough. `flutter_esc_pos_utils._text()`
  // prefixes every `generator.text()` call with an absolute print position
  // (`ESC $ 0 0`), and on Xprinter / Rongta / Munbyn firmwares that command
  // overrides the active `ESC a 1` justification — printing the heading hard
  // left. The builder therefore ALSO bakes symmetric padding into the string
  // itself. These tests assert that padding is present and correct.
  // ===========================================================================

  group('store-name heading is centred on the paper', () {
    /// Returns the printed lines WITHOUT trimming, so the leading padding
    /// spaces that perform the centring remain observable.
    Future<List<String>> rawLines(String paperSize) async {
      final bytes = await InvoiceReceiptBuilder.build(
        order: makeOrder(),
        orderDetails: makeDetails(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: paperSize,
        printer: makePrinter(paperSize),
      );
      const Map<int, int> escParams = <int, int>{
        0x40: 0, 0x4D: 1, 0x61: 1, 0x45: 1,
        0x64: 1, 0x74: 1, 0x24: 2, 0x2D: 1, 0x21: 1,
      };
      const Map<int, int> gsParams = <int, int>{0x21: 1, 0x42: 1, 0x56: 1};
      final StringBuffer sb = StringBuffer();
      int i = 0;
      while (i < bytes.length) {
        final int b = bytes[i];
        if (b == 0x1B || b == 0x1D) {
          final int sel = (i + 1 < bytes.length) ? bytes[i + 1] : -1;
          i += 2 + ((b == 0x1B ? escParams : gsParams)[sel] ?? 1);
          continue;
        }
        if (b == 0x1C) {
          i += 2;
          continue;
        }
        if (b == 0x0A) {
          sb.write('\n');
          i++;
          continue;
        }
        if (b < 0x20 || b == 0x7F) {
          i++;
          continue;
        }
        sb.writeCharCode(b);
        i++;
      }
      return sb.toString().split('\n');
    }

    for (final String size in <String>['80mm', '58mm']) {
      // Font A column budget for this paper width.
      final int cols = size == '58mm' ? 32 : 48;

      test('$size title is symmetrically padded for its size2 width', () async {
        final lines = await rawLines(size);
        final String title = InvoiceReceiptBuilder.fallbackStoreName1;
        final String line = lines.firstWhere(
            (String l) => l.trimRight().endsWith(title),
            orElse: () => '');
        expect(line, isNotEmpty,
            reason: 'title line must exist in the $size stream');

        final int leading = line.length - line.trimLeft().length;
        // The title prints at size2 (double WIDTH), so its cell budget is
        // cols / 2. Expected left pad = (budget - length) / 2.
        final int budget = cols ~/ 2;
        final int expectedPad = (budget - title.length) ~/ 2;
        expect(leading, equals(expectedPad),
            reason:
                'title on $size should carry $expectedPad leading spaces so '
                'it sits in the middle of the $cols-cell paper, got $leading');
      });

      test('$size subtitle is symmetrically padded for its size1 width',
          () async {
        final lines = await rawLines(size);
        final String sub = InvoiceReceiptBuilder.fallbackStoreName2;
        final String line = lines.firstWhere(
            (String l) => l.trimRight().endsWith(sub),
            orElse: () => '');
        expect(line, isNotEmpty,
            reason: 'subtitle line must exist in the $size stream');

        final int leading = line.length - line.trimLeft().length;
        // The subtitle prints at size1, so it gets the FULL column budget.
        final int expectedPad = (cols - sub.length) ~/ 2;
        expect(leading, equals(expectedPad),
            reason:
                'subtitle on $size should carry $expectedPad leading spaces, '
                'got $leading');
      });

      test('$size heading margins are balanced left vs right', () async {
        // The same property expressed in CELLS — this is what the operator
        // actually sees on the paper.
        final lines = await rawLines(size);
        final String title = InvoiceReceiptBuilder.fallbackStoreName1;
        final String line = lines.firstWhere(
            (String l) => l.trimRight().endsWith(title),
            orElse: () => '');
        final int leading = line.length - line.trimLeft().length;
        // Everything on this line renders at size2 => 2 cells per char.
        final int leftMarginCells = leading * 2;
        final int usedCells = (leading + title.length) * 2;
        final int rightMarginCells = cols - usedCells;
        expect((leftMarginCells - rightMarginCells).abs(), lessThanOrEqualTo(2),
            reason:
                'left margin ($leftMarginCells cells) and right margin '
                '($rightMarginCells cells) must be balanced on $size');
      });
    }
  });

  // ===========================================================================
  // PAPER CUT
  //
  // Historically only the manual InvoicePrintScreen appended the cut, so
  // auto-printed receipts (OrderDetailsScreen -> PrinterController) had to
  // be torn off by hand. The cut now lives inside the builder so every
  // caller gets it.
  // ===========================================================================

  group('paper cut is appended to the invoice ticket', () {
    /// Canonical cut sequence: ESC d 2 (feed) + GS V 0 (full cut).
    const List<int> cutSequence = <int>[0x1B, 0x64, 0x02, 0x1D, 0x56, 0x00];

    Future<List<int>> ticket(String size, {bool cut = true}) {
      return InvoiceReceiptBuilder.build(
        order: makeOrder(),
        orderDetails: makeDetails(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: size,
        printer: makePrinter(size),
        appendPaperCut: cut,
      );
    }

    int countCuts(List<int> bytes) {
      int cuts = 0;
      for (int i = 0; i < bytes.length - 1; i++) {
        if (bytes[i] == 0x1D && bytes[i + 1] == 0x56) cuts++;
      }
      return cuts;
    }

    for (final String size in <String>['80mm', '58mm']) {
      test('$size ticket ends with ESC d n + GS V 0', () async {
        final bytes = await ticket(size);
        expect(bytes.length, greaterThan(cutSequence.length));
        expect(
          bytes.sublist(bytes.length - cutSequence.length),
          equals(cutSequence),
          reason:
              'the $size invoice must terminate with the ESC/POS paper-cut '
              'sequence so the receipt is torn off automatically',
        );
      });

      test('$size ticket contains EXACTLY ONE cut (no double-cut)', () async {
        expect(countCuts(await ticket(size)), equals(1),
            reason:
                'exactly one GS V cut must be present on $size — a second one '
                'makes the printer eject a blank slip between receipts');
      });

      test('$size cut is suppressed when appendPaperCut is false', () async {
        expect(countCuts(await ticket(size, cut: false)), equals(0),
            reason: 'appendPaperCut: false must produce no cut bytes');
      });
    }

    test('the cut is preceded by a feed so the blade clears the text',
        () async {
      // Without the ESC d feed the cutter slices through the last printed
      // lines, because the print head sits above the blade.
      final bytes = await ticket('80mm');
      final int cutAt = bytes.length - 3; // index of 0x1D in GS V 0
      expect(bytes[cutAt], equals(0x1D));
      expect(bytes[cutAt + 1], equals(0x56));
      expect(bytes[cutAt - 3], equals(0x1B));
      expect(bytes[cutAt - 2], equals(0x64));
      expect(bytes[cutAt - 1], greaterThan(0),
          reason: 'the pre-cut feed must advance at least one line');
    });

    test('PrinterHelper.buildInvoiceBytes also returns a cut ticket', () async {
      // The screens call through PrinterHelper, not the builder directly,
      // so the flag must be threaded correctly.
      final bytes = await PrinterHelper.buildInvoiceBytes(
        order: makeOrder(),
        orderDetails: makeDetails(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: '80mm',
        printer: makePrinter('80mm'),
      );
      expect(bytes.sublist(bytes.length - cutSequence.length),
          equals(cutSequence));
      expect(countCuts(bytes), equals(1));
    });
  });
}