import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/widgets/order_shimmer_widget.dart';
import '../../../common/widgets/order_widget.dart';
import '../../../util/dimensions.dart';
import '../../home/widgets/order_button_widget.dart';
import '../../profile/controllers/profile_controller.dart';
import '../../store/screens/store_screen.dart';
import '../controllers/order_controller.dart';
import '../domain/models/order_model.dart';

class RunningOrderBodyWidget extends StatelessWidget {
  const RunningOrderBodyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ProfileController>(
      builder: (profileController) {
        return GetBuilder<OrderController>(
          builder: (orderController) {
            List<OrderModel> orderList = [];
            if (orderController.runningOrders != null) {orderList = orderController.runningOrders![orderController.orderIndex].orderList;}

            return Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
              child: CustomScrollView(
                slivers: [
                  if (orderController.runningOrders != null)
                    SliverPersistentHeader(pinned: true, delegate: SliverDelegate(height: 50,
                      child: Container(height: 40, color: Theme.of(context).cardColor, child: ListView.builder(padding: EdgeInsets.only(bottom: Dimensions.paddingSizeSmall),
                        scrollDirection: Axis.horizontal,
                        itemCount: orderController.runningOrders!.length,
                        itemBuilder: (context, index) => OrderButtonWidget(
                          title: orderController.runningOrders![index].status.tr,
                          index: index,
                          orderController: orderController,
                          fromHistory: false,
                        )
                      ))
                    )),


                  if (orderController.runningOrders != null) orderList.isNotEmpty ? SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return OrderWidget(orderModel: orderList[index], hasDivider: index != orderList.length - 1, isRunning: true);
                      }, childCount: orderList.length)) : SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 50, bottom: 100),
                          child: Center(child: Text('no_order_found'.tr)),
                        ))
                  else
                    SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                      return OrderShimmerWidget(isEnabled: orderController.runningOrders == null);}, childCount: 10),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
