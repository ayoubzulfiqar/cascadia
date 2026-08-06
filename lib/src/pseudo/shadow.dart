import 'package:html/dom.dart';

import '../match_context.dart';
import '../matcher.dart';
import '../specificity.dart';
import 'base.dart';

/// `:host`, and `:host(selector)` when [selector] is supplied.
class HostPseudoClass extends PseudoClassSelector {
  /// An optional compound selector the host must also match.
  final Sel? selector;

  /// Creates a `:host` selector.
  const HostPseudoClass([this.selector]);

  @override
  bool matchElement(Element element, MatchContext context) {
    // Shadow trees are not represented by package:html, so the host can only
    // be identified when the caller marks it as the scope element.
    final scope = context.scope;
    if (scope == null) {
      if (context.strict) {
        throw UndecidableSelectorError(
            toString(), 'no shadow host supplied as MatchContext.scope');
      }
      return false;
    }
    if (!identical(scope, element)) return false;
    return selector?.matchWith(element, context) ?? true;
  }

  @override
  Specificity get specificity =>
      Specificity.classSelector + (selector?.specificity ?? Specificity.zero);

  @override
  MatchSupport get support => MatchSupport.requiresContext;

  @override
  Set<String> get undecidableParts => {toString()};

  @override
  String toString() => selector == null ? ':host' : ':host($selector)';
}

/// `:host-context(selector)` — the host, when an ancestor matches.
class HostContextPseudoClass extends PseudoClassSelector {
  /// The selector applied to the host's ancestors.
  final Sel selector;

  /// Creates a `:host-context()` selector.
  const HostContextPseudoClass(this.selector);

  @override
  bool matchElement(Element element, MatchContext context) {
    final scope = context.scope;
    if (scope == null) {
      if (context.strict) {
        throw UndecidableSelectorError(
            toString(), 'no shadow host supplied as MatchContext.scope');
      }
      return false;
    }
    if (!identical(scope, element)) return false;
    for (var p = element.parentNode; p != null; p = p.parentNode) {
      if (selector.matchWith(p, context)) return true;
    }
    return false;
  }

  @override
  Specificity get specificity =>
      Specificity.classSelector + selector.specificity;

  @override
  MatchSupport get support => MatchSupport.requiresContext;

  @override
  Set<String> get undecidableParts => {toString()};

  @override
  String toString() => ':host-context($selector)';
}

/// `:has-slotted(selector?)` — a `<slot>` with assigned content.
class HasSlottedPseudoClass extends PseudoClassSelector {
  /// An optional selector the slotted content must match.
  final Sel? selector;

  /// Creates a `:has-slotted()` selector.
  const HasSlottedPseudoClass([this.selector]);

  @override
  bool matchElement(Element element, MatchContext context) {
    if ((element.localName ?? '').toLowerCase() != 'slot') return false;
    // Without a shadow tree, fall back to the slot's fallback content.
    for (final child in element.children) {
      if (selector == null || selector!.matchWith(child, context)) return true;
    }
    return false;
  }

  @override
  Specificity get specificity =>
      Specificity.classSelector + (selector?.specificity ?? Specificity.zero);

  @override
  String toString() =>
      selector == null ? ':has-slotted' : ':has-slotted($selector)';
}
