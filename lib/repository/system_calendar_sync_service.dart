// Copyright 2023-2025 BenderBlog Rodriguez and contributors
// Copyright 2025 Traintime PDA authors.
// SPDX-License-Identifier: MPL-2.0 OR Apache-2.0

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:device_calendar/device_calendar.dart' as ohos;
import 'package:device_calendar_plus/device_calendar_plus.dart' as plus;
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:watermeter/controller/classtable_controller.dart';
import 'package:watermeter/controller/custom_class_controller.dart';
import 'package:watermeter/controller/exam_controller.dart';
import 'package:watermeter/controller/other_experiment_controller.dart';
import 'package:watermeter/controller/physics_experiment_controller.dart';
import 'package:watermeter/model/pda_service/custom_class.dart';
import 'package:watermeter/model/time_list.dart';
import 'package:watermeter/model/xidian_ids/classtable.dart';
import 'package:watermeter/model/xidian_ids/exam.dart';
import 'package:watermeter/model/xidian_ids/experiment.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/preference.dart' as preference;

const String exportedClassTableCalendarPrefix = 'PDA Class Arrangement';

/// Build a stable calendar name for exported classtable events.
String buildExportedClassTableCalendarName(String semesterCode) =>
    semesterCode.isEmpty
    ? exportedClassTableCalendarPrefix
    : '$exportedClassTableCalendarPrefix $semesterCode';

/// Build a stable snapshot used to decide whether auto sync is needed.
String buildSystemCalendarSnapshot({
  required ClassTableData classTableData,
  required List<Subject> subjects,
  required List<ExperimentData> experiments,
  required List<CustomClass> customClasses,
}) => jsonEncode({
  'classTableData': classTableData.toJson(),
  'subjects': subjects.map((item) => item.toJson()).toList(),
  'experiments': experiments.map((item) => item.toJson()).toList(),
  'customClasses': customClasses.map((item) => item.toJson()).toList(),
});

/// 平台无关的周重复规则草稿（daysOfWeek 为 ISO 星期编号：1=周一 ... 7=周日）。
class CalendarWeeklyRecurrenceDraft {
  final List<int> daysOfWeek;
  final DateTime until;

  const CalendarWeeklyRecurrenceDraft({
    required this.daysOfWeek,
    required this.until,
  });
}

/// Lightweight draft used to build events before pushing them to the system
/// calendar or serialising to iCalendar format.
///
/// 注意：不再持有任何插件具体类型的 RecurrenceRule，
/// 以便同一份草稿同时服务 device_calendar_plus（Android/iOS）
/// 与 device_calendar 鸿蒙适配版两条后端。
class CalendarEventDraft {
  final String title;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String? location;
  final CalendarWeeklyRecurrenceDraft? recurrenceRule;

  const CalendarEventDraft({
    required this.title,
    this.description,
    required this.startDate,
    required this.endDate,
    this.location,
    this.recurrenceRule,
  });
}

