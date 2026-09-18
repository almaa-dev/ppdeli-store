import 'package:get/get.dart';
import 'package:ppdelistore/api/api_client.dart';
import 'package:ppdelistore/features/reels/domain/models/reel_model.dart';
import 'package:ppdelistore/features/reels/domain/repositories/reel_repository_interface.dart';
import 'package:ppdelistore/features/reels/domain/services/reel_service_interface.dart';

class ReelService implements ReelServiceInterface {
  final ReelRepositoryInterface reelRepositoryInterface;
  ReelService({required this.reelRepositoryInterface});

  @override
  Future<ReelsModel?> getReelsList(
    String offset,
    String status,
    String sortBy, {
    String? search,
  }) async {
    return await reelRepositoryInterface.getReelsList(
      offset,
      status,
      sortBy,
      search: search,
    );
  }

  @override
  Future<Response> storeReel(
    Map<String, String> body,
    List<MultipartBody> files,
  ) async {
    return await reelRepositoryInterface.storeReel(body, files);
  }

  @override
  Future<Response> updateReel(
    Map<String, String> body,
    List<MultipartBody> files,
  ) async {
    return await reelRepositoryInterface.updateReel(body, files);
  }

  @override
  Future<Response> deleteReel(int reelId) async {
    return await reelRepositoryInterface.deleteReel(reelId);
  }

  @override
  Future<Response> changeReelStatus(int reelId, int status) async {
    return await reelRepositoryInterface.changeReelStatus(reelId, status);
  }
}
