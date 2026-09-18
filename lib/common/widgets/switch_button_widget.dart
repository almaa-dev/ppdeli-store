import 'package:flutter/cupertino.dart';
import 'package:ppdelistore/common/widgets/details_custom_card.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:flutter/material.dart';

class SwitchButtonWidget extends StatelessWidget {
  final IconData? icon;
  final String title;
  final bool? isButtonActive;
  final Function onTap;
  final String? description;
  final String? languageName;
  const SwitchButtonWidget({
    super.key,
    this.icon,
    required this.title,
    required this.onTap,
    this.isButtonActive,
    this.description,
    this.languageName,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap as void Function()?,
      child: DetailsCustomCard(
        padding: EdgeInsets.only(
          left: Dimensions.paddingSizeDefault,
          top: isButtonActive != null
              ? Dimensions.paddingSizeSmall
              : Dimensions.paddingSizeDefault,
          bottom: isButtonActive != null
              ? Dimensions.paddingSizeSmall
              : Dimensions.paddingSizeDefault,
        ),
        child: Row(
          children: [
            icon != null ? Icon(icon, size: 25) : const SizedBox(),
            SizedBox(width: icon != null ? Dimensions.paddingSizeSmall : 0),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: robotoRegular),

                  description != null
                      ? Padding(
                          padding: const EdgeInsets.only(
                            top: Dimensions.paddingSizeExtraSmall,
                          ),
                          child: Text(
                            description!,
                            style: robotoRegular.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        )
                      : const SizedBox(),
                ],
              ),
            ),

            isButtonActive != null
                ? Transform.scale(
                    scale: 0.7,
                    child: CupertinoSwitch(
                      activeTrackColor: Theme.of(context).primaryColor,
                      inactiveTrackColor: Theme.of(
                        context,
                      ).hintColor.withValues(alpha: 0.5),
                      value: isButtonActive!,
                      onChanged: (bool? value) => onTap(),
                    ),
                  )
                : languageName != null
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusSmall,
                      ),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).hintColor.withValues(alpha: 0.5),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeSmall,
                      vertical: Dimensions.paddingSizeExtraSmall,
                    ),
                    margin: const EdgeInsets.only(
                      right: Dimensions.paddingSizeLarge,
                    ),
                    child: Row(
                      children: [
                        Text(
                          languageName!,
                          style: robotoRegular.copyWith(
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        ),
                        const SizedBox(width: Dimensions.paddingSizeSmall),

                        Icon(Icons.keyboard_arrow_down, size: 15),
                      ],
                    ),
                  )
                : const SizedBox(),
          ],
        ),
      ),
    );
  }
}
