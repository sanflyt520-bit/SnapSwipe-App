import 'package:photo_manager/photo_manager.dart';

/// 媒体类型(与 photo_manager 的 AssetType 解耦,便于领域层使用)
enum MediaType { image, video }

/// 媒体处理状态(对应方案中的三态机)
enum MediaStatus { pending, kept, deleted }

/// 单个相册媒体的领域模型
class MediaItem {
  const MediaItem({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.sizeBytes,
    required this.width,
    required this.height,
    this.durationMs,
    this.assetEntity,
    this.status = MediaStatus.pending,
  });

  /// 系统资源唯一 ID(photo_manager 的 AssetEntity.id,回收站操作用)
  final String id;

  final MediaType type;

  /// 拍摄/创建日期
  final DateTime createdAt;

  /// 文件大小(字节)
  final int sizeBytes;

  final int width;
  final int height;

  /// 视频时长(毫秒),图片为 null
  final int? durationMs;

  /// 底层资源引用(用于取缩略图 / 原图 / 删除)
  final AssetEntity? assetEntity;

  final MediaStatus status;

  bool get isVideo => type == MediaType.video;

  /// 人类可读的文件大小
  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 视频时长标签,如 0:32
  String? get durationLabel {
    final d = durationMs;
    if (d == null) return null;
    final totalSec = d ~/ 1000;
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  MediaItem copyWith({MediaStatus? status}) {
    return MediaItem(
      id: id,
      type: type,
      createdAt: createdAt,
      sizeBytes: sizeBytes,
      width: width,
      height: height,
      durationMs: durationMs,
      assetEntity: assetEntity,
      status: status ?? this.status,
    );
  }

  /// 从 photo_manager 的 AssetEntity 转换
  /// [sizeBytes] 由调用方异步获取(photo_manager 的 fileSize 是异步的)
  factory MediaItem.fromAsset(AssetEntity asset, {int sizeBytes = 0}) {
    return MediaItem(
      id: asset.id,
      type: asset.type == AssetType.video ? MediaType.video : MediaType.image,
      createdAt: asset.createDateTime,
      sizeBytes: sizeBytes,
      width: asset.width,
      height: asset.height,
      durationMs: asset.type == AssetType.video
          ? asset.videoDuration.inMilliseconds
          : null,
      assetEntity: asset,
    );
  }
}
