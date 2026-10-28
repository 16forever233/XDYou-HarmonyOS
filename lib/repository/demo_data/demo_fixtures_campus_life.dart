// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:watermeter/model/xidian_ids/energy.dart';
import 'package:watermeter/model/xidian_ids/library.dart';

/// 演示用宿舍水电 / 图书馆借阅（**全部虚构**）。
///
/// 只服务首页那两张"大卡片"（电量卡、图书馆卡）：卡片本身只显示数值与书名，
/// 不含宿舍号、真实借阅记录等个人信息，因此这里也不需要伪造任何身份字段。

/// 演示用校园卡**余额**（虚构，只用于首页「流水」卡上的那一行数值）。
///
/// 设计取舍：**只造"余额"这一个展示数值**，不伪造一卡通流水明细、也不伪造支付码。
/// 旧做法是演示态把这张卡整张隐藏；为了让宣传图里的首页信息更完整，改为显示虚构
/// 余额，但点进一卡通页仍会提示「演示数据不含一卡通流水与支付码」
///（见 `SchoolCardInfoCard` 的演示态守卫）。
///
/// 数值格式与真实接口一致（`String`，可带小数）：卡片端 >=10 元会取整显示。
const String demoSchoolCardBalance = '36.50';

DateTime _dayOffset(int days) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.add(Duration(days: days));
}

/// 演示宿舍电量信息（当前余量 + 最近抄表记录）。
EnergyInfo buildDemoEnergyInfo() {
  return EnergyInfo(
    lastReadDate: _dayOffset(-1),
    electricityRemain: 126.5,
    electricityMeterList: [
      MeterInfo(
        ReadTime: _dayOffset(-1),
        ReadNum: 1873.5,
        StartNum: 1700.0,
        EndNum: 1873.5,
      ),
      MeterInfo(
        ReadTime: _dayOffset(-8),
        ReadNum: 1798.0,
        StartNum: 1700.0,
        EndNum: 1798.0,
      ),
      MeterInfo(
        ReadTime: _dayOffset(-15),
        ReadNum: 1746.5,
        StartNum: 1700.0,
        EndNum: 1746.5,
      ),
    ],
    waterMeterList: [
      MeterInfo(
        ReadTime: _dayOffset(-1),
        ReadNum: 412.8,
        StartNum: 380.0,
        EndNum: 412.8,
      ),
      MeterInfo(
        ReadTime: _dayOffset(-15),
        ReadNum: 396.2,
        StartNum: 380.0,
        EndNum: 396.2,
      ),
    ],
  );
}

/// 演示电量历史（近 12 个月，用于电量曲线）。
List<ElectricityHistoryInfo> buildDemoElectricityHistory() {
  final now = DateTime.now();
  return [
    for (var i = 11; i >= 0; i--)
      ElectricityHistoryInfo(
        // `DateTime` 会自动归一化负数月份，这里就是"往前 i 个月的 1 号"
        fetchDay: DateTime(now.year, now.month - i, 1),
        remain: (48 + ((i * 7) % 23) * 4.6).toStringAsFixed(1),
      ),
  ];
}

/// 演示图书馆借阅（5 本虚构在借图书：书名/作者/出版社都是真实出版物，
/// 借阅人信息一律不涉及）。
List<BorrowData> buildDemoBorrowList() {
  final entries = <(String, String, String, String)>[
    ("高等数学（下册）", "同济大学数学系", "高等教育出版社", "9787040396614"),
    ("大学物理学（第三册）", "张三慧", "清华大学出版社", "9787302303039"),
    ("算法导论（第 3 版）", "Thomas H. Cormen", "机械工业出版社", "9787111407010"),
    ("C 程序设计语言", "Brian W. Kernighan", "机械工业出版社", "9787111128069"),
    ("中国现代文学史", "钱理群", "北京大学出版社", "9787301251492"),
  ];

  return [
    for (var i = 0; i < entries.length; i++)
      BorrowData(
        locationId: 10 + i,
        loanId: 20260001 + i,
        renewTimes: i % 2,
        recallTimes: 0,
        loanDate: _fmt(_dayOffset(-21 + i * 2)),
        renewDate: i % 2 == 1 ? _fmt(_dayOffset(-7)) : null,
        normReturnDate: _fmt(_dayOffset(20 - i * 2)),
        returnDate: null,
        loanType: "普通外借",
        locationName: "南校区图书馆",
        curLibCode: "XDU",
        curLibName: "西安电子科技大学图书馆",
        loanDeskName: "自助借还机",
        title: entries[i].$1,
        author: entries[i].$2,
        publisher: entries[i].$3,
        isbn: entries[i].$4,
        isbn10: "",
        isbn13: entries[i].$4,
        publishYear: "2019",
        titles: entries[i].$1,
        propNo: "P${20260000 + i}",
        recordId: 90000 + i,
        imageUrl: null,
      ),
  ];
}

String _fmt(DateTime date) =>
    "${date.year}-${date.month.toString().padLeft(2, '0')}-"
    "${date.day.toString().padLeft(2, '0')}";
