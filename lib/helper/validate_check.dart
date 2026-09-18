import 'package:get/get.dart';

class ValidateCheck{

  static String? validateEmail(String? value) {
    const pattern = r"(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'"
        r'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-'
        r'\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*'
        r'[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:(2(5[0-5]|[0-4]'
        r'[0-9])|1[0-9][0-9]|[1-9]?[0-9]))\.){3}(?:(2(5[0-5]|[0-4][0-9])|1[0-9]'
        r'[0-9]|[1-9]?[0-9])|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\'
        r'x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])';
    final kEmailValid = RegExp(pattern);
    bool isValid = kEmailValid.hasMatch(value.toString());
    if (value!.isEmpty) {
      return '\u26A0 ${'email_field_is_required'.tr}';
    } else if (isValid == false) {
      return '\u26A0 ${"enter_valid_email_address".tr}';
    }
    return null;
  }

  static String? validateEmptyText(String? value, String? message) {
    if (value == null || value.isEmpty) {
      return message?.tr ?? 'this_field_is_required'.tr;
    }
    return null;
  }

  static String? validatePhone(String? value, String? message) {
    if (value == null || value.isEmpty) {
      return message?.tr ?? 'this_field_is_required'.tr;
    }
    return null;
  }

  static String? validateUrl(String? value, {String? emptyMessage, String? invalidMessage, bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? (emptyMessage?.tr ?? 'this_field_is_required'.tr) : null;
    }

    final Uri? uri = Uri.tryParse(value.trim());
    final bool isValid = uri != null
        && (uri.scheme == 'http' || uri.scheme == 'https')
        && uri.host.isNotEmpty;

    if (!isValid) {
      return invalidMessage?.tr ?? 'please_enter_a_valid_url'.tr;
    }

    return null;
  }

  static String? validatePassword(String? value, String? message) {
    if (value == null || value.isEmpty) {
      return message?.tr ?? 'this_field_is_required'.tr;
    }else if(value.length < 8){
      return 'minimum_password_is_8_character'.tr;
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'confirm_password_field_is_required'.tr;
    }else if(value != password){
      return 'confirm_password_does_not_matched'.tr;
    }
    return null;
  }

  static String? loyaltyCheck(String? value, int? minimumExchangePoint, int? point) {
    int amount = 0;
    if(value != null && value.isNotEmpty) {
      amount = int.parse(value);
    }
    if (value == null || value.isEmpty) {
      return 'this_field_is_required'.tr;
    }else if(amount < minimumExchangePoint!){
      return '${'please_exchange_more_then'.tr} $minimumExchangePoint ${'points'.tr}';
    }else if(point! < amount){
      return 'you_do_not_have_enough_point_to_exchange'.tr;
    }
    return null;
  }
}
