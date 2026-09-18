import 'package:ppdelistore/features/category/domain/models/category_model.dart';
import 'package:ppdelistore/features/store/domain/models/item_model.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/features/category/domain/services/category_service_interface.dart';

class CategoryController extends GetxController implements GetxService {
  final CategoryServiceInterface categoryServiceInterface;
  CategoryController({required this.categoryServiceInterface});

  List<CategoryModel>? _categoryList;
  List<CategoryModel>? get categoryList => _categoryList;

  List<CategoryModel>? _subCategoryList;
  List<CategoryModel>? get subCategoryList => _subCategoryList;

  String? _selectedCategoryID;
  String? get selectedCategoryID => _selectedCategoryID;

  String? _selectedSubCategoryID;
  String? get selectedSubCategoryID => _selectedSubCategoryID;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int? _pageSize;
  int? get pageSize => _pageSize;

  List<String> _offsetList = [];

  int _offset = 1;
  int get offset => _offset;

  List<Item>? _itemList;
  List<Item>? get itemList => _itemList;

  int? _selectedSubCategoryId;
  int? get selectedSubCategoryId => _selectedSubCategoryId;

  int? _isSubCategory = 0;
  int? get isSubCategory => _isSubCategory;

  int? _selectedSubCategoryIndex = 0;
  int? get selectedSubCategoryIndex => _selectedSubCategoryIndex;

  Future<void> getCategoryList() async {
    _categoryList = null;
    List<CategoryModel>? categoryList = await categoryServiceInterface
        .getCategoryList();
    if (categoryList != null) {
      _categoryList = [];
      _categoryList = categoryList;
    }
    update();
  }

  Future<void> getSubCategoryList(int categoryID) async {
    List<CategoryModel>? subCategoryList = await categoryServiceInterface
        .getSubCategoryList(categoryID);
    if (subCategoryList != null) {
      _subCategoryList = [];
      _subCategoryList = subCategoryList;
    }
    update();
  }

  Future<void> initCategoryData(Item? item) async {
    await getCategoryList();
    _selectedCategoryID = null;
    _selectedSubCategoryID = null;
    _subCategoryList = [];
    if (item != null && item.categoryIds?.isNotEmpty == true) {
      final mainId = item.categoryIds![0].id;
      if (mainId != null) {
        setSelectedCategory(mainId, isUpdate: false);

        if (item.categoryIds!.length > 1) {
          final subId = item.categoryIds![1].id;
          if (subId != null) {
            await getSubCategoryList(int.parse(mainId));
            setSelectedSubCategory(subId, isUpdate: false);
          }
        }
      }
    }
    update();
  }

  void setSelectedCategory(String id, {bool isUpdate = true}) {
    _selectedCategoryID = id;
    _selectedSubCategoryID = null;
    _subCategoryList = [];
    getSubCategoryList(int.parse(id));
    if (isUpdate) update();
  }

  void setSelectedSubCategory(String id, {bool isUpdate = true}) {
    _selectedSubCategoryID = id;
    if (isUpdate) update();
  }

  void setSelectedSubCategoryIndex(int? index, bool notify) {
    _selectedSubCategoryIndex = index;
    if (notify) {
      update();
    }
  }

  void setSelectedSubCategoryId(int? subCategoryId) {
    _selectedSubCategoryId = subCategoryId;
    _isSubCategory = 1;
    if (_selectedSubCategoryId != null) {
      getCategoryItemList(offset: '1', id: _selectedSubCategoryId!);
    }
    update();
  }

  void clearSelectedSubCategoryId() {
    _selectedSubCategoryId = null;
    _isSubCategory = 0;
  }

  Future<void> getCategoryItemList({
    required String offset,
    required int id,
    bool willUpdate = true,
  }) async {
    if (offset == '1') {
      _offsetList = [];
      _offset = 1;
      _itemList = null;
      if (willUpdate) {
        update();
      }
    }
    if (!_offsetList.contains(offset)) {
      _offsetList.add(offset);
      ItemModel? itemModel = await categoryServiceInterface.getCategoryItemList(
        offset: offset,
        id: id,
        isSubCategory: _isSubCategory!,
      );
      if (itemModel != null) {
        if (offset == '1') {
          _itemList = [];
        }
        _itemList!.addAll(itemModel.items!);
        _pageSize = itemModel.totalSize;
        _isLoading = false;
        update();
      }
    } else {
      if (isLoading) {
        _isLoading = false;
        update();
      }
    }
  }

  void showBottomLoader() {
    _isLoading = true;
    update();
  }

  void setOffset(int offset) {
    _offset = offset;
  }

  Future<void> setCategoryAndSubCategoryForAiData({
    String? categoryId,
    String? subCategoryId,
  }) async {
    if (categoryId != null) {
      _selectedCategoryID = categoryId;
      await getSubCategoryList(int.parse(categoryId)).then((value) {
        if (_subCategoryList != null && _subCategoryList!.isNotEmpty) {
          if (subCategoryId != null &&
              _subCategoryList!.any(
                (element) => element.id == int.parse(subCategoryId),
              )) {
            _selectedSubCategoryID = subCategoryId;
          }
          update();
        }
      });
    }
    update();
  }
}
