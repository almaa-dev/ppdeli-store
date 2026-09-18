import 'dart:async';
import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:ppdelistore/features/printer/helper/printer_helper.dart';
import 'package:ppdelistore/features/printer/presentation/printer_controller.dart';
import 'package:ppdelistore/features/printer/domain/models/printer_model.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:ppdelistore/features/language/controllers/language_controller.dart';
import 'package:ppdelistore/features/order/controllers/order_controller.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/features/notification/domain/models/notification_body_model.dart';
import 'package:ppdelistore/features/chat/domain/models/conversation_model.dart';
import 'package:ppdelistore/features/order/domain/models/order_details_model.dart';
import 'package:ppdelistore/features/order/domain/models/order_model.dart';
import 'package:ppdelistore/helper/date_converter_helper.dart';
import 'package:ppdelistore/helper/price_converter_helper.dart';
import 'package:ppdelistore/helper/route_helper.dart';
import 'package:ppdelistore/util/app_constants.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:ppdelistore/common/widgets/confirmation_dialog_widget.dart';
import 'package:ppdelistore/common/widgets/custom_app_bar_widget.dart';
import 'package:ppdelistore/common/widgets/custom_button_widget.dart';
import 'package:ppdelistore/common/widgets/custom_image_widget.dart';
import 'package:ppdelistore/common/widgets/custom_snackbar_widget.dart';
import 'package:ppdelistore/features/order/screens/invoice_print_screen.dart';
import 'package:ppdelistore/features/order/widgets/amount_input_dialogue_widget.dart';
import 'package:ppdelistore/features/order/widgets/camera_button_sheet_widget.dart';
import 'package:ppdelistore/features/order/widgets/cancellation_dialogue_widget.dart';
import 'package:ppdelistore/features/order/widgets/collect_money_delivery_sheet_widget.dart';
import 'package:ppdelistore/features/order/widgets/dialogue_image_widget.dart';
import 'package:ppdelistore/features/order/widgets/order_item_widget.dart';
import 'package:ppdelistore/features/order/widgets/slider_button_widget.dart';
import 'package:ppdelistore/features/order/widgets/verify_delivery_sheet_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

class OrderDetailsScreen extends StatefulWidget {
  final int orderId;
  final bool isRunningOrder;
  final bool fromNotification;
  final bool autoPrint;
  final bool autoConfirm;
  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.isRunningOrder,
    this.fromNotification = false,
    this.autoPrint = false,
    this.autoConfirm = false,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool selfDelivery = false;
  bool _isExpanded = true;
  bool _isViewMore = false;

