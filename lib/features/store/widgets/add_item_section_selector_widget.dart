import 'package:flutter/material.dart';
import 'package:ppdelistore/common/widgets/custom_ink_well_widget.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';

class AddItemSectionSelectorWidget extends StatelessWidget {
  final List<String> sectionTitles;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const AddItemSectionSelectorWidget({
    super.key,
    required this.sectionTitles,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(sectionTitles.length, (index) {
          final bool isSelected = selectedIndex == index;

          return CustomInkWellWidget(
            radius: 26,
            onTap: () => onSelect(index),
            highlightColor: Colors.transparent,
            child: AnimatedContainer(
              padding: EdgeInsets.symmetric(
                horizontal: Dimensions.paddingSizeDefault,
                vertical: Dimensions.paddingSizeSmall,
              ),
              margin: EdgeInsets.only(right: Dimensions.paddingSizeSmall),
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).disabledColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(
                  Dimensions.radiusExtraLarge,
                ),
              ),
              child: Text(
                sectionTitles[index],
                textAlign: TextAlign.center,
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeLarge,
                  color: isSelected
                      ? Theme.of(context).cardColor
                      : Theme.of(
                          context,
                        ).textTheme.bodyLarge?.color?.withValues(alpha: 0.75),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
