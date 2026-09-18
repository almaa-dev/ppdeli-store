class AttributeDataModel {
  Data? data;
  String? status;

  AttributeDataModel({this.data, this.status});

  AttributeDataModel.fromJson(Map<String, dynamic> json) {
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
    status = json['status'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    data['status'] = status;
    return data;
  }
}

class Data {
  List<ChoiceAttributes>? choiceAttributes;

  Data({this.choiceAttributes});

  Data.fromJson(Map<String, dynamic> json) {
    if (json['choice_attributes'] != null) {
      choiceAttributes = <ChoiceAttributes>[];
      json['choice_attributes'].forEach((v) {
        choiceAttributes!.add(ChoiceAttributes.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (choiceAttributes != null) {
      data['choice_attributes'] = choiceAttributes!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class ChoiceAttributes {
  int? id;
  String? name;
  List<String>? options;

  ChoiceAttributes({this.id, this.name, this.options});

  ChoiceAttributes.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    options = json['options'].cast<String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['options'] = options;
    return data;
  }
}
