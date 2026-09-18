class OtherDataModel {
  GeneralData? generalData;
  PriceData? priceData;

  OtherDataModel({this.generalData, this.priceData});

  OtherDataModel.fromJson(Map<String, dynamic> json) {
    generalData = json['generalData'] != null ? GeneralData.fromJson(json['generalData']) : null;
    priceData = json['priceData'] != null ? PriceData.fromJson(json['priceData']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (generalData != null) {
      data['generalData'] = generalData!.toJson();
    }
    if (priceData != null) {
      data['priceData'] = priceData!.toJson();
    }
    return data;
  }
}

class GeneralData {
  Data? data;

  GeneralData({this.data});

  GeneralData.fromJson(Map<String, dynamic> json) {
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class Data {
  String? categoryName;
  String? subCategoryName;
  List<String>? nutrition;
  List<String>? allergy;
  String? productType;
  List<String>? searchTags;
  bool? isHalal;
  bool? isOrganic;
  String? units;
  String? availableTimeStarts;
  String? availableTimeEnds;
  int? categoryId;
  int? subCategoryId;
  int? unitId;
  List<String>? addonsNames;
  List<int>? addonsIds;

  Data({
    this.categoryName,
    this.subCategoryName,
    this.nutrition,
    this.allergy,
    this.productType,
    this.searchTags,
    this.isHalal,
    this.isOrganic,
    this.units,
    this.availableTimeStarts,
    this.availableTimeEnds,
    this.categoryId,
    this.subCategoryId,
    this.unitId,
    this.addonsNames,
    this.addonsIds,
  });

  Data.fromJson(Map<String, dynamic> json) {
    categoryName = json['category_name'];
    subCategoryName = json['sub_category_name'];
    nutrition = json['nutrition'].cast<String>();
    allergy = json['allergy']?.cast<String>();
    productType = json['product_type'];
    searchTags = json['search_tags'].cast<String>();
    isHalal = json['is_halal'];
    isOrganic = json['is_organic'];
    units = json['units'];
    availableTimeStarts = json['available_time_starts'];
    availableTimeEnds = json['available_time_ends'];
    categoryId = json['category_id'];
    subCategoryId = json['sub_category_id'];
    unitId = json['unit_id'];
    addonsNames = json['addonsNames'].cast<String>();
    addonsIds = json['addonsIds'].cast<int>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['category_name'] = categoryName;
    data['sub_category_name'] = subCategoryName;
    data['nutrition'] = nutrition;
    data['allergy'] = allergy;
    data['product_type'] = productType;
    data['search_tags'] = searchTags;
    data['is_halal'] = isHalal;
    data['is_organic'] = isOrganic;
    data['units'] = units;
    data['available_time_starts'] = availableTimeStarts;
    data['available_time_ends'] = availableTimeEnds;
    data['category_id'] = categoryId;
    data['sub_category_id'] = subCategoryId;
    data['unit_id'] = unitId;
    data['addonsNames'] = addonsNames;
    data['addonsIds'] = addonsIds;
    return data;
  }
}

class PriceData {
  double? unitPrice;
  int? minimumOrderQuantity;
  double? discountAmount;
  String? discountType;
  int? totalStock;
  int? maxOrderQuantity;

  PriceData({
    this.unitPrice,
    this.minimumOrderQuantity,
    this.discountAmount,
    this.discountType,
    this.totalStock,
    this.maxOrderQuantity,
  });

  PriceData.fromJson(Map<String, dynamic> json) {
    unitPrice = _toDouble(json['unit_price']);
    minimumOrderQuantity = _toInt(json['minimum_order_quantity']);
    discountAmount = _toDouble(json['discount_amount']);
    discountType = json['discount_type']?.toString();
    totalStock = _toInt(json['total_stock'] ?? json['current_stock'] ?? json['stock']);
    maxOrderQuantity = _toInt(json['max_order_quantity']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['unit_price'] = unitPrice;
    data['minimum_order_quantity'] = minimumOrderQuantity;
    data['discount_amount'] = discountAmount;
    data['discount_type'] = discountType;
    data['total_stock'] = totalStock;
    data['max_order_quantity'] = maxOrderQuantity;
    return data;
  }
}

int? _toInt(dynamic value) {
  if (value == null) {
    return null;
  } else if (value is int) {
    return value;
  } else if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value.toString());
}

double? _toDouble(dynamic value) {
  if (value == null) {
    return null;
  } else if (value is double) {
    return value;
  } else if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString());
}
