import 'package:html/dom.dart';

import 'match_context.dart';
import 'matcher.dart';
import 'specificity.dart';

/// Several simple selectors applied to the same element, e.g. `div.foo#bar`.
class CompoundSelector extends Sel {
  /// The simple selectors that must all match.
  final List<Sel> selectors;

  @override
  final String pseudoElement;

  /// Creates a compound selector.
  CompoundSelector({
    required this.selectors,
    this.pseudoElement = '',
  });

  @override
  bool matchElement(Element element, MatchContext context) {
    // Audit P1-7: a pseudo-element denotes a rendered fragment, never an
    // element node, so a compound carrying one can never match. This covers
    // both the bare '::before' case (empty selectors, previously a vacuous
    // "all of nothing" that matched everything) and the qualified
    // 'p::before' case, which slipped through the original fix because only
    // the sub-selectors were consulted.
    if (pseudoElement.isNotEmpty) return false;
    if (selectors.isEmpty) return false;
    for (final sel in selectors) {
      if (!sel.matchWith(element, context)) return false;
    }
    return true;
  }

  @override
  Specificity get specificity {
    var sum = Specificity.zero;
    for (final sel in selectors) {
      sum = sum + sel.specificity;
    }
    if (pseudoElement.isNotEmpty) sum = sum + Specificity.typeSelector;
    return sum;
  }

  @override
  MatchSupport get support {
    // A compound carrying a pseudo-element denotes a rendered fragment, so it
    // can never match an element node however decidable its other parts are.
    if (pseudoElement.isNotEmpty) return MatchSupport.neverDecidable;
    var worst = MatchSupport.decidable;
    for (final sel in selectors) {
      if (sel.support.index > worst.index) worst = sel.support;
    }
    return worst;
  }

  @override
  Set<String> get undecidableParts => {
        for (final sel in selectors) ...sel.undecidableParts,
        if (pseudoElement.isNotEmpty) '::$pseudoElement',
      };

  @override
  String toString() {
    final parts = selectors.map((s) => s.toString()).join();
    final base = parts.isEmpty && pseudoElement.isEmpty ? '*' : parts;
    return pseudoElement.isEmpty ? base : '$base::$pseudoElement';
  }
}

/// Two selectors joined by a combinator, e.g. `div > p`.
class CombinedSelector extends Sel {
  /// The left-hand selector.
  final Sel first;

  /// One of `' '`, `'>'`, `'+'` or `'~'`.
  final String combinator;

  /// The right-hand selector, which must match the candidate element.
  final Sel second;

  /// Creates a combined selector.
  CombinedSelector({
    required this.first,
    required this.combinator,
    required this.second,
  });

  @override
  bool matchElement(Element element, MatchContext context) {
    if (!second.matchWith(element, context)) return false;
    switch (combinator) {
      case ' ':
        for (var p = element.parentNode; p != null; p = p.parentNode) {
          if (first.matchWith(p, context)) return true;
        }
        return false;
      case '>':
        final parent = element.parentNode;
        return parent != null && first.matchWith(parent, context);
      case '+':
        final prev = element.previousElementSibling;
        return prev != null && first.matchWith(prev, context);
      case '~':
        for (var s = element.previousElementSibling;
            s != null;
            s = s.previousElementSibling) {
          if (first.matchWith(s, context)) return true;
        }
        return false;
      default:
        return false;
    }
  }

  @override
  Specificity get specificity => first.specificity + second.specificity;

  @override
  String get pseudoElement => second.pseudoElement;

  @override
  MatchSupport get support => first.support.index > second.support.index
      ? first.support
      : second.support;

  @override
  Set<String> get undecidableParts =>
      {...first.undecidableParts, ...second.undecidableParts};

  @override
  String toString() =>
      // Audit P2-2: the descendant combinator used to emit three spaces
      // because `' '` was interpolated between two literal spaces.
      combinator == ' ' ? '$first $second' : '$first $combinator $second';
}

/// A selector with a leading combinator, used inside `:has()`.
///
/// Audit **P1-1**: `:has(> p)` used to drop the `>` and search all
/// descendants, so relative selectors — the defining feature of `:has()` in
/// Selectors Level 4 — did not work.
class RelativeSelector extends Sel {
  /// The leading combinator: `' '`, `'>'`, `'+'` or `'~'`.
  final String combinator;

  /// The selector applied to the elements reached by [combinator].
  final Sel selector;

  /// Creates a relative selector.
  RelativeSelector({required this.combinator, required this.selector});

  /// Whether any element reachable from [anchor] via [combinator] matches.
  bool matchesFrom(Element anchor, MatchContext context) {
    switch (combinator) {
      case '>':
        for (final child in anchor.children) {
          if (selector.matchWith(child, context)) return true;
        }
        return false;
      case '+':
        final next = anchor.nextElementSibling;
        return next != null && selector.matchWith(next, context);
      case '~':
        for (var s = anchor.nextElementSibling;
            s != null;
            s = s.nextElementSibling) {
          if (selector.matchWith(s, context)) return true;
        }
        return false;
      case ' ':
      default:
        return _anyDescendant(anchor, context);
    }
  }

  bool _anyDescendant(Element root, MatchContext context) {
    // Iterative to avoid a stack overflow on deep documents.
    final stack = <Element>[...root.children];
    while (stack.isNotEmpty) {
      final el = stack.removeLast();
      if (selector.matchWith(el, context)) return true;
      stack.addAll(el.children);
    }
    return false;
  }

  @override
  bool matchElement(Element element, MatchContext context) =>
      selector.matchWith(element, context);

  @override
  Specificity get specificity => selector.specificity;

  @override
  MatchSupport get support => selector.support;

  @override
  Set<String> get undecidableParts => selector.undecidableParts;

  @override
  String toString() =>
      combinator == ' ' ? '$selector' : '$combinator $selector';
}
