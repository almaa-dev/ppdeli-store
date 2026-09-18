import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/common/widgets/custom_button_widget.dart';
import 'package:ppdelistore/common/widgets/custom_ink_well_widget.dart';
import 'package:ppdelistore/common/widgets/custom_snackbar_widget.dart';
import 'package:ppdelistore/features/coupon/controllers/coupon_controller.dart';
import 'package:ppdelistore/features/coupon/domain/models/coupon_body_model.dart';
import 'package:ppdelistore/helper/date_converter_helper.dart';
import 'package:ppdelistore/helper/price_converter_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:ppdelistore/common/widgets/confirmation_dialog_widget.dart';
import 'package:ppdelistore/common/widgets/custom_loader_widget.dart';
import 'package:ppdelistore/features/coupon/screens/add_coupon_screen.dart';
import 'package:dotted_border/dotted_border.dart';

class CouponCardDialogueWidget extends StatelessWidget {
  final CouponBodyModel couponBody;
  final int index;
  const CouponCardDialogueWidget({
    super.key,
    required this.couponBody,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 500,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Dimensions.radiusLarge),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: Dimensions.paddingSizeSmall,
                      horizontal: Dimensions.paddingSizeExtraLarge,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(),
                            Container(
                              height: 5,
                              width: 70,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).disabledColor.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusDefault,
                                ),
                              ),
                            ),

                            InkWell(
                              onTap: () => Get.back(),
                              child: Icon(
                                Icons.close,
                                color: Theme.of(context).hintColor,
                                size: 20,
                              ),
                            ),
                          ],
                        ),

                        Padding(
                          padding: const EdgeInsets.only(
                            top: Dimensions.paddingSizeSmall,
                          ),
                          child: GetBuilder<CouponController>(
                            builder: (couponController) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  top: Dimensions.paddingSizeSmall,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      height: 50,
                                      width: 50,
                                      child: Image.asset(
                                        couponBody.discountType == 'percent'
                                            ? Images.fire
                                            : Images.cashIcon,
                                      ),
                                    ),
                                    Spacer(),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).disabledColor.withValues(alpha: 0.2),
                                        border: Border.all(
                                          color: Theme.of(
                                            context,
                                          ).disabledColor,
                                          width: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          Dimensions.radiusDefault,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: Dimensions.paddingSizeSmall,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            'status'.tr,
                                            style: robotoMedium,
                                          ),
                                          Transform.scale(
                                            scale: 0.7,
                                            child: CupertinoSwitch(
                                              activeTrackColor: Colors.teal,
                                              value:
                                                  couponController
                                                          .coupons![index]
                                                          .status ==
                                                      1
                                                  ? true
                                                  : false,
                                              onChanged: (bool status) {
                                                couponController
                                                    .changeStatus(
                                                      couponController
                                                          .coupons![index]
                                                          .id,
                                                      status,
                                                    )
                                                    .then((success) {
                                                      if (success) {
                                                        couponController
                                                            .getCouponList();
                                                      }
                                                    });
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                      width: Dimensions.paddingSizeSmall,
                                    ),

                                    Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).disabledColor.withValues(alpha: 0.2),
                                        border: Border.all(
                                          color: Theme.of(
                                            context,
                                          ).disabledColor,
                                          width: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          Dimensions.radiusDefault,
                                        ),
                                      ),
                                      child: CustomInkWellWidget(
                                        onTap: () {
                                          Get.back();
                                          Get.dialog(
                                            ConfirmationDialogWidget(
                                              icon: Images.warning,
                                              title:
                                                  'are_you_sure_to_delete'.tr,
                                              description:
                                                  'you_want_to_delete_this_coupon'
                                                      .tr,
                                              onYesPressed: () {
                                                couponController.deleteCoupon(
                                                  couponBody.id,
                                                );
                                              },
                                            ),
                                            barrierDismissible: false,
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal:
                                                Dimensions.paddingSizeSmall,
                                            vertical:
                                                Dimensions.paddingSizeSmall - 3,
                                          ),
                                          child: Icon(
                                            Icons.delete_forever,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: Dimensions.paddingSizeSmall),
                        Text(
                          '${couponBody.title}',
                          style: robotoMedium.copyWith(fontSize: 20),
                          textDirection: TextDirection.ltr,
                        ),
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraSmall,
                        ),
                        Text(
                          '${DateConverterHelper.stringToLocalDateOnly(couponBody.startDate!)} - ${DateConverterHelper.stringToLocalDateOnly(couponBody.startDate!)}',
                          style: robotoMedium.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                            color: Theme.of(context).textTheme.bodyLarge!.color!
                                .withValues(alpha: 0.6),
                          ),
                        ),

                        const SizedBox(height: Dimensions.paddingSizeLarge),

                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).disabledColor.withValues(alpha: 0.07),
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).disabledColor.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusDefault,
                                  ),
                                ),
                                padding: const EdgeInsets.all(
                                  Dimensions.paddingSizeSmall,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'discount'.tr,
                                      style: robotoMedium.copyWith(
                                        fontSize: Dimensions.fontSizeSmall,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color!
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: Dimensions.paddingSizeExtraSmall,
                                    ),

                                    Text(
                                      '${'${couponBody.couponType == 'free_delivery'
                                          ? 'free_delivery'.tr
                                          : couponBody.discountType != 'percent'
                                          ? PriceConverterHelper.convertPrice(double.parse(couponBody.discount.toString()))
                                          : couponBody.discount}'} ${couponBody.couponType == 'free_delivery'
                                          ? ''
                                          : couponBody.discountType == 'percent'
                                          ? '% '
                                          : ''}'
                                      '${couponBody.couponType == 'free_delivery' ? '' : 'off'.tr}',
                                      style: robotoMedium.copyWith(
                                        fontSize: Dimensions.fontSizeSmall,
                                      ),
                                      textDirection: TextDirection.ltr,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: Dimensions.paddingSizeSmall),

                            Expanded(
                              child: DottedBorder(
                                options: RoundedRectDottedBorderOptions(
                                  color: Theme.of(
                                    context,
                                  ).disabledColor.withValues(alpha: 0.3),
                                  strokeWidth: 1,
                                  strokeCap: StrokeCap.butt,
                                  dashPattern: const [5, 5],
                                  padding: const EdgeInsets.all(0),
                                  radius: const Radius.circular(
                                    Dimensions.radiusDefault,
                                  ),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).disabledColor.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(
                                      Dimensions.radiusDefault,
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(
                                    Dimensions.paddingSizeSmall,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'coupon_code'.tr,
                                              style: robotoMedium.copyWith(
                                                fontSize:
                                                    Dimensions.fontSizeSmall,
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge!
                                                    .color!
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            const SizedBox(
                                              height: Dimensions
                                                  .paddingSizeExtraSmall,
                                            ),

                                            Text(
                                              '${couponBody.code}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: robotoMedium.copyWith(
                                                fontSize:
                                                    Dimensions.fontSizeSmall,
                                              ),
                                              textDirection: TextDirection.ltr,
                                            ),
                                          ],
                                        ),
                                      ),

                                      GestureDetector(
                                        onTap: () {
                                          Clipboard.setData(
                                            ClipboardData(
                                              text: couponBody.code!,
                                            ),
                                          ).then((value) {
                                            showCustomSnackBar(
                                              'coupon_code_copied'.tr,
                                              isError: false,
                                            );
                                          });
                                        },
                                        child: Icon(
                                          Icons.copy,
                                          color: Colors.blue,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Dimensions.paddingSizeLarge),

                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).disabledColor.withValues(alpha: 0.2),
                              width: 01,
                            ),
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusDefault,
                            ),
                          ),
                          child: Column(
                            children: [
                              section(
                                'total_user'.tr,
                                '${couponBody.totalUses ?? 0}',
                              ),
                              section(
                                'limit_for_same_user'.tr,
                                '${couponBody.limit ?? 0}',
                              ),
                              section(
                                'maximum_discount'.tr,
                                PriceConverterHelper.convertPrice(
                                  double.parse(
                                    couponBody.maxDiscount.toString(),
                                  ),
                                ),
                              ),
                              section(
                                'minimum_order_amount'.tr,
                                PriceConverterHelper.convertPrice(
                                  double.parse(
                                    couponBody.minPurchase.toString(),
                                  ),
                                ),
                                showDivider: false,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Dimensions.paddingSizeLarge),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
              child: GetBuilder<CouponController>(
                builder: (couponController) {
                  return Row(
                    children: [
                      Expanded(
                        child: CustomButtonWidget(
                          onPressed: () {
                            Get.back();
                          },
                          buttonText: 'cancel'.tr,
                          color: Theme.of(
                            context,
                          ).disabledColor.withValues(alpha: 0.2),
                          textColor: Theme.of(
                            context,
                          ).textTheme.bodyLarge!.color!,
                        ),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeLarge),

                      Expanded(
                        child: CustomButtonWidget(
                          onPressed: () {
                            Get.back();
                            Get.dialog(const CustomLoaderWidget());
                            couponController
                                .getCouponDetails(
                                  couponController.coupons![index].id!,
                                )
                                .then((couponDetails) {
                                  Get.back();
                                  if (couponDetails != null) {
                                    Get.to(
                                      () => AddCouponScreen(
                                        coupon: couponDetails,
                                      ),
                                    );
                                  }
                                });
                          },
                          buttonText: 'edit'.tr,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget section(String title, String value, {bool showDivider = true}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                  color: Theme.of(Get.context!).hintColor,
                ),
              ),

              Text(
                value,
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeDefault,
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 5),
      ],
    );
  }
}