List<CalendarEventDraft> buildCalendarEvents({
  required ClassTableData classTableData,
  required List<Subject> subjects,
  required List<ExperimentData> experiments,
  required List<CustomClass> customClasses,
}) {
  List<CalendarEventDraft> events = [];

  if (classTableData.termStartDay.isNotEmpty) {
    DateTime startDay = DateTime.parse(classTableData.termStartDay);

    for (var i in classTableData.timeArrangement) {
      int j = i.weekList.indexWhere((element) => element);

      if (j == -1) continue;

      List<(int, int)> ranges = [];
      int start = -1;

      for (j; j < i.weekList.length; j++) {
        if (i.weekList[j] && start == -1) {
          start = j;
        } else if (!i.weekList[j] && start != -1) {
          ranges.add((start, j - 1));
          start = -1;
        }
      }

      if (start != -1) {
        ranges.add((start, j - 1));
      }

      String title =
          '${classTableData.getClassDetail(i).name}@${i.classroom ?? "待定"}';
      String description =
          '课程名称：${classTableData.getClassDetail(i).name} - 老师：${i.teacher ?? "未知"}';
      String? location = i.classroom ?? '待定';

      List<String> startTime = timeList[(i.start - 1) * 2].split(':');
      List<String> stopTime = timeList[(i.stop - 1) * 2 + 1].split(':');

      for (var range in ranges) {
        DateTime firstDay = startDay.add(
          Duration(days: range.$1 * 7 + i.day - 1),
        );

        DateTime startTimeToUse = firstDay.add(
          Duration(
            hours: int.parse(startTime[0]),
            minutes: int.parse(startTime[1]),
          ),
        );
        DateTime stopTimeToUse = firstDay.add(
          Duration(
            hours: int.parse(stopTime[0]),
            minutes: int.parse(stopTime[1]),
          ),
        );

        events.add(
          CalendarEventDraft(
            title: title,
            description: description,
            recurrenceRule: CalendarWeeklyRecurrenceDraft(
              daysOfWeek: [i.day],
              until: firstDay.add(
                Duration(days: (range.$2 - range.$1) * 7 + 1),
              ),
            ),
            startDate: startTimeToUse,
            endDate: stopTimeToUse,
            location: location,
          ),
        );
      }
    }
  }

  for (var i in subjects) {
    String title =
        '${i.subject} ${i.typeStr}@${i.place} ${i.seat != null ? "-${i.seat}" : ""}';
    String description = '考试信息：${i.subject} - ${i.typeStr}';
    String location = '${i.place} ${i.seat != null ? "-${i.seat}" : ""}';

    events.add(
      CalendarEventDraft(
        title: title,
        description: description,
        startDate: i.startTime!,
        endDate: i.stopTime!,
        location: location,
      ),
    );
  }

  for (var experiment in experiments) {
    for (var j in experiment.timeRanges) {
      events.add(
        CalendarEventDraft(
          title: '${experiment.name}@${experiment.classroom}',
          description: '实验名称：${experiment.name} - 老师：${experiment.teacher}',
          startDate: j.$1,
          endDate: j.$2,
          location: experiment.classroom,
        ),
      );
    }
  }

  for (final cc in customClasses) {
    for (final tr in cc.timeRanges) {
      events.add(
        CalendarEventDraft(
          title: '${cc.name}@${cc.classroom ?? "待定"}',
          description: '自定义课程：${cc.name} - 老师：${cc.teacher ?? "未知"}',
          startDate: tr.startTime,
          endDate: tr.endTime,
          location: cc.classroom,
        ),
      );
    }
  }

  return events;
}

String buildICalendarString(List<CalendarEventDraft> events) {
  String toReturn =
      'BEGIN:VCALENDAR\n'
      'CALSCALE:GREGORIAN\n'
      'BEGIN:VTIMEZONE\n'
      'TZID:Asia/Shanghai\n'
      'X-LIC-LOCATION:Asia/Shanghai\n'
      'BEGIN:STANDARD\n'
      'TZOFFSETFROM:+0800\n'
      'TZOFFSETTO:+0800\n'
      'TZNAME:CST\n'
      'DTSTART:19700101T000000\n'
      'END:STANDARD\n'
      'END:VTIMEZONE\n';

  const List<String> rruleDays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  for (var i in events) {
    String vevent = 'BEGIN:VEVENT\n';

    vevent +=
        'DTSTAMP:${DateFormat('yyyyMMddTHHmmssZ').format(DateTime.now())}\n';
    vevent += 'SUMMARY:${i.title}\n';
    vevent += 'DESCRIPTION:${i.description ?? "待定"}\n';

    vevent +=
        'DTSTART;TZID=Asia/Shanghai:'
        '${DateFormat('yyyyMMddTHHmmss').format(i.startDate)}\n';
    vevent +=
        'DTEND;TZID=Asia/Shanghai:'
        '${DateFormat('yyyyMMddTHHmmss').format(i.endDate)}\n';
    if (i.location != null) {
      vevent += 'LOCATION:${i.location}\n';
    }

    final recurrence = i.recurrenceRule;
    if (recurrence != null && recurrence.daysOfWeek.isNotEmpty) {
      final byDays = recurrence.daysOfWeek
          .map((day) => rruleDays[day - 1])
          .join(',');
      vevent +=
          'RRULE:FREQ=WEEKLY;INTERVAL=1;BYDAY=$byDays;'
          'UNTIL=${DateFormat('yyyyMMdd').format(recurrence.until)}\n';
    }
    toReturn += '${vevent}END:VEVENT\n';
  }

  return '${toReturn}END:VCALENDAR\n';
}

