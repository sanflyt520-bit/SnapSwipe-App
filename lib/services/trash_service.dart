import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

/// 批量删除的执行结果
class TrashResult {
  const TrashResult({
    required this.successIds,
    required this.failedIds,
    this.usedPermanentFallback = false,
  });

  /// 成功进入回收站 / 被删除的资源 ID
  final List<String> successIds;

  /// 删除失败的资源 ID(用户取消系统授权、资源不存在等)
  final List<String> failedIds;

  /// 是否降级为永久删除
  /// true 表示 Android 10(API 29)及以下,系统无回收站,文件将被直接删除
  final bool usedPermanentFallback;

  int get successCount => successIds.length;
  int get failedCount => failedIds.length;
  bool get isEmpty => successIds.isEmpty && failedIds.isEmpty;
}

/// 相册删除 / 回收服务
///
/// ## Android 版本策略
/// - **Android 11+(API 30+)**: 走 [moveToTrash],文件进系统回收站,
///   用户可在系统相册 App 的回收站里再恢复(通常保留 30 天),等于双重保险。
/// - **Android 10(API 29)**: 系统没有回收站概念,降级为 [deleteWithIds],
///   通常是**永久删除**。因此在 API 29 上删除前必须让用户明确知晓。
///
/// ## 为什么必须批量提交
/// `moveToTrash` 底层是 `MediaStore.createTrashRequest`,**每次调用都会弹一次系统确认框**。
/// 如果每划走一张就单独提交,用户会遭遇连续弹窗,体验无法接受。
/// 所以统一收集待删除项,在合适时机一次性提交(只弹一次)。
class TrashService {
  /// 批量移入回收站
  ///
  /// [entities] 待删除的资源对象列表。
  /// 返回成功 / 失败的 ID,以及是否降级为永久删除。
  Future<TrashResult> moveToTrash(List<AssetEntity> entities) async {
    if (entities.isEmpty) {
      return const TrashResult(successIds: [], failedIds: []);
    }

    final allIds = entities.map((e) => e.id).toList();

    if (Platform.isAndroid) {
      try {
        // Android 11+ 走系统回收站
        final trashedIds =
            await PhotoManager.editor.android.moveToTrash(entities);
        return _buildResult(
          allIds,
          trashedIds,
          usedPermanentFallback: false,
        );
      } catch (_) {
        // API 29 及以下不支持 moveToTrash,降级为直接删除(可能永久)
        final deletedIds = await PhotoManager.editor.deleteWithIds(allIds);
        return _buildResult(
          allIds,
          deletedIds,
          usedPermanentFallback: true,
        );
      }
    }

    // iOS: deleteWithIds 会进系统「最近删除」,30 天内可恢复
    final deletedIds = await PhotoManager.editor.deleteWithIds(allIds);
    return _buildResult(allIds, deletedIds, usedPermanentFallback: false);
  }

  /// 从系统回收站恢复(Android 11+)
  ///
  /// 注意:这里传入的 [entities] 必须是删除前保留的实例。
  /// 进入回收站的资源会从常规 MediaStore 查询中隐藏,重新拿不到。
  ///
  /// 该方法同样会弹系统确认框,适合做「删除历史 / 找回」这类低频功能的兜底,
  /// 高频撤销请走「延迟删除」(见 SwipePage 的 5 秒撤销窗口)。
  Future<List<String>> restoreFromTrash(List<AssetEntity> entities) async {
    if (entities.isEmpty || !Platform.isAndroid) return <String>[];
    try {
      return await PhotoManager.editor.android.restoreFromTrash(entities);
    } catch (_) {
      return <String>[];
    }
  }

  TrashResult _buildResult(
    List<String> allIds,
    List<String> processedIds, {
    required bool usedPermanentFallback,
  }) {
    final processed = processedIds.toSet();
    return TrashResult(
      successIds: allIds.where((id) => processed.contains(id)).toList(),
      failedIds: allIds.where((id) => !processed.contains(id)).toList(),
      usedPermanentFallback: usedPermanentFallback,
    );
  }
}
