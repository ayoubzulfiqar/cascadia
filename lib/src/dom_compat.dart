import 'package:html/dom.dart';

/// Node traversal helpers that `package:html` does not provide directly.
extension NodeTraversal on Node {
  /// The first child node, or null when there are none.
  Node? get firstChild => nodes.isEmpty ? null : nodes.first;

  /// The last child node, or null when there are none.
  Node? get lastChild => nodes.isEmpty ? null : nodes.last;

  /// The next sibling node, or null when this is the last.
  Node? get nextSibling {
    final siblings = parentNode?.nodes;
    if (siblings == null) return null;
    final index = _indexIn(siblings);
    if (index < 0 || index + 1 >= siblings.length) return null;
    return siblings[index + 1];
  }

  /// The previous sibling node, or null when this is the first.
  Node? get previousSibling {
    final siblings = parentNode?.nodes;
    if (siblings == null) return null;
    final index = _indexIn(siblings);
    if (index <= 0) return null;
    return siblings[index - 1];
  }

  int _indexIn(List<Node> siblings) {
    for (var i = 0; i < siblings.length; i++) {
      if (identical(siblings[i], this)) return i;
    }
    return -1;
  }
}

/// Element-only sibling traversal.
extension ElementSibling on Node {
  /// The closest preceding sibling that is an [Element].
  Element? get previousElementSibling {
    final parent = parentNode;
    if (parent == null) return null;
    Element? last;
    for (final child in parent.nodes) {
      if (identical(child, this)) return last;
      if (child is Element) last = child;
    }
    return null;
  }

  /// The closest following sibling that is an [Element].
  Element? get nextElementSibling {
    final parent = parentNode;
    if (parent == null) return null;
    var seen = false;
    for (final child in parent.nodes) {
      if (seen && child is Element) return child;
      if (identical(child, this)) seen = true;
    }
    return null;
  }
}

/// A `tagName` alias for [Element.localName].
extension ElementTagName on Element {
  /// The lowercased tag name of this element.
  String get tagName => (localName ?? '').toLowerCase();
}