/// 日历后端的最小中立封装，隔离两个插件（plus 与鸿蒙适配版）的类型差异。
class _CalendarInfo {
  final String id;
  final String name;

  const _CalendarInfo(this.id, this.name);
}

class SystemCalendarSyncService {
  final bool _isOhos = Platform.isOhos;
  final plus.DeviceCalendar _plusCalendar = plus.DeviceCalendar();
  final ohos.DeviceCalendarPlugin _ohosCalendar = ohos.DeviceCalendarPlugin();
  late final tz.Location _ohosEventLocation = tz.getLocation('Asia/Shanghai');

  ClassTableController get classTableController => ClassTableController.i;
  ExamController get examController => ExamController.i;
  PhysicsExperimentController get physicsExperimentController =>
      PhysicsExperimentController.i;
  OtherExperimentController get otherExperimentController =>
      OtherExperimentController.i;

  String get currentSemesterCode =>
      classTableController.classTableComputedSignal.value.semesterCode;

  String get savedCalendarId =>
      preference.getString(preference.Preference.systemCalendarId);

  String get savedCalendarSemesterCode =>
      preference.getString(preference.Preference.systemCalendarSemesterCode);

  String get calendarName =>
      buildExportedClassTableCalendarName(currentSemesterCode);

  List<ExperimentData> get experiments => [
    ...physicsExperimentController.physicsExperiments.value,
    ...otherExperimentController.otherExperiments.value,
  ];

  List<CustomClass> get customClasses =>
      CustomClassController.i.customClassesSignal.value;

  List<CalendarEventDraft> get events => buildCalendarEvents(
    classTableData: classTableController.classTableComputedSignal.value,
    subjects: examController.subjects.value,
    experiments: experiments,
    customClasses: customClasses,
  );

  String get snapshot => buildSystemCalendarSnapshot(
    classTableData: classTableController.classTableComputedSignal.value,
    subjects: examController.subjects.value,
    experiments: experiments,
    customClasses: customClasses,
  );

  bool get hasCalendarBinding => savedCalendarId.isNotEmpty;

  bool get isBoundCalendarForCurrentSemester =>
      savedCalendarSemesterCode.isNotEmpty &&
      savedCalendarSemesterCode == currentSemesterCode;

  bool get didSemesterChangeSinceLastBinding =>
      savedCalendarSemesterCode.isNotEmpty &&
      currentSemesterCode.isNotEmpty &&
      savedCalendarSemesterCode != currentSemesterCode;

  bool get canAutoSync =>
      hasCalendarBinding &&
      (didSemesterChangeSinceLastBinding ||
          preference.getString(preference.Preference.systemCalendarSnapshot) !=
              snapshot) &&
      classTableController.hasValidClassInfo.value;

