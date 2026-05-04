// Library export for Cascadia CSS selector engine.
export 'src/matcher.dart';
export 'src/selectors.dart';
export 'src/specificity.dart';

// Parser and compilation
export 'src/parser.dart';

// Pseudo-classes and pseudo-elements
export 'src/pseudo_classes.dart';

// Serialization utilities
export 'src/serialize.dart';

import 'package:html/dom.dart';

import 'src/dom_compat.dart';
import 'src/matcher.dart';
import 'src/parser.dart';
import 'src/serialize.dart';

/// Parse a CSS selector string into a [Sel] object.
///
/// The selector can be used for matching nodes or for serialization.
///
/// Example:
/// ```dart
/// final sel = parse('div.foo > p.bar');
/// print(sel); // outputs: div.foo > p.bar
/// ```
///
/// Throws [FormatException] if the selector syntax is invalid.
Sel parse(String selector) {
  return Parser.parse(selector);
}

/// Parse a CSS selector group (comma-separated list) into a [Sel].
///
/// A selector group matches if ANY of the individual selectors matches.
///
/// Example:
/// ```dart
/// final group = parseGroup('div, span.foo, #bar');
/// ```
Sel parseGroup(String selector) {
  return Parser.parseGroup(selector);
}

/// Compile a CSS selector into a reusable matching function.
///
/// This is equivalent to `parse(selector).asFunction()`.
/// The returned function can be called repeatedly on nodes without
/// re-parsing the selector.
///
/// Example:
/// ```dart
/// final matcher = compile('p.intro');
/// final matches = doc.querySelectorAll('*').where(matcher);
/// ```
Selector compile(String selector) {
  return Parser.parse(selector).asFunction();
}

/// Parse a selector with pseudo-element support enabled.
///
/// By default, pseudo-elements (::before, ::after, etc.) are not allowed
/// as they require special handling. Use this function when you need
/// to work with pseudo-elements.
///
/// Example:
/// ```dart
/// final sel = parseWithPseudoElements('p::first-line');
/// ```
///
/// Throws [FormatException] if a pseudo-element is encountered and
/// pseudo-elements are not allowed.
Sel parseWithPseudoElements(String selector) {
  return Parser.parseWithPseudoElements(selector);
}

/// Find the first descendant of [root] that matches [selector].
///
/// This is similar to the DOM's `querySelector`, but powered by this
/// CSS selector engine.
///
/// Example:
/// ```dart
/// final doc = parseHTML(htmlString);
/// final first = query(doc, 'div.content');
/// ```
Element? query(Node root, String selector) {
  final matcher = compile(selector);
  return _queryNode(root, matcher) as Element?;
}

/// Find all descendants of [root] that match [selector].
///
/// This is similar to the DOM's `querySelectorAll`, but uses this
/// selector engine. Returns a list of matching [Element] nodes.
///
/// Example:
/// ```dart
/// final matches = queryAll(doc, '.highlighted');
/// print('Found ${matches.length} matches');
/// ```
List<Element> queryAll(Node root, String selector) {
  final matcher = compile(selector);
  final results = <Element>[];
  _collectMatches(root, matcher, results);
  return results;
}

/// Find the first descendant of [root] that matches the compiled [matcher].
///
/// This is the low-level version that takes a pre-compiled selector function.
Node? _queryNode(Node root, Selector matcher) {
  if (matcher(root)) return root;
  for (var child = root.firstChild; child != null; child = child.nextSibling) {
    final result = _queryNode(child, matcher);
    if (result != null) return result;
  }
  return null;
}

/// Collect all descendants of [root] that match [matcher] into [results].
void _collectMatches(Node root, Selector matcher, List<Element> results) {
  if (matcher(root) && root is Element) {
    results.add(root);
  }
  for (var child = root.firstChild; child != null; child = child.nextSibling) {
    _collectMatches(child, matcher, results);
  }
}

/// Check if a [node] matches the given [selector] without compilation.
///
/// This is a convenience function for one-off checks.
///
/// Example:
/// ```dart
/// if (matches(node, '.active')) {
///   print('Node is active');
/// }
/// ```
bool matches(Node node, String selector) {
  return Parser.parse(selector).match(node);
}

/// Serialize a [Sel] back to a CSS selector string.
///
/// This is the inverse of [parse]. It converts selector objects
/// back into their textual representation.
///
/// Example:
/// ```dart
/// final sel = parse('div.foo#bar');
/// print(serialize(sel)); // div.foo#bar
/// ```
String serialize(Sel sel) {
  return Serializer.serialize(sel);
}
