import 'package:flutter/material.dart';

enum EntryDirection { expense, income }

extension EntryDirectionX on EntryDirection {
  String get label => this == EntryDirection.expense ? '支出' : '收入';
  int get storageValue => this == EntryDirection.expense ? 0 : 1;

  static EntryDirection fromStorage(int value) =>
      value == 1 ? EntryDirection.income : EntryDirection.expense;
}

class Category {
  const Category({
    required this.name,
    required this.direction,
    required this.icon,
    required this.color,
    required this.keywords,
  });

  final String name;
  final EntryDirection direction;
  final IconData icon;
  final Color color;
  final List<String> keywords;

  /// 黑白主题下用几档灰区分分类，不保留原来的彩色。
  Color get monoColor {
    const tones = [
      Color(0xFF1B1B19),
      Color(0xFF4A4742),
      Color(0xFF6F6C66),
      Color(0xFF8C887E),
    ];
    final code = name.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return tones[code % tones.length];
  }
}

const _incomeColor = Color(0xFF3E7864);

const expenseCategories = <Category>[
  Category(
    name: '餐饮',
    direction: EntryDirection.expense,
    icon: Icons.ramen_dining_rounded,
    color: Color(0xFFD0734B),
    keywords: [
      '早餐',
      '午饭',
      '午餐',
      '晚饭',
      '晚餐',
      '夜宵',
      '外卖',
      '奶茶',
      '咖啡',
      '火锅',
      '烧烤',
      '小吃',
      '食堂',
      '餐厅',
      '饭店',
      '米饭',
      '面条',
      '饺子',
      '美团',
      '饿了么',
      '肯德基',
      '麦当劳',
      '星巴克',
      '瑞幸',
      '蜜雪',
      '喜茶',
      '吃饭',
      '聚餐',
      '请吃饭',
    ],
  ),
  Category(
    name: '交通',
    direction: EntryDirection.expense,
    icon: Icons.directions_bus_rounded,
    color: Color(0xFF6E8CA0),
    keywords: [
      '打车',
      '滴滴',
      '出租车',
      '地铁',
      '公交',
      '高铁',
      '火车',
      '动车',
      '机票',
      '加油',
      '油费',
      '停车',
      '充电',
      '单车',
      '路费',
      '过路费',
      '12306',
      '车票',
      '交通',
      '通勤',
    ],
  ),
  Category(
    name: '购物',
    direction: EntryDirection.expense,
    icon: Icons.shopping_bag_rounded,
    color: Color(0xFFB08B52),
    keywords: [
      '淘宝',
      '天猫',
      '京东',
      '拼多多',
      '超市',
      '便利店',
      '商场',
      '网购',
      '衣服',
      '裤子',
      '鞋',
      '化妆品',
      '护肤',
      '日用品',
      '快递',
      '盒马',
      '山姆',
      '购物',
      '买了',
      '下单',
    ],
  ),
  Category(
    name: '居住',
    direction: EntryDirection.expense,
    icon: Icons.home_rounded,
    color: Color(0xFF8B7355),
    keywords: [
      '房租',
      '物业',
      '水费',
      '电费',
      '燃气',
      '煤气',
      '宽带',
      '家具',
      '家电',
      '维修',
      '装修',
      '保洁',
      '住宿费',
    ],
  ),
  Category(
    name: '娱乐',
    direction: EntryDirection.expense,
    icon: Icons.movie_rounded,
    color: Color(0xFF8C7B9E),
    keywords: [
      '电影',
      '游戏',
      '演出',
      '门票',
      'KTV',
      '酒吧',
      '视频会员',
      '音乐会员',
      '桌游',
      '剧本杀',
      '娱乐',
      '演唱会',
      '展览',
    ],
  ),
  Category(
    name: '医疗',
    direction: EntryDirection.expense,
    icon: Icons.medical_services_rounded,
    color: Color(0xFFA7746B),
    keywords: [
      '医院',
      '药店',
      '挂号',
      '买药',
      '体检',
      '牙科',
      '门诊',
      '住院',
      '看病',
      '医疗',
      '药费',
    ],
  ),
  Category(
    name: '学习',
    direction: EntryDirection.expense,
    icon: Icons.menu_book_rounded,
    color: Color(0xFF5E8C8A),
    keywords: [
      '书',
      '课程',
      '培训',
      '学费',
      '考试',
      '文具',
      '网课',
      '学习',
      '资料',
      '报名费',
      '书店',
    ],
  ),
  Category(
    name: '人情',
    direction: EntryDirection.expense,
    icon: Icons.redeem_rounded,
    color: Color(0xFFC07A86),
    keywords: [
      '红包',
      '礼物',
      '请客',
      '随礼',
      '份子',
      '转账',
      '给妈',
      '给爸',
      '借出',
      '人情',
      '发红包',
    ],
  ),
  Category(
    name: '通讯',
    direction: EntryDirection.expense,
    icon: Icons.phone_iphone_rounded,
    color: Color(0xFF7A8B6F),
    keywords: ['话费', '流量', '中国移动', '中国联通', '中国电信', '宽带费', '通讯'],
  ),
  Category(
    name: '旅行',
    direction: EntryDirection.expense,
    icon: Icons.flight_takeoff_rounded,
    color: Color(0xFF4F7E9E),
    keywords: ['酒店', '民宿', '机票', '景区', '旅游', '度假', '签证', '旅行', '住宿', '景点'],
  ),
  Category(
    name: 'AI使用',
    direction: EntryDirection.expense,
    icon: Icons.smart_toy_rounded,
    color: Color(0xFF6F6C66),
    keywords: [
      'AI使用',
      'ChatGPT',
      'GPT',
      'OpenAI',
      'Claude',
      'DeepSeek',
      'Gemini',
      'Copilot',
      'Midjourney',
      'Stable Diffusion',
      'stablediffusion',
      'Sora',
      '大模型',
      '人工智能',
      'AI绘画',
      'AI会员',
      'AI订阅',
      'API充值',
      'API费用',
      'Token充值',
      '算力',
    ],
  ),
  Category(
    name: '其他',
    direction: EntryDirection.expense,
    icon: Icons.more_horiz_rounded,
    color: Color(0xFF8C887E),
    keywords: [],
  ),
];

