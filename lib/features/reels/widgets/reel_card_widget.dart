import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/common/widgets/custom_image_widget.dart';
import 'package:ppdelistore/common/widgets/custom_ink_well_widget.dart';
import 'package:ppdelistore/features/reels/controllers/reels_controller.dart';
import 'package:ppdelistore/features/reels/domain/models/reel_model.dart';
import 'package:ppdelistore/helper/route_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';
import 'package:ppdelistore/util/styles.dart';

class ReelCardWidget extends StatelessWidget {
  final Reel reel;
  final VoidCallback? onTap;

  const ReelCardWidget({super.key, required this.reel, this.onTap});

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
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

    return Container(
      margin: const EdgeInsets.only(bottom: Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        color: Theme.of(context).cardColor,
        border: Border.all(
          color: Theme.of(context).disabledColor.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CustomInkWellWidget(
        onTap: onTap!,
        radius: Dimensions.radiusDefault,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: Dimensions.paddingSizeSmall,
                top: Dimensions.paddingSizeSmall,
                bottom: Dimensions.paddingSizeSmall,
                right: Dimensions.paddingSizeExtraSmall,
              ),
              child: _buildThumbnail(context),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderRow(context, statusColor),
                    const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                    Text(
                      reel.description ?? '',
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Divider(
                      thickness: 1,
                      color: Theme.of(context).disabledColor.withAlpha(100),
                    ),

                    _buildStatsRow(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(
        Radius.circular(Dimensions.radiusSmall),
      ),
      child: reel.thumbnailFullUrl != null && reel.thumbnailFullUrl!.isNotEmpty
          ? CustomImageWidget(
              image: reel.thumbnailFullUrl!,
              width: 100,
              height: 120,
              fit: BoxFit.cover,
            )
          : _buildPlaceholder(context),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: 100,
      height: 120,
      color: Theme.of(context).disabledColor.withValues(alpha: 0.15),
      child: Icon(
        Icons.play_circle_outline,
        size: 36,
        color: Theme.of(context).disabledColor.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, Color statusColor) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                'reel_id'.tr,
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                ),
              ),
              Text(
                ' #${reel.id ?? ''}',
                style: robotoBold.copyWith(fontSize: Dimensions.fontSizeSmall),
              ),

              const SizedBox(width: Dimensions.paddingSizeExtraSmall),
              Container(
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
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
        ),
        PopupMenuButton<String>(
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(
              Radius.circular(Dimensions.radiusDefault),
            ),
            side: BorderSide(
              color: Theme.of(context).hintColor.withValues(alpha: 0.1),
            ),
          ),
          onSelected: (value) => _handleMenuAction(context, value),
          itemBuilder: (BuildContext context) {
            return _getMenuItems().map((item) {
              return PopupMenuItem<String>(
                value: item['value'],
                height: 40,
                child: Row(
                  children: [
                    Text(
                      (item['label'] as String).tr,
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                      ),
                    ),

                    Spacer(),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    item['icon'],
                  ],
                ),
              );
            }).toList();
          },
          child: const Icon(Icons.more_vert_sharp, size: 24),
        ),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statItem(
          context,
          icon: Icons.remove_red_eye_outlined,
          label: 'views'.tr,
          value: _formatCount(reel.totalViews ?? 0),
        ),
        Container(
          height: 30,
          width: 2,
          color: Theme.of(context).disabledColor.withValues(alpha: 0.3),
        ),

        _statItem(
          context,
          icon: Icons.favorite_border,
          label: 'likes'.tr,
          value: _formatCount(reel.totalLikes ?? 0),
        ),
        Container(
          height: 30,
          width: 2,
          color: Theme.of(context).disabledColor.withValues(alpha: 0.3),
        ),

        _statItem(
          context,
          icon: Icons.store_mall_directory_outlined,
          label: 'visits'.tr,
          value: _formatCount(reel.totalStoreVisits ?? 0),
        ),
      ],
    );
  }

  Widget _statItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: Theme.of(context).disabledColor),
            const SizedBox(width: 3),
            Text(
              label,
              style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall,
                color: Theme.of(context).disabledColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: robotoBold.copyWith(fontSize: Dimensions.fontSizeSmall),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getMenuItems() {
    switch (reel.reelStatusLabel) {
      case 'live':
        return [
          {
            'value': 'view',
            'label': 'view_reel',
            'icon': Image.asset(
              Images.view,
              color: Color(0xFF107980),
              height: 18,
              width: 18,
            ),
          },
          {
            'value': 'deactivate',
            'label': 'deactivate_reel',
            'icon': SizedBox(
              width: 24,
              height: 18,
              child: Transform.scale(
                scale: 0.6,
                child: IgnorePointer(
                  child: Switch(
                    value: true,
                    onChanged: (bool value) {},
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    thumbColor: WidgetStateProperty.all(Colors.white),
                    trackColor: WidgetStateProperty.resolveWith<Color>((
                      states,
                    ) {
                      return Color(0xFF107980);
                    }),
                  ),
                ),
              ),
            ),
          },
          {
            'value': 'edit',
            'label': 'edit_reel',
            'icon': Icon(Icons.edit, color: Colors.blue, size: 20),
          },
          {
            'value': 'delete',
            'label': 'delete_reel',
            'icon': Image.asset(
              Images.delete,
              color: Colors.red,
              height: 18,
              width: 18,
            ),
          },
        ];
      case 'upcoming':
        return [
          {
            'value': 'view',
            'label': 'view_reel',
            'icon': Image.asset(
              Images.view,
              color: Color(0xFF107980),
              height: 18,
              width: 18,
            ),
          },
          {
            'value': 'edit',
            'label': 'edit_reel',
            'icon': Icon(Icons.edit, color: Colors.blue, size: 18),
          },
          {
            'value': 'delete',
            'label': 'delete_reel',
            'icon': Image.asset(
              Images.delete,
              color: Colors.red,
              height: 18,
              width: 18,
            ),
          },
        ];
      case 'expired':
        return [
          {
            'value': 'view',
            'label': 'view_reel',
            'icon': Image.asset(
              Images.view,
              color: Color(0xFF107980),
              height: 18,
              width: 18,
            ),
          },
          {
            'value': 'delete',
            'label': 'delete_reel',
            'icon': Image.asset(
              Images.delete,
              color: Colors.red,
              height: 18,
              width: 18,
            ),
          },
        ];
      case 'deactivated':
        return [
          {
            'value': 'view',
            'label': 'view_reel',
            'icon': Image.asset(
              Images.view,
              color: Color(0xFF107980),
              height: 18,
              width: 18,
            ),
          },
          {
            'value': 'edit',
            'label': 'edit_reel',
            'icon': Icon(Icons.edit, color: Colors.blue, size: 18),
          },
          {
            'value': 'activate',
            'label': 'activate_reel',
            'icon': SizedBox(
              width: 24,
              height: 18,
              child: Transform.scale(
                scale: 0.6,
                child: IgnorePointer(
                  child: Switch(
                    value: false,
                    onChanged: (bool value) {},
                    trackOutlineColor: WidgetStateProperty.resolveWith<Color>((
                      states,
                    ) {
                      return Color(0xFF107980);
                    }),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    thumbColor: WidgetStateProperty.all(Color(0xFF107980)),
                    trackColor: WidgetStateProperty.resolveWith<Color>((
                      states,
                    ) {
                      return Color(0xFF107980).withAlpha(25);
                    }),
                  ),
                ),
              ),
            ),
          },
          {
            'value': 'delete',
            'label': 'delete_reel',
            'icon': Image.asset(
              Images.delete,
              color: Colors.red,
              height: 18,
              width: 18,
            ),
          },
        ];
      default:
        return [
          {
            'value': 'view',
            'label': 'view_reel',
            'icon': Image.asset(
              Images.view,
              color: Color(0xFF107980),
              height: 18,
              width: 18,
            ),
          },
          {
            'value': 'delete',
            'label': 'delete_reel',
            'icon': Image.asset(
              Images.delete,
              color: Colors.red,
              height: 18,
              width: 18,
            ),
          },
        ];
    }
  }

  void _handleMenuAction(BuildContext context, String value) {
    switch (value) {
      case 'view':
        Get.toNamed(RouteHelper.getReelDetailsRoute(reel));
        break;
      case 'edit':
        Get.toNamed(RouteHelper.getAddReelRoute(reel: reel));
        break;
      case 'deactivate':
        Get.find<ReelsController>().changeReelStatus(reel.id!, 0);
        break;
      case 'activate':
        Get.find<ReelsController>().changeReelStatus(reel.id!, 1);
        break;
      case 'delete':
        Get.dialog(
          AlertDialog(
            title: Text('delete_reel'.tr, style: robotoBold),
            content: Text(
              'are_you_sure_you_want_to_delete_this_reel'.tr,
              style: robotoRegular,
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
              TextButton(
                onPressed: () {
                  Get.back();
                  Get.find<ReelsController>().deleteReel(reel.id!);
                },
                child: Text(
                  'delete'.tr,
                  style: robotoMedium.copyWith(color: Colors.red),
                ),
              ),
            ],
          ),
        );
        break;
    }
  }
}
