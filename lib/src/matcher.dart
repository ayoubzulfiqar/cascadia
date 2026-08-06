import 'package:html/dom.dart';

import 'match_context.dart';
import 'specificity.dart';

/// How well a selector can be evaluated against a static DOM.
enum MatchSupport {
  /// Fully decidable from the DOM alone.
  decidable,

  /// Decidable only when the caller supplies runtime state via [MatchContext].
  requiresContext,

  /// Can never be decided, e.g. `:visited` (privacy-restricted by design).
  neverDecidable,
}

/// A CSS selector that can be matched against a DOM node.
///
/// Audit **P2-7**: this used to be split into `Matcher` and `Sel`, where
/// `Matcher` collided with `package:matcher`/`package:test` and forced users to
/// write `hide Matcher`. `Sel` extended it and added only `toString()`, so the
/// two have been merged into this single type.
abstract class Sel {
  /// Creates a selector.
  const Sel();

  /// Whether [node] matches this selector, using no runtime context.
  ///
  /// Audit **P0-2/3/4**: subclasses implement [matchElement] and this method
  /// applies the `Element` type guard once, centrally, so a `Text` or
  /// `DocumentType` node can never reach a selector body and trigger a cast
  /// error. Subclasses that must see non-element nodes override [matchWith].
  bool match(Node node) => matchWith(node, MatchContext.empty);

  /// Whether [node] matches, using the runtime facts in [context].
  bool matchWith(Node node, MatchContext context) =>
      node is Element && matchElement(node, context);

  /// Whether [element] matches. Implemented by concrete selectors.
  bool matchElement(Element element, MatchContext context);

  /// The specificity of this selector as an `(a, b, c)` triple.
  Specificity get specificity;

  /// The pseudo-element attached to this selector, or `''` if there is none.
  String get pseudoElement => '';

  /// How well this selector can be evaluated. See [MatchSupport].
  MatchSupport get support => MatchSupport.decidable;

  /// The names of any parts of this selector that are not fully decidable.
  ///
  /// Lets callers inspect what a selector needs before relying on its result:
  ///
  /// ```dart
  /// final sel = parse('a:hover');
  /// print(sel.undecidableParts); // {':hover'}
  /// ```
  Set<String> get undecidableParts => const <String>{};

  /// The CSS text of this selector.
  @override
  String toString();
}

/// A comma-separated selector list; matches when any component matches.
class SelectorGroup extends Sel {
  /// The selectors in this group.
  final List<Sel> selectors;

  /// Creates a selector group.
  SelectorGroup(this.selectors);

  @override
  bool matchWith(Node node, MatchContext context) {
    for (final sel in selectors) {
      if (sel.matchWith(node, context)) return true;
    }
    return false;
  }

  @override
  bool matchElement(Element element, MatchContext context) =>
      matchWith(element, context);

  @override
  Specificity get specificity {
    var max = Specificity.zero;
    for (final sel in selectors) {
      final spec = sel.specificity;
      if (spec > max) max = spec;
    }
    return max;
  }

  @override
  String get pseudoElement =>
      selectors.length == 1 ? selectors.first.pseudoElement : '';

  @override
  MatchSupport get support {
    var worst = MatchSupport.decidable;
    for (final sel in selectors) {
      if (sel.support.index > worst.index) worst = sel.support;
    }
    return worst;
  }

  @override
  Set<String> get undecidableParts =>
      {for (final sel in selectors) ...sel.undecidableParts};

  @override
  String toString() => selectors.join(', ');
}

/// A function that tests whether a node matches a selector.
typedef Selector = bool Function(Node);

/// Adapts a [Sel] to a plain [Selector] function.
extension SelAdapter on Sel {
  /// Returns this selector as a callable predicate.
  Selector asFunction() => match;

  /// Returns this selector as a predicate bound to [context].
  Selector asFunctionWith(MatchContext context) =>
      (node) => matchWith(node, context);
}
