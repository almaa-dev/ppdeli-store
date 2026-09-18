import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'package:ppdelistore/common/widgets/custom_button_widget.dart';
import 'package:ppdelistore/common/widgets/custom_snackbar_widget.dart';
import 'package:ppdelistore/features/order/widgets/invoice_dialog_widget.dart';
import 'package:ppdelistore/features/order/domain/models/order_details_model.dart';
import 'package:ppdelistore/features/order/domain/models/order_model.dart';
import 'package:ppdelistore/features/printer/domain/models/printer_model.dart';
import 'package:ppdelistore/features/printer/helper/printer_helper.dart';
import 'package:ppdelistore/features/printer/presentation/printer_controller.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';

/// Screen that lets the user print the current order invoice.
///
/// Layout (matches the original / pre-refactor version):
///   * Header row: "Paired Bluetooth" + refresh + paper size dropdown.
///   * List of paired Bluetooth devices; tap a row to connect.
///   * On-screen preview of the invoice (driven by the same
///     [InvoiceDialogWidget] used before the refactor - it remains the
///     visual reference for the printed output).
///   * "Print Invoice" button at the bottom.
///
/// **The print pipeline no longer relies on a Flutter screenshot.**
/// Instead of capturing the widget as a PNG, decoding it, resizing it
/// and rasterising it, we ask [PrinterHelper.buildInvoiceBytes] to
/// walk the [OrderModel] and emit native ESC/POS text commands. The
/// result is dramatically smaller (~3-6 KB instead of ~150-600 KB)
/// and therefore much faster to push over Bluetooth.
///
/// Connection / persistence are delegated to the global
/// [PrinterController].
class InVoicePrintScreen extends StatefulWidget {
  final OrderModel? order;
  final List<OrderDetailsModel>? orderDetails;
  final bool? isPrescriptionOrder;
  final double dmTips;
  const InVoicePrintScreen({
    super.key,
    required this.order,
    required this.orderDetails,
    this.isPrescriptionOrder = false,
    required this.dmTips,
  });

  @override
  State<InVoicePrintScreen> createState() => _InVoicePrintScreenState();
}

class _InVoicePrintScreenState extends State<InVoicePrintScreen> {
  /// The global printer controller. Used for status and persistence
  /// (e.g. when the user taps a printer to connect).
  final PrinterController _printerController = Get.find<PrinterController>();

