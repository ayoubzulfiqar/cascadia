import 'package:html/dom.dart';

import '../match_context.dart';
import 'base.dart';

/// Formats an `an+b` expression in canonical CSS form.
///
/// Audit **P2-3**: the old implementation dropped the `n` and left unbalanced
/// parentheses, so `:nth-child(2n+1)` serialized as `:nth-child(2+1)`.
String formatAnB(int a, int b) {
  if (a == 0) return '$b';
  final coefficient = switch (a) { 1 => 'n', -1 => '-n', _ => '${a}n' };
  if (b == 0) return coefficient;
  return b > 0 ? '$coefficient+$b' : '$coefficient$b';
}

/// Whether a 1-based [position] satisfies `an+b`.
bool anBMatches(int a, int b, int position) {
  if (a == 0) return position == b;
  final diff = position - b;
  return diff % a == 0 && diff ~/ a >= 0;
}

/// `:nth-child()`, `:nth-last-child()`, `:nth-of-type()`, `:nth-last-of-type()`
/// and their `:first-`/`:last-` shorthands.
class NthPseudoClass extends PseudoClassSelector {
  /// The `a` coefficient.
  final int a;

  /// The `b` offset.
  final int b;

  /// Whether to count from the end of the sibling list.
  final bool last;

  /// Whether to count only siblings with the same tag name.
  final bool ofType;

  /// Creates an nth-style selector.
  const NthPseudoClass({
    required this.a,
    required this.b,
    this.last = false,
    this.ofType = false,
  });

  /// `:first-child`.
  factory NthPseudoClass.first() => const NthPseudoClass(a: 0, b: 1);

  /// `:last-child`.
  factory NthPseudoClass.last() => const NthPseudoClass(a: 0, b: 1, last: true);

  /// `:first-of-type`.
  factory NthPseudoClass.firstOfType() =>
      const NthPseudoClass(a: 0, b: 1, ofType: true);

  /// `:last-of-type`.
  factory NthPseudoClass.lastOfType() =>
      const NthPseudoClass(a: 0, b: 1, last: true, ofType: true);

  @override
  bool matchElement(Element element, MatchContext context) {
    final parent = element.parentNode;
    if (parent == null) return false;

    // Audit P0-2: the element cast is gone; Sel.matchWith guarantees an
    // Element here, and siblings are filtered by type before use.
    final tag = (element.localName ?? '').toLowerCase();
    var index = 0;
    var total = 0;
    var found = false;

    for (final sibling in parent.nodes) {
      if (sibling is! Element) continue;
      if (ofType && (sibling.localName ?? '').toLowerCase() != tag) continue;
      total++;
      if (identical(sibling, element)) {
        index = total;
        found = true;
      }
    }
    if (!found) return false;

    return anBMatches(a, b, last ? total - index + 1 : index);
  }

  @override
  String toString() {
    if (a == 0 && b == 1) {
      if (ofType) return last ? ':last-of-type' : ':first-of-type';
      return last ? ':last-child' : ':first-child';
    }
    final kind = ofType ? 'of-type' : 'child';
    final prefix = last ? ':nth-last-$kind' : ':nth-$kind';
    return '$prefix(${formatAnB(a, b)})';
  }
}

/// `:only-child` and `:only-of-type`.
class OnlyChildPseudoClass extends PseudoClassSelector {
  /// Whether to count only siblings with the same tag name.
  final bool ofType;

  /// Creates an only-child selector.
  const OnlyChildPseudoClass({required this.ofType});

  @override
  bool matchElement(Element element, MatchContext context) {
    final parent = element.parentNode;
    if (parent == null) return false;
    final tag = (element.localName ?? '').toLowerCase();
    var count = 0;
    for (final sibling in parent.nodes) {
      if (sibling is! Element) continue;
      if (ofType && (sibling.localName ?? '').toLowerCase() != tag) continue;
      if (++count > 1) return false;
    }
    return count == 1;
  }

  @override
  String toString() => ofType ? ':only-of-type' : ':only-child';
}

/// `:empty` — no element children and no non-whitespace text.
class EmptyPseudoClass extends PseudoClassSelector {
  /// Creates an `:empty` selector.
  const EmptyPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    for (final child in element.nodes) {
      if (child is Element) return false;
      if (child is Text && child.data.trim().isNotEmpty) return false;
    }
    return true;
  }

  @override
  String toString() => ':empty';
}

/// `:root` — the document's root element.
class RootPseudoClass extends PseudoClassSelector {
  /// Creates a `:root` selector.
  const RootPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    // Audit P1-11: the old check accepted any node whose parent was the
    // document, which included the doctype and top-level comments.
    final parent = element.parentNode;
    return parent is Document;
  }

  @override
  String toString() => ':root';
}

/// `:heading` and `:heading(an+b)` — non-standard heading selector.
class HeadingPseudoClass extends PseudoClassSelector {
  /// The `a` coefficient, or null to match any heading.
  final int? a;

  /// The `b` offset.
  final int? b;

  /// Creates a heading selector.
  const HeadingPseudoClass({this.a, this.b});

  static const Set<String> _tags = {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'};

  @override
  bool matchElement(Element element, MatchContext context) {
    if (!_tags.contains((element.localName ?? '').toLowerCase())) return false;
    if (a == null) return true;

    final parent = element.parentNode;
    if (parent == null) return false;

    var position = 0;
    var count = 0;
    for (final child in parent.nodes) {
      if (child is! Element) continue;
      if (!_tags.contains((child.localName ?? '').toLowerCase())) continue;
      count++;
      if (identical(child, element)) position = count;
    }
    return position != 0 && anBMatches(a!, b ?? 0, position);
  }

  @override
  String toString() =>
      a == null ? ':heading' : ':heading(${formatAnB(a!, b ?? 0)})';
}
