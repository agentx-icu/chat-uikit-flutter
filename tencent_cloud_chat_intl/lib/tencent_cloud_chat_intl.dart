// ignore_for_file: unused_local_variable

library tencent_cloud_chat_intl;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tencent_cloud_chat_intl/localizations/tencent_cloud_chat_localizations.dart';

TencentCloudChatLocalizations get tL10n => TencentCloudChatIntl().localization!;

class TencentCloudChatIntl extends ChangeNotifier {
  static TencentCloudChatIntl? _instance;

  static bool hasInitialized = false;

  TencentCloudChatIntl._internal(this._currentLocale);

  factory TencentCloudChatIntl({Locale? locale}) {
    _instance ??= TencentCloudChatIntl._internal(locale);
    return _instance!;
  }

  TencentCloudChatLocalizations? localization;
  Locale? _currentLocale;

  Locale getCurrentLocale(BuildContext context) {
    return _currentLocale ?? Localizations.localeOf(context);
  }

  init(BuildContext context) {
    if (hasInitialized) {
      return;
    }
    _currentLocale ??= Localizations.localeOf(context);
    localization = TencentCloudChatLocalizations.of(context);
    if (localization != null) {
      hasInitialized = true;
    }
  }

  void setLocale(Locale newLocale) {
    _currentLocale = newLocale;
    localization = lookupTencentCloudChatLocalizations(newLocale);
    notifyListeners();
  }

  static String serializeLocale(Locale locale) {
    String languageCode = locale.languageCode;
    String countryCode = locale.countryCode ?? '';
    String scriptCode = locale.scriptCode ?? '';

    return '${languageCode}_${countryCode}_$scriptCode';
  }

  static Locale? deserializeLocale(String localeString) {
    if (localeString.isEmpty) {
      return null;
    }
    List<String> codes = localeString.split('_');
    String languageCode = codes[0];
    String countryCode = codes.length > 1 ? codes[1] : '';
    String scriptCode = codes.length > 2 ? codes[2] : '';

    return Locale.fromSubtags(
      languageCode: languageCode,
      countryCode: countryCode.isNotEmpty ? countryCode : null,
      scriptCode: scriptCode.isNotEmpty ? scriptCode : null,
    );
  }

  static String localizedDateString(int timestamp, BuildContext context) {
    Locale locale = TencentCloudChatIntl().getCurrentLocale(context);

    // Convert the timestamp (seconds) to a DateTime object
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

    // Get the current year
    int currentYear = DateTime.now().year;

    // Choose the date format based on whether the date is in the current year
    DateFormat dateFormat = date.year == currentYear ? DateFormat.MMMMd(locale.toString()) : DateFormat.yMMMMd(locale.toString());

    // Format the date using the selected date format
    String dateString = dateFormat.format(date);

    return dateString;
  }

  /// Formats [dateTime] as a date plus time of day for display, in the current
  /// UIKit locale's own convention ("Sep 17, 2026 9:28 AM" in English,
  /// "2026年9月17日 09:28" in Chinese, ...). Resolves the locale like
  /// [formatTimestampToTime]. Use this — not [getFormattedTimeString], which is
  /// a fixed English log format — for anything a user reads.
  static String formatDateTime(DateTime dateTime, [BuildContext? context]) {
    final locale = _formatLocale(context);
    return _withLocaleFallback(locale, (l) => DateFormat.yMMMd(l).add_jm()).format(dateTime);
  }

  /// Returns a formatted string representation of the current date and time.
  ///
  /// [dateTime] (optional) represents the date and time to format. If not provided, the current date and time will be used.
  ///
  /// Returns a string in the format "yyyy-MM-dd hh:mm:ss a".
  ///
  /// This function is used to format the date and time for logging purposes.
  /// It is locale-independent on purpose; never show it in the UI.
  ///
  /// Example:
  /// ```dart
  /// void main() {
  ///   /// Get the current formatted date and time
  ///   String formattedDateTime = getFormattedTimeString();
  ///
  ///   print("Current date and time: $formattedDateTime");
  /// }
  /// ```
  static String getFormattedTimeString({
    DateTime? dateTime,
  }) {
    // If dateTime is not provided, use the current date and time.
    dateTime ??= DateTime.now();

    // Create a DateFormat object for formatting the date and time.
    final dateFormat = DateFormat('yyyy-MM-dd hh:mm:ss a');

    // Format the DateTime object as a localized string and return it.
    return dateFormat.format(dateTime);
  }

