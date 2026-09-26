import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ppdelistore/features/auth/controllers/auth_controller.dart';
import 'package:ppdelistore/features/dashboard/screens/dashboard_screen.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/features/notification/domain/models/notification_body_model.dart';
import 'package:ppdelistore/features/order/screens/order_details_screen.dart';
import 'package:ppdelistore/features/rental_module/chat/screens/taxi_chat_screen.dart';
import 'package:ppdelistore/features/rental_module/profile/controllers/taxi_profile_controller.dart';
import 'package:ppdelistore/features/rental_module/trips/screens/trip_details_screen.dart';
import 'package:ppdelistore/helper/route_helper.dart';
import 'package:ppdelistore/util/app_constants.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SplashScreen extends StatefulWidget {
  final NotificationBodyModel? body;
  const SplashScreen({super.key, required this.body});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  final GlobalKey<ScaffoldState> _globalKey = GlobalKey();
  StreamSubscription<List<ConnectivityResult>>? _onConnectivityChanged;

  @override
  void initState() {
    super.initState();

    bool firstTime = true;
    _onConnectivityChanged = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      bool isConnected =
          result.contains(ConnectivityResult.wifi) ||
          result.contains(ConnectivityResult.mobile);

      if (!firstTime) {
        isConnected
            ? ScaffoldMessenger.of(Get.context!).hideCurrentSnackBar()
            : const SizedBox();
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            backgroundColor: isConnected ? Colors.green : Colors.red,
            duration: Duration(seconds: isConnected ? 3 : 6000),
            content: Text(
              isConnected ? 'connected'.tr : 'no_connection'.tr,
              textAlign: TextAlign.center,
            ),
          ),
        );
        if (isConnected) {
          _route();
        }
      }

      firstTime = false;
    });

    Get.find<SplashController>().initSharedData();
    _route();
  }

  @override
  void dispose() {
    super.dispose();

    _onConnectivityChanged?.cancel();
  }

  void _route() {
    Get.find<SplashController>().getConfigData().then((isSuccess) async {
      if (isSuccess) {
        // PERFORMANCE FIX (startup):
        // Previously this method added a Timer(const Duration(seconds: 1))
        // before doing anything else — a full artificial 1-second freeze
        // while the splash logo was visible. Removed; every millisecond
        // counts on cold-start. Navigation now happens as soon as
        // getConfigData() resolves.
        double? minimumVersion = _getMinimumVersion();
        bool isMaintenanceMode =
            Get.find<SplashController>().configModel!.maintenanceMode!;
        bool needsUpdate = AppConstants.appVersion < minimumVersion!;

        if (needsUpdate || isMaintenanceMode) {
          Get.offNamed(RouteHelper.getUpdateRoute(needsUpdate));
        } else {
          if (widget.body != null) {
            await _handleNotificationRouting(widget.body);
          } else {
            await _handleDefaultRouting();
          }
        }
      }
    });
  }

  double? _getMinimumVersion() {
    if (GetPlatform.isAndroid) {
      return Get.find<SplashController>().configModel!.appMinimumVersionAndroid;
    } else if (GetPlatform.isIOS) {
      return Get.find<SplashController>().configModel!.appMinimumVersionIos;
    }
    return 0;
  }

  Future<void> _handleNotificationRouting(
    NotificationBodyModel? notificationBody,
  ) async {
    final notificationType = notificationBody?.notificationType;

    final Map<NotificationType, Function> notificationActions = {
      NotificationType.order: () {
        if (Get.find<AuthController>().getModuleType() == 'rental') {
          Get.to(
            () => TripDetailsScreen(
              tripId: notificationBody!.orderId!,
              fromNotification: true,
            ),
          );
        } else {
          // Pass an OrderDetailsScreen instance via Get.arguments so the
          // screen is built with `autoPrint: true` and `autoConfirm: true`.
          // The screen's `loadData` then (a) flips the order to `confirmed`
          // silently if it is still pending and (b) prints the invoice
          // once the order data is available — fulfilling the requirement
          // that opening a new-order notification auto-confirms and
          // auto-prints.
          Get.toNamed(
            RouteHelper.getOrderDetailsRoute(
              notificationBody?.orderId,
              fromNotification: true,
            ),
              arguments: OrderDetailsScreen(
              orderId: notificationBody!.orderId!,
              isRunningOrder: false,
              fromNotification: true,
              autoPrint: true,
              autoConfirm: true,
            ),
          );
        }
      },
      NotificationType.advertisement: () => Get.toNamed(
        RouteHelper.getAdvertisementDetailsScreen(
          advertisementId: notificationBody?.advertisementId,
          fromNotification: true,
        ),
      ),
      NotificationType.block: () =>
          Get.offAllNamed(RouteHelper.getSignInRoute()),
      NotificationType.unblock: () =>
          Get.offAllNamed(RouteHelper.getSignInRoute()),
      NotificationType.withdraw: () =>
          Get.to(const DashboardScreen(pageIndex: 3)),
      NotificationType.campaign: () => Get.toNamed(
        RouteHelper.getCampaignDetailsRoute(
          id: notificationBody?.campaignId,
          fromNotification: true,
        ),
      ),
      NotificationType.message: () {
        if (Get.find<AuthController>().getModuleType() == 'rental') {
          Get.to(
            () => TaxiChatScreen(
              notificationBody: notificationBody,
              conversationId: notificationBody?.conversationId,
              fromNotification: true,
            ),
          );
        } else {
          Get.toNamed(
            RouteHelper.getChatRoute(
              notificationBody: notificationBody,
              conversationId: notificationBody?.conversationId,
              fromNotification: true,
            ),
          );
        }
      },
      NotificationType.subscription: () => Get.toNamed(
        RouteHelper.getMySubscriptionRoute(fromNotification: true),
      ),
      NotificationType.product_approve: () =>
          Get.toNamed(RouteHelper.getNotificationRoute(fromNotification: true)),
      NotificationType.product_rejected: () =>
          Get.toNamed(RouteHelper.getPendingItemRoute(fromNotification: true)),
      NotificationType.general: () =>
          Get.toNamed(RouteHelper.getNotificationRoute(fromNotification: true)),
    };

    notificationActions[notificationType]?.call();
  }

  Future<void> _handleDefaultRouting() async {
    if (Get.find<AuthController>().isLoggedIn()) {
      await Get.find<AuthController>().updateToken();
      Get.find<AuthController>().getModuleType() == 'rental'
          ? await Get.find<TaxiProfileController>().getProfile()
          : await Get.find<ProfileController>().getProfile();
      Get.offNamed(RouteHelper.getInitialRoute());
    } else {
      // P2-1: app is English-only, language selection is unreachable.
      Get.offNamed(RouteHelper.getSignInRoute());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _globalKey,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(Images.logo, width: 200),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Text(
                'suffix_name'.tr,
                style: robotoMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
