import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Maximum decoded dimension for any cached image. Keeps the [ImageCache]
/// entries bounded and prevents OOM from decoding full-resolution uploads.
const int maxCacheDimension = 2048;

ImageProvider? cachedImageProvider(
  String? url, {
  double? dpr,
  int? width,
  int? height,
  int? cacheWidth,
  int? cacheHeight,
  Map<String, String>? headers,
  Uint8List? bytes,
  ImageProvider? imageProvider,
}) {
  if (url != null && url.trim().isNotEmpty) {
    imageProvider = CachedNetworkImageProvider(url.trim(), headers: headers);
  } else if (bytes != null && bytes.isNotEmpty) {
    imageProvider = MemoryImage(bytes);
  }

  if (imageProvider == null) return null;

  if (dpr != null && dpr > 0) {
    cacheWidth ??= (width != null ? (width * dpr).ceil() : null);
    cacheHeight ??= (height != null ? (height * dpr).ceil() : null);
  }

  cacheWidth = cacheWidth?.clamp(1, maxCacheDimension);
  cacheHeight = cacheHeight?.clamp(1, maxCacheDimension);

  if (cacheWidth == null && cacheHeight == null) return imageProvider;

  return ResizeImage(
    imageProvider,
    width: cacheWidth,
    height: cacheHeight,
    policy: ResizeImagePolicy.fit,
    allowUpscaling: true,
  );
}

class CachedImage extends StatefulWidget {
  const CachedImage({
    super.key,
    this.url,
    this.bytes,
    this.imageProvider,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.fit,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.low,
    this.gaplessPlayback = false,
    this.fadeInDuration = Duration.zero,
    this.loadingBuilder,
    this.errorBuilder,
    this.headers,
    this.semanticLabel,
    this.matchTextDirection = false,
    this.excludeFromSemantics = false,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.color,
    this.colorBlendMode,
    this.isAntiAlias = false,
    this.onImageInfo,
  });

  final String? url;
  final Uint8List? bytes;
  final ImageProvider? imageProvider;

  final void Function(Size size)? onImageInfo;

  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final BoxFit? fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final bool gaplessPlayback;
  final Duration fadeInDuration;
  final Widget Function(BuildContext context, double? progress)? loadingBuilder;
  final Widget Function(BuildContext context)? errorBuilder;
  final Map<String, String>? headers;

  final String? semanticLabel;
  final bool matchTextDirection;
  final bool excludeFromSemantics;
  final ImageRepeat repeat;
  final Rect? centerSlice;
  final Color? color;
  final BlendMode? colorBlendMode;
  final bool isAntiAlias;

  @override
  State<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {
  ImageProvider? _innerProvider;
  ImageProvider? _provider;
  double? _lastDpr;
  ImageStream? _imageInfoStream;
  ImageStreamListener? _imageInfoListener;
  bool _imageInfoReported = false;

  bool get _hasFixedSize =>
      widget.width != null ||
      widget.height != null ||
      widget.cacheWidth != null ||
      widget.cacheHeight != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateProvider();
  }

  @override
  void dispose() {
    if (_imageInfoStream != null && _imageInfoListener != null) {
      _imageInfoStream!.removeListener(_imageInfoListener!);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_providerChanged(oldWidget)) {
      _updateProvider();
    } else if (widget.onImageInfo != oldWidget.onImageInfo) {
      _attachImageInfoListener();
    }
  }

  bool _providerChanged(CachedImage oldWidget) {
    return widget.url != oldWidget.url ||
        widget.bytes != oldWidget.bytes ||
        widget.imageProvider != oldWidget.imageProvider ||
        widget.width != oldWidget.width ||
        widget.height != oldWidget.height ||
        widget.cacheWidth != oldWidget.cacheWidth ||
        widget.cacheHeight != oldWidget.cacheHeight ||
        MediaQuery.devicePixelRatioOf(context) != _lastDpr;
  }

  void _updateProvider() {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    _lastDpr = dpr;

    final inner = _createInnerProvider();
    _innerProvider = inner;

    if (inner == null) {
      _provider = null;
      _attachImageInfoListener();
      return;
    }

    if (_hasFixedSize) {
      _provider = _createResizedProvider(inner, dpr);
    } else {
      _provider = null;
    }

    _imageInfoReported = false;
    _attachImageInfoListener();
  }

