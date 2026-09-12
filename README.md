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
- **真实删除** — 走系统回收站(详见下方「删除机制」)
- **5 秒撤销** — 删除后弹出提示,可一键反悔把卡片放回
- **辅助操作按钮 + 完成统计页**
- **每日配额** — 默认 35 张/天(可配 30-50),单次会话最多 15 张(详见「每日配额与打卡」)
- **连续打卡** — 🔥 streak,断档自动归零,达成配额弹多邻国式庆祝页
- **进度环 + 累计统计** — 今日完成度环形进度、累计清理张数、累计释放空间

## 🗑 删除机制

删除采用**两阶段设计**,目的是同时兼顾「可撤销」和「不被系统弹窗淹没」:

1. **滑动阶段** — 右滑只把照片放进「待删除队列」,**不会立刻真删**。
   此时弹出 SnackBar,5 秒内点「撤销」即可把卡片退回。
2. **提交阶段** — 倒计时结束后,队列里的照片**一次性批量提交**到系统回收站。

**为什么这么设计:**

- photo_manager 虽有 `restoreFromTrash`,但每次调用都要弹系统确认框,
  拿来做高频撤销不可行。靠「延迟提交」,撤销时完全不弹框,手感才顺。
- `moveToTrash` 底层是 `MediaStore.createTrashRequest`,**每调用一次弹一次系统框**。
  若每划一张就提交,用户会被连续弹窗淹没,因此必须攒批提交。

| Android 版本        | 行为                                                  |
| ----------------- | --------------------------------------------------- |
| Android 11+ (API 30+) | `moveToTrash` → 系统回收站,相册 App 内可再次恢复(双重保险)      |
| Android 10 (API 29)  | 无回收站,降级 `deleteWithIds`,**永久删除**                   |
| iOS               | `deleteWithIds` → 系统「最近删除」,30 天内可恢复                |

---

## 📅 每日配额与打卡(多邻国式)

一次性清空相册容易疲劳和误删,所以产品走「每天清一点」的模式。

| 参数     | 默认值     | 说明                        |
| ------ | -------- | ------------------------- |
| 每日配额   | 35 张     | 可在 30-50 间调整                |
| 单次会话   | ≤ 15 张   | 约 2-3 分钟,避免一次劝退            |
| 重置时间   | 本地 0 点   | 跨天自动把「今日已处理」归零             |
| 连续打卡   | streak 🔥 | 断档超过 1 天自动归零                |

**关键实现细节:**

- **配额决定取多少照片** — 每次会话只取「今日剩余配额」与「15」的较小值,
  不是固定拉 100 张。配额满了就不再取照片,直接进庆祝页。
- **跨天重置只认年月日** — 日期全部归一化到 `yyyy-MM-dd` 再比较,
  否则时分秒会让「今天」和「昨天」算错。
- **streak 的四种情况** — 首次=1;同一天再清=不变;隔了 1 天=+1;隔了 2 天及以上=重置为 1。
- **「处理」包含保留** — 保留同样是做了一次决策,所以计入今日进度。
  只有**删除**的才计入「释放空间」。
- **达成配额只庆祝一次** — 靠「由未达标变为达标」这个跳变判定,不会每轮都弹。

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
├── main.dart                      # 应用入口(浅色主题,Material 3)
├── models/
│   ├── media_item.dart            # 媒体领域模型(图片/视频、三态机)
│   ├── daily_stats.dart           # 每日统计模型(进度/配额/streak/累计)
│   ├── swipe_direction.dart       # 滑动方向枚举(左滑保留/右滑删除)
│   └── cleanup_state.dart         # 清理会话的不可变状态 + 派生值
├── providers/
│   ├── service_providers.dart     # 服务实例注入(相册/删除/统计)
│   └── cleanup_provider.dart      # 清理会话 controller(配额/撤销/提交/结算)
├── services/
│   ├── permission_service.dart    # 权限申请封装
│   ├── media_repository.dart      # 相册读取封装(缩略图/原图)
│   ├── trash_service.dart         # 删除/回收封装(系统回收站、低版本降级)
│   └── stats_service.dart         # 配额、连续打卡、累计统计的持久化
└── features/
    └── swipe/
        ├── swipe_card.dart        # 卡片滑动手势组件(核心交互)
        ├── swipe_page.dart        # 滑动主页面(纯 UI:读状态 + 转发事件)
        └── widgets/
            └── daily_progress_ring.dart  # 今日进度环(多邻国风格)
