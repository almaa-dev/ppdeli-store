import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/features/ai/domain/models/attribute_data_model.dart';
import 'package:ppdelistore/features/ai/domain/services/ai_service_interface.dart';
import 'package:ppdelistore/features/ai/domain/models/other_data_model.dart';
import 'package:ppdelistore/features/ai/domain/models/title_des_model.dart';
import 'package:ppdelistore/features/ai/domain/models/title_suggestion_model.dart';
import 'package:ppdelistore/features/ai/domain/models/variation_data_model.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';

class AiController extends GetxController implements GetxService {
  final AiServiceInterface aiServiceInterface;
  AiController({required this.aiServiceInterface});

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _titleLoading = false;
  bool get titleLoading => _titleLoading;

  bool _otherDataLoading = false;
  bool get otherDataLoading => _otherDataLoading;

  bool _variationDataLoading = false;
  bool get variationDataLoading => _variationDataLoading;

  bool _imageLoading = false;
  bool get imageLoading => _imageLoading;

  TitleDesModel? _titleDesModel;
  TitleDesModel? get titleDesModel => _titleDesModel;

  OtherDataModel? _otherDataModel;
  OtherDataModel? get otherDataModel => _otherDataModel;

  VariationDataModel? _variationDataModel;
  VariationDataModel? get variationDataModel => _variationDataModel;

  AttributeDataModel? _attributeDataModel;
  AttributeDataModel? get attributeDataModel => _attributeDataModel;

  TitleSuggestionModel? _titleSuggestionModel;
  TitleSuggestionModel? get titleSuggestionModel => _titleSuggestionModel;

  List<String?> _keyWordList = [];
  List<String?> get keyWordList => _keyWordList;

  String _requestType = '';
  String get requestType => _requestType;

  void setRequestType(String type, {bool willUpdate = true}) {
    _requestType = type;
    if (willUpdate) {
      update();
    }
  }

  void setKeyWord(String? name, {bool willUpdate = true}) {
    _keyWordList.add(name);
    if (willUpdate) {
      update();
    }
  }

  void initializeKeyWords() {
    _keyWordList = [];
  }

  void removeKeyWord(int index) {
    _keyWordList.removeAt(index);
    update();
  }

  Future<void> generateTitleAndDes({
    required String title,
    required String langCode,
  }) async {
    _titleLoading = true;
    update();

    TitleDesModel? titleDesModel = await aiServiceInterface.generateTitleAndDes(
      title: title,
      langCode: langCode,
      storeId: Get.find<ProfileController>().profileModel!.id.toString(),
      moduleType: Get.find<ProfileController>()
          .profileModel!
          .stores![0]
          .module!
          .moduleType!,
      generateFrom: _requestType,
    );
    if (titleDesModel != null) {
      _titleDesModel = titleDesModel;
    }

    _titleLoading = false;
    update();
  }

  Future<void> generateOtherData({
    required String title,
    required String description,
  }) async {
    _otherDataLoading = true;
    update();

    OtherDataModel? otherDataModel = await aiServiceInterface.generateOtherData(
      title: title,
      description: description,
      storeId: Get.find<ProfileController>().profileModel!.id.toString(),
      moduleType: Get.find<ProfileController>()
          .profileModel!
          .stores![0]
          .module!
          .moduleType!,
      generateFrom: _requestType,
      moduleId:
          Get.find<ProfileController>().profileModel!.stores![0].module!.id!,
    );
    if (otherDataModel != null) {
      _otherDataModel = otherDataModel;
    }

    _otherDataLoading = false;
    update();
  }

  Future<void> generateVariationData({
    required String title,
    required String description,
  }) async {
    _variationDataLoading = true;
    update();

    VariationDataModel? variationDataModel = await aiServiceInterface
        .generateVariationData(
          title: title,
          description: description,
          storeId: Get.find<ProfileController>().profileModel!.id.toString(),
          moduleType: Get.find<ProfileController>()
              .profileModel!
              .stores![0]
              .module!
              .moduleType!,
          generateFrom: _requestType,
        );
    if (variationDataModel != null) {
      _variationDataModel = variationDataModel;
    }

    _variationDataLoading = false;
    update();
  }

  Future<void> generateAttributeData({
    required String title,
    required String description,
  }) async {
    _variationDataLoading = true;
    update();

    AttributeDataModel? attributeDataModel = await aiServiceInterface
        .generateAttributeData(
          title: title,
          description: description,
          storeId: Get.find<ProfileController>().profileModel!.id.toString(),
          moduleType: Get.find<ProfileController>()
              .profileModel!
              .stores![0]
              .module!
              .moduleType!,
          generateFrom: _requestType,
        );

    if (attributeDataModel != null) {
      _attributeDataModel = attributeDataModel;
    }

    _variationDataLoading = false;
    update();
  }

  Future<void> generateTitleSuggestions() async {
    _isLoading = true;
    update();

    String keyWord = '';
    for (var element in _keyWordList) {
      keyWord =
          keyWord + (keyWord.isEmpty ? '' : ',') + element!.replaceAll(' ', '');
    }

    TitleSuggestionModel? titleSuggestionModel = await aiServiceInterface
        .generateTitleSuggestions(
          keywords: keyWord,
          storeId: Get.find<ProfileController>().profileModel!.id.toString(),
          moduleType: Get.find<ProfileController>()
              .profileModel!
              .stores![0]
              .module!
              .moduleType!,
        );
    if (titleSuggestionModel != null) {
      _titleSuggestionModel = titleSuggestionModel;
    }

    _isLoading = false;
    update();
  }

  Future<Response> generateFromImage({required XFile image}) async {
    _imageLoading = true;
    update();

    XFile compressedImage = await compressImageFile(
      imageFile: File(image.path),
      quality: 10,
      format: CompressFormat.jpeg,
    );

    Response response = await aiServiceInterface.generateFromImage(
      image: compressedImage,
    );

    _imageLoading = false;
    update();
    return response;
  }

  Future<XFile> compressImageFile({
    required File imageFile,
    int quality = 80,
    CompressFormat format = CompressFormat.jpeg,
  }) async {
    DateTime time = DateTime.now();
    final String targetPath = path.join(
      Directory.systemTemp.path,
      'imagetemp-${format.name}-$quality-${time.second}.${format.name}',
    );

    final XFile? compressedImageFile =
        await FlutterImageCompress.compressAndGetFile(
          imageFile.path,
          targetPath,
          quality: quality,
          format: format,
          minHeight: 800,
          minWidth: 800,
        );

    if (compressedImageFile == null) {
      throw ("Image compression failed! Please try again.");
    }
    debugPrint("Compressed image saved to: ${compressedImageFile.path}");
    return compressedImageFile;
  }
}
