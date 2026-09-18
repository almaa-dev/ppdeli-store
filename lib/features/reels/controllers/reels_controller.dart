import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ppdelistore/api/api_client.dart';
import 'package:ppdelistore/common/models/config_model.dart';
import 'package:ppdelistore/common/widgets/custom_snackbar_widget.dart';
import 'package:ppdelistore/features/reels/domain/models/reel_model.dart';
import 'package:ppdelistore/features/reels/domain/services/reel_service_interface.dart';
import 'package:ppdelistore/features/store/domain/models/item_model.dart';
import 'package:ppdelistore/helper/date_converter_helper.dart';

class ReelsController extends GetxController implements GetxService {
  final ReelServiceInterface reelServiceInterface;
  ReelsController({required this.reelServiceInterface});

  List<String> _offsetList = [];

  int _offset = 1;
  int get offset => _offset;

  String _type = 'all';
  String get type => _type;

  int? _pageSize;
  int? get pageSize => _pageSize;

  ReelsModel? reelsModel;

  List<Reel>? _reelsList;
  List<Reel>? get reelsList => _reelsList;

  List<Reel>? _searchedReelsList;
  List<Reel>? get searchedReelsList => _searchedReelsList;

  final List<String> _statusList = [
    'all',
    'live',
    'upcoming',
    'expired',
    'deactivated',
  ];
  List<String> get statusList => _statusList;

  int _statusIndex = 0;
  int get statusIndex => _statusIndex;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSearchActive = false;
  bool get isSearchActive => _isSearchActive;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  final List<String> _filterList = [
    'latest',
    'most_viewed',
    'most_liked',
    'oldest',
  ];
  List<String> get filterList => _filterList;

  int _filterIndex = 0;
  int get filterIndex => _filterIndex;

  String get _sortBy => _filterList[_filterIndex];

  void setFilterIndex(int index) {
    _filterIndex = index;
    _offset = 1;
    getReelsList('1', _type);
  }

  void setType(String type) {
    _type = type;
  }

  void setStatusIndex(int index, {bool willUpdate = true}) {
    _statusIndex = index;
    if (willUpdate) {
      update();
    }
  }

  void setOffset(int offset) {
    _offset = offset;
  }

  void showBottomLoader() {
    _isLoading = true;
    update();
  }

  Timer? _searchDebounce;

  void toggleSearch() {
    _isSearchActive = !_isSearchActive;
    if (!_isSearchActive) {
      _searchDebounce?.cancel();
      _searchQuery = '';
      _searchedReelsList = null;
      getReelsList('1', _type);
    }
    update();
  }

  void searchReels(String query) {
    _searchQuery = query;
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      _searchedReelsList = null;
      getReelsList('1', _type);
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchReelsFromApi(query);
    });
  }

  Future<void> _searchReelsFromApi(String query) async {
    _searchedReelsList = null;
    update();

    ReelsModel? result = await reelServiceInterface.getReelsList(
      '1',
      _type,
      _sortBy,
      search: query,
    );
    if (result != null) {
      _searchedReelsList = result.reels ?? [];
    }
    update();
  }

  Future<void> getReelsList(String offset, String type) async {
    if (offset == '1') {
      _offsetList = [];
      _offset = 1;
      _type = type;
      _reelsList = null;
      _searchedReelsList = null;
      update();
    }
    if (!_offsetList.contains(offset)) {
      _offsetList.add(offset);
      reelsModel = await reelServiceInterface.getReelsList(
        offset,
        _type,
        _sortBy,
      );
      if (reelsModel != null) {
        if (offset == '1') {
          _reelsList = [];
        }
        _reelsList!.addAll(reelsModel!.reels ?? []);
        _pageSize = reelsModel!.totalSize;
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

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  Future<void> submitReel({
    required List<TextEditingController> descriptionControllers,
    required List<Language> languageList,
    required bool isAlwaysVisible,
    int? reelId,
    XFile? thumbnail,
    XFile? video,
    DateTimeRange? dateRange,
  }) async {
    _isSubmitting = true;
    update();

    bool isUpdate = reelId != null;

    List<MultipartBody> files = [];
    if (thumbnail != null) {
      files.add(MultipartBody('thumbnail', thumbnail));
    }
    if (video != null) {
      files.add(MultipartBody('video', video));
    }

    List<Translation> translations = [];
    for (int i = 0; i < languageList.length; i++) {
      translations.add(
        Translation(
          locale: languageList[i].key,
          key: 'description',
          value: descriptionControllers[i].text.trim().isNotEmpty
              ? descriptionControllers[i].text.trim()
              : descriptionControllers[0].text.trim(),
        ),
      );
    }

    Map<String, String> body = {};
    body['description'] = descriptionControllers[0].text.trim();
    body['translations'] = jsonEncode(
      translations.map((t) => t.toJson()).toList(),
    );

    if (isAlwaysVisible) {
      body['is_always_visible'] = '1';
    } else if (dateRange != null) {
      // body['is_always_visible'] = '0';
      String startDate = DateConverterHelper.stringToMDY(
        dateRange.start.toString(),
      );
      String endDate = DateConverterHelper.stringToMDY(
        dateRange.end.toString(),
      );
      body['dates'] = '$startDate - $endDate';
    }

    if (isUpdate) {
      body['reel_id'] = reelId.toString();
      body['_method'] = 'PUT';
    }

    Response response = isUpdate
        ? await reelServiceInterface.updateReel(body, files)
        : await reelServiceInterface.storeReel(body, files);

    if (response.statusCode == 200) {
      getReelsList('1', _type);
      Get.back();
      showCustomSnackBar(
        response.body?['message'] ??
            (isUpdate
                    ? 'reel_updated_successfully'
                    : 'reel_created_successfully')
                .tr,
        isError: false,
      );
    } else {
      if (response.body != null && response.body['errors'] != null) {
        List errors = response.body['errors'];
        if (errors.isNotEmpty) {
          showCustomSnackBar(errors[0]['message']);
        }
      } else {
        showCustomSnackBar(response.statusText ?? 'something_went_wrong'.tr);
      }
    }

    _isSubmitting = false;
    update();
  }

  Future<void> changeReelStatus(int reelId, int status) async {
    Response response = await reelServiceInterface.changeReelStatus(
      reelId,
      status,
    );
    if (response.statusCode == 200) {
      showCustomSnackBar(
        response.body?['message'] ??
            (status == 1
                    ? 'reel_activated_successfully'
                    : 'reel_deactivated_successfully')
                .tr,
        isError: false,
      );
      getReelsList('1', _type);
    } else {
      showCustomSnackBar(response.statusText ?? 'something_went_wrong'.tr);
    }
  }

  Future<void> deleteReel(int reelId) async {
    Response response = await reelServiceInterface.deleteReel(reelId);
    if (response.statusCode == 200) {
      showCustomSnackBar(
        response.body?['message'] ?? 'reel_deleted_successfully'.tr,
        isError: false,
      );
      getReelsList('1', _type);
    } else {
      showCustomSnackBar(response.statusText ?? 'something_went_wrong'.tr);
    }
  }
}