  Future<bool> _ensureCalendarPermission({
    required bool requestPermissionsIfNeeded,
    Future<void> Function()? showDialog,
  }) async {
    bool granted;
    if (_isOhos) {
      final result = await _ohosCalendar.hasPermissions();
      granted = (result.data ?? false) && result.errors.isEmpty;
      log.info(
        '[SystemCalendarSyncService][_ensureCalendarPermission] '
        'ohos hasPermissions -> data=${result.data}, errors='
        '${result.errors.map((e) => '${e.errorCode}:${e.errorMessage}').toList()}',
      );
    } else {
      final status = await _plusCalendar.hasPermissions();
      granted = status == plus.CalendarPermissionStatus.granted;
    }

    if (granted) {
      return true;
    }

    if (!requestPermissionsIfNeeded) {
      return false;
    }

    if (showDialog != null) {
      await showDialog();
    }

    if (_isOhos) {
      // 鸿蒙 fork 的 requestPermissions 在权限已永久拒绝/系统未弹授权框时
      // 可能直接失败返回，这里最多请求两次，避免一次失败就报错；
      // 每次请求后都以 hasPermissions 的二次确认为准（fork 即使拒绝也返回 true）。
      for (var attempt = 0; attempt < 2; attempt++) {
        final result = await _ohosCalendar.requestPermissions();
        log.info(
          '[SystemCalendarSyncService][_ensureCalendarPermission] '
          'ohos requestPermissions(attempt=$attempt) -> data=${result.data}, errors='
          '${result.errors.map((e) => '${e.errorCode}:${e.errorMessage}').toList()}',
        );
        final check = await _ohosCalendar.hasPermissions();
        if ((check.data ?? false) && check.errors.isEmpty) {
          return true;
        }
      }
      return false;
    } else {
      final status = await _plusCalendar.requestPermissions();
      return status == plus.CalendarPermissionStatus.granted;
    }
  }

  Future<void> _saveCalendarBinding(String calendarId) async {
    await preference.setString(
      preference.Preference.systemCalendarId,
      calendarId,
    );
    await preference.setString(
      preference.Preference.systemCalendarSemesterCode,
      currentSemesterCode,
    );
  }

  Future<void> _saveCalendarSyncState(String calendarId) async {
    await _saveCalendarBinding(calendarId);
    await preference.setString(
      preference.Preference.systemCalendarSnapshot,
      snapshot,
    );
  }

  Future<void> _clearCalendarBinding() async {
    await preference.remove(preference.Preference.systemCalendarId);
    await preference.remove(preference.Preference.systemCalendarSemesterCode);
  }

  Future<List<_CalendarInfo>?> _retrieveWritableCalendars() async {
    try {
      if (_isOhos) {
        final result = await _ohosCalendar.retrieveCalendars();
        if (result.data == null) {
          return null;
        }
        return result.data!
            .where((calendar) => !(calendar.isReadOnly ?? false))
            .map(
              (calendar) =>
                  _CalendarInfo(calendar.id ?? '', calendar.name ?? ''),
            )
            .toList();
      } else {
        final calendars = await _plusCalendar.listCalendars();
        return calendars
            .where((calendar) => !calendar.readOnly)
            .map((calendar) => _CalendarInfo(calendar.id, calendar.name))
            .toList();
      }
    } catch (e, s) {
      log.info(
        '[SystemCalendarSyncService][_retrieveWritableCalendars] '
        'Retrieve calendars failed: $e',
      );
      log.handle(e, s);
      return null;
    }
  }

  Future<_CalendarInfo?> _findBoundCalendar(
    List<_CalendarInfo> calendars,
  ) async {
    if (!hasCalendarBinding) {
      return null;
    }

    for (var calendar in calendars) {
      if (calendar.id != savedCalendarId) {
        continue;
      }

      if (isBoundCalendarForCurrentSemester) {
        return calendar;
      }

      // Migrate older bindings that do not persist the semester code yet.
      if (savedCalendarSemesterCode.isEmpty &&
          calendar.name == calendarName &&
          calendar.id.isNotEmpty) {
        await _saveCalendarBinding(calendar.id);
        return calendar;
      }

      log.info(
        '[SystemCalendarSyncService][_findBoundCalendar] '
        'Skip maintaining bound calendar from semester '
        '$savedCalendarSemesterCode while current semester is '
        '$currentSemesterCode.',
      );
      return null;
    }

    await _clearCalendarBinding();
    return null;
  }

