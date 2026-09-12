/// 每日清理统计的快照
///
/// 这是领域模型,不依赖任何存储细节。所有派生值(是否达标、进度、剩余)
/// 都在这里算好,UI 层只负责展示。
class DailyStats {
  const DailyStats({
    required this.today,
    required this.todayProcessed,
    required this.quota,
    required this.streakDays,
    required this.totalProcessed,
    required this.totalFreedBytes,
    this.lastCleanupDate,
    this.justCompletedQuota = false,
  });

  /// 今天(已归一化到年月日)
  final DateTime today;

  /// 今日已处理的张数(保留 + 删除都算,因为都做了决策)
  final int todayProcessed;

  /// 每日配额
  final int quota;

  /// 连续打卡天数
  final int streakDays;

  /// 累计处理张数
  final int totalProcessed;

  /// 累计释放空间(字节)
  final int totalFreedBytes;

  /// 最后一次清理的日期(用于判断连续 / 断档)
  final DateTime? lastCleanupDate;

  /// 本次记录是否刚好达成配额(用于触发庆祝页,只应生效一次)
  final bool justCompletedQuota;

  /// 今日是否已达配额
  bool get isQuotaReached => todayProcessed >= quota;

  /// 今日进度 0.0 ~ 1.0
  double get progress =>
      quota <= 0 ? 0.0 : (todayProcessed / quota).clamp(0.0, 1.0);

  /// 今日还剩多少张要处理
  int get remaining {
    final left = quota - todayProcessed;
    if (left < 0) return 0;
    return left > quota ? quota : left;
  }

  /// 本次会话建议取的张数:不超过剩余配额,也不超过单次会话上限
  int sessionSize(int maxPerSession) {
    final take = remaining < maxPerSession ? remaining : maxPerSession;
    return take <= 0 ? maxPerSession : take;
  }

  /// 累计释放空间的可读文本
  String get freedLabel {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (totalFreedBytes >= gb) {
      return '${(totalFreedBytes / gb).toStringAsFixed(2)} GB';
    }
    if (totalFreedBytes >= mb) {
      return '${(totalFreedBytes / mb).toStringAsFixed(1)} MB';
    }
    if (totalFreedBytes >= kb) {
      return '${(totalFreedBytes / kb).toStringAsFixed(0)} KB';
    }
    return '$totalFreedBytes B';
  }

  DailyStats copyWith({
    DateTime? today,
    int? todayProcessed,
    int? quota,
    int? streakDays,
    int? totalProcessed,
    int? totalFreedBytes,
    DateTime? lastCleanupDate,
    bool? justCompletedQuota,
  }) {
    return DailyStats(
      today: today ?? this.today,
      todayProcessed: todayProcessed ?? this.todayProcessed,
      quota: quota ?? this.quota,
      streakDays: streakDays ?? this.streakDays,
      totalProcessed: totalProcessed ?? this.totalProcessed,
      totalFreedBytes: totalFreedBytes ?? this.totalFreedBytes,
      lastCleanupDate: lastCleanupDate ?? this.lastCleanupDate,
      justCompletedQuota: justCompletedQuota ?? this.justCompletedQuota,
    );
  }

  /// 初始状态(从未清理过)
  factory DailyStats.initial({required int quota, required DateTime today}) {
    return DailyStats(
      today: today,
      todayProcessed: 0,
      quota: quota,
      streakDays: 0,
      totalProcessed: 0,
      totalFreedBytes: 0,
      lastCleanupDate: null,
    );
  }
}
