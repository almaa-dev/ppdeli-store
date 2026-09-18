import 'package:flutter/foundation.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

class CustomValidatorHelper {

  static Future<PhoneValid> isPhoneValid(String number) async {
    String phone = '';
    String countryCode = '';
    bool isValid = false;
      try {
        PhoneNumber phoneNumber = PhoneNumber.parse(number);
        isValid = phoneNumber.isValid(type: PhoneNumberType.mobile);
        countryCode = phoneNumber.countryCode;
        if(isValid) {
          phone = '+${phoneNumber.countryCode}${phoneNumber.nsn}';
        }
      } catch (e) {
        debugPrint('Phone Number Parse Error: $e');
      }
    return PhoneValid(isValid: isValid, countryCode: countryCode, phone: phone);
  }

}

class PhoneValid {
  bool isValid;
  String phone;
  String countryCode;
  PhoneValid({required this.isValid, required this.phone, required this.countryCode});
}