  /// Find the exported calendar by saved id or the current fixed name.
  Future<_CalendarInfo?> _findExportedCalendar() async {
    final calendars = await _retrieveWritableCalendars();
    if (calendars == null) {
      return null;
    }

    final hadCalendarBinding = hasCalendarBinding;
    final boundCalendar = await _findBoundCalendar(calendars);
    if (boundCalendar != null) {
      return boundCalendar;
    }
    // Treat a missing bound calendar as an explicit user opt-out, so auto sync
    // does not resurrect the export by falling back to name lookup.
    if (hadCalendarBinding && !hasCalendarBinding) {
      return null;
    }

    for (var calendar in calendars) {
      if (calendar.name == calendarName && calendar.id.isNotEmpty) {
        await _saveCalendarBinding(calendar.id);
        return calendar;
      }
    }

    return null;
  }

  Future<String?> _createExportedCalendar() async {
    try {
      if (_isOhos) {
        final result = await _ohosCalendar.createCalendar(calendarName);
        if (result.data == null || result.data!.isEmpty) {
          log.info(
            '[SystemCalendarSyncService][_createExportedCalendar] '
            'Create calendar returned empty id.',
          );
          return null;
        }
        return result.data;
      } else {
        final calendarId = await _plusCalendar.createCalendar(
          name: calendarName,
        );
        if (calendarId.isEmpty) {
          log.info(
            '[SystemCalendarSyncService][_createExportedCalendar] '
            'Create calendar returned empty id.',
          );
          return null;
        }
        return calendarId;
      }
    } catch (e, s) {
      log.info(
        '[SystemCalendarSyncService][_createExportedCalendar] '
        'Create calendar failed: $e',
      );
      log.handle(e, s);
      return null;
    }
  }

  Future<bool> _deleteCalendar(String calendarId) async {
    try {
      if (_isOhos) {
        final result = await _ohosCalendar.deleteCalendar(calendarId);
        return result.isSuccess;
      } else {
        await _plusCalendar.deleteCalendar(calendarId);
        return true;
      }
    } catch (e, s) {
      log.info(
        '[SystemCalendarSyncService][_deleteCalendar] '
        'Delete calendar failed: $e',
      );
      log.handle(e, s);
      return false;
    }
  }

  Future<String?> _prepareCalendar({required bool onlyIfCalendarExists}) async {
    _CalendarInfo? exportedCalendar = await _findExportedCalendar();
    bool shouldCreateCurrentSemesterCalendar =
        !onlyIfCalendarExists || didSemesterChangeSinceLastBinding;

    if (exportedCalendar == null) {
      if (!shouldCreateCurrentSemesterCalendar) {
        return null;
      }
      return await _createExportedCalendar();
    }

    if (exportedCalendar.id.isEmpty) {
      log.info(
        '[SystemCalendarSyncService][_prepareCalendar] '
        'Exported calendar has empty id.',
      );
      return null;
    }

    final didDelete = await _deleteCalendar(exportedCalendar.id);
    if (!didDelete) {
      return null;
    }

    await _clearCalendarBinding();
    return await _createExportedCalendar();
  }

  plus.RecurrenceRule? _buildPlusRecurrenceRule(CalendarEventDraft draft) {
    final recurrence = draft.recurrenceRule;
    if (recurrence == null) {
      return null;
    }
    return plus.WeeklyRecurrence(
      daysOfWeek: recurrence.daysOfWeek.map(_plusDayOfWeek).toList(),
      end: plus.UntilEnd(recurrence.until),
    );
  }

  plus.DayOfWeek _plusDayOfWeek(int day) {
    switch (day) {
      case 1:
        return plus.DayOfWeek.monday;
      case 2:
        return plus.DayOfWeek.tuesday;
      case 3:
        return plus.DayOfWeek.wednesday;
      case 4:
        return plus.DayOfWeek.thursday;
      case 5:
        return plus.DayOfWeek.friday;
      case 6:
        return plus.DayOfWeek.saturday;
      default:
        return plus.DayOfWeek.sunday;
    }
  }

