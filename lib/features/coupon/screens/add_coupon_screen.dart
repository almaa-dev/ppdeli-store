import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/features/coupon/controllers/coupon_controller.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/common/models/config_model.dart';
import 'package:ppdelistore/features/coupon/domain/models/coupon_body_model.dart';
import 'package:ppdelistore/features/store/domain/models/item_model.dart';
import 'package:ppdelistore/helper/date_converter_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:ppdelistore/common/widgets/custom_app_bar_widget.dart';
import 'package:ppdelistore/common/widgets/custom_button_widget.dart';
import 'package:ppdelistore/common/widgets/custom_snackbar_widget.dart';
import 'package:ppdelistore/common/widgets/text_field_widget.dart';

import '../../../common/widgets/custom_text_field_widget.dart';
import '../../ai/widgets/animated_border_container.dart';

class AddCouponScreen extends StatefulWidget {
  final CouponBodyModel? coupon;
  const AddCouponScreen({super.key, this.coupon});

  @override
  State<AddCouponScreen> createState() => _AddCouponScreenState();
}

class _AddCouponScreenState extends State<AddCouponScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _titleController = [];
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _limitController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _expireDateController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _maxDiscountController = TextEditingController();
  final TextEditingController _minPurchaseController = TextEditingController();

  final List<FocusNode> _titleNode = [];
  final FocusNode _codeNode = FocusNode();
  final FocusNode _limitNode = FocusNode();
  final FocusNode _minNode = FocusNode();
  final FocusNode _discountNode = FocusNode();
  final FocusNode _maxDiscountNode = FocusNode();
  final List<Language>? _languageList =
      Get.find<SplashController>().configModel!.language;
  TabController? _tabController;
  final List<Tab> _tabs = [];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _languageList!.length, vsync: this);
    _tabs.addAll(_languageList.map((lang) => Tab(text: lang.value)));

    if (widget.coupon != null) {
      List<Translation> translation = widget.coupon!.translations!;
      for (int index = 0; index < _languageList.length; index++) {
        Translation? languageTranslation = translation.firstWhereOrNull(
          (trans) => trans.locale == _languageList[index].key,
        );
        _titleController.add(
          TextEditingController(text: languageTranslation?.value ?? ''),
        );
        _titleNode.add(FocusNode());
      }
      _codeController.text = widget.coupon!.code!;
      _limitController.text = widget.coupon!.limit != null
          ? widget.coupon!.limit.toString()
          : '';
      _startDateController.text = widget.coupon!.startDate.toString();
      _expireDateController.text = widget.coupon!.expireDate.toString();
      _discountController.text = widget.coupon!.discount.toString();
      _maxDiscountController.text = widget.coupon!.maxDiscount.toString();
      _minPurchaseController.text = widget.coupon!.minPurchase.toString();
      Get.find<CouponController>().setCouponTypeIndex(
        widget.coupon!.couponType == 'default' ? 0 : 1,
        false,
      );
      Get.find<CouponController>().setDiscountTypeIndex(
        widget.coupon!.discountType == 'percent' ? 0 : 1,
        false,
      );
    } else {
      for (var language in _languageList) {
        if (kDebugMode) {
          print(language);
        }
        _titleController.add(TextEditingController());
        _titleNode.add(FocusNode());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    late bool selfDelivery;
    if (Get.find<ProfileController>().profileModel != null &&
        Get.find<ProfileController>().profileModel!.stores != null) {
      selfDelivery =
          Get.find<ProfileController>()
              .profileModel!
              .stores![0]
              .selfDeliverySystem ==
          1;
    }
    if (!selfDelivery) {
      Get.find<CouponController>().setCouponTypeIndex(0, false);
    }
    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      appBar: CustomAppBarWidget(
        title: widget.coupon != null ? 'update_coupon'.tr : 'add_coupon'.tr,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimensions.paddingSizeSmall,
          vertical: Dimensions.paddingSizeSmall,
        ),
        child: GetBuilder<CouponController>(
          builder: (couponController) {
            return Column(
              children: [
                AnimatedBorderContainer(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                  isLoading: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('general_info'.tr, style: robotoMedium),
                      Text(
                        'general_info_des'.tr,
                        style: robotoRegular.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      SizedBox(height: Dimensions.paddingSizeSmall),

                      Container(
                        padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).disabledColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusSmall,
                          ),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 40,
                              child: TabBar(
                                tabAlignment: TabAlignment.start,
                                controller: _tabController,
                                indicatorColor: Theme.of(context).primaryColor,
                                indicatorWeight: 3,
                                labelColor: Theme.of(context).primaryColor,
                                unselectedLabelColor: Theme.of(
                                  context,
                                ).disabledColor,
                                unselectedLabelStyle: robotoRegular.copyWith(
                                  color: Theme.of(context).disabledColor,
                                  fontSize: Dimensions.fontSizeSmall,
                                ),
                                labelStyle: robotoBold.copyWith(
                                  fontSize: Dimensions.fontSizeDefault,
                                  color: Theme.of(context).primaryColor,
                                ),
                                labelPadding: const EdgeInsets.only(
                                  right: Dimensions.radiusDefault,
                                ),
                                isScrollable: true,
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                tabs: _tabs,
                                onTap: (int? value) {
                                  setState(() {});
                                },
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(
                                bottom: Dimensions.paddingSizeLarge,
                              ),
                              child: Divider(height: 0),
                            ),

                            CustomTextFieldWidget(
                              hintText: 'coupon_name'.tr,
                              labelText: 'coupon'.tr,
                              controller:
                                  _titleController[_tabController!.index],
                              capitalization: TextCapitalization.words,
                              focusNode: _titleNode[_tabController!.index],
                              showTitle: false,
                              required: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeDefault),

                // ListView.builder(
                //   itemCount: _languageList!.length,
                //   shrinkWrap: true,
                //   physics: const NeverScrollableScrollPhysics(),
                //   itemBuilder: (context, index) {
                //     return Padding(
                //       padding: const EdgeInsets.only(bottom: Dimensions.paddingSizeLarge),
                //       child: TextFieldWidget(
                //         hintText: '${'title'.tr} (${_languageList[index].value!})',
                //         controller: _titleController[index],
                //         focusNode: _titleNode[index],
                //         nextFocus: index != _languageList.length-1 ? _titleNode[index+1] : _codeNode,
                //       ),
                //     );
                //   }
                // ),
                Container(
                  padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    boxShadow: [
                      BoxShadow(
                        offset: Offset(0, 3),
                        color: Colors.grey[Get.isDarkMode ? 700 : 200]!,
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('coupon_details'.tr, style: robotoMedium),
                      Text(
                        'coupon_details_des'.tr,
                        style: robotoRegular.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      SizedBox(height: Dimensions.paddingSizeSmall),
                      selfDelivery
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'coupon_type'.tr,
                                  style: robotoRegular.copyWith(
                                    fontSize: Dimensions.fontSizeSmall,
                                    color: Theme.of(context).disabledColor,
                                  ),
                                ),
                                const SizedBox(
                                  height: Dimensions.paddingSizeExtraSmall,
                                ),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Dimensions.paddingSizeSmall,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(
                                      Dimensions.radiusSmall,
                                    ),
                                    boxShadow: Get.isDarkMode
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: Colors.grey[200]!,
                                              spreadRadius: 2,
                                              blurRadius: 5,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                  ),
                                  child: DropdownButton<String>(
                                    value: couponController.couponTypeIndex == 0
                                        ? 'default'
                                        : 'free_delivery',
                                    items: <String>['default', 'free_delivery']
                                        .map((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value.tr),
                                          );
                                        })
                                        .toList(),
                                    onChanged: (value) {
                                      couponController.setCouponTypeIndex(
                                        value == 'default' ? 0 : 1,
                                        true,
                                      );
                                    },
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox(),
                      SizedBox(
                        height: selfDelivery
                            ? Dimensions.paddingSizeDefault
                            : 0,
                      ),
                      CustomTextFieldWidget(
                        hintText: 'code'.tr,
                        labelText: 'code'.tr,
                        showTitle: false,
                        controller: _codeController,
                        focusNode: _codeNode,
                        nextFocus: _limitNode,
                        required: true,
                      ),
                      const SizedBox(height: Dimensions.paddingSizeDefault),
                      TextFieldWidget(
                        hintText: 'limit_for_same_user'.tr,
                        showTitle: false,
                        controller: _limitController,
                        focusNode: _limitNode,
                        nextFocus: _minNode,
                        isAmount: true,
                      ),
                      const SizedBox(height: Dimensions.paddingSizeDefault),
                      TextFieldWidget(
                        hintText: 'min_purchase'.tr,
                        showTitle: false,
                        controller: _minPurchaseController,
                        isAmount: true,
                        focusNode: _minNode,
                        nextFocus: _discountNode,
                      ),
                      const SizedBox(height: Dimensions.paddingSizeDefault),
                      couponController.couponTypeIndex == 0
                          ? Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusDefault,
                                ),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).disabledColor.withValues(alpha: 0.7),
                                ),
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextFieldWidget(
                                        hintText: '${'discount'.tr} *',
                                        showTitle: false,
                                        controller: _discountController,
                                        isAmount: true,
                                        focusNode: _discountNode,
                                        nextFocus: _maxDiscountNode,
                                        showBorder: false,
                                        showLabelText: false,
                                        required: true,
                                      ),
                                    ),

                                    Container(
                                      width: 70,
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).disabledColor.withValues(alpha: 0.1),
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(
                                            Dimensions.radiusDefault,
                                          ),
                                          bottomRight: Radius.circular(
                                            Dimensions.radiusDefault,
                                          ),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: DropdownButton<String>(
                                        value:
                                            couponController
                                                    .discountTypeIndex ==
                                                0
                                            ? 'percent'
                                            : 'amount',
                                        items: <String>['percent', 'amount']
                                            .map((String value) {
                                              return DropdownMenuItem<String>(
                                                value: value,
                                                child: Text(
                                                  value == 'percent'
                                                      ? '%'
                                                      : '\$',
                                                ),
                                              );
                                            })
                                            .toList(),
                                        onChanged: (value) {
                                          couponController.setDiscountTypeIndex(
                                            value == 'percent' ? 0 : 1,
                                            true,
                                          );
                                        },
                                        underline: const SizedBox(),
                                        icon: Icon(
                                          Icons.arrow_drop_down,
                                          color: Theme.of(
                                            context,
                                          ).disabledColor,
                                        ),
                                        isExpanded: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox(),

                      // Row(children: [
                      //   Expanded(child: TextFieldWidget(
                      //     hintText: 'discount'.tr,
                      //     showTitle: false,
                      //     controller: _discountController,
                      //     isAmount: true,
                      //     focusNode: _discountNode,
                      //     nextFocus: _maxDiscountNode,
                      //   )),
                      //   const SizedBox(width: Dimensions.paddingSizeDefault),
                      //
                      //   Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      //     Container(
                      //       padding: const EdgeInsets.symmetric(horizontal: Dimensions.paddingSizeSmall),
                      //       decoration: BoxDecoration(
                      //         color: Theme.of(context).disabledColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                      //       ),
                      //       child: DropdownButton<String>(
                      //         value: couponController.discountTypeIndex == 0 ? 'percent' : 'amount',
                      //         items: <String>['percent', 'amount'].map((String value) {
                      //           return DropdownMenuItem<String>(
                      //             value: value,
                      //             child: Text(value.tr),
                      //           );
                      //         }).toList(),
                      //         onChanged: (value) {
                      //           couponController.setDiscountTypeIndex(value == 'percent' ? 0 : 1, true);
                      //         },
                      //         isExpanded: true,
                      //         underline: const SizedBox(),
                      //       ),
                      //     ),
                      //   ])),
                      // ]) : const SizedBox(),
                      const SizedBox(height: Dimensions.paddingSizeDefault),
                      couponController.couponTypeIndex == 0 &&
                              couponController.discountTypeIndex == 0
                          ? TextFieldWidget(
                              hintText: 'max_discount'.tr,
                              showTitle: false,
                              controller: _maxDiscountController,
                              isAmount: true,
                              focusNode: _maxDiscountNode,
                              inputAction: TextInputAction.done,
                            )
                          : const SizedBox(),
                    ],
                  ),
                ),

                const SizedBox(height: Dimensions.paddingSizeLarge),

                Container(
                  padding: EdgeInsets.all(Dimensions.paddingSizeSmall),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
                    boxShadow: [
                      BoxShadow(
                        offset: Offset(0, 3),
                        color: Colors.grey[Get.isDarkMode ? 700 : 200]!,
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('validity_period'.tr, style: robotoMedium),
                      Text(
                        'coupon_active_des'.tr,
                        style: robotoRegular.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      SizedBox(height: Dimensions.paddingSizeSmall),

                      GestureDetector(
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            String formattedDate =
                                DateConverterHelper.dateTimeForCoupon(
                                  pickedDate,
                                );
                            setState(() {
                              _startDateController.text = formattedDate;
                            });
                          }
                        },
                        child: CustomTextFieldWidget(
                          controller: _startDateController,
                          hintText: 'start_date'.tr,
                          labelText: 'start_date'.tr,
                          required: true,
                          showTitle: false,
                          isEnabled: false,
                          suffixChild: Icon(Icons.calendar_month),
                        ),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeDefault),

                      GestureDetector(
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (pickedDate != null) {
                            String formattedDate =
                                DateConverterHelper.dateTimeForCoupon(
                                  pickedDate,
                                );
                            setState(() {
                              _expireDateController.text = formattedDate;
                            });
                          }
                        },
                        child: CustomTextFieldWidget(
                          controller: _expireDateController,
                          hintText: 'expire_date'.tr,
                          labelText: 'expire_date'.tr,
                          showTitle: false,
                          isEnabled: false,
                          required: true,
                          suffixChild: Icon(Icons.calendar_month),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Dimensions.paddingSizeLarge),

                SizedBox(
                  height: couponController.couponTypeIndex == 0
                      ? Dimensions.paddingSizeLarge
                      : 0,
                ),

                SafeArea(
                  child: !couponController.isLoading
                      ? CustomButtonWidget(
                          buttonText: widget.coupon == null
                              ? 'add'.tr
                              : 'update'.tr,
                          onPressed: () {
                            // Check if default language title (index 0) is filled
                            bool defaultTitleEmpty = _titleController[0].text
                                .trim()
                                .isEmpty;

                            String code = _codeController.text.trim();
                            String startDate = _startDateController.text.trim();
                            String expireDate = _expireDateController.text
                                .trim();
                            String discount = _discountController.text.trim();
                            if (defaultTitleEmpty) {
                              showCustomSnackBar(
                                'please_fill_up_your_coupon_title'.tr,
                              );
                            } else if (code.isEmpty) {
                              showCustomSnackBar(
                                'please_fill_up_your_coupon_code'.tr,
                              );
                            } else if (startDate.isEmpty) {
                              showCustomSnackBar(
                                'please_select_your_coupon_start_date'.tr,
                              );
                            } else if (expireDate.isEmpty) {
                              showCustomSnackBar(
                                'please_select_your_coupon_expire_date'.tr,
                              );
                            } else if (couponController.couponTypeIndex == 0 &&
                                discount.isEmpty) {
                              showCustomSnackBar(
                                'please_fill_up_your_coupon_discount'.tr,
                              );
                            } else if (_limitController.text
                                    .trim()
                                    .isNotEmpty &&
                                (int.parse(_limitController.text.trim()) >
                                    100)) {
                              showCustomSnackBar(
                                'limit_for_same_user_cant_be_more_then_100'.tr,
                              );
                            } else {
                              List<Translation> translation = [];
                              for (
                                int index = 0;
                                index < _languageList!.length;
                                index++
                              ) {
                                translation.add(
                                  Translation(
                                    locale: _languageList[index].key,
                                    key: 'title',
                                    value:
                                        _titleController[index].text
                                            .trim()
                                            .isNotEmpty
                                        ? _titleController[index].text.trim()
                                        : _titleController[0].text.trim(),
                                  ),
                                );
                              }
                              if (widget.coupon == null) {
                                couponController.addCoupon(
                                  title: jsonEncode(translation),
                                  code: code,
                                  startDate: startDate,
                                  expireDate: expireDate,
                                  couponType:
                                      couponController.couponTypeIndex == 0
                                      ? 'default'
                                      : 'free_delivery',
                                  discount: discount,
                                  discountType:
                                      couponController.discountTypeIndex == 0
                                      ? 'percent'
                                      : 'amount',
                                  limit: _limitController.text.trim().isEmpty
                                      ? null
                                      : _limitController.text.trim(),
                                  maxDiscount: _maxDiscountController.text
                                      .trim(),
                                  minPurches: _minPurchaseController.text
                                      .trim(),
                                );
                              } else {
                                couponController.updateCoupon(
                                  couponId: widget.coupon!.id.toString(),
                                  title: jsonEncode(translation),
                                  code: code,
                                  startDate: startDate,
                                  expireDate: expireDate,
                                  couponType:
                                      couponController.couponTypeIndex == 0
                                      ? 'default'
                                      : 'free_delivery',
                                  discount: discount,
                                  discountType:
                                      couponController.discountTypeIndex == 0
                                      ? 'percent'
                                      : 'amount',
                                  limit: _limitController.text.trim().isEmpty
                                      ? null
                                      : _limitController.text.trim(),
                                  maxDiscount: _maxDiscountController.text
                                      .trim(),
                                  minPurches: _minPurchaseController.text
                                      .trim(),
                                );
                              }
                            }
                          },
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
