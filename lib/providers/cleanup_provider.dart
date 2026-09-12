import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/cleanup_state.dart';
import '../models/swipe_direction.dart';
import '../services/permission_service.dart';
import '../services/stats_service.dart';
import '../services/trash_service.dart';
import 'service_providers.dart';

/// 清理会话的状态与业务
///
/// 原来这些都散落在 `_SwipePageState` 里,靠 setState 驱动。
/// 现在改成一个 Notifier: UI 只读状态、只调方法,业务与 Widget 解耦,
/// 也方便以后加测试(Notifier 可以脱离 UI 直接测)。
///
/// 一次性提示(SnackBar)不在这里弹 —— Notifier 拿不到 BuildContext,
/// 所以状态只描述「要提示什么」([CleanupState.snack] + 递增的 snackSeq),
/// 由 UI 层监听后展示。
class CleanupController extends Notifier<CleanupState> {
  /// 删除后的可撤销窗口(秒)
  static const int undoWindowSeconds = 5;

  Timer? _undoTimer;

  @override
  CleanupState build() {
    // 销毁前把还没提交的删除结算掉,避免漏删
    ref.onDispose(() {
      _undoTimer?.cancel();
      final pending = state.pendingDeletion;
      final entities =
          pending.map((e) => e.assetEntity).whereType<AssetEntity>().toList();
      if (entities.isNotEmpty) {
        unawaited(ref.read(trashServiceProvider).moveToTrash(entities));
      }
    });

    // build 里不能改 state,所以异步加载推迟到微任务
    Future.microtask(load);
    return CleanupState.initial();
  }

  /// 加载: 读统计 → 按今日剩余配额取照片
  Future<void> load() async {
    final statsService = ref.read(statsServiceProvider);
    final repository = ref.read(mediaRepositoryProvider);

    final stats = await statsService.load();

    state = state.copyWith(
      loading: true,
      clearError: true,
      currentIndex: 0,
      keptCount: 0,
      deletedCount: 0,
      pendingDeletion: const [],
      stats: stats,
      quotaReached: stats.isQuotaReached,
      justCompletedQuota: false,
    );

    // 今日配额已满: 连权限都不用申请,直接进庆祝态
    if (stats.isQuotaReached) {
      state = state.copyWith(loading: false);
      return;
    }

    final granted = await PermissionService.instance.requestPhotoPermission();
    if (!granted) {
      state = state.copyWith(
        loading: false,
        error: '未授予相册权限,无法读取照片',
      );
      return;
    }

    final take = stats.sessionSize(StatsService.maxPerSession);
    final items = await repository.fetchRecentMedia(limit: take);
    state = state.copyWith(items: items, loading: false);
  }

  /// 处理一次滑动
  void handleSwiped(SwipeDirection direction) {
    final item = state.currentItem;
    if (item == null) return;

    if (direction == SwipeDirection.keep) {
      state = state.copyWith(
        keptCount: state.keptCount + 1,
        currentIndex: state.currentIndex + 1,
      );
    } else {
      state = state.copyWith(
        deletedCount: state.deletedCount + 1,
        currentIndex: state.currentIndex + 1,
        // 先只入队,不真的删: 给用户撤销机会,也避免每条都弹系统框
        pendingDeletion: [...state.pendingDeletion, item],
      );
      _startUndoWindow();
      _notifySnack(
        '已标记删除 ${state.pendingDeletion.length} 张 · $undoWindowSeconds 秒内可撤销',
        withUndo: true,
      );
    }

    // 一轮滑完: 提交删除 + 计入今日统计
    if (state.isSessionFinished) {
      unawaited(finishSession());
    }
  }

  /// 撤销最近一次删除: 卡片退回,并从待删除队列移除
  void undoLastDeletion() {
    final pending = state.pendingDeletion;
    if (pending.isEmpty) return;

    final removed = [...pending]..removeLast();
    state = state.copyWith(
      pendingDeletion: removed,
      deletedCount: state.deletedCount > 0 ? state.deletedCount - 1 : 0,
      currentIndex: state.currentIndex > 0 ? state.currentIndex - 1 : 0,
    );
    _undoTimer?.cancel();

    // 队列里还有则重新开一个撤销窗口
    if (removed.isNotEmpty) {
      _startUndoWindow();
    }
  }

  /// 启动撤销倒计时,到点批量提交
  void _startUndoWindow() {
    _undoTimer?.cancel();
    _undoTimer = Timer(const Duration(seconds: undoWindowSeconds), () {
      unawaited(commitPending());
    });
  }

  /// 批量提交到系统回收站(整个过程只弹一次系统确认框)
  Future<void> commitPending() async {
    final pending = state.pendingDeletion;
    if (pending.isEmpty || state.committing) return;

    _undoTimer?.cancel();

    final entities = pending
        .map((item) => item.assetEntity)
        .whereType<AssetEntity>()
        .toList();

    if (entities.isEmpty) {
      // 拿不到资源引用,丢弃队列避免堵住后续提交
      state = state.copyWith(pendingDeletion: const [], committing: false);
      return;
    }

    state = state.copyWith(committing: true);

    try {
      final result = await ref.read(trashServiceProvider).moveToTrash(entities);
      final successIds = result.successIds.toSet();
      state = state.copyWith(
        pendingDeletion: state.pendingDeletion
            .where((item) => !successIds.contains(item.id))
            .toList(),
        committing: false,
      );
      _notifyCommitResult(result);
    } catch (e) {
      state = state.copyWith(committing: false);
      _notifySnack('删除失败:$e');
    }
  }

  /// 一轮滑完的结算
  ///
  /// 顺序很重要: 先算本轮释放的空间(提交后队列会清空) → 提交删除 → 更新统计。
  /// 「处理的张数」包含保留的,因为保留同样是做了一次决策。
  Future<void> finishSession() async {
    final processed = state.items.length;
    final freedBytes =
        state.pendingDeletion.fold<int>(0, (sum, item) => sum + item.sizeBytes);

    await commitPending();

    if (processed <= 0) return;

    final updated = await ref.read(statsServiceProvider).recordCleanup(
          processed: processed,
          freedBytes: freedBytes,
        );
    state = state.copyWith(
      stats: updated,
      justCompletedQuota: updated.justCompletedQuota,
      quotaReached: updated.isQuotaReached,
    );
  }

  /// 继续下一轮: 先结算未提交的删除,再重新读取相册
  ///
  /// 重新读取是关键: 否则已删除的照片会在下一轮重新出现。
  Future<void> nextRound() async {
    await commitPending();
    await load();
  }

  void _notifyCommitResult(TrashResult result) {
    if (result.isEmpty) return;
    if (result.failedCount > 0) {
      _notifySnack(
        '已删除 ${result.successCount} 张,${result.failedCount} 张失败'
        '(可能取消了系统授权)',
      );
    } else if (result.usedPermanentFallback) {
      _notifySnack('已永久删除 ${result.successCount} 张(Android 10 无回收站)');
    } else {
      _notifySnack('已删除 ${result.successCount} 张,可在相册回收站找回');
    }
  }

  /// 请求 UI 展示一条提示(snackSeq 递增,保证相同文案也能再次触发)
  void _notifySnack(String message, {bool withUndo = false}) {
    state = state.copyWith(
      snack: SnackRequest(message, withUndo: withUndo),
      snackSeq: state.snackSeq + 1,
    );
  }
}

/// 清理会话状态
final cleanupProvider =
    NotifierProvider<CleanupController, CleanupState>(CleanupController.new);