```

### 架构分层

| 层   | 目录                | 职责                        |
| --- | ----------------- | ------------------------- |
| 表现层 | `features/swipe/` | 卡片 UI、手势、进度环;只读状态、只发事件    |
| 状态层 | `providers/`      | `CleanupController`:业务与编排    |
| 服务层 | `services/`       | 相册读取、权限申请、删除回收、统计持久化        |
| 领域层 | `models/`         | `MediaItem` / `DailyStats` / `CleanupState` |

模型用 `MediaType`(image/video)与 `MediaStatus`(pending/kept/deleted) 三态机,与 photo_manager 解耦。
删除统一由服务层的 `TrashService` 负责,Android 版本差异在这层收敛掉;
配额与打卡同理收敛在 `StatsService`,领域模型 `DailyStats` 只描述数据、不碰存储。

### 状态管理:Riverpod

业务全部收在 `CleanupController`(一个 `Notifier<CleanupState>`)里,页面只做两件事:
`ref.watch` 读状态、`ref.read(notifier)` 调方法。**没有任何业务逻辑留在 Widget 里。**

几个刻意的取舍:

- **状态不可变** —— `CleanupState` 全字段 final,变更靠 `copyWith`,派生值(当前卡片、是否滑完、展示用统计)在状态内算好,UI 不做计算。
- **SnackBar 不进 controller** —— Notifier 拿不到 `BuildContext`,所以状态只描述「要提示什么」(`snack` + 递增的 `snackSeq`),由页面 `ref.listen` 后展示。`snackSeq` 是为了让相同文案也能再次触发。
- **provider 不 autoDispose** —— 用的是 `NotifierProvider` 而非 `AutoDisposeNotifierProvider`:退后台不丢状态,且 `ref.onDispose` 只在应用退出时触发,正好用来兜底提交未结算的删除,避免漏删。
- **进度环实时性** —— 落盘一轮一次,但 `displayStats` 在展示时叠加「本轮已滑张数」,所以滑一张走一格,不会重复计数。

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
| 状态管理        | `flutter_riverpod ^2.4.0`(实装 2.6.1) |
| 日期格式化       | `intl ^0.19.0`               |
| 本地持久化       | `shared_preferences ^2.2.0`  |

> 持久化选型说明:M3 的数据都是简单键值(今日计数、streak、累计),用 KV 存储足够轻。
> 设计方案里提到的 drift(SQLite)留到 M4「已保留归档」需要结构化查询时再引入,避免过早加重。

---

## 🗺 路线图

- **M1(已完成)** — 相册读取 + 卡片滑动交互原型
- **M2(已完成)** — ✅ 系统回收站删除 + ✅ 5 秒撤销 + ✅ Riverpod 状态管理
- **M3(已完成主体)** — ✅ 每日配额 35 张 + ✅ 连续打卡 streak + ✅ 进度环与累计统计 + ✅ 达成庆祝页;⬜ 成就徽章
- **M4** — 首次引导 + 已保留归档 + 测试打磨
- **M5(可选)** — iOS 适配

> **成就徽章未做**:设计方案 3.3 提到的徽章(累计 100/500/1000 张、连续 7/30 天等)
> 属于锦上添花,数据基础(streak、累计)已经就绪,随时可加。
>
> **单元测试未做**:Riverpod 重构的主要收益之一就是 `CleanupController` 可以脱离 UI 直接测,
> 但当前还没补测试用例,建议 M4 打磨阶段一并补上。

---

## ⚠️ 已知事项

1. **photo_manager 应用 Kotlin Gradle Plugin(KGP)警告** — Flutter 未来版本可能因此构建失败,当前版本不影响。升级 Flutter 时需关注 photo_manager 的新版本。
2. **Android 10(API 29)是永久删除** — 该版本没有系统回收站,降级走 `deleteWithIds`。此版本上删除不可从回收站找回,后续可加二次确认弹窗。
3. **提交删除时会弹一次系统确认框** — 这是 `MediaStore.createTrashRequest` 的系统行为(Android 11+),无法绕过。已通过批量提交把弹窗次数压到最少。