  /// List of paired Bluetooth devices (from the OS or the controller's
  /// cached list).
  List<BluetoothInfo>? availableBluetoothDevices;
  bool _isLoading = false;
  final List<int> _paperSizeList = [80, 58];
  int _selectedSize = 80;
  String? _warningMessage;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    getBluetooth();
  }

  /// Reads the paired Bluetooth devices via the legacy plugin API as a
  /// last-resort source (in case the controller's cached list is empty).
  Future<void> getBluetooth() async {
    setState(() {
      _isLoading = true;
    });

    final List<BluetoothInfo> bluetoothDevices =
        await PrintBluetoothThermal.pairedBluetooths;
    if (kDebugMode) {
      print('Bluetooth list: $bluetoothDevices');
    }
    // Warning is shown only when no paired devices are visible to the app.
    if (bluetoothDevices.isEmpty) {
      _warningMessage =
          'please_enable_your_location_and_bluetooth_in_your_system'.tr;
    } else {
      _warningMessage = null;
    }

    setState(() {
      availableBluetoothDevices = bluetoothDevices;
      _isLoading = false;
    });
  }

  /// Connects to a printer by MAC. Preserves the previous behavior of
  /// updating the controller's `connectedMac` so the rest of the app
  /// sees the new connection.
  Future<void> setConnect(String mac) async {
    final bool result = await PrintBluetoothThermal.connect(
      macPrinterAddress: mac,
    );

    if (result) {
      _printerController.connectedMac.value = mac;
      await _printerController.refreshStatus();
    }
    if (mounted) setState(() {});
  }

  /// Builds the ESC/POS byte stream for the invoice and pushes it to
  /// the currently connected printer. The whole flow is text-based -
  /// no screenshot, no PNG, no raster.
  Future<void> _printReceipt() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      // Validate connection up-front so we don't waste time building
      // bytes for a printer that isn't reachable.
      final bool connectionStatus =
          await PrintBluetoothThermal.connectionStatus;
      if (!connectionStatus) {
        showCustomSnackBar('no_thermal_printer_connected'.tr, isError: true);
        return;
      }

      PrinterModel? target = _printerController.defaultPrinter.value;
      // Fall back to the controller's `connectedMac` lookup so we don't
      // force the operator to mark a printer as default just to print.
      target ??= _printerController.printers.firstWhereOrNull(
        (PrinterModel p) => p.address == _printerController.connectedMac.value,
      );
      if (target == null) {
        showCustomSnackBar('no_default_printer'.tr, isError: true);
        return;
      }

      final Stopwatch sw = Stopwatch()..start();
      final List<int> invoiceBytes = await PrinterHelper.buildInvoiceBytes(
        order: widget.order,
        orderDetails: widget.orderDetails,
        isPrescriptionOrder: widget.isPrescriptionOrder ?? false,
        dmTips: widget.dmTips,
        paperSize: _selectedSize == 80 ? '80mm' : '58mm',
        printer: target,
        debugTiming: kDebugMode,
        // Surface the configurable Additional Charge label so the
        // printed totals block matches the on-screen preview.
        additionalChargeName:
            Get.find<SplashController>().configModel?.additionalChargeName,
      );
      sw.stop();
      if (kDebugMode) {
        print(
          '[Print] invoice build: ${sw.elapsedMilliseconds}ms, '
          '${invoiceBytes.length} bytes',
        );
      }

      if (invoiceBytes.isEmpty) {
        showCustomSnackBar('print_failed'.tr, isError: true);
        return;
      }

      // The ticket already ends with the ESC/POS paper cut — it is
      // appended inside [PrinterHelper.buildInvoiceBytes] so that BOTH
      // this manual print flow and the auto-print flow in
      // `OrderDetailsScreen` cut the paper. We must NOT append a second
      // cut here or the printer double-cuts and ejects a blank slip.
      final Stopwatch writeSw = Stopwatch()..start();
      final bool result = await PrintBluetoothThermal.writeBytes(invoiceBytes);
      writeSw.stop();
      if (kDebugMode) {
        print(
          '[Print] bluetooth write: ${writeSw.elapsedMilliseconds}ms, '
          'result=$result',
        );
      }
      if (!result) {
        showCustomSnackBar('print_failed'.tr, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeDefault,
            vertical: Dimensions.paddingSizeDefault,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'paired_bluetooth'.tr,
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeDefault,
                    ),
                  ),
                  const SizedBox(width: Dimensions.paddingSizeExtraSmall / 3),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : InkWell(
                            onTap: () => getBluetooth(),
                            child: const Icon(Icons.refresh, size: 20),
                          ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 60,
                child: DropdownButton<int>(
                  hint: Text('select'.tr),
                  value: _selectedSize,
                  items: _paperSizeList.map((int? value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text(
                        '$value'
                        'mm',
                        style: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeSmall,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (int? value) {
                    setState(() {
                      _selectedSize = value!;
                    });
                  },
                  isExpanded: true,
                  underline: const SizedBox(),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                availableBluetoothDevices != null &&
                        (availableBluetoothDevices?.length ?? 0) > 0
                    ? ListView.builder(
                        itemCount: availableBluetoothDevices?.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (BuildContext context, int index) {
                          final String mac =
                              availableBluetoothDevices![index].macAdress;
                          return Obx(() {
                            final bool isConnected =
                                _printerController.connectedMac.value == mac;
                            return Stack(
                              children: [
                                ListTile(
                                  onTap: () => setConnect(mac),
                                  dense: true,
                                  title: Text(
                                    availableBluetoothDevices![index].name,
                                    style: robotoMedium.copyWith(
                                      fontSize: Dimensions.fontSizeSmall,
                                    ),
                                  ),
                                  subtitle: Text(
                                    isConnected
                                        ? 'connected'.tr
                                        : 'click_to_connect'.tr,
                                    style: robotoRegular.copyWith(
                                      color: isConnected
                                          ? null
                                          : Theme.of(context).primaryColor,
                                      fontSize: Dimensions.fontSizeSmall,
                                    ),
                                  ),
                                ),
                                if (isConnected)
                                  Positioned.fill(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical:
                                              Dimensions.paddingSizeExtraSmall,
                                          horizontal:
                                              Dimensions.paddingSizeLarge,
                                        ),
                                        child: Icon(
                                          Icons.check_circle_outline_outlined,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          });
                        },
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeSmall,
                        ),
                        child: Text(
                          _warningMessage ?? '',
                          style: robotoRegular.copyWith(
                            color: Colors.redAccent,
                          ),
                        ),
                      ),

                InvoiceDialogWidget(
                  order: widget.order,
                  orderDetails: widget.orderDetails,
                  isPrescriptionOrder: widget.isPrescriptionOrder,
                  paper80MM: _selectedSize == 80,
                  dmTips: widget.dmTips,
                ),
              ],
            ),
          ),
        ),

        CustomButtonWidget(
          buttonText: 'print_invoice'.tr,
          height: 40,
          isLoading: _isPrinting,
          margin: const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeSmall,
            vertical: Dimensions.paddingSizeExtraSmall,
          ),
          onPressed: _isPrinting ? null : _printReceipt,
        ),
      ],
    );
  }
}
