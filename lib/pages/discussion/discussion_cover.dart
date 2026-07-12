import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/components/discussion_card.dart'
    show NetworkImageBox;
import 'package:inter_knot/components/image_viewer.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/models/discussion.dart';

class Cover extends StatefulWidget {
  const Cover({
    super.key,
    required this.discussion,
    this.onImageLoaded,
  });

  final DiscussionModel discussion;
  final void Function(double aspectRatio)? onImageLoaded;

  @override
  State<Cover> createState() => _CoverState();
}

class _CoverState extends State<Cover> {
  final _controller = PageController();
  int _currentIndex = 0;

  /// 防止单张封面 Image 的 frameBuilder 反复 post frame 并泄漏 ImageStreamListener。
  bool _aspectRatioReported = false;
  ImageStream? _aspectRatioImageStream;
  ImageStreamListener? _aspectRatioImageListener;
  double? _lastReportedAspectRatio;

  @override
  void dispose() {
    if (_aspectRatioImageStream != null &&
        _aspectRatioImageListener != null) {
      try {
        _aspectRatioImageStream!.removeListener(_aspectRatioImageListener!);
      } catch (_) {
        // ImageStreamCompleter 可能已经 dispose，安全忽略
      }
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final covers = widget.discussion.covers;

    if (covers.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Assets.images.defaultCover.image(fit: BoxFit.contain),
      );
    }

    if (covers.length == 1) {
      final url = covers.first;
      final heroTag = 'cover-${widget.discussion.id}-0';

      return Hero(
        tag: heroTag,
        child: ClickRegion(
          onTap: () => ImageViewer.show(
            context,
            imageUrls: covers,
            heroTagPrefix: 'cover-${widget.discussion.id}',
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return const SizedBox.shrink();
              },
              errorBuilder: (context, error, stackTrace) =>
                  Assets.images.defaultCover.image(fit: BoxFit.contain),
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (frame != null &&
                    widget.onImageLoaded != null &&
                    !_aspectRatioReported) {
                  _aspectRatioReported = true;
                  // 图片加载完成，获取实际尺寸
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _aspectRatioImageStream = NetworkImage(url).resolve(
                      const ImageConfiguration(),
                    );
                    _aspectRatioImageListener = ImageStreamListener((info, _) {
                      if (!mounted) {
                        info.dispose();
                        return;
                      }
                      final image = info.image;
                      final width = image.width;
                      final height = image.height;
                      info.dispose();

                      if (width <= 0 || height <= 0) return;

                      final aspectRatio = width / height;
                      if (_lastReportedAspectRatio == aspectRatio) return;
                      _lastReportedAspectRatio = aspectRatio;

                      widget.onImageLoaded?.call(aspectRatio);
                    });
                    _aspectRatioImageStream?.addListener(
                      _aspectRatioImageListener!,
                    );
                  });
                }
                return child;
              },
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ScrollConfiguration(
            behavior: const _CoverScrollBehavior(),
            child: PageView.builder(
              controller: _controller,
              itemCount: covers.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final url = covers[index];
                final heroTag = 'cover-${widget.discussion.id}-$index';

                return Hero(
                  tag: heroTag,
                  child: ClickRegion(
                    onTap: () => ImageViewer.show(
                      context,
                      imageUrls: covers,
                      initialIndex: index,
                      heroTagPrefix: 'cover-${widget.discussion.id}',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: NetworkImageBox(
                        url: url,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        gaplessPlayback: true,
                        loadingBuilder: (context, progress) =>
                            const SizedBox.shrink(),
                        errorBuilder: (context) => Container(
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white,
                          ),
                        ),
                        fadeInDuration: const Duration(milliseconds: 400),
                        fadeOutDuration: const Duration(milliseconds: 200),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (covers.length > 1)
            Positioned.fill(
              left: 8,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _NavButton(
                  icon: Icons.chevron_left,
                  onTap: () => _goToPage(_currentIndex - 1, covers.length),
                ),
              ),
            ),
          if (covers.length > 1)
            Positioned.fill(
              right: 8,
              child: Align(
                alignment: Alignment.centerRight,
                child: _NavButton(
                  icon: Icons.chevron_right,
                  onTap: () => _goToPage(_currentIndex + 1, covers.length),
                ),
              ),
            ),
          Positioned(
            bottom: 8,
            child: IgnorePointer(
              child: SizedBox(
                height: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(covers.length, (i) {
                    final isActive = i == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xffFBC02D)
                            : const Color(0xff2E2E2E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToPage(int index, int total) {
    if (total <= 1) return;
    final target = index.clamp(0, total - 1);
    if (target == _currentIndex) return;
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xB3000000),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _CoverScrollBehavior extends MaterialScrollBehavior {
  const _CoverScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };
}
