import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/common/models/config_model.dart';
import 'package:ppdelistore/common/widgets/custom_button_widget.dart';
import 'package:ppdelistore/common/widgets/custom_snackbar_widget.dart';
import 'package:ppdelistore/features/ai/controllers/ai_controller.dart';
import 'package:ppdelistore/features/store/controllers/store_controller.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';

class ImageAnalyzeBottomSheet extends StatefulWidget {
  final List<Language>? languageList;
  final TabController? tabController;
  final List<TextEditingController>? nameControllerList;
  final List<TextEditingController>? descriptionControllerList;
  final TextEditingController? priceController;
  final TextEditingController? discountController;
  final TextEditingController? stockController;
  final TextEditingController? maxOrderQuantityController;
  final TextEditingController? metaTitleController;
  final TextEditingController? metaDescriptionController;
  final TextEditingController? maxSnippetController;
  final TextEditingController? maxVideoPreviewController;
  final VoidCallback? onGeneratedDiscountTypeSelected;
  final VoidCallback? onImageDataApplied;
  const ImageAnalyzeBottomSheet({
    super.key,
    this.nameControllerList,
    this.descriptionControllerList,
    this.priceController,
    this.discountController,
    this.stockController,
    this.maxOrderQuantityController,
    this.metaTitleController,
    this.metaDescriptionController,
    this.maxSnippetController,
    this.maxVideoPreviewController,
    this.languageList,
    this.tabController,
    this.onGeneratedDiscountTypeSelected,
    this.onImageDataApplied,
  });

  @override
  State<ImageAnalyzeBottomSheet> createState() =>
      _ImageAnalyzeBottomSheetState();
}

class _ImageAnalyzeBottomSheetState extends State<ImageAnalyzeBottomSheet> {
  @override
  void initState() {
    super.initState();
    Get.find<AiController>().setRequestType('', willUpdate: false);
    Get.find<StoreController>().pickImage(false, true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.width,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(Dimensions.radiusExtraLarge),
          topRight: Radius.circular(Dimensions.radiusExtraLarge),
        ),
      ),
      child: GetBuilder<StoreController>(
        builder: (storeController) {
          return GetBuilder<AiController>(
            builder: (aiController) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 20),

                      Container(
                        height: 5,
                        width: 35,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).hintColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(
                          right: Dimensions.paddingSizeSmall,
                          top: Dimensions.paddingSizeSmall,
                        ),
                        child: InkWell(
                          onTap: () {
                            Get.back();
                          },
                          child: Icon(
                            Icons.close,
                            color: Theme.of(
                              context,
                            ).hintColor.withValues(alpha: 0.6),
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),

                  Padding(
                    padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'upload_image'.tr,
                          style: robotoBold.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraSmall,
                        ),

                        Text(
                          'please_give_proper_image_to_generate_full_data_for_your_food'
                              .tr,
                          style: robotoRegular.copyWith(
                            color: Theme.of(context).hintColor,
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        ),
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraSmall,
                        ),

                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).hintColor,
                              radius: 3,
                            ),
                            const SizedBox(width: Dimensions.paddingSizeSmall),

                            Expanded(
                              child: Text(
                                'try_to_use_a_clean_and_avoid_blur_image'.tr,
                                style: robotoRegular.copyWith(
                                  color: Theme.of(context).hintColor,
                                  fontSize: Dimensions.fontSizeSmall,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraSmall,
                        ),

                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).hintColor,
                              radius: 3,
                            ),
                            const SizedBox(width: Dimensions.paddingSizeSmall),

                            Expanded(
                              child: Text(
                                'use_as_close_as_your_product_image'.tr,
                                style: robotoRegular.copyWith(
                                  color: Theme.of(context).hintColor,
                                  fontSize: Dimensions.fontSizeSmall,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraOverLarge,
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Dimensions.paddingSizeSmall,
                            vertical: Dimensions.paddingSizeLarge,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).hintColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(
                              Dimensions.radiusDefault,
                            ),
                          ),
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.center,
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusDefault,
                                      ),
                                      child: storeController.rawLogo != null
                                          ? GetPlatform.isWeb
                                                ? Image.network(
                                                    storeController
                                                        .rawLogo!
                                                        .path,
                                                    width: 150,
                                                    height: 150,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Image.file(
                                                    File(
                                                      storeController
                                                          .rawLogo!
                                                          .path,
                                                    ),
                                                    width: 150,
                                                    height: 150,
                                                    fit: BoxFit.cover,
                                                  )
                                          : SizedBox(
                                              width: 150,
                                              height: 150,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    CupertinoIcons.camera_fill,
                                                    color: Theme.of(context)
                                                        .hintColor
                                                        .withValues(alpha: 0.5),
                                                    size: 38,
                                                  ),
                                                  const SizedBox(
                                                    height: Dimensions
                                                        .paddingSizeExtraSmall,
                                                  ),

                                                  Text(
                                                    'upload_image'.tr,
                                                    style: robotoRegular.copyWith(
                                                      color: Theme.of(
                                                        context,
                                                      ).hintColor,
                                                      fontSize: Dimensions
                                                          .fontSizeExtraSmall,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      top: 0,
                                      left: 0,
                                      child: InkWell(
                                        onTap: () => storeController.pickImage(
                                          true,
                                          false,
                                        ),
                                        child: DottedBorder(
                                          options:
                                              RoundedRectDottedBorderOptions(
                                                color: Colors.blue,
                                                strokeWidth: 1,
                                                strokeCap: StrokeCap.butt,
                                                dashPattern: const [5, 5],
                                                padding: const EdgeInsets.all(
                                                  0,
                                                ),
                                                radius: const Radius.circular(
                                                  Dimensions.radiusDefault,
                                                ),
                                              ),
                                          child: Center(
                                            child: Visibility(
                                              visible:
                                                  storeController.rawLogo !=
                                                      null
                                                  ? true
                                                  : false,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  25,
                                                ),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    width: 2,
                                                    color: Colors.white,
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.camera_alt,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        CustomButtonWidget(
                          icon: Icons.auto_awesome,
                          isLoading: aiController.imageLoading,
                          color: Colors.blue,
                          onPressed: () async {
                            if (storeController.rawLogo == null) {
                              showCustomSnackBar('please_upload_an_image'.tr);
                            } else {
                              widget.onGeneratedDiscountTypeSelected?.call();
                              final bool isGenerated = await storeController
                                  .generateAndSetDataFromImage(
                                    languageList: widget.languageList,
                                    tabController: widget.tabController,
                                    nameControllerList:
                                        widget.nameControllerList,
                                    descriptionControllerList:
                                        widget.descriptionControllerList,
                                    priceController: widget.priceController,
                                    discountController:
                                        widget.discountController,
                                    stockController: widget.stockController,
                                    maxOrderQuantityController:
                                        widget.maxOrderQuantityController,
                                  );
                              if (isGenerated) {
                                widget.onImageDataApplied?.call();
                              }
                            }
                          },
                          buttonText: 'analyze_and_generate_content'.tr,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
