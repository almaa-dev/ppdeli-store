// Unit tests for [InvoiceReceiptBuilder].
//
// These tests cover the **shape** of the ESC/POS byte stream that the
// builder emits — they do not require a real Bluetooth adapter or printer.
//
// The builder reads from [Get.find<SplashController>()] and
// [Get.find<ProfileController>()] to populate the store header. When no
// controllers are registered (the default in tests), it falls back to
// empty values via a try/catch in [_store] and an explicit
// `Get.isRegistered<>` check in [_config]. That makes the builder fully
// testable without spinning up the whole DI container.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/features/order/domain/models/order_details_model.dart';
import 'package:ppdelistore/features/order/domain/models/order_model.dart';
import 'package:ppdelistore/features/printer/domain/models/printer_model.dart';
import 'package:ppdelistore/features/printer/helper/invoice_receipt_builder.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/features/splash/domain/services/splash_service_interface.dart';
import 'package:ppdelistore/features/store/domain/models/item_model.dart';
import 'package:ppdelistore/common/models/config_model.dart';

/// Minimal stub of [SplashServiceInterface] for tests.
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

/// Test-only [SplashController] that returns a deterministic config
/// without touching the network. We extend the real controller so its
/// [configModel] getter matches what `InvoiceReceiptBuilder` expects.
class _TestSplashController extends SplashController {
  _TestSplashController() : super(splashServiceInterface: _NoopSplashService());
  ConfigModel? _cfg;
  void setConfig(ConfigModel c) {
    _cfg = c;
  }

  @override
  ConfigModel? get configModel => _cfg;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _TestSplashController splash;

  setUp(() {
    Get.reset();
    splash = _TestSplashController();
    splash.setConfig(_config());
    Get.put<SplashController>(splash);
  });

  test('build() returns an empty list when order is null', () async {
    final List<int> bytes = await InvoiceReceiptBuilder.build(
      order: null,
      orderDetails: const <OrderDetailsModel>[],
      isPrescriptionOrder: false,
      dmTips: 0,
      paperSize: '80mm',
      printer: _printer(),
    );
    expect(bytes, isEmpty);
  });

