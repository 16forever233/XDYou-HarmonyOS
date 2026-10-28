// Copyright 2026 Traintime PDA Authours, originally by BenderBlog Rodriguez.
// SPDX-License-Identifier: MPL-2.0

import 'dart:async';

import 'package:intl/intl.dart' show DateFormat;
import 'package:signals/signals.dart';
import 'package:watermeter/controller/classtable_controller.dart';
import 'package:watermeter/controller/custom_class_controller.dart';
import 'package:watermeter/controller/energy_controller.dart';
import 'package:watermeter/controller/exam_controller.dart';
import 'package:watermeter/controller/global_timer_controller.dart';
import 'package:watermeter/controller/library_controller.dart';
import 'package:watermeter/controller/other_experiment_controller.dart';
import 'package:watermeter/controller/physics_experiment_controller.dart';
import 'package:watermeter/controller/school_card_controller.dart';
import 'package:watermeter/controller/semester_controller.dart';
import 'package:watermeter/controller/week_swift_controller.dart';
import 'package:watermeter/model/home_arrangement.dart';
import 'package:watermeter/model/password_exceptions.dart';
import 'package:watermeter/repository/ids_session/ids_reauth_client.dart';
import 'package:watermeter/repository/ids_session/ids_session.dart';
import 'package:watermeter/repository/logger.dart';
import 'package:watermeter/repository/notification/course_reminder_service.dart';
import 'package:watermeter/repository/preference.dart' as preference;
import 'package:watermeter/repository/desktop_card_sync_service.dart';
import 'package:watermeter/repository/system_calendar_sync_service.dart';
import 'package:watermeter/repository/widget_state_sync.dart';
import 'package:watermeter/repository/demo_data/demo_data_mode.dart';
import 'package:watermeter/repository/demo_data/demo_data_service.dart';

enum ArrangementState { fetching, fetched, error, none }

enum HomepageSourceState { loading, success, error, ignored, none }

enum HomepageFailedSource {
  classInfo,
  examInfo,
  physicsExperiment,
  otherExperiment,
}

class HomepageController {
  static final HomepageController i = HomepageController._();

  HomepageController._() {
    GlobalTimerController.i;
    SemesterController.i;
    WeekSwiftController.i;
    ClassTableController.i;
    ExamController.i;
    OtherExperimentController.i;
    PhysicsExperimentController.i;
    // 桌面卡片：课表/考试等数据加载完成后自动同步一次。
    // 登录/启动时的 syncDesktopCard 可能早于数据加载完成（写入空数据），
    // 这里用数据指纹节流，数据真正变化时才重新同步，避免每分钟 tick 频繁写盘。
    // 注意：
    // 1. effect 内异常会向外抛出（可能中断启动），必须兜底；
    // 2. computed 求值与 syncDesktopCard 都是主线程重活，全部延迟到
    //    事件队列（微任务）执行，避免冷启动期叠加导致 THREAD_BLOCK_6S。
    effect(() {
      // 注意：信号必须在 effect 的同步体里读取，依赖才会被登记。
      // 曾经把这两次读取放进下面的 scheduleMicrotask 里，结果 effect 一个依赖都没有、
      // 只在创建时跑了一次 —— 首个安装/首启时它是「课表还没拉到」的那一刻执行的，
      // 写进卡片的就是空窗口，之后课表数据到位、甚至登录完成都不会再写，
      // 卡片于是一直显示「暂无课程」，要重启 App（本地已有 ClassTable.json 缓存、
      // 启动时数据就绪）才恢复正常。数据到位后由下面的指纹比较触发重新写入。
      final today = todayArrangementComputedSignal.value;
      final tomorrow = tomorrowArrangementComputedSignal.value;
      final fp = _arrangementFingerprint(today, tomorrow);
      if (fp == _lastCardFingerprint) {
        return;
      }
      _lastCardFingerprint = fp;
      // 真正的重活（7 天窗口聚合 + 写 prefs + MethodChannel 调用 + 卡片推送）
      // 仍然延迟到事件队列，避免冷启动期叠加导致 THREAD_BLOCK_6S。
      scheduleMicrotask(() {
        try {
          unawaited(syncDesktopCard());
        } catch (e, s) {
          log.warning(
            '[HomepageController] desktop card sync effect failed.',
            e,
            s,
          );
        }
      });
    });
  }

