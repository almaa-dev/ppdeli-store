import 'package:ppdelistore/api/api_client.dart';
import 'package:ppdelistore/features/rental_module/provider/domain/repositories/provider_repository_interface.dart';

class ProviderRepository implements ProviderRepositoryInterface {
  final ApiClient apiClient;
  ProviderRepository({required this.apiClient});

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
