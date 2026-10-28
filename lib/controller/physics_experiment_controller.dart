// Copyright 2026 Traintime PDA Authours, originally by BenderBlog Rodriguez.
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:intl/intl.dart';
import 'package:signals/signals_flutter.dart';
import 'package:time/time.dart';
import 'package:watermeter/controller/global_timer_controller.dart';
import 'package:watermeter/controller/semester_controller.dart';
import 'package:watermeter/model/fetch_result.dart';
import 'package:watermeter/model/home_arrangement.dart';
import 'package:watermeter/model/xidian_ids/experiment.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/preference.dart' as pref;
import 'package:watermeter/repository/experiment_session/physics_experiment_session.dart';
import 'package:watermeter/repository/demo_data/demo_data_mode.dart';
import 'package:watermeter/repository/demo_data/demo_fixtures_exam_experiment.dart';

class PhysicsExperimentController {
  final ExperimentSession session = ExperimentSession();
  static final PhysicsExperimentController i = PhysicsExperimentController._();

  PhysicsExperimentController._() {
    /// Load from cache at the beginning
    final cache = session.getCache();
    if (cache != null) {
      final cached = FetchResult.cache(fetchTime: cache.$1, data: cache.$2);
      _lastValidPhysicsExperiment.value = cached;
      physicsExperimentStateSignal.value = AsyncState.data(cached);
    }
    _initEffects();
  }

  final _lastValidPhysicsExperiment =
      signal<FetchResult<List<ExperimentData>>?>(null);
  final physicsExperimentStateSignal =
      signal<AsyncState<FetchResult<List<ExperimentData>>>>(
        const AsyncLoading(),
      );
  SemesterSyncEvent? _lastHandledSemesterSyncEvent;

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
        _lastValidPhysicsExperiment.value = null;
        unawaited(
          Future(() async {
            session.deleteCache();
            await pref.remove(pref.Preference.experimentPassword);
          }),
        );
        return;
      }
      unawaited(reloadPhysicsExperiment());
    }, options: EffectOptions(name: "PhysicsExperimentSemesterChangeEffect"));
  }

  Future<void> reloadPhysicsExperiment() async {
    // 演示数据
    if (DemoDataMode.enabled) {
      applyDemoFixture();
      return;
    }
    final previous = _lastValidPhysicsExperiment.value;
    physicsExperimentStateSignal.value = previous != null
        ? AsyncState.dataRefreshing(previous)
        : AsyncState.loading();
    try {
      final result = await session.getData();
      _lastValidPhysicsExperiment.value = result;
      physicsExperimentStateSignal.set(AsyncState.data(result), force: true);
    } catch (e, s) {
      physicsExperimentStateSignal.value = AsyncState.error(e, s);
      log.handle(
        e,
        s,
        "[PhysicsExperimentController][reloadPhysicsExperiment] Have issue",
      );
    }
  }

  /// 演示数据
  void applyDemoFixture() {
    final result = FetchResult.fresh(
      fetchTime: DateTime.now(),
      data: buildDemoPhysicsExperiments(),
    );
    _lastValidPhysicsExperiment.value = result;
    physicsExperimentStateSignal.set(AsyncState.data(result), force: true);
  }

  late final physicsExperiments = computed(
    () => _lastValidPhysicsExperiment.value?.data ?? <ExperimentData>[],
  );

  late final hasValidPhysicsExperiment = computed(
    () => _lastValidPhysicsExperiment.value != null,
  );

  late final isPhysicsExperimentFromCache = computed(
    () => _lastValidPhysicsExperiment.value?.isCache ?? false,
  );

  late final physicsExperimentFetchTime = computed<DateTime?>(
    () => _lastValidPhysicsExperiment.value?.fetchTime,
  );

  late final physicsExperimentCacheHintKey = computed<String?>(
    () => _lastValidPhysicsExperiment.value?.hintKey,
  );

  late final hasPhysicsExperimentArrangement = computed(
    () => physicsExperiments.value.isNotEmpty,
  );

  /// 指定日期的物理实验（桌面卡片多天窗口用，与今日/明日 computed 同口径）。
  List<HomeArrangement> physicsExperimentsOfDay(DateTime day) {
    final DateFormat formatter = DateFormat(HomeArrangement.format);
    final List<HomeArrangement> toReturn = [];

    for (var i = 0; i < physicsExperiments.value.length; i++) {
      final experiment = physicsExperiments.value[i];
      for (final timeRange in experiment.timeRanges) {
        if (!timeRange.$1.isAtSameDayAs(day)) continue;
        toReturn.add(
          HomeArrangement(
            name: experiment.name,
            place: experiment.classroom,
            teacher: experiment.teacher,
            colorIndex: i,
            type: '实验',
            startTimeStr: formatter.format(timeRange.$1),
            endTimeStr: formatter.format(timeRange.$2),
          ),
        );
      }
    }

    return toReturn;
  }

  late final physicsExperimentOfTodayComputedSignal = computed(
    () => physicsExperimentsOfDay(
      GlobalTimerController.i.currentTimeSignal.value,
    ),
  );

  late final physicsExperimentOfTomorrowComputedSignal = computed(
    () => physicsExperimentsOfDay(
      GlobalTimerController.i.currentTimeSignal.value.add(1.days),
    ),
  );

  late final isFinishedPhysicsExperimentComputedSignal = computed(() {
    final now = GlobalTimerController.i.currentTimeSignal.value.add(1.days);
    List<ExperimentData> toReturn = [];

    bool isQualified((DateTime, DateTime) timeRange) =>
        now.isAfter(timeRange.$2);

    for (var experiment in physicsExperiments.value) {
      bool containsDoing = experiment.timeRanges.where(isQualified).isNotEmpty;
      if (!containsDoing) continue;
      ExperimentData toAdd = ExperimentData.from(experiment);
      toAdd.timeRanges.removeWhere((timeRange) => !isQualified(timeRange));
      toReturn.add(toAdd);
    }

    return toReturn;
  });

  late final isNotStartedPhysicsExperimentComputedSignal = computed(() {
    final now = GlobalTimerController.i.currentTimeSignal.value.add(1.days);
    List<ExperimentData> toReturn = [];

    bool isQualified((DateTime, DateTime) timeRange) =>
        now.isBefore(timeRange.$1);

    for (var experiment in physicsExperiments.value) {
      bool containsDoing = experiment.timeRanges.where(isQualified).isNotEmpty;
      if (!containsDoing) continue;
      ExperimentData toAdd = ExperimentData.from(experiment);
      toAdd.timeRanges.removeWhere((timeRange) => !isQualified(timeRange));
      toReturn.add(toAdd);
    }

    return toReturn;
  });

  late final isDoingPhysicsExperimentComputedSignal = computed(() {
    final now = GlobalTimerController.i.currentTimeSignal.value.add(1.days);
    List<ExperimentData> toReturn = [];

    bool isQualified((DateTime, DateTime) timeRange) =>
        now.isAfter(timeRange.$1) && now.isBefore(timeRange.$2);

    for (var experiment in physicsExperiments.value) {
      bool containsDoing = experiment.timeRanges.where(isQualified).isNotEmpty;
      if (!containsDoing) continue;
      ExperimentData toAdd = ExperimentData.from(experiment);
      toAdd.timeRanges.removeWhere((timeRange) => !isQualified(timeRange));
      toReturn.add(toAdd);
    }

    return toReturn;
  });
}
