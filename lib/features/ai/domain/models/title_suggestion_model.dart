class TitleSuggestionModel {
  Data? data;

  TitleSuggestionModel({this.data});

  TitleSuggestionModel.fromJson(Map<String, dynamic> json) {
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
  List<String>? titles;

  Data({this.titles});

  Data.fromJson(Map<String, dynamic> json) {
    titles = json['titles'].cast<String>();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['titles'] = titles;
    return data;
  }
}
