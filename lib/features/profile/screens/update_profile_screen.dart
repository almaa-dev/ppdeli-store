import 'dart:io';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:ppdelistore/common/widgets/confirmation_dialog_widget.dart';
import 'package:ppdelistore/common/widgets/custom_popup_menu_button.dart';
import 'package:ppdelistore/common/widgets/custom_tool_tip_widget.dart';
import 'package:ppdelistore/common/widgets/switch_button_widget.dart';
import 'package:ppdelistore/features/auth/controllers/auth_controller.dart';
import 'package:ppdelistore/features/language/controllers/language_controller.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/features/profile/domain/models/profile_model.dart';
import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:ppdelistore/helper/custom_validator_helper.dart';
import 'package:ppdelistore/helper/route_helper.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/images.dart';
import 'package:ppdelistore/common/widgets/custom_button_widget.dart';
import 'package:ppdelistore/common/widgets/custom_snackbar_widget.dart';
import 'package:ppdelistore/common/widgets/text_field_widget.dart';
import 'package:ppdelistore/features/profile/widgets/profile_bg_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/util/styles.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isOwner = false;
  String? _countryDialCode;
  bool _isPhoneLoading = true;

  @override
  void initState() {
    super.initState();

    if (Get.find<ProfileController>().profileModel == null) {
      Get.find<ProfileController>().getProfile();
    }
    _isOwner = Get.find<AuthController>().getUserType() == 'owner';
    _countryDialCode = CountryCode.fromCountryCode(
      Get.find<SplashController>().configModel!.country!,
    ).dialCode;
  }

  void _splitPhoneNumber(String number) async {
    _isPhoneLoading = true;
    try {
      PhoneValid phoneNumber = await CustomValidatorHelper.isPhoneValid(number);
      _phoneController.text = phoneNumber.phone.replaceFirst(
        '+${phoneNumber.countryCode}',
        '',
      );
      _countryDialCode = '+${phoneNumber.countryCode}';
    } catch (_) {}
    setState(() {
      _isPhoneLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<MenuItem> items = [
      MenuItem(
        'delete_account'.tr,
        Icons.delete_forever_rounded,
        1,
        Colors.red,
      ),
    ];
    return Scaffold(
      body: GetBuilder<ProfileController>(
        builder: (profileController) {
          if (profileController.profileModel != null &&
              _phoneController.text.isEmpty &&
              _isPhoneLoading) {
            if (profileController.profileModel?.phone != null &&
                profileController.profileModel!.phone!.isNotEmpty) {
              _splitPhoneNumber(profileController.profileModel!.phone!);
            }
          }

          if (profileController.profileModel != null &&
              _emailController.text.isEmpty) {
            _firstNameController.text =
                profileController.profileModel!.fName ?? '';
            _lastNameController.text =
                profileController.profileModel!.lName ?? '';
            _phoneController.text = profileController.profileModel!.phone ?? '';
            _emailController.text = profileController.profileModel!.email ?? '';
          }

          return profileController.profileModel != null
              ? ProfileBgWidget(
                  backButton: true,
                  circularImage: Center(
                    child: Stack(
                      children: [
                        ClipOval(
                          child: profileController.pickedFile != null
                              ? GetPlatform.isWeb
                                    ? Image.network(
                                        profileController.pickedFile!.path,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(
                                          profileController.pickedFile!.path,
                                        ),
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      )
                              : FadeInImage.assetNetwork(
                                  placeholder: Images.placeholder,
                                  image:
                                      '${profileController.profileModel!.imageFullUrl}',
                                  height: 100,
                                  width: 100,
                                  fit: BoxFit.cover,
                                  imageErrorBuilder: (c, o, s) => Image.asset(
                                    Images.placeholder,
                                    height: 100,
                                    width: 100,
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
                            onTap: () => profileController.pickImage(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  width: 1,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(25),
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
                      ],
                    ),
                  ),
                  menuButton: CustomPopupMenuButton(
                    items: items,
                    onSelected: (int value) {
                      if (value == 1) {
                        Get.dialog(
                          ConfirmationDialogWidget(
                            icon: Images.warning,
                            title: 'are_you_sure_to_delete_account'.tr,
                            description:
                                'it_will_remove_your_all_information'.tr,
                            isLogOut: true,
                            onYesPressed: () =>
                                profileController.deleteVendor(),
                          ),
                          useSafeArea: false,
                        );
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          Dimensions.radiusSmall,
                        ),
                        color: Theme.of(
                          context,
                        ).disabledColor.withValues(alpha: 0.1),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimensions.paddingSizeSmall,
                        vertical: 2,
                      ),
                      child: Icon(
                        Icons.more_vert_sharp,
                        color: Theme.of(context).cardColor,
                      ),
                    ),
                  ),
                  mainWidget: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.all(
                            Dimensions.paddingSizeSmall,
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 1170,
                              child: Column(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(
                                        Dimensions.radiusDefault,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context).disabledColor
                                              .withValues(alpha: 0.2),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: Dimensions.paddingSizeLarge,
                                      vertical: Dimensions.paddingSizeLarge,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'basic_information'.tr,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                        const SizedBox(
                                          height: Dimensions.paddingSizeLarge,
                                        ),

                                        TextFieldWidget(
                                          hintText: 'first_name'.tr,
                                          labelText: 'first_name'.tr,
                                          controller: _firstNameController,
                                          focusNode: _firstNameFocus,
                                          nextFocus: _lastNameFocus,
                                          inputType: TextInputType.name,
                                          capitalization:
                                              TextCapitalization.words,
                                          required: true,
                                          showLabelText: true,
                                          showTitle: false,
                                        ),
                                        const SizedBox(
                                          height: Dimensions.paddingSizeLarge,
                                        ),

                                        TextFieldWidget(
                                          hintText: 'last_name'.tr,
                                          labelText: 'last_name'.tr,
                                          controller: _lastNameController,
                                          focusNode: _lastNameFocus,
                                          nextFocus: _phoneFocus,
                                          inputType: TextInputType.name,
                                          capitalization:
                                              TextCapitalization.words,
                                          required: true,
                                          showLabelText: true,
                                          showTitle: false,
                                        ),
                                        const SizedBox(
                                          height: Dimensions.paddingSizeLarge,
                                        ),

                                        TextFieldWidget(
                                          hintText: 'phone'.tr,
                                          labelText: 'phone'.tr,
                                          controller: _phoneController,
                                          focusNode: _phoneFocus,
                                          inputType: TextInputType.phone,
                                          inputAction: TextInputAction.done,
                                          required: true,
                                          showLabelText: true,
                                          showTitle: false,
                                          isPhone: true,
                                          onCountryChanged:
                                              (CountryCode countryCode) =>
                                                  _countryDialCode =
                                                      countryCode.dialCode,
                                          countryDialCode:
                                              _countryDialCode ??
                                              Get.find<LocalizationController>()
                                                  .locale
                                                  .countryCode,
                                        ),
                                        const SizedBox(
                                          height: Dimensions.paddingSizeLarge,
                                        ),

                                        // TextFieldWidget(
                                        //   hintText: 'email'.tr,
                                        //   labelText: 'email'.tr,
                                        //   controller: _emailController,
                                        //   focusNode: _emailFocus,
                                        //   inputAction: TextInputAction.done,
                                        //   inputType: TextInputType.emailAddress,
                                        //   isEnabled: false,
                                        //   showLabelText: true,
                                        //   showTitle: false,
                                        // ),
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            CustomToolTip(
                                              message:
                                                  'email_can_not_be_edited'.tr,
                                              preferredDirection:
                                                  AxisDirection.up,
                                              child: Container(
                                                height: 50,
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(
                                                    context,
                                                  ).cardColor,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        Dimensions
                                                            .radiusDefault,
                                                      ),
                                                  border: Border.all(
                                                    color: Theme.of(context)
                                                        .hintColor
                                                        .withValues(alpha: 0.5),
                                                    width: 1,
                                                  ),
                                                ),
                                                padding: const EdgeInsets.only(
                                                  left: Dimensions
                                                      .paddingSizeDefault,
                                                  right: Dimensions
                                                      .paddingSizeSmall,
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    // Icon(CupertinoIcons.mail_solid, color: Theme.of(context).hintColor.withValues(alpha: 0.5), size: 17),
                                                    const SizedBox(width: 15),
                                                    Flexible(
                                                      fit: FlexFit
                                                          .loose, // Use Flexible with FlexFit.loose
                                                      child: Text(
                                                        _emailController.text,
                                                        style: robotoRegular
                                                            .copyWith(
                                                              color: Theme.of(
                                                                context,
                                                              ).hintColor,
                                                              fontSize: Dimensions
                                                                  .fontSizeDefault,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            Positioned(
                                              left: 10,
                                              top: -15,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Theme.of(
                                                    context,
                                                  ).cardColor,
                                                ),
                                                padding: const EdgeInsets.all(
                                                  5,
                                                ),
                                                child: Text(
                                                  'email'.tr,
                                                  style: robotoRegular.copyWith(
                                                    color: Theme.of(
                                                      context,
                                                    ).hintColor,
                                                    fontSize: Dimensions
                                                        .fontSizeSmall,
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
                                    height: Dimensions.paddingSizeLarge,
                                  ),

                                  _isOwner
                                      ? SwitchButtonWidget(
                                          icon: Icons.lock,
                                          title: 'change_password'.tr,
                                          onTap: () {
                                            Get.toNamed(
                                              RouteHelper.getResetPasswordRoute(
                                                '',
                                                '',
                                                'password-change',
                                              ),
                                            );
                                          },
                                        )
                                      : const SizedBox(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      SafeArea(
                        top: false,
                        child: !profileController.isLoading
                            ? CustomButtonWidget(
                                onPressed: () =>
                                    _updateProfile(profileController),
                                margin: const EdgeInsets.all(
                                  Dimensions.paddingSizeSmall,
                                ),
                                buttonText: 'update'.tr,
                              )
                            : const Center(child: CircularProgressIndicator()),
                      ),
                    ],
                  ),
                )
              : const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  void _updateProfile(ProfileController profileController) async {
    String firstName = _firstNameController.text.trim();
    String lastName = _lastNameController.text.trim();
    String email = _emailController.text.trim();
    String phoneNumber = _phoneController.text.trim();
    String numberWithCountryCode = _countryDialCode! + phoneNumber;
    PhoneValid phoneValid = await CustomValidatorHelper.isPhoneValid(
      numberWithCountryCode,
    );
    numberWithCountryCode = phoneValid.phone;

    if (!phoneValid.isValid) {
      showCustomSnackBar('invalid_phone_number'.tr);
    } else if (profileController.profileModel!.fName == firstName &&
        profileController.profileModel!.lName == lastName &&
        profileController.profileModel!.phone == phoneNumber &&
        profileController.profileModel!.email == _emailController.text &&
        profileController.pickedFile == null) {
      showCustomSnackBar('change_something_to_update'.tr);
    } else if (firstName.isEmpty) {
      showCustomSnackBar('enter_your_first_name'.tr);
    } else if (lastName.isEmpty) {
      showCustomSnackBar('enter_your_last_name'.tr);
    } else if (email.isEmpty) {
      showCustomSnackBar('enter_email_address'.tr);
    } else if (!GetUtils.isEmail(email)) {
      showCustomSnackBar('enter_a_valid_email_address'.tr);
    } else if (phoneNumber.isEmpty) {
      showCustomSnackBar('enter_phone_number'.tr);
    } /*else if (phoneNumber.length < 6) {
      showCustomSnackBar('enter_a_valid_phone_number'.tr);
    } */ else {
      ProfileModel updatedUser = ProfileModel(
        fName: firstName,
        lName: lastName,
        email: email,
        phone: numberWithCountryCode,
      );
      await profileController.updateUserInfo(
        updatedUser,
        Get.find<AuthController>().getUserToken(),
      );
    }
  }
}
