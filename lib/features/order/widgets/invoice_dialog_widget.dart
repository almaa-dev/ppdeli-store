import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/common/widgets/dotted_divider.dart';
import 'package:ppdelistore/features/language/controllers/language_controller.dart';
import 'package:ppdelistore/features/order/widgets/price_widget.dart';
import 'package:ppdelistore/features/printer/helper/printer_helper.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/features/store/domain/models/item_model.dart';
import 'package:ppdelistore/features/order/domain/models/order_details_model.dart';
import 'package:ppdelistore/features/order/domain/models/order_model.dart';
import 'package:ppdelistore/features/profile/domain/models/profile_model.dart';
import 'package:ppdelistore/helper/date_converter_helper.dart';
import 'package:ppdelistore/helper/price_converter_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';

/// On-screen preview of the order invoice.
///
/// **Important:** This widget is **only the visual preview**. The print
/// pipeline no longer renders this widget as a screenshot — it is purely a
/// UI reference for the operator. The native ESC/POS byte stream sent to the
/// thermal printer is produced by [PrinterHelper.buildInvoiceBytes] (which
/// delegates to `InvoiceReceiptBuilder`).
///
/// The legacy [ScreenshotController] parameter has been **removed**: it is
/// no longer required, and the [Screenshot] wrapper that previously
/// surrounded the invoice body has been unwrapped as well.
class InvoiceDialogWidget extends StatelessWidget {
  final OrderModel? order;
  final List<OrderDetailsModel>? orderDetails;
  final bool? isPrescriptionOrder;
  final bool paper80MM;
  final double dmTips;
  const InvoiceDialogWidget({
    super.key,
    required this.order,
    required this.orderDetails,
    required this.isPrescriptionOrder,
    required this.paper80MM,
    required this.dmTips,
  });

  String _priceDecimal(double price) =>
      PriceConverterHelper.convertPrice(price);

  /// Returns the human-readable delivery label that mirrors the
  /// reference image exactly. Translation keys are checked first;
  /// unknown orderType values fall back to a derived Title Case
  /// (e.g. "delivery" → "Delivery", "take_away" → "Take Away").
  String _deliveryLabel(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final String translated = raw.tr;
    if (translated == raw) {
      // No translation key — derive from raw, replacing underscores.
      final String pretty = raw
          .replaceAll('_', ' ')
          .split(' ')
          .where((String s) => s.isNotEmpty)
          .map((String s) => s[0].toUpperCase() + s.substring(1))
          .join(' ');
      return pretty;
    }
    return translated;
  }

  /// Returns the human-readable payment method label. Most restaurants
  /// only need three values (`cash_on_delivery`, `digital_payment`,
  /// `wallet`). Anything else is derived just like [_deliveryLabel].
  String _paymentLabel(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final String translated = raw.tr;
    if (translated == raw) {
      final String pretty = raw
          .replaceAll('_', ' ')
          .split(' ')
          .where((String s) => s.isNotEmpty)
          .map((String s) => s[0].toUpperCase() + s.substring(1))
          .join(' ');
      return pretty;
    }
    return translated;
  }

  /// Splits the date returned by [DateConverterHelper] into two
  /// right-aligned rows: the date on top, the time (bold) underneath,
  /// matching the layout in the reference image.
  List<Widget> _buildOrderDateColumns({
    required BuildContext context,
    required String createdAt,
    required double fontSize,
  }) {
    String raw = '';
    try {
      raw = DateConverterHelper.dateTimeStringToMonthAndTime(createdAt);
    } catch (_) {
      raw = createdAt;
    }
    final List<String> parts = raw
        .split('\n')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
    final List<Widget> out = <Widget>[];
    if (parts.isNotEmpty) {
      out.add(
        Text(
          parts.first,
          textAlign: TextAlign.end,
          style: robotoMedium.copyWith(color: Colors.black, fontSize: fontSize),
        ),
      );
    }
    if (parts.length > 1) {
      out.add(const SizedBox(height: 1));
      out.add(
        Text(
          parts[1],
          textAlign: TextAlign.end,
          style: robotoBold.copyWith(
            color: Colors.black,
            fontSize: fontSize + 0.5,
          ),
        ),
      );
    }
    return out;
  }

