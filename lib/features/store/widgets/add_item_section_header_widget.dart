import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:ppdelistore/common/widgets/custom_ink_well_widget.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';

class AddItemSectionHeaderWidget extends StatelessWidget {
  final String title;
  final String? subTitle;
  final bool isRequired;
  final String? requiredText;
  final String actionText;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool showAction;
  final IconData actionIcon;
  final Color actionColor;
  final Widget child;

  const AddItemSectionHeaderWidget({
    super.key,
    required this.title,
    this.subTitle,
    this.isRequired = false,
    this.requiredText,
    this.actionText = 'Generate',
    this.onTap,
    this.isLoading = false,
    this.showAction = false,
    this.actionIcon = Icons.auto_awesome,
    this.actionColor = Colors.blue,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: title,
                            children: isRequired
                                ? [
                                    TextSpan(
                                      text: ' ${requiredText ?? '*'}',
                                      style: robotoSemiBold.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                        fontSize: Dimensions.fontSizeSmall,
                                      ),
                                    ),
                                  ]
                                : null,
                          ),
                          style: robotoSemiBold.copyWith(
                            fontSize: Dimensions.fontSizeDefault,
                          ),
                        ),
                      ),

                      if (showAction) ...[
                        const SizedBox(width: Dimensions.paddingSizeSmall),
                        CustomInkWellWidget(
                          radius: Dimensions.radiusDefault,
                          onTap: onTap ?? () {},
                          highlightColor: Colors.transparent,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Shimmer(
                                enabled: isLoading,
                                color: Colors.blue,
                                duration: Duration(seconds: 2),
                                child: Row(
                                  children: [
                                    Icon(
                                      actionIcon,
                                      size: Dimensions.fontSizeSmall,
                                      color: actionColor,
                                    ),
                                    const SizedBox(
                                      width: Dimensions.paddingSizeExtraSmall,
                                    ),

                                    Text(
                                      isLoading ? 'Generating' : actionText,
                                      style: robotoMedium.copyWith(
                                        fontSize: Dimensions.fontSizeSmall,
                                        color: actionColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: Dimensions.paddingSizeExtraSmall),

                  if (subTitle != null)
                    Text(
                      subTitle!,
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        color: Theme.of(
                          context,
                        ).disabledColor.withValues(alpha: 0.95),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: Dimensions.paddingSizeExtraLarge),

        child,
      ],
    );
  }
}

class AiGenerateWrapper extends StatelessWidget {
  final String? title;
  final String actionText;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool showAction;
  final IconData actionIcon;
  final Color actionColor;
  final Widget child;

  const AiGenerateWrapper({
    super.key,
    this.title,
    this.actionText = 'Generate',
    this.onTap,
    this.isLoading = false,
    this.showAction = true,
    this.actionIcon = Icons.auto_awesome,
    this.actionColor = Colors.blue,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null || showAction) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title ?? '',
                            style: robotoSemiBold.copyWith(
                              fontSize: Dimensions.fontSizeLarge,
                            ),
                          ),
                        ),

                        if (showAction) ...[
                          const SizedBox(width: Dimensions.paddingSizeSmall),
                          CustomInkWellWidget(
                            radius: Dimensions.radiusDefault,
                            onTap: onTap ?? () {},
                            highlightColor: Colors.transparent,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Shimmer(
                                  enabled: isLoading,
                                  color: Colors.blue,
                                  duration: Duration(seconds: 2),
                                  child: Row(
                                    children: [
                                      Icon(
                                        actionIcon,
                                        size: Dimensions.fontSizeSmall,
                                        color: actionColor,
                                      ),
                                      const SizedBox(
                                        width: Dimensions.paddingSizeExtraSmall,
                                      ),

                                      Text(
                                        isLoading ? 'Generating' : actionText,
                                        style: robotoMedium.copyWith(
                                          fontSize: Dimensions.fontSizeSmall,
                                          color: actionColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Dimensions.paddingSizeSmall),
        ],

        child,
      ],
    );
  }
}
