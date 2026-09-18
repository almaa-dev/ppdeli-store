import 'package:image_picker/image_picker.dart';

class Functions {
  static Future<String?> fileSize(XFile? file)async{
    if(file == null){
      return '-';
    }
    int sizeInBytes = await file.length();

    return getSizeWithUnit(sizeInBytes);
  }

  static String getSizeWithUnit(int sizeInBytes){
    double sizeInKB = sizeInBytes / 1024;
    double sizeInMB = sizeInKB / 1024;
    return sizeInMB >= 1.0 ? "${sizeInMB.toStringAsFixed(2)} MB" : "${sizeInKB.toStringAsFixed(2)} KB";
  }
}