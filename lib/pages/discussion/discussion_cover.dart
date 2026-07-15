import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:inter_knot/components/cached_image.dart';
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
    this.isMobile = false,
    this.maxHeight,
    this.borderRadius,
  });

  final DiscussionModel discussion;
  final void Function(double aspectRatio)? onImageLoaded;
  final bool isMobile;
  final double? maxHeight;
  final BorderRadius? borderRadius;

  @override
  State<Cover> createState() => _CoverState();
}

class _CoverState extends State<Cover> {
  final _controller = PageController();
  int _currentIndex = 0;

  double? _lastReportedAspectRatio;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final covers = widget.discussion.covers;

    final coverRadius = widget.borderRadius ?? BorderRadius.circular(8);

    if (covers.isEmpty) {
      return ClipRRect(
        borderRadius: coverRadius,
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
            borderRadius: coverRadius,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dpr = MediaQuery.devicePixelRatioOf(context);
                final maxWidth = constraints.maxWidth;
                final maxHeight = constraints.maxHeight;
                final cacheWidth = maxWidth.isFinite
                    ? (maxWidth * dpr).ceil().clamp(1, 9999)
                    : null;
                final cacheHeight = maxHeight.isFinite
                    ? (maxHeight * dpr).ceil().clamp(1, 9999)
                    : null;

                return CachedImage(
                  url: url,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  cacheWidth: cacheWidth,
                  cacheHeight: cacheHeight,
                  onImageInfo: widget.onImageLoaded == null
                      ? null
                      : (size) {
                          if (size.width <= 0 || size.height <= 0) return;
                          final aspectRatio = size.width / size.height;
                          if (_lastReportedAspectRatio == aspectRatio) return;
                          _lastReportedAspectRatio = aspectRatio;
                          widget.onImageLoaded?.call(aspectRatio);
                        },
                  loadingBuilder: (_, __) => const SizedBox.shrink(),
                  errorBuilder: (_) => Assets.images.defaultCover.image(
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    final multiHeight = widget.maxHeight ?? 220;
    return SizedBox(
      height: multiHeight,
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
                      borderRadius: coverRadius,
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
