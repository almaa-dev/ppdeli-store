import 'package:ppdelistore/features/store/controllers/store_controller.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/features/store/domain/models/item_model.dart';
import 'package:ppdelistore/features/store/widgets/update_stock_bottom_sheet.dart';
import 'package:ppdelistore/helper/date_converter_helper.dart';
import 'package:ppdelistore/helper/price_converter_helper.dart';
import 'package:ppdelistore/helper/route_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:ppdelistore/common/widgets/confirmation_dialog_widget.dart';
import 'package:ppdelistore/common/widgets/custom_image_widget.dart';
import 'package:ppdelistore/common/widgets/custom_snackbar_widget.dart';
import 'package:ppdelistore/common/widgets/discount_tag_widget.dart';
import 'package:ppdelistore/common/widgets/not_available_widget.dart';
import 'package:ppdelistore/features/store/screens/item_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ItemWidget extends StatelessWidget {
  final Item item;
  final int index;
  final int length;
  final bool inStore;
  final bool isCampaign;
  const ItemWidget({
    super.key,
    required this.item,
    required this.index,
    required this.length,
    this.inStore = false,
    this.isCampaign = false,
  });

  @override
  Widget build(BuildContext context) {
    double? discount;
    String? discountType;
    bool isAvailable;
    discount = (item.storeDiscount == 0 || isCampaign)
        ? item.discount
        : item.storeDiscount;
    discountType = (item.storeDiscount == 0 || isCampaign)
        ? item.discountType
        : 'percent';
    isAvailable = DateConverterHelper.isAvailable(
      item.availableTimeStarts,
      item.availableTimeEnds,
    );

    double width = MediaQuery.of(context).size.width;

    return InkWell(
      onTap: () => Get.toNamed(
        RouteHelper.getItemDetailsRoute(item),
        arguments: ItemDetailsScreen(product: item),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeSmall,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              offset: Offset(0, 3),
              color: Colors.grey[Get.isDarkMode ? 700 : 200]!,
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            /// Image section
            item.imageFullUrl != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusDefault,
                        ),
                        child: CustomImageWidget(
                          image: '${item.imageFullUrl}',
                          height: 60,
                          width: 69,
                          fit: BoxFit.cover,
                        ),
                      ),
                      DiscountTagWidget(
                        discount: discount,
                        discountType: discountType,
                        freeDelivery: false,
                      ),
                      isAvailable
                          ? const SizedBox()
                          : const NotAvailableWidget(isStore: false),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    child: CustomImageWidget(
                      image: Images.image,
                      height: 60,
                      width: 69,
                      fit: BoxFit.cover,
                    ),
                  ),
            const SizedBox(width: Dimensions.paddingSizeSmall),

            /// Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  /// Name
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        item.name ?? '',
                        textAlign: TextAlign.start,
                        style: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(width: Dimensions.paddingSizeExtraSmall),
                      item.veg == 1
                          ? Image.asset(Images.vegIcon, width: 12)
                          : item.veg == 0
                          ? Image.asset(Images.nonVegIcon, width: 12)
                          : SizedBox.shrink(),
                      SizedBox(
                        width: item.imageFullUrl == null
                            ? Dimensions.paddingSizeExtraSmall
                            : 0,
                      ),

                      item.imageFullUrl == null
                          ? discount! > 0
                                ? Text(
                                    '(${discount > 0 ? '$discount${discountType == 'percent' ? '%' : Get.find<SplashController>().configModel!.currencySymbol} ${'off'.tr}' : 'free_delivery'.tr})',
                                    style: robotoMedium.copyWith(
                                      color: Colors.green,
                                      fontSize: Dimensions.fontSizeExtraSmall,
                                    ),
                                  )
                                : const SizedBox()
                          : const SizedBox(),
                    ],
                  ),
                  SizedBox(
                    height: item.imageFullUrl != null
                        ? Dimensions.paddingSizeExtraSmall
                        : 0,
                  ),

                  /// Rating bar
                  Row(
                    children: [
                      // RatingBarWidget(
                      //   rating: item.avgRating, size: 12,
                      //   ratingCount: item.ratingCount,
                      // ),
                      if (item.avgRating != null && item.avgRating != 0.0)
                        Row(
                          children: [
                            Image.asset(Images.starIcon, width: 10),
                            Text(
                              ' ${item.avgRating!.toStringAsFixed(2)} ',
                              style: robotoRegular.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                              ),
                            ),
                            Text(
                              ' (${item.ratingCount})',
                              style: robotoBold.copyWith(
                                fontSize: Dimensions.fontSizeExtraSmall,
                                color: Theme.of(context).hintColor,
                                decoration: TextDecoration.underline,
                                decorationColor: Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        ),

                      item.imageFullUrl == null && !isAvailable
                          ? Padding(
                              padding: const EdgeInsets.only(left: 5.0),
                              child: Text(
                                '(${'not_available_now'.tr})',
                                textAlign: TextAlign.center,
                                style: robotoRegular.copyWith(
                                  color: Colors.red,
                                  fontSize: Dimensions.fontSizeExtraSmall,
                                ),
                              ),
                            )
                          : const SizedBox(),
                    ],
                  ),
                  const SizedBox(height: 2),

                  /// Price and Stock
                  Row(
                    children: [
                      discount! > 0
                          ? Text(
                              PriceConverterHelper.convertPrice(item.price),
                              style: robotoBold.copyWith(
                                fontSize: Dimensions.fontSizeExtraSmall,
                                color: Theme.of(context).disabledColor,
                                decoration: TextDecoration.lineThrough,
                              ),
                            )
                          : const SizedBox(),

                      SizedBox(
                        width: discount > 0
                            ? Dimensions.paddingSizeExtraSmall
                            : 0,
                      ),

                      Text(
                        PriceConverterHelper.convertPrice(
                          item.price,
                          discount: discount,
                          discountType: discountType,
                        ),
                        style: robotoBold.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                ],
              ),
            ),

            width > 320
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        onSelected: (String result) {
                          if (result == '1') {
                            Get.bottomSheet(
                              UpdateStockBottomSheet(
                                item: item,
                                onSuccess: (bool isSuccess) {},
                              ),
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                            );
                          } else if (result == '2') {
                            if (Get.find<ProfileController>()
                                .profileModel!
                                .stores![0]
                                .itemSection!) {
                              Get.find<StoreController>()
                                  .getItemDetails(item.id!)
                                  .then((itemDetails) {
                                    if (itemDetails != null) {
                                      Get.toNamed(
                                        RouteHelper.getAddItemRoute(
                                          itemDetails,
                                        ),
                                      );
                                    }
                                  });
                            } else {
                              showCustomSnackBar(
                                'this_feature_is_blocked_by_admin'.tr,
                              );
                            }
                          } else if (result == '3') {
                            if (Get.find<ProfileController>()
                                .profileModel!
                                .stores![0]
                                .itemSection!) {
                              Get.dialog(
                                ConfirmationDialogWidget(
                                  icon: Images.warning,
                                  description:
                                      'are_you_sure_want_to_delete_this_product'
                                          .tr,
                                  onYesPressed: () =>
                                      Get.find<StoreController>().deleteItem(
                                        item.id,
                                      ),
                                ),
                              );
                            } else {
                              showCustomSnackBar(
                                'this_feature_is_blocked_by_admin'.tr,
                              );
                            }
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                              if (!Get.find<SplashController>()
                                  .getStoreModuleConfig()
                                  .newVariation!)
                                PopupMenuItem<String>(
                                  value: '1',
                                  child: ListTile(
                                    title: Text(
                                      'stock'.tr,
                                      style: robotoMedium,
                                    ),
                                    trailing: const Icon(
                                      Icons.add_circle,
                                      color: Colors.indigo,
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              PopupMenuItem<String>(
                                value: '2',
                                child: ListTile(
                                  title: Text('edit'.tr, style: robotoMedium),
                                  trailing: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: '3',
                                child: ListTile(
                                  title: Text('delete'.tr, style: robotoMedium),
                                  trailing: const Icon(
                                    Icons.delete_forever,
                                    color: Colors.red,
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                        icon: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).disabledColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusSmall,
                            ),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Icon(Icons.more_vert_sharp, size: 20),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          right: Dimensions.paddingSizeSmall,
                          bottom: Dimensions.paddingSizeSmall,
                        ),
                        child: item.stock != 0 && item.stock != null
                            ? Text(
                                'Stock : ${item.stock}',
                                style: robotoRegular.copyWith(
                                  fontSize: Dimensions.fontSizeSmall,
                                  color: Theme.of(context).disabledColor,
                                ),
                              )
                            : SizedBox.shrink(),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      if (!Get.find<SplashController>()
                          .getStoreModuleConfig()
                          .newVariation!)
                        GestureDetector(
                          onTap: () {
                            Get.bottomSheet(
                              UpdateStockBottomSheet(
                                item: item,
                                onSuccess: (bool isSuccess) {},
                              ),
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                            );
                          },
                          child: const Icon(
                            Icons.add_circle,
                            color: Colors.indigo,
                          ),
                        ),

                      GestureDetector(
                        onTap: () {
                          if (Get.find<ProfileController>()
                              .profileModel!
                              .stores![0]
                              .itemSection!) {
                            Get.find<StoreController>()
                                .getItemDetails(item.id!)
                                .then((itemDetails) {
                                  if (itemDetails != null) {
                                    Get.toNamed(
                                      RouteHelper.getAddItemRoute(itemDetails),
                                    );
                                  }
                                });
                          } else {
                            showCustomSnackBar(
                              'this_feature_is_blocked_by_admin'.tr,
                            );
                          }
                        },
                        child: const Icon(Icons.edit, color: Colors.blue),
                      ),

                      GestureDetector(
                        onTap: () {
                          if (Get.find<ProfileController>()
                              .profileModel!
                              .stores![0]
                              .itemSection!) {
                            Get.dialog(
                              ConfirmationDialogWidget(
                                icon: Images.warning,
                                description:
                                    'are_you_sure_want_to_delete_this_product'
                                        .tr,
                                onYesPressed: () => Get.find<StoreController>()
                                    .deleteItem(item.id),
                              ),
                            );
                          } else {
                            showCustomSnackBar(
                              'this_feature_is_blocked_by_admin'.tr,
                            );
                          }
                        },
                        child: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
