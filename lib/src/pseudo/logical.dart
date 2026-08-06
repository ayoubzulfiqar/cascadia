import 'package:html/dom.dart';

import '../combined_selector.dart';
import '../escape.dart';
import '../match_context.dart';
import '../matcher.dart';
import '../specificity.dart';
import 'base.dart';

/// `:not(...)` — matches elements that match none of the argument selectors.
class NotPseudoClass extends PseudoClassSelector {
  /// The argument selector list.
  final Sel argument;

  /// Creates a `:not()` selector.
  NotPseudoClass(this.argument);

  @override
  bool matchElement(Element element, MatchContext context) =>
      !argument.matchWith(element, context);

  @override
  Specificity get specificity => argument.specificity;

  @override
  MatchSupport get support => argument.support;

  @override
  Set<String> get undecidableParts => argument.undecidableParts;

  @override
  String toString() => ':not($argument)';
}

/// `:is(...)` — matches elements matching any argument selector.
class IsPseudoClass extends PseudoClassSelector {
  /// The argument selector list.
  final Sel argument;

  /// Creates an `:is()` selector.
  IsPseudoClass(this.argument);

  @override
  bool matchElement(Element element, MatchContext context) =>
      argument.matchWith(element, context);

  @override
  Specificity get specificity => argument.specificity;

  @override
  MatchSupport get support => argument.support;

  @override
  Set<String> get undecidableParts => argument.undecidableParts;

  @override
  String toString() => ':is($argument)';
}

/// `:where(...)` — like `:is()` but always contributes zero specificity.
class WherePseudoClass extends PseudoClassSelector {
  /// The argument selector list.
  final Sel argument;

  /// Creates a `:where()` selector.
  WherePseudoClass(this.argument);

  @override
  bool matchElement(Element element, MatchContext context) =>
      argument.matchWith(element, context);

  @override
  Specificity get specificity => Specificity.zero;

  @override
  MatchSupport get support => argument.support;

  @override
  Set<String> get undecidableParts => argument.undecidableParts;

  @override
  String toString() => ':where($argument)';
}

/// `:has(...)` — matches elements with a relative selector match.
///
/// Audit **P1-1**: relative combinators (`:has(> p)`, `:has(+ p)`) were
/// previously discarded, so every argument was treated as a descendant search.
/// Audit **P2-5**: `:has()` now contributes its own `(0,1,0)`.
class HasPseudoClass extends PseudoClassSelector {
  /// The relative selectors, any of which may match.
  final List<RelativeSelector> arguments;

  /// Creates a `:has()` selector.
  HasPseudoClass(this.arguments);

  @override
  bool matchElement(Element element, MatchContext context) {
    for (final rel in arguments) {
      if (rel.matchesFrom(element, context)) return true;
    }
    return false;
  }

  @override
  Specificity get specificity {
    // Selectors L4 §15: the specificity of :is(), :not() and :has() "is
    // replaced by the specificity of the most specific complex selector in
    // its selector list argument" — it is NOT added to a (0,1,0) of its own.
    // (Only :nth-child()/:nth-last-child() add the pseudo-class itself.)
    var max = Specificity.zero;
    for (final rel in arguments) {
      if (rel.specificity > max) max = rel.specificity;
    }
    return max;
  }

  @override
  MatchSupport get support {
    var worst = MatchSupport.decidable;
    for (final rel in arguments) {
      if (rel.support.index > worst.index) worst = rel.support;
    }
    return worst;
  }

  @override
  Set<String> get undecidableParts =>
      {for (final rel in arguments) ...rel.undecidableParts};

  @override
  String toString() => ':has(${arguments.join(', ')})';
}

/// `:haschild(...)` — non-standard; matches elements with a matching child.
class HasChildPseudoClass extends PseudoClassSelector {
  /// The selector applied to each child.
  final Sel argument;

  /// Creates a `:haschild()` selector.
  HasChildPseudoClass(this.argument);

  @override
  bool matchElement(Element element, MatchContext context) {
    for (final child in element.children) {
      if (argument.matchWith(child, context)) return true;
    }
    return false;
  }

  @override
  Specificity get specificity => argument.specificity;

  @override
  MatchSupport get support => argument.support;

  @override
  Set<String> get undecidableParts => argument.undecidableParts;

  @override
  String toString() => ':haschild($argument)';
}

/// `:contains(text)` / `:containsown(text)` — non-standard text search.
class ContainsPseudoClass extends PseudoClassSelector {
  /// The substring to search for, compared case-insensitively.
  final String text;

  /// Whether to search only immediate text children.
  final bool ownOnly;

  /// Creates a `:contains()` selector.
  ContainsPseudoClass(this.text, this.ownOnly);

  @override
  bool matchElement(Element element, MatchContext context) {
    final content =
        ownOnly ? TextContent.own(element) : TextContent.all(element);
    return content.toLowerCase().contains(text.toLowerCase());
  }

  @override
  String toString() =>
      '${ownOnly ? ':containsown' : ':contains'}(${escapeCssString(text)})';
}

/// `:matches(/re/)` / `:matchesown(/re/)` — non-standard regex text search.
///
/// Audit **P2-6**: the pattern used to be round-tripped through a string and
/// rebuilt with a `contains('/')` heuristic, so `:matches(/foo/)` threw.
class MatchesPseudoClass extends PseudoClassSelector {
  /// The compiled pattern.
  final RegExp pattern;

  /// Whether to search only immediate text children.
  final bool ownOnly;

  /// Creates a `:matches()` selector.
  MatchesPseudoClass(this.pattern, this.ownOnly);

  @override
  bool matchElement(Element element, MatchContext context) {
    final content =
        ownOnly ? TextContent.own(element) : TextContent.all(element);
    return pattern.hasMatch(content);
  }

  @override
  String toString() {
    final flags = pattern.isCaseSensitive ? '' : 'i';
    return '${ownOnly ? ':matchesown' : ':matches'}(/${pattern.pattern}/$flags)';
  }
}