  /// Extracts only the variation value(s) from any raw variation string —
  /// dropping the label and the parentheses entirely.
  ///
  /// Examples:
  ///   "Burger - Turkey, Preparation - Medium Rare"
  ///     -> ["Turkey", "Medium Rare"]
  ///   "choose your burger (turkey)"
  ///     -> ["turkey"]
  ///   "Size (Large, Medium)"
  ///     -> ["Large", "Medium"]
  ///   "Size (Large), Color (Red)"
  ///     -> ["Large", "Red"]
  List<String> _splitVariationText(String raw) {
    if (raw.trim().isEmpty) return const <String>[];

    // 1) If anything is wrapped in parentheses, everything inside is the
    // actual value, the rest is just labels.
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

    // 2) Fallback: legacy "Label - Value" comma-separated string.
    final List<String> result = <String>[];
    for (final String part in raw.split(',')) {
      String trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      // Strip "Label - " prefix; keep only what comes after the separator.
      final int sepIndex = trimmed.indexOf(' - ');
      if (sepIndex >= 0) {
        trimmed = trimmed.substring(sepIndex + 3).trim();
      }
      if (trimmed.isNotEmpty) result.add(trimmed);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final double fontSize = paper80MM ? 13 : 11;
    Store store = Get.find<ProfileController>().profileModel!.stores![0];

    double itemsPrice = 0;
    double addOns = 0;

    if (isPrescriptionOrder!) {
      double orderAmount = order!.orderAmount ?? 0;
      double discount = order!.storeDiscountAmount ?? 0;
      double tax = order!.totalTaxAmount ?? 0;
      double deliveryCharge = order!.deliveryCharge ?? 0;
      double additionalCharge = order!.additionalCharge!;
      bool taxIncluded = order!.taxStatus ?? false;
      itemsPrice =
          (orderAmount + discount) -
          ((taxIncluded ? 0 : tax) + deliveryCharge + additionalCharge) -
          dmTips;
    }
    for (OrderDetailsModel orderDetails in orderDetails!) {
      for (AddOn addOn in orderDetails.addOns!) {
        addOns = addOns + (addOn.price! * addOn.quantity!);
      }
      if (!isPrescriptionOrder!) {
        itemsPrice =
            itemsPrice + (orderDetails.price! * orderDetails.quantity!);
      }
    }

    return OrientationBuilder(
      builder: (context, orientation) {
        // The on-screen preview is rendered at a fixed logical width that
        // matches the physical paper width used by the thermal printer (see
        // [PrinterHelper.buildDimensions80mm] / [buildDimensions58mm]). The
        // **print pipeline no longer captures this widget** — it is purely a
        // visual reference for the operator; the bytes sent to the printer
        // are produced natively by `InvoiceReceiptBuilder`.
        final double printWidth = paper80MM
            ? PrinterHelper.buildDimensions80mm
            : PrinterHelper.buildDimensions58mm;
        final bool taxIncluded = order!.taxStatus!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 1.4),
                ),
                width: printWidth,
                padding: EdgeInsets.symmetric(
                  horizontal: paper80MM ? 10 : 8,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ──────────── HEADER ────────────
                    // Reference image: store name + triple-star ornament +
                    // address + phone, framed by a thin top border and a
                    // thick separator at the bottom.
                    Container(
                      padding: const EdgeInsets.only(bottom: 6),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.black, width: 1.2),
                          bottom: BorderSide(color: Colors.black, width: 1.8),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            store.name!.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: robotoBlack.copyWith(
                              color: Colors.black,
                              fontSize: fontSize + 3,
                              letterSpacing: 0.6,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '★ ───── ★ ───── ★',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: fontSize - 4,
                              letterSpacing: 0.2,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            store.address ?? '',
                            textAlign: TextAlign.center,
                            style: robotoMedium.copyWith(
                              color: Colors.black,
                              fontSize: fontSize - 0.5,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${'phone'.tr}: ${store.phone ?? ''}',
                            textAlign: TextAlign.center,
                            style: robotoMedium.copyWith(
                              color: Colors.black,
                              fontSize: fontSize,
                              height: 1.2,
                            ),
                          ),
                          // if (store.email != null && store.email!.isNotEmpty)
                          //   Text(
                          //     store.email!,
                          //     textAlign: TextAlign.center,
                          //     style: robotoMedium.copyWith(
                          //       color: Colors.black,
                          //       fontSize: fontSize - 2,
                          //       height: 1.1,
                          //     ),
                          //   ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),

                    // ──────────── ORDER INFO (# + date) ────────────
                    // Reference image: "# {id}" bold left, date right and
                    // time on a second bold line. Dashed separator below.
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              '# ${order!.id}',
                              style: robotoBlack.copyWith(
                                color: Colors.black,
                                fontSize: fontSize + 2,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 8,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: _buildOrderDateColumns(
                                context: context,
                                createdAt: order!.createdAt!,
                                fontSize: fontSize,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: DottedDivider(
                        height: 1.2,
                        dashWidth: 4,
                        dashHeight: 1.2,
                      ),
                    ),

                    // ──────────── SCHEDULED (optional) ────────────
                    if (order!.scheduled == 1) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${'scheduled_order_time'.tr}:',
                            style: robotoBold.copyWith(
                              color: Colors.black,
                              fontSize: fontSize,
                            ),
                          ),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              DateConverterHelper.dateTimeStringToDateTime(
                                order!.scheduleAt!,
                              ),
                              style: robotoMedium.copyWith(
                                color: Colors.black,
                                fontSize: fontSize - 1,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],

                    // ──────────── DELIVERY / PAYMENT ────────────
                    // Dashed top + dashed bottom band matching the
                    // reference image. The two side-by-side labels
                    // (Delivery | Cash On Delivery) are bold.
                    const DottedDivider(
                      height: 1.2,
                      dashWidth: 4,
                      dashHeight: 1.2,
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              _deliveryLabel(order!.orderType),
                              style: robotoBlack.copyWith(
                                color: Colors.black,
                                fontSize: fontSize + 1,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              _paymentLabel(order!.paymentMethod),
                              style: robotoBlack.copyWith(
                                color: Colors.black,
                                fontSize: fontSize + 1,
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const DottedDivider(
                      height: 1.2,
                      dashWidth: 4,
                      dashHeight: 1.2,
                    ),
                    const SizedBox(height: 6),

                    // ──────────── CUSTOMER ────────────
                    if (order!.orderType != 'take_away')
                      Align(
                        alignment: Get.find<LocalizationController>().isLtr
                            ? Alignment.topLeft
                            : Alignment.topRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '👤 ',
                                    style: TextStyle(
                                      fontSize: fontSize + 1,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      order!
                                              .deliveryAddress
                                              ?.contactPersonName ??
                                          '',
                                      style: robotoBlack.copyWith(
                                        color: Colors.black,
                                        fontSize: fontSize + 1,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '📍 ',
                                    style: TextStyle(
                                      fontSize: fontSize + 1,
                                      color: Colors.red,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      order!.deliveryAddress?.address ?? '',
                                      style: robotoMedium.copyWith(
                                        color: Colors.black,
                                        fontSize: fontSize,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (order!.deliveryAddress?.contactPersonNumber !=
                                      null &&
                                  order!
                                      .deliveryAddress!
                                      .contactPersonNumber!
                                      .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '📞 ',
                                        style: TextStyle(
                                          fontSize: fontSize + 1,
                                          color: Colors.green,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          order!
                                              .deliveryAddress!
                                              .contactPersonNumber!,
                                          style: robotoMedium.copyWith(
                                            color: Colors.black,
                                            fontSize: fontSize,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                                              // ── Street Number (label: "Apartment Number") ──
                              if ((order!.deliveryAddress?.streetNumber ??
                                          '')
                                      .trim()
                                      .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '🏢 ',
                                        style: TextStyle(
                                          fontSize: fontSize + 1,
                                          color: Colors.deepPurple,
                                        ),
                                      ),
                                      Text(
                                        '${'street_number'.tr}: ',
                                        style: robotoBold.copyWith(
                                          color: Colors.black,
                                          fontSize: fontSize,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          order!.deliveryAddress!
                                              .streetNumber!,
                                          style: robotoMedium.copyWith(
                                            color: Colors.black,
                                            fontSize: fontSize,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // ── House (label: "State") ──
                              if ((order!.deliveryAddress?.house ?? '')
                                      .trim()
                                      .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '🗺️ ',
                                        style: TextStyle(
                                          fontSize: fontSize + 1,
                                          color: Colors.orange,
                                        ),
                                      ),
                                      Text(
                                        '${'house'.tr}: ',
                                        style: robotoBold.copyWith(
                                          color: Colors.black,
                                          fontSize: fontSize,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          order!.deliveryAddress!.house!,
                                          style: robotoMedium.copyWith(
                                            color: Colors.black,
                                            fontSize: fontSize,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // ── Floor (label: "ZIP Code") ──
                              if ((order!.deliveryAddress?.floor ?? '')
                                      .trim()
                                      .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '📮 ',
                                        style: TextStyle(
                                          fontSize: fontSize + 1,
                                          color: Colors.brown,
                                        ),
                                      ),
                                      Text(
                                        '${'floor'.tr}: ',
                                        style: robotoBold.copyWith(
                                          color: Colors.black,
                                          fontSize: fontSize,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          order!.deliveryAddress!.floor!,
                                          style: robotoMedium.copyWith(
                                            color: Colors.black,
                                            fontSize: fontSize,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (order!.orderType != 'take_away')
                      const SizedBox(height: 6),

                    // ──────────── ITEMS TABLE HEADER ────────────
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: const BoxDecoration(color: Colors.black),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Text(
                              '#',
                              textAlign: TextAlign.center,
                              style: robotoBlack.copyWith(
                                color: Colors.white,
                                fontSize: fontSize,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                'item_info'.tr.toUpperCase(),
                                style: robotoBlack.copyWith(
                                  color: Colors.white,
                                  fontSize: fontSize,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'qty'.tr.toUpperCase(),
                              style: robotoBlack.copyWith(
                                color: Colors.white,
                                fontSize: fontSize,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'price'.tr.toUpperCase(),
                              style: robotoBlack.copyWith(
                                color: Colors.white,
                                fontSize: fontSize,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ──────────── ITEMS LIST ────────────
                    ListView.separated(
                      itemCount: orderDetails!.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.black,
                      ),
                      itemBuilder: (context, index) {
                        // Addons text — also rendered as bullet list.
                        final List<String> addOnParts = <String>[];
                        for (var addOn in orderDetails![index].addOns!) {
                          addOnParts.add('${addOn.name} ×${addOn.quantity}');
                        }

                        // Variations text (still constructed the legacy
                        // way, then split into separate lines).
                        String variationText = '';
                        if (orderDetails![index].variation!.isNotEmpty) {
                          if (orderDetails![index].variation!.isNotEmpty) {
                            List<String> variationTypes = orderDetails![index]
                                .variation![0]
                                .type!
                                .split('-');
                            if (variationTypes.length ==
                                orderDetails![index]
                                    .itemDetails!
                                    .choiceOptions!
                                    .length) {
                              int idx = 0;
                              for (var choice
                                  in orderDetails![index]
                                      .itemDetails!
                                      .choiceOptions!) {
                                variationText =
                                    '$variationText${(idx == 0) ? '' : ',  '}${choice.title} - ${variationTypes[idx]}';
                                idx = idx + 1;
                              }
                            } else {
                              variationText = orderDetails![index]
                                  .itemDetails!
                                  .variations![0]
                                  .type!;
                            }
                          }
                        } else if (orderDetails![index]
                            .foodVariation!
                            .isNotEmpty) {
                          for (FoodVariation variation
                              in orderDetails![index].foodVariation!) {
                            variationText +=
                                '${variationText.isNotEmpty ? ', ' : ''}${variation.name} (';
                            for (VariationValue value
                                in variation.variationValues!) {
                              variationText +=
                                  '${variationText.endsWith('(') ? '' : ', '}${value.level}';
                            }
                            variationText += ')';
                          }
                        }

                        final List<String> variationParts = _splitVariationText(
                          variationText,
                        );
                        final String noteText = orderDetails![index].note ?? '';
                        final bool hasNote = noteText.trim().isNotEmpty;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 1,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 1,
                                child: Text(
                                  (index + 1).toString(),
                                  textAlign: TextAlign.center,
                                  style: robotoBlack.copyWith(
                                    color: Colors.black,
                                    fontSize: fontSize,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Item name
                                    Text(
                                      orderDetails![index].itemDetails!.name!,
                                      style: robotoBlack.copyWith(
                                        color: Colors.black,
                                        fontSize: fontSize,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),

                                    // Variations — one per line, bullet style.
                                    if (variationParts.isNotEmpty) ...[
                                      for (final String line in variationParts)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 6,
                                            top: 1,
                                          ),
                                          child: Text(
                                            '• $line',
                                            style: robotoMedium.copyWith(
                                              color: Colors.black,
                                              fontSize: fontSize - 1,
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 3),
                                    ],

                                    // Add-ons — also bullet list.
                                    if (addOnParts.isNotEmpty) ...[
                                      Text(
                                        '${'addons'.tr}:',
                                        style: robotoBold.copyWith(
                                          color: Colors.black,
                                          fontSize: fontSize - 1,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      for (final String line in addOnParts)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 6,
                                            top: 1,
                                          ),
                                          child: Text(
                                            '• $line',
                                            style: robotoMedium.copyWith(
                                              color: Colors.black,
                                              fontSize: fontSize - 1,
                                              height: 1.2,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 3),
                                    ],

                                    // Note — italic for visual distinction.
                                    if (hasNote)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: RichText(
                                          text: TextSpan(
                                            style: robotoMedium.copyWith(
                                              color: Colors.black,
                                              fontSize: fontSize - 1,
                                              height: 1.2,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: '${'note'.tr}: ',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              TextSpan(
                                                text: noteText,
                                                style: const TextStyle(
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  orderDetails![index].quantity.toString(),
                                  textAlign: TextAlign.center,
                                  style: robotoBlack.copyWith(
                                    color: Colors.black,
                                    fontSize: fontSize,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  _priceDecimal(orderDetails![index].price!),
                                  textAlign: TextAlign.end,
                                  style: robotoBold.copyWith(
                                    color: Colors.black,
                                    fontSize: fontSize,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    if (order!.orderNote != null &&
                        order!.orderNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: TextSpan(
                            style: robotoMedium.copyWith(
                              color: Colors.black,
                              fontSize: fontSize,
                              height: 1.25,
                            ),
                            children: [
                              TextSpan(
                                text: 'Order Note: ',
                                style: robotoBold.copyWith(
                                  color: Colors.black,
                                  fontSize: fontSize,
                                ),
                              ),
                              TextSpan(text: order!.orderNote!.trim()),
                            ],
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: DottedDivider(
                          height: 1.5,
                          dashWidth: 4,
                          dashHeight: 1.5,
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // ──────────── TOTALS ────────────
                    // Reference image: light gray background containing
                    // "Item Price", "Subtotal", "Tax" (and any optional
                    // extras like discount / delivery fee).
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Column(
                        children: [
                          if (!isPrescriptionOrder!) ...[
                            PriceWidget(
                              title: 'item_price'.tr,
                              value: _priceDecimal(itemsPrice),
                              fontSize: fontSize,
                            ),
                            const SizedBox(height: 3),
                            PriceWidget(
                              title: 'subtotal'.tr,
                              value: _priceDecimal(itemsPrice + addOns),
                              fontSize: fontSize,
                            ),
                            const SizedBox(height: 3),
                          ],

                          if (order!.storeDiscountAmount! > 0) ...[
                            PriceWidget(
                              title: 'discount'.tr,
                              value:
                                  '- ${_priceDecimal(order!.storeDiscountAmount!)}',
                              fontSize: fontSize,
                            ),
                            const SizedBox(height: 3),
                          ],

                          if (order!.couponDiscountAmount! > 0) ...[
                            PriceWidget(
                              title: 'coupon_discount'.tr,
                              value:
                                  '- ${_priceDecimal(order!.couponDiscountAmount!)}',
                              fontSize: fontSize,
                            ),
                            const SizedBox(height: 3),
                          ],

                          if (order!.referrerBonusAmount! > 0) ...[
                            PriceWidget(
                              title: 'referral_discount'.tr,
                              value:
                                  '- ${_priceDecimal(order!.referrerBonusAmount!)}',
                              fontSize: fontSize,
                            ),
                            const SizedBox(height: 3),
                          ],

                          if (!taxIncluded && order!.totalTaxAmount! > 0) ...[
                            PriceWidget(
                              title: 'tax'.tr,
                              value:
                                  '+ ${_priceDecimal(order!.totalTaxAmount!)}',
                              fontSize: fontSize,
                            ),
                            const SizedBox(height: 3),
                          ],

                          if (dmTips > 0) ...[
                            PriceWidget(
                              title: 'delivery_man_tips'.tr,
                              value: '+ ${_priceDecimal(dmTips)}',
                              fontSize: fontSize,
                            ),
                            const SizedBox(height: 3),
                          ],

                          if (order!.extraPackagingAmount! > 0) ...[
                            PriceWidget(
                              title: 'extra_packaging'.tr,
                              value:
                                  '+ ${_priceDecimal(order!.extraPackagingAmount!)}',
                              fontSize: fontSize,
                            ),
                            const SizedBox(height: 3),
                          ],

                          if (order!.deliveryCharge! > 0) ...[
                            PriceWidget(
                              title: 'delivery_fee'.tr,
                              value:
                                  '+ ${_priceDecimal(order!.deliveryCharge!)}',
                              fontSize: fontSize,
                            ),
                            const SizedBox(height: 3),
                          ],

                          if (order!.additionalCharge != null &&
                              order!.additionalCharge! > 0) ...[
                            PriceWidget(
                              title: Get.find<SplashController>()
                                  .configModel!
                                  .additionalChargeName!,
                              value:
                                  '+ ${_priceDecimal(order!.additionalCharge!)}',
                              fontSize: fontSize,
                            ),
                            const SizedBox(height: 3),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ──────────── GRAND TOTAL ────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'total_amount'.tr.toUpperCase(),
                            style: robotoBlack.copyWith(
                              color: Colors.white,
                              fontSize: fontSize + 2,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Text(
                            _priceDecimal(order!.orderAmount!),
                            style: robotoBlack.copyWith(
                              color: Colors.white,
                              fontSize: fontSize + 5,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),

                    // ──────────── FOOTER ────────────
                    // Reference image: solid top separator, then a large
                    // centered "✹ Thank You ✹" headline (matching the
                    // receipt's star motif), then another separator, and
                    // finally a row of "[Business Name]   @ {year}" set
                    // with the business name on the left and the year on
                    // the right.
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.black, width: 1),
                        ),
                      ),
                      padding: const EdgeInsets.only(top: 6, bottom: 6),
                      child: Column(
                        children: [
                          Text(
                            '✹ Thank You ✹',
                            textAlign: TextAlign.center,
                            style: robotoBlack.copyWith(
                              color: Colors.black,
                              fontSize: fontSize + 5,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                Get.find<SplashController>()
                                        .configModel!
                                        .businessName ??
                                    '',
                                style: robotoBold.copyWith(
                                  color: Colors.black,
                                  fontSize: fontSize,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              Text(
                                '@ ${DateTime.now().year}',
                                style: robotoMedium.copyWith(
                                  color: Colors.black,
                                  fontSize: fontSize,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
