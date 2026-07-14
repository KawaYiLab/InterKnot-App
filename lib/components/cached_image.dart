import 'dart:async' show StreamController, StreamSubscription, scheduleMicrotask;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

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
    imageProvider = createNetworkImageProvider(
      url.trim(),
      headers: headers,
    );
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

  if (imageProvider is SingleFrameNetworkImageProvider) {
    final targetWidth = cacheWidth?.toDouble() ?? maxCacheDimension.toDouble();
    final targetHeight = cacheHeight?.toDouble() ?? maxCacheDimension.toDouble();
    return SingleFrameNetworkImageProvider(
      imageProvider.url,
      headers: imageProvider.headers,
      scale: imageProvider.scale,
      cacheKey: imageProvider.cacheKey,
      targetSize: Size(targetWidth, targetHeight),
      targetDpr: dpr ?? 1.0,
    );
  }

  if (cacheWidth == null && cacheHeight == null) return imageProvider;

  return ResizeImage(
    imageProvider,
    width: cacheWidth,
    height: cacheHeight,
    policy: ResizeImagePolicy.fit,
    allowUpscaling: true,
  );
}

ImageProvider createNetworkImageProvider(
  String url, {
  Map<String, String>? headers,
  double scale = 1.0,
  String? cacheKey,
}) {
  final uri = Uri.tryParse(url);
  if (uri != null && uri.path.toLowerCase().endsWith('.gif')) {
    return SingleFrameNetworkImageProvider(
      url,
      headers: headers,
      scale: scale,
      cacheKey: cacheKey,
    );
  }
  return CachedNetworkImageProvider(
    url,
    headers: headers,
    scale: scale,
    cacheKey: cacheKey,
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
      return createNetworkImageProvider(
        widget.url!.trim(),
        headers: widget.headers,
      );
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
    if (inner is SingleFrameNetworkImageProvider) return inner;

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

    final dpr = MediaQuery.devicePixelRatioOf(context);

    if (_hasFixedSize) {
      final provider = _provider;
      if (provider == null) return _buildError(context);

      double? imageWidth = widget.width;
      double? imageHeight = widget.height;
      if (imageWidth == null || imageHeight == null) {
        if (widget.cacheWidth != null && widget.cacheHeight != null) {
          imageWidth ??= widget.cacheWidth! / dpr;
          imageHeight ??= widget.cacheHeight! / dpr;
        } else if (widget.cacheWidth != null) {
          imageWidth ??= widget.cacheWidth! / dpr;
          imageHeight ??= widget.cacheWidth! / dpr;
        } else if (widget.cacheHeight != null) {
          imageWidth ??= widget.cacheHeight! / dpr;
          imageHeight ??= widget.cacheHeight! / dpr;
        }
      }

      return _buildImage(
        context,
        provider,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
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

        final ImageProvider provider;
        if (inner is SingleFrameNetworkImageProvider) {
          provider = inner;
        } else {
          provider = ResizeImage(
            inner,
            width: width,
            height: height,
            policy: ResizeImagePolicy.fit,
            allowUpscaling: true,
          );
        }

        return _buildImage(context, provider);
      },
    );
  }

  Widget _buildImage(
    BuildContext context,
    ImageProvider provider, {
    double? imageWidth,
    double? imageHeight,
  }) {
    return Image(
      image: provider,
      width: imageWidth ?? widget.width,
      height: imageHeight ?? widget.height,
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

class SingleFrameNetworkImageProvider
    extends ImageProvider<SingleFrameNetworkImageProvider> {
  const SingleFrameNetworkImageProvider(
    this.url, {
    this.headers,
    this.scale = 1.0,
    this.cacheKey,
    this.targetSize = const Size(2048.0, 2048.0),
    this.targetDpr = 1.0,
  });

  final String url;
  final Map<String, String>? headers;
  final double scale;
  final String? cacheKey;
  final Size targetSize;
  final double targetDpr;

  @override
  Future<SingleFrameNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    final dpr = configuration.devicePixelRatio ?? targetDpr;
    final size = configuration.size;
    final logicalTargetSize = size == null
        ? targetSize
        : Size(
            (size.width * dpr).clamp(1.0, maxCacheDimension.toDouble()),
            (size.height * dpr).clamp(1.0, maxCacheDimension.toDouble()),
          );
    return SynchronousFuture<SingleFrameNetworkImageProvider>(
      SingleFrameNetworkImageProvider(
        url,
        headers: headers,
        scale: scale,
        cacheKey: cacheKey,
        targetSize: logicalTargetSize,
        targetDpr: dpr,
      ),
    );
  }

  @override
  ImageStreamCompleter loadImage(
    SingleFrameNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final chunkEvents = StreamController<ImageChunkEvent>();
    final image = _loadImage(key, decode, chunkEvents);
    return SingleFrameNetworkImageStreamCompleter(
      image: image,
      chunkEvents: chunkEvents.stream,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<SingleFrameNetworkImageProvider>('Image key', key),
      ],
    );
  }

  Future<ImageInfo> _loadImage(
    SingleFrameNetworkImageProvider key,
    ImageDecoderCallback decode,
    StreamController<ImageChunkEvent> chunkEvents,
  ) async {
    final manager = DefaultCacheManager();
    try {
      await for (final FileResponse response in manager.getFileStream(
        key.url,
        headers: key.headers,
        key: key.cacheKey,
        withProgress: true,
      )) {
        if (response is DownloadProgress) {
          if (!chunkEvents.isClosed) {
            chunkEvents.add(ImageChunkEvent(
              cumulativeBytesLoaded: response.downloaded,
              expectedTotalBytes: response.totalSize,
            ));
          }
        } else if (response is FileInfo) {
          final bytes = await response.file.readAsBytes();
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          final codec = await decode(buffer);
          final frame = await codec.getNextFrame();

          final originalImage = frame.image;
          final originalWidth = originalImage.width;
          final originalHeight = originalImage.height;

          final targetWidth = key.targetSize.width.clamp(
            1.0,
            maxCacheDimension.toDouble(),
          );
          final targetHeight = key.targetSize.height.clamp(
            1.0,
            maxCacheDimension.toDouble(),
          );

          final scale = math.min(
            targetWidth / originalWidth,
            targetHeight / originalHeight,
          );
          final scaledWidth = math.min(
            maxCacheDimension,
            math.max(1, (originalWidth * scale).ceil()),
          );
          final scaledHeight = math.min(
            maxCacheDimension,
            math.max(1, (originalHeight * scale).ceil()),
          );

          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          final paint = ui.Paint()
            ..filterQuality = ui.FilterQuality.high;
          canvas.drawImageRect(
            originalImage,
            Rect.fromLTRB(0, 0, originalWidth.toDouble(), originalHeight.toDouble()),
            Rect.fromLTRB(0, 0, scaledWidth.toDouble(), scaledHeight.toDouble()),
            paint,
          );
          final picture = recorder.endRecording();
          final scaledImage = await picture.toImage(scaledWidth, scaledHeight);
          picture.dispose();
          originalImage.dispose();
          codec.dispose();

          if (!chunkEvents.isClosed) {
            await chunkEvents.close();
          }
          return ImageInfo(
            image: scaledImage,
            scale: key.targetDpr,
            debugLabel: key.url,
          );
        }
      }
      throw StateError(
        'Image stream completed without returning a file for ${key.url}',
      );
    } on Object catch (error, stackTrace) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      if (!chunkEvents.isClosed) {
        await chunkEvents.close();
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is! SingleFrameNetworkImageProvider) return false;
    return (cacheKey ?? url) == (other.cacheKey ?? other.url) &&
        scale == other.scale &&
        targetSize == other.targetSize &&
        targetDpr == other.targetDpr;
  }

  @override
  int get hashCode => Object.hash(cacheKey ?? url, scale, targetSize, targetDpr);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'SingleFrameNetworkImageProvider')}'
      '(url: "$url", scale: $scale, targetSize: $targetSize, targetDpr: $targetDpr)';
}

