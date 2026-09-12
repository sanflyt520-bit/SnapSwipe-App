/// 滑动方向: 左滑保留 / 右滑删除
///
/// 放在 models 而不是 UI 组件里,是为了让状态层(provider)能引用它,
/// 避免 provider 反过来依赖 features/ 下的组件文件。
enum SwipeDirection { keep, delete }
