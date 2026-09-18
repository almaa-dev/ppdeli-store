import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:ppdelistore/common/models/config_model.dart';
import 'package:ppdelistore/common/widgets/custom_button_widget.dart';
import 'package:ppdelistore/common/widgets/custom_snackbar_widget.dart';
import 'package:ppdelistore/common/widgets/custom_text_field_widget.dart';
import 'package:ppdelistore/features/ai/controllers/ai_controller.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';

class GenerateTitleBottomSheet extends StatefulWidget {
  final List<Language>? languageList;
  final TabController? tabController;
  final List<TextEditingController>? nameControllerList;
  const GenerateTitleBottomSheet({
    super.key,
    this.nameControllerList,
    this.languageList,
    this.tabController,
  });

  @override
  State<GenerateTitleBottomSheet> createState() =>
      _GenerateTitleBottomSheetState();
}

class _GenerateTitleBottomSheetState extends State<GenerateTitleBottomSheet> {
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Get.find<AiController>().initializeKeyWords();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Container(
        width: context.width,
        padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(Dimensions.radiusExtraLarge),
            topRight: Radius.circular(Dimensions.radiusExtraLarge),
          ),
        ),
        child: GetBuilder<AiController>(
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

                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(
                      Dimensions.paddingSizeDefault,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'great'.tr,
                          style: robotoBold.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraSmall,
                        ),

                        Text(
                          'now_tell_me_which_product_you_want_to_create_just_type_it_simply_like'
                              .tr,
                          style: robotoBold.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        const SizedBox(height: Dimensions.paddingSizeSmall),

                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).hintColor,
                              radius: 3,
                            ),
                            const SizedBox(width: Dimensions.paddingSizeSmall),

                            Expanded(
                              child: Text(
                                'enter_some_keywords_you_want_in_the_name'.tr,
                                style: robotoRegular.copyWith(
                                  color: Theme.of(context).hintColor,
                                  fontSize: Dimensions.fontSizeSmall,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Dimensions.paddingSizeSmall),

                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context).hintColor,
                              radius: 3,
                            ),
                            const SizedBox(width: Dimensions.paddingSizeSmall),

                            Expanded(
                              child: Text(
                                'or_you_can_give_related_title_we_will_generate_some_new_title_for_you'
                                    .tr,
                                style: robotoRegular.copyWith(
                                  color: Theme.of(context).hintColor,
                                  fontSize: Dimensions.fontSizeSmall,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Dimensions.paddingSizeSmall),

                        Text(
                          'feel_free_to_describe_it_your_own_way'.tr,
                          style: robotoRegular.copyWith(
                            color: Theme.of(context).hintColor,
                            fontSize: Dimensions.fontSizeSmall,
                          ),
                        ),
                        SizedBox(height: Dimensions.paddingSizeExtraLarge),

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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 8,
                                    child: CustomTextFieldWidget(
                                      hintText: 'enter_sample_keyword'.tr,
                                      labelText: 'keyword'.tr,
                                      showTitle: false,
                                      controller: _titleController,
                                      inputAction: TextInputAction.done,
                                      onSubmit: (name) {
                                        if (name.isNotEmpty) {
                                          aiController.setKeyWord(name);
                                          _titleController.text = '';
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(
                                    width: Dimensions.paddingSizeDefault,
                                  ),

                                  Expanded(
                                    flex: 2,
                                    child: CustomButtonWidget(
                                      buttonText: 'add'.tr,
                                      color: Colors.blue,
                                      onPressed: () {
                                        if (_titleController.text.isNotEmpty) {
                                          aiController.setKeyWord(
                                            _titleController.text.trim(),
                                          );
                                          _titleController.text = '';
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: aiController.keyWordList.isNotEmpty
                                    ? Dimensions.paddingSizeSmall
                                    : 0,
                              ),

                              aiController.keyWordList.isNotEmpty
                                  ? SizedBox(
                                      height: 40,
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        scrollDirection: Axis.horizontal,
                                        itemCount:
                                            aiController.keyWordList.length,
                                        itemBuilder: (context, index) {
                                          return Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: Dimensions
                                                  .paddingSizeExtraSmall,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal:
                                                  Dimensions.paddingSizeSmall,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).hintColor
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    Dimensions.radiusSmall,
                                                  ),
                                            ),
                                            child: Center(
                                              child: Row(
                                                children: [
                                                  Text(
                                                    aiController
                                                        .keyWordList[index]!,
                                                    style: robotoMedium
                                                        .copyWith(
                                                          color: Theme.of(
                                                            context,
                                                          ).hintColor,
                                                        ),
                                                  ),
                                                  const SizedBox(
                                                    width: Dimensions
                                                        .paddingSizeExtraSmall,
                                                  ),

                                                  InkWell(
                                                    onTap: () => aiController
                                                        .removeKeyWord(index),
                                                    child: Icon(
                                                      Icons.clear,
                                                      size: 18,
                                                      color: Theme.of(
                                                        context,
                                                      ).hintColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : const SizedBox(),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: Dimensions.paddingSizeExtraLarge,
                        ),

                        CustomButtonWidget(
                          icon: Icons.auto_awesome,
                          isLoading: aiController.isLoading,
                          color: Colors.blue,
                          onPressed: () {
                            if (aiController.keyWordList.isEmpty) {
                              showCustomSnackBar(
                                'please_add_a_keyword_to_generate_food_name'.tr,
                              );
                            } else {
                              aiController.generateTitleSuggestions();
                            }
                          },
                          buttonText: 'generate_food_name'.tr,
                        ),
                        SizedBox(
                          height: !aiController.isLoading
                              ? 0
                              : Dimensions.paddingSizeLarge,
                        ),

                        !aiController.isLoading
                            ? SizedBox()
                            : Shimmer(
                                duration: const Duration(seconds: 2),
                                color: Colors.blue,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(
                                      width: Dimensions.paddingSizeExtraSmall,
                                    ),

                                    Text(
                                      '${'generating'.tr}...',
                                      style: robotoBold.copyWith(
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        SizedBox(
                          height:
                              aiController.titleSuggestionModel?.data?.titles !=
                                      null &&
                                  aiController
                                      .titleSuggestionModel!
                                      .data!
                                      .titles!
                                      .isNotEmpty
                              ? Dimensions.paddingSizeLarge
                              : 0,
                        ),

                        aiController.titleSuggestionModel?.data?.titles !=
                                    null &&
                                aiController
                                    .titleSuggestionModel!
                                    .data!
                                    .titles!
                                    .isNotEmpty
                            ? Text(
                                'suggested_food_name'.tr,
                                style: robotoBold.copyWith(
                                  fontSize: Dimensions.fontSizeLarge,
                                ),
                              )
                            : SizedBox(),
                        const SizedBox(height: Dimensions.paddingSizeSmall),

                        aiController.titleSuggestionModel?.data?.titles !=
                                    null &&
                                aiController
                                    .titleSuggestionModel!
                                    .data!
                                    .titles!
                                    .isNotEmpty
                            ? ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: aiController
                                    .titleSuggestionModel
                                    ?.data
                                    ?.titles
                                    ?.length,
                                itemBuilder: (context, index) {
                                  bool isUse =
                                      widget
                                          .nameControllerList![widget
                                              .tabController!
                                              .index]
                                          .text ==
                                      aiController
                                          .titleSuggestionModel!
                                          .data!
                                          .titles![index];

                                  return Card(
                                    elevation: 1,
                                    margin: const EdgeInsets.symmetric(
                                      vertical:
                                          Dimensions.paddingSizeExtraSmall,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusSmall,
                                      ),
                                      side: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).hintColor.withValues(alpha: 0.2),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        aiController
                                                .titleSuggestionModel
                                                ?.data
                                                ?.titles?[index] ??
                                            '',
                                        style: robotoRegular.copyWith(
                                          fontSize: Dimensions.fontSizeSmall,
                                        ),
                                      ),
                                      trailing: InkWell(
                                        onTap: () {
                                          widget
                                              .nameControllerList![widget
                                                  .tabController!
                                                  .index]
                                              .text = aiController
                                              .titleSuggestionModel!
                                              .data!
                                              .titles![index];
                                          Get.back();
                                          Get.back();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal:
                                                Dimensions.paddingSizeSmall,
                                            vertical: Dimensions
                                                .paddingSizeExtraSmall,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: isUse
                                                  ? Theme.of(
                                                      context,
                                                    ).primaryColor
                                                  : Colors.blue,
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              Dimensions.radiusSmall,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                CupertinoIcons
                                                    .checkmark_rectangle,
                                                color: isUse
                                                    ? Theme.of(
                                                        context,
                                                      ).primaryColor
                                                    : Colors.blue,
                                                size: 16,
                                              ),
                                              const SizedBox(
                                                width: Dimensions
                                                    .paddingSizeExtraSmall,
                                              ),

                                              Text(
                                                isUse ? 'used'.tr : 'use'.tr,
                                                style: robotoRegular.copyWith(
                                                  color: isUse
                                                      ? Theme.of(
                                                          context,
                                                        ).primaryColor
                                                      : Colors.blue,
                                                  fontSize:
                                                      Dimensions.fontSizeSmall,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal:
                                                Dimensions.paddingSizeSmall,
                                            vertical: Dimensions
                                                .paddingSizeExtraSmall,
                                          ),
                                    ),
                                  );
                                },
                              )
                            : SizedBox(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