  /// Expand weekly recurrence drafts into individual one-off events.
  ///
  /// The OHOS device_calendar fork currently maps Dart's
  /// `RecurrenceFrequency.Weekly` index (1) directly to the native
  /// `calendarManager.RecurrenceFrequency` enum, where 1 means MONTHLY.
  /// Writing one-off events avoids the broken recurrence path entirely and
  /// also works around the fork swallowing addEvent errors on the native side.
  List<CalendarEventDraft> _expandOhosEvents(List<CalendarEventDraft> source) {
    final expanded = <CalendarEventDraft>[];
    for (final draft in source) {
      final recurrence = draft.recurrenceRule;
      if (recurrence == null || recurrence.daysOfWeek.isEmpty) {
        expanded.add(draft);
        continue;
      }

      final daysOfWeek = recurrence.daysOfWeek.toSet();
      final duration = draft.endDate.difference(draft.startDate);

      for (var day = 0; ; day++) {
        final candidate = draft.startDate.add(Duration(days: day));
        if (!candidate.isBefore(recurrence.until)) {
          break;
        }
        if (!daysOfWeek.contains(candidate.weekday)) {
          continue;
        }
        expanded.add(
          CalendarEventDraft(
            title: draft.title,
            description: draft.description,
            startDate: candidate,
            endDate: candidate.add(duration),
            location: draft.location,
          ),
        );
      }
    }
    return expanded;
  }

  Future<bool> _writeEventsToCalendar(String calendarId) async {
    final eventsToWrite = _isOhos ? _expandOhosEvents(events) : events;
    log.info(
      '[SystemCalendarSyncService][_writeEventsToCalendar] '
      'Writing ${eventsToWrite.length} events to calendar $calendarId '
      '(${_isOhos ? "ohos" : "plus"} backend).',
    );

    for (var i in eventsToWrite) {
      try {
        if (_isOhos) {
          final event = ohos.Event(
            calendarId,
            title: i.title,
            start: tz.TZDateTime.from(i.startDate, _ohosEventLocation),
            end: tz.TZDateTime.from(i.endDate, _ohosEventLocation),
            description: i.description,
            location: i.location,
          );
          final result = await _ohosCalendar.createOrUpdateEvent(event);
          if (result == null || !result.isSuccess) {
            log.info(
              '[SystemCalendarSyncService][_writeEventsToCalendar] '
              'Create or update event failed: title=${i.title}, '
              'start=${i.startDate}, result=$result',
            );
            return false;
          }
        } else {
          await _plusCalendar.createEvent(
            calendarId: calendarId,
            title: i.title,
            startDate: i.startDate,
            endDate: i.endDate,
            description: i.description,
            location: i.location,
            recurrenceRule: _buildPlusRecurrenceRule(i),
          );
        }
      } catch (e, s) {
        log.info(
          '[SystemCalendarSyncService][_writeEventsToCalendar] '
          'Write event failed: $e',
        );
        log.handle(e, s);
        return false;
      }
    }

    return true;
  }

  Future<bool> syncSystemCalendar({
    required bool requestPermissionsIfNeeded,
    required bool onlyIfCalendarExists,
    Future<void> Function()? showDialog,
  }) async {
    try {
      bool hasPermitted = await _ensureCalendarPermission(
        requestPermissionsIfNeeded: requestPermissionsIfNeeded,
        showDialog: showDialog,
      );
      if (!hasPermitted) {
        log.info(
          '[SystemCalendarSyncService][syncSystemCalendar] '
          'Calendar permission denied.',
        );
        return false;
      }

      String? calendarId = await _prepareCalendar(
        onlyIfCalendarExists: onlyIfCalendarExists,
      );
      if (calendarId == null || calendarId.isEmpty) {
        return false;
      }

      bool didWrite = await _writeEventsToCalendar(calendarId);
      if (didWrite) {
        await _saveCalendarSyncState(calendarId);
      }
      return didWrite;
    } catch (e, s) {
      log.handle(e, s);
      return false;
    }
  }
}

/// Auto sync only when the exported payload changed and the bound calendar
/// still exists.
Future<void> maybeAutoSyncSystemCalendar() async {
  try {
    final service = SystemCalendarSyncService();
    if (!service.canAutoSync) {
      return;
    }

    await service.syncSystemCalendar(
      requestPermissionsIfNeeded: false,
      onlyIfCalendarExists: true,
    );
  } catch (e, s) {
    log.handle(e, s);
  }
}
