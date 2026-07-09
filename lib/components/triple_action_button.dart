import 'package:flutter/material.dart';
import 'package:inter_knot/constants/globals.dart';

/// B 站风格「长按点赞 → 一键三连」触发器。
///
/// 职责：仅做手势识别 + 蓄力圆环，不发请求。
/// - 短按 → 触发 [onLike]。
/// - 长按（约 500ms，圆环填满）→ 触发 [onTriple]；若 [canTriple]=false
///   则回退为短按行为。
/// - [canTriple]=false 的场景：本人帖、匿名帖、未登录。
class TripleActionButton extends StatefulWidget {
  final bool liked;
  final int likesCount;
  final bool canTriple;
  final bool busy;
  final VoidCallback onLike;
  final VoidCallback onTriple;

  const TripleActionButton({
    super.key,
    required this.liked,
    required this.likesCount,
    required this.canTriple,
    this.busy = false,
    required this.onLike,
    required this.onTriple,
  });

  @override
  State<TripleActionButton> createState() => _TripleActionButtonState();
}

class _TripleActionButtonState extends State<TripleActionButton>
    with SingleTickerProviderStateMixin {
  static const _chargeMs = 500;

  late final AnimationController _chargeController;
  bool _charging = false;

  @override
  void initState() {
    super.initState();
    _chargeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _chargeMs),
    )..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _chargeController.dispose();
    super.dispose();
  }

  void _startCharge(TapDownDetails _) {
    if (widget.busy || !widget.canTriple) return;
    _charging = true;
    _chargeController.forward(from: 0);
  }

  void _stopCharge() {
    if (!_charging) return;
    if (mounted) setState(() => _charging = false);
    _chargeController.reset();
  }

  void _handleLike() {
    _stopCharge();
    if (!widget.busy) widget.onLike();
  }

  void _handleTriple() {
    _stopCharge();
    if (widget.busy) return;
    if (!widget.canTriple) {
      widget.onLike();
      return;
    }
    widget.onTriple();
  }

  @override
  Widget build(BuildContext context) {
    final liked = widget.liked;
    final count = widget.likesCount;
    final canTriple = widget.canTriple;

    final message = canTriple
        ? (liked ? '取消点赞，长按一键三连' : '点赞，长按一键三连')
        : (liked ? '取消点赞' : '点赞');

    const activeColor = Color(0xffD7FF00);
    final inactiveColor = Colors.grey;

    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.manual,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleLike,
        onTapDown: _startCharge,
        onTapCancel: _stopCharge,
        onLongPress: _handleTriple,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xff222222),
            borderRadius: BorderRadius.circular(maxRadius),
            border: Border.all(color: const Color(0xff2D2D2D), width: 4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                      color: liked ? activeColor : null,
                      size: 22,
                    ),
                    if (_charging)
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          value: _chargeController.value,
                          strokeWidth: 2,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(activeColor),
                        ),
                      ),
                  ],
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 13,
                    color: liked ? activeColor : inactiveColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
