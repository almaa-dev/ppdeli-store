import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../util/dimensions.dart';
import '../../../util/styles.dart';
import '../controllers/store_controller.dart';

void showFilterPopup({
  required BuildContext context,
  required Offset offset,
  required String? selectedType,
  required Function(String value) onSelected,
}) {
  final storeController = Get.find<StoreController>();

  showMenu(
    context: context,
    position: RelativeRect.fromLTRB(offset.dx, offset.dy, offset.dx + 1, offset.dy + 1),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Dimensions.radiusLarge),),
    elevation: 8,
    items: storeController.itemTypeList.map((type) {
      final bool isSelected = type == selectedType;
      return PopupMenuItem<String>(
        value: type,
        onTap: () => onSelected(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(type == 'all'
              ? 'all_foods'.tr
              : type == 'veg'
              ? 'veg_foods'.tr
              : type == 'non_veg' ?'non_veg_foods'.tr : 'campaign_foods'.tr,
              style: robotoRegular.copyWith(fontSize: 12, color: isSelected ? Colors.green : Colors.black87, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
        ),
      );
    }).toList(),
  );
}