import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cleanup_state.dart';
import '../../models/swipe_direction.dart';
import '../../providers/cleanup_provider.dart';
import '../../services/permission_service.dart';
import 'swipe_card.dart';
import 'widgets/daily_progress_ring.dart';

/// 滑动清理主页面
///
/// 状态全部来自 [cleanupProvider]:这里只负责渲染与事件转发,
/// 业务逻辑(配额、撤销、提交删除、结算)都在 controller 里,不再和 Widget 耦在一起。
class SwipePage extends ConsumerStatefulWidget {
  const SwipePage({super.key});

  @override
  ConsumerState<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends ConsumerState<SwipePage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cleanupProvider);
    final controller = ref.read(cleanupProvider.notifier);

    // 一次性提示(SnackBar)由 UI 负责:Notifier 没有 context,
    // 只能在状态里描述「要提示什么」,这里监听 snackSeq 变化后展示。
    ref.listen<int>(cleanupProvider.select((s) => s.snackSeq), (prev, next) {
      final snack = ref.read(cleanupProvider).snack;
      if (snack != null) _showSnack(snack, controller);
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _buildBody(state, controller)),
    );
  }

  void _showSnack(SnackRequest snack, CleanupController controller) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(snack.message),
        action: snack.withUndo
            ? SnackBarAction(
                label: '撤销',
                onPressed: controller.undoLastDeletion,
              )
            : null,
        duration: Duration(
          seconds: snack.withUndo ? CleanupController.undoWindowSeconds : 3,
        ),
      ),
    );
  }

  Widget _buildBody(CleanupState state, CleanupController controller) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) return _buildError(state, controller);

    // 今日配额达成 → 庆祝页(优先于其它状态)
    if (state.quotaReached) return _buildCelebration(state);

    if (!state.hasItems) {
      return const Center(
        child: Text('相册中没有可清理的照片', style: TextStyle(color: Colors.black54)),
      );
    }
    if (state.isSessionFinished) return _buildCompleted(state, controller);
    return _buildSwipeArea(state, controller);
  }

  Widget _buildError(CleanupState state, CleanupController controller) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.perm_media_outlined, color: Colors.black45, size: 48),
          const SizedBox(height: 12),
          Text(state.error!, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: PermissionService.instance.openSettings,
            child: const Text('去设置'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => controller.load(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeArea(CleanupState state, CleanupController controller) {
    final current = state.currentItem!;
    final next = state.nextItem;

    return Column(
      children: [
        _buildHeader(state),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Stack(
              children: [
                // 下一张卡片(垫底,预加载)
                if (next != null)
                  Positioned.fill(
                    child: Transform.scale(
                      scale: 0.94,
                      child: SwipeCard(
                        key: ValueKey(next.id),
                        item: next,
                        index: state.currentIndex + 1,
                        total: state.items.length,
                        onSwiped: (_) {},
                      ),
                    ),
                  ),
                // 当前卡片(可滑动)
                Positioned.fill(
                  child: SwipeCard(
                    key: ValueKey(current.id),
                    item: current,
                    index: state.currentIndex,
                    total: state.items.length,
                    onSwiped: controller.handleSwiped,
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildActions(controller),
      ],
    );
  }

  Widget _buildHeader(CleanupState state) {
    // displayStats 让进度环跟着每一张滑动实时走
    final stats = state.displayStats;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          if (stats != null) ...[
            DailyProgressRing(stats: stats),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '本轮 ${state.currentIndex} / ${state.items.length}',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (stats != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '🔥 连续 ${stats.streakDays} 天 · 累计 ${stats.totalProcessed} 张',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '保留 ${state.keptCount} · 删除 ${state.deletedCount}',
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(CleanupController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          const Text(
            '左滑保留 · 右滑删除',
            style: TextStyle(color: Colors.black38, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.check,
                  label: '保留',
                  color: const Color(0xFF34C759),
                  onTap: () => controller.handleSwiped(SwipeDirection.keep),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _actionButton(
                  icon: Icons.close,
                  label: '删除',
                  color: const Color(0xFFFF3B30),
                  onTap: () => controller.handleSwiped(SwipeDirection.delete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 一轮滑完、但今日配额还没满
  Widget _buildCompleted(CleanupState state, CleanupController controller) {
    final stats = state.stats;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✨', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            '这一轮完成',
            style: TextStyle(color: Colors.black87, fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            '共处理 ${state.items.length} 张 · 保留 ${state.keptCount} · 删除 ${state.deletedCount}',
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          if (stats != null) ...[
            const SizedBox(height: 6),
            Text(
              '今日进度 ${stats.todayProcessed}/${stats.quota} · 还剩 ${stats.remaining} 张',
              style: const TextStyle(color: Colors.black38, fontSize: 13),
            ),
          ],
          if (state.committing) ...[
            const SizedBox(height: 12),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  '正在提交删除…',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => controller.nextRound(),
            child: const Text('继续下一轮'),
          ),
        ],
      ),
    );
  }

  /// 今日配额达成的庆祝页(多邻国式)
  ///
  /// 突出「连续打卡」这个留存钩子,并给出累计战果与「明天继续」的引导。
  Widget _buildCelebration(CleanupState state) {
    final stats = state.stats;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              state.justCompletedQuota ? '今日清理完成' : '今日已完成',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (stats != null) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text(
                    '连续 ${stats.streakDays} 天',
                    style: const TextStyle(
                      color: Color(0xFFFF9500),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '今日完成 ${stats.todayProcessed} 张',
                style: const TextStyle(color: Colors.black87, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                '累计清理 ${stats.totalProcessed} 张 · 释放 ${stats.freedLabel}',
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ],
            if (state.committing) ...[
              const SizedBox(height: 16),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '正在提交删除…',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            const Text(
              '明天再来,保持连击 👋',
              style: TextStyle(color: Colors.black38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
