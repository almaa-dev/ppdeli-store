import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/common/widgets/rating_bar_widget.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';

class ReviewSummaryWidget extends StatelessWidget {
  final double avgRating;
  final int totalReviews;
  final List<int> ratingBreakdown;

  const ReviewSummaryWidget({
    super.key,
    required this.avgRating,
    required this.totalReviews,
    required this.ratingBreakdown,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      margin: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Row(
        children: [
          // Avg Rating
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: Dimensions.paddingSizeSmall,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              ),
              child: Column(
                children: [
                  Text(
                    avgRating.toStringAsFixed(1),
                    style: robotoBold.copyWith(fontSize: 40),
                  ),
                  RatingBarWidget(
                    rating: avgRating,
                    ratingCount: null,
                    size: 20,
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                  Text(
                    '$totalReviews ${'reviews'.tr}',
                    style: robotoRegular.copyWith(
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: Dimensions.paddingSizeDefault),

          // Progress Bars
          Expanded(
            flex: 6,
            child: Column(
              children: [
                _buildProgressBar(
                  context,
                  'excellent'.tr,
                  5,
                  ratingBreakdown[0],
                  totalReviews,
                ),
                SizedBox(height: Dimensions.paddingSizeExtraSmall),
                _buildProgressBar(
                  context,
                  'good'.tr,
                  4,
                  ratingBreakdown[1],
                  totalReviews,
                ),
                SizedBox(height: Dimensions.paddingSizeExtraSmall),
                _buildProgressBar(
                  context,
                  'average'.tr,
                  3,
                  ratingBreakdown[2],
                  totalReviews,
                ),
                SizedBox(height: Dimensions.paddingSizeExtraSmall),
                _buildProgressBar(
                  context,
                  'below_average'.tr,
                  2,
                  ratingBreakdown[3],
                  totalReviews,
                ),
                SizedBox(height: Dimensions.paddingSizeExtraSmall),
                _buildProgressBar(
                  context,
                  'poor'.tr,
                  1,
                  ratingBreakdown[4],
                  totalReviews,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    String title,
    int star,
    int count,
    int total,
  ) {
    double percentage = total == 0 ? 0 : (count / total);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: Theme.of(context).disabledColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeExtraSmall),
          Expanded(
            flex: 5,
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Theme.of(
                context,
              ).disabledColor.withValues(alpha: 0.2),
              color: Colors.green,
              minHeight: 4,
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeExtraSmall),
          Expanded(
            flex: 2,
            child: Text(
              '${(percentage * 100).toInt()}%',
              style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall,
                color: Theme.of(context).disabledColor,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
