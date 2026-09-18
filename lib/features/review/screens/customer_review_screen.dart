import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/common/widgets/custom_app_bar_widget.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/features/review/widgets/customer_review_screen_shimmer.dart';
import 'package:ppdelistore/features/review/widgets/review_card_widget.dart';
import 'package:ppdelistore/features/store/controllers/store_controller.dart';
import 'package:ppdelistore/features/store/domain/models/review_model.dart';
import 'package:ppdelistore/features/review/widgets/review_summary_widget.dart';
import 'package:ppdelistore/util/dimensions.dart';

class CustomerReviewScreen extends StatefulWidget {
  const CustomerReviewScreen({super.key});

  @override
  State<CustomerReviewScreen> createState() => _CustomerReviewScreenState();
}

class _CustomerReviewScreenState extends State<CustomerReviewScreen> {
  @override
  void initState() {
    super.initState();

    Get.find<StoreController>().getStoreReviewList(
      Get.find<ProfileController>().profileModel!.stores![0].id,
      '',
      willUpdate: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarWidget(title: 'customer_reviews'.tr),
      body: GetBuilder<StoreController>(
        builder: (storeController) {
          List<ReviewModel>? searchReviewList;
          if (storeController.isSearching) {
            searchReviewList = storeController.searchReviewList;
          } else {
            searchReviewList = storeController.storeReviewList;
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: Dimensions.paddingSizeDefault),
                if (searchReviewList != null &&
                    !storeController.isSearching) ...[
                  ReviewSummaryWidget(
                    avgRating:
                        Get.find<ProfileController>()
                            .profileModel!
                            .stores![0]
                            .avgRating ??
                        0,
                    totalReviews:
                        Get.find<ProfileController>()
                            .profileModel!
                            .stores![0]
                            .ratingCount ??
                        0,
                    ratingBreakdown: _calculateRatingBreakdown(
                      storeController.storeReviewList ?? [],
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                ],

                searchReviewList != null
                    ? searchReviewList.isNotEmpty
                          ? ListView.builder(
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: searchReviewList.length,
                              shrinkWrap: true,
                              padding: const EdgeInsets.all(
                                Dimensions.paddingSizeSmall,
                              ),
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: Dimensions.paddingSizeDefault,
                                  ),
                                  child: ReviewCardWidget(
                                    review: searchReviewList![index],
                                  ),
                                );
                              },
                            )
                          : Padding(
                              padding: EdgeInsets.only(
                                top: context.height * 0.35,
                              ),
                              child: Text('no_review_found'.tr),
                            )
                    : const CustomerReviewScreenShimmer(),
              ],
            ),
          );
        },
      ),
    );
  }

  List<int> _calculateRatingBreakdown(List<ReviewModel> reviews) {
    List<int> breakdown = [0, 0, 0, 0, 0];
    for (var review in reviews) {
      if (review.rating == 5) {
        breakdown[0]++;
      } else if (review.rating == 4) {
        breakdown[1]++;
      } else if (review.rating == 3) {
        breakdown[2]++;
      } else if (review.rating == 2) {
        breakdown[3]++;
      } else if (review.rating == 1) {
        breakdown[4]++;
      }
    }
    return breakdown;
  }
}
