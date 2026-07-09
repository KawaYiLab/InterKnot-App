import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:get/get.dart';
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
                      return Image.network(
                        url,
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Text(
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
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
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
    final editorState = discussion.editorState;
    if (editorState == null || editorState.isEmpty) {
      return _buildMarkdownBody(discussion);
    }

    try {
      final controller = quill.QuillController(
        document: quill.Document.fromJson(editorState),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );

      return quill.QuillEditor.basic(
        controller: controller,
        config: quill.QuillEditorConfig(
          scrollable: false,
          padding: EdgeInsets.zero,
          autoFocus: false,
          showCursor: false,
          enableSelectionToolbar: true,
          onLaunchUrl: (url) => _onUrlTap(context, url),
          embedBuilders: FlutterQuillEmbeds.editorBuilders(
            imageEmbedConfig: QuillEditorImageEmbedConfig(
              onImageClicked: (url) => ImageViewer.show(
                context,
                imageUrls: [url],
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      return _buildMarkdownBody(discussion);
    }
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

  @override
  Widget build(BuildContext context) {
    final discussion = widget.discussion;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                discussion.title,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 16),
              _buildRichBody(discussion),
            ],
          ),
        ],
      ),
    );
  }
}
