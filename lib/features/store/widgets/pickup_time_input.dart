import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/common/widgets/custom_drop_down_button.dart.dart';
import 'package:ppdelistore/features/store/controllers/store_controller.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';

class PickupTimeInput extends StatefulWidget {
  final TextEditingController minTimeController;
  final TextEditingController maxTimeController;
  const PickupTimeInput({
    super.key,
    required this.minTimeController,
    required this.maxTimeController,
  });

  @override
  State<PickupTimeInput> createState() => _PickupTimeInputState();
}

class _PickupTimeInputState extends State<PickupTimeInput> {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreController>(
      builder: (storeController) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).disabledColor.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: widget.minTimeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeDefault,
                        ),
                        hintText: 'mini'.tr,
                        hintStyle: robotoRegular.copyWith(
                          color: Theme.of(context).disabledColor,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  Container(
                    height: 25,
                    width: 1,
                    color: Theme.of(
                      context,
                    ).disabledColor.withValues(alpha: 0.2),
                  ),

                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: widget.maxTimeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: Dimensions.paddingSizeDefault,
                        ),
                        hintText: 'maxi'.tr,
                        hintStyle: robotoRegular.copyWith(
                          color: Theme.of(context).disabledColor,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  Expanded(
                    flex: 3,
                    child: CustomDropdownButton(
                      items: storeController.durations,
                      isBorder: false,
                      borderRadius: 0,
                      backgroundColor: Theme.of(
                        context,
                      ).disabledColor.withValues(alpha: 0.2),
                      onChanged: (String? value) {
                        storeController.setSelectedDuration(value!);
                      },
                      selectedValue: storeController.selectedDuration,
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              left: 10,
              top: -15,
              child: Container(
                decoration: BoxDecoration(color: Theme.of(context).cardColor),
                padding: const EdgeInsets.all(5),
                child: Text(
                  'approximate_delivery_time'.tr,
                  style: robotoRegular.copyWith(
                    color: Theme.of(context).disabledColor,
                    fontSize: Dimensions.fontSizeSmall,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
