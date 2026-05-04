import 'package:html/dom.dart';

/// Compatibility extension providing traversal getters for Node.
///
/// The `package:html` DOM implementation does not provide `firstChild`,
/// `nextSibling`, and `previousSibling` directly. This extension derives
/// them from the `nodes` list and `parentNode`.
extension NodeTraversal on Node {
  /// Returns the first child node, or null if there are no children.
  Node? get firstChild {
    final childNodes = nodes;
    return childNodes.isEmpty ? null : childNodes.first;
  }

  /// Returns the next sibling node, or null if this is the last sibling.
  Node? get nextSibling {
    final parent = parentNode;
    if (parent == null) return null;
    final siblings = parent.nodes;
    final index = siblings.indexOf(this);
    if (index == -1 || index + 1 >= siblings.length) return null;
    return siblings[index + 1];
  }

  /// Returns the previous sibling node, or null if this is the first sibling.
  Node? get previousSibling {
    final parent = parentNode;
    if (parent == null) return null;
    final siblings = parent.nodes;
    final index = siblings.indexOf(this);
    if (index <= 0) return null;
    return siblings[index - 1];
  }
}

/// Extension to get only element siblings.
///
/// Provides previousElementSibling and nextElementSibling for Node/Element.
extension ElementSibling on Node {
  /// Returns the previous sibling that is an [Element], or null.
  Element? get previousElementSibling {
    var sibling = previousSibling;
    while (sibling != null) {
      if (sibling is Element) return sibling;
      sibling = sibling.previousSibling;
    }
    return null;
  }

  /// Returns the next sibling that is an [Element], or null.
  Element? get nextElementSibling {
    var sibling = nextSibling;
    while (sibling != null) {
      if (sibling is Element) return sibling;
      sibling = sibling.nextSibling;
    }
    return null;
  }
}

/// Extension to provide `tagName` for Element, mirroring the standard DOM API.
///
/// In `package:html`, Element exposes `localName`. This getter provides
/// a `tagName` aliases for compatibility.
extension ElementTagName on Element {
  /// Returns the tag name of this element (lowercase for HTML elements).
  String get tagName => localName ?? '';
}
