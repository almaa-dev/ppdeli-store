import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/features/auth/controllers/auth_controller.dart';
import 'package:ppdelistore/features/order/controllers/order_controller.dart';
import 'package:ppdelistore/features/order/screens/order_details_screen.dart';
import 'package:ppdelistore/features/rental_module/trips/screens/trip_details_screen.dart';
import 'package:ppdelistore/helper/route_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:ppdelistore/common/widgets/custom_button_widget.dart';

class NewRequestDialogWidget extends StatefulWidget {
  final int orderId;

  const NewRequestDialogWidget({super.key, required this.orderId});

  @override
  State<NewRequestDialogWidget> createState() => _NewRequestDialogWidgetState();
}

class _NewRequestDialogWidgetState extends State<NewRequestDialogWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _startAlarm();
    // Ensure the dialog opens immediately (no animation delay) and navigation
    // after tap is immediate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAlarm() async {
    AudioPlayer audio = AudioPlayer();
    audio.play(AssetSource('notification.mp3'));
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      audio.play(AssetSource('notification.mp3'));
    });
  }

  /// User tapped the giant "Confirm Order" button.
  ///
  /// 1. Stop the alarm immediately.
  /// 2. Close the dialog immediately so the user feels the action is instant.
  /// 3. Fire the `updateOrderStatus('confirmed')` call silently in the
  ///    background; the navigation happens before the API replies to keep
  ///    the experience immediate (per the user's request).
  /// 4. Navigate to the order details screen with `autoConfirm: true` and
  ///    `autoPrint: true` so the invoice is printed automatically once the
  ///    order data is loaded.
  void _confirmAndNavigate() {
    // Cancel the alarm immediately for a snappy feel.
    _timer?.cancel();

    final bool isRental =
        Get.find<AuthController>().getModuleType() == 'rental';

    // Close the dialog right away.
    if (Get.isDialogOpen!) {
      Get.back();
    }

    // Kick off the status update silently. We do not await it because the
    // user wants an immediate response — the network call will complete in
    // the background while the order details screen is opening.
    final OrderController orderController = Get.find<OrderController>();
    // `silent: true` suppresses the success / failure snackbar so it does
    // not interrupt the navigation flow.
    unawaited(
      orderController.updateOrderStatus(
        widget.orderId,
        'confirmed',
        silent: true,
      ),
    );

    // Navigate immediately with no extra delay. The OrderDetailsScreen
    // is built with `autoPrint: true` so that the invoice is printed
    // automatically as soon as the order data is fetched.
    if (isRental) {
      Get.offAll(
        () => TripDetailsScreen(tripId: widget.orderId, fromNotification: true),
      );
    } else {
      Get.offAllNamed(
        RouteHelper.getOrderDetailsRoute(
          widget.orderId,
          fromNotification: true,
        ),
        arguments: OrderDetailsScreen(
          orderId: widget.orderId,
          isRunningOrder: false,
          fromNotification: true,
          autoPrint: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isRental =
        Get.find<AuthController>().getModuleType() == 'rental';

    // Use a much taller container with red background to match the design.
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeLarge,
        vertical: Dimensions.paddingSizeExtraLarge,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.72,
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B3B),
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top: Icon at the top of the dialog.
            Padding(
              padding: const EdgeInsets.only(
                top: Dimensions.paddingSizeExtraLarge,
              ),
              child: Container(
                height: 96,
                width: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                  child: Image.asset(
                    Images.notificationIn,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Middle: Big white confirmation text.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeLarge,
                  vertical: Dimensions.paddingSizeDefault,
                ),
                child: Center(
                  child: Text(
                    isRental ? 'new_trip_booked'.tr : 'new_order_placed'.tr,
                    textAlign: TextAlign.center,
                    style: robotoBold.copyWith(
                      color: Colors.white,
                      fontSize: Dimensions.fontSizeOverLarge * 1.6,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),

            // Bottom: Big "Confirm Order" button.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Dimensions.paddingSizeLarge,
                0,
                Dimensions.paddingSizeLarge,
                Dimensions.paddingSizeExtraLarge,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 64,
                child: CustomButtonWidget(
                  height: 64,
                  buttonText: 'confirm_order'.tr,
                  color: Colors.white,
                  textColor: const Color(0xFFFF3B3B),
                  fontSize: Dimensions.fontSizeOverLarge,
                  radius: Dimensions.radiusDefault,
                  onPressed: _confirmAndNavigate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
