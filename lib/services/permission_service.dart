import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

/// 相册权限申请服务
///
/// - Android 13+ (API 33+): photo_manager 会自动分项申请 READ_MEDIA_IMAGES / READ_MEDIA_VIDEO
/// - Android 10-12 (API 29-32): READ_EXTERNAL_STORAGE
/// - iOS(后续扩展): PHPhotoLibrary
///
/// 统一入口,后续可在此接入"去设置"引导与永久拒绝检测。
class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  /// 请求相册读取权限,返回是否已授权
  Future<bool> requestPhotoPermission() async {
    // photo_manager 针对不同 API 级别请求正确权限
    final ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth || ps.hasAccess;
  }

  /// 是否已被永久拒绝(需引导用户去系统设置)
  Future<bool> isPermanentlyDenied() async {
    final status = await Permission.photos.status;
    return status.isPermanentlyDenied;
  }

  /// 打开系统设置页
  Future<void> openSettings() => openAppSettings();
}
