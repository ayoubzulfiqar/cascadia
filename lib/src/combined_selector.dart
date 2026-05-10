import 'package:html/dom.dart';

import 'matcher.dart';
import 'specificity.dart';

/// A compound selector combines multiple simple selectors that all apply
/// to the same element.
///
/// Example: `div.foo#bar[href]` is a compound of tag, class, id, and attr.
/// Only one pseudo-element may appear per compound selector, and it must
/// be at the end.
///
/// Specificity = sum of all sub-selectors + (0,0,1) if pseudo-element present.
class CompoundSelector implements Sel {
  final List<Sel> selectors;
  @override
  final String pseudoElement;

  CompoundSelector({
    required this.selectors,
    this.pseudoElement = '',
  });

  @override
  bool match(Node node) {
    for (final sel in selectors) {
      if (!sel.match(node)) return false;
    }
    return true;
  }

  @override
  Specificity get specificity {
    var sum = Specificity(0, 0, 0);
    for (final sel in selectors) {
      sum = sum + sel.specificity;
    }
    if (pseudoElement.isNotEmpty) {
      sum = sum + Specificity(0, 0, 1);
    }
    return sum;
  }

  @override
  String toString() {
    final parts = selectors.map((s) => s.toString()).join('');
    if (pseudoElement.isNotEmpty) {
      return '$parts::$pseudoElement';
    }
    return parts.isEmpty ? '*' : parts;
  }
}

/// A combined selector represents two selectors connected by a combinator.
///
/// The combinator can be:
/// - ' ' (space): descendant combinator
/// - '>': child combinator
/// - '+': adjacent sibling combinator
/// - '~': general sibling combinator
///
/// Example: `div > p.foo` has first=div, combinator='>', second=p.foo
///
/// Specificity = sum of first + second.
class CombinedSelector implements Sel {
  final Sel first;
  final String combinator;
  final Sel second;

  CombinedSelector({
    required this.first,
    required this.combinator,
    required this.second,
  });

  @override
  bool match(Node node) {
    // The second selector must match the node itself.
    if (!second.match(node)) return false;

    // Check the relationship between first and second.
    switch (combinator) {
      case ' ':
        return _descendantMatch(node);
      case '>':
        return _childMatch(node);
      case '+':
        return _siblingMatch(node, adjacent: true);
      case '~':
        return _siblingMatch(node, adjacent: false);
      default:
        return false;
    }
  }

  /// Check if [node] has an ancestor that matches [first].
  bool _descendantMatch(Node node) {
    var parent = node.parentNode;
    while (parent != null) {
      if (first.match(parent)) return true;
      parent = parent.parentNode;
    }
    return false;
  }

  /// Check if [node]'s immediate parent matches [first].
  bool _childMatch(Node node) {
    final parent = node.parentNode;
    return parent != null && first.match(parent);
  }

  /// Check sibling relationship.
  ///
  /// If [adjacent] is true, only the immediately preceding sibling is checked.
  /// If false, any preceding element sibling is checked.
  bool _siblingMatch(Node node, {required bool adjacent}) {
    final parent = node.parentNode;
    if (parent == null) return false;

    // Iterate through siblings to find index and check preceding elements
    int foundIdx = -1;
    int idx = 0;
    
    // First pass: find the index of this node among element siblings
    for (var i = 0; i < parent.nodes.length; i++) {
      final child = parent.nodes[i];
      if (child is Element) {
        if (identical(child, node)) {
          foundIdx = idx;
          break;
        }
        idx++;
      }
    }
    if (foundIdx == -1) return false;

    // Second pass: check preceding siblings
    if (adjacent) {
      if (foundIdx == 0) return false;
      // Find the immediate previous sibling
      idx = 0;
      for (var i = 0; i < parent.nodes.length; i++) {
        final child = parent.nodes[i];
        if (child is Element) {
          if (idx == foundIdx - 1) return first.match(child);
          idx++;
        }
      }
      return false;
    } else {
      // Check all preceding siblings
      int checkIdx = 0;
      for (var i = 0; i < parent.nodes.length; i++) {
        final child = parent.nodes[i];
        if (child is Element) {
          if (checkIdx == foundIdx) break;
          if (first.match(child)) return true;
          checkIdx++;
        }
      }
      return false;
    }
  }

  @override
  Specificity get specificity => first.specificity + second.specificity;

  @override
  String get pseudoElement => second.pseudoElement;

  @override
  String toString() {
    final firstStr = first.toString();
    final secondStr = second.toString();
    final comb = combinator == ' ' ? ' ' : combinator;
    return '$firstStr $comb $secondStr';
  }
}
