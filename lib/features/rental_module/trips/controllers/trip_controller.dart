import 'package:get/get.dart';
import 'package:ppdelistore/features/rental_module/trips/domain/services/trip_service_interface.dart';

class TripController extends GetxController implements GetxService {
  final TripServiceInterface tripServiceInterface;
  TripController({required this.tripServiceInterface});

  Future<void> getTripList({String? status, String? offset}) async {
    return;
  }
}