  Future<void> loadData() async {
    if (Get.find<ProfileController>().profileModel == null) {
      Get.find<ProfileController>().getProfile();
    }
    Get.find<OrderController>().pickPrescriptionImage(
      isRemove: true,
      isCamera: false,
    );
    await Get.find<OrderController>().getOrderDetails(widget.orderId);

    ///order

    await Get.find<OrderController>().getOrderItemsDetails(widget.orderId);

    ///order details

    if (Get.find<OrderController>().showDeliveryImageField) {
      Get.find<OrderController>().changeDeliveryImageStatus(isUpdate: false);
    }

    // If the screen was opened from the "Confirm Order" notification dialog
    // (`autoConfirm: true`), fire a silent `updateOrderStatus` only if the
    // order is still in the `pending` state. The [OrderController]
    // call started by the dialog itself may not have completed by the time
    // we load the order, so this acts as a defensive fallback that keeps
    // the order in the `confirmed` state without showing any snackbar.
    if (widget.autoConfirm &&
        Get.find<OrderController>().orderModel != null &&
        Get.find<OrderController>().orderModel!.orderStatus == 'pending') {
      unawaited(
        Get.find<OrderController>().updateOrderStatus(
          widget.orderId,
          AppConstants.confirmed,
          silent: true,
        ),
      );
    }

    // If the screen was opened from the "Confirm Order" dialog, kick off
    // an automatic print of the invoice after the data is loaded.
    if (widget.autoPrint) {
      // Run after the current frame so the UI has time to render and the
      // [OrderController] has emitted a `GetBuilder` update.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _autoPrintInvoice();
      });
    }

    _startApiCalling();
  }

  /// Builds and prints the invoice using native ESC/POS commands.
  ///
  /// **No screenshot, no PNG, no image decode/rasterise.** The
  /// [PrinterHelper.buildInvoiceBytes] builder walks the live
  /// [OrderModel] / [OrderDetailsModel] structures and emits
  /// plain-text ESC/POS bytes. The result is a tiny byte stream
  /// (~3-6 KB instead of ~150-600 KB) that prints much faster on
  /// the Bluetooth link.
  ///
  /// Designed to be triggered immediately after the order details
  /// are loaded so the receipt is printed with no further user
  /// interaction.
  Future<void> _autoPrintInvoice() async {
    try {
      final OrderController orderController = Get.find<OrderController>();
      if (orderController.orderModel == null ||
          orderController.orderDetailsModel == null) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (orderController.orderModel == null ||
            orderController.orderDetailsModel == null) {
          return;
        }
      }

      final PrinterController printerController = Get.find<PrinterController>();
      await printerController.printInvoice(
        ticketBuilder: (PrinterModel p) => PrinterHelper.buildInvoiceBytes(
          order: orderController.orderModel,
          orderDetails: orderController.orderDetailsModel,
          isPrescriptionOrder:
              orderController.orderModel?.prescriptionOrder ?? false,
          dmTips: orderController.orderModel!.dmTips ?? 0,
          paperSize: p.printerType,
          printer: p,
          // Surface the configurable Additional Charge label so the
          // printed totals block matches the on-screen preview.
          additionalChargeName:
              Get.find<SplashController>().configModel?.additionalChargeName,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('auto-print failed: $e');
      }
    }
  }

  /// Starts a periodic refresh of the order details.
  void _startApiCalling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      Get.find<OrderController>().getOrderDetails(widget.orderId);
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    Get.find<OrderController>().clearPreviousData();
    loadData();
  }

  @override
  void didChangeAppLifecycleState(final AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startApiCalling();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    super.dispose();

    WidgetsBinding.instance.removeObserver(this);

    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    bool? cancelPermission =
        Get.find<SplashController>().configModel!.canceledByStore;

    if (Get.find<ProfileController>().profileModel != null) {
      selfDelivery =
          Get.find<ProfileController>()
              .profileModel!
              .stores![0]
              .selfDeliverySystem ==
          1;
    }

    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) async {
        if (widget.fromNotification && !didPop) {
          Get.offAllNamed(RouteHelper.getInitialRoute());
        } else {
          return;
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).cardColor,
        appBar: CustomAppBarWidget(
          titleWidget: GetBuilder<OrderController>(
            builder: (controller) {
              if (controller.orderModel == null) {
                return const SizedBox(height: 20);
              }
              return Column(
                children: [
                  Text(
                    "${'order'.tr} #${controller.orderModel!.id.toString().tr}",
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                  Text(
                    "${"order_is".tr}  ${controller.orderModel!.orderStatus! == 'picked_up' ? 'on_the_way'.tr : controller.orderModel!.orderStatus!.tr}",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              );
            },
          ),
          menuWidget: Platform.isAndroid
              ? GetBuilder<OrderController>(
                  builder: (controller) {
                    return GestureDetector(
                      onTap: () {
                        _allowPermission().then((access) {
                          Get.dialog(
                            Dialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusSmall,
                                ),
                              ),
                              child: InVoicePrintScreen(
                                order: controller.orderModel,
                                orderDetails: controller.orderDetailsModel,
                                isPrescriptionOrder:
                                    controller.orderModel?.prescriptionOrder,
                                dmTips: controller.orderModel!.dmTips!,
                              ),
                            ),
                          );
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.asset(Images.downloadIcon),
                      ),
                    );
                  },
                )
              : null,
          onTap: () {
            if (widget.fromNotification) {
              Get.offAllNamed(RouteHelper.getInitialRoute());
            } else {
              Get.back();
            }
          },
        ),
        body: SafeArea(
          child: GetBuilder<OrderController>(
            builder: (orderController) {
              OrderModel? controllerOrderModel = orderController.orderModel;
              bool restConfModel =
                  Get.find<SplashController>()
                      .configModel!
                      .orderConfirmationModel !=
                  'deliveryman';
              bool showSlider = controllerOrderModel != null
                  ? (controllerOrderModel.orderStatus == 'pending' &&
                            (controllerOrderModel.orderType == 'take_away' ||
                                restConfModel ||
                                selfDelivery)) ||
                        controllerOrderModel.orderStatus == 'confirmed' ||
                        controllerOrderModel.orderStatus == 'processing' ||
                        (controllerOrderModel.orderStatus == 'accepted' &&
                            controllerOrderModel.confirmed != null) ||
                        // Show the slider for every order in the
                        // "ready for handover" state, regardless of
                        // `orderType` (delivery, pickup/take_away or
                        // self-delivery). This allows the vendor to
                        // swipe-to-deliver the order in all cases.
                        controllerOrderModel.orderStatus == 'handover'
                  : false;
              bool showBottomView = controllerOrderModel != null
                  ? showSlider ||
                        controllerOrderModel.orderStatus == 'picked_up' ||
                        widget.isRunningOrder
                  : false;
              bool showDeliveryConfirmImage =
                  orderController.showDeliveryImageField;
              if (kDebugMode) {
                debugPrint(
                  'Delivery man number => ${orderController.orderModel?.toJson()}',
                );
              }

              double? deliveryCharge = 0;
              double itemsPrice = 0;
              double? discount = 0;
              double? couponDiscount = 0;
              double? tax = 0;
              double addOns = 0;
              double? dmTips = 0;
              double additionalCharge = 0;
              double extraPackagingAmount = 0;
              double referrerBonusAmount = 0;
              bool? isPrescriptionOrder = false;
              bool? taxIncluded = false;
              OrderModel? order = controllerOrderModel;
              if (order != null && orderController.orderDetailsModel != null) {
                if (order.orderType == 'delivery') {
                  deliveryCharge = order.deliveryCharge;
                  dmTips = order.dmTips;
                  isPrescriptionOrder = order.prescriptionOrder;
                }
                discount =
                    order.storeDiscountAmount! +
                    order.flashAdminDiscountAmount! +
                    order.flashStoreDiscountAmount!;
                tax = order.totalTaxAmount;
                taxIncluded = order.taxStatus;
                additionalCharge = order.additionalCharge!;
                extraPackagingAmount = order.extraPackagingAmount!;
                referrerBonusAmount = order.referrerBonusAmount!;
                couponDiscount = order.couponDiscountAmount;
                if (isPrescriptionOrder!) {
                  double orderAmount = order.orderAmount ?? 0;
                  itemsPrice =
                      (orderAmount + discount) -
                      ((taxIncluded! ? 0 : tax!) +
                          deliveryCharge! +
                          additionalCharge) -
                      dmTips!;
                } else {
                  for (OrderDetailsModel orderDetails
                      in orderController.orderDetailsModel!) {
                    for (AddOn addOn in orderDetails.addOns!) {
                      addOns = addOns + (addOn.price! * addOn.quantity!);
                    }
                    itemsPrice =
                        itemsPrice +
                        (orderDetails.price! * orderDetails.quantity!);
                  }
                }
              }
              double subTotal = itemsPrice + addOns;
              double total =
                  itemsPrice +
                  addOns -
                  discount +
                  (taxIncluded! ? 0 : tax!) +
                  deliveryCharge! -
                  couponDiscount! +
                  dmTips! +
                  additionalCharge +
                  extraPackagingAmount -
                  referrerBonusAmount;

              return (orderController.orderDetailsModel != null &&
                      controllerOrderModel != null)
                  ? Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(
                              bottom: Dimensions.paddingSizeSmall,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 1170,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      height: Dimensions.paddingSizeExtraSmall,
                                    ),

                                    /// general_info
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal:
                                            Dimensions.paddingSizeDefault,
                                        vertical: Dimensions.paddingSizeSmall,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(
                                          Dimensions.radiusSmall,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            offset: Offset(0, 3),
                                            color:
                                                Colors.grey[Get.isDarkMode
                                                    ? 700
                                                    : 200]!,
                                            blurRadius: 8,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'general_info'.tr,
                                            style: robotoBold,
                                          ),
                                          Divider(
                                            thickness: 1,
                                            color: Theme.of(
                                              context,
                                            ).hintColor.withValues(alpha: 0.1),
                                          ),

                                          /// Order date
                                          Row(
                                            children: [
                                              Text(
                                                '${'order_date'.tr}:',
                                                style: robotoRegular.copyWith(
                                                  color: Theme.of(
                                                    context,
                                                  ).hintColor,
                                                ),
                                              ),
                                              Spacer(),
                                              Icon(
                                                Icons.access_time,
                                                size: 18,
                                                color: Theme.of(
                                                  context,
                                                ).disabledColor,
                                              ),
                                              Text(
                                                ' ${DateConverterHelper.dateTimeStringToDateTime(order!.createdAt!)}',
                                                style: robotoRegular,
                                              ),
                                            ],
                                          ),

                                          /// Scheduled
                                          order.scheduled == 1
                                              ? Divider(
                                                  thickness: 1,
                                                  color: Theme.of(context)
                                                      .hintColor
                                                      .withValues(alpha: 0.1),
                                                )
                                              : SizedBox.shrink(),
                                          order.scheduled == 1
                                              ? Row(
                                                  children: [
                                                    Text(
                                                      '${'scheduled_at'.tr}:',
                                                      style: robotoRegular
                                                          .copyWith(
                                                            color: Theme.of(
                                                              context,
                                                            ).hintColor,
                                                          ),
                                                    ),
                                                    Spacer(),
                                                    Icon(
                                                      Icons.access_time,
                                                      size: 18,
                                                      color: Theme.of(
                                                        context,
                                                      ).disabledColor,
                                                    ),
                                                    Text(
                                                      ' ${DateConverterHelper.dateTimeStringToDateTime(order.scheduleAt!)}',
                                                      style: robotoRegular,
                                                    ),
                                                  ],
                                                )
                                              : SizedBox.shrink(),

                                          /// scheduled_at
                                          // order.scheduled == 1 ? Row(children: [
                                          //   Text('${'scheduled_at'.tr}:', style: robotoRegular),
                                          //   const SizedBox(width: Dimensions.paddingSizeExtraSmall),
                                          //   Text(DateConverterHelper.dateTimeStringToDateTime(order.scheduleAt!), style: robotoMedium),
                                          // ]) : const SizedBox(),

                                          /// orderType
                                          Divider(
                                            thickness: 1,
                                            color: Theme.of(
                                              context,
                                            ).hintColor.withValues(alpha: 0.1),
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                '${'order_type'.tr}:',
                                                style: robotoRegular.copyWith(
                                                  color: Theme.of(
                                                    context,
                                                  ).hintColor,
                                                ),
                                              ),
                                              Spacer(),
                                              Text(
                                                order.orderType == 'delivery'
                                                    ? 'home_delivery'.tr
                                                    : order.orderType!.tr,
                                                style: robotoMedium.copyWith(
                                                  color: Colors.blueAccent,
                                                ),
                                              ),
                                            ],
                                          ),

                                          /// Cooking time
                                          // controllerOrderModel.orderStatus == 'processing' ? Column(children: [
                                          //   Divider(thickness: 1, color: Theme.of(context).hintColor.withValues(alpha: 0.1)),
                                          //   Row(children: [
                                          //     Text('${'cooking_time'.tr}:', style: robotoRegular.copyWith(color: Theme.of(context).hintColor)),
                                          //     Spacer(),
                                          //     Text(
                                          //       '${order.processingTime} ${'mins'.tr}',
                                          //       style: robotoMedium.copyWith(color: Colors.blueAccent),
                                          //     ),
                                          //   ])
                                          // ]) : SizedBox.shrink(),

                                          /// cutlery
                                          Get.find<SplashController>()
                                                  .getModuleConfig(
                                                    order.moduleType,
                                                  )
                                                  .newVariation!
                                              ? Column(
                                                  children: [
                                                    Divider(
                                                      thickness: 1,
                                                      color: Theme.of(context)
                                                          .hintColor
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                    ),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          '${'cutlery'.tr}: ',
                                                          style: robotoRegular
                                                              .copyWith(
                                                                color: Theme.of(
                                                                  context,
                                                                ).hintColor,
                                                              ),
                                                        ),
                                                        Spacer(),
                                                        Text(
                                                          order.cutlery!
                                                              ? 'yes'.tr
                                                              : 'no'.tr,
                                                          style: robotoRegular,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                )
                                              : const SizedBox(),

                                          /// orderNote
                                          SizedBox(
                                            height: Dimensions.paddingSizeSmall,
                                          ),
                                          if (order.orderNote != null &&
                                              order.orderNote!.isNotEmpty)
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(
                                                Dimensions.paddingSizeSmall,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      Dimensions.radiusSmall,
                                                    ),
                                                color: Theme.of(context)
                                                    .hintColor
                                                    .withValues(alpha: 0.06),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'additional_note'.tr,
                                                    style: robotoMedium,
                                                  ),
                                                  SizedBox(
                                                    height: Dimensions
                                                        .paddingSizeExtraSmall,
                                                  ),
                                                  Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.all(
                                                          Dimensions
                                                              .paddingSizeSmall,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            Dimensions
                                                                .radiusSmall,
                                                          ),
                                                      color: Theme.of(
                                                        context,
                                                      ).cardColor,
                                                    ),
                                                    child: Text(
                                                      order.orderNote!,
                                                      style: robotoRegular,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                          /// unavailableItemNote
                                          (order.unavailableItemNote != null &&
                                                  order
                                                      .unavailableItemNote!
                                                      .isNotEmpty)
                                              ? SizedBox(
                                                  height: Dimensions
                                                      .paddingSizeSmall,
                                                )
                                              : SizedBox.shrink(),
                                          if (order.unavailableItemNote !=
                                                  null &&
                                              order
                                                  .unavailableItemNote!
                                                  .isNotEmpty)
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(
                                                Dimensions.paddingSizeSmall,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      Dimensions.radiusSmall,
                                                    ),
                                                color: Theme.of(context)
                                                    .hintColor
                                                    .withValues(alpha: 0.06),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'unavailable_item_note'.tr,
                                                    style: robotoMedium,
                                                  ),
                                                  SizedBox(
                                                    height: Dimensions
                                                        .paddingSizeExtraSmall,
                                                  ),
                                                  Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.all(
                                                          Dimensions
                                                              .paddingSizeSmall,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            Dimensions
                                                                .radiusSmall,
                                                          ),
                                                      color: Theme.of(
                                                        context,
                                                      ).cardColor,
                                                    ),
                                                    child: Text(
                                                      order
                                                          .unavailableItemNote!,
                                                      style: robotoRegular
                                                          .copyWith(
                                                            color:
                                                                Colors.orange,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                          /// deliveryInstruction
                                          (order.deliveryInstruction != null &&
                                                  order
                                                      .deliveryInstruction!
                                                      .isNotEmpty)
                                              ? SizedBox(
                                                  height: Dimensions
                                                      .paddingSizeSmall,
                                                )
                                              : SizedBox.shrink(),
                                          if (order.deliveryInstruction !=
                                                  null &&
                                              order
                                                  .deliveryInstruction!
                                                  .isNotEmpty)
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(
                                                Dimensions.paddingSizeSmall,
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      Dimensions.radiusSmall,
                                                    ),
                                                color: Theme.of(context)
                                                    .hintColor
                                                    .withValues(alpha: 0.06),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'delivery_instruction'.tr,
                                                    style: robotoMedium,
                                                  ),
                                                  SizedBox(
                                                    height: Dimensions
                                                        .paddingSizeExtraSmall,
                                                  ),
                                                  Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.all(
                                                          Dimensions
                                                              .paddingSizeSmall,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            Dimensions
                                                                .radiusSmall,
                                                          ),
                                                      color: Theme.of(
                                                        context,
                                                      ).cardColor,
                                                    ),
                                                    child: Text(
                                                      '${order.deliveryInstruction}'
                                                          .tr,
                                                      style: robotoRegular,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(
                                      height: Dimensions.paddingSizeDefault,
                                    ),

                                    /// Item info
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal:
                                            Dimensions.paddingSizeDefault,
                                        vertical: Dimensions.paddingSizeSmall,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(
                                          Dimensions.radiusSmall,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            offset: Offset(0, 3),
                                            color:
                                                Colors.grey[Get.isDarkMode
                                                    ? 700
                                                    : 300]!,
                                            blurRadius: 8,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'item_info'.tr,
                                                style: robotoBold,
                                              ),
                                              const SizedBox(
                                                width: Dimensions
                                                    .paddingSizeExtraSmall,
                                              ),
                                              Container(
                                                width: Dimensions
                                                    .paddingSizeExtremeLarge,
                                                height: Dimensions
                                                    .paddingSizeExtremeLarge,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        Dimensions.radiusLarge,
                                                      ),
                                                  color: Theme.of(context)
                                                      .hintColor
                                                      .withValues(alpha: 0.2),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    orderController
                                                        .orderDetailsModel!
                                                        .length
                                                        .toString(),
                                                    style: robotoMedium,
                                                  ),
                                                ),
                                              ),
                                              Spacer(),
                                              IconButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _isExpanded = !_isExpanded;
                                                  });
                                                },
                                                icon: Icon(
                                                  _isExpanded
                                                      ? Icons.keyboard_arrow_up
                                                      : Icons
                                                            .keyboard_arrow_down,
                                                  color: Theme.of(
                                                    context,
                                                  ).primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (_isExpanded)
                                            Column(
                                              children: [
                                                Divider(
                                                  thickness: 1,
                                                  color: Theme.of(context)
                                                      .hintColor
                                                      .withValues(alpha: 0.1),
                                                ),
                                                ListView.builder(
                                                  shrinkWrap: true,
                                                  physics:
                                                      const NeverScrollableScrollPhysics(),
                                                  itemCount: orderController
                                                      .orderDetailsModel!
                                                      .length,
                                                  itemBuilder: (context, index) {
                                                    return Column(
                                                      children: [
                                                        OrderItemWidget(
                                                          order: order,
                                                          orderDetails:
                                                              orderController
                                                                  .orderDetailsModel![index],
                                                        ),
                                                        if (orderController
                                                                    .orderDetailsModel!
                                                                    .length >
                                                                1 &&
                                                            index <
                                                                orderController
                                                                        .orderDetailsModel!
                                                                        .length -
                                                                    1)
                                                          Divider(
                                                            thickness: 1,
                                                            height: 30,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    ).hintColor
                                                                    .withValues(
                                                                      alpha:
                                                                          0.1,
                                                                    ),
                                                          ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),

                                    /// Delivery Info
                                    if (order.deliveryAddress != null ||
                                        (order
                                                .deliveryInstruction!
                                                .isNotEmpty ||
                                            order.deliveryInstruction !=
                                                null)) ...[
                                      const SizedBox(
                                        height: Dimensions.paddingSizeDefault,
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal:
                                              Dimensions.paddingSizeDefault,
                                          vertical: Dimensions.paddingSizeSmall,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusSmall,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              offset: Offset(0, 3),
                                              color:
                                                  Colors.grey[Get.isDarkMode
                                                      ? 700
                                                      : 300]!,
                                              blurRadius: 8,
                                              spreadRadius: 0,
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'delivery_information'.tr,
                                              style: robotoBold,
                                            ),
                                            Divider(
                                              thickness: 1,
                                              color: Theme.of(context).hintColor
                                                  .withValues(alpha: 0.1),
                                            ),
                                            if (order
                                                    .deliveryAddress!
                                                    .contactPersonName !=
                                                null) ...[
                                              Row(
                                                children: [
                                                  Image.asset(
                                                    Images.userIcon,
                                                    width: 14,
                                                    height: 14,
                                                  ),
                                                  SizedBox(
                                                    width: Dimensions
                                                        .paddingSizeSmall,
                                                  ),
                                                  Text(
                                                    order
                                                        .deliveryAddress!
                                                        .contactPersonName!,
                                                    style: robotoMedium
                                                        .copyWith(
                                                          fontSize: Dimensions
                                                              .fontSizeSmall,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(
                                                height: Dimensions
                                                    .paddingSizeExtraSmall,
                                              ),
                                            ],

                                            if (order
                                                    .deliveryAddress!
                                                    .contactPersonNumber !=
                                                null) ...[
                                              Row(
                                                children: [
                                                  Image.asset(
                                                    Images.phoneFlip,
                                                    width: 14,
                                                    height: 14,
                                                  ),
                                                  SizedBox(
                                                    width: Dimensions
                                                        .paddingSizeSmall,
                                                  ),
                                                  Text(
                                                    order
                                                        .deliveryAddress!
                                                        .contactPersonNumber!,
                                                    style: robotoMedium
                                                        .copyWith(
                                                          color: Theme.of(
                                                            context,
                                                          ).hintColor,
                                                          fontSize: Dimensions
                                                              .fontSizeSmall,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(
                                                height: Dimensions
                                                    .paddingSizeExtraSmall,
                                              ),
                                            ],

                                            if (order
                                                    .deliveryAddress
                                                    ?.address !=
                                                null)
                                              Row(
                                                children: [
                                                  Image.asset(
                                                    Images.markerIcon,
                                                    width: 12,
                                                    height: 12,
                                                  ),
                                                  SizedBox(
                                                    width: Dimensions
                                                        .paddingSizeSmall,
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      order
                                                          .deliveryAddress!
                                                          .address!,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: robotoMedium
                                                          .copyWith(
                                                            color: Theme.of(
                                                              context,
                                                            ).hintColor,
                                                            fontSize: Dimensions
                                                                .fontSizeSmall,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),

                                            if (_isViewMore) ...[
                                              SizedBox(
                                                height: Dimensions
                                                    .paddingSizeExtraSmall,
                                              ),

                                              if (order
                                                          .deliveryAddress!
                                                          .streetNumber !=
                                                      null &&
                                                  order
                                                      .deliveryAddress!
                                                      .streetNumber!
                                                      .isNotEmpty) ...[
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.signpost,
                                                      size: 14,
                                                      color: Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                    ),
                                                    SizedBox(
                                                      width: Dimensions
                                                          .paddingSizeSmall,
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        '${'street_number'.tr}: ${order.deliveryAddress!.streetNumber!}',
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: robotoMedium
                                                            .copyWith(
                                                              color: Theme.of(
                                                                context,
                                                              ).hintColor,
                                                              fontSize: Dimensions
                                                                  .fontSizeSmall,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(
                                                  height: Dimensions
                                                      .paddingSizeExtraSmall,
                                                ),
                                              ],

                                              if (order
                                                          .deliveryAddress!
                                                          .house !=
                                                      null &&
                                                  order
                                                      .deliveryAddress!
                                                      .house!
                                                      .isNotEmpty) ...[
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.home_outlined,
                                                      size: 14,
                                                      color: Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                    ),
                                                    SizedBox(
                                                      width: Dimensions
                                                          .paddingSizeSmall,
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        '${'house'.tr}: ${order.deliveryAddress!.house!}',
                                                        maxLines: 2,
                                                        overflow:
                                                            TextOverflow.clip,
                                                        style: robotoMedium
                                                            .copyWith(
                                                              color: Theme.of(
                                                                context,
                                                              ).hintColor,
                                                              fontSize: Dimensions
                                                                  .fontSizeSmall,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(
                                                  height: Dimensions
                                                      .paddingSizeExtraSmall,
                                                ),
                                              ],

                                              if (order
                                                          .deliveryAddress!
                                                          .floor !=
                                                      null &&
                                                  order
                                                      .deliveryAddress!
                                                      .floor!
                                                      .isNotEmpty) ...[
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.stairs,
                                                      size: 14,
                                                      color: Theme.of(
                                                        context,
                                                      ).primaryColor,
                                                    ),
                                                    SizedBox(
                                                      width: Dimensions
                                                          .paddingSizeSmall,
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        '${'floor'.tr}: ${order.deliveryAddress!.floor!}',
                                                        maxLines: 2,
                                                        overflow:
                                                            TextOverflow.clip,
                                                        style: robotoMedium
                                                            .copyWith(
                                                              color: Theme.of(
                                                                context,
                                                              ).hintColor,
                                                              fontSize: Dimensions
                                                                  .fontSizeSmall,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],

                                            // View More Toggle Button
                                            ((order
                                                                .deliveryAddress!
                                                                .streetNumber !=
                                                            null &&
                                                        order
                                                            .deliveryAddress!
                                                            .streetNumber!
                                                            .isNotEmpty) ||
                                                    (order
                                                                .deliveryAddress!
                                                                .house !=
                                                            null &&
                                                        order
                                                            .deliveryAddress!
                                                            .house!
                                                            .isNotEmpty) ||
                                                    (order
                                                                .deliveryAddress!
                                                                .floor !=
                                                            null &&
                                                        order
                                                            .deliveryAddress!
                                                            .floor!
                                                            .isNotEmpty))
                                                ? InkWell(
                                                    onTap: () => setState(
                                                      () => _isViewMore =
                                                          !_isViewMore,
                                                    ),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: Dimensions
                                                                .paddingSizeExtraSmall,
                                                          ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Text(
                                                            _isViewMore
                                                                ? 'view_less'.tr
                                                                : 'view_more'
                                                                      .tr,
                                                            style: robotoMedium.copyWith(
                                                              color: Theme.of(
                                                                context,
                                                              ).primaryColor,
                                                              fontSize: Dimensions
                                                                  .fontSizeSmall,
                                                            ),
                                                          ),
                                                          Icon(
                                                            _isViewMore
                                                                ? Icons
                                                                      .keyboard_arrow_up
                                                                : Icons
                                                                      .keyboard_arrow_down,
                                                            size: 18,
                                                            color: Theme.of(
                                                              context,
                                                            ).primaryColor,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                : SizedBox.shrink(),

                                            // if (_isExpanded)
                                            //   Wrap(children: [
                                            //       (order.deliveryAddress!.streetNumber != null && order.deliveryAddress!.streetNumber!.isNotEmpty) ? Text('${'street_number'.tr}: {order.deliveryAddress!.streetNumber!}, ',
                                            //         style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).disabledColor), maxLines: 1, overflow: TextOverflow.ellipsis,
                                            //       ) : const SizedBox(),
                                            //
                                            //       (order.deliveryAddress!.house != null && order.deliveryAddress!.house!.isNotEmpty) ? Text('${'house'.tr}: ${order.deliveryAddress!.house!}, ',
                                            //         style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).disabledColor), maxLines: 1, overflow: TextOverflow.ellipsis,
                                            //       ) : const SizedBox(),
                                            //
                                            //       (order.deliveryAddress!.floor != null && order.deliveryAddress!.floor!.isNotEmpty) ? Text('${'floor'.tr}: ${order.deliveryAddress!.floor!}' ,
                                            //         style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).disabledColor), maxLines: 1, overflow: TextOverflow.ellipsis,
                                            //       ) : const SizedBox(),
                                            //     ]),
                                          ],
                                        ),
                                      ),
                                    ],

                                    ///Customer info
                                    if (order.deliveryAddress != null) ...[
                                      const SizedBox(
                                        height: Dimensions.paddingSizeDefault,
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal:
                                              Dimensions.paddingSizeDefault,
                                          vertical: Dimensions.paddingSizeSmall,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusSmall,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              offset: Offset(0, 3),
                                              color:
                                                  Colors.grey[Get.isDarkMode
                                                      ? 700
                                                      : 200]!,
                                              blurRadius: 8,
                                              spreadRadius: 0,
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'customer_details'.tr,
                                              style: robotoBold,
                                            ),
                                            Divider(
                                              thickness: 1,
                                              color: Theme.of(context).hintColor
                                                  .withValues(alpha: 0.1),
                                            ),
                                            Row(
                                              children: [
                                                ClipOval(
                                                  child: CustomImageWidget(
                                                    image:
                                                        '${order.customer != null ? order.customer!.imageFullUrl : ''}',
                                                    height: 55,
                                                    width: 55,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: Dimensions
                                                      .paddingSizeSmall,
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        order
                                                            .deliveryAddress!
                                                            .contactPersonName!,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: robotoMedium,
                                                      ),
                                                      Text(
                                                        order
                                                                .deliveryAddress!
                                                                .address ??
                                                            '',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: robotoRegular
                                                            .copyWith(
                                                              color: Theme.of(
                                                                context,
                                                              ).hintColor,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                (order.orderType ==
                                                            'take_away' &&
                                                        (order.orderStatus ==
                                                                'pending' ||
                                                            order.orderStatus ==
                                                                'confirmed' ||
                                                            order.orderStatus ==
                                                                'processing'))
                                                    ? IconButton(
                                                        onPressed: () async {
                                                          String url =
                                                              'https://www.google.com/maps/dir/?api=1&destination=${order.deliveryAddress!.latitude}'
                                                              ',${order.deliveryAddress!.longitude}&mode=d';
                                                          if (await canLaunchUrlString(
                                                            url,
                                                          )) {
                                                            await launchUrlString(
                                                              url,
                                                              mode: LaunchMode
                                                                  .externalApplication,
                                                            );
                                                          } else {
                                                            showCustomSnackBar(
                                                              'unable_to_launch_google_map'
                                                                  .tr,
                                                            );
                                                          }
                                                        },
                                                        icon: const Icon(
                                                          Icons.directions,
                                                        ),
                                                      )
                                                    : const SizedBox(),

                                                (order.orderStatus !=
                                                            'delivered' &&
                                                        order.orderStatus !=
                                                            'failed' &&
                                                        Get.find<
                                                              ProfileController
                                                            >()
                                                            .modulePermission!
                                                            .chat! &&
                                                        order.orderStatus !=
                                                            'canceled' &&
                                                        order.orderStatus !=
                                                            'refunded')
                                                    ? order.isGuest!
                                                          ? const SizedBox()
                                                          : Row(
                                                              children: [
                                                                IconButton(
                                                                  onPressed: () async {
                                                                    if (Get.find<
                                                                                  ProfileController
                                                                                >()
                                                                                .profileModel!
                                                                                .subscription !=
                                                                            null &&
                                                                        Get.find<
                                                                                  ProfileController
                                                                                >()
                                                                                .profileModel!
                                                                                .subscription!
                                                                                .chat ==
                                                                            0 &&
                                                                        Get.find<
                                                                                  ProfileController
                                                                                >()
                                                                                .profileModel!
                                                                                .stores![0]
                                                                                .storeBusinessModel ==
                                                                            'subscription') {
                                                                      showCustomSnackBar(
                                                                        'you_have_no_available_subscription'
                                                                            .tr,
                                                                      );
                                                                    } else {
                                                                      _timer
                                                                          ?.cancel();
                                                                      await Get.toNamed(
                                                                        RouteHelper.getChatRoute(
                                                                          notificationBody: NotificationBodyModel(
                                                                            orderId:
                                                                                order.id,
                                                                            customerId:
                                                                                order.customer!.id,
                                                                          ),
                                                                          user: User(
                                                                            id: order.customer!.id,
                                                                            fName:
                                                                                order.customer!.fName,
                                                                            lName:
                                                                                order.customer!.lName,
                                                                            imageFullUrl:
                                                                                order.customer!.imageFullUrl,
                                                                          ),
                                                                        ),
                                                                      );
                                                                      _startApiCalling();
                                                                    }
                                                                  },
                                                                  icon: Image.asset(
                                                                    Images
                                                                        .chatIcon,
                                                                    width: 22,
                                                                    height: 22,
                                                                  ),
                                                                ),

                                                                if (order
                                                                            .customer
                                                                            ?.phone !=
                                                                        null &&
                                                                    order
                                                                            .customer
                                                                            ?.phone !=
                                                                        '')
                                                                  IconButton(
                                                                    onPressed: () async {
                                                                      if (Get.find<
                                                                                    ProfileController
                                                                                  >()
                                                                                  .profileModel!
                                                                                  .subscription !=
                                                                              null &&
                                                                          Get.find<
                                                                                    ProfileController
                                                                                  >()
                                                                                  .profileModel!
                                                                                  .subscription!
                                                                                  .chat ==
                                                                              0 &&
                                                                          Get.find<
                                                                                    ProfileController
                                                                                  >()
                                                                                  .profileModel!
                                                                                  .stores![0]
                                                                                  .storeBusinessModel ==
                                                                              'subscription') {
                                                                        showCustomSnackBar(
                                                                          'you_have_no_available_subscription'
                                                                              .tr,
                                                                        );
                                                                      } else {
                                                                        _timer
                                                                            ?.cancel();
                                                                        if (await canLaunchUrlString(
                                                                          'tel:${order.customer?.phone ?? ''}',
                                                                        )) {
                                                                          launchUrlString(
                                                                            'tel:${order.customer?.phone ?? ''}',
                                                                            mode:
                                                                                LaunchMode.externalApplication,
                                                                          );
                                                                        } else {
                                                                          showCustomSnackBar(
                                                                            '${'can_not_launch'.tr} ${order.customer?.phone ?? ''}',
                                                                          );
                                                                        }
                                                                      }
                                                                    },
                                                                    icon: Image.asset(
                                                                      Images
                                                                          .callIcon,
                                                                      width: 22,
                                                                      height:
                                                                          22,
                                                                    ),
                                                                  ),
                                                              ],
                                                            )
                                                    : const SizedBox(),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(
                                        height: Dimensions.paddingSizeDefault,
                                      ),
                                    ],

                                    /// cutlery
                                    // Get.find<SplashController>().getModuleConfig(order.moduleType).newVariation!
                                    // ? Column(children: [
                                    //   const Divider(height: Dimensions.paddingSizeLarge),
                                    //
                                    //   Row(children: [
                                    //     Text('${'cutlery'.tr}: ', style: robotoRegular),
                                    //     const Expanded(child: SizedBox()),
                                    //
                                    //     Text(
                                    //       order.cutlery! ? 'yes'.tr : 'no'.tr,
                                    //       style: robotoRegular,
                                    //     ),
                                    //   ]),
                                    // ]) : const SizedBox(),

                                    /// unavailable_item_note
                                    // order.unavailableItemNote != null ? Column(
                                    //   children: [
                                    //     const Divider(height: Dimensions.paddingSizeLarge),
                                    //
                                    //     Row(children: [
                                    //       Text('${'unavailable_item_note'.tr}: ', style: robotoMedium),
                                    //
                                    //       Text(
                                    //         order.unavailableItemNote!,
                                    //         style: robotoRegular,
                                    //       ),
                                    //     ]),
                                    //   ],
                                    // ) : const SizedBox(),

                                    /// delivery_instruction
                                    // order.deliveryInstruction != null ? Column(children: [
                                    //   const Divider(height: Dimensions.paddingSizeLarge),
                                    //   Row(children: [
                                    //     Text('${'delivery_instruction'.tr}: ', style: robotoMedium),
                                    //     Text(order.deliveryInstruction?.tr ?? '', style: robotoRegular),
                                    //   ]),
                                    // ]) : const SizedBox(),
                                    // SizedBox(height: order.deliveryInstruction != null ? Dimensions.paddingSizeSmall : 0),

                                    /// in_change_for_the_customer_when_making_the_delivery
                                    // order.bringChangeAmount != null && order.bringChangeAmount! > 0 ? Container(
                                    //   width: double.infinity,
                                    //   padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                                    //   decoration: BoxDecoration(
                                    //     color: const Color(0XFF009AF1).withValues(alpha: 0.1),
                                    //     borderRadius: BorderRadius.circular(Dimensions.radiusSmall)),
                                    //   child: RichText(text: TextSpan(children: [
                                    //       TextSpan(text: 'please_bring'.tr, style: robotoRegular.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                                    //       TextSpan(text: ' ${PriceConverterHelper.convertPrice(order.bringChangeAmount)}', style: robotoMedium.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                                    //       TextSpan(text: ' ${'in_change_for_the_customer_when_making_the_delivery'.tr}', style: robotoRegular.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color)),
                                    //     ])),
                                    // ) : const SizedBox(),

                                    /// Additional Note
                                    // (order.orderNote  != null && order.orderNote!.isNotEmpty) ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    //   Text('additional_note'.tr, style: robotoRegular),
                                    //   const SizedBox(height: Dimensions.paddingSizeSmall),
                                    //   Container(
                                    //     width: 1170,
                                    //     padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                                    //     decoration: BoxDecoration(
                                    //       borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                                    //       border: Border.all(width: 1, color: Theme.of(context).disabledColor)),
                                    //     child: Text(order.orderNote!,
                                    //       style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).disabledColor)),
                                    //   ),
                                    //   const SizedBox(height: Dimensions.paddingSizeLarge),
                                    // ]) : const SizedBox(),

                                    /// prescription
                                    // (Get.find<SplashController>().getModuleConfig(order.moduleType).orderAttachment! && order.orderAttachmentFullUrl != null
                                    // && order.orderAttachmentFullUrl!.isNotEmpty) ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    //   Text('prescription'.tr, style: robotoRegular),
                                    //   const SizedBox(height: Dimensions.paddingSizeSmall),
                                    //   GridView.builder(
                                    //       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    //         childAspectRatio: 1,
                                    //         crossAxisCount: ResponsiveHelper.isTab(context) ? 5 : 3,
                                    //         mainAxisSpacing: 10,
                                    //         crossAxisSpacing: 5,
                                    //       ),
                                    //       shrinkWrap: true,
                                    //       physics: const NeverScrollableScrollPhysics(),
                                    //       itemCount: order.orderAttachmentFullUrl!.length,
                                    //       itemBuilder: (BuildContext context, index) {
                                    //         return Padding(
                                    //           padding: const EdgeInsets.only(right: 8),
                                    //           child: InkWell(
                                    //             onTap: () => openDialog(context, order.orderAttachmentFullUrl![index]),
                                    //             child: Center(child: ClipRRect(
                                    //               borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                                    //               child: CustomImageWidget(
                                    //                 image: order.orderAttachmentFullUrl![index],
                                    //                 width: 100, height: 100,
                                    //               ),
                                    //             )),
                                    //           ),
                                    //         );
                                    //       }),
                                    //   const SizedBox(height: Dimensions.paddingSizeLarge),
                                    // ]) : const SizedBox(),

                                    /// order_proof
                                    // (controllerOrderModel.orderStatus == 'delivered' && order.orderProofFullUrl != null
                                    // && order.orderProofFullUrl!.isNotEmpty) ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    //   Text('order_proof'.tr, style: robotoRegular),
                                    //   const SizedBox(height: Dimensions.paddingSizeSmall),
                                    //
                                    //   GridView.builder(
                                    //       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    //         childAspectRatio: 1.5,
                                    //         crossAxisCount: ResponsiveHelper.isTab(context) ? 5 : 3,
                                    //         mainAxisSpacing: 10,
                                    //         crossAxisSpacing: 5,
                                    //       ),
                                    //       shrinkWrap: true,
                                    //       physics: const NeverScrollableScrollPhysics(),
                                    //       itemCount: order.orderProofFullUrl!.length,
                                    //       itemBuilder: (BuildContext context, index) {
                                    //         return Padding(
                                    //           padding: const EdgeInsets.only(right: 8),
                                    //           child: InkWell(
                                    //             onTap: () => openDialog(context, order.orderProofFullUrl![index]),
                                    //             child: Center(child: ClipRRect(
                                    //               borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                                    //               child: CustomImageWidget(
                                    //                 image: order.orderProofFullUrl![index],
                                    //                 width: 100, height: 100,
                                    //               ),
                                    //             )),
                                    //           ),
                                    //         );
                                    //       }),
                                    //
                                    //   const SizedBox(height: Dimensions.paddingSizeLarge),
                                    // ]) : const SizedBox(),

                                    /// Customer details
                                    // Text('customer_details'.tr, style: robotoRegular),
                                    // const SizedBox(height: Dimensions.paddingSizeExtraSmall),
                                    //
                                    // order.deliveryAddress != null ? Row(children: [
                                    //   SizedBox(
                                    //     height: 35, width: 35,
                                    //     child: ClipOval(child: CustomImageWidget(
                                    //       image: '${order.customer != null ? order.customer!.imageFullUrl : ''}',
                                    //       height: 35, width: 35, fit: BoxFit.cover,
                                    //     )),
                                    //   ),
                                    //   const SizedBox(width: Dimensions.paddingSizeSmall),
                                    //   Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    //     Text(
                                    //       order.deliveryAddress!.contactPersonName!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    //       style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
                                    //     ),
                                    //     Text(
                                    //       order.deliveryAddress!.address ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                    //       style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).disabledColor),
                                    //     ),
                                    //
                                    //     Wrap(children: [
                                    //       (order.deliveryAddress!.streetNumber != null && order.deliveryAddress!.streetNumber!.isNotEmpty) ? Text('${'street_number'.tr}: ${order.deliveryAddress!.streetNumber!}, ',
                                    //         style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).disabledColor), maxLines: 1, overflow: TextOverflow.ellipsis,
                                    //       ) : const SizedBox(),
                                    //
                                    //       (order.deliveryAddress!.house != null && order.deliveryAddress!.house!.isNotEmpty) ? Text('${'house'.tr}: ${order.deliveryAddress!.house!}, ',
                                    //         style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).disabledColor), maxLines: 1, overflow: TextOverflow.ellipsis,
                                    //       ) : const SizedBox(),
                                    //
                                    //       (order.deliveryAddress!.floor != null && order.deliveryAddress!.floor!.isNotEmpty) ? Text('${'floor'.tr}: ${order.deliveryAddress!.floor!}' ,
                                    //         style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).disabledColor), maxLines: 1, overflow: TextOverflow.ellipsis,
                                    //       ) : const SizedBox(),
                                    //     ]),
                                    //
                                    //   ])),
                                    //
                                    //   (order.orderType == 'take_away' && (order.orderStatus == 'pending' || order.orderStatus == 'confirmed' || order.orderStatus == 'processing')) ? TextButton.icon(
                                    //     onPressed: () async {
                                    //       String url ='https://www.google.com/maps/dir/?api=1&destination=${order.deliveryAddress!.latitude}'
                                    //           ',${order.deliveryAddress!.longitude}&mode=d';
                                    //       if (await canLaunchUrlString(url)) {
                                    //         await launchUrlString(url, mode: LaunchMode.externalApplication);
                                    //       }else {
                                    //         showCustomSnackBar('unable_to_launch_google_map'.tr);
                                    //       }
                                    //     },
                                    //     icon: const Icon(Icons.directions), label: Text('direction'.tr),
                                    //   ) : const SizedBox(),
                                    //   const SizedBox(width: Dimensions.paddingSizeSmall),
                                    //
                                    //   (order.orderStatus != 'delivered' && order.orderStatus != 'failed' && Get.find<ProfileController>().modulePermission!.chat!
                                    //   && order.orderStatus != 'canceled' && order.orderStatus != 'refunded') ? order.isGuest! ? const SizedBox() : TextButton.icon(
                                    //     onPressed: () async {
                                    //
                                    //       if(Get.find<ProfileController>().profileModel!.subscription != null && Get.find<ProfileController>().profileModel!.subscription!.chat == 0
                                    //       && Get.find<ProfileController>().profileModel!.stores![0].storeBusinessModel == 'subscription') {
                                    //
                                    //       showCustomSnackBar('you_have_no_available_subscription'.tr);
                                    //
                                    //       } else {
                                    //         _timer?.cancel();
                                    //         await Get.toNamed(RouteHelper.getChatRoute(
                                    //           notificationBody: NotificationBodyModel(
                                    //             orderId: order.id, customerId: order.customer!.id,
                                    //           ),
                                    //           user: User(
                                    //             id: order.customer!.id, fName: order.customer!.fName,
                                    //             lName: order.customer!.lName, imageFullUrl: order.customer!.imageFullUrl,
                                    //           ),
                                    //         ));
                                    //         _startApiCalling();
                                    //       }
                                    //     },
                                    //     icon: Icon(Icons.message, color: Theme.of(context).primaryColor, size: 20),
                                    //     label: Text(
                                    //       'chat'.tr,
                                    //       style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor),
                                    //     ),
                                    //   ) : const SizedBox(),
                                    // ]) : const SizedBox(),
                                    // const SizedBox(height: Dimensions.paddingSizeLarge),

                                    /// Delivery man details
                                    // order.deliveryMan != null ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    //
                                    //   Text('delivery_man'.tr, style: robotoRegular),
                                    //   const SizedBox(height: Dimensions.paddingSizeSmall),
                                    //
                                    //   Row(children: [
                                    //
                                    //     ClipOval(child: CustomImageWidget(
                                    //       image: order.deliveryMan != null ? '${order.deliveryMan!.imageFullUrl}' : '',
                                    //       height: 35, width: 35, fit: BoxFit.cover,
                                    //     )),
                                    //     const SizedBox(width: Dimensions.paddingSizeSmall),
                                    //
                                    //     Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    //       Text(
                                    //         '${order.deliveryMan!.fName} ${order.deliveryMan!.lName}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                    //         style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall),
                                    //       ),
                                    //       Text(
                                    //         order.deliveryMan!.email!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    //         style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).disabledColor),
                                    //       ),
                                    //     ])),
                                    //
                                    //     (controllerOrderModel.orderStatus != 'delivered' && controllerOrderModel.orderStatus != 'failed'
                                    //     && controllerOrderModel.orderStatus != 'canceled' && controllerOrderModel.orderStatus != 'refunded') ? TextButton.icon(
                                    //       onPressed: () async {
                                    //         if(await canLaunchUrlString('tel:${order.deliveryMan!.phone ?? '' }')) {
                                    //           launchUrlString('tel:${order.deliveryMan!.phone ?? '' }', mode: LaunchMode.externalApplication);
                                    //         }else {
                                    //           showCustomSnackBar('${'can_not_launch'.tr} ${order.deliveryMan!.phone ?? ''}');
                                    //         }
                                    //       },
                                    //       icon: Icon(Icons.call, color: Theme.of(context).primaryColor, size: 20),
                                    //       label: Text(
                                    //         'call'.tr,
                                    //         style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor),
                                    //       ),
                                    //     ) : const SizedBox(),
                                    //
                                    //     (controllerOrderModel.orderStatus != 'delivered' && controllerOrderModel.orderStatus != 'failed' && controllerOrderModel.orderStatus != 'canceled'
                                    //     && controllerOrderModel.orderStatus != 'refunded' && Get.find<ProfileController>().modulePermission!.chat!) ? TextButton.icon(
                                    //       onPressed: () async {
                                    //
                                    //         if(Get.find<ProfileController>().profileModel!.subscription != null && Get.find<ProfileController>().profileModel!.subscription!.chat == 0
                                    //         && Get.find<ProfileController>().profileModel!.stores![0].storeBusinessModel == 'subscription') {
                                    //
                                    //           showCustomSnackBar('you_have_no_available_subscription'.tr);
                                    //
                                    //         } else {
                                    //           _timer?.cancel();
                                    //           await Get.toNamed(RouteHelper.getChatRoute(
                                    //             notificationBody: NotificationBodyModel(
                                    //               orderId: controllerOrderModel.id, deliveryManId: order.deliveryMan!.id,
                                    //             ),
                                    //             user: User(
                                    //               id: controllerOrderModel.deliveryMan!.id, fName: controllerOrderModel.deliveryMan!.fName,
                                    //               lName: controllerOrderModel.deliveryMan!.lName, imageFullUrl: controllerOrderModel.deliveryMan!.imageFullUrl,
                                    //             ),
                                    //           ));
                                    //           _startApiCalling();
                                    //         }
                                    //
                                    //       },
                                    //       icon: Icon(Icons.chat_bubble_outline, color: Theme.of(context).primaryColor, size: 20),
                                    //       label: Text(
                                    //         'chat'.tr,
                                    //         style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).primaryColor),
                                    //       ),
                                    //     ) : const SizedBox(),
                                    //
                                    //   ]),
                                    //
                                    //   const SizedBox(height: Dimensions.paddingSizeSmall),
                                    // ]) : const SizedBox(),

                                    // Total

                                    /// Payment Details
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal:
                                            Dimensions.paddingSizeDefault,
                                        vertical: Dimensions.paddingSizeSmall,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(
                                          Dimensions.radiusSmall,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            offset: Offset(0, 3),
                                            color:
                                                Colors.grey[Get.isDarkMode
                                                    ? 700
                                                    : 200]!,
                                            blurRadius: 8,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'payment_details'.tr,
                                                style: robotoBold,
                                              ),
                                              Spacer(),
                                              Text(
                                                ((order.paymentMethod ==
                                                            'partial_payment') &&
                                                        (order
                                                                .payments?[0]
                                                                .amount !=
                                                            null))
                                                    ? 'paid'.tr
                                                    : 'unpaid'.tr,
                                                style: robotoRegular.copyWith(
                                                  color: Theme.of(
                                                    context,
                                                  ).primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Divider(
                                            thickness: 1,
                                            color: Theme.of(
                                              context,
                                            ).hintColor.withValues(alpha: 0.1),
                                          ),

                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              Image.asset(
                                                Images.mdiCashIcon,
                                                width: 24,
                                                height: 24,
                                              ),
                                              SizedBox(
                                                width:
                                                    Dimensions.paddingSizeSmall,
                                              ),
                                              Text(
                                                (order.paymentMethod ==
                                                        'partial_payment')
                                                    ? 'wallet'.tr
                                                    : 'cash'.tr,
                                                style: restConfModel
                                                    ? robotoMedium
                                                    : robotoRegular,
                                              ),
                                              order.paymentMethod ==
                                                      'partial_payment'
                                                  ? Text(
                                                      '(${'partial_payment'.tr})',
                                                      style: robotoRegular
                                                          .copyWith(
                                                            fontSize: Dimensions
                                                                .fontSizeSmall,
                                                            color: Theme.of(
                                                              context,
                                                            ).hintColor,
                                                          ),
                                                    )
                                                  : SizedBox.shrink(),
                                              Spacer(),
                                              Text(
                                                (order.paymentMethod ==
                                                        'partial_payment')
                                                    ? PriceConverterHelper.convertPrice(
                                                        order
                                                            .payments![0]
                                                            .amount,
                                                      )
                                                    : PriceConverterHelper.convertPrice(
                                                        total,
                                                      ),
                                                style: restConfModel
                                                    ? robotoMedium
                                                    : robotoRegular,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(
                                      height: Dimensions.paddingSizeSmall,
                                    ),

                                    /// Billing Summary
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal:
                                            Dimensions.paddingSizeDefault,
                                        vertical: Dimensions.paddingSizeSmall,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(
                                          Dimensions.radiusSmall,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            offset: Offset(0, 3),
                                            color:
                                                Colors.grey[Get.isDarkMode
                                                    ? 700
                                                    : 200]!,
                                            blurRadius: 8,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'billing_summary'.tr,
                                            style: robotoBold,
                                          ),
                                          Divider(
                                            thickness: 1,
                                            color: Theme.of(
                                              context,
                                            ).hintColor.withValues(alpha: 0.1),
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'item_price'.tr,
                                                style: robotoRegular,
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  order.prescriptionOrder!
                                                      ? IconButton(
                                                          constraints:
                                                              const BoxConstraints(
                                                                maxHeight: 36,
                                                              ),
                                                          onPressed: () => Get.dialog(
                                                            AmountInputDialogueWidget(
                                                              orderId: widget
                                                                  .orderId,
                                                              isItemPrice: true,
                                                              amount:
                                                                  itemsPrice,
                                                              additionalCharge:
                                                                  additionalCharge,
                                                            ),
                                                            barrierDismissible:
                                                                true,
                                                          ),
                                                          icon: const Icon(
                                                            Icons.edit,
                                                            size: 16,
                                                          ),
                                                        )
                                                      : const SizedBox(),
                                                  Text(
                                                    PriceConverterHelper.convertPrice(
                                                      itemsPrice,
                                                    ),
                                                    style: robotoRegular,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(
                                            height: Dimensions.paddingSizeSmall,
                                          ),

                                          Get.find<SplashController>()
                                                  .getModuleConfig(
                                                    order.moduleType,
                                                  )
                                                  .addOn!
                                              ? Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'addons'.tr,
                                                      style: robotoRegular,
                                                    ),
                                                    Text(
                                                      '(+) ${PriceConverterHelper.convertPrice(addOns)}',
                                                      style: robotoRegular,
                                                    ),
                                                  ],
                                                )
                                              : const SizedBox(),

                                          Get.find<SplashController>()
                                                  .getModuleConfig(
                                                    order.moduleType,
                                                  )
                                                  .addOn!
                                              ? Divider(
                                                  thickness: 1,
                                                  color: Theme.of(context)
                                                      .hintColor
                                                      .withValues(alpha: 0.1),
                                                )
                                              : const SizedBox(),

                                          Get.find<SplashController>()
                                                  .getModuleConfig(
                                                    order.moduleType,
                                                  )
                                                  .addOn!
                                              ? Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'subtotal'.tr,
                                                      style: robotoMedium,
                                                    ),
                                                    Text(
                                                      PriceConverterHelper.convertPrice(
                                                        subTotal,
                                                      ),
                                                      style: robotoMedium,
                                                    ),
                                                  ],
                                                )
                                              : const SizedBox(),
                                          SizedBox(
                                            height:
                                                Get.find<SplashController>()
                                                    .getModuleConfig(
                                                      order.moduleType,
                                                    )
                                                    .addOn!
                                                ? 10
                                                : 0,
                                          ),

                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'discount'.tr,
                                                style: robotoRegular,
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  order.prescriptionOrder!
                                                      ? IconButton(
                                                          constraints:
                                                              const BoxConstraints(
                                                                maxHeight: 36,
                                                              ),
                                                          onPressed: () => Get.dialog(
                                                            AmountInputDialogueWidget(
                                                              orderId: widget
                                                                  .orderId,
                                                              isItemPrice:
                                                                  false,
                                                              amount: discount,
                                                            ),
                                                            barrierDismissible:
                                                                true,
                                                          ),
                                                          icon: const Icon(
                                                            Icons.edit,
                                                            size: 16,
                                                          ),
                                                        )
                                                      : const SizedBox(),
                                                  Text(
                                                    '(-) ${PriceConverterHelper.convertPrice(discount)}',
                                                    style: robotoRegular,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),

                                          couponDiscount > 0
                                              ? Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'coupon_discount'.tr,
                                                      style: robotoRegular,
                                                    ),
                                                    Text(
                                                      '(-) ${PriceConverterHelper.convertPrice(couponDiscount)}',
                                                      style: robotoRegular,
                                                    ),
                                                  ],
                                                )
                                              : const SizedBox(),
                                          SizedBox(
                                            height: couponDiscount > 0 ? 10 : 0,
                                          ),

                                          (referrerBonusAmount > 0)
                                              ? Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'referral_discount'.tr,
                                                      style: robotoRegular,
                                                    ),
                                                    Text(
                                                      '(-) ${PriceConverterHelper.convertPrice(referrerBonusAmount)}',
                                                      style: robotoRegular,
                                                    ),
                                                  ],
                                                )
                                              : const SizedBox(),
                                          SizedBox(
                                            height: referrerBonusAmount > 0
                                                ? 10
                                                : 0,
                                          ),

                                          taxIncluded || (tax == 0)
                                              ? const SizedBox()
                                              : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'vat_tax'.tr,
                                                      style: robotoRegular,
                                                    ),
                                                    Text(
                                                      '(+) ${PriceConverterHelper.convertPrice(tax)}',
                                                      style: robotoRegular,
                                                    ),
                                                  ],
                                                ),
                                          SizedBox(
                                            height: taxIncluded || (tax == 0)
                                                ? 0
                                                : 10,
                                          ),

                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'delivery_man_tips'.tr,
                                                style: robotoRegular,
                                              ),
                                              Text(
                                                '(+) ${PriceConverterHelper.convertPrice(dmTips)}',
                                                style: robotoRegular,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),

                                          (extraPackagingAmount > 0)
                                              ? Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'extra_packaging'.tr,
                                                      style: robotoRegular,
                                                    ),
                                                    Text(
                                                      '(+) ${PriceConverterHelper.convertPrice(extraPackagingAmount)}',
                                                      style: robotoRegular,
                                                    ),
                                                  ],
                                                )
                                              : const SizedBox(),
                                          SizedBox(
                                            height: extraPackagingAmount > 0
                                                ? 10
                                                : 0,
                                          ),
                                          (order.additionalCharge != null &&
                                                  order.additionalCharge! > 0)
                                              ? Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        Get.find<
                                                              SplashController
                                                            >()
                                                            .configModel!
                                                            .additionalChargeName!,
                                                        style: robotoRegular,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: Dimensions
                                                          .paddingSizeSmall,
                                                    ),
                                                    Text(
                                                      '(+) ${PriceConverterHelper.convertPrice(order.additionalCharge)}',
                                                      style: robotoRegular,
                                                      textDirection:
                                                          TextDirection.ltr,
                                                    ),
                                                  ],
                                                )
                                              : const SizedBox(),
                                          (order.additionalCharge != null &&
                                                  order.additionalCharge! > 0)
                                              ? const SizedBox(height: 10)
                                              : const SizedBox(),

                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'delivery_fee'.tr,
                                                style: robotoRegular,
                                              ),
                                              Text(
                                                '(+) ${PriceConverterHelper.convertPrice(deliveryCharge)}',
                                                style: robotoRegular,
                                              ),
                                            ],
                                          ),

                                          // if(order.orderStatus != 'pending')
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical:
                                                  Dimensions.paddingSizeSmall,
                                            ),
                                            child: Divider(
                                              thickness: 1,
                                              color: Theme.of(context).hintColor
                                                  .withValues(alpha: 0.1),
                                            ),
                                          ),

                                          order.paymentMethod ==
                                                  'partial_payment'
                                              ? DottedBorder(
                                                  options:
                                                      RoundedRectDottedBorderOptions(
                                                        color: Theme.of(
                                                          context,
                                                        ).primaryColor,
                                                        strokeWidth: 1,
                                                        strokeCap:
                                                            StrokeCap.butt,
                                                        dashPattern: const [
                                                          8,
                                                          5,
                                                        ],
                                                        padding:
                                                            const EdgeInsets.all(
                                                              0,
                                                            ),
                                                        radius:
                                                            const Radius.circular(
                                                              Dimensions
                                                                  .radiusDefault,
                                                            ),
                                                      ),
                                                  child: Ink(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          Dimensions
                                                              .paddingSizeSmall,
                                                        ),
                                                    color: restConfModel
                                                        ? Theme.of(context)
                                                              .primaryColor
                                                              .withValues(
                                                                alpha: 0.05,
                                                              )
                                                        : Colors.transparent,
                                                    child: Column(
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'total_amount'.tr,
                                                              style: robotoMedium
                                                                  .copyWith(
                                                                    fontSize:
                                                                        Dimensions
                                                                            .fontSizeLarge,
                                                                  ),
                                                            ),
                                                            Text(
                                                              PriceConverterHelper.convertPrice(
                                                                total,
                                                              ),
                                                              style: robotoMedium
                                                                  .copyWith(
                                                                    fontSize:
                                                                        Dimensions
                                                                            .fontSizeLarge,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),

                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'paid_by_wallet'
                                                                  .tr,
                                                              style:
                                                                  restConfModel
                                                                  ? robotoMedium
                                                                  : robotoRegular,
                                                            ),
                                                            Text(
                                                              PriceConverterHelper.convertPrice(
                                                                order
                                                                    .payments![0]
                                                                    .amount,
                                                              ),
                                                              style:
                                                                  restConfModel
                                                                  ? robotoMedium
                                                                  : robotoRegular,
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 10,
                                                        ),

                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              '${order.payments?[1].paymentStatus == 'paid' ? 'paid_by'.tr : 'due_amount'.tr} (${order.payments![1].paymentMethod?.tr})',
                                                              style:
                                                                  restConfModel
                                                                  ? robotoMedium
                                                                  : robotoRegular,
                                                            ),
                                                            Text(
                                                              PriceConverterHelper.convertPrice(
                                                                order
                                                                    .payments![1]
                                                                    .amount,
                                                              ),
                                                              style:
                                                                  restConfModel
                                                                  ? robotoMedium
                                                                  : robotoRegular,
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                              : const SizedBox(),

                                          // order.orderStatus != 'pending' &&
                                          if (order.paymentMethod !=
                                              'partial_payment')
                                            Row(
                                              children: [
                                                Text(
                                                  'total_amount'.tr,
                                                  style: robotoMedium.copyWith(
                                                    fontSize: Dimensions
                                                        .fontSizeLarge,
                                                  ),
                                                ),
                                                taxIncluded || (tax == 0)
                                                    ? Text(
                                                        ' ${'inc_vat_tax'.tr}',
                                                        style: robotoMedium.copyWith(
                                                          fontSize: Dimensions
                                                              .fontSizeExtraSmall,
                                                          color: Theme.of(
                                                            context,
                                                          ).hintColor,
                                                        ),
                                                      )
                                                    : const SizedBox(),
                                                const Expanded(
                                                  child: SizedBox(),
                                                ),
                                                Text(
                                                  PriceConverterHelper.convertPrice(
                                                    total,
                                                  ),
                                                  style: robotoMedium.copyWith(
                                                    fontSize: Dimensions
                                                        .fontSizeLarge,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        showDeliveryConfirmImage &&
                                Get.find<SplashController>()
                                    .configModel!
                                    .dmPictureUploadStatus! &&
                                controllerOrderModel.orderStatus != 'delivered'
                            ? Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: Dimensions.paddingSizeDefault,
                                  vertical: Dimensions.paddingSizeSmall,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusSmall,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      offset: Offset(0, 3),
                                      color: Colors
                                          .grey[Get.isDarkMode ? 700 : 200]!,
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      height: Dimensions.paddingSizeDefault,
                                    ),
                                    Text(
                                      'completed_after_delivery_picture'.tr,
                                      style: robotoRegular,
                                    ),
                                    const SizedBox(
                                      height: Dimensions.paddingSizeSmall,
                                    ),

                                    Container(
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(
                                          Dimensions.radiusDefault,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(
                                        Dimensions.paddingSizeSmall,
                                      ),
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        itemCount:
                                            orderController
                                                .pickedPrescriptions
                                                .length +
                                            1,
                                        itemBuilder: (context, index) {
                                          XFile? file =
                                              index ==
                                                  orderController
                                                      .pickedPrescriptions
                                                      .length
                                              ? null
                                              : orderController
                                                    .pickedPrescriptions[index];
                                          if (index < 5 &&
                                              index ==
                                                  orderController
                                                      .pickedPrescriptions
                                                      .length) {
                                            return InkWell(
                                              onTap: () {
                                                if (GetPlatform.isIOS) {
                                                  Get.find<OrderController>()
                                                      .pickPrescriptionImage(
                                                        isRemove: false,
                                                        isCamera: false,
                                                      );
                                                } else {
                                                  Get.bottomSheet(
                                                    const CameraButtonSheetWidget(),
                                                  );
                                                }
                                              },
                                              child: Container(
                                                height: 60,
                                                width: 60,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        Dimensions
                                                            .radiusDefault,
                                                      ),
                                                  color: Theme.of(context)
                                                      .primaryColor
                                                      .withValues(alpha: 0.1),
                                                ),
                                                child: Icon(
                                                  Icons.camera_alt_sharp,
                                                  color: Theme.of(
                                                    context,
                                                  ).primaryColor,
                                                  size: 32,
                                                ),
                                              ),
                                            );
                                          }
                                          return file != null
                                              ? Container(
                                                  margin: const EdgeInsets.only(
                                                    right: Dimensions
                                                        .paddingSizeSmall,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          Dimensions
                                                              .radiusDefault,
                                                        ),
                                                  ),
                                                  child: Stack(
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              Dimensions
                                                                  .radiusDefault,
                                                            ),
                                                        child: GetPlatform.isWeb
                                                            ? Image.network(
                                                                file.path,
                                                                width: 60,
                                                                height: 60,
                                                                fit: BoxFit
                                                                    .cover,
                                                              )
                                                            : Image.file(
                                                                File(file.path),
                                                                width: 60,
                                                                height: 60,
                                                                fit: BoxFit
                                                                    .cover,
                                                              ),
                                                      ),
                                                      Positioned(
                                                        right: 0,
                                                        top: 0,
                                                        child: InkWell(
                                                          onTap: () =>
                                                              orderController
                                                                  .removePrescriptionImage(
                                                                    index,
                                                                  ),
                                                          child: const Padding(
                                                            padding: EdgeInsets.all(
                                                              Dimensions
                                                                  .paddingSizeSmall,
                                                            ),
                                                            child: Icon(
                                                              Icons
                                                                  .delete_forever,
                                                              color: Colors.red,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : const SizedBox();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox(),

                        showDeliveryConfirmImage &&
                                controllerOrderModel.orderStatus != 'delivered'
                            ? Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: Dimensions.paddingSizeDefault,
                                  vertical: Dimensions.paddingSizeSmall,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusSmall,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      offset: Offset(0, 3),
                                      color: Colors
                                          .grey[Get.isDarkMode ? 700 : 200]!,
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: CustomButtonWidget(
                                  buttonText: 'complete_delivery'.tr,
                                  onPressed: () {
                                    if (Get.find<SplashController>()
                                        .configModel!
                                        .orderDeliveryVerification!) {
                                      orderController.sendDeliveredNotification(
                                        controllerOrderModel.id,
                                      );

                                      Get.bottomSheet(
                                        VerifyDeliverySheetWidget(
                                          orderID: controllerOrderModel.id,
                                          verify: Get.find<SplashController>()
                                              .configModel!
                                              .orderDeliveryVerification,
                                          orderAmount:
                                              order.paymentMethod ==
                                                  'partial_payment'
                                              ? order.payments![1].amount!
                                                    .toDouble()
                                              : controllerOrderModel
                                                    .orderAmount,
                                          cod:
                                              controllerOrderModel
                                                      .paymentMethod ==
                                                  'cash_on_delivery' ||
                                              (order.paymentMethod ==
                                                      'partial_payment' &&
                                                  order
                                                          .payments![1]
                                                          .paymentMethod ==
                                                      'cash_on_delivery'),
                                        ),
                                        isScrollControlled: true,
                                      ).then((isSuccess) {
                                        if (isSuccess &&
                                                controllerOrderModel
                                                        .paymentMethod ==
                                                    'cash_on_delivery' ||
                                            (order.paymentMethod ==
                                                    'partial_payment' &&
                                                order
                                                        .payments![1]
                                                        .paymentMethod ==
                                                    'cash_on_delivery')) {
                                          Get.bottomSheet(
                                            CollectMoneyDeliverySheetWidget(
                                              orderID: controllerOrderModel.id,
                                              verify:
                                                  Get.find<SplashController>()
                                                      .configModel!
                                                      .orderDeliveryVerification,
                                              orderAmount:
                                                  order.paymentMethod ==
                                                      'partial_payment'
                                                  ? order.payments![1].amount!
                                                        .toDouble()
                                                  : controllerOrderModel
                                                        .orderAmount,
                                              cod:
                                                  controllerOrderModel
                                                          .paymentMethod ==
                                                      'cash_on_delivery' ||
                                                  (order.paymentMethod ==
                                                          'partial_payment' &&
                                                      order
                                                              .payments![1]
                                                              .paymentMethod ==
                                                          'cash_on_delivery'),
                                            ),
                                            isScrollControlled: true,
                                            isDismissible: false,
                                          );
                                        }
                                      });
                                    } else {
                                      Get.bottomSheet(
                                        CollectMoneyDeliverySheetWidget(
                                          orderID: controllerOrderModel.id,
                                          verify: Get.find<SplashController>()
                                              .configModel!
                                              .orderDeliveryVerification,
                                          orderAmount:
                                              order.paymentMethod ==
                                                  'partial_payment'
                                              ? order.payments![1].amount!
                                                    .toDouble()
                                              : controllerOrderModel
                                                    .orderAmount,
                                          cod:
                                              controllerOrderModel
                                                      .paymentMethod ==
                                                  'cash_on_delivery' ||
                                              (order.paymentMethod ==
                                                      'partial_payment' &&
                                                  order
                                                          .payments![1]
                                                          .paymentMethod ==
                                                      'cash_on_delivery'),
                                        ),
                                        isScrollControlled: true,
                                      );
                                    }
                                  },
                                ),
                              )
                            : showBottomView
                            ? (controllerOrderModel.orderStatus == 'picked_up')
                                  ? Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal:
                                            Dimensions.paddingSizeDefault,
                                        vertical: Dimensions.paddingSizeSmall,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(
                                          Dimensions.radiusSmall,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            offset: Offset(0, 3),
                                            color:
                                                Colors.grey[Get.isDarkMode
                                                    ? 700
                                                    : 200]!,
                                            blurRadius: 8,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      width: MediaQuery.of(context).size.width,
                                      alignment: Alignment.center,
                                      child: Text(
                                        'item_is_on_the_way'.tr,
                                        style: robotoMedium,
                                      ),
                                    )
                                  : showSlider
                                  ? (controllerOrderModel.orderStatus ==
                                                'pending' &&
                                            (controllerOrderModel.orderType ==
                                                    'take_away' ||
                                                restConfModel ||
                                                selfDelivery) &&
                                            cancelPermission!)
                                        ? Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  Dimensions.paddingSizeDefault,
                                              vertical:
                                                  Dimensions.paddingSizeSmall,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).cardColor,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    Dimensions.radiusSmall,
                                                  ),
                                              boxShadow: [
                                                BoxShadow(
                                                  offset: Offset(0, 3),
                                                  color:
                                                      Colors.grey[Get.isDarkMode
                                                          ? 700
                                                          : 200]!,
                                                  blurRadius: 8,
                                                  spreadRadius: 0,
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              children: [
                                                order.paymentMethod !=
                                                        'partial_payment'
                                                    ? Row(
                                                        children: [
                                                          Text(
                                                            'total_amount'.tr,
                                                            style: robotoMedium
                                                                .copyWith(
                                                                  fontSize:
                                                                      Dimensions
                                                                          .fontSizeLarge,
                                                                ),
                                                          ),
                                                          taxIncluded
                                                              ? Text(
                                                                  ' ${'vat_tax_inc'.tr}',
                                                                  style: robotoMedium.copyWith(
                                                                    fontSize:
                                                                        Dimensions
                                                                            .fontSizeExtraSmall,
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).hintColor,
                                                                  ),
                                                                )
                                                              : const SizedBox(),
                                                          const Expanded(
                                                            child: SizedBox(),
                                                          ),
                                                          Text(
                                                            PriceConverterHelper.convertPrice(
                                                              total,
                                                            ),
                                                            style: robotoMedium
                                                                .copyWith(
                                                                  fontSize:
                                                                      Dimensions
                                                                          .fontSizeLarge,
                                                                ),
                                                          ),
                                                        ],
                                                      )
                                                    : const SizedBox(),
                                                SizedBox(
                                                  height: Dimensions
                                                      .paddingSizeSmall,
                                                ),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextButton(
                                                        onPressed: () {
                                                          orderController
                                                              .setOrderCancelReason(
                                                                '',
                                                              );
                                                          Get.dialog(
                                                            CancellationDialogueWidget(
                                                              orderId: order.id,
                                                            ),
                                                          );
                                                        },
                                                        style: TextButton.styleFrom(
                                                          minimumSize:
                                                              const Size(
                                                                1170,
                                                                40,
                                                              ),
                                                          padding:
                                                              EdgeInsets.zero,
                                                          backgroundColor:
                                                              Theme.of(context)
                                                                  .hintColor
                                                                  .withValues(
                                                                    alpha: 0.2,
                                                                  ),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  Dimensions
                                                                      .radiusSmall,
                                                                ),
                                                            side: BorderSide(
                                                              width: 1,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .hintColor
                                                                      .withValues(
                                                                        alpha:
                                                                            0.2,
                                                                      ),
                                                            ),
                                                          ),
                                                        ),
                                                        child: Text(
                                                          'cancel'.tr,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: robotoRegular.copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .bodyLarge!
                                                                    .color,
                                                            fontSize: Dimensions
                                                                .fontSizeLarge,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: Dimensions
                                                          .paddingSizeSmall,
                                                    ),

                                                    Expanded(
                                                      child: CustomButtonWidget(
                                                        buttonText:
                                                            'confirm'.tr,
                                                        height: 40,
                                                        onPressed: () {
                                                          Get.dialog(
                                                            ConfirmationDialogWidget(
                                                              icon: Images
                                                                  .warning,
                                                              title:
                                                                  'are_you_sure_to_confirm'
                                                                      .tr,
                                                              description:
                                                                  'you_want_to_confirm_this_order'
                                                                      .tr,
                                                              onYesPressed: () {
                                                                orderController.updateOrderStatus(
                                                                  widget
                                                                      .orderId,
                                                                  AppConstants
                                                                      .confirmed,
                                                                  fromNotification:
                                                                      true,
                                                                );
                                                              },
                                                            ),
                                                            barrierDismissible:
                                                                false,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          )
                                        : Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal:
                                                  Dimensions.paddingSizeSmall,
                                            ),
                                            child: SliderButton(
                                              action: () {
                                                final orderStatus =
                                                    controllerOrderModel
                                                        .orderStatus;
                                                final isSelfOrTakeAway =
                                                    controllerOrderModel
                                                            .orderType ==
                                                        'take_away' ||
                                                    restConfModel ||
                                                    selfDelivery;

                                                String? nextStatus;
                                                if (orderStatus == 'pending' &&
                                                    isSelfOrTakeAway) {
                                                  nextStatus =
                                                      AppConstants.confirmed;
                                                } else if (orderStatus ==
                                                        'confirmed' ||
                                                    (orderStatus ==
                                                            'accepted' &&
                                                        controllerOrderModel
                                                                .confirmed !=
                                                            null)) {
                                                  // Cooking tab removed:
                                                  // skip processing/cooking and
                                                  // jump straight to delivered
                                                  // for self-delivery / take-away.
                                                  // For delivery-man flow,
                                                  // we still need handover first.
                                                  if (isSelfOrTakeAway) {
                                                    if (Get.find<
                                                              SplashController
                                                            >()
                                                            .configModel!
                                                            .orderDeliveryVerification! ||
                                                        controllerOrderModel
                                                                .paymentMethod ==
                                                            'cash_on_delivery') {
                                                      orderController
                                                          .changeDeliveryImageStatus();
                                                      if (kDebugMode) {
                                                        print(
                                                          '=====jjj : ${Get.find<SplashController>().configModel!.orderDeliveryVerification} ; ${controllerOrderModel.paymentMethod}',
                                                        );
                                                      }
                                                      Get.dialog(
                                                        const DialogImageWidget(),
                                                        barrierDismissible:
                                                            false,
                                                      );
                                                      nextStatus = null;
                                                    } else {
                                                      nextStatus = AppConstants
                                                          .delivered;
                                                    }
                                                  } else {
                                                    nextStatus =
                                                        AppConstants.handover;
                                                  }
                                                } else if (orderStatus ==
                                                        'processing' ||
                                                    orderStatus == 'cooking') {
                                                  nextStatus =
                                                      AppConstants.handover;
                                                } else if (orderStatus ==
                                                    'handover') {
                                                  // Apply the same swipe-to-deliver
                                                  // logic for every order type in the
                                                  // "ready for handover" state, so the
                                                  // vendor can mark delivery orders
                                                  // (not only take_away / self-delivery)
                                                  // as delivered directly from the slider.
                                                  if (Get.find<
                                                            SplashController
                                                          >()
                                                          .configModel!
                                                          .orderDeliveryVerification! ||
                                                      controllerOrderModel
                                                              .paymentMethod ==
                                                          'cash_on_delivery') {
                                                    orderController
                                                        .changeDeliveryImageStatus();
                                                    if (kDebugMode) {
                                                      print(
                                                        '=====jjj : ${Get.find<SplashController>().configModel!.dmPictureUploadStatus!}',
                                                      );
                                                    }
                                                    if (Get.find<
                                                          SplashController
                                                        >()
                                                        .configModel!
                                                        .dmPictureUploadStatus!) {
                                                      Get.dialog(
                                                        const DialogImageWidget(),
                                                        barrierDismissible:
                                                            false,
                                                      );
                                                    }
                                                  } else {
                                                    nextStatus =
                                                        AppConstants.delivered;
                                                  }
                                                }

                                                if (nextStatus != null) {
                                                  Get.find<OrderController>()
                                                      .updateOrderStatus(
                                                        controllerOrderModel.id,
                                                        nextStatus,
                                                      );
                                                }
                                              },
                                              label: Text(
                                                (controllerOrderModel
                                                                .orderStatus ==
                                                            'pending' &&
                                                        (controllerOrderModel
                                                                    .orderType ==
                                                                'take_away' ||
                                                            restConfModel ||
                                                            selfDelivery))
                                                    ? 'swipe_to_confirm_order'
                                                          .tr
                                                    : (controllerOrderModel
                                                                  .orderStatus ==
                                                              'confirmed' ||
                                                          (controllerOrderModel
                                                                      .orderStatus ==
                                                                  'accepted' &&
                                                              controllerOrderModel
                                                                      .confirmed !=
                                                                  null))
                                                    ? 'swipe_to_deliver_order'
                                                          .tr
                                                    : (controllerOrderModel
                                                                  .orderStatus ==
                                                              'processing' ||
                                                          controllerOrderModel
                                                                  .orderStatus ==
                                                              'cooking')
                                                    ? 'swipe_if_ready_for_handover'
                                                          .tr
                                                    : (controllerOrderModel
                                                              .orderStatus ==
                                                          'handover')
                                                    ? 'swipe_to_deliver_order'
                                                          .tr
                                                    : '',
                                                style: robotoMedium.copyWith(
                                                  fontSize:
                                                      Dimensions.fontSizeLarge,
                                                  color: Theme.of(
                                                    context,
                                                  ).primaryColor,
                                                ),
                                              ),
                                              dismissThresholds: 0.5,
                                              dismissible: false,
                                              shimmer: true,
                                              width: 1170,
                                              height: 50,
                                              buttonSize: 45,
                                              radius: 10,
                                              icon: Center(
                                                child: Icon(
                                                  Get.find<
                                                            LocalizationController
                                                          >()
                                                          .isLtr
                                                      ? Icons.double_arrow_sharp
                                                      : Icons
                                                            .keyboard_arrow_left,
                                                  color: Colors.white,
                                                  size: 20.0,
                                                ),
                                              ),
                                              isLtr:
                                                  Get.find<
                                                        LocalizationController
                                                      >()
                                                      .isLtr,
                                              boxShadow: const BoxShadow(
                                                blurRadius: 0,
                                              ),
                                              buttonColor: Theme.of(
                                                context,
                                              ).primaryColor,
                                              backgroundColor: const Color(
                                                0xffF4F7FC,
                                              ),
                                              baseColor: Theme.of(
                                                context,
                                              ).primaryColor,
                                            ),
                                          )
                                  : const SizedBox()
                            : const SizedBox(),

                        /// Print Invoice
                        // if(Platform.isAndroid)
                        //   Padding(
                        //     padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                        //     child: CustomButtonWidget(
                        //       onPressed: () {
                        //         _allowPermission().then((access) {
                        //           Get.dialog(Dialog(
                        //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusSmall)),
                        //             child: InVoicePrintScreen(order: order, orderDetails: orderController.orderDetailsModel, isPrescriptionOrder: isPrescriptionOrder, dmTips: dmTips!),
                        //           ));
                        //         });
                        //       },
                        //       icon: Icons.local_print_shop,
                        //       buttonText: 'print_invoice'.tr,
                        //     ),
                        //   ),
                      ],
                    )
                  : const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
    );
  }

  void openDialog(BuildContext context, String imageUrl) => showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              child: PhotoView(
                tightMode: true,
                imageProvider: NetworkImage(imageUrl),
                heroAttributes: PhotoViewHeroAttributes(tag: imageUrl),
              ),
            ),

            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                splashRadius: 5,
                onPressed: () => Get.back(),
                icon: const Icon(Icons.cancel, color: Colors.red),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<bool> _allowPermission() async {
  if (!await _requestAndCheckPermission(Permission.location)) {
    return false;
  }
  if (!await _requestAndCheckPermission(Permission.bluetooth)) {
    return false;
  }
  if (!await _requestAndCheckPermission(Permission.bluetoothConnect)) {
    return false;
  }
  if (!await _requestAndCheckPermission(Permission.bluetoothScan)) {
    return false;
  }

  return true;
}

Future<bool> _requestAndCheckPermission(Permission permission) async {
  await permission.request();
  var status = await permission.status;
  return !status.isDenied;
}
