import 'package:ppdelistore/common/widgets/custom_card.dart';
import 'package:ppdelistore/common/widgets/custom_popup_menu_button.dart';
import 'package:ppdelistore/features/addon/controllers/addon_controller.dart';
import 'package:ppdelistore/features/addon/widgets/addon_delete_dialog.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/features/store/controllers/store_controller.dart';
import 'package:ppdelistore/helper/price_converter_helper.dart';
import 'package:ppdelistore/helper/route_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:ppdelistore/common/widgets/custom_app_bar_widget.dart';
import 'package:ppdelistore/common/widgets/custom_snackbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AddonScreen extends StatefulWidget {
  const AddonScreen({super.key});

  @override
  State<AddonScreen> createState() => _AddonScreenState();
}

class _AddonScreenState extends State<AddonScreen> {
  @override
  void initState() {
    super.initState();
    Get.find<AddonController>().getAddonList();
    Get.find<AddonController>().getAddonCategoryList();

    if (Get.find<SplashController>().configModel!.systemTaxType ==
        'product_wise') {
      Get.find<StoreController>().getVatTaxList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: 'addons'.tr),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (Get.find<ProfileController>()
              .profileModel!
              .stores![0]
              .itemSection!) {
            Get.toNamed(RouteHelper.getAddAddonRoute(null));
          } else {
            showCustomSnackBar('this_feature_is_blocked_by_admin'.tr);
          }
        },
        child: Icon(Icons.add, size: 30, color: Theme.of(context).cardColor),
      ),

      body: GetBuilder<AddonController>(
        builder: (addonController) {
          final List<MenuItem> items = [
            MenuItem('edit'.tr, Icons.edit, 1, Colors.blue),
            MenuItem('delete'.tr, Icons.delete_forever_rounded, 2, Colors.red),
          ];
          return addonController.addonList != null
              ? addonController.addonList!.isNotEmpty
                    ? RefreshIndicator(
                        onRefresh: () async {
                          await addonController.getAddonList();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(
                            Dimensions.paddingSizeDefault,
                          ),
                          itemCount: addonController.addonList!.length,
                          itemBuilder: (context, index) {
                            String categoryName = 'no_category'.tr;

                            if (addonController.addonCategoryList != null) {
                              for (var category
                                  in addonController.addonCategoryList!) {
                                if (category.id ==
                                    addonController
                                        .addonList?[index]
                                        .addonCategoryId) {
                                  categoryName = category.name!;
                                  break;
                                }
                              }
                            }
                            return CustomCard(
                              padding: const EdgeInsets.all(
                                Dimensions.paddingSizeSmall,
                              ),
                              margin: const EdgeInsets.only(
                                bottom: Dimensions.paddingSizeSmall,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          addonController
                                                  .addonList?[index]
                                                  .name ??
                                              '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: robotoMedium.copyWith(
                                            fontSize:
                                                Dimensions.fontSizeDefault,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyLarge!
                                                .color
                                                ?.withValues(alpha: 1),
                                          ),
                                        ),
                                        const SizedBox(
                                          height:
                                              Dimensions.paddingSizeExtraSmall,
                                        ),

                                        Text(
                                          '${'category'.tr}: $categoryName',
                                          style: robotoRegular.copyWith(
                                            fontSize: Dimensions.fontSizeSmall,
                                          ),
                                        ),
                                        const SizedBox(
                                          height:
                                              Dimensions.paddingSizeExtraSmall,
                                        ),

                                        Text(
                                          addonController
                                                      .addonList![index]
                                                      .price! >
                                                  0
                                              ? PriceConverterHelper.convertPrice(
                                                  addonController
                                                      .addonList![index]
                                                      .price,
                                                )
                                              : 'free'.tr,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: robotoMedium.copyWith(
                                            fontSize: Dimensions.fontSizeSmall,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  CustomPopupMenuButton(
                                    items: items,
                                    onSelected: (int value) {
                                      if (value == 1) {
                                        Get.toNamed(
                                          RouteHelper.getAddAddonRoute(
                                            addonController.addonList![index],
                                          ),
                                        );
                                      } else if (value == 2) {
                                        Get.dialog(
                                          AddonDeleteDialog(
                                            addonID: addonController
                                                .addonList![index]
                                                .id!,
                                          ),
                                          barrierDismissible: false,
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).disabledColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(
                                          Dimensions.radiusDefault - 2,
                                        ),
                                      ),
                                      child: Icon(Icons.more_vert, size: 25),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    : Center(child: Text('no_addon_found'.tr))
              : const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
