// Copyright 2026 XDYou HarmonyOS port authors.
// SPDX-License-Identifier: MPL-2.0

import 'package:watermeter/external/ruisi_flutter/lib/models/forum.dart';
import 'package:watermeter/external/ruisi_flutter/lib/models/post.dart';
import 'package:watermeter/external/ruisi_flutter/lib/models/topic.dart';

/// 演示用睿思数据（**全部虚构**：板块名沿用校内真实分区，帖子标题/作者/内容都是编的）。
///
/// 结构：一张总表 [_topics]，其余接口按 fid / 时间派生 ——
/// 这样"列表里点进去看到的帖子"与列表本身永远一致。
abstract final class DemoRuisiFixtures {
  /// 板块分组（fid 与真实分区一致，保证首页 7 个 tab 都能取到内容）。
  static List<ForumGroup> forumGroups() => [
    ForumGroup(
      fgId: 1,
      name: "校园生活",
      forums: [
        Forum(fid: 72, name: "校园闲聊", todayPosts: 128, totalPosts: 86432,
            description: "聊聊校园里的日常", ),
        Forum(fid: 142, name: "失物招领", todayPosts: 9, totalPosts: 5127,
            description: "丢了东西、捡到东西都发这里", ),
        Forum(fid: 110, name: "跳蚤市场", todayPosts: 34, totalPosts: 20318,
            description: "二手交易，校内自提", ),
      ],
    ),
    ForumGroup(
      fgId: 2,
      name: "学习交流",
      forums: [
        Forum(fid: 561, name: "摄影天地", todayPosts: 22, totalPosts: 12094,
            description: "记录校园的光影", ),
        Forum(fid: 553, name: "求职就业", todayPosts: 41, totalPosts: 33980,
            description: "实习、秋招、考研交流", ),
        Forum(fid: 300, name: "课程交流", todayPosts: 57, totalPosts: 41260,
            description: "选课、作业、考试经验", ),
      ],
    ),
    ForumGroup(
      fgId: 3,
      name: "站务管理",
      forums: [
        Forum(fid: 1, name: "站务公告", todayPosts: 1, totalPosts: 1062,
            description: "睿思站务与公告", ),
        Forum(fid: 2, name: "意见建议", todayPosts: 3, totalPosts: 4488,
            description: "对睿思的建议", ),
      ],
    ),
  ];

  /// 新帖（各板块交叉取前几条，读起来像真实的"新帖"流）。
  static List<Topic> newTopics() {
    final buckets = _fids.map(topicsOf).toList();
    final result = <Topic>[];
    for (var round = 0; round < 4; round++) {
      for (final bucket in buckets) {
        if (round < bucket.length) {
          result.add(bucket[round]);
        }
      }
    }
    return result;
  }

  /// 新回复（按回复数倒序取前 10 条，等价于"最热的讨论"）。
  static List<Topic> newReplyTopics() {
    final sorted = [..._topics]..sort((a, b) => b.replies.compareTo(a.replies));
    return sorted.take(10).map((e) => _toTopic(e)).toList();
  }

  /// 某个板块的帖子列表；没有内容的板块给空列表（不会出现假数据串板块）。
  static List<Topic> topicsOf(int fid) =>
      _topics.where((e) => e.fid == fid).map(_toTopic).toList();

  /// 帖子详情：主楼用 [_DemoTopic.body]，楼层用统一的回复池生成，
  /// 保证任何一条帖子点进去都有 6~7 楼、可翻页。
  static TopicDetail topicDetail(int tid) {
    final source = _topics.firstWhere(
      (e) => e.tid == tid,
      orElse: () => _topics.first,
    );
    final posts = <Post>[
      Post(
        pid: source.tid * 10,
        tid: source.tid,
        authorId: source.authorId,
        author: source.author,
        time: source.time,
        content: source.body,
        index: 0,
      ),
      for (var i = 0; i < _replyPool.length; i++)
        Post(
          pid: source.tid * 10 + i + 1,
          tid: source.tid,
          authorId: 30000 + i * 37,
          author: _replyPool[i].$1,
          time: _replyPool[i].$3,
          content: i == 2
              ? "回复 2 楼：${_replyPool[i].$2}"
              : _replyPool[i].$2,
          isQuote: i == 2,
          index: i + 1,
        ),
    ];

    return TopicDetail(
      tid: source.tid,
      fid: source.fid,
      title: source.title,
      author: source.author,
      authorId: source.authorId,
      time: source.time,
      replies: _replyPool.length,
      posts: posts,
      currentPage: 1,
      totalPages: 2,
    );
  }

