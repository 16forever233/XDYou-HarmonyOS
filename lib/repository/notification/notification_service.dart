// Copyright 2025 Hazuki Keatsu and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0

// Abstract base class for notification services using flutter_local_notifications

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:watermeter/repository/logger.dart';

/// Abstract base class for managing notifications.
///
/// This class provides a common interface and basic implementation for
/// notification functionalities, intended to be extended by specific
/// notification services (e.g., course reminders).
///
/// Attention: Every Subclass inherits from this should add the subclass
/// in the [NotificationRegistrar](./notification_registrar.dart)
/// to make sure the initialization and event handle.
abstract class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Platform specific notification details configuration
  final AndroidNotificationDetails? androidNotificationDetails;
  final DarwinNotificationDetails? darwinNotificationDetails;

  NotificationService({
    this.androidNotificationDetails,
    this.darwinNotificationDetails,
  });

  @protected
  bool initialized = false;

  bool get isInitialized => initialized;

  /// Initializes the notification service.
  ///
  /// This must be called before any other methods. It sets up the
  /// notification plugin, time zones, and platform-specific settings.
  Future<void> initialize({String? timeZone}) async {
    if (initialized) return;

    try {
      // Initialize time zone data
      tz.initializeTimeZones();
      final effectiveTimeZone = timeZone ?? 'Asia/Shanghai';
      tz.setLocalLocation(tz.getLocation(effectiveTimeZone));

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
            macOS: initializationSettingsDarwin,
            ohos: OhosInitializationSettings('icon'),
          );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: handleNotificationTap,
      );

      initialized = true;
      log.info(
        'Notification service initialized successfully for ${runtimeType.toString()}',
      );
    } catch (e, stackTrace) {
      log.error(
        'Failed to initialize notification service for ${runtimeType.toString()}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Abstract method to handle notification tap events.
  ///
  /// Subclasses must implement this to define behavior when a user
  /// taps on a notification.
  ///
  /// If you wanna use this method, please call
  /// [handleAppLaunchFromNotification] of your instance to make it work.
  void handleNotificationTap(NotificationResponse response);

  /// Handle app launch from notification tap.
  ///
  /// This should be called during app startup to process any notification
  /// that launched the app.
  Future<void> handleAppLaunchFromNotification() async {
    final NotificationAppLaunchDetails? launchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse != null) {
      handleNotificationTap(launchDetails.notificationResponse!);
    }
  }

  /// On OHOS, proactively request notification permission before scheduling
  /// or showing a notification, so the first use triggers the system dialog
  /// and the task only runs after permission is granted.
  Future<void> _ensureOhosNotificationPermission() async {
    if (!Platform.isOhos) {
      return;
    }
    if (await checkNotificationPermission()) {
      return;
    }
    await requestNotificationPermission();
    if (!await checkNotificationPermission()) {
      throw StateError('Notification permission not granted');
    }
  }

  /// Core zoned-schedule call (one attempt).
  Future<void> _zonedScheduleOnce({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(
      scheduledTime,
      tz.local,
    );

    if (Platform.isAndroid) {
      final notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } else if (Platform.isIOS || Platform.isMacOS) {
      final notificationDetails = NotificationDetails(
        iOS: Platform.isIOS ? darwinNotificationDetails : null,
        macOS: Platform.isMacOS ? darwinNotificationDetails : null,
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } else if (Platform.isOhos) {
      final notificationDetails = NotificationDetails(
        ohos: const OhosNotificationDetails(
          // 同 showImmediate：SOCIAL_COMMUNICATION 带横幅+声音（跟随系统通知设置）。
          OhosNotificationSlotType.SOCIAL_COMMUNICATION,
        ),
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    }

    log.info(
      '[CourseReminderService] [scheduleNotification] Scheduled course notification $id at $scheduledTime',
    );
  }

  /// Subclasses must implement this to provide specific details for
  /// scheduling, such as channel information and payload structure.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (!initialized) {
      throw StateError(
        '[CourseReminderService] Notification service not initialized',
      );
    }

    await _ensureOhosNotificationPermission();

    try {
      await _zonedScheduleOnce(
        id: id,
        title: title,
        body: body,
        scheduledTime: scheduledTime,
        payload: payload,
      );
    } catch (e, stackTrace) {
      // HarmonyOS reminderAgentManager 对提醒数有上限（1700002）。
      // 首次失败时清空本应用历史提醒再重试一次，避免测试/历史残留导致超限。
      if (e.toString().contains('exceeds the limit') ||
          (e is PlatformException && e.code == '1700002')) {
        log.info(
          '[CourseReminderService] [scheduleNotification] Reminder limit hit (1700002), cancelling all reminders and retrying once',
        );
        try {
          await cancelAllNotifications();
        } catch (_) {}
        try {
          await _zonedScheduleOnce(
            id: id,
            title: title,
            body: body,
            scheduledTime: scheduledTime,
            payload: payload,
          );
          return;
        } catch (e2, s2) {
          int pendingCount = 0;
          try {
            pendingCount = (await getPendingNotifications()).length;
          } catch (_) {}
          log.error(
            '[CourseReminderService] [scheduleNotification] '
            'Still 1700002 after cancel+retry, pendingReminderCount=$pendingCount',
            e2,
            s2,
          );
          throw PlatformException(
            code: '1700002',
            message: '1700002 after retry, pendingReminderCount=$pendingCount',
            details: e2,
          );
        }
      }
      log.error(
        '[CourseReminderService] [scheduleNotification] Failed to schedule course notification',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Method to send (show) a notification immediately.
  ///
  /// Subclasses can override this to provide platform- and
  /// channel-specific logic for showing a notification right away.
  Future<void> sendImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!initialized) {
      throw StateError('Notification service not initialized');
    }

    await _ensureOhosNotificationPermission();

    try {
      if (Platform.isAndroid) {
        final notificationDetails = NotificationDetails(
          android: androidNotificationDetails,
        );

        await flutterLocalNotificationsPlugin.show(
          id,
          title,
          body,
          notificationDetails,
          payload: payload,
        );
      } else if (Platform.isIOS || Platform.isMacOS) {
        final notificationDetails = NotificationDetails(
          iOS: Platform.isIOS ? darwinNotificationDetails : null,
          macOS: Platform.isMacOS ? darwinNotificationDetails : null,
        );

        await flutterLocalNotificationsPlugin.show(
          id,
          title,
          body,
          notificationDetails,
          payload: payload,
        );
      } else if (Platform.isOhos) {
        final notificationDetails = NotificationDetails(
          ohos: const OhosNotificationDetails(
            // SOCIAL_COMMUNICATION：有横幅 + 声音（跟随系统通知设置/静音模式）。
            OhosNotificationSlotType.SOCIAL_COMMUNICATION,
          ),
        );

        await flutterLocalNotificationsPlugin.show(
          id,
          title,
          body,
          notificationDetails,
          payload: payload,
        );
      }

      log.info('Sent immediate notification $id');
    } catch (e, stackTrace) {
      log.error('Failed to send immediate notification', e, stackTrace);
      rethrow;
    }
  }

  /// Requests notification permissions from the user.
  Future<bool> requestNotificationPermission() async {
    bool? result;
    if (Platform.isAndroid) {
      result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isMacOS) {
      result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isOhos) {
      final status = await Permission.notification.request();
      if (status.isGranted) {
        return true;
      }
      // HarmonyOS 一旦用户拒绝过 requestEnableNotification，系统不允许再次弹窗，
      // 只能跳转到系统通知设置页手动开启。
      await openAppSettings();
      return false;
    } else {
      return false;
    }
    return result ?? false;
  }

  /// Checks if notification permissions have been granted.
  Future<bool> checkNotificationPermission() async {
    if (Platform.isAndroid) {
      final result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      return result ?? false;
    } else if (Platform.isIOS) {
      // On iOS, we use requestPermissions to check current status
      // The plugin will return the current permission status without showing a prompt if already determined
      final iosPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosPlugin == null) return false;

      // Request permissions returns true if any permission is granted
      // This doesn't show a prompt if the user has already responded
      final result = await iosPlugin.checkPermissions();
      if (result == null) return false;
      return result.isEnabled;
    } else if (Platform.isMacOS) {
      final macosPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macosPlugin == null) return false;
      final result = await macosPlugin.checkPermissions();
      if (result == null) return false;
      return result.isEnabled;
    } else if (Platform.isOhos) {
      final status = await Permission.notification.status;
      return status.isGranted;
    } else {
      return false;
    }
  }

  /// Requests schedule exact alarm permission (Android only).
  Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true; // Not applicable on other platforms

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return false;

    // Request exact alarm permission by opening settings
    final result = await androidPlugin.requestExactAlarmsPermission();
    return result ?? false;
  }

  /// Checks if schedule exact alarm permission has been granted (Android only).
  Future<bool> checkExactAlarmPermission() async {
    if (!Platform.isAndroid) return true; // Not applicable on other platforms

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return false;

    final result = await androidPlugin.canScheduleExactNotifications();
    return result ?? false;
  }

  /// Retrieves a list of all pending (scheduled) notifications.
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!initialized) {
      throw StateError('Notification service not initialized');
    }

    try {
      final results = await flutterLocalNotificationsPlugin
          .pendingNotificationRequests();
      return results;
    } catch (e, stackTrace) {
      log.error('Failed to get pending notifications', e, stackTrace);
      return [];
    }
  }

  /// Cancels a specific notification by its [id].
  Future<void> cancelNotification(int id) async {
    if (!initialized) {
      throw StateError('Notification service not initialized');
    }

    try {
      await flutterLocalNotificationsPlugin.cancel(id);
      log.info('Cancelled notification $id');
    } catch (e, stackTrace) {
      log.error('Failed to cancel notification', e, stackTrace);
      rethrow;
    }
  }

  /// Cancels all scheduled notifications.
  Future<void> cancelAllNotifications() async {
    if (!initialized) {
      throw StateError('Notification service not initialized');
    }

    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      log.info('Cancelled all notifications');
    } catch (e, stackTrace) {
      log.error('Failed to cancel all notifications', e, stackTrace);
      rethrow;
    }
  }

  /// Opens the app's notification settings page.
  Future<void> openNotificationSettings() async {
    if (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isOhos) {
      await openAppSettings();
    }
  }
}
