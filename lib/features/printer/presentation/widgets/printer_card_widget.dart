import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:ppdelistore/common/widgets/confirmation_dialog_widget.dart';
import 'package:ppdelistore/features/printer/domain/models/printer_model.dart';
import 'package:ppdelistore/features/printer/presentation/printer_controller.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';
import 'package:ppdelistore/util/styles.dart';

/// A self-contained card that renders a single [PrinterModel] and exposes
/// connect / disconnect / set-default / delete actions.
class PrinterCardWidget extends StatelessWidget {
  final PrinterModel printer;
  final PrinterController controller;
  const PrinterCardWidget({
    super.key,
    required this.printer,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final PrinterUiStatus status = controller.getUiStatus(printer);
      final bool isConnected = status == PrinterUiStatus.connected;
      final bool isConnecting =
          status == PrinterUiStatus.connecting || controller.connecting.value;
      final bool isBluetoothOff =
          status == PrinterUiStatus.bluetoothOff ||
          status == PrinterUiStatus.permissionDenied;
      final PrinterModel? currentDefault = controller.defaultPrinter.value;
      final bool isDefault =
          printer.isDefault || (currentDefault?.address == printer.address);

      return Container(
        margin: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeDefault,
          vertical: Dimensions.paddingSizeSmall,
        ),
        padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
          border: Border.all(
            color: isDefault
                ? Theme.of(context).primaryColor
                : Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: isDefault ? 1.5 : 1.0,
          ),
          boxShadow: Get.isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: printer icon + name + default badge + delete button
            Row(
              children: [
                Icon(
                  Icons.print_outlined,
                  color: isDefault
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).disabledColor,
                  size: 28,
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(
                  child: Text(
                    printer.name,
                    style: robotoBold.copyWith(
                      fontSize: Dimensions.fontSizeLarge,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeSmall,
                      vertical: Dimensions.paddingSizeExtraSmall / 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusDefault,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'default_printer_badge'.tr,
                          style: robotoMedium.copyWith(
                            color: Colors.white,
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 22,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'remove_printer'.tr,
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),

            const SizedBox(height: Dimensions.paddingSizeSmall),

            // MAC address
            Row(
              children: [
                Text(
                  '${'mac_address'.tr}: ',
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Theme.of(context).disabledColor,
                  ),
                ),
                Expanded(
                  child: Text(
                    printer.address,
                    style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: Dimensions.paddingSizeExtraSmall),

            // Status row
            Row(
              children: [
                Text(
                  '${'status'.tr}: ',
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Theme.of(context).disabledColor,
                  ),
                ),
                _StatusIndicator(status: status),
              ],
            ),

            const SizedBox(height: Dimensions.paddingSizeExtraSmall),

            // Paper size selector
            Row(
              children: [
                Text(
                  '${'paper_size'.tr}: ',
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Theme.of(context).disabledColor,
                  ),
                ),
                _PaperSizeChip(
                  currentSize: printer.printerType,
                  onChanged: (String size) =>
                      controller.setPrinterPaperSize(printer, size),
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                if (printer.connectionCount > 0)
                  Text(
                    '${'connections_count'.tr}: ${printer.connectionCount}',
                    style: robotoRegular.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
              ],
            ),

            if (printer.lastConnected != null) ...[
              const SizedBox(height: Dimensions.paddingSizeExtraSmall),
              Row(
                children: [
                  Text(
                    '${'last_connected'.tr}: ',
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatTimestamp(printer.lastConnected!),
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (printer.lastPrintSuccess != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    '${'last_print'.tr}: ',
                    style: robotoMedium.copyWith(
                      fontSize: Dimensions.fontSizeSmall,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatTimestamp(printer.lastPrintSuccess!),
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: Dimensions.paddingSizeDefault),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: isConnected ? 'disconnect'.tr : 'connect'.tr,
                    icon: isConnected ? Icons.link_off : Icons.link,
                    color: isConnected
                        ? Colors.red
                        : Theme.of(context).primaryColor,
                    isLoading:
                        isConnecting &&
                        controller.connectedMac.value == printer.address,
                    enabled: !isBluetoothOff && !isConnecting,
                    onTap: () async {
                      if (isConnected) {
                        await controller.disconnectPrinter();
                      } else {
                        await controller.connectPrinter(printer);
                      }
                    },
                  ),
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Expanded(
                  child: _ActionButton(
                    label: isDefault ? 'is_default'.tr : 'set_default'.tr,
                    icon: isDefault
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: isDefault
                        ? Theme.of(context).disabledColor
                        : Colors.amber.shade700,
                    enabled: !isDefault,
                    onTap: isDefault
                        ? null
                        : () => controller.setDefaultPrinter(printer),
                  ),
                ),
              ],
            ),

            if (isDefault) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              SizedBox(
                width: double.infinity,
                child: _ActionButton(
                  label: 'print_test'.tr,
                  icon: Icons.print_outlined,
                  color: Theme.of(context).primaryColor,
                  enabled: !controller.printing.value && !isBluetoothOff,
                  isLoading: controller.printing.value,
                  onTap: () => controller.printTest(printer: printer),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  String _formatTimestamp(String iso) {
    try {
      final DateTime dt = DateTime.parse(iso);
      return dt.toLocal().toString().split('.').first;
    } catch (_) {
      return iso;
    }
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog<void>(
      ConfirmationDialogWidget(
        icon: Images.warning,
        title: 'remove_printer'.tr,
        description: 'remove_printer_confirm'.tr,
        onYesPressed: () async {
          Get.back();
          await controller.removePrinter(printer);
        },
      ),
      useSafeArea: false,
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final PrinterUiStatus status;
  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String text;
    final IconData icon;
    switch (status) {
      case PrinterUiStatus.connected:
        color = Colors.green;
        text = 'connected'.tr;
        icon = Icons.check_circle;
        break;
      case PrinterUiStatus.connecting:
        color = Colors.amber;
        text = 'connecting'.tr;
        icon = Icons.sync;
        break;
      case PrinterUiStatus.scanning:
        color = Colors.blue;
        text = 'scanning'.tr;
        icon = Icons.bluetooth_searching;
        break;
      case PrinterUiStatus.printing:
        color = Colors.deepPurple;
        text = 'printing'.tr;
        icon = Icons.print;
        break;
      case PrinterUiStatus.printFailed:
        color = Colors.redAccent;
        text = 'print_failed'.tr;
        icon = Icons.error_outline;
        break;
      case PrinterUiStatus.ready:
        color = Colors.green;
        text = 'ready'.tr;
        icon = Icons.check_circle_outline;
        break;
      case PrinterUiStatus.disconnected:
        color = Colors.red;
        text = 'not_connected'.tr;
        icon = Icons.radio_button_unchecked;
        break;
      case PrinterUiStatus.bluetoothOff:
        color = Colors.grey;
        text = 'bluetooth_off'.tr;
        icon = Icons.bluetooth_disabled;
        break;
      case PrinterUiStatus.permissionDenied:
        color = Colors.deepOrange;
        text = 'permission_denied'.tr;
        icon = Icons.lock_outline;
        break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: robotoMedium.copyWith(
            color: color,
            fontSize: Dimensions.fontSizeSmall,
          ),
        ),
      ],
    );
  }
}

class _PaperSizeChip extends StatelessWidget {
  final String currentSize;
  final ValueChanged<String> onChanged;
  const _PaperSizeChip({required this.currentSize, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final String value = (currentSize == '58mm' || currentSize == '58_mm')
        ? '58mm'
        : '80mm';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      ),
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        underline: const SizedBox(),
        items: <String>['58mm', '80mm'].map((String size) {
          return DropdownMenuItem<String>(
            value: size,
            child: Text(
              size,
              style: robotoMedium.copyWith(
                fontSize: Dimensions.fontSizeSmall,
                color: Theme.of(context).primaryColor,
              ),
            ),
          );
        }).toList(),
        onChanged: (String? newSize) {
          if (newSize != null && newSize != value) {
            onChanged(newSize);
          }
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool enabled;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = enabled ? color : Theme.of(context).disabledColor;
    return InkWell(
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      onTap: (!enabled || isLoading) ? null : onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: robotoMedium.copyWith(
                        color: Colors.white,
                        fontSize: Dimensions.fontSizeSmall,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
