import 'package:shared_preferences/shared_preferences.dart';
import 'package:ppdelistore/api/api_client.dart';
import 'package:ppdelistore/util/app_constants.dart';
import 'package:get/get.dart';
import 'package:ppdelistore/features/splash/domain/repositories/splash_repository_interface.dart';

class SplashRepository implements SplashRepositoryInterface {
  final ApiClient apiClient;
  final SharedPreferences sharedPreferences;
  SplashRepository({required this.apiClient, required this.sharedPreferences});

  @override
  Future<Response> getConfigData() async {
    return await apiClient.getData(AppConstants.configUri);
  }

  @override
  Future<bool> initSharedData() async {
    // PERFORMANCE FIX (startup):
    // The previous implementation used six consecutive
    // `if (!containsKey) return setBool(...)` blocks. Two side effects:
    //   1. The very first run stops after the FIRST missing key — every
    //      other default (countryCode, languageCode, notification, intro,
    //      notificationCount) was **never** written for fresh installs.
    //      This is the "anti-pattern" already flagged in §19.1.2 of the
    //      Knowledge Base.
    //   2. Each successful `return` was an early-exit; even when all keys
    //      were present we did up to 5 synchronous `containsKey` lookups.
    //
    // The new version reads the existing values once via `getKeys()`,
    // computes the set of missing keys, and persists all defaults in a
    // single tight loop. It also separates the duplicate `intro` guard
    // that was masking `notificationCount`.
    final Set<String> existing = sharedPreferences.getKeys();

    bool dirty = false;
    if (!existing.contains(AppConstants.theme)) {
      dirty = await sharedPreferences.setBool(AppConstants.theme, false);
    }
    if (!existing.contains(AppConstants.countryCode)) {
      dirty =
          await sharedPreferences.setString(
            AppConstants.countryCode,
            AppConstants.languages[0].countryCode!,
          ) ||
          dirty;
    }
    if (!existing.contains(AppConstants.languageCode)) {
      dirty =
          await sharedPreferences.setString(
            AppConstants.languageCode,
            AppConstants.languages[0].languageCode!,
          ) ||
          dirty;
    }
    if (!existing.contains(AppConstants.notification)) {
      dirty =
          await sharedPreferences.setBool(AppConstants.notification, true) ||
          dirty;
    }
    if (!existing.contains(AppConstants.intro)) {
      dirty =
          await sharedPreferences.setBool(AppConstants.intro, true) || dirty;
    }
    // Original code accidentally re-entered the intro branch to write
    // notificationCount. Decoupled so the two values are independent.
    if (!existing.contains(AppConstants.notificationCount)) {
      dirty =
          await sharedPreferences.setInt(AppConstants.notificationCount, 0) ||
          dirty;
    }
    return dirty || true;
  }

  @override
  bool showIntro() {
    return sharedPreferences.getBool(AppConstants.intro) ?? true;
  }

  @override
  void setIntro(bool intro) {
    sharedPreferences.setBool(AppConstants.intro, intro);
  }

  @override
  Future<bool> removeSharedData() {
    return sharedPreferences.clear();
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