  /// 演示态一律不放图（网络图会裂图）：列表用纯文字卡片，详情不带附件
  static Topic _toTopic(_DemoTopic source) => Topic(
    tid: source.tid,
    fid: source.fid,
    title: source.title,
    author: source.author,
    authorId: source.authorId,
    views: source.views,
    replies: source.replies,
    postTime: source.time,
    lastReplyTime: source.recency,
    isStick: source.isStick,
    isImage: false,
    imageUrl: null,
    categoryName: source.category,
  );

  /// 首页 7 个 tab 对应的板块（新帖 / 新回复两个 tab 由上面两个方法给出）。
  static const List<int> _fids = [72, 142, 110, 561, 553];

  /// 统一的回复池（作者、内容、时间）。
  static const List<(String, String, String)> _replyPool = [
    ("李响", "同问，蹲一个答案～", "12 分钟前"),
    ("王雨", "我上周刚去过，感觉还不错，推荐试试！", "1 小时前"),
    ("赵辰", "楼上说得有道理，补充一点：最好早点去，晚了人多。", "2 小时前"),
    ("钱屿", "感谢分享，收藏了。", "今天 10:24"),
    ("孙禾", "帮顶，我也遇到同样的问题。", "今天 09:41"),
    ("周然", "已经私信你了，麻烦看下～", "昨天 21:08"),
    ("吴桐", "路过帮顶，祝早日解决。", "昨天 19:33"),
  ];

