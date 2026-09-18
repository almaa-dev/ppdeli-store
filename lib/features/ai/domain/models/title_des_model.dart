class TitleDesModel {
  String? title;
  String? description;

  TitleDesModel({this.title, this.description});

  TitleDesModel.fromJson(Map<String, dynamic> json) {
    title = json['title'];
    description = json['description'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['title'] = title;
    data['description'] = description;
    return data;
  }
}