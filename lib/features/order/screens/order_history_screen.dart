import 'package:ppdelistore/features/order/controllers/order_controller.dart';
import 'package:ppdelistore/features/order/widgets/running_order_body_widget.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:ppdelistore/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../widgets/order_history_body_widget.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.find<OrderController>().getPaginatedOrders(1, true);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: CustomAppBarWidget(
          title: 'my_orders'.tr,
          isBackButtonExist: false,
          bottom: _orderTabBar(context),
        ),
        body: TabBarView(
          children: [RunningOrderBodyWidget(), OrderHistoryBodyWidget()],
        ),
      ),
    );
  }
}

TabBar _orderTabBar(BuildContext context) {
  return TabBar(
    indicator: BoxDecoration(
      color: Theme.of(context).primaryColor,
      borderRadius: BorderRadius.circular(30),
    ),
    indicatorSize: TabBarIndicatorSize.tab,
    labelColor: Theme.of(context).cardColor,
    unselectedLabelColor: Theme.of(context).hintColor,
    labelStyle: robotoMedium.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
    unselectedLabelStyle: robotoMedium.copyWith(fontSize: 14),
    dividerColor: Colors.transparent,
    overlayColor: WidgetStateProperty.all(Colors.transparent),
    padding: const EdgeInsets.only(
      left: Dimensions.paddingSizeDefault,
      top: Dimensions.paddingSizeSmall,
      bottom: Dimensions.paddingSizeDefault,
      right: 96,
    ),
    tabs: [
      Tab(text: 'running_order'.tr),
      Tab(text: 'order_history'.tr),
    ],
  );
}
