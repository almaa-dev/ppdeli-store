import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/features/reports/domain/enum/filter_type.dart';
import 'package:ppdelistore/features/reports/domain/models/earning_report_model.dart';
import 'package:ppdelistore/features/reports/domain/models/expense_model.dart';
import 'package:ppdelistore/features/reports/domain/models/tax_report_model.dart';
import 'package:ppdelistore/features/reports/domain/services/report_service_interface.dart';
import 'package:ppdelistore/helper/date_converter_helper.dart';

class ReportController extends GetxController implements GetxService {
  final ReportServiceInterface reportServiceInterface;
  ReportController({required this.reportServiceInterface});

  int? _pageSize;
  int? get pageSize => _pageSize;

  List<String> _offsetList = [];

  bool _setCustom = false;
  bool get setCustom => _setCustom;

  int _offset = 1;
  int get offset => _offset;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Expense>? _expenses;
  List<Expense>? get expenses => _expenses;

  String _type = 'earning';
  String get type => _type;

  EarningReportModel? _earningReportModel;
  EarningReportModel? get getEarningReportModel => _earningReportModel;

  String filterType = FilterType.all.name;

  void setEarningReportModelTransactions({TransactionContainer? value}) {
    _earningReportModel?.transactions = value;
    update();
  }

  void setType(String type) {
    _type = type;
  }

  late DateTimeRange _selectedDateRange;

  String? _from;
  String? get from => _from;

  String? _to;
  String? get to => _to;

  String? _searchText;
  String? get searchText => _searchText;

  bool _searchMode = false;
  bool get searchMode => _searchMode;

  TaxReportModel? _taxReportModel;
  TaxReportModel? get taxReportModel => _taxReportModel;

  List<Orders>? _orders;
  List<Orders>? get orders => _orders;

  void initSetDate() {
    _from = DateConverterHelper.dateTimeForCoupon(
      DateTime.now().subtract(const Duration(days: 2000)),
    );
    _to = DateConverterHelper.dateTimeForCoupon(DateTime.now());
    _searchText = '';
    _setCustom = false;
    filterType = FilterType.all.name;
  }

  void initTaxReportDate() {
    _from = DateConverterHelper.dateTimeForTax(
      DateTime.now().subtract(const Duration(days: 2000)),
    );
    _to = DateConverterHelper.dateTimeForTax(DateTime.now());
    _setCustom = false;
  }

  void setSearchText({
    required String offset,
    required String? from,
    required String? to,
    required String searchText,
  }) {
    _searchText = searchText;
    _searchMode = !_searchMode;
    getExpenseList(
      offset: offset.toString(),
      from: from,
      to: to,
      searchText: searchText,
    );
  }

