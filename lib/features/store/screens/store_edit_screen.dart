import 'dart:developer';
import 'dart:io';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:ppdelistore/common/widgets/custom_asset_image_widget.dart';
import 'package:ppdelistore/common/widgets/custom_card.dart';
import 'package:ppdelistore/common/widgets/custom_image_widget.dart';
import 'package:ppdelistore/common/widgets/custom_text_field_widget.dart';
import 'package:ppdelistore/features/store/controllers/store_controller.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/common/models/config_model.dart';
import 'package:ppdelistore/features/store/domain/models/item_model.dart';
import 'package:ppdelistore/features/profile/domain/models/profile_model.dart'
    as profile;
import 'package:ppdelistore/helper/custom_validator_helper.dart';
import 'package:ppdelistore/helper/validate_check.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:ppdelistore/common/widgets/custom_app_bar_widget.dart';
import 'package:ppdelistore/common/widgets/custom_button_widget.dart';
import 'package:ppdelistore/common/widgets/custom_snackbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../common/widgets/custom_tool_tip_widget.dart';
import '../../profile/domain/models/profile_model.dart' hide Module;
import '../widgets/meta_seo_item_widget.dart';

class StoreEditScreen extends StatefulWidget {
  final profile.Store store;
  const StoreEditScreen({super.key, required this.store});

  @override
  State<StoreEditScreen> createState() => _StoreEditScreenState();
}

