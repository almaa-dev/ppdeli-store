import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:ppdelistore/common/widgets/custom_button_widget.dart';
import 'package:ppdelistore/common/widgets/custom_snackbar_widget.dart';
import 'package:ppdelistore/features/printer/domain/models/printer_model.dart';
import 'package:ppdelistore/features/printer/presentation/printer_controller.dart';
import 'package:ppdelistore/features/printer/presentation/printer_diagnostics_screen.dart';
import 'package:ppdelistore/features/printer/presentation/widgets/printer_card_widget.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';

/// Main screen that lists the user's Bluetooth printers.
class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  final PrinterController controller = Get.find<PrinterController>();

  @override
  void initState() {
    super.initState();
    // Refresh Bluetooth + connection state when the user opens this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await controller.refreshStatus();
      await controller.scanPrinters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('printers'.tr),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0.5,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'diagnostics_title'.tr,
            onPressed: () =>
                Get.to<void>(() => const PrinterDiagnosticsScreen()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.scanPrinters(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _StatusHeader(),
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeDefault,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: CustomButtonWidget(
                        buttonText: 'scan_printers'.tr,
                        icon: Icons.search,
                        height: 45,
                        isLoading: controller.scanning.value,
                        onPressed: () => controller.scanPrinters(),
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    Expanded(
                      child: CustomButtonWidget(
                        buttonText: 'add_manually'.tr,
                        icon: Icons.add,
                        height: 45,
                        onPressed: () => _showAddManuallyDialog(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Dimensions.paddingSizeDefault),
              Obx(() {
                final List<PrinterModel> printers = controller.printers
                    .toList();
                if (controller.scanning.value && printers.isEmpty) {
                  return const _SearchingPlaceholder();
                }
                if (printers.isEmpty) {
                  return _EmptyState(onScan: controller.scanPrinters);
                }
                return Column(
                  children: printers
                      .map(
                        (p) => PrinterCardWidget(
                          printer: p,
                          controller: controller,
                        ),
                      )
                      .toList(),
                );
              }),
              const SizedBox(height: Dimensions.paddingSizeExtraLarge),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddManuallyDialog(BuildContext context) async {
    final TextEditingController macController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    String paperSize = '80mm';
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    await Get.dialog<void>(
      AlertDialog(
        title: Text('add_printer_manually'.tr),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'add_printer_hint'.tr,
                  style: robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeSmall,
                    color: Theme.of(context).disabledColor,
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'printer_name'.tr,
                    hintText: 'printer_name_hint'.tr,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                TextFormField(
                  controller: macController,
                  decoration: InputDecoration(
                    labelText: 'mac_address'.tr,
                    hintText: '00:11:22:33:44:55',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'mac_address_required'.tr;
                    }
                    final RegExp re = RegExp(
                      r'^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$',
                    );
                    if (!re.hasMatch(value.trim())) {
                      return 'invalid_mac_address'.tr;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: Dimensions.paddingSizeSmall),
                DropdownButtonFormField<String>(
                  initialValue: paperSize,
                  decoration: InputDecoration(
                    labelText: 'paper_size'.tr,
                    border: const OutlineInputBorder(),
                  ),
                  items: <String>['58mm', '80mm'].map((String size) {
                    return DropdownMenuItem<String>(
                      value: size,
                      child: Text(size),
                    );
                  }).toList(),
                  onChanged: (String? v) {
                    if (v != null) {
                      paperSize = v;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Get.back<void>(),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }
              Get.back<void>();
              await controller.addPrinterManually(
                mac: macController.text,
                name: nameController.text,
                paperSize: paperSize,
              );
            },
            child: Text('add'.tr),
          ),
        ],
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader();

  @override
  Widget build(BuildContext context) {
    final PrinterController controller = Get.find<PrinterController>();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Obx(() {
        final bool bluetoothOn = controller.bluetoothEnabled.value;
        final bool perms = controller.permissionsGranted.value;
        final PrinterModel? def = controller.defaultPrinter.value;
        final bool defConnected =
            def != null && controller.connectedMac.value == def.address;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Bluetooth row — tappable so the user can enable Bluetooth
            // or refresh the adapter state from the printer screen.
            InkWell(
              onTap: () async {
                if (bluetoothOn) {
                  await controller.refreshAdapterNow();
                  if (!context.mounted) {
                    return;
                  }
                  showCustomSnackBar('bluetooth_refreshed'.tr, isError: false);
                } else {
                  await controller.openBluetoothSettings();
                }
              },
              borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    Icon(
                      bluetoothOn ? Icons.bluetooth : Icons.bluetooth_disabled,
                      color: bluetoothOn ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    Expanded(
                      child: Text(
                        'bluetooth'.tr,
                        style: robotoMedium.copyWith(
                          fontSize: Dimensions.fontSizeDefault,
                        ),
                      ),
                    ),
                    Text(
                      bluetoothOn ? 'enabled'.tr : 'disabled'.tr,
                      style: robotoMedium.copyWith(
                        color: bluetoothOn ? Colors.green : Colors.red,
                        fontSize: Dimensions.fontSizeDefault,
                      ),
                    ),
                    const SizedBox(width: Dimensions.paddingSizeSmall),
                    Icon(
                      bluetoothOn ? Icons.refresh : Icons.settings_bluetooth,
                      size: 18,
                      color: bluetoothOn
                          ? Colors.green
                          : Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
            ),
            // When Bluetooth is OFF, surface a clear, single-tap CTA so
            // the user can enable it without leaving the printers screen.
            if (!bluetoothOn)
              Padding(
                padding: const EdgeInsets.only(
                  left: 28,
                  top: Dimensions.paddingSizeExtraSmall,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => controller.openBluetoothSettings(),
                    icon: const Icon(Icons.power_settings_new, size: 18),
                    label: Text('turn_on_bluetooth'.tr),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeSmall,
                        vertical: 0,
                      ),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
            Row(
              children: <Widget>[
                Icon(
                  perms ? Icons.lock_open : Icons.lock_outline,
                  color: perms ? Colors.green : Colors.deepOrange,
                  size: 18,
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Text(
                  'permission_status'.tr,
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                  ),
                ),
                const Spacer(),
                Text(
                  perms ? 'diagnostic_granted'.tr : 'diagnostic_missing'.tr,
                  style: robotoMedium.copyWith(
                    color: perms ? Colors.green : Colors.deepOrange,
                    fontSize: Dimensions.fontSizeDefault,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),
            Row(
              children: <Widget>[
                Icon(
                  Icons.print_outlined,
                  color: def != null
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).disabledColor,
                ),
                const SizedBox(width: Dimensions.paddingSizeSmall),
                Text(
                  'default_printer'.tr,
                  style: robotoMedium.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Dimensions.paddingSizeExtraSmall),
            if (def != null)
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      def.name,
                      style: robotoBold.copyWith(
                        fontSize: Dimensions.fontSizeLarge,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Icon(
                          defConnected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 14,
                          color: defConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          defConnected ? 'connected'.tr : 'disconnected'.tr,
                          style: robotoRegular.copyWith(
                            color: defConnected ? Colors.green : Colors.red,
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  'no_default_printer'.tr,
                  style: robotoRegular.copyWith(
                    color: Theme.of(context).disabledColor,
                    fontSize: Dimensions.fontSizeDefault,
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _SearchingPlaceholder extends StatelessWidget {
  const _SearchingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Dimensions.paddingSizeLarge,
      ),
      child: Center(
        child: Column(
          children: <Widget>[
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),
            Text(
              'searching'.tr,
              style: robotoMedium.copyWith(
                color: Theme.of(context).disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onScan;
  const _EmptyState({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Dimensions.paddingSizeDefault,
        vertical: Dimensions.paddingSizeExtraLarge,
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.print_disabled_outlined,
            size: 80,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Text(
            'no_printers_paired'.tr,
            textAlign: TextAlign.center,
            style: robotoMedium.copyWith(
              fontSize: Dimensions.fontSizeDefault,
              color: Theme.of(context).disabledColor,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeSmall),
          Text(
            'pair_printer_hint'.tr,
            textAlign: TextAlign.center,
            style: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall,
              color: Theme.of(context).disabledColor,
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),
          CustomButtonWidget(
            buttonText: 'scan_printers'.tr,
            icon: Icons.search,
            width: 220,
            height: 45,
            onPressed: () => onScan(),
          ),
        ],
      ),
    );
  }
}
