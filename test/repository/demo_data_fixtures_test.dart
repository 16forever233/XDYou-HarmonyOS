// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:watermeter/model/home_arrangement.dart';
import 'package:watermeter/model/time_list.dart';
import 'package:watermeter/repository/demo_data/demo_data_mode.dart';
import 'package:watermeter/repository/demo_data/demo_fixtures_campus_life.dart';
import 'package:watermeter/repository/demo_data/demo_fixtures_exam_experiment.dart';
import 'package:watermeter/repository/demo_data/demo_fixtures_ruisi.dart';
import 'package:watermeter/repository/demo_data/demo_fixtures_timetable.dart';

/// 演示数据 fixture 的健全性测试。
///
/// 目的：这些假数据只在"开启演示数据"后才构造，一旦构造时抛异常
/// （例如自定义课程时间越界、课表数据断言失败、考试时间正则不匹配），
/// 界面就会停在启动页/报错页。所以这里把每个 fixture 都真实构造一遍并检查约束。
void main() {
  test('课表 fixture 能构造，且今天有课、每个课次都合法', () {
    final table = buildDemoClassTable();

    expect(table.semesterLength, greaterThan(0));
    expect(table.semesterCode, isNotEmpty);
    expect(table.termStartDay, isNotEmpty, reason: '有课次时必须给学期开始日');
    expect(table.classDetail, isNotEmpty);
    expect(table.timeArrangement, isNotEmpty);

    final maxSlot = timeList.length ~/ 2;
    for (final arrangement in table.timeArrangement) {
      expect(arrangement.index, lessThan(table.classDetail.length));
      expect(arrangement.start, greaterThanOrEqualTo(1));
      expect(arrangement.stop, lessThanOrEqualTo(maxSlot));
      expect(arrangement.start, lessThanOrEqualTo(arrangement.stop));
      expect(arrangement.weekList.length, table.semesterLength);
      expect(arrangement.classroom, isNotNull);
    }

    // 每个工作日都要有课（周末没有，与真实课表一致）
    for (final day in [1, 2, 3, 4, 5]) {
      expect(
        table.timeArrangement.any((e) => e.day == day),
        isTrue,
        reason: '星期$day 应该有课',
      );
    }
  });

  test('自定义课程 / 考试 / 实验 fixture 能构造且时间合法', () {
    final customClasses = buildDemoCustomClasses();
    expect(customClasses, isNotEmpty);
    for (final customClass in customClasses) {
      for (final range in customClass.timeRanges) {
        // 模型自身会校验 08:30-21:25、不跨天、start < end，这里显式再确认一次
        expect(range.startTime.isBefore(range.endTime), isTrue);
        expect(range.startTime.day, range.endTime.day);
        expect(range.startTime.hour * 60 + range.startTime.minute,
            greaterThanOrEqualTo(8 * 60 + 30));
        expect(range.endTime.hour * 60 + range.endTime.minute,
            lessThanOrEqualTo(21 * 60 + 25));
      }
    }

    final exams = buildDemoExamData();
    expect(exams.subject, isNotEmpty);
    for (final subject in exams.subject) {
      expect(subject.startTime, isNotNull, reason: '考试时间必须能被正则解析');
      expect(subject.stopTime, isNotNull);
      expect(subject.seat, isNotNull);
      expect(subject.startTime!.isBefore(subject.stopTime!), isTrue);
      // 今天必须有一场考试（首页今日日程里要能看到）
      final now = DateTime.now();
      expect(
        exams.subject.any((e) => e.startTime!.day == now.day),
        isTrue,
        reason: '今天应该有一场考试',
      );
    }

    expect(buildDemoPhysicsExperiments(), isNotEmpty);
    expect(buildDemoOtherExperiments(), isNotEmpty);
  });

  test('电量 / 图书馆 fixture 能构造', () {
    final energy = buildDemoEnergyInfo();
    expect(energy.electricityMeterList, isNotEmpty);
    expect(energy.electricityRemain, greaterThan(0));
    expect(buildDemoElectricityHistory().length, 12);
    expect(buildDemoBorrowList(), isNotEmpty);

    // 校园卡演示余额：非空且可被解析（卡片端用 double.parse 判断是否显示金额）
    expect(demoSchoolCardBalance, isNotEmpty);
    expect(double.tryParse(demoSchoolCardBalance), isNotNull);
  });

  test('睿思 fixture 能构造，列表与详情一致、且不放图', () {    final groups = DemoRuisiFixtures.forumGroups();
    expect(groups, isNotEmpty);
    expect(groups.first.forums, isNotEmpty);

    final newTopics = DemoRuisiFixtures.newTopics();
    expect(newTopics, isNotEmpty);
    expect(DemoRuisiFixtures.newReplyTopics(), isNotEmpty);

    // 首页 7 个页签对应的 fid 都要有内容
    for (final fid in [72, 142, 110, 561, 553]) {
      expect(
        DemoRuisiFixtures.topicsOf(fid),
        isNotEmpty,
        reason: '板块 $fid 必须有演示帖子',
      );
    }

    final topic = newTopics.first;
    final detail = DemoRuisiFixtures.topicDetail(topic.tid);
    expect(detail.tid, topic.tid);
    expect(detail.title, topic.title);
    expect(detail.posts.length, greaterThan(3));
    expect(detail.posts.first.content, isNotEmpty);
    // 演示态不放图，避免网络图裂图
    expect(detail.posts.every((p) => p.images.isEmpty), isTrue);
    expect(newTopics.every((t) => t.isImage == false), isTrue);
  });

  test('演示日程裁剪：条数不超上限，且优先保留不同类型', () {
    HomeArrangement item(String type, String name, int hour) =>
        HomeArrangement(
          type: type,
          name: name,
          startTimeStr:
              '2026-09-11 ${hour.toString().padLeft(2, '0')}:00:00',
          endTimeStr:
              '2026-09-11 ${hour.toString().padLeft(2, '0')}:45:00',
        );

    final items = [
      item('课程', '高等数学（下）', 10),
      item('课程', '大学物理', 11),
      item('课程', '大学英语', 13),
      item('考试', '高等数学（下）考试', 14),
      item('实验', '示波器的使用', 15),
      item('自定义', '实验室安全培训', 18),
    ];

    final limited = DemoDataMode.limitTodayItems(items);
    expect(limited.length, DemoDataMode.todayItemLimit);
    // 优先保留不同类型：裁剪后的类型数应与条数一致（前几条类型互不相同）
    expect(
      limited.map((e) => e.type).toSet().length,
      DemoDataMode.todayItemLimit,
    );
    // 结果按时间排序
    for (var i = 1; i < limited.length; i++) {
      expect(
        limited[i - 1].startTime.isAfter(limited[i].startTime),
        isFalse,
      );
    }

    // 已经不超过上限时原样返回
    final few = items.take(2).toList();
    expect(identical(DemoDataMode.limitTodayItems(few), few), isTrue);
  });
}
