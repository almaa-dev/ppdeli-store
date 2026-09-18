import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ppdelistore/features/ai/domain/models/attribute_data_model.dart';
import 'package:ppdelistore/features/ai/domain/models/other_data_model.dart';
import 'package:ppdelistore/features/ai/domain/models/title_des_model.dart';
import 'package:ppdelistore/features/ai/domain/models/title_suggestion_model.dart';
import 'package:ppdelistore/features/ai/domain/models/variation_data_model.dart';
import 'package:ppdelistore/features/ai/domain/repositories/ai_repository_interface.dart';
import 'package:ppdelistore/features/ai/domain/services/ai_service_interface.dart';

class AiService implements AiServiceInterface {
  final AiRepositoryInterface aiRepositoryInterface;
  AiService({required this.aiRepositoryInterface});

  @override
  Future<TitleDesModel?> generateTitleAndDes({
    required String title,
    required String langCode,
    required String storeId,
    required String moduleType,
    required String generateFrom,
  }) async {
    return await aiRepositoryInterface.generateTitleAndDes(
      title: title,
      langCode: langCode,
      storeId: storeId,
      moduleType: moduleType,
      generateFrom: generateFrom,
    );
  }

  @override
  Future<OtherDataModel?> generateOtherData({
    required String title,
    required String description,
    required String storeId,
    required String moduleType,
    required String generateFrom,
    required int moduleId,
  }) async {
    return await aiRepositoryInterface.generateOtherData(
      title: title,
      description: description,
      storeId: storeId,
      moduleType: moduleType,
      generateFrom: generateFrom,
      moduleId: moduleId,
    );
  }

  @override
  Future<VariationDataModel?> generateVariationData({
    required String title,
    required String description,
    required String storeId,
    required String moduleType,
    required String generateFrom,
  }) async {
    return await aiRepositoryInterface.generateVariationData(
      title: title,
      description: description,
      storeId: storeId,
      moduleType: moduleType,
      generateFrom: generateFrom,
    );
  }

  @override
  Future<AttributeDataModel?> generateAttributeData({
    required String title,
    required String description,
    required String storeId,
    required String moduleType,
    required String generateFrom,
  }) async {
    return await aiRepositoryInterface.generateAttributeData(
      title: title,
      description: description,
      storeId: storeId,
      moduleType: moduleType,
      generateFrom: generateFrom,
    );
  }

  @override
  Future<TitleSuggestionModel?> generateTitleSuggestions({
    required String keywords,
    required String storeId,
    required String moduleType,
  }) async {
    return await aiRepositoryInterface.generateTitleSuggestions(
      keywords: keywords,
      storeId: storeId,
      moduleType: moduleType,
    );
  }

  @override
  Future<Response> generateFromImage({required XFile image}) async {
    return await aiRepositoryInterface.generateFromImage(image: image);
  }
}
