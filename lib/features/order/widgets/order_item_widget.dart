import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/features/store/domain/models/item_model.dart';
import 'package:ppdelistore/features/order/domain/models/order_details_model.dart';
import 'package:ppdelistore/features/order/domain/models/order_model.dart';
import 'package:ppdelistore/helper/price_converter_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:ppdelistore/common/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OrderItemWidget extends StatelessWidget {
  final OrderModel? order;
  final OrderDetailsModel orderDetails;
  const OrderItemWidget({
    super.key,
    required this.order,
    required this.orderDetails,
  });

  @override
  Widget build(BuildContext context) {
    String addOnText = '';
    for (var addOn in orderDetails.addOns!) {
      addOnText =
          '$addOnText${(addOnText.isEmpty) ? '' : ',  '}${addOn.name} (${addOn.quantity})';
    }

    String variationText = '';
    if (orderDetails.variation!.isNotEmpty) {
      if (orderDetails.variation!.isNotEmpty) {
        List<String> variationTypes = orderDetails.variation![0].type!.split(
          '-',
        );
        if (variationTypes.length ==
            orderDetails.itemDetails!.choiceOptions!.length) {
          int index = 0;
          for (var choice in orderDetails.itemDetails!.choiceOptions!) {
            variationText =
                '$variationText${(index == 0) ? '' : ',  '}${choice.title} - ${variationTypes[index]}';
            index = index + 1;
          }
        } else {
          variationText = orderDetails.itemDetails!.variations![0].type!;
        }
      }
    } else if (orderDetails.foodVariation!.isNotEmpty) {
      for (FoodVariation variation in orderDetails.foodVariation!) {
        variationText +=
            '${variationText.isNotEmpty ? ', ' : ''}${variation.name} (';
        for (VariationValue value in variation.variationValues!) {
          variationText +=
              '${variationText.endsWith('(') ? '' : ', '}${value.level}';
        }
        variationText += ')';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            orderDetails.itemDetails!.imageFullUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    child: CustomImageWidget(
                      height: 50,
                      width: 50,
                      fit: BoxFit.cover,
                      image: '${orderDetails.itemDetails!.imageFullUrl}',
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    child: CustomImageWidget(
                      height: 50,
                      width: 50,
                      fit: BoxFit.cover,
                      image: Images.image,
                    ),
                  ),
            SizedBox(width: Dimensions.paddingSizeSmall),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          orderDetails.itemDetails!.name!,
                          style: robotoBold.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      Text(
                        '${'quantity'.tr}: ',
                        style: robotoRegular.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      Text(
                        orderDetails.quantity.toString(),
                        style: robotoMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          PriceConverterHelper.convertPrice(orderDetails.price),
                          style: robotoMedium.copyWith(
                            fontSize: Dimensions.fontSizeLarge,
                          ),
                        ),
                      ),
                      ((Get.find<SplashController>()
                                      .configModel!
                                      .moduleConfig!
                                      .module!
                                      .unit! &&
                                  orderDetails.itemDetails!.unitType != null) ||
                              (Get.find<SplashController>()
                                      .configModel!
                                      .moduleConfig!
                                      .module!
                                      .vegNonVeg! &&
                                  Get.find<SplashController>()
                                      .configModel!
                                      .toggleVegNonVeg!))
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: Dimensions.paddingSizeExtraSmall,
                                horizontal: Dimensions.paddingSizeSmall,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusSmall,
                                ),
                                color: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.1),
                              ),
                              child: Text(
                                Get.find<SplashController>()
                                        .configModel!
                                        .moduleConfig!
                                        .module!
                                        .unit!
                                    ? orderDetails.itemDetails!.unitType ?? ''
                                    : orderDetails.itemDetails!.veg == 0
                                    ? 'non_veg'.tr
                                    : 'veg'.tr,
                                style: robotoMedium.copyWith(
                                  fontSize: Dimensions.fontSizeSmall,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            )
                          : const SizedBox(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        variationText.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(
                  top: Dimensions.paddingSizeExtraSmall,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text(
                        '${'variations'.tr} ',
                        style: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                    Text(': '),
                    Expanded(
                      flex: 4,
                      child: Text(
                        " $variationText",
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox(),

        addOnText.isNotEmpty
            ? Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${'addons'.tr} ',
                      style: robotoMedium.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                  Text(': '),
                  Expanded(
                    flex: 4,
                    child: Text(
                      " $addOnText",
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                ],
              )
            : const SizedBox(),
      ],
    );
  }
}
