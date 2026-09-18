import 'package:ppdelistore/features/store/domain/models/item_model.dart';
import 'package:ppdelistore/interface/repository_interface.dart';

abstract class CategoryRepositoryInterface implements RepositoryInterface {
  Future<dynamic> getSubCategoryList(int? parentID);
  Future<ItemModel?> getCategoryItemList({
    required String offset,
    required int id,
    required int isSubCategory,
  });
}
