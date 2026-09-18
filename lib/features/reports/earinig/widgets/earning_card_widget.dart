import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/common/widgets/custom_asset_image_widget.dart';
import 'package:ppdelistore/helper/price_converter_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';
import 'package:ppdelistore/util/styles.dart';

class EarningCardWidget extends StatelessWidget {
  final Color cardColor;
  final String icon;
  final Color iconColor;
  final String title;
  final double amount;
  final List<Map<String, dynamic>>? data;
  final String? profitText;
  const EarningCardWidget({
    super.key,
    required this.cardColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.data,
    this.profitText,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: robotoMedium.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyLarge!.color?.withValues(alpha: 0.6),
                        fontSize: Dimensions.fontSizeExtraSmall,
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                    Text(
                      PriceConverterHelper.convertPrice(amount),
                      style: robotoSemiBold.copyWith(
                        color: iconColor,
                        fontSize: Dimensions.fontSizeLarge,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),

              _IconWidget(icon: icon, color: iconColor),
            ],
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),

          if (data != null)
            SizedBox(
              height: 45,
              child: ListView.builder(
                itemCount: data!
                    .length, //reportController.taxReportModel?.taxSummary?.length,
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  return Container(
                    padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                    margin: EdgeInsets.only(
                      right: index == (data?.length ?? 0) - 1
                          ? 0
                          : Dimensions.paddingSizeSmall,
                    ),
                    width: 240,
                    decoration: BoxDecoration(
                      color: Get.isDarkMode
                          ? Theme.of(context).hintColor.withValues(alpha: 0.3)
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusSmall,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${data![index]['label']}'.tr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: robotoMedium.copyWith(
                              color: Theme.of(context).hintColor,
                              fontSize: Dimensions.fontSizeExtraSmall,
                            ),
                          ),
                        ),
                        SizedBox(width: Dimensions.paddingSizeSmall),

                        Text(
                          PriceConverterHelper.convertPrice(
                            data![index]['value']?.toDouble() ?? 0.0,
                          ),
                          style: robotoMedium.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          if (profitText != null)
            Container(
              height: 45,
              width: double.infinity,
              padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
              decoration: BoxDecoration(
                color: Get.isDarkMode
                    ? Theme.of(context).hintColor.withValues(alpha: 0.3)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              ),
              child: Row(
                children: [
                  CustomAssetImageWidget(
                    Images.noteIconTwo,
                    height: 12,
                    width: 12,
                    color: iconColor,
                  ),
                  SizedBox(width: Dimensions.paddingSizeSmall),

                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        profitText!,
                        maxLines: 1,
                        style: robotoMedium.copyWith(
                          color: Theme.of(context).hintColor,
                          fontSize: Dimensions.fontSizeExtraSmall,
                        ),
                      ),
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

class _IconWidget extends StatelessWidget {
  final String icon;
  final Color color;
  const _IconWidget({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: CustomAssetImageWidget(icon, height: 20, width: 20),
    );
  }
}
