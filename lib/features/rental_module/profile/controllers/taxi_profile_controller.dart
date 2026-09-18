import 'package:get/get.dart';
import 'package:ppdelistore/features/rental_module/profile/domain/services/taxi_profile_service_interface.dart';

class TaxiProfileController extends GetxController implements GetxService {
  final TaxiProfileServiceInterface taxiProfileServiceInterface;
  TaxiProfileController({required this.taxiProfileServiceInterface});

  Future<void> getProfile() async {
    return;
  }
}
