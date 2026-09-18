import 'package:ppdelistore/common/widgets/details_custom_card.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:flutter/material.dart';

class ProfileCardWidget extends StatelessWidget {
  final String title;
  final String data;
  const ProfileCardWidget({super.key, required this.data, required this.title});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DetailsCustomCard(
        height: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              data,
              style: robotoMedium.copyWith(
                fontSize: Dimensions.fontSizeExtraLarge,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeSmall),

            Text(
              title,
              style: robotoRegular.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: Theme.of(context).disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