const incomeCategories = <Category>[
  Category(
    name: '工资',
    direction: EntryDirection.income,
    icon: Icons.payments_rounded,
    color: _incomeColor,
    keywords: ['工资', '薪资', '薪水', '发薪', '月薪', '基本工资'],
  ),
  Category(
    name: '奖金',
    direction: EntryDirection.income,
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFC0963F),
    keywords: ['奖金', '年终奖', '提成', '绩效', '奖励'],
  ),
  Category(
    name: '兼职',
    direction: EntryDirection.income,
    icon: Icons.work_outline_rounded,
    color: Color(0xFF6E8B74),
    keywords: ['兼职', '外包', '稿费', '副业', '私活'],
  ),
  Category(
    name: '理财',
    direction: EntryDirection.income,
    icon: Icons.trending_up_rounded,
    color: Color(0xFF5D7A93),
    keywords: ['利息', '分红', '基金', '股票', '收益', '理财', '余额宝'],
  ),
  Category(
    name: '退款',
    direction: EntryDirection.income,
    icon: Icons.undo_rounded,
    color: Color(0xFF9A7B5F),
    keywords: ['退款', '退货', '返还', '退回'],
  ),
  Category(
    name: '红包',
    direction: EntryDirection.income,
    icon: Icons.card_giftcard_rounded,
    color: Color(0xFFC07A86),
    keywords: ['红包', '压岁钱', '收红包'],
  ),
  Category(
    name: '报销',
    direction: EntryDirection.income,
    icon: Icons.receipt_long_rounded,
    color: Color(0xFF7A8B6F),
    keywords: ['报销', '差旅费'],
  ),
  Category(
    name: '其他',
    direction: EntryDirection.income,
    icon: Icons.more_horiz_rounded,
    color: _incomeColor,
    keywords: [],
  ),
];

const allCategories = <Category>[...expenseCategories, ...incomeCategories];

Category categoryFor(String name, EntryDirection direction) {
  final pool = direction == EntryDirection.expense
      ? expenseCategories
      : incomeCategories;
  return pool.firstWhere(
    (category) => category.name == name,
    orElse: () => pool.last,
  );
}

const _incomeSignals = <String>[
  '工资',
  '薪资',
  '薪水',
  '奖金',
  '年终奖',
  '提成',
  '绩效',
  '报销',
  '退款',
  '退回',
  '收到',
  '收入',
  '进账',
  '到账',
  '收款',
  '利息',
  '分红',
  '收益',
  '收红包',
  '压岁钱',
  '赚了',
  '兼职',
  '稿费',
];

const _expenseSignals = <String>[
  '支出',
  '花了',
  '花',
  '付了',
  '付款',
  '支付',
  '买了',
  '买',
  '消费',
  '请客',
  '发红包',
  '交费',
  '缴费',
  '充话费',
  '还款',
  '借出',
  '给了',
];

/// 判断一句话里的收支方向。显式正负号在解析器里优先处理。
EntryDirection inferDirection(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), '');
  var incomeScore = 0;
  var expenseScore = 0;

  for (final signal in _incomeSignals) {
    if (normalized.contains(signal)) incomeScore += signal.length + 2;
  }
  for (final signal in _expenseSignals) {
    if (normalized.contains(signal)) expenseScore += signal.length + 2;
  }

  if (incomeScore > expenseScore) return EntryDirection.income;
  return EntryDirection.expense;
}

/// 按关键词命中长度累加权重；同分时保留分类表里的先后顺序。
Category classifyCategory(String text, EntryDirection direction) {
  final normalized = text.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  final pool = direction == EntryDirection.expense
      ? expenseCategories
      : incomeCategories;

  Category? best;
  var bestScore = 0;

  for (final category in pool) {
    var score = 0;
    for (final keyword in category.keywords) {
      if (normalized.contains(keyword.toLowerCase())) {
        score += keyword.length * 3 + 2;
      }
    }
    if (normalized.contains(category.name)) {
      score += category.name.length * 3 + 4;
    }
    if (score > bestScore) {
      bestScore = score;
      best = category;
    }
  }

  return best ?? pool.last;
}

/// 收入分类里的强信号，用于把“退款 99”这类没有动词的句子判成收入。
bool hasIncomeCategorySignal(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), '');
  return incomeCategories
      .where((category) => category.name != '其他')
      .any(
        (category) =>
            normalized.contains(category.name) ||
            category.keywords.any(normalized.contains),
      );
}
