import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../util/dimensions.dart';
import '../../../util/styles.dart';
import '../../home/widgets/order_button_widget.dart';
import '../../profile/controllers/profile_controller.dart';
import '../controllers/order_controller.dart';
import 'count_widget.dart';
import 'order_view_widget.dart';

class OrderHistoryBodyWidget extends StatelessWidget {
  const OrderHistoryBodyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<OrderController>(builder: (orderController) {
      return Get.find<ProfileController>().modulePermission!.order! ? Container(
        color: Theme.of(context).cardColor,
        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        child: Column(children: [
          GetBuilder<ProfileController>(builder: (profileController) {
            return profileController.profileModel != null ? Container(
              margin: EdgeInsets.only(top: Dimensions.paddingSizeSmall),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                boxShadow: [BoxShadow(
                  offset: Offset(0, 1),
                  color: Theme.of(context).disabledColor.withValues(alpha: 0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                )]
              ),
              child: Row(children: [
                CountWidget(title: 'today'.tr, count: profileController.profileModel!.todaysOrderCount),
                Container(width: 1, height: 30, color: Theme.of(context).hintColor.withValues(alpha: 0.2)),
                CountWidget(title: 'this_week'.tr, count: profileController.profileModel!.thisWeekOrderCount),
                Container(width: 1, height: 30, color: Theme.of(context).hintColor.withValues(alpha: 0.2)),
                CountWidget(title: 'this_month'.tr, count: profileController.profileModel!.thisMonthOrderCount),
              ]),
            ) : const SizedBox();
          }),
          const SizedBox(height: Dimensions.paddingSizeLarge),

          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: orderController.statusList.length,
              itemBuilder: (context, index) {
                return OrderButtonWidget(
                  title: orderController.statusList[index].tr, index: index, orderController: orderController, fromHistory: true,
                );
              },
            ),
          ),
          SizedBox(height: orderController.historyOrderList != null ? Dimensions.paddingSizeSmall : 0),

          Expanded(
            child: orderController.historyOrderList != null ? orderController.historyOrderList!.isNotEmpty
                ? const OrderViewWidget() : Center(child: Text('no_order_found'.tr)) : const Center(child: CircularProgressIndicator()),
          ),

        ]),
      ) : Center(child: Text('you_have_no_permission_to_access_this_feature'.tr, style: robotoMedium));
    });
  }
}
