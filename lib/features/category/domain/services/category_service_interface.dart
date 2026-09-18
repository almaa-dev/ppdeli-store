import 'package:ppdelistore/features/category/domain/models/category_model.dart';
import 'package:ppdelistore/features/store/domain/models/item_model.dart';

abstract class CategoryServiceInterface {
  Future<List<CategoryModel>?> getCategoryList();
  Future<List<CategoryModel>?> getSubCategoryList(int? parentID);
  Future<ItemModel?> getCategoryItemList({
    required String offset,
    required int id,
    required int isSubCategory,
  });
}
