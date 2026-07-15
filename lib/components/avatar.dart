import 'package:flutter/material.dart';
import 'package:inter_knot/components/cached_image.dart';
import 'package:inter_knot/gen/assets.gen.dart';

class Avatar extends StatelessWidget {
  const Avatar(
    this.src, {
    super.key,
    this.size = 40,
    this.onTap,
  });

  final String? src;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasSrc = src != null && src!.trim().isNotEmpty;
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(1, 9999);
    final avatar = ClipOval(
      child: !hasSrc
          ? Assets.images.profilePhoto.image(
              height: size,
              width: size,
              fit: BoxFit.cover,
            )
          : CachedImage(
              url: src!.trim(),
              width: size,
              height: size,
              cacheWidth: cacheSize,
              cacheHeight: cacheSize,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              errorBuilder: (_) => Assets.images.profilePhoto.image(
                height: size,
                width: size,
                fit: BoxFit.cover,
              ),
            ),
    );
    if (onTap == null) return avatar;
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: avatar,
    );
  }
}
