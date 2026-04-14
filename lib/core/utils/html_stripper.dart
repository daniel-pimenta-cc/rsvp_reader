import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Converts EPUB XHTML content to clean plain text.
///
/// Preserves paragraph boundaries as double newlines.
/// Handles HTML entities automatically via the html parser.
class HtmlStripper {
  const HtmlStripper._();

  static const _blockTags = {
    'p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'li', 'blockquote', 'section', 'article', 'header',
    'footer', 'aside', 'figcaption', 'dt', 'dd', 'tr',
  };

  static const _breakTags = {'br', 'hr'};

  /// Tags whose entire subtree must be ignored — they don't carry
  /// reading content (CSS, scripts, metadata, embedded media, etc.).
  static const _skipTags = {
    'style', 'script', 'noscript', 'head', 'meta', 'link',
    'title', 'object', 'embed', 'svg', 'iframe', 'template',
  };

  /// Strip HTML tags and return clean text with paragraph breaks.
  static String strip(String htmlContent) {
    if (htmlContent.trim().isEmpty) return '';

    final document = html_parser.parseFragment(htmlContent);
    final buffer = StringBuffer();
    _walkNodes(document, buffer);

    // Clean up excessive whitespace while preserving paragraph breaks
    return buffer
        .toString()
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  static void _walkNodes(Node node, StringBuffer buffer) {
    for (final child in node.nodes) {
      if (child.nodeType == Node.TEXT_NODE) {
        buffer.write(child.text);
      } else if (child.nodeType == Node.ELEMENT_NODE) {
        final element = child as Element;
        final tag = element.localName?.toLowerCase();

        // Skip the entire subtree for non-content tags (style, script, etc.)
        if (tag != null && _skipTags.contains(tag)) {
          continue;
        }

        if (tag != null && _breakTags.contains(tag)) {
          buffer.write('\n');
        }

        if (tag != null && _blockTags.contains(tag)) {
          buffer.write('\n\n');
        }

        _walkNodes(child, buffer);

        if (tag != null && _blockTags.contains(tag)) {
          buffer.write('\n\n');
        }
      }
    }
  }
}
