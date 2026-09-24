import 'package:image_picker/image_picker.dart';
import 'package:ppdelistore/common/models/response_model.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/api/api_client.dart';
import 'package:ppdelistore/features/order/domain/models/update_status_body_model.dart';
import 'package:ppdelistore/features/order/domain/models/order_cancellation_body_model.dart';
import 'package:ppdelistore/features/order/domain/models/order_details_model.dart';
import 'package:ppdelistore/features/order/domain/models/order_model.dart';
import 'package:ppdelistore/features/order/domain/models/running_order_model.dart';
import 'package:ppdelistore/common/widgets/custom_snackbar_widget.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/features/order/domain/services/order_service_interface.dart';
import 'package:ppdelistore/helper/route_helper.dart';

class OrderController extends GetxController implements GetxService {
  final OrderServiceInterface orderServiceInterface;
  OrderController({required this.orderServiceInterface});

  List<OrderModel>? _orderList;
  List<OrderModel>? get orderList => _orderList;

  List<OrderModel>? _runningOrderList;
  List<OrderModel>? get runningOrderList => _runningOrderList;

  List<RunningOrderModel>? _runningOrders;
  List<RunningOrderModel>? get runningOrders => _runningOrders;

  List<OrderModel>? _historyOrderList;
  List<OrderModel>? get historyOrderList => _historyOrderList;

  List<OrderDetailsModel>? _orderDetailsModel;
  List<OrderDetailsModel>? get orderDetailsModel => _orderDetailsModel;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _orderIndex = 0;
  int get orderIndex => _orderIndex;

  String _otp = '';
  String get otp => _otp;

  int _historyIndex = 0;
  int get historyIndex => _historyIndex;

  // final List<String> _statusList = ['all', 'delivered', 'refunded', 'canceled'];
    final List<String> _statusList = [
    'all',
    'confirmed',
    'handover',
    'delivered',
    'pickedup',
    'canceled',
  ];

  List<String> get statusList => _statusList;

  bool _paginate = false;
  bool get paginate => _paginate;

  int? _pageSize;
  int? get pageSize => _pageSize;

  List<int> _offsetList = [];

  int _offset = 1;
  int get offset => _offset;

  String _orderType = 'all';
  String get orderType => _orderType;

  OrderModel? _orderModel;
  OrderModel? get orderModel => _orderModel;

  List<Data>? _orderCancelReasons;
  List<Data>? get orderCancelReasons => _orderCancelReasons;

  String? _cancelReason = '';
  String? get cancelReason => _cancelReason;

  bool _showDeliveryImageField = false;
  bool get showDeliveryImageField => _showDeliveryImageField;

  List<XFile> _pickedPrescriptions = [];
  List<XFile> get pickedPrescriptions => _pickedPrescriptions;

  bool _hideNotificationButton = false;
  bool get hideNotificationButton => _hideNotificationButton;

  Future<bool> sendDeliveredNotification(int? orderID) async {
    _hideNotificationButton = true;
    update();
    bool isSuccess = await orderServiceInterface.sendDeliveredNotification(
      orderID,
    );
    _hideNotificationButton = false;
    update();
    return isSuccess;
  }

  void changeDeliveryImageStatus({bool isUpdate = true}) {
    _showDeliveryImageField = !_showDeliveryImageField;
    if (isUpdate) {
      update();
    }
  }

  void pickPrescriptionImage({
    required bool isRemove,
    required bool isCamera,
  }) async {
    if (isRemove) {
      _pickedPrescriptions = [];
    } else {
      XFile? xFile = await ImagePicker().pickImage(
        source: isCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 50,
      );
      if (xFile != null) {
        _pickedPrescriptions.add(xFile);
        if (Get.isDialogOpen!) {
          Get.back();
        }
      }
      update();
    }
  }

  void removePrescriptionImage(int index) {
    _pickedPrescriptions.removeAt(index);
    update();
  }

  void setOrderCancelReason(String? reason) {
    _cancelReason = reason;
    update();
  }

  Future<void> getOrderCancelReasons() async {
    OrderCancellationBodyModel? orderCancellationBody =
        await orderServiceInterface.getCancelReasons();
    if (orderCancellationBody != null) {
      _orderCancelReasons = [];
      for (var element in orderCancellationBody.data!) {
        _orderCancelReasons!.add(element);
      }
    }
    update();
  }

  void clearPreviousData() {
    _orderDetailsModel = null;
    _orderModel = null;
  }

  Future<void> getOrderDetails(int orderId) async {
    OrderModel? orderModel = await orderServiceInterface.getOrderWithId(
      orderId,
    );
    if (orderModel != null) {
      _orderModel = orderModel;
    }
    update();
  }

  Future<void> getCurrentOrders() async {
    List<OrderModel>? runningOrderList = await orderServiceInterface
        .getCurrentOrders();
    if (runningOrderList != null) {
      _runningOrderList = [];
      _runningOrders = [
        RunningOrderModel(status: 'pending', orderList: []),
        RunningOrderModel(status: 'confirmed', orderList: []),
        RunningOrderModel(status: 'ready_for_handover', orderList: []),
        RunningOrderModel(status: 'food_on_the_way', orderList: []),
        RunningOrderModel(status: 'food_on_pickedup', orderList: []),
        RunningOrderModel(status: 'canceled', orderList: []),
      ];
      _runningOrderList!.addAll(runningOrderList);
      _populateRunningOrders();
    }
    update();
  }

