import 'daily_stats.dart';
import 'media_item.dart';

/// 需要 UI 展示的一次性提示(SnackBar)
///
/// 之所以放进状态、而不是在 controller 里直接弹:
/// SnackBar 需要 BuildContext,而 Notifier 拿不到 context。
/// 所以状态只负责「描述要提示什么」,由 UI 层监听后展示。
class SnackRequest {
  const SnackRequest(this.message, {this.withUndo = false});

  final String message;

  /// 是否带「撤销」按钮(删除入队时用)
  final bool withUndo;
}

/// 清理会话的全部状态(不可变)
///
/// 所有派生值(当前卡片、是否滑完、展示用统计)都在这里算好,
/// UI 层只读不算,controller 只负责产出新状态。
class CleanupState {
  const CleanupState({
    required this.items,
    required this.currentIndex,
    required this.keptCount,
    required this.deletedCount,
    required this.pendingDeletion,
    required this.committing,
    required this.loading,
    required this.quotaReached,
    required this.justCompletedQuota,
    required this.snackSeq,
    this.error,
    this.stats,
    this.snack,
  });

  /// 本轮取到的媒体
  final List<MediaItem> items;

  /// 当前处理到的下标
  final int currentIndex;

  final int keptCount;
  final int deletedCount;

  /// 已标记删除、尚未提交到系统回收站的队列
  final List<MediaItem> pendingDeletion;

  /// 是否正在向系统提交删除(防重复提交)
  final bool committing;

  final bool loading;
  final String? error;

  /// 每日统计(配额 / streak / 累计)
  final DailyStats? stats;

  /// 今日配额是否已达成
  final bool quotaReached;

  /// 本轮是否刚好把配额做满(用于只弹一次庆祝页)
  final bool justCompletedQuota;

  /// 待展示的提示
  final SnackRequest? snack;

  /// 提示序号: 每次请求提示都 +1,保证相同文案也能被再次触发
  final int snackSeq;

  factory CleanupState.initial() {
    return const CleanupState(
      items: [],
      currentIndex: 0,
      keptCount: 0,
      deletedCount: 0,
      pendingDeletion: [],
      committing: false,
      loading: true,
      quotaReached: false,
      justCompletedQuota: false,
      snackSeq: 0,
    );
  }

  // ---- 派生值 ----

  bool get hasItems => items.isNotEmpty;

  /// 本轮是否滑完
  bool get isSessionFinished => items.isNotEmpty && currentIndex >= items.length;

  /// 当前卡片
  MediaItem? get currentItem =>
      (currentIndex >= 0 && currentIndex < items.length)
          ? items[currentIndex]
          : null;

  /// 下一张卡片(垫底预加载)
  MediaItem? get nextItem =>
      (currentIndex + 1 < items.length) ? items[currentIndex + 1] : null;

  /// 展示用的统计 = 已落盘进度 + 本轮已滑张数
  ///
  /// 落盘只在一轮结束时发生,但进度环必须每滑一张就走一格,
  /// 否则滑了 14 张进度还停在 0,反馈太迟钝。
  /// 这里只在展示时叠加,不动 [stats],所以不会重复计数。
  DailyStats? get displayStats {
    final s = stats;
    if (s == null || currentIndex <= 0) return s;
    return s.copyWith(todayProcessed: s.todayProcessed + currentIndex);
  }

  CleanupState copyWith({
    List<MediaItem>? items,
    int? currentIndex,
    int? keptCount,
    int? deletedCount,
    List<MediaItem>? pendingDeletion,
    bool? committing,
    bool? loading,
    String? error,
    DailyStats? stats,
    bool? quotaReached,
    bool? justCompletedQuota,
    SnackRequest? snack,
    int? snackSeq,
    bool clearError = false,
    bool clearSnack = false,
  }) {
    return CleanupState(
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      keptCount: keptCount ?? this.keptCount,
      deletedCount: deletedCount ?? this.deletedCount,
      pendingDeletion: pendingDeletion ?? this.pendingDeletion,
      committing: committing ?? this.committing,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      stats: stats ?? this.stats,
      quotaReached: quotaReached ?? this.quotaReached,
      justCompletedQuota: justCompletedQuota ?? this.justCompletedQuota,
      snack: clearSnack ? null : (snack ?? this.snack),
      snackSeq: snackSeq ?? this.snackSeq,
    );
  }
}
