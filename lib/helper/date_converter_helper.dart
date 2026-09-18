import 'package:ppdelistore/features/splash/controllers/splash_controller.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';

class DateConverterHelper {
  static String formatDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd hh:mm:ss').format(dateTime);
  }

  static String estimatedDate(DateTime dateTime) {
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  static DateTime convertStringToDatetime(String dateTime) {
    return DateFormat("yyyy-MM-ddTHH:mm:ss.SSS").parse(dateTime);
  }

  static DateTime isoStringToLocalDate(String dateTime) {
    return DateFormat('yyyy-MM-ddTHH:mm:ss.SSS').parse(dateTime).toLocal();
  }

  static String dateTimeStringToDateTime(String dateTime) {
    return DateFormat(
      'dd MMM yyyy  ${_timeFormatter()}',
    ).format(DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateTime));
  }

  static String dateTimeStringToDateOnly(String dateTime) {
    return DateFormat(
      'dd MMM yyyy',
    ).format(DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateTime));
  }

  static DateTime dateTimeStringToDate(String dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateTime);
  }

  static String isoStringToLocalDateOnly(String dateTime) {
    return DateFormat('dd MMM yyyy').format(isoStringToLocalDate(dateTime));
  }

  static String isoStringToLocalDateTimeOnly(String dateTime) {
    return DateFormat(
      'dd MMM yyyy | HH:mm a',
    ).format(isoStringToLocalDate(dateTime));
  }

  static String localDateToIsoString(DateTime dateTime) {
    return DateFormat('yyyy-MM-ddTHH:mm:ss.SSS').format(dateTime);
  }

  static String convertStringTimeToTime(String time) {
    return DateFormat(_timeFormatter()).format(DateFormat('HH:mm').parse(time));
  }

  static String convertTimeToTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  static DateTime convertTimeToDateTime(String time) {
    return DateFormat('HH:mm').parse(time);
  }

  static String convertDateToDate(String date) {
    return DateFormat(
      'dd MMM yyyy',
    ).format(DateFormat('yyyy-MM-dd').parse(date));
  }

  static String dateTimeStringToMonthAndTime(String dateTime) {
    return DateFormat(
      'dd MMM yyyy \nHH:mm a',
    ).format(dateTimeStringToDate(dateTime));
  }

  static String dateTimeForCoupon(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  static String utcToDateTime(String dateTime) {
    DateTime? parsedDate = DateTime.tryParse(dateTime);
    parsedDate ??= DateTime.tryParse(dateTime.replaceFirst(' ', 'T'));

    if (parsedDate != null) {
      return DateFormat('dd MMM, yyyy h:mm a').format(parsedDate.toLocal());
    }

    String cleanedDate = dateTime.replaceAll('T', ' ');
    cleanedDate = cleanedDate.replaceAll(
      RegExp(r'(\.\d+)?Z$', caseSensitive: false),
      '',
    );
    return cleanedDate.trim();
  }

  static String utcToDate(String dateTime) {
    return DateFormat('dd MMM, yyyy').format(DateTime.parse(dateTime));
  }

  static bool isAvailable(
    String? start,
    String? end, {
    DateTime? time,
    bool isoTime = false,
  }) {
    DateTime currentTime;
    if (time != null) {
      currentTime = time;
    } else {
      currentTime = Get.find<SplashController>().currentTime;
    }
    DateTime start0 = start != null
        ? isoTime
              ? isoStringToLocalDate(start)
              : DateFormat('HH:mm').parse(start)
        : DateTime(currentTime.year);
    DateTime end0 = end != null
        ? isoTime
              ? isoStringToLocalDate(end)
              : DateFormat('HH:mm').parse(end)
        : DateTime(
            currentTime.year,
            currentTime.month,
            currentTime.day,
            23,
            59,
          );
    DateTime startTime = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
      start0.hour,
      start0.minute,
      start0.second,
    );
    DateTime endTime = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
      end0.hour,
      end0.minute,
      end0.second,
    );
    if (endTime.isBefore(startTime)) {
      endTime = endTime.add(const Duration(days: 1));
    }
    return currentTime.isAfter(startTime) && currentTime.isBefore(endTime);
  }

  static String _timeFormatter() {
    return Get.find<SplashController>().configModel!.timeformat == '24'
        ? 'HH:mm'
        : 'hh:mm a';
  }

  static String localDateToIsoStringAMPM(DateTime dateTime) {
    return DateFormat(
      '${_timeFormatter()} | d-MMM-yyyy ',
    ).format(dateTime.toLocal());
  }

  static String dateTimeStringForDisbursement(String time) {
    var newTime = '${time.substring(0, 10)} ${time.substring(11, 23)}';
    return DateFormat(
      'dd MMM, yyyy',
    ).format(DateFormat('yyyy-MM-dd HH:mm:ss').parse(newTime));
  }

  // static int expireDifferanceInDays(DateTime dateTime) {
  //   return dateTime.difference(DateTime.now()).inDays;
  // }

  static String localDateToMonthDateSince(DateTime dateTime) {
    return DateFormat('MMM d, yyyy ').format(dateTime.toLocal());
  }

  static int differenceInDaysIgnoringTime(
    DateTime dateTime1,
    DateTime? dateTime2,
  ) {
    DateTime date1 = DateTime(dateTime1.year, dateTime1.month, dateTime1.day);
    DateTime date2;
    if (dateTime2 != null) {
      date2 = DateTime(dateTime2.year, dateTime2.month, dateTime2.day);
    } else {
      date2 = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
    }
    return date1.difference(date2).inDays;
  }

  static String stringToMDY(String dateTime) {
    return DateFormat('MM/dd/yyyy').format(DateTime.parse(dateTime).toLocal());
  }

  static DateTime stringToDateTimeMDY(String dateTime) {
    return DateFormat('MM/dd/yyyy').parse(dateTime).toLocal();
  }

  static DateTime isoUtcStringToLocalDateOnly(String dateTime) {
    return DateFormat('yyyy-MM-dd').parse(dateTime, true).toLocal();
  }

  static String dateMonthYearTime(DateTime? dateTime) {
    return DateFormat('d MMM, y ${_timeFormatter()}').format(dateTime!);
  }

  static DateTime isoUtcStringToLocalDate(String dateTime) {
    return DateFormat(
      'yyyy-MM-ddTHH:mm:ss.SSS',
    ).parse(dateTime, true).toLocal();
  }

  static String stringToLocalDateOnly(String dateTime) {
    return DateFormat(
      'dd MMM, yyyy',
    ).format(DateTime.parse(dateTime).toLocal());
  }

  static String dayDateTime(String dateTime) {
    return DateFormat(
      'EEEE, dd MMMM yyyy, hh:mm a',
    ).format(DateTime.parse(dateTime).toLocal());
  }

  static DateTime formattingTripDateTime(
    DateTime pickedTime,
    DateTime pickedDate,
  ) {
    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  static bool isSameDate(DateTime pickedTime) {
    return pickedTime.year == DateTime.now().year &&
        pickedTime.month == DateTime.now().month &&
        pickedTime.day == DateTime.now().day &&
        pickedTime.hour == DateTime.now().hour;
  }

  static bool isAfterCurrentDateTime(DateTime pickedTime) {
    DateTime pick = DateTime(
      pickedTime.year,
      pickedTime.month,
      pickedTime.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    DateTime current = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      DateTime.now().hour,
      DateTime.now().minute,
    );
    return pick.isAfter(current);
  }

  static String dateTimeForTax(DateTime dateTime) {
    return DateFormat('MM/dd/yyyy').format(dateTime);
  }

  static String beforeTimeFormat(
    String time, {
    DateTime? now,
    int showFullDateThreshold = 30,
  }) {
    final currentTime = now ?? DateTime.now();
    DateTime pastTime = dateTimeStringToDate(time);
    final Duration difference = currentTime.difference(pastTime);

    if (difference.isNegative) {
      return 'in the future';
    }

    final int seconds = difference.inSeconds;

    if (seconds < 60) {
      return 'just_now'.tr;
    }

    if (seconds < 86400) {
      // Less than 1 day
      final int totalMinutes = difference.inMinutes;
      final int hours = (totalMinutes / 60).floor();
      final int minutes = totalMinutes % 60;

      if (hours > 0) {
        // Example: "3 hours 45 minutes ago"
        final String hourText = '${hours}h';
        final String minuteText = minutes > 0 ? ' ${minutes}min' : '';
        return '$hourText$minuteText ${'ago'.tr}';
      } else {
        // Fallback to minutes if less than an hour
        return '${minutes}min ${'ago'.tr}';
      }
    } else if (seconds < 604800) {
      // Less than 7 days
      final int totalHours = difference.inHours;
      final int days = (totalHours / 24).floor();
      final int hours = totalHours % 24;

      // Example: "1 day 5 hours ago"
      final String dayText = '${days}d';
      final String hourText = hours > 0 ? ' ${hours}h' : '';
      return '$dayText$hourText ${'ago'.tr}';
    }

    List<_TimeUnit> units = [
      // We start checks here because minutes, hours, and days are handled above.
      // ~30 days cutoff (2592000s). Divisor: 604800 to get weeks.
      _TimeUnit(
        cutoffSeconds: 2592000,
        unitName: 'week'.tr,
        conversionFactor: 604800,
      ),
      // ~1 year cutoff (31536000s). Divisor: 2592000 to get months.
      _TimeUnit(
        cutoffSeconds: 31536000,
        unitName: 'month'.tr,
        conversionFactor: 2592000,
      ),
      // Final large cutoff. Divisor: 31536000 to get years.
      _TimeUnit(
        cutoffSeconds: 999999999999,
        unitName: 'year'.tr,
        conversionFactor: 31536000,
      ),
    ];

    for (final unit in units) {
      if (seconds < unit.cutoffSeconds) {
        final int value = (seconds / unit.conversionFactor).floor();
        return '$value ${'${unit.unitName}${value == 1 ? '' : 's'}'.tr} ${'ago'.tr}';
      }
    }

    final int years = (seconds / 31536000).floor();
    return '$years ${'year${years == 1 ? '' : 's'}'.tr} ${'ago'.tr}';
  }
}

class _TimeUnit {
  final int cutoffSeconds;
  final String unitName;
  final int conversionFactor;

  const _TimeUnit({
    required this.cutoffSeconds,
    required this.unitName,
    required this.conversionFactor,
  });
}