  Future<void> getPaginatedOrders(int offset, bool reload) async {
    if (offset == 1 || reload) {
      _offsetList = [];
      _offset = 1;
      if (reload) {
        _historyOrderList = null;
      }
      update();
    }
    if (!_offsetList.contains(offset)) {
      _offsetList.add(offset);
      PaginatedOrderModel? historyOrderModel = await orderServiceInterface
          .getPaginatedOrderList(offset, _statusList[_historyIndex]);
      if (historyOrderModel != null) {
        if (offset == 1) {
          _historyOrderList = [];
        }
        _historyOrderList!.addAll(historyOrderModel.orders!);
        _pageSize = historyOrderModel.totalSize;
        _paginate = false;
        update();
      }
    } else {
      if (_paginate) {
        _paginate = false;
        update();
      }
    }
  }

  void showBottomLoader() {
    _paginate = true;
    update();
  }

  void setOffset(int offset) {
    _offset = offset;
  }

  void setOrderType(String type) {
    _orderType = type;
    getPaginatedOrders(1, true);
  }

  Future<bool> updateOrderStatus(
    int? orderID,
    String status, {
    bool back = false,
    String? reason,
    String? processingTime,
    bool fromNotification = false,
    bool silent = false,
  }) async {
    _isLoading = true;
    update();
    List<MultipartBody> pickedPrescriptions = orderServiceInterface
        .processMultipartData(_pickedPrescriptions);
    UpdateStatusBodyModel updateStatusBody = UpdateStatusBodyModel(
      orderId: orderID,
      status: status,
      otp: status == 'delivered' ? _otp : null,
      processingTime: processingTime,
      reason: reason,
    );
    ResponseModel responseModel = await orderServiceInterface.updateOrderStatus(
      updateStatusBody,
      pickedPrescriptions,
    );
    // Only close dialog if one is open (like confirmation dialogs)
    if (Get.isDialogOpen == true) {
      Get.back(result: responseModel.isSuccess);
    }
    if (responseModel.isSuccess) {
      if (back && fromNotification) {
        Get.offAllNamed(RouteHelper.getInitialRoute());
      } else if (back && !fromNotification) {
        Get.back();
      }
      getCurrentOrders();
      Get.find<ProfileController>().getProfile();
      if (!silent) {
        showCustomSnackBar(responseModel.message, isError: false);
      }
    } else {
      if (!silent) {
        showCustomSnackBar(responseModel.message, isError: true);
      }
    }
    _isLoading = false;
    update();
    return responseModel.isSuccess;
  }

  Future<bool> updateOrderAmount(
    int orderID,
    String amount,
    bool isItemPrice,
  ) async {
    _isLoading = true;
    update();
    Map<String, String> body = <String, String>{};
    if (isItemPrice) {
      body['_method'] = 'PUT';
      body['order_id'] = orderID.toString();
      body['order_amount'] = amount;
    } else {
      body['_method'] = 'PUT';
      body['order_id'] = orderID.toString();
      body['discount_amount'] = amount;
    }
    ResponseModel responseModel = await orderServiceInterface.updateOrderAmount(
      body,
    );
    if (responseModel.isSuccess) {
      await getOrderDetails(orderID);
      Get.back();
      showCustomSnackBar(responseModel.message, isError: false);
    } else {
      showCustomSnackBar(responseModel.message, isError: true);
    }
    _isLoading = false;
    update();
    return responseModel.isSuccess;
  }

  Future<void> getOrderItemsDetails(int orderID) async {
    _orderDetailsModel = null;
    if (_orderModel != null && !_orderModel!.prescriptionOrder!) {
      List<OrderDetailsModel>? orderDetailsModel = await orderServiceInterface
          .getOrderDetails(orderID);
      if (orderDetailsModel != null) {
        _orderDetailsModel = [];
        _orderDetailsModel!.addAll(orderDetailsModel);
      }
      update();
    } else {
      _orderDetailsModel = [];
    }
  }

  void setOrderIndex(int index) {
    _orderIndex = index;
    update();
  }

  void _populateRunningOrders() {
    _runningOrders![0].orderList = [];
    _runningOrders![1].orderList = [];
    _runningOrders![2].orderList = [];
    _runningOrders![3].orderList = [];
    _runningOrders![4].orderList = [];
    _runningOrders![5].orderList = [];
    for (var order in _runningOrderList!) {
      if (order.orderStatus == 'pending' &&
          (Get.find<SplashController>().configModel!.orderConfirmationModel !=
                  'deliveryman' ||
              order.orderType == 'take_away' ||
              Get.find<ProfileController>()
                      .profileModel!
                      .stores![0]
                      .selfDeliverySystem ==
                  1)) {
        _runningOrders![0].orderList.add(order);
      } else if ((order.orderStatus == 'confirmed' ||
          (order.orderStatus == 'accepted' && order.confirmed != null))) {
        _runningOrders![1].orderList.add(order);
      } else if (order.orderStatus == 'processing' ||
          order.orderStatus == 'handover' ||
          order.orderStatus == 'cooking') {
        // Cooking tab removed: collapse processing/cooking/handover into ready_for_handover
        _runningOrders![2].orderList.add(order);
      } else if (order.orderStatus == 'delivered' &&
          order.orderType == 'delivery') {
        _runningOrders![3].orderList.add(order);
      }  else if (order.orderStatus == 'delivered' &&
          order.orderType == 'take_away') {
        _runningOrders![4].orderList.add(order);
      } else if (order.orderStatus == 'canceled') {
        _runningOrders![5].orderList.add(order);
      }
    }
  }

  void setOtp(String otp) {
    _otp = otp;
    if (otp != '') {
      update();
    }
  }

  void setHistoryIndex(int index) {
    _historyIndex = index;
    getPaginatedOrders(offset, true);
    update();
  }

  String? getBluetoothMacAddress() =>
      orderServiceInterface.getBluetoothAddress();

  void setBluetoothMacAddress(String? address) =>
      orderServiceInterface.setBluetoothAddress(address);
}
