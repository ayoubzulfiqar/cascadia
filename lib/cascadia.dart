import 'dart:collection';

import 'package:html/dom.dart' show Document, Element, Node;

import 'src/match_context.dart';
import 'src/matcher.dart';
import 'src/parser.dart';

export 'src/combined_selector.dart';
export 'src/escape.dart' show escapeCssIdent, escapeCssString;
export 'src/match_context.dart';
export 'src/matcher.dart';
export 'src/parser.dart' show Parser;
export 'src/pseudo_classes.dart';
export 'src/selectors.dart';
export 'src/specificity.dart';

const int _maxCacheSize = 512;
const int _maxCacheableLength = 512;

/// A bounded least-recently-used cache of parsed selectors.
///
/// Audit **P0-5**: the previous cache claimed to be an LRU but flushed itself
/// entirely once full, and cached selectors of any length, so hostile input
/// could thrash it. Insertion order in a [LinkedHashMap] gives a real LRU.
final LinkedHashMap<String, Sel> _parseCache = LinkedHashMap<String, Sel>();

Sel _cachedParse(String selector) {
  final hit = _parseCache.remove(selector);
  if (hit != null) {
    _parseCache[selector] = hit; // move to most-recently-used
    return hit;
  }
  final parsed = Parser.parse(selector);
  if (selector.length <= _maxCacheableLength) {
    if (_parseCache.length >= _maxCacheSize) {
      _parseCache.remove(_parseCache.keys.first);
    }
    _parseCache[selector] = parsed;
  }
  return parsed;
}

/// Removes every entry from the parsed-selector cache.
void clearSelectorCache() => _parseCache.clear();

/// The number of selectors currently cached. Exposed for tests and tuning.
int get selectorCacheSize => _parseCache.length;

/// Parses [selector] into a reusable [Sel].
///
/// Throws a [FormatException] if the selector is not valid.
///
/// ```dart
/// final sel = parse('div.foo > p');
/// ```
Sel parse(String selector) => _cachedParse(selector);

/// Parses [selector], which may be a comma-separated list.
Sel parseGroup(String selector) => _cachedParse(selector);

/// Parses [selector] with pseudo-elements such as `::before` permitted.
Sel parseWithPseudoElements(String selector) =>
    Parser.parseWithPseudoElements(selector);

/// Parses [selector], tolerating pseudo-classes this library does not know.
///
/// Useful for forward compatibility with newer CSS; unknown pseudo-classes
/// never match.
Sel parseLenient(String selector) =>
    Parser.parse(selector, allowUnknownPseudoClasses: true);

/// Compiles [selector] into a predicate function.
Selector compile(String selector) => _cachedParse(selector).asFunction();

/// Whether [node] matches [selector].
bool matches(Node node, String selector,
        [MatchContext context = MatchContext.empty]) =>
    _cachedParse(selector).matchWith(node, context);

/// Returns the first descendant of [root] matching [selector], or null.
///
/// Like `querySelector`, [root] itself is never returned.
Element? query(Node root, String selector,
    [MatchContext context = MatchContext.empty]) {
  final sel = _cachedParse(selector);
  for (final element in _descendantElements(root)) {
    if (sel.matchWith(element, context)) return element;
  }
  return null;
}

/// Returns every descendant of [root] matching [selector].
///
/// Audit **P1-8**: [root] itself is excluded, matching the DOM's
/// `querySelectorAll`. The previous implementation included it, so
/// `queryAll(divElement, 'div')` wrongly returned the element itself.
List<Element> queryAll(Node root, String selector,
    [MatchContext context = MatchContext.empty]) {
  final sel = _cachedParse(selector);
  final results = <Element>[];
  for (final element in _descendantElements(root)) {
    if (sel.matchWith(element, context)) results.add(element);
  }
  return results;
}

/// Returns the closest inclusive ancestor of [node] matching [selector].
Element? closest(Node node, String selector,
    [MatchContext context = MatchContext.empty]) {
  final sel = _cachedParse(selector);
  for (Node? n = node; n != null; n = n.parentNode) {
    if (n is Element && sel.matchWith(n, context)) return n;
  }
  return null;
}

/// Yields every descendant element of [root] in document order.
///
/// Iterative rather than recursive so deep documents cannot overflow the
/// stack, and lazy so [query] can stop at the first match.
Iterable<Element> _descendantElements(Node root) sync* {
  final stack = <Node>[];
  for (var i = root.nodes.length - 1; i >= 0; i--) {
    stack.add(root.nodes[i]);
  }
  while (stack.isNotEmpty) {
    final node = stack.removeLast();
    if (node is Element) yield node;
    if (node is Element || node is Document) {
      for (var i = node.nodes.length - 1; i >= 0; i--) {
        stack.add(node.nodes[i]);
      }
    }
  }
}

/// Serializes [sel] back to CSS text.
///
/// Audit **§3.1**: the old `Serializer` class duplicated every `toString()`
/// implementation and reproduced their bugs; selectors now serialize
/// themselves.
String serialize(Sel sel) => sel.toString();