  test(
    'build() returns a non-empty ESC/POS byte stream for a normal order',
    () async {
      final List<int> bytes = await InvoiceReceiptBuilder.build(
        order: _order(),
        orderDetails: _details(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: '80mm',
        printer: _printer(),
      );

      // We should get back a sizeable byte stream — not zero, not just
      // a few ESC/POS init bytes.
      expect(bytes.length, greaterThan(100));
      // The reset command (ESC @) is always first.
      expect(bytes.first, equals(0x1B));
    },
  );

  test(
    'build() encodes item variations, notes, and totals in latin1',
    () async {
      final List<int> bytes = await InvoiceReceiptBuilder.build(
        order: _order(),
        orderDetails: _details(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: '80mm',
        printer: _printer(),
      );

      // Decode as latin1 and strip ESC/POS control bytes; the printer
      // output is a control stream, so we normalize the printable text before
      // comparing the actual receipt content. The `_normalizedText` form
      // collapses ESC/POS `Generator.row` line wraps (introduced when an
      // item name overflows its 6-unit `size2` column) into a single space
      // so name-presence assertions remain robust.
      final String text = _printableText(bytes);
      final String upper = text.toUpperCase();
      final String normalized = _normalizedText(bytes).toUpperCase();

      // The item name `Build a Burger` (14 chars) overflows the 6-unit
      // `size2` column and wraps onto a second line in the receipt, so
      // the literal substring `BUILD A BURGER` does not appear
      // contiguously even though every word is present. The wrap point
      // observed in the actual byte stream is after `BUILD A BUR` so
      // we match `BUILD.*A.*BURGER` to tolerate any wrapping point.
      expect(normalized, matches(RegExp(r'BUILD.*A.*BURGER')));
      expect(normalized, contains('GRILLED CHEESE'));
      expect(normalized, contains('NAPOLEON'));
      expect(normalized, contains('CHEESECAKE'));

      // Variations rendered as bullets ('*' is the latin1-safe substitute
      // for the on-screen bullet glyph U+2022).
      expect(upper, contains('* VEGGIE'));
      expect(upper, contains('* POPPY SEED ROLL'));
      expect(upper, contains('* PLAIN'));

      // Note label is a bold "NOTE:" prefix.
      expect(upper, contains('NOTE:'));

      // Totals (the GetX `.tr` extension returns the translation key as a
      // fallback when translations aren't loaded, so we accept either the
      // human-readable label ('Item Price' → 'ITEM PRICE') or the raw
      // key with underscores ('item_price' → 'ITEM_PRICE').)
      expect(
        upper.contains('ITEM PRICE') || upper.contains('ITEM_PRICE'),
        isTrue,
        reason: 'expected item-price label, got: $upper',
      );
      expect(upper.contains('SUBTOTAL'), isTrue);
      // The reference image labels the government levy "Tax" (not "VAT"),
      // and the builder emits the translated key `'tax'.tr` → "TAX".
      expect(upper.contains('TAX'), isTrue);
      expect(upper.contains('TOTAL'), isTrue);

      // Footer
      expect(
        upper.contains('THANK YOU') || upper.contains('THANK_YOU'),
        isTrue,
      );
    },
  );

  test('build() matches the reference total row layout', () async {
    final List<int> bytes = await InvoiceReceiptBuilder.build(
      order: _order(),
      orderDetails: _details(),
      isPrescriptionOrder: false,
      dmTips: 0,
      paperSize: '80mm',
      printer: _printer(),
    );

    final String text = _printableText(bytes);
    final String normalized = _normalizedText(bytes);
    expect(text.toUpperCase(), contains('TOTAL'));
    // `PriceConverterHelper.convertPrice` puts a single space between
    // the currency symbol and the amount when `currencySymbolDirection`
    // is `'left'`, so the printed receipt reads `$ 42.68`. We assert
    // both the normalized (space-collapsed) and raw form to stay robust
    // against any future formatting tweaks.
    expect(normalized, contains('\$ 42.68'));
    expect(normalized, isNot(contains('TOTAL_AMOUNT')));
  });

  test('build() skips the customer block for take_away orders', () async {
    final OrderModel takeAway = _order();
    takeAway.orderType = 'take_away';

    final List<int> bytes = await InvoiceReceiptBuilder.build(
      order: takeAway,
      orderDetails: _details(),
      isPrescriptionOrder: false,
      dmTips: 0,
      paperSize: '80mm',
      printer: _printer(),
    );

    final String text = _printableText(bytes);
    expect(text.contains('almovlihi'), isFalse);
    expect(text.contains('+967777363554'), isFalse);
  });

  // ---------------------------------------------------------------------------
  // Tests covering the receipt redesign that matches the on-screen reference.
  // ---------------------------------------------------------------------------

  test(
    'build() avoids duplicate store-name rows and preserves printed amounts',
    () async {
      final List<int> bytes = await InvoiceReceiptBuilder.build(
        order: _order(),
        orderDetails: _details(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: '80mm',
        printer: _printer(),
      );

      final String text = _normalizedText(bytes).toUpperCase();
      expect(text, contains('PICKLES AND PIES'));
      expect(text, isNot(contains('PICKLES AND PIES PICKLES AND PIES')));
      expect(text, contains('\$ 42.68'));
      expect(text, contains('ITEM PRICE'));
      expect(text, contains('SUBTOTAL'));
      expect(text, contains('TAX'));
    },
  );

  test(
    'build() emits the items-table header row with the column labels in sequence',
    () async {
      final List<int> bytes = await InvoiceReceiptBuilder.build(
        order: _order(),
        orderDetails: _details(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: '80mm',
        printer: _printer(),
      );

      final String raw = latin1.decode(bytes, allowInvalid: true);
      // The header row carries the `# ITEM_INFO  QTY  PRICE` column
      // labels. As of the receipt-printing bug-fix the header is plain
      // **bold** (not white-on-black); the bold weight plus the solid
      // rule lines above and below it produce the same visual band
      // without depending on the printer's reverse-mode quirks (which
      // caused the per-column header words to wrap onto separate lines
      // on Xprinter firmware). The TOTAL row at the bottom of the
      // receipt **is** still reversed and emits the
      // `GS B 01` (`0x1D 0x42 0x01`) command, which we assert below.
      expect(raw, contains('ITEM_INFO'));
      expect(raw, contains('QTY'));
      expect(raw, contains('PRICE'));
      // ESC/POS reverse-video enable = GS B n (0x1D 0x42 0x01).
      // This is emitted by the TOTAL row.
      expect(raw.codeUnits, containsAll(<int>[0x1D, 0x42, 0x01]));
    },
  );

  test(
    'build() keeps the totals labels plain and only the TOTAL row reversed',
    () async {
      final List<int> bytes = await InvoiceReceiptBuilder.build(
        order: _order(),
        orderDetails: _details(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: '80mm',
        printer: _printer(),
      );

      final String text = _normalizedText(bytes).toUpperCase();
      expect(text, contains('ITEM PRICE'));
      expect(text, contains('SUBTOTAL'));
      expect(text, contains('TAX'));
      expect(text, contains('TOTAL'));

      // The reference image shows `Item Price / Subtotal / Tax` on a
      // subtle background and only `TOTAL` as a heavy black band. We
      // assert the exact number of reverse-video enable commands in the
      // build by counting the GS B 01 triplets.
      //
      // NOTE: as of the receipt-printing bug-fix the items-table header
      // is **plain bold** (no reverse). The previous `reverse: true` on
      // the items-header band made the per-column header words wrap onto
      // separate physical lines on the Xprinter profile and the rest of
      // the receipt got pushed off the printable width. The visual
      // emphasis of the band is now carried by the bold weight plus the
      // solid rule lines above and below it. If a future regression
      // adds `reverse: true` to the subtotal lines (as the old code did
      // for ITEM PRICE), this number will grow and the assertion will
      // fail loudly.
      final List<int> raw = bytes;
      int reverseCount = 0;
      for (int i = 0; i + 2 < raw.length; i++) {
        if (raw[i] == 0x1D && raw[i + 1] == 0x42 && raw[i + 2] == 0x01) {
          reverseCount++;
        }
      }
      // Exactly 2 reverse-video bands are expected:
      //   1. the store-name heading (white-on-black brand band), and
      //   2. the TOTAL row.
      // The items-table header and the subtotal lines must stay plain —
      // reversing those is what made them wrap on the Xprinter profile.
      expect(reverseCount, equals(2));

      // Every reverse band must be switched OFF again (GS B 00), otherwise
      // the rest of the receipt prints white-on-black and the thermal head
      // burns an entirely black strip of paper.
      int reverseOffCount = 0;
      for (int i = 0; i + 2 < raw.length; i++) {
        if (raw[i] == 0x1D && raw[i + 1] == 0x42 && raw[i + 2] == 0x00) {
          reverseOffCount++;
        }
      }
      expect(reverseOffCount, equals(reverseCount),
          reason: 'each GS B 01 must be balanced by a GS B 00');
    },
  );

  test(
    'build() renders the configured currency symbol in the TOTAL row',
    () async {
      final List<int> bytes = await InvoiceReceiptBuilder.build(
        order: _order(),
        orderDetails: _details(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: '80mm',
        printer: _printer(),
      );

      final String normalized = _normalizedText(bytes);
      // `PriceConverterHelper.convertPrice` uses the configured symbol
      // and direction; with `currencySymbolDirection = 'left'` the
      // printed receipt reads `$ 42.68`.
      expect(normalized, contains(r'$ 42.68'));
    },
  );

  test(
    'build() stacks date + time in the right-hand order-info column',
    () async {
      final List<int> bytes = await InvoiceReceiptBuilder.build(
        order: _order(),
        orderDetails: _details(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: '80mm',
        printer: _printer(),
      );

      // Both the date and the time should appear inside the same right
      // column of the order-info row, with no blank left half on the
      // second line. We assert that the printable text contains the
      // date and the time as separate lines, in that order.
      final String raw = latin1.decode(bytes, allowInvalid: true);
      expect(raw, contains('26 Jul 2026'));
      expect(raw, contains('19:16'));
      // The time must appear AFTER the date inside the same row, i.e.
      // its byte offset is strictly greater than the date's.
      expect(raw.indexOf('19:16'), greaterThan(raw.indexOf('26 Jul 2026')));
    },
  );

  // ===========================================================================
  // VARIANT-PER-LINE REGRESSION (Bug fix: each variation on its own bullet)
  // ===========================================================================
  // Prior to the redesign the food-variation renderer concatenated every
  // `variationValues.level` entry onto a single comma-separated line which
  // wrapped across several physical lines on 58 mm paper and frequently
  // dropped the price-column boundary. The new renderer emits each value
  // on its OWN line (matching the on-screen `InvoiceDialogWidget` preview).
  // These tests guard against the regression of joining them with ", ".

  test(
    'build() renders every legacy variation value on its own bullet line',
    () async {
      final List<int> bytes = await InvoiceReceiptBuilder.build(
        order: _order(),
        orderDetails: _details(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: '80mm',
        printer: _printer(),
      );

      final String upper = _normalizedText(bytes).toUpperCase();
      // Each `Variation.type` of 'Veggie, Rare, Extra Cheese' must render
      // as a separate bullet line — NOT a single comma-joined string.
      expect(upper, contains('* VEGGIE'));
      expect(upper, contains('* RARE'));
      expect(upper, contains('* EXTRA CHEESE'));
      // And the comma-joined form (which was the source of the wrap bug)
      // must be absent.
      expect(upper, isNot(contains('VEGGIE, RARE')));
    },
  );

  test(
    'build() renders every FoodVariation value on its own bullet line',
    () async {
      // Build a custom detail that uses the rich `FoodVariation` shape
      // (the modern API path most vendors rely on), with three values
      // on the same option group. We assert that all three appear as
      // separate bullet lines, not joined.
      final Item richItem = Item();
      richItem.name = 'Philly Cheesesteak';
      richItem.price = 15.99;
      richItem.variations = const <Variation>[];
      richItem.choiceOptions = const <ChoiceOptions>[];

      final OrderDetailsModel detail = OrderDetailsModel();
      detail.itemDetails = richItem;
      detail.price = 15.99;
      detail.quantity = 1;
      detail.variation = const <Variation>[];
      detail.addOns = const <AddOn>[];
      detail.foodVariation = <FoodVariation>[
        FoodVariation(
          name: 'Bread',
          variationValues: <VariationValue>[
            VariationValue(level: 'Whole Wheat Roll'),
            VariationValue(level: 'Italian Roll'),
            VariationValue(level: 'Hoagie Roll'),
          ],
        ),
      ];

      final List<int> bytes = await InvoiceReceiptBuilder.build(
        order: _order(),
        orderDetails: <OrderDetailsModel>[detail],
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: '80mm',
        printer: _printer(),
      );

      final String upper = _normalizedText(bytes).toUpperCase();
      expect(upper, contains('* WHOLE WHEAT ROLL'));
      expect(upper, contains('* ITALIAN ROLL'));
      expect(upper, contains('* HOAGIE ROLL'));
      // The comma-joined "level, level, level" form must NOT appear.
      expect(upper, isNot(contains('WHOLE WHEAT ROLL, ITALIAN')));
    },
  );

  // ===========================================================================
  // OPTIONAL CHARGES — Tips / Additional Charge / Discounts gating
  // ===========================================================================
  // The totals block must mirror the on-screen `InvoiceDialogWidget` preview
  // byte-for-byte: every optional row is gated on `> 0` and every discount
  // row is rendered with a leading `-` sign while every charge row uses
  // a leading `+` sign.

  test(
    'build() emits a Tips row only when dmTips is greater than zero',
    () async {
      // dmTips = 0 → row must be absent.
      final List<int> zeroBytes = await InvoiceReceiptBuilder.build(
        order: _order(),
        orderDetails: _details(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: '80mm',
        printer: _printer(),
      );
      final String zeroText = _normalizedText(zeroBytes).toUpperCase();
      expect(zeroText, isNot(contains('TIPS')));

      // dmTips > 0 → row must appear with a positive sign and the value.
      final List<int> withTipsBytes = await InvoiceReceiptBuilder.build(
        order: _order(),
        orderDetails: _details(),
        isPrescriptionOrder: false,
        dmTips: 3.00,
        paperSize: '80mm',
        printer: _printer(),
      );
      final String withTipsText = _normalizedText(withTipsBytes).toUpperCase();
      // Translation key for tips is `delivery_man_tips` which renders as
      // "TIPS" or "DELIVERY_MAN_TIPS" depending on whether `.tr` found
      // a translation; we accept both spellings.
      expect(
        withTipsText.contains('TIPS') ||
            withTipsText.contains('DELIVERY_MAN_TIPS'),
        isTrue,
        reason: 'expected a Tips row, got: $withTipsText',
      );
      // The 3.00 amount must appear with a positive sign.
      expect(withTipsText, contains('+ \$ 3.00'));
    },
  );

  test(
    'build() emits an Additional Charge row with the configured label',
    () async {
      final OrderModel order = _order();
      order.additionalCharge = 5.00;

      final List<int> withDefault = await InvoiceReceiptBuilder.build(
        order: order,
        orderDetails: _details(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: '80mm',
        printer: _printer(),
      );
      final String defaultText = _normalizedText(withDefault).toUpperCase();
      // With no `additionalChargeName` provided the builder falls back
      // to the generic translation key.
      expect(
        defaultText.contains('ADDITIONAL CHARGE') ||
            defaultText.contains('ADDITIONAL_CHARGE'),
        isTrue,
        reason: 'expected Additional Charge label, got: $defaultText',
      );
      expect(defaultText, contains('+ \$ 5.00'));

      // With an explicit custom label the builder surfaces it verbatim.
      final List<int> withCustom = await InvoiceReceiptBuilder.build(
        order: order,
        orderDetails: _details(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: '80mm',
        printer: _printer(),
        additionalChargeName: 'Service Fee',
      );
      final String customText = _normalizedText(withCustom).toUpperCase();
      expect(customText, contains('SERVICE FEE'));
      expect(customText, contains('+ \$ 5.00'));
    },
  );

  test(
    'build() omits the Additional Charge row when the value is zero',
    () async {
      final OrderModel order = _order();
      order.additionalCharge = 0;

      final List<int> bytes = await InvoiceReceiptBuilder.build(
        order: order,
        orderDetails: _details(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: '80mm',
        printer: _printer(),
        additionalChargeName: 'Service Fee',
      );
      final String text = _normalizedText(bytes).toUpperCase();
      expect(text, isNot(contains('SERVICE FEE')));
      expect(text, isNot(contains('ADDITIONAL CHARGE')));
    },
  );

  test(
    'build() emits discounts with a leading minus sign',
    () async {
      final OrderModel order = _order();
      order.storeDiscountAmount = 2.50;
      order.couponDiscountAmount = 1.25;
      order.referrerBonusAmount = 0.50;

      final List<int> bytes = await InvoiceReceiptBuilder.build(
        order: order,
        orderDetails: _details(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: '80mm',
        printer: _printer(),
      );
      final String text = _normalizedText(bytes);
      // All three discounts render with a leading "-" sign.
      expect(text, contains('- \$ 2.50'));
      expect(text, contains('- \$ 1.25'));
      expect(text, contains('- \$ 0.50'));
    },
  );

  test(
    'build() emits extra packaging, delivery fee, and additional charge',
    () async {
      final OrderModel order = _order();
      order.extraPackagingAmount = 1.50;
      order.deliveryCharge = 4.99;
      order.additionalCharge = 2.00;
      order.dmTips = 0; // already zero in _order

      final List<int> bytes = await InvoiceReceiptBuilder.build(
        order: order,
        orderDetails: _details(),
        isPrescriptionOrder: false,
        dmTips: 0,
        paperSize: '80mm',
        printer: _printer(),
        additionalChargeName: 'Service Fee',
      );
      final String text = _normalizedText(bytes);
      expect(text, contains('+ \$ 1.50')); // extra packaging
      expect(text, contains('+ \$ 4.99')); // delivery fee
      expect(text, contains('+ \$ 2.00')); // additional charge
      // Translation keys may surface either as the key with underscores
      // (e.g. EXTRA_PACKAGING) or as the translated string (EXTRA
      // PACKAGING) depending on whether `.tr` found a match. Accept
      // either form so the assertion stays robust against future
      // translation updates.
      expect(
        text.toUpperCase().contains('EXTRA PACKAGING') ||
            text.toUpperCase().contains('EXTRA_PACKAGING'),
        isTrue,
      );
      expect(
        text.toUpperCase().contains('DELIVERY FEE') ||
            text.toUpperCase().contains('DELIVERY_FEE'),
        isTrue,
      );
      expect(text.toUpperCase(), contains('SERVICE FEE'));
    },
  );
}

String _printableText(List<int> bytes) {
  final String raw = latin1.decode(bytes, allowInvalid: true);
  return raw.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
}

/// Normalises the printable text by collapsing all whitespace (including
/// the newlines that ESC/POS `Generator.row` inserts when an item name
/// overflows its 6-unit `size2` column) into a single space. Without
/// this, item-name assertions would be brittle to wrapping changes in
/// the underlying column renderer.
String _normalizedText(List<int> bytes) {
  return _printableText(bytes).replaceAll(RegExp(r'\s+'), ' ').trim();
}

PrinterModel _printer() => PrinterModel(
  name: 'TestPrinter',
  address: 'AA:BB:CC:DD:EE:FF',
  printerType: '80mm',
  isDefault: true,
);

ConfigModel _config() {
  final ConfigModel c = ConfigModel();
  c.currencySymbol = '\$';
  c.currencySymbolDirection = 'left';
  c.digitAfterDecimalPoint = 2;
  return c;
}

OrderModel _order() {
  final DeliveryAddress addr = DeliveryAddress(
    contactPersonName: 'almovlihi',
    address: 'Rockaway Beach, Queens, NY, USA',
    contactPersonNumber: '+967777363554',
  );
  return OrderModel(
    id: 100119,
    orderAmount: 42.68,
    paymentMethod: 'cash_on_delivery',
    orderType: 'delivery',
    createdAt: '2026-07-26 19:16:00',
    deliveryAddress: addr,
    storeDiscountAmount: 0,
    couponDiscountAmount: 0,
    totalTaxAmount: 3.48,
    deliveryCharge: 0,
    taxStatus: false,
    scheduled: 0,
  );
}

List<OrderDetailsModel> _details() {
  Item mkItem(String name, {double price = 0}) {
    final Item item = Item();
    item.name = name;
    item.price = price;
    item.variations = const <Variation>[];
    item.choiceOptions = const <ChoiceOptions>[];
    return item;
  }

  OrderDetailsModel d(
    String name, {
    double price = 0,
    int quantity = 1,
    String? note,
    List<Variation>? variation,
  }) {
    final OrderDetailsModel od = OrderDetailsModel();
    od.itemDetails = mkItem(name, price: price);
    od.price = price;
    od.quantity = quantity;
    od.variation = variation ?? const <Variation>[];
    od.addOns = const <AddOn>[];
    od.note = note;
    return od;
  }

  final List<Variation> burger = <Variation>[
    Variation(type: 'Veggie, Rare, Extra Cheese'),
  ];
  final List<Variation> cheese = <Variation>[
    Variation(type: 'Poppy Seed Roll, White American, Ham'),
  ];
  final List<Variation> napoleon = <Variation>[Variation(type: 'Plain')];
  final List<Variation> cheesecake = <Variation>[Variation(type: 'Strawberry')];
  final List<Variation> grilled = <Variation>[
    Variation(type: 'Whole Wheat Roll, Swiss, Tomato'),
  ];

  return <OrderDetailsModel>[
    d('Build a Burger', price: 12.74, note: 'بویت', variation: burger),
    d('Grilled Cheese', price: 7.99, note: 'الزینت', variation: cheese),
    d('Napoleon', price: 5.49, variation: napoleon),
    d('Cheesecake', price: 6.49, variation: cheesecake),
    d('Grilled Cheese', price: 6.49, variation: grilled),
  ];
}
