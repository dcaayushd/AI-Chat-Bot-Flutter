import 'package:chatbotapp/utilities/app_snackbar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:material_ui/material_ui.dart';

class AssistantResponseContent extends StatelessWidget {
  const AssistantResponseContent({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final body = theme.textTheme.bodyLarge?.copyWith(height: 1.5);
    return MarkdownBody(
      data: text,
      selectable: true,
      fitContent: false,
      builders: {'pre': _CodeBlockBuilder()},
      // Avoid making network requests based on markup in the reply.
      imageBuilder: (uri, title, alt) => Text(alt ?? title ?? 'Image'),
      onTapLink: (text, href, title) async {
        final link = href == null ? null : Uri.tryParse(href);
        if (link != null && (link.scheme == 'https' || link.scheme == 'http')) {
          await _copy(context, href!, 'Link copied');
        }
      },
      styleSheet: MarkdownStyleSheet(
        a: body?.copyWith(
          color: colors.primary,
          decoration: TextDecoration.underline,
        ),
        p: body,
        pPadding: EdgeInsets.zero,
        h1: theme.textTheme.headlineSmall,
        h2: theme.textTheme.titleLarge,
        h3: theme.textTheme.titleMedium,
        h4: theme.textTheme.bodyLarge,
        h5: theme.textTheme.bodyLarge,
        h6: theme.textTheme.bodyLarge,
        em: const TextStyle(fontStyle: FontStyle.italic),
        strong: const TextStyle(fontWeight: FontWeight.bold),
        del: const TextStyle(decoration: TextDecoration.lineThrough),
        blockquote: body,
        blockquotePadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        blockquoteDecoration: BoxDecoration(
          color: colors.surfaceContainer,
          border: Border(left: BorderSide(color: colors.primary, width: 3)),
        ),
        img: body,
        checkbox: TextStyle(color: colors.primary),
        code: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: colors.surfaceContainerHigh,
        ),
        codeblockPadding: EdgeInsets.zero,
        codeblockDecoration: const BoxDecoration(),
        listBullet: body,
        listIndent: 24,
        listBulletPadding: const EdgeInsets.only(right: 4),
        blockSpacing: 12,
        tableHead: theme.textTheme.labelLarge,
        tableHeadAlign: TextAlign.start,
        tableBody: theme.textTheme.bodyMedium,
        tableBorder: TableBorder.all(color: colors.outlineVariant),
        tableColumnWidth: const IntrinsicColumnWidth(),
        tablePadding: EdgeInsets.zero,
        tableCellsPadding: const EdgeInsets.all(8),
        tableCellsDecoration: const BoxDecoration(),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
      ),
    );
  }
}

Future<void> _copy(
  BuildContext context,
  String text,
  String confirmation,
) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showAppSnackBar(context, confirmation, bottomOffset: 78);
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget visitText(md.Text text, TextStyle? preferredStyle) =>
      const SizedBox.shrink();

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.children?.whereType<md.Element>().firstOrNull;
    final language = code?.attributes['class']?.replaceFirst('language-', '');
    return _CodeBlockCard(language: language, code: element.textContent);
  }
}

class _CodeBlockCard extends StatelessWidget {
  const _CodeBlockCard({required this.language, required this.code});

  final String? language;
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language ?? 'Code',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy code',
                  onPressed: () => _copy(context, code, 'Code copied'),
                  icon: const Icon(Icons.content_copy_rounded, size: 16),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
