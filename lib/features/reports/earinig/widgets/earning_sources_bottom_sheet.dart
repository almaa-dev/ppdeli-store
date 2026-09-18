import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/features/reports/controllers/report_controller.dart';
import 'package:ppdelistore/features/reports/domain/models/earning_report_model.dart';
import 'package:ppdelistore/helper/price_converter_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';

class EarningSourcesBottomSheet extends StatelessWidget {
  final int index;
  EarningSourcesBottomSheet({super.key, required this.index});
  final ReportController reportController = Get.find<ReportController>();

  @override
  Widget build(BuildContext context) {
    final bool isEarning = reportController.type == 'earning';
    final bool isExpense = reportController.type == 'expense';
    final TransactionModel transactionModel =
        reportController.getEarningReportModel!.transactions!.data[index];
    final Map<dynamic, dynamic>? breakdown = transactionModel.breakdown is Map
        ? transactionModel.breakdown as Map
        : null;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40),

              Container(
                height: 5,
                width: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).disabledColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              InkWell(
                onTap: () => Get.back(),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.highlight_remove,
                    color: Theme.of(context).disabledColor,
                    size: 25,
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  isEarning
                      ? "earning_source".tr
                      : isExpense
                      ? "expense_source".tr
                      : "subscription".tr,
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                  ),
                ),
                Text(
                  transactionModel.transactionId ?? "",
                  style: robotoRegular.copyWith(
                    color: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.color?.withAlpha(170),
                    fontSize: Dimensions.fontSizeSmall,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeLarge),

                if (breakdown != null && breakdown.isNotEmpty)
                  ...List.generate(breakdown.length, (index) {
                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimensions.paddingSizeSmall,
                            vertical: Dimensions.paddingSizeSmall,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).hintColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusSmall,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${breakdown.keys.toList()[index]}'.tr,
                                style: robotoRegular.copyWith(
                                  fontSize: Dimensions.fontSizeSmall,
                                ),
                              ),
                              const Spacer(),

                              Text(
                                '${isEarning ? '+' : '-'} ${PriceConverterHelper.convertPrice(double.tryParse(breakdown.values.toList()[index].toString()) ?? 0.0)}',
                                style: robotoRegular.copyWith(
                                  fontSize: Dimensions.fontSizeSmall,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (index != (breakdown.length - 1))
                          const SizedBox(height: Dimensions.paddingSizeSmall),
                      ],
                    );
                  }),

                if (!isEarning && (breakdown == null || breakdown.isEmpty))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeSmall,
                      vertical: Dimensions.paddingSizeSmall,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).hintColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusSmall,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          isExpense
                              ? (transactionModel.badge ?? '')
                              : transactionModel.transactionType ??
                                    'subscription_fee'.tr,
                          style: robotoRegular.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        ),
                        const Spacer(),

                        Text(
                          '${'-'} ${PriceConverterHelper.convertPrice((transactionModel.amount ?? 0.0))}',
                          style: robotoRegular.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                          ),
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
  }
}
