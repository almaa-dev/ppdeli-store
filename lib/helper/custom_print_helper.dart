import 'package:flutter/foundation.dart';

void customPrint(Object? message) {
  if (kDebugMode) {
    print(message);
  }
}