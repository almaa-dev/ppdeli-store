import 'package:country_code_picker/country_code_picker.dart';
import 'package:ppdelistore/common/widgets/code_picker_widget.dart';
import 'package:ppdelistore/util/dimensions.dart';
import 'package:ppdelistore/util/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class TextFieldWidget extends StatefulWidget {
  final String hintText;
  final String? titleText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocus;
  final TextInputType inputType;
  final TextInputAction inputAction;
  final bool isPassword;
  final Function? onChanged;
  final Function? onSubmit;
  final bool isEnabled;
  final int maxLines;
  final TextCapitalization capitalization;
  final String? prefixImage;
  final IconData? prefixIcon;
  final bool divider;
  final bool showTitle;
  final bool isAmount;
  final bool isNumber;
  final bool isPhone;
  final String? countryDialCode;
  final Function(CountryCode countryCode)? onCountryChanged;
  final bool showBorder;
  final double iconSize;
  final Color? borderColor;
  final bool showLabelText;
  final bool required;
  final String? labelText;
  final double? levelTextSize;
  final bool fromUpdateProfile;
  final String? Function(String?)? validator;
  final IconData? suffixIcon;
  final Function()? onSuffixPressed;
  final Function()? onTap;
  final bool readOnly;
  final Color? suffixIconColor;
  final bool hideEnableText;
  final int? maxLength;
  final bool onFocusChanged;

  const TextFieldWidget({
    super.key,
    this.hintText = 'Write something...',
    this.titleText,
    this.controller,
    this.focusNode,
    this.nextFocus,
    this.isEnabled = true,
    this.inputType = TextInputType.text,
    this.inputAction = TextInputAction.next,
    this.maxLines = 1,
    this.onSubmit,
    this.onChanged,
    this.prefixImage,
    this.prefixIcon,
    this.capitalization = TextCapitalization.none,
    this.isPassword = false,
    this.divider = false,
    this.showTitle = true,
    this.isAmount = false,
    this.isNumber = false,
    this.isPhone = false,
    this.countryDialCode,
    this.onCountryChanged,
    this.showBorder = true,
    this.iconSize = 18,
    this.borderColor,
    this.showLabelText = false,
    this.required = false,
    this.labelText,
    this.levelTextSize,
    this.fromUpdateProfile = false,
    this.validator,
    this.suffixIcon,
    this.onSuffixPressed,
    this.onTap,
    this.readOnly = false,
    this.suffixIconColor,
    this.hideEnableText = false,
    this.maxLength,
    this.onFocusChanged = true,
  });

  @override
  TextFieldWidgetState createState() => TextFieldWidgetState();
}

class TextFieldWidgetState extends State<TextFieldWidget> {
  bool _obscureText = true;