  String? _lastCardFingerprint;

  static String _arrangementFingerprint(
    List<HomeArrangement> today,
    List<HomeArrangement> tomorrow,
  ) {
    String fp(List<HomeArrangement> list) => list
        .map((e) => '${e.startTime.millisecondsSinceEpoch}:${e.name}:${e.type}')
        .join('|');
    return '${fp(today)}#${fp(tomorrow)}';
  }

  Future<void> _comboLogin({
    required Future<void> Function(String) sliderCaptcha,
  }) async {
    if (loginState == IDSLoginState.requesting) {
      return;
    }
    loginState = IDSLoginState.requesting;

    try {
      await IDSSession().checkAndLogin(
        target:
            "https://ehall.xidian.edu.cn/login?service="
            "https://ehall.xidian.edu.cn/new/index.html",
        sliderCaptcha: sliderCaptcha,
      );
      loginState = IDSLoginState.success;
      unawaited(syncDesktopCard());
    } on PasswordWrongException {
      loginState = IDSLoginState.passwordWrong;
      log.warning(
        "[HomepageController][_comboLogin] "
        "Combo login failed because the password is wrong.",
      );
    } on IDSReAuthCancelledException {
      loginState = IDSLoginState.cancelled;
      log.info(
        '[HomepageController][_comboLogin] '
        'Additional verification was cancelled by the user.',
      );
    } catch (e, s) {
      loginState = IDSLoginState.fail;
      log.warning(
        "[HomepageController][_comboLogin] Combo login failed.",
        e,
        s,
      );
    }
  }

  Future<void> _safeReload(
    String name,
    Future<void> Function() callback,
  ) async {
    try {
      await callback();
    } catch (e, s) {
      log.handle(e, s, "[HomepageController][$name] Have issue");
    }
  }

  Future<void> refresh({
    bool forceRetryLogin = false,
    required Future<void> Function(String) sliderCaptcha,
  }) async {
    // 演示数据
    if (DemoDataMode.enabled) {
      DemoDataModeService.refreshAll();
      return;
    }

    if (forceRetryLogin || loginState == IDSLoginState.fail) {
      await _comboLogin(sliderCaptcha: sliderCaptcha);
    }

    await _safeReload("Semester", SemesterController.i.refreshSemesterInfo);

    await Future.wait([
      _safeReload("Classtable", ClassTableController.i.reloadClassTable),
      _safeReload("Exam", ExamController.i.reloadExamInfo),
      _safeReload(
        "PhysicsExperiment",
        PhysicsExperimentController.i.reloadPhysicsExperiment,
      ),
      _safeReload(
        "OtherExperiment",
        OtherExperimentController.i.reloadOtherExperiment,
      ),
      _safeReload("Library", LibraryController.i.reloadBorrowList),
      _safeReload("SchoolCard", SchoolCardController.i.reloadOverview),
      _safeReload("Electricity", EnergyController.i.refreshElectricityInfo),
    ]);
    await maybeAutoSyncSystemCalendar();

    final reminderService = CourseReminderService();
    if (reminderService.isInitialized) {
      reminderService.validateAndUpdateNotifications();
    } else {
      await reminderService.initialize();
      reminderService.validateAndUpdateNotifications();
    }

    final hasCredential =
        preference.getString(preference.Preference.idsAccount).isNotEmpty &&
        preference.getString(preference.Preference.idsPassword).isNotEmpty;
    await syncWidgetLoginState(hasCredential);
  }

