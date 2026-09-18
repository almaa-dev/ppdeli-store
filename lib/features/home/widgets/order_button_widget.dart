import 'package:ppdelistore/common/widgets/custom_ink_well_widget.dart';
import 'package:ppdelistore/features/order/controllers/order_controller.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:flutter/material.dart';

class OrderButtonWidget extends StatelessWidget {
  final String title;
  final int index;
  final OrderController orderController;
  final bool fromHistory;
  const OrderButtonWidget({
    super.key,
    required this.title,
    required this.index,
    required this.orderController,
    required this.fromHistory,
  });

  @override
  Widget build(BuildContext context) {
    int selectedIndex;
    int length = 0;
    int titleLength = 0;
    if (fromHistory) {
      selectedIndex = orderController.historyIndex;
      titleLength = orderController.statusList.length;
      length = 0;
      debugPrint('$titleLength');
    } else {
      selectedIndex = orderController.orderIndex;
      titleLength = orderController.runningOrders!.length;
      length = orderController.runningOrders![index].orderList.length;
    }
    bool isSelected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(right: Dimensions.paddingSizeSmall),
      child: CustomInkWellWidget(
        radius: Dimensions.radiusDefault,
        onTap: () => fromHistory
            ? orderController.setHistoryIndex(index)
            : orderController.setOrderIndex(index),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeSmall,
          ),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
                width: 1,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: robotoMedium.copyWith(
                  fontSize: Dimensions.fontSizeSmall,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).hintColor,
                ),
              ),

              !fromHistory
                  ? Container(
                      margin: const EdgeInsets.only(
                        left: Dimensions.paddingSizeExtraSmall,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeExtraSmall,
                        vertical: 2,
                      ),
                      child: Text(
                        '($length)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).hintColor,
                        ),
                      ),
                    )
                  : const SizedBox(),
            ],
          ),
        ),
      ),
    );
  }
}
