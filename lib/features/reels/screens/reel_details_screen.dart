import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/common/widgets/custom_app_bar_widget.dart';
import 'package:ppdelistore/common/widgets/custom_image_widget.dart';
import 'package:ppdelistore/common/widgets/network_video_preview_widget.dart';
import 'package:ppdelistore/features/reels/domain/models/reel_model.dart';
import 'package:ppdelistore/helper/date_converter_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';

class ReelDetailsScreen extends StatelessWidget {
  final Reel reel;
  const ReelDetailsScreen({super.key, required this.reel});

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'always_visible'.tr;
    try {
      return DateConverterHelper.convertDateToDate(raw);
    } catch (_) {
      return raw;
    }
  }

  Color _statusColor(BuildContext context) {
    switch (reel.reelStatusLabel) {
      case 'live':
        return Colors.green;
      case 'upcoming':
        return Colors.blue;
      case 'expired':
        return Colors.red;
      case 'deactivated':
        return Theme.of(context).disabledColor;
      default:
        return Theme.of(context).disabledColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(context);
    final bool hasVideo =
        reel.videoFullUrl != null && reel.videoFullUrl!.isNotEmpty;

    return Scaffold(
      appBar: CustomAppBarWidget(title: 'reels_details'.tr),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPreview(context, hasVideo),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
                vertical: Dimensions.paddingSizeSmall,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDescriptionCard(context, statusColor),
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                  _buildValidityCard(context),
                  const SizedBox(height: Dimensions.paddingSizeDefault),
                  _buildStatsCard(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context, bool hasVideo) {
    if (hasVideo) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeDefault,
          vertical: Dimensions.paddingSizeSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'video'.tr,
              style: robotoMedium.copyWith(
                fontSize: Dimensions.fontSizeDefault,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),
            ClipRRect(
              borderRadius: BorderRadius.all(
                Radius.circular(Dimensions.paddingSizeExtraSmall),
              ),
              child: NetworkVideoPreviewWidget(
                videoFile: reel.videoFullUrl!,
                height: MediaQuery.of(context).size.height * 0.45,
              ),
            ),
          ],
        ),
      );
    }

    final double height = MediaQuery.of(context).size.height * 0.45;
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeSmall,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        child:
            reel.thumbnailFullUrl != null && reel.thumbnailFullUrl!.isNotEmpty
            ? CustomImageWidget(
                image: reel.thumbnailFullUrl!,
                width: double.infinity,
                height: height,
                fit: BoxFit.cover,
              )
            : Container(
                color: Theme.of(context).disabledColor.withValues(alpha: 0.15),
                alignment: Alignment.center,
                child: Icon(
                  Icons.play_circle_outline,
                  size: 72,
                  color: Theme.of(context).disabledColor.withValues(alpha: 0.5),
                ),
              ),
      ),
    );
  }

  Widget _buildDescriptionCard(BuildContext context, Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).disabledColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'reel_id'.tr,
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                    ),
                  ),
                  Text(
                    ' #${reel.id ?? ''}',
                    style: robotoBold.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 3,
                  horizontal: Dimensions.paddingSizeSmall,
                ),
                child: Text(
                  (reel.reelStatusLabel ?? '').tr,
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeExtraSmall,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Text(
            'short_description'.tr,
            style: robotoBold.copyWith(fontSize: Dimensions.fontSizeDefault),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(
            reel.description ?? '',
            style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidityCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).disabledColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'reel_validity'.tr,
            style: robotoBold.copyWith(fontSize: Dimensions.fontSizeDefault),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _buildLabelValue(
                    context,
                    label: 'upload_date'.tr,
                    value: _formatDate(reel.createdAt),
                  ),
                ),

                Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeDefault,
                  ),
                  width: 2,
                  color: Theme.of(context).disabledColor.withAlpha(100),
                ),

                Expanded(
                  child: _buildLabelValue(
                    context,
                    label: 'expired_date'.tr,
                    value: _formatDate(reel.endDate),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelValue(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: robotoRegular.copyWith(
            fontSize: Dimensions.fontSizeSmall,
            color: Theme.of(context).disabledColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: robotoBold.copyWith(fontSize: Dimensions.fontSizeSmall),
        ),
      ],
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeDefault,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).disabledColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Row(
        children: [
          Expanded(
            child: _statItem(
              context,
              icon: Icons.remove_red_eye_outlined,
              label: 'views'.tr,
              value: _formatCount(reel.totalViews ?? 0),
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: Theme.of(context).disabledColor.withValues(alpha: 0.25),
          ),
          Expanded(
            child: _statItem(
              context,
              icon: Icons.thumb_up_off_alt_outlined,
              label: 'likes'.tr,
              value: _formatCount(reel.totalLikes ?? 0),
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: Theme.of(context).disabledColor.withValues(alpha: 0.25),
          ),
          Expanded(
            child: _statItem(
              context,
              icon: Icons.store_mall_directory_outlined,
              label: 'store_visits'.tr,
              value: _formatCount(reel.totalStoreVisits ?? 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Theme.of(context).disabledColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: Theme.of(context).disabledColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: robotoBold.copyWith(
            fontSize: Dimensions.fontSizeLarge,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ],
    );
  }
}
