import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/widgets/custom_bottom_sheet_widget.dart';
import '../../../common/widgets/custom_button_widget.dart';
import '../../../common/widgets/custom_snackbar_widget.dart';
import '../../../common/widgets/custom_text_field_widget.dart';
import '../../../util/dimensions.dart';
import '../../../util/styles.dart';
import '../controllers/store_controller.dart';
import 'announcement_status_bottom_sheet.dart';

void showAnnouncementBottomSheet({
  required BuildContext context,
  required int announcementStatus,
  required String announcementMessage,
}) {
  final TextEditingController announcementController = TextEditingController(text: announcementMessage);

  final bool initialStatus = announcementStatus == 1;

  final storeController = Get.find<StoreController>();
  storeController.setAnnouncementStatus(initialStatus, willUpdate: false);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: Dimensions.paddingSizeExtraSmall, left: Dimensions.paddingSizeDefault, right: Dimensions.paddingSizeDefault),
        child: GetBuilder<StoreController>(
          builder: (storeController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(children: [
                  Divider(thickness: 4, endIndent: 170, indent: 170, color: Theme.of(context).hintColor.withValues(alpha: 0.2)),
                  Align(alignment: Alignment.topRight, child: IconButton(
                    icon: Icon(Icons.close, color: Theme.of(context).hintColor),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.all(1),
                  )),
                ]),

                Text('make_announcement'.tr, style: robotoMedium.copyWith(fontSize: 18)),


                const SizedBox(height: Dimensions.paddingSizeDefault),

                Container(
                  padding: EdgeInsets.all(Dimensions.paddingSizeDefault),
                  decoration: BoxDecoration(
                    color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('announcement_visibility'.tr, style: robotoMedium),
                    Text('announcement_notice'.tr, style: robotoRegular.copyWith(fontSize: Dimensions.paddingSizeSmall)),
                    const SizedBox(height: Dimensions.paddingSizeDefault),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: Dimensions.paddingSizeExtraSmall, horizontal: Dimensions.paddingSizeDefault),
                      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(Dimensions.radiusSmall)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('status'.tr),
                      Transform.scale(
                        scale: 0.7,
                        child: CupertinoSwitch(
                          inactiveTrackColor: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                          activeTrackColor: Theme.of(context).primaryColor,
                          value: storeController.announcementStatus,
                          onChanged: (value) {
                            showCustomBottomSheet(
                              child: AnnouncementStatusBottomSheet(),
                            );
                          },
                        ),
                      ),
                    ]),
                  )
                  ]),
                ),

                const SizedBox(height: Dimensions.paddingSizeDefault),

                Container(
                    padding: EdgeInsets.all(Dimensions.paddingSizeDefault),
                    decoration: BoxDecoration(
                      color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("announcement_content".tr, style: robotoRegular),
                    const SizedBox(height: Dimensions.paddingSizeDefault),
                    CustomTextFieldWidget(hintText: "type_announcement".tr, showLabelText: false, controller: announcementController, maxLines: 5, maxLength: 100),
                  ]),
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),
                !storeController.isLoading
                    ? Row(children: [
                        Expanded(child: CustomButtonWidget(
                            onPressed: () {announcementController.text = announcementMessage; storeController.setAnnouncementStatus(initialStatus, willUpdate: true);},
                            buttonText: 'reset'.tr, color: Theme.of(context).hintColor.withValues(alpha: 0.2), textColor: Theme.of(context).textTheme.bodyLarge?.color,
                        )),
                        SizedBox(width: Dimensions.paddingSizeDefault),
                        Expanded(
                          child: CustomButtonWidget(onPressed: () {
                            if (announcementController.text.isEmpty) {
                              showCustomSnackBar('enter_announcement'.tr);
                            } else {
                              storeController.updateAnnouncement(
                                storeController.announcementStatus ? 1 : 0,
                                announcementController.text,
                              );
                              Navigator.pop(context);
                            }},
                            buttonText: 'submit'.tr),
                        ),
                      ],
                    )
                    : const Center(child: CircularProgressIndicator()),
                const SizedBox(height: Dimensions.paddingSizeDefault),
              ],
            );
          },
        ),
      );
    },
  );
}
