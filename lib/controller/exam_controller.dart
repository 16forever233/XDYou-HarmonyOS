// Copyright 2026 Traintime PDA Authours, originally by BenderBlog Rodriguez.
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:intl/intl.dart';
import 'package:signals/signals.dart';
import 'package:time/time.dart';
import 'package:watermeter/bridge/app_info.dart';
import 'package:watermeter/controller/global_timer_controller.dart';
import 'package:watermeter/controller/semester_controller.dart';
import 'package:watermeter/model/fetch_result.dart';
import 'package:watermeter/model/home_arrangement.dart';
import 'package:watermeter/model/xidian_ids/exam.dart';
import 'package:watermeter/repository/card_debug_store.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/ids_session/exam_session.dart';
import 'package:watermeter/repository/preference.dart';
import 'package:watermeter/repository/demo_data/demo_data_mode.dart';
import 'package:watermeter/repository/demo_data/demo_fixtures_exam_experiment.dart';

class ExamController {
  static final ExamController i = ExamController._();
  final session = ExamSession();

  ExamController._() {
    final cache = session.getCache();
    if (cache != null) {
      final cached = FetchResult.cache(fetchTime: cache.$1, data: cache.$2);
      _lastValidExamInfo.value = cached;
      examInfoStateSignal.value = AsyncState.data(cached);
    }
    refreshDebugSubjects();
    _initEffects();
  }

  final _lastValidExamInfo = signal<FetchResult<ExamData>?>(null);
  final examInfoStateSignal = signal<AsyncState<FetchResult<ExamData>>>(
    const AsyncLoading(),
  );
  SemesterSyncEvent? _lastHandledSemesterSyncEvent;

  /// 调试签名包注入的模拟考试（
  /// 注入后同时作用于应用内「考试安排」页与桌面卡片
  /// （`homepage_controller.arrangementsOfDay` → `examsOfDay`），两端同一口径。
  final _debugSubjects = signal<List<Subject>>(const <Subject>[]);

  /// 重新读取调试注入的模拟考试；调试页每次注入/清除后调用。
  void refreshDebugSubjects() {
    _debugSubjects.value = isDebugProvisioned
        ? CardDebugStore.load().map((e) => e.toSubject()).toList()
        : const <Subject>[];
  }

  /// 是否有调试注入的模拟考试（正式包恒为 false）。
  bool get hasDebugSubjects => _debugSubjects.value.isNotEmpty;

  void _initEffects() {
    effect(() {
      final semesterChangeEvent =
          SemesterController.i.semesterSyncEventSignal.value;
      if (semesterChangeEvent == null ||
          identical(semesterChangeEvent, _lastHandledSemesterSyncEvent)) {
        return;
      }

      _lastHandledSemesterSyncEvent = semesterChangeEvent;
      if (semesterChangeEvent.didChange) {
        _lastValidExamInfo.value = null;
        session.deleteCache();
      }
      unawaited(reloadExamInfo());
    }, options: EffectOptions(name: "ExamControllerSemesterChangeEffect"));
  }

  Future<void> reloadExamInfo() async {
    // 演示数据
    if (DemoDataMode.enabled) {
      applyDemoFixture();
      return;
    }
    final previous = _lastValidExamInfo.value;
    examInfoStateSignal.value = previous != null
        ? AsyncState.dataRefreshing(previous)
        : AsyncState.loading();
    try {
      final result = await session.getScoreInfo(
        SemesterController.i.semesterSignal.value,
        getUserRole(),
      );
      _lastValidExamInfo.value = result;
      examInfoStateSignal.set(AsyncState.data(result), force: true);
    } catch (e, s) {
      examInfoStateSignal.value = AsyncState.error(e, s);
      log.handle(e, s, "[ExamController][reloadExamInfo] Have issue");
    }
  }

  /// 演示数据
  void applyDemoFixture() {
    final result = FetchResult.fresh(
      fetchTime: DateTime.now(),
      data: buildDemoExamData(),
    );
    _lastValidExamInfo.value = result;
    examInfoStateSignal.set(AsyncState.data(result), force: true);
  }

  late final subjects = computed(
    () => <Subject>[
      ...?_lastValidExamInfo.value?.data.subject,
      ..._debugSubjects.value,
    ],
  );

  late final toBeArranged = computed(
    () => _lastValidExamInfo.value?.data.toBeArranged ?? <ToBeArranged>[],
  );

  /// 有可展示的考试信息
  late final hasValidExamInfo = computed(
    () => _lastValidExamInfo.value != null || _debugSubjects.value.isNotEmpty,
  );

  late final isExamFromCache = computed(
    () => _lastValidExamInfo.value?.isCache ?? false,
  );

  late final examFetchTime = computed<DateTime?>(
    () => _lastValidExamInfo.value?.fetchTime,
  );

  late final examCacheHintKey = computed<String?>(
    () => _lastValidExamInfo.value?.hintKey,
  );

  late final hasExamArrangement = computed(
    () => subjects.value.isNotEmpty || toBeArranged.value.isNotEmpty,
  );

  late final isDisQualified = computed(() {
    return subjects.value
        .where((e) => e.startTime == null || e.stopTime == null)
        .toList();
  });

  late final isFinished = computed(() {
    final now = GlobalTimerController.i.currentTimeSignal.value;
    return subjects.value.where((e) {
      if (e.startTime == null) return false;
      return !e.startTime!.isAfter(now);
    }).toList();
  });

  late final isNotFinished = computed(() {
    final now = GlobalTimerController.i.currentTimeSignal.value;

    final list = subjects.value.where((e) {
      if (e.startTime == null) return false;
      return e.startTime!.isAfter(now);
    }).toList();

    return list..sort((a, b) => a.startTime!.compareTo(b.startTime!));
  });

  /// 指定日期的考试
  List<HomeArrangement> examsOfDay(DateTime day) {
    final formatter = DateFormat(HomeArrangement.format);

    return subjects.value
        .asMap()
        .entries
        .where((entry) => entry.value.startTime?.isAtSameDayAs(day) ?? false)
        .map(
          (entry) => HomeArrangement(
            // 科目名本身已带「考试」时不再重复拼接（调试注入的模拟考试名为
            // 「【测试】模拟考试」，否则会变成「【测试】模拟考试考试」）。
            name: entry.value.subject.endsWith("考试")
                ? entry.value.subject
                : "${entry.value.subject}考试",
            place: entry.value.place,
            seat: entry.value.seat,
            colorIndex: entry.key,
            type: '考试',
            startTimeStr: entry.value.startTime != null
                ? formatter.format(entry.value.startTime!)
                : entry.value.startTimeStr,
            endTimeStr: entry.value.stopTime != null
                ? formatter.format(entry.value.stopTime!)
                : entry.value.endTimeStr,
          ),
        )
        .toList();
  }

  late final todayExams = computed<List<HomeArrangement>>(
    () => examsOfDay(GlobalTimerController.i.currentTimeSignal.value),
  );

  late final tomorrowExams = computed<List<HomeArrangement>>(
    () => examsOfDay(
      GlobalTimerController.i.currentTimeSignal.value.add(
        const Duration(days: 1),
      ),
    ),
  );
}
