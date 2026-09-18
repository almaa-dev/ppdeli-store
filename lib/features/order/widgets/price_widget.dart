import 'package:flutter/material.dart';
import 'package:ppdelistore/util/styles.dart';

class PriceWidget extends StatelessWidget {
  final String title;
  final String value;
  final double fontSize;
  final bool emphasized;

  const PriceWidget({
    super.key,
    required this.title,
    required this.value,
    required this.fontSize,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = (emphasized ? robotoBlack : robotoMedium)
        .copyWith(color: Colors.black, fontSize: fontSize, height: 1.2);
    final TextStyle valueStyle = (emphasized ? robotoBlack : robotoBold)
        .copyWith(color: Colors.black, fontSize: fontSize, height: 1.2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: Text(title, style: titleStyle)),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: Text(value, textAlign: TextAlign.end, style: valueStyle),
        ),
      ],
    );
  }
}