  /// 总表：tid 唯一、fid 对应上面的板块；order 越小越"新"。
  static const List<_DemoTopic> _topics = [
    // ---- 校园闲聊 fid 72 ----
    _DemoTopic(900001, 72, "食堂三楼新开的窗口有人吃过吗", "小麦", 10021, 1286, 23,
        "8 分钟前", "今天 12:30", true, "校园生活",
        "看队伍排得挺长的，不知道味道怎么样，有没有去过的同学说说？"),
    _DemoTopic(900002, 72, "图书馆四楼的空调是不是坏了", "夜猫子", 10022, 842, 16,
        "25 分钟前", "今天 11:02", false, "校园生活",
        "今天在四楼自习，感觉空调完全没风，热得看不进去书，有没有同样感觉的？"),
    _DemoTopic(900003, 72, "今天暴雨，伞在教三楼门口被吹翻了", "阿柚", 10023, 2103, 41,
        "1 小时前", "今天 09:15", false, "校园生活",
        "刚出教三就一阵大风，伞骨直接反了，大家出门记得带结实的伞。"),
    _DemoTopic(900004, 72, "求推荐一款便宜好用的台灯", "小灯", 10024, 617, 12,
        "3 小时前", "今天 08:20", false, "校园生活",
        "宿舍桌子比较小，想要不占地方、护眼的那种，预算 100 以内。"),
    _DemoTopic(900005, 72, "宿舍楼热水时间能不能延长一点", "晚归人", 10025, 1508, 33,
        "5 小时前", "昨天 22:40", false, "校园生活",
        "晚上做实验回来经常就停热水了，希望后勤能考虑延后半小时。"),
    _DemoTopic(900006, 72, "有没有一起夜跑的同学", "跑者", 10026, 434, 8,
        "昨天 21:10", "昨天 20:55", false, "校园生活",
        "每周二四晚上九点在操场跑 5 公里，有意一起的私信我。"),

    // ---- 摄影天地 fid 561 ----
    _DemoTopic(900011, 561, "这几天的晚霞，随手拍了几张", "光影", 10031, 3260, 58,
        "40 分钟前", "今天 10:12", true, "摄影天地",
        "傍晚在操场东侧拍的，云层特别好看。后期只做了轻微的对比度调整。"),
    _DemoTopic(900012, 561, "用 50mm 定焦拍的校园一角", "定焦党", 10032, 1877, 27,
        "2 小时前", "今天 08:44", false, "摄影天地",
        "一直觉得 50 定焦很适合拍学校里的小景，光圈收到 2.8 锐度会更好。"),
    _DemoTopic(900013, 561, "求推荐入门相机，预算 3000 左右", "新手", 10033, 942, 35,
        "4 小时前", "昨天 23:12", false, "摄影天地",
        "主要想拍风景和人像，二手也可以接受，希望各位给点建议。"),
    _DemoTopic(900014, 561, "图书馆前的银杏，终于等到黄了", "秋天", 10034, 2415, 44,
        "昨天 20:02", "昨天 18:30", false, "摄影天地",
        "早上七点多去的，人少光也好，建议想拍的同学早点去。"),
    _DemoTopic(900015, 561, "第一次尝试长曝光，请多指教", "慢门", 10035, 1130, 19,
        "昨天 15:26", "昨天 14:10", false, "摄影天地",
        "三脚架 + 10 秒曝光拍的车流，感觉还是有点糊，求指点。"),

    // ---- 跳蚤市场 fid 110 ----
    _DemoTopic(900021, 110, "出九成新自行车，200 出", "老车主", 10041, 1673, 26,
        "15 分钟前", "今天 11:40", true, "跳蚤市场",
        "骑了半年，链条刚上过油，车锁一起送。南校区自提。"),
    _DemoTopic(900022, 110, "求购一台 24 寸二手显示器", "显示器", 10042, 806, 14,
        "1 小时前", "今天 10:05", false, "跳蚤市场",
        "要求无亮点坏点，HDMI 接口，价格好商量。"),
    _DemoTopic(900023, 110, "宿舍用小冰箱转让，八成新", "冰箱", 10043, 1290, 22,
        "3 小时前", "今天 08:12", false, "跳蚤市场",
        "毕业要搬走，冰箱用了不到一年，制冷正常，150 出。"),
    _DemoTopic(900024, 110, "出考研数学全套资料", "上岸了", 10044, 2214, 39,
        "6 小时前", "昨天 21:50", false, "跳蚤市场",
        "1800 题 + 复习全书 + 笔记，打包 80，笔记做得很全。"),
    _DemoTopic(900025, 110, "收一个用着顺手的机械键盘", "键盘侠", 10045, 587, 11,
        "昨天 19:20", "昨天 18:02", false, "跳蚤市场",
        "红轴或茶轴都行，预算 200 左右。"),

    // ---- 求职就业 fid 553 ----
    _DemoTopic(900031, 553, "秋招 offer 比较：算法岗 vs 嵌入式", "纠结中", 10051, 4120, 87,
        "30 分钟前", "今天 09:30", true, "求职就业",
        "一个是算法，一个是嵌入式，待遇差不多，想听听师兄师姐的建议。"),
    _DemoTopic(900032, 553, "简历求修改，投了 20 家没回应", "求职者", 10052, 2360, 52,
        "2 小时前", "今天 07:55", false, "求职就业",
        "主要是项目经历写得比较平，不知道该突出什么，求指点。"),
    _DemoTopic(900033, 553, "华为面试一般会问什么", "准备中", 10053, 3050, 63,
        "5 小时前", "昨天 22:15", false, "求职就业",
        "投的是硬件岗，听说会有手撕代码，不知道难度如何。"),
    _DemoTopic(900034, 553, "实习需要提前准备什么", "大三", 10054, 1420, 28,
        "昨天 18:40", "昨天 17:20", false, "求职就业",
        "明年想找暑期实习，现在开始准备来得及吗？"),
    _DemoTopic(900035, 553, "关于三方协议的几个问题", "签约", 10055, 980, 17,
        "昨天 12:08", "昨天 11:00", false, "求职就业",
        "违约金一般怎么算？签之前需要注意什么？"),

    // ---- 失物招领 fid 142 ----
    _DemoTopic(900041, 142, "寻找一张校园卡，昨天在食堂丢的", "着急", 10061, 640, 9,
        "20 分钟前", "今天 12:00", true, "失物招领",
        "卡号尾号 2345，昨天中午在二食堂三楼附近丢的，捡到的同学请联系我。"),
    _DemoTopic(900042, 142, "在教二楼 305 捡到一把钥匙", "好心人", 10062, 420, 6,
        "2 小时前", "今天 10:30", false, "失物招领",
        "钥匙上挂着一个蓝色小熊挂件，放在 305 讲台抽屉里了。"),
    _DemoTopic(900043, 142, "丢了一个黑色耳机盒", "耳机", 10063, 380, 5,
        "4 小时前", "昨天 23:40", false, "失物招领",
        "大概是昨天下午在图书馆三楼丢的，里面还有一副耳机，谢谢！"),
    _DemoTopic(900044, 142, "在操场捡到一副眼镜", "跑步", 10064, 512, 7,
        "昨天 20:30", "昨天 19:50", false, "失物招领",
        "黑色半框，放在操场器材室门口的值班桌上。"),
    _DemoTopic(900045, 142, "寻找蓝色保温杯", "杯子", 10065, 296, 4,
        "昨天 16:12", "昨天 15:30", false, "失物招领",
        "杯身上有一张卡通贴纸，可能落在教三楼了。"),
  ];
}

/// 演示帖子的一条记录（比 `Topic` 多带正文，便于生成详情）。
class _DemoTopic {
  final int tid;
  final int fid;
  final String title;
  final String author;
  final int authorId;
  final int views;
  final int replies;

  /// 展示用的"多久以前"（列表里当最后回复时间用）
  final String recency;

  /// 发帖时间（展示用字符串）
  final String time;
  final bool isStick;
  final String category;
  final String body;

  const _DemoTopic(
    this.tid,
    this.fid,
    this.title,
    this.author,
    this.authorId,
    this.views,
    this.replies,
    this.recency,
    this.time,
    this.isStick,
    this.category,
    this.body,
  );
}
