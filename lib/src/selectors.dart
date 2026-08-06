import 'package:html/dom.dart';

import 'escape.dart';
import 'match_context.dart';
import 'matcher.dart';
import 'specificity.dart';

final RegExp _whitespacePattern = RegExp(r'\s+');

/// Well-known namespace URIs, used to resolve namespace prefixes.
const Map<String, String> defaultNamespaces = <String, String>{
  'html': 'http://www.w3.org/1999/xhtml',
  'svg': 'http://www.w3.org/2000/svg',
  'math': 'http://www.w3.org/1998/Math/MathML',
  'xlink': 'http://www.w3.org/1999/xlink',
  'xml': 'http://www.w3.org/XML/1998/namespace',
  'xmlns': 'http://www.w3.org/2000/xmlns/',
};

/// Serializes a namespace prefix: `*` and the empty prefix are literal.
String _serializeNsPrefix(String prefix) =>
    prefix == '*' || prefix.isEmpty ? prefix : escapeCssIdent(prefix);

/// The universal selector `*`.
///
/// Audit **P2-4**: split out of [TagSelector] so it can carry the correct
/// zero specificity instead of a type selector's `(0,0,1)`.
class UniversalSelector extends Sel {
  /// The namespace prefix, or null for "no namespace constraint".
  final String? namespacePrefix;

  /// Creates a universal selector, optionally namespace-qualified (`svg|*`).
  const UniversalSelector({this.namespacePrefix});

  @override
  bool matchElement(Element element, MatchContext context) =>
      namespaceMatches(element, namespacePrefix);

  @override
  Specificity get specificity => Specificity.zero;

  @override
  String toString() => namespacePrefix == null
      ? '*'
      : '${_serializeNsPrefix(namespacePrefix!)}|*';
}

/// Whether [element] satisfies the namespace constraint [prefix].
///
/// Audit **P1-10**: namespace matching used to be dead code — the element
/// prefix was hardcoded to `null`. It now resolves against the element's real
/// [Element.namespaceUri].
bool namespaceMatches(Element element, String? prefix) {
  if (prefix == null || prefix == '*') return true;
  final uri = element.namespaceUri;
  if (prefix.isEmpty) {
    // `|tag` matches only elements in no namespace.
    return uri == null || uri.isEmpty;
  }
  final expected = defaultNamespaces[prefix.toLowerCase()];
  if (expected != null) return uri == expected;
  // Unknown prefix: compare literally so callers can use raw URIs.
  return uri == prefix;
}

/// A type selector such as `div`, or `svg|rect` when namespace-qualified.
class TagSelector extends Sel {
  /// The local element name, lowercased.
  final String tag;

  /// The namespace prefix, or null when unconstrained.
  final String? namespacePrefix;

  /// Creates a type selector.
  TagSelector(String tag, {this.namespacePrefix}) : tag = tag.toLowerCase();

  @override
  bool matchElement(Element element, MatchContext context) {
    if (!namespaceMatches(element, namespacePrefix)) return false;
    return (element.localName ?? '').toLowerCase() == tag;
  }

  @override
  Specificity get specificity => Specificity.typeSelector;

  @override
  String toString() => namespacePrefix == null
      ? escapeCssIdent(tag)
      : '${_serializeNsPrefix(namespacePrefix!)}|${escapeCssIdent(tag)}';
}

/// A class selector such as `.warning`.
class ClassSelector extends Sel {
  /// The class name to match.
  final String className;

  /// Creates a class selector.
  ClassSelector(this.className);

  @override
  bool matchElement(Element element, MatchContext context) {
    final classAttr = element.attributes['class'];
    if (classAttr == null || classAttr.isEmpty) return false;
    // Audit P1-2: HTML class names are case-SENSITIVE in standards mode.
    for (final c in classAttr.split(_whitespacePattern)) {
      if (c == className) return true;
    }
    return false;
  }

  @override
  Specificity get specificity => Specificity.classSelector;

  @override
  String toString() => '.${escapeCssIdent(className)}';
}