  List<HomeArrangement> _sortArrangements(Iterable<HomeArrangement> data) {
    return data.toList()..sort();
  }

  bool _isEffectiveLoading(HomepageSourceState state) =>
      state == HomepageSourceState.loading;

  bool _isRealError(HomepageSourceState state) =>
      state == HomepageSourceState.error;

  /// 指定日期的自定义日程。
  List<HomeArrangement> customClassesOfDay(DateTime day) {
    final formatter = DateFormat(HomeArrangement.format);
    final result = <HomeArrangement>[];
    for (final cc in CustomClassController.i.customClassesSignal.value) {
      for (final tr in cc.timeRanges) {
        if (tr.startTime.year == day.year &&
            tr.startTime.month == day.month &&
            tr.startTime.day == day.day) {
          result.add(
            HomeArrangement(
              name: cc.name,
              teacher: cc.teacher,
              place: cc.classroom,
              startTimeStr: formatter.format(tr.startTime),
              endTimeStr: formatter.format(tr.endTime),
              type: '自定义',
            ),
          );
        }
      }
    }
    return result;
  }

  /// 指定日期的全部日程（课程 / 自定义 / 考试 / 实验），按开始时间排序。
  /// 首页今日/明日卡片与鸿蒙桌面卡片的多天窗口共用这一口径。
  List<HomeArrangement> arrangementsOfDay(DateTime day) => _sortArrangements([
    ...ClassTableController.i.getArrangementOfDay(day),
    ...customClassesOfDay(day),
    ...ExamController.i.examsOfDay(day),
    ...PhysicsExperimentController.i.physicsExperimentsOfDay(day),
    ...OtherExperimentController.i.otherExperimentsOfDay(day),
  ]);

  late final updateTimeComputedSignal = computed<DateTime>(
    () => GlobalTimerController.i.currentTimeSignal.value,
  );

  late final classTableSourceStateComputedSignal =
      computed<HomepageSourceState>(() {
        final state = ClassTableController.i.schoolClassTableStateSignal.value;
        if (state.isLoading) {
          return HomepageSourceState.loading;
        }
        if (ClassTableController.i.hasValidClassInfo.value) {
          return HomepageSourceState.success;
        }
        if (state is AsyncError) {
          return HomepageSourceState.error;
        }
        return HomepageSourceState.none;
      });

  late final examSourceStateComputedSignal = computed<HomepageSourceState>(() {
    final state = ExamController.i.examInfoStateSignal.value;
    if (state.isLoading) {
      return HomepageSourceState.loading;
    }
    if (ExamController.i.hasValidExamInfo.value) {
      return HomepageSourceState.success;
    }
    if (state is AsyncError) {
      return HomepageSourceState.error;
    }
    return HomepageSourceState.none;
  });

  late final physicsExperimentSourceStateComputedSignal =
      computed<HomepageSourceState>(() {
        final state =
            PhysicsExperimentController.i.physicsExperimentStateSignal.value;
        if (state.isLoading) {
          return HomepageSourceState.loading;
        }
        if (PhysicsExperimentController.i.hasValidPhysicsExperiment.value) {
          return HomepageSourceState.success;
        }
        if (state is AsyncError) {
          final error = state.error;
          if (error is NoPasswordException &&
              error.type == PasswordType.physicsExperiment) {
            return HomepageSourceState.ignored;
          }
          return HomepageSourceState.error;
        }
        return HomepageSourceState.none;
      });

  late final otherExperimentSourceStateComputedSignal =
      computed<HomepageSourceState>(() {
        final state =
            OtherExperimentController.i.otherExperimentStateSignal.value;
        if (state.isLoading) {
          return HomepageSourceState.loading;
        }
        if (OtherExperimentController.i.hasValidOtherExperiment.value) {
          return HomepageSourceState.success;
        }
        if (state is AsyncError) {
          return HomepageSourceState.error;
        }
        return HomepageSourceState.none;
      });

