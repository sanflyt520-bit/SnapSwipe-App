# SnapSwipe — 相册清理 App

> 短视频式(Tinder 式)相册清理工具:左右滑动快速决定照片/视频的去留,多邻国式每日轻量清理。  
> Android 优先,基于 Flutter 跨平台(iOS 后续适配)。

---

## ✨ 功能特性

- **相册读取** — photo_manager 读取图片 + 视频,时间倒序
- **权限申请** — Android 13+ 分项权限自动适配(README_MEDIA_IMAGES / VIDEO / 旧版存储权限)
- **卡片式全屏滑动** — 跟手位移 + 旋转、绿/红判定标记、飞出/回弹动画
- **双阈值手势判定** — 位移 + 速度双条件触发
- **视频时长角标** — 元信息展示(日期 / 大小 / 时长 / 序号)
- **辅助操作按钮 + 完成统计页**

> ⚠️ M1 为**交互原型**,"删除"目前只是本地计数,**不会真实删除文件**。真实删除(系统回收站)将在 M2 通过 `MediaStore.createTrashRequest` 实现,详见下方路线图。

---

## 🚀 快速开始

### 环境要求

| 依赖            | 版本                           |
| ------------- | ---------------------------- |
| Flutter SDK   | ≥ 3.47(含 Dart)               |
| Android SDK   | Platform 36 + Build-Tools 36 |
| JDK           | 17                           |
| minSdkVersion | 21                           |
| compileSdk    | 36                           |

> 本机开发环境已配置完毕(Flutter / JDK / Android SDK 均位于 `G:\buddyG\`,并已配置腾讯 Gradle 镜像与阿里云 Maven 镜像加速)。

### 安装依赖

```bash
cd snapswipe
flutter pub get
```

### 构建 APK

```bash
flutter build apk --debug
```

产物路径:`build/app/outputs/flutter-apk/app-debug.apk`

> ✅ 已验证构建成功(约 15 分钟,首次需下载 Gradle 依赖)。  
> 正式发布用 `flutter build apk --release`,体积可降至 20~30 MB。

### 运行到设备

```bash
# 真机 / 模拟器
flutter run

# 或安装已构建的 APK
flutter install
```

---

## 📁 项目结构

```
lib/
├── main.dart                      # 应用入口(暗色主题,Material 3)
├── models/
│   └── media_item.dart            # 媒体领域模型(图片/视频、三态机)
├── services/
│   ├── permission_service.dart    # 权限申请封装
│   └── media_repository.dart      # 相册读取封装(缩略图/原图)
└── features/
    └── swipe/
        ├── swipe_card.dart        # 卡片滑动手势组件(核心交互)
        └── swipe_page.dart        # 滑动主页面(堆叠/统计/完成页)
```

### 架构分层

| 层   | 目录                | 职责                 |
| --- | ----------------- | ------------------ |
| 表现层 | `features/swipe/` | 卡片 UI、手势、页面状态      |
| 服务层 | `services/`       | 相册读取、权限申请          |
| 领域层 | `models/`         | `MediaItem` 模型与三态机 |

模型用 `MediaType`(image/video)与 `MediaStatus`(pending/kept/deleted) 三态机,与 photo_manager 解耦,便于后续接入真实删除与撤销。

---

## 🎮 交互规则

| 手势 | 动作 | 视觉反馈       |
| -- | -- | ---------- |
| 左滑 | 保留 | 绿色「✓ 保留」标记 |
| 右滑 | 删除 | 红色「✗ 删除」标记 |

| 判定参数 | 值         |
| ---- | --------- |
| 位移阈值 | 屏宽 40%    |
| 速度阈值 | 1000 px/s |
| 最大旋转 | 15°       |

---

## 🔧 权限配置(已配置)

`android/app/src/main/AndroidManifest.xml` 已声明:

```xml

<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />


<uses-permission
    android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />


<uses-permission android:name="android.permission.ACCESS_MEDIA_LOCATION" />
```

---

## 🧱 技术栈

| 用途          | 依赖                           |
| ----------- | ---------------------------- |
| 相册读取 / 缩略图  | `photo_manager ^3.0.0`       |
| 权限申请        | `permission_handler ^11.0.0` |
| 视频播放(M2 启用) | `video_player ^2.7.0`        |
| 状态管理(M2 引入) | `flutter_riverpod ^2.4.0`    |
| 日期格式化       | `intl ^0.19.0`               |

---

## 🗺 路线图

- **M1(已完成)** — 相册读取 + 卡片滑动交互原型
- **M2** — 系统回收站删除(`MediaStore.createTrashRequest`)+ 5 秒撤销 + Riverpod 状态管理
- **M3** — 每日配额(30-50 张)+ 连续打卡 + 游戏化统计
- **M4** — 首次引导 + 已保留归档 + 测试打磨
- **M5(可选)** — iOS 适配

---

## ⚠️ 已知事项

1. **photo_manager 应用 Kotlin Gradle Plugin(KGP)警告** — Flutter 未来版本可能因此构建失败,当前版本不影响。升级 Flutter 时需关注 photo_manager 的新版本。
2. **M1 删除非真实删除** — 仅本地计数,真实删除待 M2。