/// An ID selector such as `#header`.
class IdSelector extends Sel {
  /// The ID to match.
  final String id;

  /// Creates an ID selector.
  IdSelector(this.id);

  @override
  bool matchElement(Element element, MatchContext context) =>
      element.attributes['id'] == id;

  @override
  Specificity get specificity => Specificity.idSelector;

  @override
  String toString() => '#${escapeCssIdent(id)}';
}

/// The operators supported by [AttributeSelector].
enum AttrOp {
  /// `[attr]` — the attribute is present.
  present,

  /// `[attr=value]` — exact match.
  equal,

  /// `[attr~=value]` — whitespace-separated word match.
  includes,

  /// `[attr|=value]` — equal to `value`, or starting with `value-`.
  dashMatch,

  /// `[attr^=value]` — prefix match.
  prefix,

  /// `[attr$=value]` — suffix match.
  suffix,

  /// `[attr*=value]` — substring match.
  substring,

  /// `[attr!=value]` — negated exact match (non-standard).
  notEqual,

  /// `[attr#=regex]` — regular-expression match (non-standard).
  regexMatch,
}

/// An attribute selector such as `[href^="https"]`.
class AttributeSelector extends Sel {
  /// The attribute name.
  final String attributeName;

  /// The comparison operator.
  final AttrOp operation;

  /// The value being compared against, if the operator takes one.
  final String? value;

  /// The compiled pattern for [AttrOp.regexMatch].
  final RegExp? regexp;

  /// Whether the comparison ignores case (the `i` flag).
  final bool caseInsensitive;

  /// Creates an attribute selector.
  AttributeSelector({
    required this.attributeName,
    required this.operation,
    this.value,
    this.regexp,
    this.caseInsensitive = false,
  });

  @override
  bool matchElement(Element element, MatchContext context) {
    final attrValue = element.attributes[attributeName];

    if (operation == AttrOp.present) return attrValue != null;

    // `[attr!=value]` is true when the attribute is absent, matching the
    // behaviour of the original Go cascadia.
    if (attrValue == null) return operation == AttrOp.notEqual;

    if (operation == AttrOp.regexMatch) {
      return regexp != null && regexp!.hasMatch(attrValue);
    }

    final pattern = caseInsensitive ? (value ?? '').toLowerCase() : value ?? '';
    final target = caseInsensitive ? attrValue.toLowerCase() : attrValue;

    switch (operation) {
      case AttrOp.equal:
        return target == pattern;
      case AttrOp.includes:
        if (pattern.isEmpty) return false;
        for (final token in target.split(_whitespacePattern)) {
          if (token == pattern) return true;
        }
        return false;
      case AttrOp.dashMatch:
        return target == pattern || target.startsWith('$pattern-');
      case AttrOp.prefix:
        return pattern.isNotEmpty && target.startsWith(pattern);
      case AttrOp.suffix:
        return pattern.isNotEmpty && target.endsWith(pattern);
      case AttrOp.substring:
        return pattern.isNotEmpty && target.contains(pattern);
      case AttrOp.notEqual:
        return target != pattern;
      case AttrOp.present:
      case AttrOp.regexMatch:
        return true; // handled above
    }
  }

  @override
  Specificity get specificity => Specificity.classSelector;

  @override
  String toString() {
    final name = escapeCssIdent(attributeName);
    final flag = caseInsensitive ? ' i' : '';
    if (operation == AttrOp.present) return '[$name]';
    if (operation == AttrOp.regexMatch) {
      return '[$name#=/${regexp?.pattern ?? ''}/]';
    }
    // Audit P2-1: this used to be a raw string, so every suffix selector
    // serialized to the literal text `[$name$="$value"]`.
    const ops = <AttrOp, String>{
      AttrOp.equal: '=',
      AttrOp.includes: '~=',
      AttrOp.dashMatch: '|=',
      AttrOp.prefix: '^=',
      AttrOp.suffix: r'$=',
      AttrOp.substring: '*=',
      AttrOp.notEqual: '!=',
    };
    return '[$name${ops[operation]}${escapeCssString(value ?? '')}$flag]';
  }
}
