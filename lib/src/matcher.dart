import 'package:html/dom.dart';

import 'specificity.dart';

/// A selector that can match an HTML node.
///
/// This is the core matching interface. Implementations must provide
/// a [match] method and a [specificity] getter.
abstract class Matcher {
  /// Returns true if this selector matches the given [node].
  bool match(Node node);

  /// The specificity of this selector as a triple [A, B, C].
  Specificity get specificity;

  /// Returns the name of the pseudo-element if this selector represents
  /// a pseudo-element, or an empty string otherwise.
  ///
  /// Only one pseudo-element may appear per selector, and it must be
  /// at the end of the selector.
  String get pseudoElement;
}

/// A more specific selector interface that also supports serialization.
///
/// This extends [Matcher] with a [toString] that produces valid CSS.
abstract class Sel extends Matcher {
  @override
  String toString();
}

/// A selector group represents a comma-separated list of selectors.
///
/// It matches a node if ANY of its component selectors matches.
class SelectorGroup implements Sel {
  final List<Sel> selectors;

  SelectorGroup(this.selectors);

  @override
  bool match(Node node) {
    for (final sel in selectors) {
      if (sel.match(node)) return true;
    }
    return false;
  }

  @override
  Specificity get specificity {
    // For a selector group, specificity is the maximum of its components.
    var max = Specificity(0, 0, 0);
    for (final sel in selectors) {
      final spec = sel.specificity;
      if (spec > max) max = spec;
    }
    return max;
  }

  @override
  String get pseudoElement => '';

  @override
  String toString() {
    return selectors.join(', ');
  }
}

/// A type alias for backward compatibility: a simple function that matches nodes.
///
/// This allows using selectors as `bool Function(Node)` in APIs that expect
/// the original Cascadia signature.
typedef Selector = bool Function(Node);

/// Convenience adapter to convert a [Sel] to a [Selector] function.
///
/// Example:
/// ```dart
/// final sel = parse('div.foo');
/// final matcher = sel.asFunction();
/// final matches = matcher(someNode);
/// ```
extension SelAdapter on Sel {
  Selector asFunction() => match;
}
