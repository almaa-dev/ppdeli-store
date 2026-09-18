import 'package:get/get.dart';
import 'package:ppdelistore/api/api_client.dart';
import 'package:ppdelistore/features/reports/domain/models/earning_report_model.dart';
import 'package:ppdelistore/features/reports/domain/models/expense_model.dart';
import 'package:ppdelistore/features/reports/domain/models/tax_report_model.dart';
import 'package:ppdelistore/features/reports/domain/repositories/report_repository_interface.dart';
import 'package:ppdelistore/util/app_constants.dart';

class ReportRepository implements ReportRepositoryInterface {
  final ApiClient apiClient;
  ReportRepository({required this.apiClient});

  @override
  Future<ExpenseBodyModel?> getExpenseList({
    required int offset,
    required int? restaurantId,
    required String? from,
    required String? to,
    required String? searchText,
  }) async {
    ExpenseBodyModel? expenseModel;
    Response response = await apiClient.getData(
      '${AppConstants.expenseListUri}?limit=10&offset=$offset&restaurant_id=$restaurantId&from=$from&to=$to&search=${searchText ?? ''}',
    );
    if (response.statusCode == 200) {
      expenseModel = ExpenseBodyModel.fromJson(response.body);
    }
    return expenseModel;
  }

  @override
  Future<TaxReportModel?> getTaxReport({
    required int offset,
    required String? from,
    required String? to,
  }) async {
    TaxReportModel? taxReportModel;
    Response response = await apiClient.getData(
      '${AppConstants.getTaxReportUri}?limit=10&offset=$offset&from=$from&to=$to',
    );
    if (response.statusCode == 200) {
      taxReportModel = TaxReportModel.fromJson(response.body);
    }
    return taxReportModel;
  }

  @override
  Future<EarningReportModel?> getEarningReport({
    required int offset,
    required int restaurantId,
    required String? from,
    required String? to,
    required String type,
  }) async {
    EarningReportModel? earningReportModel;
    Response response = await apiClient.getData(
      '${AppConstants.earningReportUri}?restaurant_id=$restaurantId&offset=$offset&limit=10${(from != null && to != null && from.isNotEmpty && to.isNotEmpty) ? '&filter=custom&from=$from&to=$to' : ''}&type=$type',
    );
    if (response.statusCode == 200) {
      earningReportModel = EarningReportModel.fromJson(response.body);
    }
    return earningReportModel;
  }

  @override
  Future add(value) {
    throw UnimplementedError();
  }

  @override
  Future delete(int? id) {
    throw UnimplementedError();
  }

  @override
  Future get(int? id) {
    throw UnimplementedError();
  }

  @override
  Future getList() {
    throw UnimplementedError();
  }

  @override
  Future update(Map<String, dynamic> body) {
    throw UnimplementedError();
  }
}