  /// Formats a given timestamp (in seconds) into a time-of-day string in the
  /// current UIKit locale's own convention ("11:00 AM" in English, "11:00" in
  /// Chinese, ...).
  ///
  /// This method takes an integer [timestamp] representing the number of seconds since the Unix epoch
  /// (January 1, 1970 at 00:00:00 UTC) and returns a formatted time string.
  ///
  /// The locale is the one [getCurrentLocale] resolves for [context] — the same
  /// source [formatTimestampToHumanReadable] uses, so a message bubble and its
  /// conversation-list row agree. Without [context] it falls back to the locale
  /// last applied through [setLocale]. A locale-less `DateFormat.jm()` would
  /// format with `Intl.defaultLocale` instead, which the app never sets, so
  /// every non-English UI showed English "9:28 AM" bubble times.
  ///
  /// Example:
  /// ```
  /// int timestamp = 1635504600; // Represents "2021-10-29 11:00:00"
  /// String formattedTime = formatTimestampToTime(timestamp, context);
  /// print(formattedTime); // Output: "11:00 AM" (en), "11:00" (zh)
  /// ```
  static String formatTimestampToTime(int timestamp, [BuildContext? context]) {
    // Convert the timestamp (in seconds) to a DateTime object.
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

    final locale = _formatLocale(context);
    return _withLocaleFallback(locale, DateFormat.jm).format(dateTime);
  }

  static String? _formatLocale(BuildContext? context) {
    final intl = TencentCloudChatIntl();
    return (context != null ? intl.getCurrentLocale(context) : intl._currentLocale)?.toString();
  }

  /// Date symbols for non-English locales arrive with the first
  /// `GlobalMaterialLocalizations` load. A context-less call made before that
  /// (or for a locale intl does not ship) would throw, so degrade to the
  /// default pattern instead of taking the caller down.
  static DateFormat _withLocaleFallback(String? locale, DateFormat Function(String?) build) {
    try {
      return build(locale);
    } on ArgumentError {
      return build(null);
    }
  }

  /// Formats a given timestamp (in seconds) into a human-readable string based on different scenarios.
  ///
  /// This method takes an integer [timestamp] representing the number of seconds since the Unix epoch
  /// (January 1, 1970 at 00:00:00 UTC) and returns a human-readable string based on different scenarios:
  /// - If the timestamp and current time are on the same day, it returns the time in the current format (e.g., "11:00 AM").
  /// - If the timestamp is from yesterday, it returns "Yesterday".
  /// - If the timestamp is from before yesterday but in the same week, it returns the day of the week (e.g., "Monday").
  /// - If the timestamp is from before the current week but in the same year, it returns the date string without the year.
  /// - Otherwise, it returns the date string with the year.
  ///
  /// Example:
  /// ```
  /// int timestamp = 1635504600; // Represents "2021-10-29 11:00:00"
  /// String formattedTime = formatTimestampToHumanReadable(timestamp);
  /// print(formattedTime); // Output: "11:00 AM"
  /// ```
  static String formatTimestampToHumanReadable(int timestamp, BuildContext context) {
    Locale locale = TencentCloudChatIntl().getCurrentLocale(context);

    final now = DateTime.now();
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final timeFormat = DateFormat.jm(locale.toString());
    final dateFormat = DateFormat.yMMMMd(locale.toString());

    // Check if timestamp and now are on the same day
    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return timeFormat.format(dateTime);
    }

    // Check if timestamp is from yesterday
    final yesterday = now.subtract(const Duration(days: 1));
    if (dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day) {
      return tL10n.yesterday;
    }

    // Check if timestamp is from before yesterday but in the same week
    if (dateTime.isAfter(now.subtract(const Duration(days: 6)))) {
      if(locale.languageCode == "en"){
        return DateFormat.E(locale.toString()).format(dateTime);
      }
      return DateFormat.EEEE(locale.toString()).format(dateTime);
    }

    // Check if timestamp is from before the current week but in the same year
    if (dateTime.year == now.year) {
      return DateFormat('MM/dd', locale.toString()).format(dateTime);
    }

    // Return the date string with the year for other cases
    return MaterialLocalizations.of(context).formatCompactDate(dateTime);
  }

  static String formatSeconds(int seconds) {
    String timeStr = '$seconds${tL10n.second}';

    if (seconds > 60) {
      int second = seconds % 60;
      int min = seconds ~/ 60;
      timeStr = '$min${tL10n.min}$second${tL10n.second}';

      if (min > 60) {
        min = (seconds ~/ 60) % 60;
        int hour = (seconds ~/ 60) ~/ 60;
        timeStr = '$hour${tL10n.hour}$min${tL10n.min}$second${tL10n.second}';

        if (hour % 24 == 0) {
          int day = ((seconds ~/ 60) ~/ 60) ~/ 24;
          timeStr = '$day${tL10n.day}';
        } else if (hour > 24) {
          hour = ((seconds ~/ 60) ~/ 60) % 24;
          int day = ((seconds ~/ 60) ~/ 60) ~/ 24;
          timeStr = '$day${tL10n.day}$hour${tL10n.hour}$min${tL10n.min}$second${tL10n.second}';
        }
      }
    }

    return timeStr;
  }

}