class SingleFrameNetworkImageStreamCompleter extends ImageStreamCompleter {
  SingleFrameNetworkImageStreamCompleter({
    required Future<ImageInfo> image,
    required Stream<ImageChunkEvent> chunkEvents,
    InformationCollector? informationCollector,
  }) {
    StreamSubscription<ImageChunkEvent>? chunkSubscription;

    void stopListening() {
      chunkSubscription?.cancel();
      chunkSubscription = null;
    }

    chunkSubscription = chunkEvents.listen(
      (ImageChunkEvent event) {
        try {
          reportImageChunkEvent(event);
        } on StateError {
          stopListening();
        }
      },
      onDone: stopListening,
      onError: (Object error, StackTrace stack) {
        // Errors from the chunk stream are surfaced through the image future.
      },
    );

    addOnLastListenerRemovedCallback(stopListening);

    image.then<void>(
      (ImageInfo info) {
        stopListening();
        try {
          setImage(info);
        } on StateError {
          info.dispose();
        }
      },
      onError: (Object error, StackTrace stack) {
        stopListening();
        try {
          reportError(
            context: ErrorDescription(
              'resolving a single-frame network image stream',
            ),
            exception: error,
            stack: stack,
            informationCollector: informationCollector,
            silent: true,
          );
        } on StateError {
          // The completer was disposed before the error could be reported.
        }
      },
    );
  }
}
