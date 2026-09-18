class VariationDataModel {
  List<Data>? data;
  String? status;

  VariationDataModel({this.data, this.status});

  VariationDataModel.fromJson(Map<String, dynamic> json) {
    if (json['data'] != null) {
      data = <Data>[];
      json['data'].forEach((v) {
        data!.add(Data.fromJson(v));
      });
    }
    status = json['status'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (this.data != null) {
      data['data'] = this.data!.map((v) => v.toJson()).toList();
    }
    data['status'] = status;
    return data;
  }
}

class Data {
  String? variationName;
  bool? required;
  String? selectionType;
  int? min;
  int? max;
  List<Options>? options;

  Data({
    this.variationName,
    this.required,
    this.selectionType,
    this.min,
    this.max,
    this.options,
  });

  Data.fromJson(Map<String, dynamic> json) {
    variationName = json['variation_name'];
    required = json['required'];
    selectionType = json['selection_type'];
    min = json['min'];
    max = json['max'];
    if (json['options'] != null) {
      options = <Options>[];
      json['options'].forEach((v) {
        options!.add(Options.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['variation_name'] = variationName;
    data['required'] = required;
    data['selection_type'] = selectionType;
    data['min'] = min;
    data['max'] = max;
    if (options != null) {
      data['options'] = options!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Options {
  String? optionName;
  double? optionPrice;

  Options({this.optionName, this.optionPrice});

  Options.fromJson(Map<String, dynamic> json) {
    optionName = json['option_name'];
    optionPrice = double.tryParse(json['option_price'].toString()) ?? 0.0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['option_name'] = optionName;
    data['option_price'] = optionPrice;
    return data;
  }
}