  void onFocusChanged() {
    FocusScope.of(context).unfocus();
    FocusScope.of(Get.context!).requestFocus(widget.focusNode);
    widget.focusNode?.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.showTitle
            ? RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: widget.titleText ?? widget.hintText,
                      style: robotoRegular.copyWith(
                        fontSize: Dimensions.fontSizeSmall,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                    TextSpan(
                      text: ' *',
                      style: robotoMedium.copyWith(
                        fontSize: Dimensions.fontSizeDefault,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox(),
        // widget.showTitle ? Text(widget.titleText ?? widget.hintText, style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeSmall)) : const SizedBox(),
        SizedBox(
          height: widget.showTitle ? Dimensions.paddingSizeExtraSmall : 0,
        ),

        TextFormField(
          onTap: widget.onFocusChanged ? onFocusChanged : widget.onTap,
          maxLines: widget.maxLines,
          controller: widget.controller,
          focusNode: widget.focusNode,
          readOnly: widget.readOnly,
          style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeDefault),
          textInputAction: widget.inputAction,
          validator: widget.validator,
          keyboardType: widget.isAmount
              ? TextInputType.number
              : widget.inputType,
          cursorColor: Theme.of(context).primaryColor,
          textCapitalization: widget.capitalization,
          enabled: widget.isEnabled,
          autofocus: false,
          maxLength: widget.maxLength,
          autofillHints: widget.inputType == TextInputType.name
              ? [AutofillHints.name]
              : widget.inputType == TextInputType.emailAddress
              ? [AutofillHints.email]
              : widget.inputType == TextInputType.phone
              ? [AutofillHints.telephoneNumber]
              : widget.inputType == TextInputType.streetAddress
              ? [AutofillHints.fullStreetAddress]
              : widget.inputType == TextInputType.url
              ? [AutofillHints.url]
              : widget.inputType == TextInputType.visiblePassword
              ? [AutofillHints.password]
              : null,
          obscureText: widget.isPassword ? _obscureText : false,
          inputFormatters: widget.inputType == TextInputType.phone
              ? <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp('[0-9+]')),
                ]
              : widget.isAmount
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : widget.isNumber
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))]
              : null,
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              borderSide: BorderSide(
                style: widget.showBorder ? BorderStyle.solid : BorderStyle.none,
                width: 0.5,
                color: Theme.of(context).disabledColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              borderSide: BorderSide(
                style: widget.showBorder ? BorderStyle.solid : BorderStyle.none,
                width: 1,
                color: Theme.of(context).disabledColor,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              borderSide: BorderSide(
                style: widget.showBorder ? BorderStyle.solid : BorderStyle.none,
                width: 0.5,
                color: Theme.of(context).disabledColor,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
              borderSide: BorderSide(
                style: widget.showBorder ? BorderStyle.solid : BorderStyle.none,
                width: 0.5,
                color: Theme.of(context).disabledColor,
              ),
            ),
            isDense: true,
            hintText: widget.hintText,
            fillColor: !widget.isEnabled
                ? Theme.of(context).hintColor.withValues(alpha: 0.1)
                : Theme.of(context).cardColor,
            hintStyle: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeDefault,
              color: Theme.of(context).hintColor,
            ),
            filled: true,
            labelStyle: widget.showLabelText
                ? robotoRegular.copyWith(
                    fontSize: Dimensions.fontSizeDefault,
                    color: Theme.of(context).hintColor,
                  )
                : null,
            errorStyle: robotoRegular.copyWith(
              fontSize: Dimensions.fontSizeSmall,
            ),
            label: widget.showLabelText
                ? Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: widget.labelText ?? '',
                          style: robotoRegular.copyWith(
                            fontSize:
                                widget.levelTextSize ??
                                Dimensions.fontSizeDefault,
                            color:
                                ((widget.focusNode?.hasFocus == true ||
                                        widget.controller!.text.isNotEmpty) &&
                                    widget.isEnabled)
                                ? Theme.of(context).textTheme.bodyLarge?.color
                                : Theme.of(context).hintColor,
                          ),
                        ),
                        if (widget.required && widget.labelText != null)
                          TextSpan(
                            text: ' *',
                            style: robotoRegular.copyWith(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: Dimensions.fontSizeDefault,
                            ),
                          ),
                        if (widget.isEnabled == false)
                          TextSpan(
                            text: widget.hideEnableText
                                ? ''
                                : widget.fromUpdateProfile
                                ? ' (${'phone_number_can_not_be_edited'.tr})'
                                : ' (${'non_changeable'.tr})',
                            style: robotoRegular.copyWith(
                              fontSize: Dimensions.fontSizeDefault,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  )
                : null,
            prefixIcon: widget.isPhone
                ? SizedBox(
                    width: 95,
                    child: Row(
                      children: [
                        Container(
                          width: 85,
                          height: 50,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(Dimensions.radiusSmall),
                              bottomLeft: Radius.circular(
                                Dimensions.radiusSmall,
                              ),
                            ),
                          ),
                          margin: const EdgeInsets.only(right: 0),
                          padding: const EdgeInsets.only(left: 5),
                          child: Center(
                            child: CodePickerWidget(
                              dialogBackgroundColor: Theme.of(
                                context,
                              ).cardColor,
                              flagWidth: 25,
                              padding: EdgeInsets.zero,
                              onChanged: widget.onCountryChanged,
                              initialSelection: widget.countryDialCode,
                              favorite: [widget.countryDialCode!],
                              textStyle: robotoRegular.copyWith(
                                fontSize: Dimensions.fontSizeDefault,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium!.color,
                              ),
                            ),
                          ),
                        ),

                        Container(
                          height: 20,
                          width: 2,
                          color: Theme.of(context).disabledColor,
                        ),
                      ],
                    ),
                  )
                : widget.prefixImage != null && widget.prefixIcon == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeSmall,
                      vertical: Dimensions.paddingSizeDefault,
                    ),
                    child: Image.asset(
                      widget.prefixImage!,
                      height: 20,
                      width: 20,
                    ),
                  )
                : widget.prefixImage == null && widget.prefixIcon != null
                ? Icon(
                    widget.prefixIcon,
                    size: widget.iconSize,
                    color: widget.focusNode?.hasFocus == true
                        ? Theme.of(context).textTheme.bodyLarge?.color
                        : Theme.of(context).disabledColor,
                  )
                : null,
            suffixIcon: widget.suffixIcon != null && !widget.isPassword
                ? Icon(
                    widget.suffixIcon,
                    color:
                        widget.suffixIconColor ??
                        Theme.of(context).disabledColor,
                    size: 22,
                  )
                : widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      color: Theme.of(context).disabledColor,
                    ),
                    onPressed: _toggle,
                  )
                : null,
          ),
          onFieldSubmitted: (text) => widget.nextFocus != null
              ? FocusScope.of(context).requestFocus(widget.nextFocus)
              : widget.onSubmit != null
              ? widget.onSubmit!(text)
              : null,
          onChanged: widget.onChanged as void Function(String)?,
        ),

        widget.divider
            ? const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: Dimensions.paddingSizeLarge,
                ),
                child: Divider(),
              )
            : const SizedBox(),
      ],
    );
  }

  void _toggle() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }
}
