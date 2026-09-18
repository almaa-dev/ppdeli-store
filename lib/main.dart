import 'dart:async';
import 'package:flutter/services.dart';
import 'package:ppdelistore/features/home/widgets/trial_widget.dart';
import 'package:ppdelistore/features/language/controllers/language_controller.dart';
import 'package:ppdelistore/features/printer/presentation/printer_controller.dart';
import 'package:ppdelistore/common/controllers/theme_controller.dart';
import 'package:ppdelistore/features/notification/domain/models/notification_body_model.dart';
import 'package:ppdelistore/features/profile/controllers/profile_controller.dart';
import 'package:ppdelistore/helper/date_converter_helper.dart';
import 'package:ppdelistore/helper/notification_helper.dart';
import 'package:ppdelistore/helper/route_helper.dart';
import 'package:ppdelistore/theme/dark_theme.dart';
import 'package:ppdelistore/theme/light_theme.dart';
import 'package:ppdelistore/util/app_constants.dart';
import 'package:ppdelistore/util/messages.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'helper/get_di.dart' as di;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();
  // PERFORMANCE FIX (startup):
  // Run DI registration / language asset loading in PARALLEL with the
  // Firebase init. Each used to run one-after-another ("await ... ; await
  // ... ;") and their durations summed up. Running them concurrently
  // shortens the time spent on the "white screen" before the splash UI
  // is even built.
  final Future<Map<String, Map<String, String>>> languagesFuture = di.init();

  final Future<void> firebaseFuture = GetPlatform.isAndroid
      ? Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyClR9gV_285DgJviVaWvZrgkc2_Bb2wNwQ",
            appId: "1:422412778152:android:83c2b403a662f58e24e09d",
            messagingSenderId: "422412778152",
            projectId: "ppdeli-f07a9",
          ),
        )
      : Firebase.initializeApp();

  final Map<String, Map<String, String>> languages = await Future.wait<dynamic>(
    [languagesFuture, firebaseFuture],
  ).then((_) async => await languagesFuture);

  // Register the FCM background handler as early as possible (it's just a
  // top-level reference assignment, so no I/O happens here).
  try {
    if (GetPlatform.isMobile) {
      FirebaseMessaging.onBackgroundMessage(myBackgroundMessageHandler);
    }
  } catch (_) {}

  NotificationBodyModel? body;
  // Do NOT await getInitialMessage() here. Querying FCM for a cold-start
  // notification can take 200-800 ms and was a major contributor to the
  // white screen. We schedule it for AFTER the first frame is painted.
  runApp(MyApp(languages: languages, body: body));

  // ─── Everything below runs AFTER the first frame is on screen ───
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // 1. Cold-start FCM payload (fire-and-forget).
    try {
      if (GetPlatform.isMobile) {
        unawaited(
          FirebaseMessaging.instance
              .getInitialMessage()
              .then((remoteMessage) {
                // The splash screen already routes via the `body` it received
                // when MyApp was constructed. A cold-start payload here is
                // uncommon; we keep it best-effort and non-blocking.
                if (remoteMessage != null) {
                  // Optional: store for later use. Intentionally not blocking.
                }
              })
              .catchError((_) {}),
        );
      }
    } catch (_) {}

    // 2. Local notifications plugin + FCM channels. Was previously awaited
    //    synchronously inside main(), which prompted the user for
    //    notification permission before paint.
    try {
      if (GetPlatform.isMobile) {
        await NotificationHelper.initialize(flutterLocalNotificationsPlugin);
      }
    } catch (_) {}

    // 3. Bluetooth / printer bootstrap. Was the BIGGEST source of the
    //    white screen — it requested BT runtime permissions, checked the
    //    adapter and tried to reconnect to a saved printer — all before
    //    the first frame could be drawn. Deferring it keeps the splash
    //    instant. Printing only happens on user demand.
    try {
      if (GetPlatform.isMobile && Get.isRegistered<PrinterController>()) {
        await Get.find<PrinterController>().initialize();
      }
    } catch (_) {}
  });
}

class MyApp extends StatelessWidget {
  final Map<String, Map<String, String>>? languages;
  final NotificationBodyModel? body;
  const MyApp({super.key, required this.languages, required this.body});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return GetBuilder<ThemeController>(
      builder: (themeController) {
        return GetBuilder<LocalizationController>(
          builder: (localizeController) {
            return GetMaterialApp(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              navigatorKey: Get.key,
              theme: themeController.darkTheme ? dark : light,
              locale: localizeController.locale,
              translations: Messages(languages: languages),
              fallbackLocale: Locale(
                AppConstants.languages[0].languageCode!,
                AppConstants.languages[0].countryCode,
              ),
              initialRoute: RouteHelper.getSplashRoute(body),
              getPages: RouteHelper.routes,
              defaultTransition: Transition.topLevel,
              transitionDuration: const Duration(milliseconds: 50),
              builder: (BuildContext context, widget) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1)),
                  child: Material(
                    child: SafeArea(
                      top: false,
                      bottom: GetPlatform.isAndroid,
                      child: Stack(
                        children: [
                          widget!,

                          GetBuilder<ProfileController>(
                            builder: (profileController) {
                              bool canShow =
                                  profileController.profileModel != null &&
                                  profileController
                                          .profileModel!
                                          .subscription !=
                                      null &&
                                  profileController
                                          .profileModel!
                                          .subscription!
                                          .isTrial ==
                                      1 &&
                                  int.tryParse(
                                        profileController
                                            .profileModel!
                                            .subscription!
                                            .status
                                            .toString(),
                                      ) ==
                                      1 &&
                                  DateConverterHelper.differenceInDaysIgnoringTime(
                                        DateTime.parse(
                                          profileController
                                              .profileModel!
                                              .subscription!
                                              .expiryDate!,
                                        ),
                                        null,
                                      ) >
                                      0;

                              return canShow &&
                                      !profileController.trialWidgetNotShow
                                  ? Align(
                                      alignment: Alignment.bottomRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 90,
                                        ),
                                        child: TrialWidget(
                                          subscription: profileController
                                              .profileModel!
                                              .subscription!,
                                        ),
                                      ),
                                    )
                                  : const SizedBox();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
