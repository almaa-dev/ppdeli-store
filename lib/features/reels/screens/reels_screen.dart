import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/common/widgets/custom_app_bar_widget.dart';
import 'package:ppdelistore/features/reels/controllers/reels_controller.dart';
import 'package:ppdelistore/features/reels/domain/models/reel_model.dart';
import 'package:ppdelistore/features/reels/widgets/reel_card_widget.dart';
import 'package:ppdelistore/helper/route_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Get.find<ReelsController>().setStatusIndex(0, willUpdate: false);
    Get.find<ReelsController>().getReelsList('1', 'all');

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
              _scrollController.position.maxScrollExtent &&
          Get.find<ReelsController>().reelsList != null &&
          !Get.find<ReelsController>().isLoading) {
        final int pageSize = (Get.find<ReelsController>().pageSize! / 10)
            .ceil();
        if (Get.find<ReelsController>().offset < pageSize) {
          Get.find<ReelsController>().setOffset(
            Get.find<ReelsController>().offset + 1,
          );
          Get.find<ReelsController>().showBottomLoader();
          Get.find<ReelsController>().getReelsList(
            Get.find<ReelsController>().offset.toString(),
            Get.find<ReelsController>().type,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ReelsController>(
      builder: (reelsController) {
        return Scaffold(
          appBar: CustomAppBarWidget(title: 'reels'.tr),
          body: Column(
            children: [
              if (reelsController.isSearchActive)
                _buildSearchField(reelsController),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      Dimensions.radiusDefault,
                    ),
                    color: Theme.of(context).cardColor,
                  ),
                  // margin: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                  // padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                  child: Column(
                    children: [
                      const SizedBox(height: Dimensions.paddingSizeDefault),
                      _buildStatusTabs(reelsController),
                      const SizedBox(height: Dimensions.paddingSizeSmall),
                      _buildListHeader(context, reelsController),
                      const SizedBox(height: Dimensions.paddingSizeSmall),
                      Expanded(child: _buildBody(reelsController)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: reelsController.reelsList != null
              ? FloatingActionButton(
                  elevation: 0,
                  backgroundColor: Theme.of(context).primaryColor,
                  onPressed: () => Get.toNamed(RouteHelper.getAddReelRoute()),
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }

  Widget _buildSearchField(ReelsController reelsController) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeSmall,
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'search_reels'.tr,
          hintStyle: robotoRegular.copyWith(
            fontSize: Dimensions.fontSizeDefault,
            color: Theme.of(context).disabledColor,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Theme.of(context).disabledColor,
          ),
          suffixIcon: IconButton(
            icon: Icon(Icons.close, color: Theme.of(context).disabledColor),
            onPressed: () {
              _searchController.clear();
              reelsController.toggleSearch();
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            borderSide: BorderSide(
              color: Theme.of(context).disabledColor.withValues(alpha: 0.3),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            borderSide: BorderSide(
              color: Theme.of(context).disabledColor.withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
          ),
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: Theme.of(context).disabledColor.withValues(alpha: 0.05),
        ),
        onChanged: reelsController.searchReels,
      ),
    );
  }

  Widget _buildStatusTabs(ReelsController reelsController) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: reelsController.statusList.length,
        padding: EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
        itemBuilder: (context, index) {
          return _statusTabWidget(
            reelsController: reelsController,
            title: reelsController.statusList[index].tr,
            index: index,
          );
        },
      ),
    );
  }

  Widget _statusTabWidget({
    required ReelsController reelsController,
    required String title,
    required int index,
  }) {
    final bool isSelected = reelsController.statusIndex == index;

    return InkWell(
      onTap: () {
        reelsController.setStatusIndex(index);
        reelsController.setType(reelsController.statusList[index]);
        reelsController.setOffset(1);
        reelsController.getReelsList('1', reelsController.statusList[index]);
        if (reelsController.isSearchActive) {
          _searchController.clear();
          reelsController.toggleSearch();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeDefault,
        ),
        margin: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Dimensions.radiusExtraLarge),
          color: isSelected
              ? Theme.of(context).primaryColor
              : Theme.of(context).disabledColor.withValues(alpha: 0.3),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: robotoMedium.copyWith(
            fontSize: Dimensions.fontSizeSmall,
            color: isSelected
                ? Theme.of(context).cardColor
                : Theme.of(context).textTheme.bodyLarge!.color,
          ),
        ),
      ),
    );
  }

  Widget _buildListHeader(
    BuildContext context,
    ReelsController reelsController,
  ) {
    final int totalCount =
        reelsController.isSearchActive &&
            reelsController.searchedReelsList != null
        ? reelsController.searchedReelsList!.length
        : (reelsController.reelsModel?.totalSize ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${'reels'.tr} ($totalCount)',
            style: robotoBold.copyWith(fontSize: Dimensions.fontSizeDefault),
          ),
          Row(
            children: [
              InkWell(
                onTap: () => reelsController.toggleSearch(),
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                child: Container(
                  padding: const EdgeInsets.all(
                    Dimensions.paddingSizeExtraSmall,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    color: reelsController.isSearchActive
                        ? Theme.of(context).cardColor
                        : Theme.of(
                            context,
                          ).disabledColor.withValues(alpha: 0.2),
                    border: Border.all(
                      color: Theme.of(context).disabledColor,
                      width: 0.2,
                    ),
                  ),
                  child: Icon(
                    Icons.search,
                    size: 22,
                    color: reelsController.isSearchActive
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
              ),
              const SizedBox(width: Dimensions.paddingSizeSmall),
              PopupMenuButton<int>(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                ),
                offset: const Offset(0, 35),
                padding: EdgeInsets.zero,
                onSelected: (int index) {
                  reelsController.setFilterIndex(index);
                },
                itemBuilder: (context) {
                  return List.generate(reelsController.filterList.length, (
                    index,
                  ) {
                    final bool isSelected =
                        reelsController.filterIndex == index;
                    return PopupMenuItem<int>(
                      value: index,
                      child: Text(
                        reelsController.filterList[index].tr,
                        style: (isSelected ? robotoBold : robotoRegular)
                            .copyWith(
                              fontSize: Dimensions.fontSizeDefault,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(
                                      context,
                                    ).textTheme.bodyLarge!.color,
                            ),
                      ),
                    );
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(
                    Dimensions.paddingSizeExtraSmall,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    color: Theme.of(context).cardColor,
                    border: Border.all(
                      color: Theme.of(context).disabledColor,
                      width: 0.2,
                    ),
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    size: 22,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ReelsController reelsController) {
    if (reelsController.reelsList == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<Reel> displayList =
        reelsController.isSearchActive &&
            reelsController.searchedReelsList != null
        ? reelsController.searchedReelsList!
        : reelsController.reelsList!;

    if (displayList.isEmpty) {
      return _buildEmptyView(reelsController);
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: displayList.length + 1,
            padding: const EdgeInsets.symmetric(
              horizontal: Dimensions.paddingSizeDefault,
              vertical: Dimensions.paddingSizeExtraSmall,
            ),
            itemBuilder: (context, index) {
              if (index == displayList.length) {
                return const SizedBox(
                  height: Dimensions.paddingSizeExtraLarge * 2,
                );
              }
              return ReelCardWidget(
                reel: displayList[index],
                onTap: () => Get.toNamed(
                  RouteHelper.getReelDetailsRoute(displayList[index]),
                ),
              );
            },
          ),
        ),
        if (reelsController.isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyView(ReelsController reelsController) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 64,
            color: Theme.of(context).disabledColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Text(
            reelsController.isSearchActive
                ? 'no_reels_found'.tr
                : 'no_reels_available'.tr,
            style: robotoMedium.copyWith(
              fontSize: Dimensions.fontSizeLarge,
              color: Theme.of(context).disabledColor,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(
            reelsController.isSearchActive
                ? 'try_different_search'.tr
                : 'create_your_first_reel'.tr,
            style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeDefault,
              color: Theme.of(context).disabledColor,
            ),
          ),
        ],
      ),
    );
  }
}
