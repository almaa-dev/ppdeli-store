import 'package:flutter/material.dart';

import '../../../common/widgets/custom_tool_tip_widget.dart';
import '../../../util/dimensions.dart';
import '../../../util/styles.dart';

class MetaSeoItem extends StatelessWidget {
  final String title;
  final bool value;
  final Function(bool?) callback;
  final String? message;
  const MetaSeoItem({super.key, required this.title, required this.value, required this.callback, this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      child: InkWell(
        onTap: () => callback(!value),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.start, children: [
          SizedBox(
            height: Dimensions.paddingSizeDefault, width: Dimensions.paddingSizeDefault,
            child: Checkbox(
              checkColor: Theme.of(context).cardColor,
              value: value,
              onChanged: callback,
            ),
          ),
          const SizedBox(width: Dimensions.paddingSizeSmall),

          Flexible(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeDefault, color: Theme.of(context).textTheme.bodyLarge?.color))),
          SizedBox(width: message != null ? Dimensions.paddingSizeSmall : 0),

          message != null ? CustomToolTip(
            message: message!,
            size: 16,
          ) : SizedBox(),
        ]),
      ),
    );
  }
}