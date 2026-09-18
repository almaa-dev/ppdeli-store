import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ppdelistore/features/ai/domain/models/attribute_data_model.dart';
import 'package:ppdelistore/features/ai/domain/models/other_data_model.dart';
import 'package:ppdelistore/features/ai/domain/models/title_des_model.dart';
import 'package:ppdelistore/features/ai/domain/models/title_suggestion_model.dart';
import 'package:ppdelistore/features/ai/domain/models/variation_data_model.dart';
import 'package:ppdelistore/interface/repository_interface.dart';

abstract class AiRepositoryInterface implements RepositoryInterface {
  Future<TitleDesModel?> generateTitleAndDes({
    required String title,
    required String langCode,
    required String storeId,
    required String moduleType,
    required String generateFrom,
  });
  Future<OtherDataModel?> generateOtherData({
    required String title,
    required String description,
    required String storeId,
    required String moduleType,
    required String generateFrom,
    required int moduleId,
  });
  Future<VariationDataModel?> generateVariationData({
    required String title,
    required String description,
    required String storeId,
    required String moduleType,
    required String generateFrom,
  });
  Future<AttributeDataModel?> generateAttributeData({
    required String title,
    required String description,
    required String storeId,
    required String moduleType,
    required String generateFrom,
  });
  Future<TitleSuggestionModel?> generateTitleSuggestions({
    required String keywords,
    required String storeId,
    required String moduleType,
  });
  Future<Response> generateFromImage({required XFile image});
}
