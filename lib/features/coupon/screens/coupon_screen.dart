import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/features/coupon/controllers/coupon_controller.dart';
import 'package:ppdelistore/features/language/controllers/language_controller.dart';
import 'package:ppdelistore/features/coupon/widgets/coupon_card_dialogue_widget.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/helper/date_converter_helper.dart';
import 'package:ppdelistore/helper/price_converter_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:ppdelistore/common/widgets/confirmation_dialog_widget.dart';
import 'package:ppdelistore/common/widgets/custom_app_bar_widget.dart';
import 'package:ppdelistore/common/widgets/custom_loader_widget.dart';
import 'package:ppdelistore/features/coupon/screens/add_coupon_screen.dart';

class CouponScreen extends StatefulWidget {
  const CouponScreen({super.key});

  @override
  State<CouponScreen> createState() => _CouponScreenState();
}

class _CouponScreenState extends State<CouponScreen> {
  @override
  void initState() {
    super.initState();
    Get.find<CouponController>().getCouponList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: 'coupon_list'.tr),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to(() => const AddCouponScreen()),
        child: Icon(
          Icons.add_circle_outline,
          size: 30,
          color: Theme.of(context).cardColor,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Get.find<CouponController>().getCouponList();
        },
        child: GetBuilder<CouponController>(
          builder: (couponController) {
            return couponController.coupons != null
                ? couponController.coupons!.isNotEmpty
                      ? ListView.builder(
                          shrinkWrap: true,
                          itemCount: couponController.coupons!.length,
                          padding: const EdgeInsets.all(
                            Dimensions.paddingSizeLarge,
                          ),
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: Dimensions.paddingSizeDefault,
                              ),
                              child: InkWell(
                                onTap: () {
                                  Get.bottomSheet(
                                    CouponCardDialogueWidget(
                                      couponBody:
                                          couponController.coupons![index],
                                      index: index,
                                    ),
                                    isScrollControlled: true,
                                  );
                                },
                                child: SizedBox(
                                  height: 150,
                                  child: Stack(
                                    children: [
                                      Transform.rotate(
                                        angle:
                                            Get.find<LocalizationController>()
                                                .isLtr
                                            ? 0
                                            : pi,
                                        child: Container(
                                          height: 150,
                                          decoration: BoxDecoration(
                                            boxShadow: Get.isDarkMode
                                                ? null
                                                : [
                                                    BoxShadow(
                                                      color: Colors.grey
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      spreadRadius: 1,
                                                      blurRadius: 10,
                                                      offset: const Offset(
                                                        0,
                                                        1,
                                                      ),
                                                    ),
                                                  ],
                                          ),
                                          child: Image.asset(
                                            Images.couponBgDark,
                                            fit: BoxFit.fill,
                                            color: Get.isDarkMode
                                                ? Colors.black
                                                : null,
                                          ),
                                        ),
                                      ),

                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 6,
                                            child: Container(
                                              alignment: Alignment.center,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Center(
                                                    child: Image.asset(
                                                      couponController
                                                                  .coupons![index]
                                                                  .discountType ==
                                                              'percent'
                                                          ? Images.fire
                                                          : Images.cashIcon,
                                                      height: 35,
                                                      width: 35,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    height: Dimensions
                                                        .paddingSizeSmall,
                                                  ),

                                                  Text(
                                                    '${'${couponController.coupons![index].couponType == 'free_delivery'
                                                        ? 'free_delivery'.tr
                                                        : couponController.coupons![index].discountType != 'percent'
                                                        ? PriceConverterHelper.convertPrice(double.parse(couponController.coupons![index].discount.toString()))
                                                        : couponController.coupons![index].discount}'} ${couponController.coupons![index].couponType == 'free_delivery'
                                                        ? ''
                                                        : couponController.coupons![index].discountType == 'percent'
                                                        ? '% '
                                                        : ''}'
                                                    '${couponController.coupons![index].couponType == 'free_delivery' ? '' : 'off'.tr}',
                                                    style: robotoBold.copyWith(
                                                      fontSize: Dimensions
                                                          .fontSizeExtraLarge,
                                                    ),
                                                    textDirection:
                                                        TextDirection.ltr,
                                                  ),
                                                  const SizedBox(
                                                    height: Dimensions
                                                        .paddingSizeSmall,
                                                  ),

                                                  Text(
                                                    'on ${Get.find<ProfileController>().profileModel!.stores?[0].name ?? ''}',
                                                    style: robotoRegular
                                                        .copyWith(
                                                          fontSize: Dimensions
                                                              .fontSizeSmall,
                                                          color: Theme.of(
                                                            context,
                                                          ).hintColor,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: Dimensions
                                                .paddingSizeExtraSmall,
                                          ),

                                          Expanded(
                                            flex: 8,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: Dimensions
                                                        .paddingSizeSmall,
                                                    horizontal: Dimensions
                                                        .paddingSizeDefault,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Align(
                                                    alignment:
                                                        Alignment.topRight,
                                                    child: PopupMenuButton(
                                                      itemBuilder: (context) {
                                                        bool status =
                                                            couponController
                                                                    .coupons![index]
                                                                    .status ==
                                                                1
                                                            ? true
                                                            : false;
                                                        return <PopupMenuEntry>[
                                                          PopupMenuItem(
                                                            value: 'status',
                                                            child: Column(
                                                              children: [
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  children: [
                                                                    Text(
                                                                      'status'
                                                                          .tr,
                                                                      style:
                                                                          robotoMedium,
                                                                    ),
                                                                    SizedBox(
                                                                      width: 50,
                                                                    ),
                                                                    Container(
                                                                      width: 40,
                                                                      decoration: BoxDecoration(
                                                                        color:
                                                                            status
                                                                            ? Colors.teal
                                                                            : Theme.of(
                                                                                context,
                                                                              ).hintColor,
                                                                        borderRadius: BorderRadius.circular(
                                                                          Dimensions
                                                                              .radiusLarge,
                                                                        ),
                                                                      ),
                                                                      padding:
                                                                          const EdgeInsets.all(
                                                                            1,
                                                                          ),
                                                                      child: Align(
                                                                        alignment:
                                                                            status
                                                                            ? Alignment.centerRight
                                                                            : Alignment.centerLeft,
                                                                        child: Container(
                                                                          height:
                                                                              20,
                                                                          width:
                                                                              20,
                                                                          decoration: BoxDecoration(
                                                                            shape:
                                                                                BoxShape.circle,
                                                                            color: Theme.of(
                                                                              context,
                                                                            ).cardColor,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),

                                                          PopupMenuItem(
                                                            value: 'view',
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Text(
                                                                  'view'.tr,
                                                                  style:
                                                                      robotoMedium,
                                                                ),
                                                                const Icon(
                                                                  Icons
                                                                      .remove_red_eye,
                                                                  size: 24,
                                                                ),
                                                              ],
                                                            ),
                                                          ),

                                                          PopupMenuItem(
                                                            value: 'edit',
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Text(
                                                                  'edit'.tr,
                                                                  style:
                                                                      robotoMedium,
                                                                ),
                                                                Container(
                                                                  padding:
                                                                      const EdgeInsets.all(
                                                                        4,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color: Colors
                                                                        .blue,
                                                                    shape: BoxShape
                                                                        .circle,
                                                                  ),
                                                                  child: const Icon(
                                                                    Icons
                                                                        .edit_outlined,
                                                                    color: Colors
                                                                        .white,
                                                                    size: 14,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),

                                                          PopupMenuItem(
                                                            value: 'delete',
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Text(
                                                                  'delete'.tr,
                                                                  style:
                                                                      robotoMedium,
                                                                ),
                                                                Icon(
                                                                  CupertinoIcons
                                                                      .trash_fill,
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.error,
                                                                  size: 22,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ];
                                                      },
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              Dimensions
                                                                  .radiusSmall,
                                                            ),
                                                      ),
                                                      offset: const Offset(
                                                        -20,
                                                        20,
                                                      ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              3,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              Theme.of(context)
                                                                  .hintColor
                                                                  .withValues(
                                                                    alpha: 0.15,
                                                                  ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                Dimensions
                                                                    .radiusSmall,
                                                              ),
                                                        ),
                                                        child: Icon(
                                                          Icons.more_vert,
                                                          size: 20,
                                                          color: Theme.of(
                                                            context,
                                                          ).hintColor,
                                                        ),
                                                      ),
                                                      onSelected: (dynamic value) {
                                                        if (value == 'status') {
                                                          bool status =
                                                              couponController
                                                                      .coupons![index]
                                                                      .status ==
                                                                  1
                                                              ? true
                                                              : false;
                                                          couponController
                                                              .changeStatus(
                                                                couponController
                                                                    .coupons![index]
                                                                    .id,
                                                                !status,
                                                              )
                                                              .then((success) {
                                                                if (success) {
                                                                  Get.find<
                                                                        CouponController
                                                                      >()
                                                                      .getCouponList();
                                                                }
                                                              });
                                                        } else if (value ==
                                                            'view') {
                                                          Get.bottomSheet(
                                                            CouponCardDialogueWidget(
                                                              couponBody:
                                                                  couponController
                                                                      .coupons![index],
                                                              index: index,
                                                            ),
                                                            isScrollControlled:
                                                                true,
                                                          );
                                                        } else if (value ==
                                                            'delete') {
                                                          Get.dialog(
                                                            ConfirmationDialogWidget(
                                                              icon: Images
                                                                  .warning,
                                                              title:
                                                                  'are_you_sure_to_delete'
                                                                      .tr,
                                                              description:
                                                                  'you_want_to_delete_this_coupon'
                                                                      .tr,
                                                              onYesPressed: () {
                                                                couponController
                                                                    .deleteCoupon(
                                                                      couponController
                                                                          .coupons![index]
                                                                          .id,
                                                                    )
                                                                    .then((
                                                                      success,
                                                                    ) {
                                                                      if (success) {
                                                                        Get.find<
                                                                              CouponController
                                                                            >()
                                                                            .getCouponList();
                                                                      }
                                                                    });
                                                              },
                                                            ),
                                                            barrierDismissible:
                                                                false,
                                                          );
                                                        } else {
                                                          Get.dialog(
                                                            const CustomLoaderWidget(),
                                                          );
                                                          couponController
                                                              .getCouponDetails(
                                                                couponController
                                                                    .coupons![index]
                                                                    .id!,
                                                              )
                                                              .then((
                                                                couponDetails,
                                                              ) {
                                                                Get.back();
                                                                if (couponDetails !=
                                                                    null) {
                                                                  Get.to(
                                                                    () => AddCouponScreen(
                                                                      coupon:
                                                                          couponDetails,
                                                                    ),
                                                                  );
                                                                }
                                                              });
                                                        }
                                                      },
                                                    ),
                                                  ),

                                                  Text(
                                                    couponController
                                                        .coupons![index]
                                                        .code!,
                                                    style: robotoBold.copyWith(
                                                      fontSize: Dimensions
                                                          .fontSizeLarge,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 5),

                                                  FittedBox(
                                                    child: Text(
                                                      '${DateConverterHelper.stringToLocalDateOnly(couponController.coupons![index].startDate!)}  - ${DateConverterHelper.stringToLocalDateOnly(couponController.coupons![index].expireDate!)}',
                                                      style: robotoRegular
                                                          .copyWith(
                                                            fontSize: Dimensions
                                                                .fontSizeSmall,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 5),

                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        '*',
                                                        style: robotoRegular
                                                            .copyWith(
                                                              color: Theme.of(
                                                                context,
                                                              ).colorScheme.error,
                                                            ),
                                                      ),
                                                      Text(
                                                        'min_purchase'.tr,
                                                        style: robotoRegular
                                                            .copyWith(
                                                              fontSize: Dimensions
                                                                  .fontSizeSmall,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .hintColor
                                                                      .withValues(
                                                                        alpha:
                                                                            0.6,
                                                                      ),
                                                            ),
                                                      ),
                                                      Text(
                                                        ' ${PriceConverterHelper.convertPrice(double.parse(couponController.coupons![index].minPurchase.toString()))}',
                                                        style: robotoRegular
                                                            .copyWith(
                                                              fontSize: Dimensions
                                                                  .fontSizeSmall,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .hintColor
                                                                      .withValues(
                                                                        alpha:
                                                                            0.6,
                                                                      ),
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Center(child: Text('no_coupon_found'.tr))
                : const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}