  ImageProvider? _createInnerProvider() {
    if (widget.url != null && widget.url!.trim().isNotEmpty) {
      return CachedNetworkImageProvider(widget.url!.trim(), headers: widget.headers);
    }
    if (widget.bytes != null && widget.bytes!.isNotEmpty) {
      return MemoryImage(widget.bytes!);
    }
    return widget.imageProvider;
  }

  ImageProvider _createResizedProvider(
    ImageProvider inner,
    double dpr,
  ) {
    final width = widget.cacheWidth ??
        (widget.width != null ? (widget.width! * dpr).ceil() : null);
    final height = widget.cacheHeight ??
        (widget.height != null ? (widget.height! * dpr).ceil() : null);

    if (width == null && height == null) return inner;

    return ResizeImage(
      inner,
      width: width?.clamp(1, maxCacheDimension),
      height: height?.clamp(1, maxCacheDimension),
      policy: ResizeImagePolicy.fit,
      allowUpscaling: true,
    );
  }

  void _attachImageInfoListener() {
    if (_imageInfoStream != null && _imageInfoListener != null) {
      _imageInfoStream!.removeListener(_imageInfoListener!);
      _imageInfoStream = null;
      _imageInfoListener = null;
    }

    final onImageInfo = widget.onImageInfo;
    final provider = _provider;
    if (onImageInfo == null || provider == null) return;

    final stream = provider.resolve(ImageConfiguration.empty);
    _imageInfoStream = stream;
    _imageInfoListener = ImageStreamListener((info, _) {
      if (_imageInfoReported) {
        info.dispose();
        return;
      }
      _imageInfoReported = true;

      final dpr = _lastDpr ?? 1.0;
      final size = Size(
        info.image.width / info.scale / dpr,
        info.image.height / info.scale / dpr,
      );
      info.dispose();

      if (!mounted) return;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onImageInfo?.call(size);
      });
    });
    stream.addListener(_imageInfoListener!);
  }

  @override
  Widget build(BuildContext context) {
    final inner = _innerProvider;
    if (inner == null) {
      return _buildError(context);
    }

    if (_hasFixedSize) {
      final provider = _provider;
      if (provider == null) return _buildError(context);
      return _buildImage(context, provider);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : maxWidth * 3;

        final width = (maxWidth * dpr).ceil().clamp(1, maxCacheDimension);
        final height = (maxHeight * dpr).ceil().clamp(1, maxCacheDimension);

        final provider = ResizeImage(
          inner,
          width: width,
          height: height,
          policy: ResizeImagePolicy.fit,
          allowUpscaling: true,
        );

        return _buildImage(context, provider);
      },
    );
  }

  Widget _buildImage(BuildContext context, ImageProvider provider) {
    return Image(
      image: provider,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      filterQuality: widget.filterQuality,
      gaplessPlayback: widget.gaplessPlayback,
      errorBuilder: widget.errorBuilder != null
          ? (context, error, stackTrace) => widget.errorBuilder!(context)
          : null,
      loadingBuilder: widget.loadingBuilder != null
          ? (context, child, progress) {
              if (progress == null) return child;
              final value = progress.expectedTotalBytes != null &&
                      progress.expectedTotalBytes! > 0
                  ? progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes!
                  : null;
              return widget.loadingBuilder!(context, value);
            }
          : null,
      frameBuilder: widget.fadeInDuration > Duration.zero
          ? (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                return AnimatedOpacity(
                  opacity: frame == null ? 0.0 : 1.0,
                  duration: widget.fadeInDuration,
                  child: child,
                );
              }
              return AnimatedOpacity(
                opacity: 0.0,
                duration: widget.fadeInDuration,
                child: child,
              );
            }
          : null,
      semanticLabel: widget.semanticLabel,
      matchTextDirection: widget.matchTextDirection,
      excludeFromSemantics: widget.excludeFromSemantics,
      repeat: widget.repeat,
      centerSlice: widget.centerSlice,
      color: widget.color,
      colorBlendMode: widget.colorBlendMode,
      isAntiAlias: widget.isAntiAlias,
    );
  }

  Widget _buildError(BuildContext context) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context);
    }
    return const SizedBox.shrink();
  }
}
