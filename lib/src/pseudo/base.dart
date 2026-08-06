import 'package:html/dom.dart';

import '../match_context.dart';
import '../matcher.dart';
import '../specificity.dart';

/// Base class for pseudo-class selectors. Defaults to `(0,1,0)` specificity.
abstract class PseudoClassSelector extends Sel {
  /// Creates a pseudo-class selector.
  const PseudoClassSelector();

  @override
  Specificity get specificity => Specificity.classSelector;
}

/// A pseudo-class whose result depends on runtime state the caller may supply.
///
/// Audit **§2.2A/§2.2B**: roughly ninety pseudo-classes were previously
/// separate classes whose entire body was `return false`, which made
/// "not implemented" indistinguishable from "did not match". They are now a
/// single parameterised type that reports what it needs via
/// [Sel.undecidableParts] and can throw under [MatchContext.strict].
class UndecidablePseudoClass extends PseudoClassSelector {
  /// The CSS text of the pseudo-class, e.g. `:hover`.
  final String name;

  /// Why it cannot be decided from a static DOM.
  final String reason;

  @override
  final MatchSupport support;

  /// Creates an undecidable pseudo-class.
  const UndecidablePseudoClass(
    this.name,
    this.reason, {
    this.support = MatchSupport.requiresContext,
  });

  @override
  bool matchElement(Element element, MatchContext context) {
    if (context.strict) throw UndecidableSelectorError(name, reason);
    return false;
  }

  @override
  Set<String> get undecidableParts => {name};

  @override
  String toString() => name;
}

/// A pseudo-class this library does not recognise.
///
/// Only produced when the parser runs with `allowUnknownPseudoClasses: true`;
/// by default an unknown pseudo-class is a parse error (audit **P2-8**).
class UnknownPseudoClass extends PseudoClassSelector {
  /// The unrecognised pseudo-class name, without the leading colon.
  final String name;

  /// Creates an unknown pseudo-class.
  const UnknownPseudoClass(this.name);

  @override
  bool matchElement(Element element, MatchContext context) {
    if (context.strict) {
      throw UndecidableSelectorError(':$name', 'unknown pseudo-class');
    }
    return false;
  }

  @override
  MatchSupport get support => MatchSupport.neverDecidable;

  @override
  Set<String> get undecidableParts => {':$name'};

  @override
  String toString() => ':$name';
}

/// Text extraction helpers shared by `:contains()` and `:matches()`.
///
/// Audit **§2.2D**: these were duplicated verbatim across two classes.
abstract final class TextContent {
  /// The concatenated text of [node] and all of its descendants.
  static String all(Node node) {
    final buffer = StringBuffer();
    final stack = <Node>[node];
    final ordered = <Node>[];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      ordered.add(current);
      for (var i = current.nodes.length - 1; i >= 0; i--) {
        stack.add(current.nodes[i]);
      }
    }
    for (final n in ordered) {
      if (n is Text) buffer.write(n.data);
    }
    return buffer.toString();
  }

  /// The text of [node]'s immediate text children only.
  static String own(Node node) {
    final buffer = StringBuffer();
    for (final child in node.nodes) {
      if (child is Text) buffer.write(child.data);
    }
    return buffer.toString();
  }
}
