import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/common/widgets/custom_button_widget.dart';
import 'package:ppdelistore/common/widgets/custom_image_widget.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/features/store/domain/models/review_model.dart';
import 'package:ppdelistore/helper/date_converter_helper.dart';
import 'package:ppdelistore/helper/route_helper.dart';
import 'package:ppdelistore/common/widgets/rating_bar_widget.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';
import 'package:ppdelistore/util/styles.dart';

class ReviewCardWidget extends StatelessWidget {
  final ReviewModel review;
  const ReviewCardWidget({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
                  child: CustomImageWidget(
                    image: '${review.itemImageFullUrl}',
                    height: 60,
                    width: 60,
                    fit: BoxFit.cover,
                    placeholder: Images.placeholder,
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeDefault),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.itemName ?? '',
                        style: robotoBold,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                      RatingBarWidget(
                        rating: (review.rating ?? 0).toDouble(),
                        ratingCount: null,
                        size: 15,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeDefault),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      review.reviewId != null
                          ? "${'review_id'.tr} # ${review.reviewId}"
                          : '',
                      style: robotoBold,
                    ),
                    Text(
                      DateConverterHelper.utcToDateTime(review.createdAt!),
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(
            height: 0,
            thickness: 1,
            color: Theme.of(context).disabledColor.withValues(alpha: 0.2),
          ),

          Padding(
            padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'reviewer'.tr,
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Theme.of(context).disabledColor,
                      ),
                    ),
                    const SizedBox(height: Dimensions.paddingSizeSmall),
                    Text(review.customerName ?? '', style: robotoBold),
                  ],
                ),

                // Reply Button
                Get.find<SplashController>().configModel!.storeReviewReply ??
                        false
                    ? CustomButtonWidget(
                        onPressed: () => Get.toNamed(
                          RouteHelper.getReviewReplyRoute(
                            isGiveReply: review.reply != null ? false : true,
                            review: review,
                            storeReviewReplyStatus: Get.find<SplashController>()
                                .configModel!
                                .storeReviewReply!,
                          ),
                        ),
                        width: 95,
                        height: 40,
                        radius: 8,
                        fontWeight: FontWeight.w500,
                        fontSize: Dimensions.fontSizeDefault,
                        buttonText: review.reply != null
                            ? 'view_reply'.tr
                            : 'give_reply'.tr,
                        color: review.reply != null
                            ? Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.1)
                            : Theme.of(context).primaryColor,
                        isViewReply: review.reply != null,
                      )
                    : CustomButtonWidget(
                        onPressed: () => Get.toNamed(
                          RouteHelper.getReviewReplyRoute(
                            isGiveReply: review.reply != null ? false : true,
                            review: review,
                            storeReviewReplyStatus: Get.find<SplashController>()
                                .configModel!
                                .storeReviewReply!,
                          ),
                        ),
                        width: 95,
                        height: 40,
                        radius: 8,
                        fontWeight: FontWeight.w500,
                        fontSize: Dimensions.fontSizeDefault,
                        buttonText: 'view'.tr,
                        color: Theme.of(context).primaryColor,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
