import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../models/media_item.dart';
import '../../models/swipe_direction.dart';

/// 卡片式全屏滑动组件(核心交互)
///
/// 手势判定采用「位移 + 速度」双阈值:
/// - 位移阈值:屏幕宽度的 40%
/// - 速度阈值:1000 px/s(甩动速度达标时,位移不足也触发)
///
/// 视觉反馈:
/// - 卡片跟手位移 + 旋转(最大 15°)
/// - 左滑渐显绿色「保留」标记,右滑渐显红色「删除」标记
class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.item,
    required this.index,
    required this.total,
    required this.onSwiped,
    this.thumbnail,
  });

  final MediaItem item;
  final int index;
  final int total;
  final ValueChanged<SwipeDirection> onSwiped;

  /// 预加载好的缩略图字节(由父组件传入,避免重复解码)
  final Uint8List? thumbnail;

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard>
    with SingleTickerProviderStateMixin {
  static const double _maxRotation = 15.0; // 度
  static const double _displacementRatio = 0.4; // 位移阈值(占屏宽比例)
  static const double _velocityThreshold = 1000.0; // 速度阈值 px/s

  late final AnimationController _controller;
  Animation<Offset>? _offsetAnimation;

  Offset _offset = Offset.zero;
  Uint8List? _thumbnail;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(_onTick);
    _thumbnail = widget.thumbnail;
    if (_thumbnail == null) {
      _loadThumbnail();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTick() {
    final anim = _offsetAnimation;
    if (anim == null) return;
    setState(() => _offset = anim.value);
  }

  Future<void> _loadThumbnail() async {
    final asset = widget.item.assetEntity;
    if (asset == null) return;
    try {
      final data = await asset.thumbnailDataWithSize(
        const ThumbnailSize(512, 512),
      );
      if (mounted) setState(() => _thumbnail = data);
    } catch (_) {
      // 缩略图加载失败时展示占位图
    }
  }

  // ---- 手势处理 ----

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _offset += details.delta;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * _displacementRatio;
    final velocity = details.primaryVelocity ?? 0;

    if (_offset.dx < -threshold || velocity < -_velocityThreshold) {
      _flyOut(SwipeDirection.keep);
    } else if (_offset.dx > threshold || velocity > _velocityThreshold) {
      _flyOut(SwipeDirection.delete);
    } else {
      _springBack();
    }
  }

  void _flyOut(SwipeDirection direction) {
    final screenWidth = MediaQuery.of(context).size.width;
    final targetX = direction == SwipeDirection.delete
        ? screenWidth * 1.5
        : -screenWidth * 1.5;

    HapticFeedback.lightImpact();

    _offsetAnimation = Tween<Offset>(
      begin: _offset,
      end: Offset(targetX, _offset.dy * 1.2),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward(from: 0).whenComplete(() {
      if (mounted) widget.onSwiped(direction);
    });
  }

  void _springBack() {
    _offsetAnimation = Tween<Offset>(
      begin: _offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward(from: 0);
  }

  // ---- 构建 ----

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * _displacementRatio;

    // 旋转角度(左滑为正、右滑为负,与方向相反更自然)
    final rotation = (_offset.dx / screenWidth) * _maxRotation;

    // 标记透明度(0 → 1)
    final keepOpacity = (-_offset.dx / threshold).clamp(0.0, 1.0);
    final deleteOpacity = (_offset.dx / threshold).clamp(0.0, 1.0);

    return Transform.translate(
      offset: _offset,
      child: Transform.rotate(
        angle: rotation * 0.0174533, // 度转弧度
        child: GestureDetector(
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCardContent(),
              _buildOverlayMark(keepOpacity, deleteOpacity),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_thumbnail != null)
            Image.memory(_thumbnail!, fit: BoxFit.contain)
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.black45),
            ),
          _buildTopInfoBar(),
          if (widget.item.isVideo) _buildVideoBadge(),
        ],
      ),
    );
  }

  Widget _buildTopInfoBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${widget.index + 1} / ${widget.total}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _metaLabel(),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _metaLabel() {
    final item = widget.item;
    final date = '${item.createdAt.year}-'
        '${item.createdAt.month.toString().padLeft(2, '0')}-'
        '${item.createdAt.day.toString().padLeft(2, '0')}';
    final parts = [date, item.sizeLabel];
    if (item.durationLabel != null) parts.add(item.durationLabel!);
    return parts.join(' · ');
  }

  Widget _buildVideoBadge() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(
              widget.item.durationLabel ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayMark(double keepOpacity, double deleteOpacity) {
    return IgnorePointer(
      child: Stack(
        children: [
          // 左滑:保留标记(绿色)
          Opacity(
            opacity: keepOpacity,
            child: Align(
              alignment: Alignment.topLeft,
              child: _markContainer(
                text: '✓ 保留',
                color: const Color(0xFF34C759),
              ),
            ),
          ),
          // 右滑:删除标记(红色)
          Opacity(
            opacity: deleteOpacity,
            child: Align(
              alignment: Alignment.topRight,
              child: _markContainer(
                text: '✗ 删除',
                color: const Color(0xFFFF3B30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _markContainer({required String text, required Color color}) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