  late final _sourceStatesComputedSignal = computed<List<HomepageSourceState>>(
    () => [
      classTableSourceStateComputedSignal.value,
      examSourceStateComputedSignal.value,
      physicsExperimentSourceStateComputedSignal.value,
      otherExperimentSourceStateComputedSignal.value,
    ],
  );

  late final isTomorrowComputedSignal = computed<bool>(() {
    final updateTime = GlobalTimerController.i.currentTimeSignal.value;
    return updateTime.hour * 60 + updateTime.minute > 21 * 60 + 25;
  });

  late final todayArrangementComputedSignal = computed<List<HomeArrangement>>(
    () => arrangementsOfDay(GlobalTimerController.i.currentTimeSignal.value),
  );

  late final tomorrowArrangementComputedSignal =
      computed<List<HomeArrangement>>(
        () => arrangementsOfDay(
          GlobalTimerController.i.currentTimeSignal.value.add(
            const Duration(days: 1),
          ),
        ),
      );

  late final arrangementComputedSignal = computed<List<HomeArrangement>>(() {
    // 演示数据
    final updateTime = DemoDataMode.awareNow(
      updateTimeComputedSignal.value,
    );
    final isTomorrow = isTomorrowComputedSignal.value;

    if (isTomorrow) {
      final items = tomorrowArrangementComputedSignal.value;
      // 演示态裁剪条数
      return DemoDataMode.enabled
          ? DemoDataMode.limitTodayItems(items)
          : items;
    }

    final items = _sortArrangements(
      todayArrangementComputedSignal.value.where(
        (element) => updateTime.isBefore(element.endTime),
      ),
    );
    return DemoDataMode.enabled
        ? DemoDataMode.limitTodayItems(items)
        : items;
  });

  late final hasArrangementComputedSignal = computed<bool>(
    () => arrangementComputedSignal.value.isNotEmpty,
  );

  late final arrangementStateComputedSignal = computed<ArrangementState>(() {
    final sourceStates = _sourceStatesComputedSignal.value;

    if (classTableSourceStateComputedSignal.value ==
        HomepageSourceState.success) {
      return ArrangementState.fetched;
    }

    if (sourceStates.any(_isEffectiveLoading)) {
      return ArrangementState.fetching;
    }

    if (sourceStates.any(_isRealError)) {
      return ArrangementState.error;
    }

    return ArrangementState.none;
  });

  late final homepageArrangementStateComputedSignal =
      computed<ArrangementState>(() => arrangementStateComputedSignal.value);

  late final isAllSourcesLoadingComputedSignal = computed<bool>(
    () => _sourceStatesComputedSignal.value.every(_isEffectiveLoading),
  );

  late final isPartialSourcesLoadingComputedSignal = computed<bool>(() {
    final sourceStates = _sourceStatesComputedSignal.value;
    return sourceStates.any(_isEffectiveLoading) &&
        !sourceStates.every(_isEffectiveLoading);
  });

  late final failedSourcesComputedSignal = computed<List<HomepageFailedSource>>(
    () {
      final failedSources = <HomepageFailedSource>[];

      if (classTableSourceStateComputedSignal.value ==
          HomepageSourceState.error) {
        failedSources.add(HomepageFailedSource.classInfo);
      }
      if (examSourceStateComputedSignal.value == HomepageSourceState.error) {
        failedSources.add(HomepageFailedSource.examInfo);
      }
      if (physicsExperimentSourceStateComputedSignal.value ==
          HomepageSourceState.error) {
        failedSources.add(HomepageFailedSource.physicsExperiment);
      }
      if (otherExperimentSourceStateComputedSignal.value ==
          HomepageSourceState.error) {
        failedSources.add(HomepageFailedSource.otherExperiment);
      }

      return failedSources;
    },
  );

  late final havePhysicsExperimentSignal = computed<bool>(
    () => ClassTableController.i.havePhysicsExperimentSignal.value,
  );

  final isPostGraduate = preference.getBool(preference.Preference.role);
}
