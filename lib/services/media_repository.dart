import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

import '../models/media_item.dart';

/// 相册媒体读取封装(图片 + 视频)
///
/// M1: 一次性读取最近 N 张用于滑动原型验证
/// M2 优化点: 增量分页、缩略图缓存、按日期区间读取
class MediaRepository {
  MediaRepository({this.pageSize = 100});

  final int pageSize;

  /// 是否已授权
  Future<bool> hasPermission() async {
    final ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth || ps.hasAccess;
  }

  /// 读取"所有"相册中最近的 [limit] 张媒体(图片 + 视频,按时间倒序)
  Future<List<MediaItem>> fetchRecentMedia({int? limit}) async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.common, // image + video
      onlyAll: true,
    );
    if (paths.isEmpty) return [];

    // paths.first 即"所有"相册(时间倒序)
    final allAssets = paths.first;
    final count = await allAssets.assetCountAsync;
    final end = (limit ?? pageSize) > count ? count : (limit ?? pageSize);

    final assets = await allAssets.getAssetListRange(start: 0, end: end);
    // 文件大小是异步的,并行获取
    final items = await Future.wait(assets.map((a) async {
      final size = await a.fileSize;
      return MediaItem.fromAsset(a, sizeBytes: size);
    }));
    return items;
  }

  /// 获取缩略图字节(用于卡片展示)
  Future<Uint8List?> thumbnail(AssetEntity asset, {int size = 512}) {
    return asset.thumbnailDataWithSize(ThumbnailSize(size, size));
  }

  /// 获取原图字节(后续原图预览用,注意内存)
  Future<Uint8List?> original(AssetEntity asset) {
    return asset.originBytes;
  }
}
