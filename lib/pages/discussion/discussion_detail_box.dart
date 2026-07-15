import 'dart:convert' show base64;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/cached_image.dart';
import 'package:inter_knot/components/image_viewer.dart';
import 'package:inter_knot/controllers/emote_controller.dart';
import 'package:inter_knot/helpers/content_segments.dart';
import 'package:inter_knot/helpers/dialog_helper.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/pages/profile_page.dart';
import 'package:markdown_widget/markdown_widget.dart' hide ImageViewer;
import 'package:url_launcher/url_launcher_string.dart';

class DiscussionDetailBox extends StatefulWidget {
  const DiscussionDetailBox({
    super.key,
    required this.discussion,
  });

  final DiscussionModel discussion;

  @override
  State<DiscussionDetailBox> createState() => _DiscussionDetailBoxState();
}

class _DiscussionDetailBoxState extends State<DiscussionDetailBox> {
  quill.QuillController? _quillController;

  @override
  void initState() {
    super.initState();
    _quillController = _createQuillController();
  }

  @override
  void didUpdateWidget(covariant DiscussionDetailBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.discussion.editorState != oldWidget.discussion.editorState) {
      _quillController?.dispose();
      _quillController = _createQuillController();
    }
  }

  @override
  void dispose() {
    _quillController?.dispose();
    super.dispose();
  }

  quill.QuillController? _createQuillController() {
    final editorState = widget.discussion.editorState;
    if (editorState == null || editorState.isEmpty) return null;
    try {
      return quill.QuillController(
        document: quill.Document.fromJson(editorState),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    } catch (_) {
      return null;
    }
  }

  Widget _buildMarkdownBody(DiscussionModel discussion) {
    return GetBuilder<EmoteController>(
      init: EmoteController(),
      builder: (emoteController) {
        final urlMap = <String, String>{
          for (final e in emoteController.emotes)
            if (e.code.isNotEmpty) e.code: e.url,
        };
        final enriched = enrichMarkdownForRichRender(
          discussion.rawBodyText,
          emoteUrlMap: urlMap,
        );
        return SelectionArea(
          child: MarkdownWidget(
            data: enriched,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            config: MarkdownConfig.darkConfig.copy(
              configs: [
                ImgConfig(
                  builder: (url, attributes) {
                    final alt = attributes['alt'] ?? '';
                    final emoteCode = alt.length > 2 &&
                            alt.startsWith(':') &&
                            alt.endsWith(':')
                        ? alt.substring(1, alt.length - 1)
                        : '';
                    final isEmote =
                        emoteCode.isNotEmpty &&
                        emoteController.emoteMap.containsKey(emoteCode);

                    if (isEmote) {
                      return CachedImage(
                        url: url,
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                        errorBuilder: (_) => Text(
                          alt,
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    }

                    return GestureDetector(
                      onTap: () => ImageViewer.show(
                        context,
                        imageUrls: [url],
                      ),
                      child: CachedImage(
                        url: url,
                        fit: BoxFit.contain,
                        errorBuilder: (_) => const Icon(
                          Icons.broken_image,
                          color: Colors.redAccent,
                        ),
                      ),
                    );
                  },
                ),
                LinkConfig(
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  onTap: (url) => _onUrlTap(context, url),
                ),
                const PConfig(
                  textStyle: TextStyle(
                    fontSize: 16,
                    color: Color(0xffE0E0E0),
                  ),
                ),
                PreConfig.darkConfig.copy(
                  wrapper: (child, code, language) => Stack(
                    children: [
                      child,
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Text(
                          language,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRichBody(DiscussionModel discussion) {
    final controller = _quillController;
    if (controller == null) {
      return _buildMarkdownBody(discussion);
    }

    return quill.QuillEditor.basic(
      controller: controller,
      config: quill.QuillEditorConfig(
        scrollable: false,
        padding: EdgeInsets.zero,
        autoFocus: false,
        showCursor: false,
        enableSelectionToolbar: true,
        onLaunchUrl: (url) => _onUrlTap(context, url),
        embedBuilders: [
          _CachedImageEmbedBuilder(
            onImageClicked: (url) => ImageViewer.show(
              context,
              imageUrls: [url],
            ),
          ),
          ...FlutterQuillEmbeds.editorBuilders(
            imageEmbedConfig: null,
          ),
        ],
      ),
    );
  }

  void _onUrlTap(BuildContext context, String url) {
    if (url.isEmpty) return;
    const profilePrefix = 'ik://profile/';
    if (url.startsWith(profilePrefix)) {
      final authorId = url.substring(profilePrefix.length);
      if (authorId.isNotEmpty) {
        showZZZDialog(
          context: context,
          pageBuilder: (_) => ProfilePage(authorDocumentId: authorId),
        );
      }
      return;
    }
    launchUrlString(url);
  }

  bool _bodyHasContent(DiscussionModel discussion) {
    if (discussion.editorState != null && discussion.editorState!.isNotEmpty) {
      return true;
    }
    final body = discussion.rawBodyText.trim();
    if (body.isEmpty) return false;
    final textOnly = body.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return textOnly.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final discussion = widget.discussion;
    final category = discussion.category;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                if (category != null)
                  TextSpan(
                    text: '[ ${category.name} ] ',
                    style: const TextStyle(
                      color: Color(0xff808080),
                      fontSize: 22,
                      fontWeight: FontWeight.normal,
                      height: 1.3,
                    ),
                  ),
                TextSpan(
                  text: discussion.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_bodyHasContent(discussion))
            _buildRichBody(discussion)
          else
            const Text(
              '啥都木有¯\\(°_o)/¯',
              style: TextStyle(
                color: Color(0xff808080),
                fontSize: 16,
                height: 1.7,
              ),
            ),
        ],
      ),
    );
  }
}

class _CachedImageEmbedBuilder extends quill.EmbedBuilder {
  const _CachedImageEmbedBuilder({this.onImageClicked});

  final void Function(String url)? onImageClicked;

  @override
  String get key => quill.BlockEmbed.imageType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    var imageSource = embedContext.node.value.data as String;
    if (imageSource.contains('base64')) {
      final parts = imageSource.split(',');
      if (parts.length > 1) {
        imageSource = parts[1];
      }
    }

    if (imageSource.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final size = _getImageSize(embedContext.node);
    final alignment = _getAlignment(embedContext.node);

    final image = _buildImage(imageSource, size, alignment);

    return GestureDetector(
      onTap: () {
        if (_isHttpUrl(imageSource)) {
          onImageClicked?.call(imageSource);
        }
      },
      child: image,
    );
  }

  Widget _buildImage(
    String imageSource,
    ({double? width, double? height}) size,
    Alignment alignment,
  ) {
    if (_isHttpUrl(imageSource)) {
      return CachedImage(
        url: imageSource,
        width: size.width,
        height: size.height,
        fit: BoxFit.contain,
        alignment: alignment,
        gaplessPlayback: true,
        errorBuilder: (_) => const Icon(
          Icons.broken_image,
          color: Colors.redAccent,
        ),
      );
    }

    if (_isBase64Image(imageSource)) {
      try {
        final bytes = base64.decode(imageSource);
        if (bytes.isNotEmpty) {
          return CachedImage(
            bytes: bytes,
            width: size.width,
            height: size.height,
            fit: BoxFit.contain,
            alignment: alignment,
            gaplessPlayback: true,
            errorBuilder: (_) => const Icon(
              Icons.broken_image,
              color: Colors.redAccent,
            ),
          );
        }
      } catch (_) {
        // 非有效 base64，回退到默认图标
      }
    }

    // file or asset
    final file = File(imageSource);
    if (file.existsSync()) {
      return CachedImage(
        imageProvider: FileImage(file),
        width: size.width,
        height: size.height,
        fit: BoxFit.contain,
        alignment: alignment,
        gaplessPlayback: true,
        errorBuilder: (_) => const Icon(
          Icons.broken_image,
          color: Colors.redAccent,
        ),
      );
    }

    return CachedImage(
      imageProvider: AssetImage(imageSource),
      width: size.width,
      height: size.height,
      fit: BoxFit.contain,
      alignment: alignment,
      gaplessPlayback: true,
      errorBuilder: (_) => const Icon(
        Icons.broken_image,
        color: Colors.redAccent,
      ),
    );
  }

  ({double? width, double? height}) _getImageSize(quill.Node node) {
    double? width;
    double? height;

    final widthAttr = node.style.attributes[quill.Attribute.width.key];
    final heightAttr = node.style.attributes[quill.Attribute.height.key];
    if (widthAttr?.value != null) {
      width = _parseCssLength(widthAttr!.value.toString());
    }
    if (heightAttr?.value != null) {
      height = _parseCssLength(heightAttr!.value.toString());
    }

    final styleAttr = node.style.attributes['style'];
    if (styleAttr != null) {
      final css = _parseCssString(styleAttr.value.toString());
      width = width ?? _parseCssLength(css['width'] ?? '');
      height = height ?? _parseCssLength(css['height'] ?? '');
    }

    return (width: width, height: height);
  }

  Alignment _getAlignment(quill.Node node) {
    final styleAttr = node.style.attributes['style'];
    if (styleAttr == null) return Alignment.center;
    final css = _parseCssString(styleAttr.value.toString());
    return _parseAlignment(css['alignment'] ?? '');
  }

  double? _parseCssLength(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final withoutUnit = trimmed.replaceAll(RegExp(r'[a-zA-Z%]+$'), '').trim();
    return double.tryParse(withoutUnit);
  }

  Map<String, String> _parseCssString(String css) {
    final result = <String, String>{};
    for (final entry in css.split(';')) {
      final kv = entry.split(':');
      if (kv.length == 2) {
        result[kv[0].trim()] = kv[1].trim();
      }
    }
    return result;
  }

  Alignment _parseAlignment(String value) {
    switch (value.trim()) {
      case 'left':
        return Alignment.centerLeft;
      case 'right':
        return Alignment.centerRight;
      case 'center':
      default:
        return Alignment.center;
    }
  }

  bool _isHttpUrl(String url) {
    try {
      final uri = Uri.parse(url.trim());
      return uri.isScheme('HTTP') || uri.isScheme('HTTPS');
    } catch (_) {
      return false;
    }
  }

  bool _isBase64Image(String imageSource) {
    if (_isHttpUrl(imageSource)) return false;
    try {
      base64.decode(imageSource);
      return true;
    } catch (_) {
      return false;
    }
  }
}
