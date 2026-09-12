import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/media_repository.dart';
import '../services/stats_service.dart';
import '../services/trash_service.dart';

/// 相册读取
final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository();
});

/// 删除 / 回收(系统回收站、低版本降级)
final trashServiceProvider = Provider<TrashService>((ref) {
  return TrashService();
});

/// 每日配额 / 连续打卡 / 累计统计
final statsServiceProvider = Provider<StatsService>((ref) {
  return StatsService();
});
