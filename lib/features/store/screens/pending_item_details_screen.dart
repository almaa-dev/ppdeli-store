import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/common/widgets/details_custom_card.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/features/store/controllers/store_controller.dart';
import 'package:ppdelistore/common/models/config_model.dart';
import 'package:ppdelistore/features/store/domain/models/item_model.dart';
import 'package:ppdelistore/features/store/widgets/information_text_widget.dart';
import 'package:ppdelistore/features/store/widgets/item_delete_dialog.dart';
import 'package:ppdelistore/features/store/widgets/title_tag_widget.dart';
import 'package:ppdelistore/features/store/widgets/variation_view_for_foood_widget.dart';
import 'package:ppdelistore/features/store/widgets/variation_view_for_general_widget.dart';
import 'package:ppdelistore/helper/date_converter_helper.dart';
import 'package:ppdelistore/helper/price_converter_helper.dart';
import 'package:ppdelistore/helper/route_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:ppdelistore/common/widgets/custom_button_widget.dart';
import 'package:ppdelistore/common/widgets/custom_image_widget.dart';
import 'package:ppdelistore/common/widgets/custom_video_player_widget.dart';
import 'package:ppdelistore/common/widgets/custom_youtube_player_widget.dart';

class PendingItemDetailsScreen extends StatefulWidget {
  final int id;
  const PendingItemDetailsScreen({super.key, required this.id});

  @override
  State<PendingItemDetailsScreen> createState() =>
      _PendingItemDetailsScreenState();
}

