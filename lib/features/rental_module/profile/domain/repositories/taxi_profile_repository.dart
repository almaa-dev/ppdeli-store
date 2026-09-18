import 'package:shared_preferences/shared_preferences.dart';
import 'package:ppdelistore/api/api_client.dart';
import 'package:ppdelistore/features/rental_module/profile/domain/repositories/taxi_profile_repository_interface.dart';

class TaxiProfileRepository implements TaxiProfileRepositoryInterface {
  final ApiClient apiClient;
  final SharedPreferences sharedPreferences;
  TaxiProfileRepository({
    required this.apiClient,
    required this.sharedPreferences,
  });

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
