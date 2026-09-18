import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:flutter/material.dart';

class CountWidget extends StatelessWidget {
  final String title;
  final int? count;
  const CountWidget({super.key, required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Dimensions.paddingSizeDefault,
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeExtraLarge,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
            Text(
              title,
              style: robotoMedium.copyWith(
                fontSize: Dimensions.fontSizeExtraSmall,
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