class _PendingItemDetailsScreenState extends State<PendingItemDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    Get.find<StoreController>().getPendingItemDetails(
      widget.id,
      canUpdate: false,
    );
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreController>(
      builder: (storeController) {
        return Scaffold(
          appBar: AppBar(
            title: Column(
              children: [
                Text(
                  'item_details'.tr,
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeLarge,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeExtraSmall),

                Text(
                  storeController.item != null &&
                          storeController.item?.isRejected == 1
                      ? 'this_item_has_been_rejected'.tr
                      : 'this_item_is_under_review'.tr,
                  style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color:
                        storeController.item != null &&
                            storeController.item?.isRejected == 1
                        ? Theme.of(context).colorScheme.error
                        : Colors.blue,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              color: Theme.of(context).textTheme.bodyLarge!.color,
              onPressed: () => Get.back(),
            ),
            backgroundColor: Theme.of(context).cardColor,
            surfaceTintColor: Theme.of(context).cardColor,
            shadowColor: Theme.of(context).disabledColor.withValues(alpha: 0.5),
            elevation: 2,
            actions: [
              storeController.item != null
                  ? IconButton(
                      onPressed: () {
                        Get.dialog(
                          const ItemDeleteDialog(),
                          barrierDismissible: false,
                        );
                      },
                      icon: Icon(
                        CupertinoIcons.delete_simple,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  : const SizedBox(),
            ],
          ),

          body: storeController.item != null
              ? EnglishLanguageItemTab(
                  item: storeController.item!,
                  storeController: storeController,
                )
              : const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class EnglishLanguageItemTab extends StatelessWidget {
  final Item item;
  final StoreController storeController;
  const EnglishLanguageItemTab({
    super.key,
    required this.item,
    required this.storeController,
  });

  @override
  Widget build(BuildContext context) {
    final List<Language>? languageList =
        Get.find<SplashController>().configModel!.language;
    BoxShadow boxShadow = BoxShadow(
      color: Theme.of(context).disabledColor.withValues(alpha: 0.3),
      blurRadius: 10,
    );
    double cardRadius = Dimensions.radiusDefault;
    final List<String> additionalImages = (item.imagesFullUrl ?? <String?>[])
        .whereType<String>()
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    final String videoFullUrl = item.videoFullUrl?.trim() ?? '';
    final String videoLink = item.videoLink?.trim() ?? '';
    String itemName = '';
    String itemDescription = '';
    for (Translation translation in item.translations!) {
      if (translation.locale ==
          languageList![storeController.languageSelectedIndex].key) {
        if (translation.key == 'name') {
          itemName = translation.value!;
        }
        if (translation.key == 'description') {
          itemDescription = translation.value!;
        }
      }
    }
    Module? module =
        Get.find<SplashController>().configModel!.moduleConfig!.module;

    return Column(
      children: [
        (item.isRejected == 1) && item.note != null && item.note!.isNotEmpty
            ? Container(
                padding: const EdgeInsets.all(
                  Dimensions.paddingSizeDefault - 3,
                ),
                margin: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xffFD5100).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(Dimensions.radiusMedium),
                ),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${'denied_note'.tr} : ',
                        style: robotoRegular.copyWith(
                          color: const Color(0xffFD5100),
                        ),
                      ),

                      TextSpan(
                        text: item.note ?? '',
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyLarge!.color?.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox(),
        SizedBox(
          height:
              (item.isRejected == 1) &&
                  item.note != null &&
                  item.note!.isNotEmpty
              ? 0
              : Dimensions.paddingSizeLarge,
        ),

        SizedBox(
          height: 40,
          child: ListView.builder(
            itemCount: languageList!.length,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: Dimensions.paddingSizeSmall),
            itemBuilder: (context, index) {
              bool selected = index == storeController.languageSelectedIndex;
              return Padding(
                padding: const EdgeInsets.only(
                  right: Dimensions.paddingSizeSmall,
                ),
                child: InkWell(
                  onTap: () => storeController.setLanguageSelect(index),
                  child: Column(
                    children: [
                      Text(
                        languageList[index].value!,
                        style: selected
                            ? robotoBold.copyWith(
                                color: Theme.of(context).primaryColor,
                              )
                            : robotoMedium,
                      ),
                      Container(
                        height: 2,
                        width: 100,
                        color: selected
                            ? Theme.of(context).primaryColor
                            : Colors.transparent,
                        margin: const EdgeInsets.only(
                          top: Dimensions.paddingSizeSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                DetailsCustomCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                  borderRadius: 0,
                  isBorder: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 90,
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: Dimensions.paddingSizeSmall,
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 70,
                                width: 70,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusDefault,
                                  ),
                                  color: Theme.of(
                                    context,
                                  ).disabledColor.withValues(alpha: 0.2),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusDefault,
                                  ),
                                  child: CustomImageWidget(
                                    image: '${item.imageFullUrl}',
                                    fit: BoxFit.cover,
                                    width: 70,
                                    height: 70,
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: Dimensions.paddingSizeDefault,
                              ),
                              Expanded(
                                child: Text(
                                  itemName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: robotoMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Text(
                        itemDescription,
                        style: robotoRegular.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                additionalImages.isNotEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(cardRadius),
                          color: Theme.of(context).cardColor,
                          boxShadow: [boxShadow],
                        ),
                        width: double.infinity,
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeSmall,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('additional_images'.tr, style: robotoMedium),
                            const SizedBox(height: Dimensions.paddingSizeSmall),

                            SizedBox(
                              height: 90,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: additionalImages.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(
                                      width: Dimensions.paddingSizeSmall,
                                    ),
                                itemBuilder: (context, index) {
                                  return InkWell(
                                    onTap: () => Get.toNamed(
                                      RouteHelper.getItemImagesRoute(item),
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      cardRadius,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        cardRadius,
                                      ),
                                      child: CustomImageWidget(
                                        image: additionalImages[index],
                                        height: 90,
                                        width: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(),
                SizedBox(
                  height: additionalImages.isNotEmpty
                      ? Dimensions.paddingSizeSmall
                      : 0,
                ),

                if (videoLink.isNotEmpty || videoFullUrl.isNotEmpty) ...[
                  InkWell(
                    onTap: () {
                      if (videoLink.isNotEmpty) {
                        Get.to(
                          () => CustomYoutubePlayerPage(
                            videoUrl: videoLink,
                            title: videoLink,
                          ),
                        );
                      } else {
                        Get.to(
                          () => CustomVideoPlayerPage(
                            filePath: videoFullUrl,
                            isNetwork: true,
                            title: videoFullUrl,
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(cardRadius),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(cardRadius),
                        color: Theme.of(context).cardColor,
                        boxShadow: [boxShadow],
                      ),
                      width: double.infinity,
                      padding: const EdgeInsets.all(
                        Dimensions.paddingSizeSmall,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(
                              Dimensions.paddingSizeSmall,
                            ),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(width: Dimensions.paddingSizeSmall),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('video'.tr, style: robotoMedium),
                                const SizedBox(
                                  height: Dimensions.paddingSizeExtraSmall,
                                ),
                                Text(
                                  'view'.tr,
                                  style: robotoRegular.copyWith(
                                    fontSize: Dimensions.fontSizeSmall,
                                    color: Theme.of(context).disabledColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Theme.of(context).disabledColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                ],

                Column(
                  children: [
                    TitleTagWidget(title: 'general_information'.tr),

                    InformationTextWidget(
                      title: 'store'.tr,
                      value: item.storeName.toString(),
                    ),

                    InformationTextWidget(
                      title: 'category'.tr,
                      value: item.categoryIds![0].name.toString(),
                    ),

                    item.categoryIds!.length > 1
                        ? InformationTextWidget(
                            title: 'sub_category'.tr,
                            value: item.categoryIds![1].name.toString(),
                          )
                        : const SizedBox(),

                    InformationTextWidget(
                      title: storeController.isFoodModule()
                          ? 'available_time'.tr
                          : 'total_stock'.tr,
                      value: storeController.isFoodModule()
                          ? '${DateConverterHelper.convertStringTimeToTime(item.availableTimeStarts!)} - ${DateConverterHelper.convertStringTimeToTime(item.availableTimeEnds!)}'
                          : item.stock.toString(),
                    ),

                    item.unitType != null
                        ? InformationTextWidget(
                            title: 'product_unit'.tr,
                            value: item.unitType!,
                          )
                        : const SizedBox(),

                    InformationTextWidget(
                      title: storeController.isFoodModule()
                          ? 'item_type'.tr
                          : 'is_organic'.tr,
                      value: storeController.isFoodModule()
                          ? item.veg == 1
                                ? 'veg'.tr
                                : 'non_veg'.tr
                          : item.veg == 1
                          ? 'yes'.tr
                          : 'no'.tr,
                    ),
                  ],
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                Column(
                  children: [
                    TitleTagWidget(title: 'price_information'.tr),

                    InformationTextWidget(
                      title: 'unit_price'.tr,
                      value: PriceConverterHelper.convertPrice(item.price!),
                    ),

                    InformationTextWidget(
                      title: 'discount'.tr,
                      value: item.discountType != 'percent'
                          ? PriceConverterHelper.convertPrice(item.discount)
                          : '${item.discount.toString()} %',
                    ),
                  ],
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),

                item.taxData != null && item.taxData!.isNotEmpty
                    ? Column(
                        children: [
                          TitleTagWidget(title: 'tax'.tr),

                          ListView.builder(
                            itemCount: item.taxData!.length,
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              return InformationTextWidget(
                                title: item.taxData![index].name ?? '',
                                value:
                                    '${item.taxData![index].taxRate.toString()} %',
                              );
                            },
                          ),
                        ],
                      )
                    : const SizedBox(),

                (item.foodVariations != null &&
                            item.foodVariations!.isNotEmpty) ||
                        (item.variations != null && item.variations!.isNotEmpty)
                    ? Column(
                        children: [
                          TitleTagWidget(title: 'available_variation'.tr),

                          Get.find<SplashController>()
                                  .getStoreModuleConfig()
                                  .newVariation!
                              ? VariationViewForFood(item: item)
                              : VariationViewForGeneral(
                                  item: item,
                                  stock: module!.stock,
                                ),
                        ],
                      )
                    : const SizedBox(),
                SizedBox(
                  height:
                      (item.foodVariations != null &&
                              item.foodVariations!.isNotEmpty) ||
                          (item.variations != null &&
                              item.variations!.isNotEmpty)
                      ? Dimensions.paddingSizeSmall
                      : 0,
                ),

                (item.addOns!.isNotEmpty && module!.addOn!)
                    ? Column(
                        children: [
                          TitleTagWidget(title: 'addons'.tr),

                          (item.addOns!.isNotEmpty && module.addOn!)
                              ? ListView.builder(
                                  itemCount: item.addOns!.length,
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemBuilder: (context, index) {
                                    return InformationTextWidget(
                                      title: item.addOns![index].name!,
                                      value: PriceConverterHelper.convertPrice(
                                        item.addOns![index].price,
                                      ),
                                    );
                                  },
                                )
                              : const SizedBox(),
                        ],
                      )
                    : const SizedBox(),

                (item.tags != null && item.tags!.isNotEmpty)
                    ? Column(
                        children: [
                          TitleTagWidget(title: 'tags'.tr),

                          (item.tags != null && item.tags!.isNotEmpty)
                              ? Container(
                                  height: 35,
                                  width: context.width,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Dimensions.paddingSizeDefault,
                                    vertical: Dimensions.paddingSizeSmall,
                                  ),
                                  color: Theme.of(context).cardColor,
                                  child: ListView.builder(
                                    itemCount: item.tags!.length,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    scrollDirection: Axis.horizontal,
                                    itemBuilder: (context, index) {
                                      return Wrap(
                                        children: [
                                          Text(
                                            item.tags![index].tag!,
                                            style: robotoRegular.copyWith(
                                              fontSize:
                                                  Dimensions.fontSizeSmall,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                )
                              : const SizedBox(),
                        ],
                      )
                    : const SizedBox(),
              ],
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: const [
              BoxShadow(color: Colors.black12, spreadRadius: 1, blurRadius: 5),
            ],
          ),
          child: CustomButtonWidget(
            onPressed: () => Get.toNamed(RouteHelper.getAddItemRoute(item)),
            buttonText: 'edit_and_resubmit'.tr,
          ),
        ),
      ],
    );
  }
}
