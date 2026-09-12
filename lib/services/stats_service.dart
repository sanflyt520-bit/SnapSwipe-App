import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_stats.dart';

/// 每日配额 / 连续打卡 / 累计统计
///
/// ## 设计要点
/// - **跨天重置**: 读取时比对存储的日期,不是今天就把「今日已处理」归零。
/// - **断档清零**: 距上次清理超过 1 天,streak 视为中断(读出来即为 0)。
///   注意这里只在读取时判定,不写回,避免没打开 App 也改变数据语义。
/// - **日期只比年月日**: 全部经 [_dateOnly] 归一化,避免时分秒导致误判。
class StatsService {
  /// 默认每日配额(设计方案 3.1)
  static const int defaultQuota = 35;

  /// 配额可调区间
  static const int minQuota = 30;
  static const int maxQuota = 50;

  /// 单次会话最多取多少张(设计方案: 一次 10-15 张,约 2-3 分钟)
  static const int maxPerSession = 15;

  static const String _kQuota = 'stats_quota';
  static const String _kTodayProcessed = 'stats_today_processed';
  static const String _kTodayDate = 'stats_today_date';
  static const String _kStreak = 'stats_streak';
  static const String _kLastCleanup = 'stats_last_cleanup';
  static const String _kTotalProcessed = 'stats_total_processed';
  static const String _kTotalFreed = 'stats_total_freed';

  /// 读取统计(自动处理跨天与断档)
  Future<DailyStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateOnly(DateTime.now());

    final quota = prefs.getInt(_kQuota) ?? defaultQuota;

    // 跨天则今日计数归零
    var todayProcessed = prefs.getInt(_kTodayProcessed) ?? 0;
    final storedDate = prefs.getString(_kTodayDate);
    if (storedDate != null && storedDate != _format(today)) {
      todayProcessed = 0;
    }

    // 断档则 streak 视为中断
    var streak = prefs.getInt(_kStreak) ?? 0;
    final lastCleanup = _parse(prefs.getString(_kLastCleanup));
    if (lastCleanup != null && _diffDays(lastCleanup, today) > 1) {
      streak = 0;
    }

    return DailyStats(
      today: today,
      todayProcessed: todayProcessed,
      quota: quota,
      streakDays: streak,
      totalProcessed: prefs.getInt(_kTotalProcessed) ?? 0,
      totalFreedBytes: prefs.getInt(_kTotalFreed) ?? 0,
      lastCleanupDate: lastCleanup,
    );
  }

  /// 记录一次清理
  ///
  /// [processed] 本次处理的张数(保留 + 删除都算,都付出了决策)
  /// [freedBytes] 本次释放的空间(被删除文件的大小之和)
  Future<DailyStats> recordCleanup({
    required int processed,
    required int freedBytes,
  }) async {
    final current = await load();
    final prefs = await SharedPreferences.getInstance();
    final today = current.today;

    final newProcessed = current.todayProcessed + processed;
    final newTotal = current.totalProcessed + processed;
    final newFreed = current.totalFreedBytes + freedBytes;

    // 连续打卡判定
    final last = current.lastCleanupDate;
    final int streak;
    if (processed <= 0) {
      streak = current.streakDays;
    } else if (last == null) {
      streak = 1; // 首次
    } else {
      final gap = _diffDays(last, today);
      if (gap == 0) {
        streak = current.streakDays; // 同一天,不重复加
      } else if (gap == 1) {
        streak = current.streakDays + 1; // 接上了
      } else {
        streak = 1; // 断档后重开
      }
    }

    // 只在「由未达标变为达标」这一刻为 true,避免重复弹庆祝
    final justCompleted =
        current.todayProcessed < current.quota && newProcessed >= current.quota;

    await Future.wait([
      prefs.setInt(_kTodayProcessed, newProcessed),
      prefs.setString(_kTodayDate, _format(today)),
      prefs.setInt(_kStreak, streak),
      prefs.setString(_kLastCleanup, _format(today)),
      prefs.setInt(_kTotalProcessed, newTotal),
      prefs.setInt(_kTotalFreed, newFreed),
    ]);

    return DailyStats(
      today: today,
      todayProcessed: newProcessed,
      quota: current.quota,
      streakDays: streak,
      totalProcessed: newTotal,
      totalFreedBytes: newFreed,
      lastCleanupDate: today,
      justCompletedQuota: justCompleted,
    );
  }

  /// 设置每日配额,超出 [minQuota]~[maxQuota] 会被收敛,返回实际生效值
  Future<int> setQuota(int value) async {
    final clamped = value < minQuota
        ? minQuota
        : (value > maxQuota ? maxQuota : value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kQuota, clamped);
    return clamped;
  }

  /// 清空统计(便于调试 / 重置)
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_kTodayProcessed),
      prefs.remove(_kTodayDate),
      prefs.remove(_kStreak),
      prefs.remove(_kLastCleanup),
      prefs.remove(_kTotalProcessed),
      prefs.remove(_kTotalFreed),
    ]);
  }

  /// 归一化到年月日,去掉时分秒
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _format(DateTime d) =>
      '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parse(String? s) {
    if (s == null) return null;
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// b - a,相差天数(按自然日算)
  static int _diffDays(DateTime a, DateTime b) =>
      _dateOnly(b).difference(_dateOnly(a)).inDays;
}