class _StoreEditScreenState extends State<StoreEditScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _nameController = [];
  final List<TextEditingController> _addressController = [];
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _maxSnippetController = TextEditingController();
  final TextEditingController _maxVideoPreviewController =
      TextEditingController();
  final TextEditingController _metaTitleController = TextEditingController();
  final TextEditingController _metaDescriptionController =
      TextEditingController();

  final List<FocusNode> _nameNode = [];
  final List<FocusNode> _addressNode = [];
  final FocusNode _contactNode = FocusNode();
  final FocusNode _metaTitleNode = FocusNode();
  final FocusNode _metaDescriptionNode = FocusNode();

  late profile.Store _store;
  final Module? _module =
      Get.find<SplashController>().configModel!.moduleConfig!.module;
  final List<Language>? _languageList =
      Get.find<SplashController>().configModel!.language;

  final List<Translation>? translation =
      Get.find<ProfileController>().profileModel!.translations!;
  TabController? _tabController;
  final List<Tab> _tabs = [];
  String? _countryDialCode;
  String? _countryCode;

  @override
  void initState() {
    super.initState();

    final storeController = Get.find<StoreController>();
    _countryDialCode = CountryCode.fromCountryCode(
      Get.find<SplashController>().configModel!.country!,
    ).dialCode;
    _countryCode = CountryCode.fromCountryCode(
      Get.find<SplashController>().configModel!.country!,
    ).code;
    _splitPhone(widget.store.phone);
    Get.find<StoreController>().initStoreBasicData();
    _metaTitleController.text = widget.store.metaTitle ?? '';
    _metaDescriptionController.text = widget.store.metaDescription ?? '';

    storeController.initializeMetaData(widget.store.metaData);

    if (widget.store.metaData != null) {
      _maxSnippetController.text =
          widget.store.metaData!.metaMaxSnippetValue?.toString() ?? '';
      _maxVideoPreviewController.text =
          widget.store.metaData!.metaMaxVideoPreviewValue?.toString() ?? '';
    }

    _tabController = TabController(length: _languageList!.length, vsync: this);

    for (var language in _languageList) {
      _tabs.add(Tab(text: language.value));
    }

    for (int index = 0; index < _languageList.length; index++) {
      _nameController.add(TextEditingController());
      _addressController.add(TextEditingController());
      _nameNode.add(FocusNode());
      _addressNode.add(FocusNode());

      for (var trans in translation!) {
        if (_languageList[index].key == trans.locale && trans.key == 'name') {
          _nameController[index] = TextEditingController(text: trans.value);
        } else if (_languageList[index].key == trans.locale &&
            trans.key == 'address') {
          _addressController[index] = TextEditingController(text: trans.value);
        }
      }
    }

    _store = widget.store;
  }

  void _splitPhone(String? phone) async {
    try {
      if (phone != null && phone.isNotEmpty) {
        PhoneNumber phoneNumber = PhoneNumber.parse(phone);
        _countryDialCode = '+${phoneNumber.countryCode}';
        _countryCode = phoneNumber.isoCode.name;
        _contactController.text = phoneNumber.international
            .substring(_countryDialCode!.length)
            .trim();
      }
    } catch (e) {
      debugPrint('Phone Number Parse Error: $e');
      if (phone != null && phone.isNotEmpty) {
        _contactController.text = phone;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _metaTitleController.dispose();
    _metaDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    log('Store Meta Data => ${widget.store.toJson()}');
    return Scaffold(
      appBar: CustomAppBarWidget(
        title: _module!.showRestaurantText!
            ? 'edit_restaurant_info'.tr
            : 'edit_store_info'.tr,
      ),

      body: GetBuilder<StoreController>(
        builder: (storeController) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomCard(
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeSmall,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('basic_info'.tr, style: robotoBold),
                            const SizedBox(height: Dimensions.paddingSizeSmall),
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
                                ).hintColor,
                                unselectedLabelStyle: robotoRegular.copyWith(
                                  color: Theme.of(context).hintColor,
                                  fontSize: Dimensions.fontSizeSmall,
                                ),
                                labelStyle: robotoBold.copyWith(
                                  fontSize: Dimensions.fontSizeDefault,
                                ),
                                labelPadding: const EdgeInsets.only(
                                  right: Dimensions.paddingSizeLarge,
                                ),
                                indicatorPadding: const EdgeInsets.only(
                                  right: Dimensions.paddingSizeLarge,
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
                                bottom: Dimensions.paddingSizeSmall,
                              ),
                              child: Divider(height: 0),
                            ),
                            const SizedBox(
                              height: Dimensions.paddingSizeDefault,
                            ),
                            CustomTextFieldWidget(
                              hintText:
                                  '${_module.showRestaurantText! ? 'restaurant_name'.tr : 'store_name'.tr} (${_languageList?[_tabController!.index].value!})',
                              labelText:
                                  '${_module.showRestaurantText! ? 'restaurant_name'.tr : 'store_name'.tr} (${_languageList?[_tabController!.index].value!})',
                              controller:
                                  _nameController[_tabController!.index],
                              capitalization: TextCapitalization.words,
                              focusNode: _nameNode[_tabController!.index],
                              nextFocus:
                                  _tabController!.index !=
                                      _languageList!.length - 1
                                  ? _addressNode[_tabController!.index]
                                  : _contactNode,
                              required: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeDefault),

                      CustomCard(
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeSmall,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomTextFieldWidget(
                              hintText: 'xxx-xxxxxxx',
                              labelText: 'phone_number'.tr,
                              controller: _contactController,
                              focusNode: _contactNode,
                              nextFocus: _metaTitleNode,
                              required: true,
                              inputType: TextInputType.phone,
                              isPhone: true,
                              onCountryChanged: (CountryCode countryCode) {
                                _countryDialCode = countryCode.dialCode;
                              },
                              countryDialCode:
                                  _countryCode ??
                                  CountryCode.fromCountryCode(
                                    Get.find<SplashController>()
                                        .configModel!
                                        .country!,
                                  ).code,
                              validator: (value) =>
                                  ValidateCheck.validateEmptyText(value, null),
                            ),
                            const SizedBox(
                              height: Dimensions.paddingSizeExtraLarge,
                            ),
                            CustomTextFieldWidget(
                              hintText:
                                  '${'address'.tr} (${_languageList[_tabController!.index].value!})',
                              labelText:
                                  '${'address'.tr} (${_languageList[_tabController!.index].value!})',
                              controller:
                                  _addressController[_tabController!.index],
                              focusNode: _addressNode[_tabController!.index],
                              capitalization: TextCapitalization.sentences,
                              maxLines: 3,
                              nextFocus: _contactNode,
                              required: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeDefault),

                      CustomCard(
                        width: context.width,
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeDefault,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'business_logo'.tr,
                                    style: robotoBold.copyWith(
                                      fontSize: Dimensions.fontSizeDefault,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge!.color,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '*',
                                    style: robotoRegular.copyWith(
                                      fontSize: Dimensions.fontSizeLarge,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'image_format_and_ratio_for_business_logo'.tr,
                              style: robotoRegular.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                            const SizedBox(
                              height: Dimensions.paddingSizeDefault,
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusDefault,
                                      ),
                                      child: storeController.rawLogo != null
                                          ? GetPlatform.isWeb
                                                ? Image.network(
                                                    storeController
                                                        .rawLogo!
                                                        .path,
                                                    width: 120,
                                                    height: 120,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Image.file(
                                                    File(
                                                      storeController
                                                          .rawLogo!
                                                          .path,
                                                    ),
                                                    width: 120,
                                                    height: 120,
                                                    fit: BoxFit.cover,
                                                  )
                                          : widget.store.logoFullUrl != null
                                          ? CustomImageWidget(
                                              image:
                                                  widget.store.logoFullUrl ??
                                                  '',
                                              height: 120,
                                              width: 120,
                                              fit: BoxFit.cover,
                                            )
                                          : SizedBox(
                                              width: 120,
                                              height: 120,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  CustomAssetImageWidget(
                                                    Images.uploadIcon,
                                                    height: 30,
                                                    width: 30,
                                                    color: Theme.of(
                                                      context,
                                                    ).hintColor,
                                                  ),
                                                  const SizedBox(
                                                    height: Dimensions
                                                        .paddingSizeSmall,
                                                  ),
                                                  Text(
                                                    'click_to_upload'.tr,
                                                    style: robotoMedium
                                                        .copyWith(
                                                          color: Colors.blue,
                                                          fontSize: Dimensions
                                                              .fontSizeSmall,
                                                        ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
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
                                        options: RoundedRectDottedBorderOptions(
                                          color: Theme.of(context).hintColor,
                                          strokeWidth: 1,
                                          strokeCap: StrokeCap.butt,
                                          dashPattern: const [5, 5],
                                          padding: const EdgeInsets.all(0),
                                          radius: const Radius.circular(
                                            Dimensions.radiusDefault,
                                          ),
                                        ),
                                        child: const SizedBox(
                                          width: 120,
                                          height: 120,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: Dimensions.paddingSizeLarge),
                          ],
                        ),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeDefault),

                      CustomCard(
                        width: context.width,
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeDefault,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'cover_photo'.tr,
                                    style: robotoBold.copyWith(
                                      fontSize: Dimensions.fontSizeDefault,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge!.color,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '*',
                                    style: robotoRegular.copyWith(
                                      fontSize: Dimensions.fontSizeLarge,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'image_format_and_ratio_for_business_cover'.tr,
                              style: robotoRegular.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                            const SizedBox(
                              height: Dimensions.paddingSizeDefault,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 40,
                                right: 40,
                              ),
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusDefault,
                                      ),
                                      child: storeController.rawCover != null
                                          ? GetPlatform.isWeb
                                                ? Image.network(
                                                    storeController
                                                        .rawCover!
                                                        .path,
                                                    width: context.width,
                                                    height: 140,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Image.file(
                                                    File(
                                                      storeController
                                                          .rawCover!
                                                          .path,
                                                    ),
                                                    width: context.width,
                                                    height: 140,
                                                    fit: BoxFit.cover,
                                                  )
                                          : widget.store.coverPhotoFullUrl !=
                                                null
                                          ? CustomImageWidget(
                                              image:
                                                  widget
                                                      .store
                                                      .coverPhotoFullUrl ??
                                                  '',
                                              height: 140,
                                              width: context.width * 0.7,
                                              fit: BoxFit.cover,
                                            )
                                          : SizedBox(
                                              width: context.width,
                                              height: 140,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  CustomAssetImageWidget(
                                                    Images.uploadIcon,
                                                    height: 30,
                                                    width: 30,
                                                    color: Theme.of(
                                                      context,
                                                    ).hintColor,
                                                  ),
                                                  const SizedBox(
                                                    width: Dimensions
                                                        .paddingSizeSmall,
                                                  ),
                                                  Text(
                                                    'click_to_upload'.tr,
                                                    style: robotoMedium
                                                        .copyWith(
                                                          color: Colors.blue,
                                                          fontSize: Dimensions
                                                              .fontSizeSmall,
                                                        ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
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
                                        false,
                                        false,
                                      ),
                                      child: DottedBorder(
                                        options: RoundedRectDottedBorderOptions(
                                          color: Theme.of(context).hintColor,
                                          strokeWidth: 1,
                                          strokeCap: StrokeCap.butt,
                                          dashPattern: const [5, 5],
                                          padding: const EdgeInsets.all(0),
                                          radius: const Radius.circular(
                                            Dimensions.radiusDefault,
                                          ),
                                        ),
                                        child: SizedBox(
                                          width: context.width,
                                          height: 140,
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
                      const SizedBox(height: Dimensions.paddingSizeDefault),

                      /// Meta Section
                      CustomCard(
                        width: context.width,
                        padding: const EdgeInsets.all(
                          Dimensions.paddingSizeDefault,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('meta_data'.tr, style: robotoBold),
                            const SizedBox(height: Dimensions.paddingSizeSmall),
                            Text(
                              'meta_data_des'.tr,
                              style: robotoRegular.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                                color: Theme.of(context).disabledColor,
                              ),
                            ),
                            const SizedBox(height: Dimensions.paddingSizeSmall),
                            Container(
                              padding: EdgeInsets.all(
                                Dimensions.paddingSizeSmall,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).disabledColor.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusDefault,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  // '${widget.store.metaTitle}',
                                  CustomTextFieldWidget(
                                    hintText: 'title'.tr,
                                    labelText: 'title'.tr,
                                    controller: _metaTitleController,
                                    capitalization: TextCapitalization.words,
                                    focusNode: _metaTitleNode,
                                    nextFocus: _metaDescriptionNode,
                                    showTitle: false,
                                    required: true,
                                  ),
                                  const SizedBox(
                                    height: Dimensions.paddingSizeExtraLarge,
                                  ),

                                  CustomTextFieldWidget(
                                    hintText:
                                        widget.store.metaDescription ??
                                        'meta_description'.tr,
                                    labelText: 'description'.tr,
                                    controller: _metaDescriptionController,
                                    focusNode: _metaDescriptionNode,
                                    capitalization:
                                        TextCapitalization.sentences,
                                    maxLines: 5,
                                    inputAction: TextInputAction.done,
                                    nextFocus: null,
                                    showTitle: false,
                                    required: true,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(
                              height: Dimensions.paddingSizeDefault,
                            ),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(
                                Dimensions.paddingSizeSmall,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).disabledColor.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusDefault,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'meta_image'.tr,
                                    style: robotoMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'image_format_and_ratio_for_business_logo'
                                        .tr,
                                    style: robotoRegular.copyWith(
                                      fontSize: Dimensions.fontSizeSmall,
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: Dimensions.paddingSizeSmall,
                                  ),
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            Dimensions.radiusDefault,
                                          ),
                                          child:
                                              storeController.pickedMetaImage !=
                                                  null
                                              ? GetPlatform.isWeb
                                                    ? Image.network(
                                                        storeController
                                                            .pickedMetaImage!
                                                            .path,
                                                        width: double.infinity,
                                                        height: 150,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Image.file(
                                                        File(
                                                          storeController
                                                              .pickedMetaImage!
                                                              .path,
                                                        ),
                                                        width: double.infinity,
                                                        height: 150,
                                                        fit: BoxFit.cover,
                                                      )
                                              : CustomImageWidget(
                                                  image:
                                                      '${widget.store.metaImageFullUrl}',
                                                  height: 150,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                ),
                                        ),
                                      ),

                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        top: 0,
                                        left: 0,
                                        child: InkWell(
                                          onTap: () =>
                                              storeController.pickMetaImage(),
                                          child: DottedBorder(
                                            options:
                                                RoundedRectDottedBorderOptions(
                                                  radius: const Radius.circular(
                                                    Dimensions.radiusDefault,
                                                  ),
                                                  dashPattern: const [8, 4],
                                                  strokeWidth: 1,
                                                  color: Theme.of(
                                                    context,
                                                  ).hintColor,
                                                ),
                                            child: const SizedBox(
                                              width: 120,
                                              height: 120,
                                            ),
                                          ),
                                        ),
                                      ),

                                      Positioned(
                                        top: -10,
                                        right: -10,
                                        child: InkWell(
                                          onTap: () =>
                                              storeController.pickMetaImage(),
                                          child: Container(
                                            padding: const EdgeInsets.all(
                                              Dimensions.paddingSizeExtraSmall,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).cardColor,
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.black12,
                                                  spreadRadius: 0,
                                                  blurRadius: 5,
                                                ),
                                              ],
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.blue,
                                                width: 0.5,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.edit,
                                              color: Colors.blue,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                              height: Dimensions.paddingSizeDefault,
                            ),

                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(
                                Dimensions.paddingSizeSmall,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).disabledColor.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusDefault,
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(
                                  Dimensions.paddingSizeSmall,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusDefault,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        storeController.setMetaIndex('index');
                                        storeController.setNoFollow('0');
                                        storeController.setNoImageIndex('0');
                                        storeController.setNoArchive('0');
                                        storeController.setNoSnippet('0');
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          const SizedBox(
                                            width:
                                                Dimensions
                                                    .paddingSizeExtraSmall +
                                                2,
                                          ),
                                          SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: RadioGroup<String>(
                                              groupValue:
                                                  storeController.metaIndex,
                                              onChanged: (value) {
                                                storeController.setMetaIndex(
                                                  value!,
                                                );
                                                storeController.setNoFollow(
                                                  '0',
                                                );
                                                storeController.setNoImageIndex(
                                                  '0',
                                                );
                                                storeController.setNoArchive(
                                                  '0',
                                                );
                                                storeController.setNoSnippet(
                                                  '0',
                                                );
                                              },
                                              child: Radio<String>(
                                                value: 'index',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: Dimensions.paddingSizeSmall,
                                          ),

                                          Text(
                                            'index'.tr,
                                            style: robotoRegular.copyWith(
                                              fontSize:
                                                  Dimensions.fontSizeDefault,
                                              color: Theme.of(
                                                context,
                                              ).textTheme.bodyLarge?.color,
                                            ),
                                          ),
                                          const SizedBox(
                                            width: Dimensions.paddingSizeSmall,
                                          ),

                                          CustomToolTip(
                                            message:
                                                'allow_search_engines_to_index_this_page'
                                                    .tr,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: Dimensions.paddingSizeSmall,
                                    ),

                                    MetaSeoItem(
                                      title: 'no_follow'.tr,
                                      value:
                                          storeController.noFollow == 'nofollow'
                                          ? true
                                          : false,
                                      callback: (bool? value) {
                                        storeController.setNoFollow(
                                          value! ? 'nofollow' : '0',
                                        );
                                      },
                                      message:
                                          'instruct_search_engines_not_to_follow_links_from_this_page'
                                              .tr,
                                    ),

                                    MetaSeoItem(
                                      title: 'no_image_index'.tr,
                                      value:
                                          storeController.noImageIndex ==
                                              'noimageindex'
                                          ? true
                                          : false,
                                      callback: (bool? value) {
                                        storeController.setNoImageIndex(
                                          value! ? 'noimageindex' : '0',
                                        );
                                      },
                                      message:
                                          'prevent_images_from_being_indexed'
                                              .tr,
                                    ),
                                    const SizedBox(
                                      height: Dimensions.paddingSizeSmall,
                                    ),

                                    InkWell(
                                      onTap: () {
                                        storeController.setMetaIndex('noindex');
                                        storeController.setNoFollow('nofollow');
                                        storeController.setNoImageIndex(
                                          'noimageindex',
                                        );
                                        storeController.setNoArchive(
                                          'noarchive',
                                        );
                                        storeController.setNoSnippet(
                                          'nosnippet',
                                        );
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          const SizedBox(
                                            width:
                                                Dimensions
                                                    .paddingSizeExtraSmall +
                                                2,
                                          ),
                                          SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: RadioGroup<String>(
                                              groupValue:
                                                  storeController.metaIndex,
                                              onChanged: (value) {
                                                storeController.setMetaIndex(
                                                  value!,
                                                );
                                                storeController.setNoFollow(
                                                  'nofollow',
                                                );
                                                storeController.setNoImageIndex(
                                                  'noimageindex',
                                                );
                                                storeController.setNoArchive(
                                                  'noarchive',
                                                );
                                                storeController.setNoSnippet(
                                                  'nosnippet',
                                                );
                                              },
                                              child: Radio<String>(
                                                value: 'noindex',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: Dimensions.paddingSizeSmall,
                                          ),

                                          Text(
                                            'no_index'.tr,
                                            style: robotoRegular.copyWith(
                                              fontSize:
                                                  Dimensions.fontSizeDefault,
                                              color: Theme.of(
                                                context,
                                              ).textTheme.bodyLarge?.color,
                                            ),
                                          ),
                                          const SizedBox(
                                            width: Dimensions.paddingSizeSmall,
                                          ),

                                          CustomToolTip(
                                            message:
                                                'disallow_search_engines_from_indexing_this_page'
                                                    .tr,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: Dimensions.paddingSizeSmall,
                                    ),

                                    MetaSeoItem(
                                      title: 'no_archive'.tr,
                                      value:
                                          storeController.noArchive ==
                                              'noarchive'
                                          ? true
                                          : false,
                                      callback: (bool? value) {
                                        storeController.setNoArchive(
                                          value! ? 'noarchive' : '0',
                                        );
                                      },
                                      message:
                                          'prevent_search_engines_from_caching_this_page'
                                              .tr,
                                    ),

                                    MetaSeoItem(
                                      title: 'no_snippet'.tr,
                                      value:
                                          storeController.noSnippet ==
                                              'nosnippet'
                                          ? true
                                          : false,
                                      callback: (bool? value) {
                                        storeController.setNoSnippet(
                                          value! ? 'nosnippet' : '0',
                                        );
                                      },
                                      message:
                                          'prevent_search_engines_from_showing_snippet'
                                              .tr,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: Dimensions.paddingSizeLarge),

                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(
                                Dimensions.paddingSizeSmall,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).disabledColor.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(
                                  Dimensions.radiusDefault,
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(
                                  Dimensions.paddingSizeSmall,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(
                                    Dimensions.radiusDefault,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          MetaSeoItem(
                                            title: 'max_snippet'.tr,
                                            value:
                                                storeController.maxSnippet ==
                                                    '1'
                                                ? true
                                                : false,
                                            callback: (bool? value) {
                                              storeController.setMaxSnippet(
                                                value! ? '1' : '0',
                                              );
                                            },
                                          ),
                                          SizedBox(
                                            height: Dimensions.paddingSizeSmall,
                                          ),

                                          MetaSeoItem(
                                            title: 'max_video_preview'.tr,
                                            value:
                                                storeController
                                                        .maxVideoPreview ==
                                                    '1'
                                                ? true
                                                : false,
                                            callback: (bool? value) {
                                              storeController
                                                  .setMaxVideoPreview(
                                                    value! ? '1' : '0',
                                                  );
                                            },
                                          ),
                                          SizedBox(
                                            height: Dimensions.paddingSizeSmall,
                                          ),

                                          MetaSeoItem(
                                            title: 'max_image_preview'.tr,
                                            value:
                                                storeController
                                                        .maxImagePreview ==
                                                    '1'
                                                ? true
                                                : false,
                                            callback: (bool? value) {
                                              storeController
                                                  .setMaxImagePreview(
                                                    value! ? '1' : '0',
                                                  );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                      width: Dimensions.paddingSizeDefault,
                                    ),

                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            height: 48,
                                            child: CustomTextFieldWidget(
                                              hintText: 'ex_1'.tr,
                                              showLabelText: false,
                                              inputType: TextInputType.number,
                                              controller: _maxSnippetController,
                                            ),
                                          ),
                                          SizedBox(
                                            height: Dimensions.paddingSizeSmall,
                                          ),

                                          SizedBox(
                                            height: 48,
                                            child: CustomTextFieldWidget(
                                              hintText: 'ex_1'.tr,
                                              showLabelText: false,
                                              inputType: TextInputType.number,
                                              controller:
                                                  _maxVideoPreviewController,
                                            ),
                                          ),
                                          SizedBox(
                                            height: Dimensions.paddingSizeSmall,
                                          ),

                                          Container(
                                            height: 48,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal:
                                                  Dimensions.paddingSizeSmall,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Theme.of(context)
                                                    .disabledColor
                                                    .withValues(alpha: 0.5),
                                                width: 1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    Dimensions.radiusDefault,
                                                  ),
                                              color: Theme.of(
                                                context,
                                              ).cardColor,
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: storeController
                                                    .imagePreviewSelectedType,
                                                items: storeController
                                                    .imagePreviewType
                                                    .map((String value) {
                                                      return DropdownMenuItem<
                                                        String
                                                      >(
                                                        value: value,
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          alignment: Alignment
                                                              .centerLeft,
                                                          child: Text(
                                                            value.tr,
                                                            style: robotoRegular.copyWith(
                                                              fontSize: Dimensions
                                                                  .fontSizeDefault,
                                                              color:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodyLarge
                                                                      ?.color,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    })
                                                    .toList(),
                                                onChanged: (value) {
                                                  storeController
                                                      .setImagePreviewType(
                                                        value!,
                                                      );
                                                },
                                                isExpanded: true,
                                                icon: Icon(
                                                  Icons
                                                      .keyboard_arrow_down_rounded,
                                                  color: Theme.of(
                                                    context,
                                                  ).primaryColor,
                                                  size: 24,
                                                ),
                                                dropdownColor: Theme.of(
                                                  context,
                                                ).cardColor,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      Dimensions.radiusDefault,
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
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Dimensions.paddingSizeDefault),
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      spreadRadius: 1,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: CustomButtonWidget(
                  isLoading: storeController.isLoading,
                  onPressed: () async {
                    bool defaultNameNull = false;
                    bool defaultAddressNull = false;

                    for (int index = 0; index < _languageList.length; index++) {
                      if (_languageList[index].key == 'en') {
                        if (_nameController[index].text.trim().isEmpty) {
                          defaultNameNull = true;
                        }
                        if (_addressController[index].text.trim().isEmpty) {
                          defaultAddressNull = true;
                        }
                        break;
                      }
                    }

                    String contact = _contactController.text.trim();
                    String metaTitle = _metaTitleController.text.trim();
                    String metaDescription = _metaDescriptionController.text
                        .trim();

                    String numberWithCountryCode;
                    if (contact.startsWith('+') ||
                        contact.startsWith(
                          _countryDialCode!.replaceAll('+', ''),
                        )) {
                      numberWithCountryCode = contact.startsWith('+')
                          ? contact
                          : '+$contact';
                    } else {
                      numberWithCountryCode = _countryDialCode! + contact;
                    }
                    PhoneValid phoneValid =
                        await CustomValidatorHelper.isPhoneValid(
                          numberWithCountryCode,
                        );
                    numberWithCountryCode = phoneValid.phone;

                    bool? showRestaurantText = _module.showRestaurantText;

                    if (defaultNameNull) {
                      showCustomSnackBar(
                        showRestaurantText!
                            ? 'enter_your_restaurant_name'.tr
                            : 'enter_your_store_name'.tr,
                      );
                    } else if (defaultAddressNull) {
                      showCustomSnackBar(
                        showRestaurantText!
                            ? 'enter_restaurant_address'.tr
                            : 'enter_store_address'.tr,
                      );
                    } else if (contact.isEmpty) {
                      showCustomSnackBar(
                        showRestaurantText!
                            ? 'enter_restaurant_contact_number'.tr
                            : 'enter_store_contact_number'.tr,
                      );
                    } else if (!phoneValid.isValid) {
                      showCustomSnackBar(
                        showRestaurantText!
                            ? 'enter_valid_restaurant_contact_number'.tr
                            : 'enter_valid_store_contact_number'.tr,
                      );
                    } else if (widget.store.logoFullUrl == null &&
                        storeController.rawLogo == null) {
                      showCustomSnackBar('upload_business_logo'.tr);
                    } else if (widget.store.coverPhotoFullUrl == null &&
                        storeController.rawCover == null) {
                      showCustomSnackBar('upload_cover_image'.tr);
                    } else if (metaTitle.isEmpty) {
                      showCustomSnackBar('enter_meta_title'.tr);
                    } else if (metaDescription.isEmpty) {
                      showCustomSnackBar('enter_meta_description'.tr);
                    } else {
                      List<Translation> translation = [];

                      for (
                        int index = 0;
                        index < _languageList.length;
                        index++
                      ) {
                        translation.add(
                          Translation(
                            locale: _languageList[index].key,
                            key: 'name',
                            value: _nameController[index].text.trim().isNotEmpty
                                ? _nameController[index].text.trim()
                                : _nameController[0].text.trim(),
                          ),
                        );
                        translation.add(
                          Translation(
                            locale: _languageList[index].key,
                            key: 'address',
                            value:
                                _addressController[index].text.trim().isNotEmpty
                                ? _addressController[index].text.trim()
                                : _addressController[0].text.trim(),
                          ),
                        );
                      }

                      _store.phone = numberWithCountryCode;
                      _store.metaTitle = metaTitle;
                      _store.metaDescription = metaDescription;
                      MetaSeoData metaSeoData = MetaSeoData(
                        metaIndex: storeController.metaIndex,
                        metaNoFollow: storeController.noFollow,
                        metaNoImageIndex: storeController.noImageIndex,
                        metaNoArchive: storeController.noArchive,
                        metaNoSnippet: storeController.noSnippet,
                        metaMaxSnippet: storeController.maxSnippet,
                        metaMaxVideoPreview: storeController.maxVideoPreview,
                        metaMaxImagePreview: storeController.maxImagePreview,
                        metaMaxSnippetValue: _maxSnippetController.text.trim(),
                        metaMaxVideoPreviewValue: _maxVideoPreviewController
                            .text
                            .trim(),
                        metaMaxImagePreviewValue:
                            storeController.imagePreviewSelectedType,
                      );
                      _store.metaData = metaSeoData;

                      storeController.updateStoreBasicInfo(_store, translation);
                    }
                  },
                  buttonText: 'update'.tr,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
