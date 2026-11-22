import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:chatbotapp/utilities/app_snackbar.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AssistantResponseContent extends StatelessWidget {
  const AssistantResponseContent({
    super.key,
    required this.text,
  });

  static final RegExp _codeBlockPattern =
      RegExp(r'```([^\n`]*)\n([\s\S]*?)```');

  final String text;

  static bool containsCodeBlocks(String text) =>
      _codeBlockPattern.hasMatch(text);

  @override
  Widget build(BuildContext context) {
    final segments = _segmentsFrom(text);
    final markdownStyle = _markdownStyle(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final segment in segments) ...[
          if (segment.isCode)
            _CodeBlockCard(
              language: segment.language,
              code: segment.content,
            )
          else if (segment.content.trim().isNotEmpty)
            MarkdownBody(
              selectable: true,
              data: segment.content,
              styleSheet: markdownStyle,
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  List<_ResponseSegment> _segmentsFrom(String text) {
    final segments = <_ResponseSegment>[];
    var lastEnd = 0;

    for (final match in _codeBlockPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        segments.add(
          _ResponseSegment.markdown(
            text.substring(lastEnd, match.start),
          ),
        );
      }

      segments.add(
        _ResponseSegment.code(
          (match.group(2) ?? '').trimRight(),
          language: (match.group(1) ?? '').trim(),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      segments.add(_ResponseSegment.markdown(text.substring(lastEnd)));
    }

    return segments.isEmpty ? [_ResponseSegment.markdown(text)] : segments;
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MarkdownStyleSheet(
      pPadding: EdgeInsets.zero,
      h1: theme.textTheme.headlineSmall,
      h1Padding: EdgeInsets.zero,
      h2: theme.textTheme.titleLarge,
      h2Padding: EdgeInsets.zero,
      h3: theme.textTheme.titleMedium,
      h3Padding: EdgeInsets.zero,
      h4: theme.textTheme.bodyLarge,
      h4Padding: EdgeInsets.zero,
      h5: theme.textTheme.bodyLarge,
      h5Padding: EdgeInsets.zero,
      h6: theme.textTheme.bodyLarge,
      h6Padding: EdgeInsets.zero,
      em: const TextStyle(fontStyle: FontStyle.italic),
      strong: const TextStyle(fontWeight: FontWeight.bold),
      del: const TextStyle(decoration: TextDecoration.lineThrough),
      blockquote: theme.textTheme.bodyMedium,
      img: theme.textTheme.bodyMedium,
      checkbox: theme.textTheme.bodyMedium?.copyWith(
        color: theme.primaryColor,
      ),
      listIndent: 24,
      listBulletPadding: const EdgeInsets.only(right: 4),
      tableHead: const TextStyle(fontWeight: FontWeight.w600),
      tableBody: theme.textTheme.bodyMedium,
      tableHeadAlign: TextAlign.center,
      tablePadding: const EdgeInsets.only(bottom: 4),
      tableBorder: TableBorder.all(color: theme.dividerColor),
      tableColumnWidth: const FlexColumnWidth(),
      tableCellsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      tableCellsDecoration: const BoxDecoration(),
      blockquotePadding: const EdgeInsets.all(8),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(width: 5, color: theme.dividerColor),
        ),
      ),
      p: theme.textTheme.bodyLarge?.copyWith(height: 1.48),
      listBullet: theme.textTheme.bodyLarge,
      blockquoteDecoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      blockSpacing: 14,
      code: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
      ),
      codeblockPadding: EdgeInsets.zero,
      codeblockDecoration: const BoxDecoration(
        color: Colors.transparent,
      ),
    );
  }
}

class _CodeBlockCard extends StatelessWidget {
  const _CodeBlockCard({
    required this.language,
    required this.code,
  });

  final String language;
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.48),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                child: Row(
                  children: [
                    Text(
                      language.isEmpty ? 'Code' : language.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Copy code',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (context.mounted) {
                          showAppSnackBar(context, 'Code copied',
                              bottomOffset: 132);
                        }
                      },
                      icon: const Icon(CupertinoIcons.doc_on_doc, size: 18),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth - 28,
                  ),
                  child: SelectableText(
                    code,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.6,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ResponseSegment {
  const _ResponseSegment._({
    required this.content,
    required this.isCode,
    this.language = '',
  });

  factory _ResponseSegment.markdown(String content) {
    return _ResponseSegment._(
      content: content,
      isCode: false,
    );
  }

  factory _ResponseSegment.code(String content, {required String language}) {
    return _ResponseSegment._(
      content: content,
      isCode: true,
      language: language,
    );
  }

  final String content;
  final bool isCode;
  final String language;
}
