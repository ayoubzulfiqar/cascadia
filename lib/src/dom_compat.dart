import 'package:html/dom.dart';

/// A lowercased `tagName` alias for [Element.localName].
///
/// HTML tag names are matched case-insensitively and `localName` is nullable,
/// so this removes a repeated `(localName ?? '').toLowerCase()` from every
/// selector implementation.
///
/// Sibling traversal helpers previously lived here too, but `package:html`
/// defines `previousElementSibling`/`nextElementSibling` on `Element`, so its
/// own members always won and the extension versions were unreachable.
extension ElementTagName on Element {
  /// The lowercased tag name of this element.
  String get tagName => (localName ?? '').toLowerCase();
}
