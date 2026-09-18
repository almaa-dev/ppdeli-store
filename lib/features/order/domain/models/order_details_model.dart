import 'package:ppdelistore/features/store/domain/models/item_model.dart';

class OrderDetailsModel {
  int? id;
  int? itemId;
  int? orderId;
  double? price;
  Item? itemDetails;
  List<Variation>? variation;
  List<FoodVariation>? foodVariation;
  List<AddOn>? addOns;
  double? discountOnItem;
  String? discountType;
  int? quantity;
  double? taxAmount;
  String? variant;
  String? createdAt;
  String? updatedAt;
  int? itemCampaignId;
  double? totalAddOnPrice;
  String? note;

  OrderDetailsModel({
    this.id,
    this.itemId,
    this.orderId,
    this.price,
    this.itemDetails,
    this.variation,
    this.foodVariation,
    this.addOns,
    this.discountOnItem,
    this.discountType,
    this.quantity,
    this.taxAmount,
    this.variant,
    this.createdAt,
    this.updatedAt,
    this.itemCampaignId,
    this.totalAddOnPrice,
    this.note,
  });

  OrderDetailsModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    itemId = json['item_id'];
    orderId = json['order_id'];
    price = json['price'] != null ? json['price']?.toDouble() : 0.0;
    itemDetails = json['item_details'] != null
        ? Item.fromJson(json['item_details'])
        : null;
    variation = [];
    foodVariation = [];
    if (json['variation'] != null &&
        json['variation'] is List &&
        (json['variation'] as List).isNotEmpty) {
      final List variationList = json['variation'] as List;
      final firstVariation = variationList[0];
      if (firstVariation != null && firstVariation['values'] != null) {
        for (var v in variationList) {
          if (v != null) foodVariation!.add(FoodVariation.fromJson(v));
        }
      } else {
        for (var v in variationList) {
          if (v != null) variation!.add(Variation.fromJson(v));
        }
      }
    }
    // if (json['variation'] != null && json['variation'].isNotEmpty) {
    //   if(json['variation'][0]['values'] != null) {
    //     json['variation'].forEach((v) {
    //       foodVariation!.add(FoodVariation.fromJson(v));
    //     });
    //   }else {
    //     json['variation'].forEach((v) {
    //       variation!.add(Variation.fromJson(v));
    //     });
    //   }
    // }
    if (json['add_ons'] != null) {
      addOns = [];
      json['add_ons'].forEach((v) {
        addOns!.add(AddOn.fromJson(v));
      });
    }
    discountOnItem = json['discount_on_item']?.toDouble();
    discountType = json['discount_type'];
    quantity = json['quantity'];
    taxAmount = json['tax_amount']?.toDouble();
    variant = json['variant'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    itemCampaignId = json['item_campaign_id'];
    totalAddOnPrice = json['total_add_on_price']?.toDouble();
    note = json['note'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['item_id'] = itemId;
    data['order_id'] = orderId;
    data['price'] = price;
    if (itemDetails != null) {
      data['item_details'] = itemDetails!.toJson();
    }
    if (variation != null) {
      data['variation'] = variation!.map((v) => v.toJson()).toList();
    } else if (foodVariation != null) {
      data['variation'] = foodVariation!.map((v) => v.toJson()).toList();
    }
    if (addOns != null) {
      data['add_ons'] = addOns!.map((v) => v.toJson()).toList();
    }
    data['discount_on_item'] = discountOnItem;
    data['discount_type'] = discountType;
    data['quantity'] = quantity;
    data['tax_amount'] = taxAmount;
    data['variant'] = variant;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    data['item_campaign_id'] = itemCampaignId;
    data['total_add_on_price'] = totalAddOnPrice;
    data['note'] = note;
    return data;
  }
}

class AddOn {
  String? name;
  double? price;
  int? quantity;

  AddOn({this.name, this.price, this.quantity});

  AddOn.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    price = json['price'] != null ? json['price']?.toDouble() : 0.0;
    quantity = int.parse(json['quantity'].toString());
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['price'] = price;
    data['quantity'] = quantity;
    return data;
  }
}