  Future<void> getExpenseList({
    required String offset,
    required String? from,
    required String? to,
    required String? searchText,
  }) async {
    if (offset == '1') {
      _offsetList = [];
      _offset = 1;
      _expenses = null;
      update();
    }
    if (!_offsetList.contains(offset)) {
      _offsetList.add(offset);

      ExpenseBodyModel? expenseModel = await reportServiceInterface
          .getExpenseList(
            offset: int.parse(offset),
            from: from,
            to: to,
            restaurantId:
                Get.find<ProfileController>().profileModel!.stores![0].id,
            searchText: searchText,
          );
      if (expenseModel != null) {
        if (offset == '1') {
          _expenses = [];
        }
        _expenses!.addAll(expenseModel.expense!);
        _pageSize = expenseModel.totalSize;
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

  Future<void> getEarningReport({
    required String offset,
    required String? from,
    required String? to,
    required String type,
    bool onlyTransaction = false,
  }) async {
    if (offset == '1') {
      _offsetList = [];
      _offset = 1;
      _pageSize = null;
      if (!onlyTransaction) {
        _earningReportModel = null;
      } else {
        _earningReportModel?.transactions = null;
      }
      update();
    }

    if (!_offsetList.contains(offset)) {
      _offsetList.add(offset);

      final int storeId = Get.find<ProfileController>().profileModel!.id!;

      EarningReportModel? earningReportModel = await reportServiceInterface
          .getEarningReport(
            offset: int.parse(offset),
            restaurantId: storeId,
            from: from,
            to: to,
            type: type,
          );
      if (earningReportModel != null) {
        if (getEarningReportModel != null) {
          _earningReportModel!.transactions ??= TransactionContainer(data: []);
          _earningReportModel!.transactions!.data.addAll(
            earningReportModel.transactions?.data ?? [],
          );
          _isLoading = false;
          _pageSize = earningReportModel.totalSize;
        } else {
          _earningReportModel = earningReportModel;
          _isLoading = false;
          _pageSize = earningReportModel.totalSize;
        }
        update();
      } else {
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

  List<Map<String, Object>> getEarningData() {
    return [
      {
        'label': "order_sales",
        'value': getEarningReportModel?.summary?.breakdown?.orderSales ?? 0.0,
      },
      {
        'label': "tax_collected",
        'value': getEarningReportModel?.summary?.breakdown?.taxCollected ?? 0.0,
      },
      {
        'label': "packaging_charge",
        'value':
            getEarningReportModel?.summary?.breakdown?.packagingFeeCollected ??
            0.0,
      },
    ];
  }

  List<Map<String, Object>> getExpenseData() {
    return [
      {
        'label': "commission_paid",
        'value':
            getEarningReportModel?.summary?.breakdown?.adminCommission ?? 0.0,
      },
      {
        'label': "subscription_fee",
        'value':
            getEarningReportModel?.summary?.breakdown?.subscriptionFee ?? 0.0,
      },
      {
        'label': "discount_on_item",
        'value':
            getEarningReportModel?.summary?.breakdown?.discountOnItem ?? 0.0,
      },
      {
        'label': "coupon_contribution",
        'value':
            getEarningReportModel?.summary?.breakdown?.couponContribution ??
            0.0,
      },
      {
        'label': "free_delivery",
        'value': getEarningReportModel?.summary?.breakdown?.freeDelivery ?? 0.0,
      },
    ];
  }

  void setOffset(int offset) {
    _offset = offset;
  }

  void showBottomLoader() {
    _isLoading = true;
    update();
  }

  void showDatePicker(
    BuildContext context, {
    bool? isTaxReport,
    bool? isEarningReport,
  }) async {
    final DateTimeRange? result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      currentDate: DateTime.now(),
      saveText: 'done'.tr,
      confirmText: 'done'.tr,
      cancelText: 'cancel'.tr,
      fieldStartLabelText: 'start_date'.tr,
      fieldEndLabelText: 'end_date'.tr,
      errorInvalidRangeText: 'select_range'.tr,
    );

    if (result != null) {
      _selectedDateRange = result;
      _setCustom = true;
      filterType = FilterType.custom.name;

      if (isTaxReport ?? false) {
        _from = DateConverterHelper.dateTimeForTax(_selectedDateRange.start);
        _to = DateConverterHelper.dateTimeForTax(_selectedDateRange.end);
      } else if (isEarningReport ?? false) {
        _from = DateConverterHelper.dateTimeForCoupon(_selectedDateRange.start);
        _to = DateConverterHelper.dateTimeForCoupon(_selectedDateRange.end);
      } else {
        _from = DateConverterHelper.dateTimeForCoupon(_selectedDateRange.start);
        _to = DateConverterHelper.dateTimeForCoupon(_selectedDateRange.end);
      }

      update();

      if (isTaxReport ?? false) {
        getTaxReport(offset: '1', from: _from, to: _to);
      } else if (isEarningReport ?? false) {
        getEarningReport(offset: '1', from: _from, to: _to, type: type);
      } else {
        getExpenseList(
          offset: '1',
          from: _from,
          to: _to,
          searchText: searchText,
        );
      }
    }
  }

  Future<void> getTaxReport({
    required String offset,
    required String? from,
    required String? to,
  }) async {
    if (offset == '1') {
      _offsetList = [];
      _offset = 1;
      _orders = null;
      update();
    }
    if (!_offsetList.contains(offset)) {
      _offsetList.add(offset);

      TaxReportModel? taxReportModel = await reportServiceInterface
          .getTaxReport(offset: int.parse(offset), from: from, to: to);
      if (taxReportModel != null) {
        if (offset == '1') {
          _orders = [];
        }
        _taxReportModel = taxReportModel;
        _orders!.addAll(taxReportModel.orders!);
        _pageSize = taxReportModel.totalSize;
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

  void setFilter(
    String filterText, {
    bool transaction = false,
    bool order = false,
    bool campaign = false,
    bool isTaxReport = false,
    bool isEarningReport = false,
  }) {
    filterType = filterText;
    update();

    if (filterText == FilterType.all.name) {
      _from = DateConverterHelper.dateTimeForCoupon(
        DateTime.now().subtract(const Duration(days: 2000)),
      );
      _to = DateConverterHelper.dateTimeForCoupon(DateTime.now());
      _setCustom = false;
    } else if (filterText == FilterType.thisYear.name) {
      _from = DateConverterHelper.dateTimeForCoupon(
        DateTime.now().subtract(const Duration(days: 365)),
      );
      _to = DateConverterHelper.dateTimeForCoupon(DateTime.now());
      _setCustom = false;
    } else if (filterText == FilterType.previousYear.name) {
      DateTime now = DateTime.now();
      _from = DateConverterHelper.dateTimeForCoupon(
        DateTime(now.year - 1, 1, 1),
      );
      _to = DateConverterHelper.dateTimeForCoupon(
        DateTime(now.year - 1, 12, 31),
      );
      _setCustom = false;
    } else if (filterText == FilterType.thisMonth.name) {
      DateTime now = DateTime.now();
      _from = DateConverterHelper.dateTimeForCoupon(
        DateTime(now.year, now.month, 1),
      );
      _to = DateConverterHelper.dateTimeForCoupon(DateTime.now());
      _setCustom = false;
    } else if (filterText == FilterType.thisWeek.name) {
      DateTime now = DateTime.now();
      int currentWeekday = now.weekday;
      _from = DateConverterHelper.dateTimeForCoupon(
        now.subtract(Duration(days: currentWeekday - 1)),
      );
      _to = DateConverterHelper.dateTimeForCoupon(DateTime.now());
      _setCustom = false;
    }

    if (isTaxReport) {
      getTaxReport(offset: '1', from: _from, to: _to);
    } else if (transaction) {
      // getTransactionReportList(offset: '1', from: _from, to: _to);
    } else if (order) {
      // getOrderReportList(offset: '1', from: _from, to: _to);
    } else if (campaign) {
      // getCampaignReportList(offset: '1', from: _from, to: _to);
    } else if (isEarningReport) {
      getEarningReport(offset: '1', from: _from, to: _to, type: type);
    } else {
      // getFoodReportList(offset: '1', from: _from, to: _to);
    }
  }
}
