import 'package:html/dom.dart';

import '../match_context.dart';
import '../matcher.dart';
import '../specificity.dart';
import 'base.dart';

/// Pseudo-elements recognised by this library, and whether each takes an
/// argument (`required`, `optional` or `none`).
const Map<String, String> knownPseudoElements = <String, String>{
  // Typographic
  'first-line': 'none',
  'first-letter': 'none',
  // Generated content
  'before': 'none',
  'after': 'none',
  // Tree-abiding
  'marker': 'none',
  'backdrop': 'none',
  'column': 'none',
  'details-content': 'none',
  // Form-related
  'placeholder': 'none',
  'file-selector-button': 'none',
  'picker-icon': 'none',
  'checkmark': 'none',
  'picker': 'required',
  // Highlight
  'selection': 'none',
  'target-text': 'none',
  'spelling-error': 'none',
  'grammar-error': 'none',
  'search-text': 'none',
  'highlight': 'required',
  // Shadow DOM
  'part': 'required',
  'slotted': 'optional',
  // Media
  'cue': 'optional',
  'cue-region': 'optional',
  // Scroll
  'scroll-button': 'optional',
  'scroll-marker': 'none',
  'scroll-marker-group': 'none',
  // View transitions
  'view-transition': 'none',
  'view-transition-group': 'required',
  'view-transition-image-pair': 'required',
  'view-transition-old': 'required',
  'view-transition-new': 'required',
};

/// A pseudo-element such as `::before` or `::part(header)`.
///
/// Audit **§2.2A**: this replaces thirty-one separate classes
/// (`BeforePseudoElement`, `MarkerPseudoElement`, …) that were exported and
/// documented but never constructed by the parser — it flattened every
/// pseudo-element to a bare string. Names are now validated against
/// [knownPseudoElements], so `::bogus` is a parse error rather than a
/// silently-accepted no-op.
class PseudoElementSelector extends Sel {
  /// The pseudo-element name, without the leading `::`.
  final String name;

  /// The argument, for functional forms like `::part(header)`.
  final String? argument;

  /// Creates a pseudo-element selector.
  const PseudoElementSelector(this.name, [this.argument]);

  @override
  bool matchElement(Element element, MatchContext context) {
    // A pseudo-element denotes a rendered fragment, never an element node.
    if (context.strict) {
      throw UndecidableSelectorError(
          toString(), 'pseudo-elements match rendered fragments, not nodes');
    }
    return false;
  }

  @override
  Specificity get specificity => Specificity.typeSelector;

  @override
  String get pseudoElement => argument == null ? name : '$name($argument)';

  @override
  MatchSupport get support => MatchSupport.neverDecidable;

  @override
  Set<String> get undecidableParts => {toString()};

  @override
  String toString() => '::$pseudoElement';
}

/// The CSS nesting selector `&`.
class NestingSelector extends PseudoClassSelector {
  /// Creates a nesting selector.
  const NestingSelector();

  @override
  bool matchElement(Element element, MatchContext context) {
    final scope = context.scope;
    if (scope != null) return identical(scope, element);
    if (context.strict) {
      throw UndecidableSelectorError(
          '&', 'the nesting selector needs a parent context');
    }
    return false;
  }

  @override
  Specificity get specificity => Specificity.zero;

  @override
  MatchSupport get support => MatchSupport.requiresContext;

  @override
  Set<String> get undecidableParts => {'&'};

  @override
  String toString() => '&';
}
