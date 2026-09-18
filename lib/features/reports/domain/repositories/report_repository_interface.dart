import 'package:ppdelistore/features/reports/domain/models/earning_report_model.dart';
import 'package:ppdelistore/features/reports/domain/models/tax_report_model.dart';
import 'package:ppdelistore/interface/repository_interface.dart';

abstract class ReportRepositoryInterface implements RepositoryInterface {
  Future<dynamic> getExpenseList({
    required int offset,
    required int? restaurantId,
    required String? from,
    required String? to,
    required String? searchText,
  });
  Future<TaxReportModel?> getTaxReport({
    required int offset,
    required String? from,
    required String? to,
  });
  Future<EarningReportModel?> getEarningReport({
    required int offset,
    required int restaurantId,
    required String? from,
    required String? to,
    required String type,
  });
}
