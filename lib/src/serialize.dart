import 'combined_selector.dart';
import 'matcher.dart';
import 'pseudo_classes.dart';
import 'selectors.dart';

/// Serializes selector objects back to CSS string representation.
///
/// This is the inverse of the parser: given a [Sel] object, produces
/// a valid CSS selector string.
class Serializer {
  /// Convert a [Sel] to its CSS string representation.
  static String serialize(Sel sel) {
    if (sel is SelectorGroup) {
      return sel.selectors.map((s) => serialize(s)).join(', ');
    } else if (sel is CombinedSelector) {
      final first = serialize(sel.first);
      final second = serialize(sel.second);
      final comb = sel.combinator == ' ' ? ' ' : sel.combinator;
      return '$first $comb $second';
    } else if (sel is CompoundSelector) {
      final parts = sel.selectors.map((s) => serialize(s)).join('');
      if (sel.pseudoElement.isNotEmpty) {
        return '$parts::${sel.pseudoElement}';
      }
      return parts.isEmpty ? '*' : parts;
    } else if (sel is TagSelector) {
      return sel.tag;
    } else if (sel is ClassSelector) {
      return '.${sel.className}';
    } else if (sel is IdSelector) {
      return '#${sel.id}';
    } else if (sel is AttributeSelector) {
      return sel.toString();
    } else if (sel is PseudoClassSelector) {
      return sel.toString();
    } else {
      return sel.toString();
    }
  }
}
