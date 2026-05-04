import 'package:html/dom.dart';

import 'matcher.dart';
import 'specificity.dart';

/// A type selector that matches elements by tag name.
///
/// Example: `div`, `p`, `span`
/// Specificity: (0, 0, 1)
class TagSelector implements Sel {
  final String tag;

  /// Tag names are compared case-insensitively in HTML.
  TagSelector(this.tag);

  @override
  bool match(Node node) {
    if (node is! Element) return false;

    // Universal selector matches any element
    if (tag == '*') return true;

    final nodeTag = node.localName ?? '';

    // Check for namespace separator '|'
    final pipeIdx = tag.indexOf('|');
    if (pipeIdx != -1) {
      final nsPrefix = tag.substring(0, pipeIdx);
      final localPart = tag.substring(pipeIdx + 1);

      // Local name must match
      if (nodeTag != localPart) return false;

      // Namespace matching
      // Namespace prefix not directly available in package:html; treat as null for now.
      final nodePrefix = null;
      if (nsPrefix == '*') {
        return true; // any namespace
      } else if (nsPrefix.isEmpty) {
        // '|a' matches elements with no namespace prefix
        return nodePrefix == null || nodePrefix.isEmpty;
      } else {
        return nsPrefix == nodePrefix;
      }
    } else {
      // No namespace constraint
      return nodeTag.toLowerCase() == tag.toLowerCase();
    }
  }

  @override
  Specificity get specificity => Specificity.typeSelector;

  @override
  String get pseudoElement => '';

  @override
  String toString() => tag;
}

/// A class selector that matches elements with a given class.
///
/// Example: `.foo`, `.bar`
/// Matches if the element's class attribute contains the class name
/// as a whitespace-separated token.
/// Specificity: (0, 1, 0)
class ClassSelector implements Sel {
  final String className;

  ClassSelector(this.className);

  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final classAttr = node.attributes['class'];
    if (classAttr == null) return false;
    // Split on whitespace and check for exact match (case-insensitive)
    final classes = classAttr.split(RegExp(r'\s+'));
    return classes.any((c) => c.toLowerCase() == className.toLowerCase());
  }

  @override
  Specificity get specificity => Specificity.classSelector;

  @override
  String get pseudoElement => '';

  @override
  String toString() => '.$className';
}

/// An ID selector that matches an element with a specific ID.
///
/// Example: `#header`, `#main`
/// Specificity: (1, 0, 0)
class IdSelector implements Sel {
  final String id;

  IdSelector(this.id);

  @override
  bool match(Node node) {
    if (node is! Element) return false;
    return node.id == id;
  }

  @override
  Specificity get specificity => Specificity.idSelector;

  @override
  String get pseudoElement => '';

  @override
  String toString() => '#$id';
}

/// Attribute operator types for attribute selectors.
enum AttrOp {
  /// `[attr]` - presence
  present,

  /// `[attr=value]` - exact match
  equal,

  /// `[attr~=value]` - whitespace-separated word list includes value
  includes,

  /// `[attr|=value]` - value or value-*
  dashMatch,

  /// `[attr^=value]` - starts with
  prefix,

  /// `[attr$=value]` - ends with
  suffix,

  /// `[attr*=value]` - contains substring
  substring,

  /// `[attr!=value]` - not equal
  notEqual,

  /// `[attr#=regex]` - regex match (non-standard extension)
  regexMatch,
}

/// An attribute selector that matches elements based on attribute values.
///
/// Examples:
/// - `[href]` - presence
/// - `[href="https://example.com"]` - exact match
/// - `[class~="active"]` - class contains "active"
/// - `[lang|="en"]` - starts with "en" or "en-"
/// - `[href^="https"]` - starts with
/// - `[src$=".png"]` - ends with
/// - `[title*="warning"]` - contains
/// - `[data-id#="^[0-9]+$"]` - regex match (non-standard)
/// - `[type="password" i]` - case-insensitive match (non-standard 'i' flag)
///
/// Specificity: (0, 1, 0)
class AttributeSelector implements Sel {
  final String attributeName;
  final AttrOp operation;
  final String? value;
  final RegExp? regexp;
  final bool caseInsensitive;

  AttributeSelector({
    required this.attributeName,
    required this.operation,
    this.value,
    this.regexp,
    this.caseInsensitive = false,
  });

  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final attrValue = node.attributes[attributeName];
    if (operation == AttrOp.present) {
      return attrValue != null;
    }
    if (attrValue == null) return false;

    final compareValue = value ?? '';
    final source = attrValue;
    final pattern = caseInsensitive ? compareValue.toLowerCase() : compareValue;
    final target = caseInsensitive ? source.toLowerCase() : source;

    switch (operation) {
      case AttrOp.equal:
        return target == pattern;
      case AttrOp.includes:
        return target.split(RegExp(r'\s+')).any((token) => token == pattern);
      case AttrOp.dashMatch:
        return target == pattern || target.startsWith('$pattern-');
      case AttrOp.prefix:
        return target.startsWith(pattern);
      case AttrOp.suffix:
        return target.endsWith(pattern);
      case AttrOp.substring:
        return target.contains(pattern);
      case AttrOp.notEqual:
        return target != pattern;
      case AttrOp.regexMatch:
        if (regexp == null) return false;
        return regexp!.hasMatch(source);
      case AttrOp.present:
        // Already handled above
        return true;
    }
  }

  @override
  Specificity get specificity => Specificity.classSelector;

  @override
  String get pseudoElement => '';

  @override
  String toString() {
    final name = attributeName;
    switch (operation) {
      case AttrOp.present:
        return '[$name]';
      case AttrOp.equal:
        return '[$name="$value"]';
      case AttrOp.includes:
        return '[$name~="$value"]';
      case AttrOp.dashMatch:
        return '[$name|="$value"]';
      case AttrOp.prefix:
        return '[$name^="$value"]';
      case AttrOp.suffix:
        return r'[$name$="$value"]';
      case AttrOp.substring:
        return '[$name*="$value"]';
      case AttrOp.notEqual:
        return '[$name!="$value"]';
      case AttrOp.regexMatch:
        return '[$name#=$value]';
    }
  }
}
