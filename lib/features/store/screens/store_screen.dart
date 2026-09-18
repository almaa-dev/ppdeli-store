import 'dart:async';
import 'package:marquee/marquee.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:ppdelistore/common/widgets/custom_app_bar_widget.dart';
import 'package:ppdelistore/features/store/controllers/store_controller.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/features/store/widgets/announcement_bottom_sheet_widget.dart';
import 'package:ppdelistore/helper/date_converter_helper.dart';
import 'package:ppdelistore/helper/price_converter_helper.dart';
import 'package:ppdelistore/helper/route_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:ppdelistore/common/widgets/custom_image_widget.dart';
import 'package:ppdelistore/common/widgets/custom_snackbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/widgets/item_shimmer_widget.dart';
import '../widgets/filter_popup_widget.dart';
import '../widgets/item_view_widget.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  Timer? _coverPhotoTimer;
  bool _showCoverShimmer = true;

  @override
  void initState() {
    super.initState();
    _coverPhotoTimer = Timer(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showCoverShimmer = false;
        });
      }
    });

    Get.find<ProfileController>().getProfile();
    Get.find<StoreController>().getItemList(
      offset: '1',
      type: 'all',
      search: '',
      categoryId: 0,
      willUpdate: false,
    );
    Get.find<StoreController>().getStoreReviewList(
      Get.find<ProfileController>().profileModel!.stores![0].id,
      '',
      willUpdate: false,
    );
  }

  @override
  void dispose() {
    _coverPhotoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreController>(
      builder: (storeController) {
        return GetBuilder<ProfileController>(
          builder: (profileController) {
            final store = profileController.profileModel!.stores![0];
            bool isShowingTrialContent =
                profileController.profileModel != null &&
                profileController.profileModel!.subscription != null &&
                int.tryParse('') == 1 &&
                DateConverterHelper.differenceInDaysIgnoringTime(
                      DateTime.parse(
                        profileController
                            .profileModel!
                            .subscription!
                            .expiryDate!,
                      ),
                      null,
                    ) >
                    0;

            if (profileController.profileModel == null ||
                profileController.modulePermission == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return profileController.modulePermission?.myShop == true
                ? Scaffold(
                    backgroundColor: Theme.of(context).cardColor,

                    appBar: CustomAppBarWidget(
                      title: 'my_shop'.tr,
                      isBackButtonExist: false,
                    ),

                    floatingActionButton: GetBuilder<StoreController>(
                      builder: (storeController) {
                        return storeController.isFabVisible &&
                                (storeController.tabIndex == 0 &&
                                    profileController.modulePermission?.item ==
                                        true)
                            ? Padding(
                                padding: EdgeInsets.only(
                                  bottom: isShowingTrialContent ? 100 : 0,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.3,
                                        ),
                                        spreadRadius: 2,
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: FloatingActionButton(
                                    heroTag: 'nothing',
                                    onPressed: () {
                                      if (Get.find<ProfileController>()
                                          .profileModel!
                                          .stores![0]
                                          .itemSection!) {
                                        Get.toNamed(
                                          RouteHelper.getAddItemRoute(null),
                                        );
                                      } else {
                                        showCustomSnackBar(
                                          'this_feature_is_blocked_by_admin'.tr,
                                        );
                                      }
                                    },
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor,
                                    child: Icon(
                                      Icons.add,
                                      color: Theme.of(context).cardColor,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox();
                      },
                    ),

                    body: RefreshIndicator(
                      onRefresh: () async {
                        _coverPhotoTimer?.cancel();
                        setState(() {
                          _showCoverShimmer = true;
                        });
                        _coverPhotoTimer = Timer(Duration(seconds: 3), () {
                          if (mounted) {
                            setState(() {
                              _showCoverShimmer = false;
                            });
                          }
                        });
                        await Get.find<ProfileController>().getProfile();
                        await Get.find<StoreController>().getItemList(
                          offset: '1',
                          type: 'all',
                          search: '',
                          categoryId: 0,
                          willUpdate: false,
                        );
                        await Get.find<StoreController>().getStoreReviewList(
                          Get.find<ProfileController>()
                              .profileModel!
                              .stores![0]
                              .id,
                          '',
                          willUpdate: false,
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.all(Dimensions.paddingSizeDefault),
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          controller: _scrollController,
                          slivers: [
                            // SliverAppBar(
                            //   expandedHeight: 120,
                            //   toolbarHeight: 0,
                            //   pinned: false, floating: false,
                            //   backgroundColor: Theme.of(context).cardColor,
                            // actions: [
                            //   IconButton(icon: Container(
                            //     height: 50, width: 40, alignment: Alignment.center,
                            //     padding: const EdgeInsets.all(7),
                            //     decoration: BoxDecoration(
                            //       color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                            //       border: Border.all(color: Theme.of(context).cardColor.withValues(alpha: 0.7), width: 1.5)),
                            //     child: Icon(Icons.edit, color: Theme.of(context).cardColor, size: 20),
                            //   ),
                            //   onPressed: () {
                            //     if(Get.find<ProfileController>().modulePermission!.myShop!){
                            //       Get.toNamed(RouteHelper.getStoreEditRoute(store));
                            //     }else{
                            //       showCustomSnackBar('access_denied'.tr);
                            //     }
                            //   })
                            // ],
                            // flexibleSpace: FlexibleSpaceBar(
                            //   background: Padding(
                            //     padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                            //     child: CustomImageWidget(
                            //       fit: BoxFit.cover, placeholder: Images.restaurantCover,
                            //       image: '${store.coverPhotoFullUrl}',
                            //     ),
                            //   ),
                            // ),
                            // ),

                            /// Store Info Section
                            SliverToBoxAdapter(
                              child: Container(
                                padding: EdgeInsets.all(
                                  Dimensions.paddingSizeExtraSmall,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  boxShadow: [
                                    BoxShadow(
                                      offset: Offset(0, 3),
                                      color: Colors
                                          .grey[Get.isDarkMode ? 700 : 200]!,
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(
                                      Dimensions.radiusLarge,
                                    ),
                                    bottomRight: Radius.circular(
                                      Dimensions.radiusLarge,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    /// Cover Images
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        store.coverPhotoFullUrl != null
                                            ? CustomImageWidget(
                                                fit: BoxFit.cover,
                                                placeholder:
                                                    Images.restaurantCover,
                                                image:
                                                    '${store.coverPhotoFullUrl}',
                                                width: double.infinity,
                                                height: 86,
                                              )
                                            : _showCoverShimmer
                                            ? Shimmer(
                                                color: Theme.of(
                                                  context,
                                                ).disabledColor,
                                                colorOpacity: 0.4,
                                                child: SizedBox(
                                                  height: 86,
                                                  width: double.infinity,
                                                ),
                                              )
                                            : SizedBox.shrink(),

                                        Positioned(
                                          bottom: -40,
                                          left: Dimensions.paddingSizeDefault,
                                          child: Container(
                                            height: 60,
                                            width: 60,
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).cardColor,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    Dimensions.radiusSmall,
                                                  ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.1),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 5),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    Dimensions.radiusSmall,
                                                  ),
                                              child: store.logoFullUrl != null
                                                  ? CustomImageWidget(
                                                      image:
                                                          '${store.logoFullUrl}',
                                                      fit: BoxFit.cover,
                                                    )
                                                  : _showCoverShimmer
                                                  ? Shimmer(
                                                      color: Theme.of(
                                                        context,
                                                      ).disabledColor,
                                                      colorOpacity: 0.4,
                                                      child: SizedBox(
                                                        height: 86,
                                                        width: double.infinity,
                                                      ),
                                                    )
                                                  : SizedBox.shrink(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    ///Store Details
                                    store.name != null && store.address != null
                                        ? Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal:
                                                  Dimensions.paddingSizeDefault,
                                              vertical: Dimensions
                                                  .paddingSizeExtraSmall,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                SizedBox(width: 75),
                                                // Store Details
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              store.name ?? '',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: robotoMedium
                                                                  .copyWith(
                                                                    fontSize:
                                                                        Dimensions
                                                                            .fontSizeExtraLarge,
                                                                  ),
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            width: Dimensions
                                                                .paddingSizeExtraSmall,
                                                          ),

                                                          if (store
                                                                  .verifiedSeller ??
                                                              false)
                                                            Image.asset(
                                                              Images
                                                                  .verifyedBadge,
                                                              width: Dimensions
                                                                  .fontSizeExtraLarge,
                                                              height: Dimensions
                                                                  .fontSizeExtraLarge,
                                                            ),
                                                        ],
                                                      ),
                                                      Text(
                                                        store.address ?? '',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: robotoRegular
                                                            .copyWith(
                                                              fontSize: Dimensions
                                                                  .fontSizeSmall,
                                                              color: Theme.of(
                                                                context,
                                                              ).disabledColor,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: Dimensions
                                                      .paddingSizeSmall,
                                                ),
                                                InkWell(
                                                  onTap: () {
                                                    if (Get.find<
                                                          ProfileController
                                                        >()
                                                        .modulePermission!
                                                        .myShop!) {
                                                      Get.toNamed(
                                                        RouteHelper.getStoreEditRoute(
                                                          store,
                                                        ),
                                                      );
                                                    } else {
                                                      showCustomSnackBar(
                                                        'access_denied'.tr,
                                                      );
                                                    }
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(
                                                      Dimensions
                                                          .paddingSizeExtraSmall,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.indigo,
                                                    ),
                                                    child: Icon(
                                                      Icons.edit_outlined,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : _showCoverShimmer
                                        ? Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              SizedBox(width: 75),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    SizedBox(height: 6),
                                                    Shimmer(
                                                      color: Theme.of(
                                                        context,
                                                      ).disabledColor,
                                                      colorOpacity: 0.4,
                                                      child: SizedBox(
                                                        height: 20,
                                                        width: double.infinity,
                                                      ),
                                                    ),
                                                    SizedBox(height: 6),
                                                    Shimmer(
                                                      color: Theme.of(
                                                        context,
                                                      ).disabledColor,
                                                      colorOpacity: 0.4,
                                                      child: SizedBox(
                                                        height: 14,
                                                        width: double.infinity,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                width:
                                                    Dimensions.paddingSizeSmall,
                                              ),
                                              Shimmer(
                                                color: Theme.of(
                                                  context,
                                                ).disabledColor,
                                                colorOpacity: 0.4,
                                                child: SizedBox(
                                                  height: 36,
                                                  width: 36,
                                                ),
                                              ),
                                            ],
                                          )
                                        : SizedBox.shrink(),

                                    /// Store Discount
                                    // SizedBox(height: store.discount != null ? Dimensions.paddingSizeDefault : 0),
                                    // store.discount != null ? Container(
                                    //   width: context.width,
                                    //   margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                                    //   decoration: BoxDecoration(borderRadius: BorderRadius.circular(Dimensions.radiusSmall), color: Theme.of(context).primaryColor),
                                    //   padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                                    //   child: Text(
                                    //     '${store.discount!.discountType == 'percent' ? '${store.discount!.discount}%'
                                    //       : PriceConverterHelper.convertPrice(store.discount!.discount)} '
                                    //       '${'discount_will_be_applicable_when_order_amount_exceeds_is_more_than'.tr} ${PriceConverterHelper.convertPrice(store.discount!.minPurchase)},'
                                    //       ' ${'max'.tr}: ${PriceConverterHelper.convertPrice(store.discount!.maxDiscount)} ${'discount_is_applicable'.tr}',
                                    //       style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: Colors.white),
                                    //     textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
                                    //   )) : _showCoverShimmer ? Shimmer( color: Theme.of(context).disabledColor, colorOpacity: 0.4,
                                    //     child: Container(height: 56, width: double.infinity,
                                    //     margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault))
                                    // ) : SizedBox.shrink(),
                                    SizedBox(
                                      height:
                                          (store.delivery ?? false) &&
                                              (store.freeDelivery ?? false)
                                          ? Dimensions.paddingSizeSmall
                                          : 0,
                                    ),
                                    // (store.delivery ?? false) && (store.freeDelivery ?? false) ? Text(
                                    //   'free_delivery'.tr,
                                    //   style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor),
                                    // ) : const SizedBox(),

                                    /// Store Info
                                    store.totalItems != null &&
                                            store.totalOrder != null &&
                                            store.avgRating != null &&
                                            store.ratingCount != null
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  padding: EdgeInsets.all(
                                                    Dimensions.paddingSizeSmall,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          Dimensions
                                                              .radiusSmall,
                                                        ),
                                                    color: Theme.of(context)
                                                        .disabledColor
                                                        .withValues(alpha: 0.1),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Flexible(
                                                            child: FittedBox(
                                                              child: Text(
                                                                'items'.tr,
                                                              ),
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            width: Dimensions
                                                                .paddingSizeSmall,
                                                          ),
                                                          Image.asset(
                                                            Images.itemsIcon,
                                                            width: 20,
                                                            height: 20,
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(
                                                        height: Dimensions
                                                            .paddingSizeDefault,
                                                      ),

                                                      Text(
                                                        (store.totalItems ?? 0)
                                                            .toString(),
                                                        style: robotoBold.copyWith(
                                                          fontSize: Dimensions
                                                              .fontSizeLarge,
                                                          color: Theme.of(
                                                            context,
                                                          ).primaryColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width:
                                                    Dimensions.paddingSizeSmall,
                                              ),
                                              Expanded(
                                                child: Container(
                                                  padding: EdgeInsets.all(
                                                    Dimensions.paddingSizeSmall,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          Dimensions
                                                              .radiusSmall,
                                                        ),
                                                    color: Theme.of(context)
                                                        .disabledColor
                                                        .withValues(alpha: 0.1),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Flexible(
                                                            child: FittedBox(
                                                              child: Text(
                                                                'orders'.tr,
                                                              ),
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            width: Dimensions
                                                                .paddingSizeSmall,
                                                          ),
                                                          Image.asset(
                                                            Images.ordersIcon,
                                                            width: 20,
                                                            height: 20,
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(
                                                        height: Dimensions
                                                            .paddingSizeDefault,
                                                      ),
                                                      Text(
                                                        store.totalOrder
                                                            .toString(),
                                                        style: robotoBold.copyWith(
                                                          fontSize: Dimensions
                                                              .fontSizeLarge,
                                                          color: Colors.indigo,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width:
                                                    Dimensions.paddingSizeSmall,
                                              ),
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    Get.toNamed(
                                                      RouteHelper
                                                          .customerReview,
                                                    );
                                                  },
                                                  child: Container(
                                                    padding: EdgeInsets.all(
                                                      Dimensions
                                                          .paddingSizeSmall,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            Dimensions
                                                                .radiusSmall,
                                                          ),
                                                      color: Theme.of(context)
                                                          .disabledColor
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Flexible(
                                                              child: FittedBox(
                                                                child: Text(
                                                                  'ratings'.tr,
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width: Dimensions
                                                                  .paddingSizeSmall,
                                                            ),
                                                            Image.asset(
                                                              Images
                                                                  .ratingsIcon,
                                                              width: 20,
                                                              height: 20,
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(
                                                          height: Dimensions
                                                              .paddingSizeDefault,
                                                        ),
                                                        Row(
                                                          children: [
                                                            Text(
                                                              '${store.avgRating} ',
                                                              style: robotoBold
                                                                  .copyWith(
                                                                    fontSize:
                                                                        Dimensions
                                                                            .fontSizeLarge,
                                                                    color: Colors
                                                                        .orange,
                                                                  ),
                                                            ),
                                                            Text(
                                                              '(${store.ratingCount})',
                                                              style: robotoBold.copyWith(
                                                                fontSize: Dimensions
                                                                    .fontSizeSmall,
                                                                color: Theme.of(
                                                                  context,
                                                                ).hintColor,
                                                                decoration:
                                                                    TextDecoration
                                                                        .underline,
                                                                decorationColor:
                                                                    Theme.of(
                                                                      context,
                                                                    ).disabledColor,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : _showCoverShimmer
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Shimmer(
                                                  color: Theme.of(
                                                    context,
                                                  ).disabledColor,
                                                  colorOpacity: 0.4,
                                                  child: SizedBox(height: 56),
                                                ),
                                              ),
                                              Expanded(
                                                child: Shimmer(
                                                  color: Theme.of(
                                                    context,
                                                  ).disabledColor,
                                                  colorOpacity: 0.4,
                                                  child: SizedBox(height: 56),
                                                ),
                                              ),
                                              Expanded(
                                                child: Shimmer(
                                                  color: Theme.of(
                                                    context,
                                                  ).disabledColor,
                                                  colorOpacity: 0.4,
                                                  child: SizedBox(height: 56),
                                                ),
                                              ),
                                            ],
                                          )
                                        : SizedBox.shrink(),
                                    SizedBox(
                                      height: Dimensions.paddingSizeSmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: store.discount != null
                                        ? Dimensions.paddingSizeDefault
                                        : 0,
                                  ),
                                  store.discount != null
                                      ? Container(
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .disabledColor
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              Dimensions.radiusSmall,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width:
                                                    Dimensions.paddingSizeSmall,
                                              ),
                                              Image.asset(
                                                Images.discountIcon,
                                                width: 18,
                                                height: 18,
                                              ),
                                              SizedBox(
                                                width:
                                                    Dimensions.paddingSizeSmall,
                                              ),
                                              Expanded(
                                                child: Marquee(
                                                  text:
                                                      '${store.discount!.discountType == 'percent' ? '${store.discount!.discount}% ' : PriceConverterHelper.convertPrice(store.discount!.discount)} '
                                                      '${'discount_will_be_applicable_when_order_amount_exceeds_is_more_than'.tr} ${PriceConverterHelper.convertPrice(store.discount!.minPurchase)},'
                                                      ' ${'max'.tr}: ${PriceConverterHelper.convertPrice(store.discount!.maxDiscount)} ${'discount_is_applicable'.tr}',
                                                  style: robotoRegular.copyWith(
                                                    fontSize: Dimensions
                                                        .fontSizeDefault,
                                                  ),
                                                  scrollAxis: Axis.horizontal,
                                                  velocity: 40.0,
                                                  blankSpace: 100.0,
                                                  pauseAfterRound:
                                                      const Duration(
                                                        seconds: 1,
                                                      ),
                                                  startAfter: const Duration(
                                                    milliseconds: 500,
                                                  ),
                                                  fadingEdgeStartFraction: 0.1,
                                                  fadingEdgeEndFraction: 0.1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : SizedBox.shrink(),
                                ],
                              ),
                            ),

                            /// Make Announcement Section
                            SliverToBoxAdapter(
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                  vertical: Dimensions.paddingSizeLarge,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  boxShadow: [
                                    BoxShadow(
                                      offset: Offset(0, 1),
                                      color: Colors
                                          .grey[Get.isDarkMode ? 700 : 200]!,
                                      blurRadius: 3,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: EdgeInsets.all(
                                    Dimensions.paddingSizeDefault,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orangeAccent.shade100
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(
                                      Dimensions.radiusSmall,
                                    ),
                                    // boxShadow: [BoxShadow( offset: Offset(0, 3) , color: Colors.grey[Get.isDarkMode ? 700 : 200]!, blurRadius: 8, spreadRadius: 0)],
                                  ),
                                  child: Row(
                                    children: [
                                      Image.asset(
                                        Images.adsIcon,
                                        width: 32,
                                        height: 32,
                                      ),
                                      SizedBox(
                                        width: Dimensions.paddingSizeDefault,
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'make_announcement'.tr,
                                              style: robotoBold,
                                            ),
                                            Text(
                                              'This Will be Shown in the user app/web.'
                                                  .tr,
                                              style: robotoRegular.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).hintColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            showAnnouncementBottomSheet(
                                              announcementStatus:
                                                  store.isAnnouncementActive!,
                                              announcementMessage:
                                                  store.announcementMessage ??
                                                  '',
                                              context: context,
                                            ),
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          backgroundColor: Theme.of(
                                            context,
                                          ).cardColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadiusGeometry.circular(
                                                  2,
                                                ),
                                          ),
                                        ),
                                        child: Text(
                                          'create'.tr,
                                          style: robotoMedium.copyWith(
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            /// Items
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: SliverDelegate(
                                height: 50,
                                child: storeController.itemSize != null
                                    ? Container(
                                        width: 1170,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Text(
                                              'items'.tr,
                                              style: robotoMedium,
                                            ),
                                            Text(
                                              '(${storeController.itemSize})',
                                              style: robotoMedium,
                                            ),
                                            Spacer(),
                                            store.module?.moduleType == 'food'
                                                ? GestureDetector(
                                                    onTapDown: (details) {
                                                      showFilterPopup(
                                                        context: context,
                                                        offset: details
                                                            .globalPosition,
                                                        selectedType:
                                                            storeController
                                                                .type,
                                                        onSelected: (val) {
                                                          storeController
                                                              .setType(val);
                                                          storeController.getItemList(
                                                            offset: '1',
                                                            type: val,
                                                            search: '',
                                                            categoryId:
                                                                storeController
                                                                    .categoryId,
                                                          );
                                                        },
                                                      );
                                                    },
                                                    child: Icon(
                                                      Icons.filter_list,
                                                      color: Theme.of(
                                                        context,
                                                      ).hintColor,
                                                    ),
                                                  )
                                                : SizedBox.shrink(),
                                          ],
                                        ),
                                      )
                                    : _showCoverShimmer
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Shimmer(
                                            color: Theme.of(
                                              context,
                                            ).disabledColor,
                                            colorOpacity: 0.4,
                                            child: SizedBox(
                                              width: 86,
                                              height: 30,
                                            ),
                                          ),
                                          Shimmer(
                                            color: Theme.of(
                                              context,
                                            ).disabledColor,
                                            colorOpacity: 0.4,
                                            child: SizedBox(
                                              width: 32,
                                              height: 30,
                                            ),
                                          ),
                                        ],
                                      )
                                    : SizedBox.shrink(),
                              ),
                            ),
                            if (storeController.itemList != null &&
                                storeController.itemList!.isNotEmpty)
                              SliverToBoxAdapter(
                                child:
                                    profileController.modulePermission?.item ==
                                        true
                                    ? ItemViewWidget(
                                        scrollController: _scrollController,
                                        type: storeController.type,
                                        onVegFilterTap: (String type) {
                                          Get.find<StoreController>()
                                              .getItemList(
                                                offset: '1',
                                                type: type,
                                                search: '',
                                                categoryId: 0,
                                              );
                                        },
                                      )
                                    : Center(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 100,
                                          ),
                                          child: Text(
                                            'you_have_no_permission_to_access_this_feature'
                                                .tr,
                                            style: robotoMedium,
                                          ),
                                        ),
                                      ),
                              )
                            else
                              SliverToBoxAdapter(
                                child: _showCoverShimmer
                                    ? ItemShimmerWidget(
                                        isEnabled: true,
                                        hasDivider: false,
                                      )
                                    : Center(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 100,
                                          ),
                                          child: Text(
                                            'no_item_available'.tr,
                                            style: robotoMedium,
                                          ),
                                        ),
                                      ),
                              ),

                            // if (storeController.itemList != null && storeController.itemList!.isNotEmpty)
                            //   SliverToBoxAdapter(child: profileController.modulePermission?.item == true
                            //       ? ItemViewWidget(scrollController: _scrollController, type: storeController.type, onVegFilterTap: (String type) {
                            //         Get.find<StoreController>().getItemList(offset: '1', type: type, search: '', categoryId: 0);}) : Center(child: Padding(
                            //       padding: const EdgeInsets.only(top: 100),
                            //       child: Text('you_have_no_permission_to_access_this_feature'.tr, style: robotoMedium),
                            //     )),
                            //   ),

                            // SliverPersistentHeader(
                            //   pinned: true,
                            //   delegate: SliverDelegate(child: Center(child: Container(
                            //     width: 1170,
                            //     decoration: BoxDecoration(color: Theme.of(context).cardColor),
                            //     child: TabBar(
                            //       controller: _tabController,
                            //       indicatorColor: Theme.of(context).hintColor,
                            //       indicatorWeight: 3,
                            //       padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeDefault),
                            //       indicatorSize: TabBarIndicatorSize.tab,
                            //       labelColor: Theme.of(context).textTheme.bodyLarge!.color,
                            //       unselectedLabelColor: Theme.of(context).disabledColor,
                            //       unselectedLabelStyle: robotoBold.copyWith(color: Theme.of(context).disabledColor),
                            //       labelStyle: robotoBold.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor),
                            //       tabs: _review! ? [
                            //         Tab(text: 'all_items'.tr),
                            //         Tab(text: 'reviews'.tr),
                            //       ] : [
                            //         Tab(text: 'all_items'.tr),
                            //       ],
                            //     ),
                            //   ))),
                            // ),
                            //
                            // SliverToBoxAdapter(child: AnimatedBuilder(
                            //   animation: _tabController!.animation!,
                            //   builder: (context, child) {
                            //     if (_tabController!.index == 0) {
                            //       return Get.find<ProfileController>().modulePermission!.item!
                            //           ? ItemViewWidget(scrollController: _scrollController, type: storeController.type, onVegFilterTap: (String type) {
                            //         Get.find<StoreController>().getItemList(offset: '1', type: type, search: '', categoryId: 0);
                            //       }) : Center(child: Padding(
                            //         padding: const EdgeInsets.only(top: 100),
                            //         child: Text('you_have_no_permission_to_access_this_feature'.tr, style: robotoMedium),
                            //       ));
                            //     } else {
                            //       return haveSubscription ? Get.find<ProfileController>().modulePermission!.reviews! ? storeController.storeReviewList != null ? storeController.storeReviewList!.isNotEmpty ? ListView.builder(
                            //         itemCount: storeController.storeReviewList!.length,
                            //         physics: const NeverScrollableScrollPhysics(),
                            //         shrinkWrap: true,
                            //         padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                            //         itemBuilder: (context, index) {
                            //           return ReviewWidget(
                            //             review: storeController.storeReviewList![index], fromStore: true,
                            //             hasDivider: index != storeController.storeReviewList!.length-1,
                            //           );
                            //         },
                            //       ) : Padding(
                            //         padding: const EdgeInsets.only(top: 200),
                            //         child: Center(child: Text('no_review_found'.tr, style: robotoRegular.copyWith(color: Theme.of(context).disabledColor))),
                            //       ) : const Padding(
                            //         padding: EdgeInsets.only(top: Dimensions.paddingSizeLarge),
                            //         child: Center(child: CircularProgressIndicator()),
                            //       ) : Center(child: Padding(
                            //         padding: const EdgeInsets.only(top: 100),
                            //         child: Text('you_have_no_permission_to_access_this_feature'.tr, style: robotoMedium),
                            //       )) : Padding(
                            //         padding: const EdgeInsets.only(top: 50),
                            //         child: Center(child: Text('you_have_no_available_subscription'.tr, style: robotoRegular.copyWith(color: Theme.of(context).disabledColor))),
                            //       );
                            //     }
                            //   },
                            // )),
                          ],
                        ),
                      ),
                    ),
                  )
                : Scaffold(
                    body: Center(
                      child: Text(
                        'you_have_no_permission_to_access_this_feature'.tr,
                        style: robotoMedium,
                      ),
                    ),
                  );
          },
        );
      },
    );
  }
}

class SliverDelegate extends SliverPersistentHeaderDelegate {
  Widget child;
  final double height;

  SliverDelegate({required this.child, required this.height});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(height: height, child: child);
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(SliverDelegate oldDelegate) {
    return oldDelegate.maxExtent != height ||
        oldDelegate.minExtent != height ||
        child != oldDelegate.child;
  }
}
