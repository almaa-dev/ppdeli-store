import 'package:ppdelistore/features/category/domain/models/category_model.dart';
import 'package:ppdelistore/features/category/domain/repositories/category_repository_interface.dart';
import 'package:ppdelistore/features/category/domain/services/category_service_interface.dart';
import 'package:ppdelistore/features/store/domain/models/item_model.dart';

class CategoryService implements CategoryServiceInterface {
  final CategoryRepositoryInterface categoryRepositoryInterface;
  CategoryService({required this.categoryRepositoryInterface});

  @override
  Future<List<CategoryModel>?> getCategoryList() async {
    return await categoryRepositoryInterface.getList();
  }

  @override
  Future<List<CategoryModel>?> getSubCategoryList(int? parentID) async {
    return await categoryRepositoryInterface.getSubCategoryList(parentID);
  }

  @override
  Future<ItemModel?> getCategoryItemList({
    required String offset,
    required int id,
    required int isSubCategory,
  }) async {
    return await categoryRepositoryInterface.getCategoryItemList(
      offset: offset,
      id: id,
      isSubCategory: isSubCategory,
    );
  }
}
