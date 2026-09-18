import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ppdelistore/features/auth/controllers/auth_controller.dart';
import 'package:ppdelistore/features/home/widgets/business_analytics_widget.dart';
import 'package:ppdelistore/features/notification/controllers/notification_controller.dart';
import 'package:ppdelistore/features/order/controllers/order_controller.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/features/order/domain/models/order_model.dart';
import 'package:ppdelistore/helper/route_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:ppdelistore/common/widgets/order_shimmer_widget.dart';
import 'package:ppdelistore/common/widgets/order_widget.dart';
import 'package:ppdelistore/features/home/widgets/order_button_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppLifecycleListener _listener;
  bool _isNotificationPermissionGranted = true;
  bool _isBatteryOptimizationGranted = true;
  final JustTheController tooltipController = JustTheController();

  @override
  void initState() {
    super.initState();

    _checkSystemNotification();

    _listener = AppLifecycleListener(onStateChange: _onStateChanged);

    _loadData();

    Future.delayed(const Duration(milliseconds: 200), () {
      checkPermission();
    });
  }

  Future<void> _loadData() async {
    await Get.find<ProfileController>().getProfile();
    await Get.find<OrderController>().getCurrentOrders();
    await Get.find<NotificationController>().getNotificationList();
  }

  Future<void> _checkSystemNotification() async {
    if (await Permission.notification.status.isDenied ||
        await Permission.notification.status.isPermanentlyDenied) {
      await Get.find<AuthController>().setNotificationActive(false);
    }
  }

  void _onStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        break;
      case AppLifecycleState.resumed:
        Future.delayed(const Duration(milliseconds: 200), () {
          checkPermission();
        });
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        break;
      case AppLifecycleState.paused:
        break;
    }
  }

  Future<void> checkPermission() async {
    var notificationStatus = await Permission.notification.status;
    var batteryStatus = await Permission.ignoreBatteryOptimizations.status;

    if (notificationStatus.isDenied || notificationStatus.isPermanentlyDenied) {
      setState(() {
        _isNotificationPermissionGranted = false;
        _isBatteryOptimizationGranted = true;
      });

      await Get.find<AuthController>().setNotificationActive(
        !notificationStatus.isDenied,
      );
    } else if (batteryStatus.isDenied) {
      setState(() {
        _isBatteryOptimizationGranted = false;
        _isNotificationPermissionGranted = true;
      });
    } else {
      setState(() {
        _isNotificationPermissionGranted = true;
        _isBatteryOptimizationGranted = true;
      });
      Get.find<ProfileController>().setBackgroundNotificationActive(true);
    }

    if (batteryStatus.isDenied) {
      Get.find<ProfileController>().setBackgroundNotificationActive(false);
    }
  }

  Future<void> requestNotificationPermission() async {
    if (await Permission.notification.request().isGranted) {
      return;
    } else {
      await openAppSettings();
    }

    checkPermission();
  }

  void requestBatteryOptimization() async {
    var status = await Permission.ignoreBatteryOptimizations.status;

    if (status.isGranted) {
      return;
    } else if (status.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    } else {
      openAppSettings();
    }

    checkPermission();
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        titleSpacing: 0,
        surfaceTintColor: Theme.of(context).cardColor,
        shadowColor: Theme.of(context).disabledColor.withValues(alpha: 0.5),
        elevation: 2,
        title: Padding(
          padding: const EdgeInsets.only(left: Dimensions.paddingSizeDefault),
          child: Image.asset(Images.logo, height: 30),
        ),
        actions: [
          IconButton(
            icon: GetBuilder<NotificationController>(
              builder: (notificationController) {
                return Stack(
                  children: [
                    Icon(
                      Icons.notifications,
                      size: 25,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                    notificationController.hasNotification
                        ? Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              height: 10,
                              width: 10,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  width: 1,
                                  color: Theme.of(context).cardColor,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox(),
                  ],
                );
              },
            ),
            onPressed: () => Get.toNamed(RouteHelper.getNotificationRoute()),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          await _loadData();
        },
        child: GetBuilder<ProfileController>(
          builder: (profileController) {
            return GetBuilder<OrderController>(
              builder: (orderController) {
                List<OrderModel> orderList = [];
                if (orderController.runningOrders != null) {
                  orderList = orderController
                      .runningOrders![orderController.orderIndex]
                      .orderList;
                }

                return CustomScrollView(
                  slivers: [
                    GetPlatform.isAndroid
                        ? SliverToBoxAdapter(
                            child: Column(
                              children: [
                                if (!_isNotificationPermissionGranted)
                                  permissionWarning(
                                    isBatteryPermission: false,
                                    onTap: requestNotificationPermission,
                                    closeOnTap: () {
                                      setState(() {
                                        _isNotificationPermissionGranted = true;
                                      });
                                    },
                                  ),

                                if (!_isBatteryOptimizationGranted)
                                  permissionWarning(
                                    isBatteryPermission: true,
                                    onTap: requestBatteryOptimization,
                                    closeOnTap: () {
                                      setState(() {
                                        _isBatteryOptimizationGranted = true;
                                      });
                                    },
                                  ),
                              ],
                            ),
                          )
                        : const SliverToBoxAdapter(),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: Dimensions.paddingSizeDefault,
                          right: Dimensions.paddingSizeDefault,
                          top: GetPlatform.isAndroid
                              ? 0
                              : Dimensions.paddingSizeDefault,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: Dimensions.paddingSizeLarge),

                            profileController.modulePermission != null &&
                                    profileController.modulePermission!.wallet!
                                ? BusinessAnalyticsWidget(
                                    profileController: profileController,
                                  )
                                : const SizedBox(),
                            SizedBox(
                              height:
                                  profileController.modulePermission != null &&
                                      profileController
                                          .modulePermission!
                                          .wallet!
                                  ? Dimensions.paddingSizeExtraLarge
                                  : 0,
                            ),

                            // profileController.modulePermission != null &&
                            //         profileController
                            //             .modulePermission!
                            //             .advertisement!
                            //     ? const AdsSectionWidget()
                            //     : const SizedBox(),
                            const SizedBox(height: Dimensions.paddingSizeSmall),
                          ],
                        ),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeDefault,
                        ),
                        child: Column(
                          children: [
                            profileController.modulePermission != null
                                ? Get.find<ProfileController>()
                                          .modulePermission!
                                          .order!
                                      ? Column(
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'ongoing_orders'.tr,
                                                  style: robotoBold.copyWith(
                                                    fontSize: Dimensions
                                                        .fontSizeLarge,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            orderController.runningOrders !=
                                                    null
                                                ? SizedBox(
                                                    height: 40,
                                                    child: ListView.builder(
                                                      scrollDirection:
                                                          Axis.horizontal,
                                                      itemCount: orderController
                                                          .runningOrders!
                                                          .length,
                                                      itemBuilder: (context, index) {
                                                        return OrderButtonWidget(
                                                          title: orderController
                                                              .runningOrders![index]
                                                              .status
                                                              .tr,
                                                          index: index,
                                                          orderController:
                                                              orderController,
                                                          fromHistory: false,
                                                        );
                                                      },
                                                    ),
                                                  )
                                                : const SizedBox(),

                                            const SizedBox(
                                              height:
                                                  Dimensions.paddingSizeDefault,
                                            ),

                                            orderController.runningOrders !=
                                                    null
                                                ? orderList.isNotEmpty
                                                      ? ListView.builder(
                                                          physics:
                                                              const NeverScrollableScrollPhysics(),
                                                          shrinkWrap: true,
                                                          itemCount:
                                                              orderList.length,
                                                          itemBuilder: (context, index) {
                                                            return OrderWidget(
                                                              orderModel:
                                                                  orderList[index],
                                                              hasDivider:
                                                                  index !=
                                                                  orderList
                                                                          .length -
                                                                      1,
                                                              isRunning: true,
                                                            );
                                                          },
                                                        )
                                                      : Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                top: 50,
                                                                bottom: 100,
                                                              ),
                                                          child: Center(
                                                            child: Text(
                                                              'no_order_found'
                                                                  .tr,
                                                            ),
                                                          ),
                                                        )
                                                : ListView.builder(
                                                    physics:
                                                        const NeverScrollableScrollPhysics(),
                                                    shrinkWrap: true,
                                                    itemCount: 10,
                                                    itemBuilder: (context, index) {
                                                      return OrderShimmerWidget(
                                                        isEnabled:
                                                            orderController
                                                                .runningOrders ==
                                                            null,
                                                      );
                                                    },
                                                  ),
                                          ],
                                        )
                                      : Center(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 100,
                                            ),
                                            child: Text(
                                              'you_have_no_permission_to_access_this_feature'
                                                  .tr,
                                              style: robotoMedium,
                                            ),
                                          ),
                                        )
                                : ListView.builder(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: 10,
                                    itemBuilder: (context, index) {
                                      return OrderShimmerWidget(
                                        isEnabled:
                                            orderController.runningOrders ==
                                            null,
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget permissionWarning({
    required bool isBatteryPermission,
    required Function() onTap,
    required Function() closeOnTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).textTheme.bodyLarge!.color!.withValues(alpha: 0.7),
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
              child: Row(
                children: [
                  if (isBatteryPermission)
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.warning_rounded, color: Colors.yellow),
                    ),

                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            isBatteryPermission
                                ? 'for_better_performance_allow_notification_to_run_in_background'
                                      .tr
                                : 'notification_is_disabled_please_allow_notification'
                                      .tr,
                            maxLines: 2,
                            style: robotoRegular.copyWith(
                              fontSize: Dimensions.fontSizeSmall,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: Dimensions.paddingSizeSmall),
                        const Icon(
                          Icons.arrow_circle_right_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),
                ],
              ),
            ),

            Positioned(
              top: 5,
              right: 5,
              child: InkWell(
                onTap: closeOnTap,
                child: const Icon(Icons.clear, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
