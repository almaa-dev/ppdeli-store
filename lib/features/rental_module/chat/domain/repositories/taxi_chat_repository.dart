import 'package:shared_preferences/shared_preferences.dart';
import 'package:ppdelistore/api/api_client.dart';
import 'package:ppdelistore/features/rental_module/chat/domain/repositories/taxi_chat_repository_interface.dart';

class TaxiChatRepository implements TaxiChatRepositoryInterface {
  final ApiClient apiClient;
  final SharedPreferences sharedPreferences;
  TaxiChatRepository({
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
