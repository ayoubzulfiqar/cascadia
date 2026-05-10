import 'package:html/dom.dart';

import 'dom_compat.dart';
import 'matcher.dart';
import 'specificity.dart';

/// Base class for all pseudo-class selectors.
///
/// By default, pseudo-classes have specificity (0,1,0) unless overridden.
abstract class PseudoClassSelector implements Sel {
  const PseudoClassSelector();

  @override
  String get pseudoElement => '';

  @override
  Specificity get specificity => Specificity.classSelector;
}

// ============================================================================
// NEGATION / RELATIONAL PSEUDO-CLASSES
// ============================================================================

/// The `:not(selector)` pseudo-class represents elements that do not match
/// the argument selector.
///
/// Specificity: the maximum specificity among its arguments.
class NotPseudoClass extends PseudoClassSelector {
  final Sel argument;

  NotPseudoClass(this.argument);

  @override
  bool match(Node node) {
    return !argument.match(node);
  }

  @override
  Specificity get specificity => argument.specificity;

  @override
  String toString() => ':not($argument)';
}

/// The `:has(selector)` pseudo-class represents elements that have at least
/// one descendant matching the argument selector.
class HasPseudoClass extends PseudoClassSelector {
  final Sel argument;

  HasPseudoClass(this.argument);

  @override
  bool match(Node node) {
    return _hasDescendantMatch(node);
  }

  bool _hasDescendantMatch(Node node) {
    for (var child = node.firstChild;
        child != null;
        child = child.nextSibling) {
      if (argument.match(child) || _hasDescendantMatch(child)) return true;
    }
    return false;
  }

  @override
  Specificity get specificity => argument.specificity;

  @override
  String toString() => ':has($argument)';
}

/// The `:haschild(selector)` pseudo-class represents elements that have at
/// least one immediate child matching the argument selector.
class HasChildPseudoClass extends PseudoClassSelector {
  final Sel argument;

  HasChildPseudoClass(this.argument);

  @override
  bool match(Node node) {
    for (var child = node.firstChild;
        child != null;
        child = child.nextSibling) {
      if (argument.match(child)) return true;
    }
    return false;
  }

  @override
  Specificity get specificity => argument.specificity;

  @override
  String toString() => ':haschild($argument)';
}

/// The `:is(selector)` pseudo-class represents elements that match any of
/// the selectors in its argument list.
///
/// Specificity: maximum specificity among arguments.
class IsPseudoClass extends PseudoClassSelector {
  final Sel argument;

  IsPseudoClass(this.argument);

  @override
  bool match(Node node) {
    return argument.match(node);
  }

  @override
  Specificity get specificity => argument.specificity;

  @override
  String toString() => ':is($argument)';
}

/// The `:where(selector)` pseudo-class is equivalent to `:is()` but with
/// zero specificity.
class WherePseudoClass extends PseudoClassSelector {
  final Sel argument;

  WherePseudoClass(this.argument);

  @override
  bool match(Node node) {
    return argument.match(node);
  }

  @override
  Specificity get specificity => Specificity(0, 0, 0);

  @override
  String toString() => ':where($argument)';
}

// ============================================================================
// TEXT-CONTENT PSEUDO-CLASSES
// ============================================================================

/// The `:contains(text)` pseudo-class matches elements containing the given
/// text as a substring anywhere in their descendant text content.
///
/// Matching is case-insensitive.
class ContainsPseudoClass extends PseudoClassSelector {
  final String text;
  final bool ownOnly;

  ContainsPseudoClass(this.text, this.ownOnly);

  @override
  bool match(Node node) {
    final textContent = ownOnly ? _ownText(node) : _allText(node);
    return textContent.toLowerCase().contains(text.toLowerCase());
  }

  String _allText(Node node) {
    final buffer = StringBuffer();
    _collectText(node, buffer);
    return buffer.toString();
  }

  String _ownText(Node node) {
    final buffer = StringBuffer();
    for (var i = 0; i < node.nodes.length; i++) {
      final child = node.nodes[i];
      if (child is Text) buffer.write(child.text);
    }
    return buffer.toString();
  }

  void _collectText(Node node, StringBuffer buffer) {
    if (node is Text) {
      buffer.write(node.text);
    } else {
      for (var i = 0; i < node.nodes.length; i++) {
        _collectText(node.nodes[i], buffer);
      }
    }
  }

  @override
  String toString() {
    return ownOnly ? ':containsown("$text")' : ':contains("$text")';
  }
}

/// The `:matches(regex)` pseudo-class matches if the element's text content
/// matches the given regular expression.
class MatchesPseudoClass extends PseudoClassSelector {
  final RegExp pattern;
  final bool ownOnly;

  MatchesPseudoClass(this.pattern, this.ownOnly);

  @override
  bool match(Node node) {
    final text = ownOnly ? _ownText(node) : _allText(node);
    return pattern.hasMatch(text);
  }

  String _allText(Node node) {
    final buffer = StringBuffer();
    _collectText(node, buffer);
    return buffer.toString();
  }

  String _ownText(Node node) {
    final buffer = StringBuffer();
    for (var i = 0; i < node.nodes.length; i++) {
      final child = node.nodes[i];
      if (child is Text) buffer.write(child.text);
    }
    return buffer.toString();
  }

  void _collectText(Node node, StringBuffer buffer) {
    if (node is Text) {
      buffer.write(node.text);
    } else {
      for (var i = 0; i < node.nodes.length; i++) {
        _collectText(node.nodes[i], buffer);
      }
    }
  }

  @override
  String toString() {
    final patternStr = pattern.pattern;
    final flags = pattern.isCaseSensitive ? '' : 'i';
    return '${ownOnly ? ':matchesown' : ':matches'}($patternStr/$flags)';
  }
}

// ============================================================================
// NTH-LEVEL PSEUDO-CLASSES
// ============================================================================

/// Supports an+b formulas like `2n+1`, `-n+3`, `3`, `odd`, `even`.
/// Also supports `:first-child`, `:last-child`, `:first-of-type`, `:last-of-type`.
class NthPseudoClass extends PseudoClassSelector {
  final int a;
  final int b;
  final bool last;
  final bool ofType;

  const NthPseudoClass({
    required this.a,
    required this.b,
    this.last = false,
    this.ofType = false,
  });

  /// :first-child shortcut
  factory NthPseudoClass.first() {
    return NthPseudoClass(a: 0, b: 1, last: false, ofType: false);
  }

  /// :last-child shortcut
  factory NthPseudoClass.last() {
    return NthPseudoClass(a: 0, b: 1, last: true, ofType: false);
  }

  /// :first-of-type shortcut
  factory NthPseudoClass.firstOfType() {
    return NthPseudoClass(a: 0, b: 1, last: false, ofType: true);
  }

  /// :last-of-type shortcut
  factory NthPseudoClass.lastOfType() {
    return NthPseudoClass(a: 0, b: 1, last: true, ofType: true);
  }

  @override
  bool match(Node node) {
    if (node.parentNode == null) return false;

    // Compute position from start and total count in one pass
    int posFromStart = 0;
    int totalMatching = 0;
    Element? foundNode;
    final nodeTag = (node as Element).localName ?? '';
    final parent = node.parentNode!;

    for (var i = 0; i < parent.nodes.length; i++) {
      final sibling = parent.nodes[i];
      if (sibling is Element) {
        if (!ofType || (sibling.localName ?? '') == nodeTag) {
          totalMatching++;
          if (identical(sibling, node)) {
            foundNode = sibling;
            posFromStart = totalMatching; // Position from start when found
          }
        }
      }
    }

    if (foundNode == null) return false;

    // Position from end for :nth-last-* pseudo-classes
    int position = last ? (totalMatching - posFromStart + 1) : posFromStart;

    // Apply an+b formula: (position - b) mod a == 0 and quotient >= 0
    if (a == 0) {
      return position == b;
    } else {
      final diff = position - b;
      if (diff % a != 0) return false;
      final quotient = diff ~/ a;
      return quotient >= 0;
    }
  }

  @override
  Specificity get specificity => Specificity.classSelector;

  @override
  String toString() {
    if (ofType) {
      if (a == 0 && b == 1 && !last) return ':first-of-type';
      if (a == 0 && b == 1 && last) return ':last-of-type';
    } else {
      if (a == 0 && b == 1 && !last) return ':first-child';
      if (a == 0 && b == 1 && last) return ':last-child';
    }

    final which = ofType ? '-of-type' : '-child';
    final prefix = last ? ':nth-last' : ':nth';
    if (a == 1) {
      return '$prefix$which($b';
    } else if (a == -1) {
      return '$prefix$which(${-b}';
    } else if (a == 0) {
      return '$prefix$which($b)';
    } else {
      final sign = a > 0 ? '+' : '';
      return '$prefix$which($a$sign$b)';
    }
  }
}

/// :heading matches any heading element (h1–h6) and, with an an+b argument, selects headings based on their position among sibling heading elements.
class HeadingPseudoClass extends PseudoClassSelector {
  final int? a;
  final int? b;

  const HeadingPseudoClass({this.a, this.b});

  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final tag = (node.localName ?? '').toLowerCase();
    if (!{'h1', 'h2', 'h3', 'h4', 'h5', 'h6'}.contains(tag)) {
      return false;
    }

    if (a == null) return true;

    final parent = node.parentNode;
    if (parent == null) return false;

    // Single pass: count and find position without intermediate list
    int pos = 0;
    int count = 0;
    for (var i = 0; i < parent.nodes.length; i++) {
      final child = parent.nodes[i];
      if (child is Element) {
        final childTag = (child.localName ?? '').toLowerCase();
        if ({'h1', 'h2', 'h3', 'h4', 'h5', 'h6'}.contains(childTag)) {
          count++;
          if (identical(child, node)) {
            pos = count;
          }
        }
      }
    }
    if (pos == 0) return false;

    final aVal = a!;
    final bVal = b!;
    if (aVal == 0) {
      return pos == bVal;
    } else {
      final diff = pos - bVal;
      if (diff % aVal != 0) return false;
      final quotient = diff ~/ aVal;
      return quotient >= 0;
    }
  }

  @override
  Specificity get specificity => Specificity.classSelector;

  @override
  String toString() {
    if (a == null) {
      return ':heading';
    }
    final aVal = a!;
    final bVal = b!;
    if (aVal == 0) {
      return ':heading($bVal)';
    } else if (aVal == 1) {
      return ':heading($bVal';
    } else if (aVal == -1) {
      return ':heading(${-bVal}';
    } else {
      final sign = aVal > 0 ? '+' : '';
      return ':heading($aVal$sign$bVal)';
    }
  }
}

/// :only-child matches elements that are the only child of their parent.
class OnlyChildPseudoClass extends PseudoClassSelector {
  final bool ofType;

  OnlyChildPseudoClass({required this.ofType});

  @override
  bool match(Node node) {
    if (node.parentNode == null) return false;
    final nodeTag = (node as Element).localName ?? '';
    int count = 0;
    final parent = node.parentNode!;
    for (var i = 0; i < parent.nodes.length; i++) {
      final sibling = parent.nodes[i];
      if (sibling is! Element) continue;
      if (ofType && (sibling.localName ?? '') != nodeTag) continue;
      count++;
      if (count > 1) return false;
    }
    return count == 1;
  }

  @override
  Specificity get specificity => Specificity.classSelector;

  @override
  String toString() => ofType ? ':only-of-type' : ':only-child';
}

// ============================================================================
// STRUCTURAL / ROOT / EMPTY
// ============================================================================

/// :empty matches elements that have no children at all, or only
/// whitespace text nodes and comment nodes.
class EmptyPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    for (var i = 0; i < node.nodes.length; i++) {
      final child = node.nodes[i];
      if (child is Element) return false;
      if (child is Text && child.text.trim().isNotEmpty) return false;
    }
    return true;
  }

  @override
  String toString() => ':empty';
}

/// :root matches the root element of the document (html in HTML).
class RootPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    return node.parentNode?.nodeType == Node.DOCUMENT_NODE;
  }

  @override
  String toString() => ':root';
}

// ============================================================================
// LINK / LANGUAGE / INPUT
// ============================================================================

/// :link matches unvisited links (`a[href]`, `area[href]`, `link[href]`).
class LinkPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final tag = (node.localName ?? '').toLowerCase();
    final hasHref = node.attributes.containsKey('href') &&
        node.attributes['href']!.isNotEmpty;
    return (tag == 'a' || tag == 'area' || tag == 'link') && hasHref;
  }

  @override
  String toString() => ':link';
}

/// :visited matches visited links (`a[href]`, `area[href]`).
///
/// Due to privacy restrictions, the matched state is not exposed to scripts.
class VisitedPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Visited state is privacy-restricted and cannot be determined in static analysis.
    return false;
  }

  @override
  String toString() => ':visited';
}

/// :lang(language) matches elements with the given language or language prefix.
class LangPseudoClass extends PseudoClassSelector {
  final String language;

  LangPseudoClass(this.language);

  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final lang = node.attributes['lang'] ?? node.attributes['xml:lang'];
    if (lang != null && _langMatches(lang, language)) return true;
    var parent = node.parentNode;
    while (parent is Element) {
      final parentLang =
          parent.attributes['lang'] ?? parent.attributes['xml:lang'];
      if (parentLang != null && _langMatches(parentLang, language)) return true;
      parent = parent.parentNode;
    }
    return false;
  }

  bool _langMatches(String elementLang, String requiredLang) {
    final el = elementLang.toLowerCase();
    final req = requiredLang.toLowerCase();
    return el == req || el.startsWith('$req-');
  }

  @override
  String toString() => ':lang("$language")';
}

/// :input matches form control elements: input, select, textarea, button.
class InputPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final tag = (node.localName ?? '').toLowerCase();
    return tag == 'input' ||
        tag == 'select' ||
        tag == 'textarea' ||
        tag == 'button';
  }

  @override
  String toString() => ':input';
}

/// :enabled matches form elements that are enabled.
class EnabledPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final tag = (node.localName ?? '').toLowerCase();
    final disabled = node.attributes['disabled'];
    if (disabled != null) return false;
    if (tag == 'input' ||
        tag == 'select' ||
        tag == 'textarea' ||
        tag == 'button' ||
        tag == 'fieldset' ||
        tag == 'legend') {
      return !_isInDisabledFieldset(node);
    }
    return true;
  }

  bool _isInDisabledFieldset(Node node) {
    var parent = node.parentNode;
    while (parent != null) {
      if (parent is Element &&
          (parent.localName ?? '').toLowerCase() == 'fieldset') {
        final disabled = parent.attributes['disabled'];
        if (disabled != null) {
          // Legend without preceding sibling legend is exempt
          if (node is Element &&
              (node.localName ?? '').toLowerCase() == 'legend') {
            var prev = node.previousElementSibling;
            while (prev != null) {
              if ((prev.localName ?? '').toLowerCase() == 'legend') {
                return false;
              }
              prev = prev.previousElementSibling;
            }
          }
          return true;
        }
      }
      parent = parent.parentNode;
    }
    return false;
  }

  @override
  String toString() => ':enabled';
}

/// :disabled matches form elements that are disabled.
class DisabledPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    if (node.attributes.containsKey('disabled')) return true;
    return _isInDisabledFieldset(node);
  }

  bool _isInDisabledFieldset(Node node) {
    var parent = node.parentNode;
    while (parent != null) {
      if (parent is Element &&
          (parent.localName ?? '').toLowerCase() == 'fieldset') {
        if (parent.attributes.containsKey('disabled')) return true;
      }
      parent = parent.parentNode;
    }
    return false;
  }

  @override
  String toString() => ':disabled';
}

/// :checked matches checked radio/checkbox inputs and selected options.
class CheckedPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final tag = (node.localName ?? '').toLowerCase();
    if (tag == 'input') {
      final type = (node.attributes['type'] ?? '').toLowerCase();
      if (type == 'checkbox' || type == 'radio') {
        return node.attributes.containsKey('checked');
      }
    } else if (tag == 'option') {
      return node.attributes.containsKey('selected');
    }
    return false;
  }

  @override
  String toString() => ':checked';
}

// ============================================================================
// MODERN UI PSEUDO-CLASSES (LEVEL 4 +)
// ============================================================================

/// :focus-visible matches elements that receive focus with a visible indicator.
class FocusVisiblePseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Requires runtime focus state; cannot determine from static DOM.
    return false;
  }

  @override
  String toString() => ':focus-visible';
}

/// :focus-within matches elements that contain a focused descendant.
class FocusWithinPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Requires runtime focus state.
    return false;
  }

  @override
  String toString() => ':focus-within';
}

/// :target matches the element that is the current URL fragment target.
class TargetPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Requires document.location.hash; not decidable statically.
    return false;
  }

  @override
  String toString() => ':target';
}

/// :target-within matches elements that contain the URL fragment target.
class TargetWithinPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Requires runtime state.
    return false;
  }

  @override
  String toString() => ':target-within';
}

/// :any-link matches both visited and unvisited links.
class AnyLinkPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final tag = (node.localName ?? '').toLowerCase();
    return (tag == 'a' || tag == 'area' || tag == 'link') &&
        node.attributes.containsKey('href');
  }

  @override
  String toString() => ':any-link';
}

/// :local-link matches links that point to the current origin.
class LocalLinkPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Requires origin comparison; not available in static analysis.
    return false;
  }

  @override
  String toString() => ':local-link';
}

/// :scope matches the scoping element when used in a context like querySelector.
class ScopePseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // :scope depends on the context of the query; cannot be determined statically.
    return false;
  }

  @override
  String toString() => ':scope';
}

/// :dir(ltr|rtl) matches elements based on directionality.
class DirPseudoClass extends PseudoClassSelector {
  final String direction;

  DirPseudoClass(this.direction);

  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final dir = node.attributes['dir'];
    return dir != null && dir.toLowerCase() == direction.toLowerCase();
  }

  @override
  String toString() => ':dir($direction)';
}

// ============================================================================
// FORM VALIDATION PSEUDO-CLASSES
// ============================================================================

/// Validation state for form validity pseudo-classes.
enum ValidityState {
  /// Element is valid.
  valid,

  /// Element is invalid.
  invalid,
}

/// Requiredness state for form pseudo-classes.
enum RequiredState {
  /// Element is required.
  required,

  /// Element is optional.
  optional,
}

/// Editability state for read-only/read-write pseudo-classes.
enum ReadOnlyState {
  /// Element is read-only.
  readOnly,

  /// Element is read-write (editable).
  readWrite,
}

/// Range state for in-range/out-of-range pseudo-classes.
enum RangeState {
  /// Value is within the specified range.
  inRange,

  /// Value is outside the specified range.
  outOfRange,
}

/// :valid / :invalid - matches based on form validation status.
class ValidityPseudoClass extends PseudoClassSelector {
  final ValidityState state;

  ValidityPseudoClass(this.state);

  @override
  bool match(Node node) {
    // Validation requires runtime constraint checking.
    return false;
  }

  @override
  String toString() => state == ValidityState.valid ? ':valid' : ':invalid';
}

/// :required / :optional - matches elements that are required/optional.
class RequiredPseudoClass extends PseudoClassSelector {
  final RequiredState state;

  RequiredPseudoClass(this.state);

  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final isRequired = node.attributes.containsKey('required');
    return state == RequiredState.required ? isRequired : !isRequired;
  }

  @override
  String toString() =>
      state == RequiredState.required ? ':required' : ':optional';
}

/// :read-only / :read-write - matches elements based on editability.
class ReadOnlyPseudoClass extends PseudoClassSelector {
  final ReadOnlyState state;

  ReadOnlyPseudoClass(this.state);

  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final tag = (node.localName ?? '').toLowerCase();
    final readonly = node.attributes.containsKey('readonly');
    final disabled = node.attributes.containsKey('disabled');
    final isEditable =
        (tag == 'input' && node.attributes['type'] != 'hidden' && !disabled) ||
            (tag == 'textarea' && !disabled);
    return state == ReadOnlyState.readWrite
        ? (isEditable && !readonly)
        : (!isEditable || readonly);
  }

  @override
  String toString() =>
      state == ReadOnlyState.readWrite ? ':read-write' : ':read-only';
}

/// :in-range / :out-of-range - matches based on numeric value vs min/max.
class RangePseudoClass extends PseudoClassSelector {
  final RangeState state;

  RangePseudoClass(this.state);

  @override
  bool match(Node node) {
    // Requires numeric value comparison; static analysis insufficient.
    return false;
  }

  @override
  String toString() =>
      state == RangeState.inRange ? ':in-range' : ':out-of-range';
}

// ============================================================================
// MISCELLANEOUS PSEUDO-CLASSES
// ============================================================================

/// :default matches the default option/button in a set.
class DefaultPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final tag = (node.localName ?? '').toLowerCase();
    if (tag == 'option' || tag == 'button') {
      return node.attributes.containsKey('default') ||
          node.attributes.containsKey('checked');
    }
    if (tag == 'input' && node.attributes['type'] == 'radio') {
      return node.attributes.containsKey('checked');
    }
    return false;
  }

  @override
  String toString() => ':default';
}

/// :placeholder-shown matches inputs showing placeholder text.
class PlaceholderShownPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final tag = (node.localName ?? '').toLowerCase();
    return (tag == 'input' || tag == 'textarea') &&
        node.attributes.containsKey('placeholder');
  }

  @override
  String toString() => ':placeholder-shown';
}

/// :autofill matches form controls that the browser has auto-filled.
class AutofillPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Browser auto-fill state is runtime-only.
    return false;
  }

  @override
  String toString() => ':autofill';
}

/// :indeterminate matches checkboxes/radio buttons in indeterminate state.
class IndeterminatePseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Indeterminate is a DOM property, not an attribute.
    return false;
  }

  @override
  String toString() => ':indeterminate';
}

/// :blank matches elements that are "blank" (e.g., input with no user input).
class BlankPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Requires runtime user input state.
    return false;
  }

  @override
  String toString() => ':blank';
}

/// :user-invalid matches form elements invalid after user interaction.
class UserInvalidPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Tracks user interaction; runtime-only.
    return false;
  }

  @override
  String toString() => ':user-invalid';
}

/// :modal matches elements that are currently in a modal state.
class ModalPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    if ((node.localName ?? '').toLowerCase() == 'dialog') {
      return node.attributes.containsKey('open');
    }
    return false;
  }

  @override
  String toString() => ':modal';
}

/// :fullscreen matches elements that are currently in fullscreen mode.
class FullscreenPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Fullscreen state is runtime-only; static analysis cannot determine.
    return false;
  }

  @override
  String toString() => ':fullscreen';
}

/// :open matches elements that are "open" (`details[open]`, `select[open]`, `dialog[open]`).
class OpenPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final tag = (node.localName ?? '').toLowerCase();
    return tag == 'details' || tag == 'select' || tag == 'dialog';
  }

  @override
  String toString() => ':open';
}

// ============================================================================
// ANCHOR POSITIONING PSEUDO-CLASSES (CSS Anchor Positioning)
// ============================================================================

/// :anchor() pseudo-class matches the anchor element(s) that a positioned element
/// is anchored to. (CSS Anchor Positioning Module Level 1)
class AnchorPseudoClass extends PseudoClassSelector {
  final String? name;

  AnchorPseudoClass([this.name]);

  @override
  bool match(Node node) {
    // Anchor matching requires runtime anchor resolution.
    // Stub: always false in static analysis.
    return false;
  }

  @override
  String toString() => name == null ? ':anchor' : ':anchor($name)';
}

/// :has-anchor pseudo-class matches elements that have at least one anchor.
///
/// This is part of the CSS Anchor Positioning Module Level 1.
class HasAnchorPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Requires runtime anchor tracking.
    return false;
  }

  @override
  String toString() => ':has-anchor';
}

// ============================================================================
// CONTAINER QUERIES / SCOPING (CSS Container Queries & Scoping)
// ============================================================================

/// :in-container matches elements that are currently contained by a container element.
class InContainerPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Requires container query context.
    return false;
  }

  @override
  String toString() => ':in-container';
}

/// :ancestor matches an ancestor element in a relative selector chain.
class AncestorPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Used in relative selectors within :has() etc.
    return false;
  }

  @override
  String toString() => ':ancestor';
}

/// :parent matches the parent element in a relative selector chain.
class ParentPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Used in relative selectors.
    return false;
  }

  @override
  String toString() => ':parent';
}

/// :prev-sibling and :next-sibling (relative siblings)
class PrevSiblingPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Relative selector for preceding sibling
    return false;
  }

  @override
  String toString() => ':prev-sibling';
}

/// :next-sibling matches the immediately following sibling element in a relative selector chain.
class NextSiblingPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Relative selector for following sibling
    return false;
  }

  @override
  String toString() => ':next-sibling';
}

// ============================================================================
// PLAYBACK / MEDIA STATE PSEUDO-CLASSES
// ============================================================================

/// :buffering matches media elements that are currently buffering.
class BufferingPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final tag = (node.localName ?? '').toLowerCase();
    if (tag == 'audio' || tag == 'video') {
      // Buffering is a runtime state; cannot determine from static DOM.
      return false;
    }
    return false;
  }

  @override
  String toString() => ':buffering';
}

/// :seeking matches media elements in a seeking state.
class SeekingPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Requires runtime seeking flag.
    return false;
  }

  @override
  String toString() => ':seeking';
}

/// :stalled matches media elements that have stalled network activity.
class StalledPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Requires runtime network state.
    return false;
  }

  @override
  String toString() => ':stalled';
}

/// :paused matches paused media or animation elements.
class PausedPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final tag = (node.localName ?? '').toLowerCase();
    if (tag == 'audio' ||
        tag == 'video' ||
        tag == 'animation' ||
        tag == 'transition') {
      return node.attributes.containsKey('paused');
    }
    return false;
  }

  @override
  String toString() => ':paused';
}

/// :playing matches media or animation elements that are playing.
class PlayingPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final tag = (node.localName ?? '').toLowerCase();
    if (tag == 'audio' ||
        tag == 'video' ||
        tag == 'animation' ||
        tag == 'transition') {
      final paused = node.attributes.containsKey('paused');
      final ended = node.attributes.containsKey('ended');
      return !paused && !ended;
    }
    return false;
  }

  @override
  String toString() => ':playing';
}

/// :muted matches media elements whose audio is muted.
class MutedPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final tag = (node.localName ?? '').toLowerCase();
    if (tag == 'audio' || tag == 'video') {
      final muted = node.attributes['muted'];
      return muted != null;
    }
    return false;
  }

  @override
  String toString() => ':muted';
}

/// :volume-locked matches media elements with locked volume.
class VolumeLockedPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Volume lock state not generally exposed statically.
    return false;
  }

  @override
  String toString() => ':volume-locked';
}

// ============================================================================
// TEMPORAL / VIEW-TRANSITION PSEUDO-CLASSES
// ============================================================================

/// :future matches elements that will appear in a future view (e.g., scroll-driven).
class FuturePseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Used in scroll-driven animation timelines; requires runtime context.
    return false;
  }

  @override
  String toString() => ':future';
}

/// :past matches elements that have already passed in a view timeline.
class PastPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Used in view-timeline/scroll-driven animations.
    return false;
  }

  @override
  String toString() => ':past';
}

/// :current matches the currently-viewed element in a scroll container.
class CurrentPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Used with view-timeline; requires runtime.
    return false;
  }

  @override
  String toString() => ':current';
}

/// :target-current matches the current target in view transitions.
class TargetCurrentPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // View transition state.
    return false;
  }

  @override
  String toString() => ':target-current';
}

/// :target-before matches elements before the target in view transitions.
class TargetBeforePseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    return false;
  }

  @override
  String toString() => ':target-before';
}

/// :target-after matches elements after the target in view transitions.
class TargetAfterPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    return false;
  }

  @override
  String toString() => ':target-after';
}

/// :active-view-transition matches the root element during an active view transition.
class ActiveViewTransitionPseudoClass extends PseudoClassSelector {
  /// Creates an [ActiveViewTransitionPseudoClass] instance.
  const ActiveViewTransitionPseudoClass();

  @override
  bool match(Node node) => false;

  @override
  String toString() => ':active-view-transition';
}

/// :active-view-transition-type() matches the root element when a view transition of the specified type is active.
class ActiveViewTransitionTypePseudoClass extends PseudoClassSelector {
  /// The view transition type name.
  final String type;

  /// Creates an [ActiveViewTransitionTypePseudoClass] with the given [type].
  ActiveViewTransitionTypePseudoClass(this.type);

  @override
  bool match(Node node) => false;

  @override
  String toString() => ':active-view-transition-type($type)';
}

// ============================================================================
// PAGED MEDIA PSEUDO-CLASSES (CSS Paged Media)
// ============================================================================

/// :left matches elements on left-hand pages in paged media.
class LeftPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Requires knowledge of page side; runtime-only.
    return false;
  }

  @override
  String toString() => ':left';
}

/// :right matches elements on right-hand pages in paged media.
class RightPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    return false;
  }

  @override
  String toString() => ':right';
}

/// :first matches elements on the first page in paged media.
class FirstPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    return false;
  }

  @override
  String toString() => ':first';
}

// ============================================================================
// POPOVER / DIALOG PSEUDO-CLASSES
// ============================================================================

/// :popover-open matches popover elements that are currently open.
class PopoverOpenPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final popover = node.attributes['popover'];
    return popover != null && popover.isNotEmpty;
  }

  @override
  String toString() => ':popover-open';
}

// ============================================================================
// INTEREST / TARGETING PSEUDO-CLASSES (CSS Interest API - experimental)
// ============================================================================

/// :interest-source matches elements that are sources of user interest.
class InterestSourcePseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Requires Interest API runtime tracking.
    return false;
  }

  @override
  String toString() => ':interest-source';
}

/// :interest-target matches elements that are targets of user interest.
class InterestTargetPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Requires runtime target tracking.
    return false;
  }

  @override
  String toString() => ':interest-target';
}

// ============================================================================
// INTERACTION STATE PSEUDO-CLASSES (User input states)
// ============================================================================

/// :active matches the element that is currently being activated by the user.
class ActivePseudoClass extends PseudoClassSelector {
  /// Creates an [ActivePseudoClass] instance.
  const ActivePseudoClass();

  @override
  bool match(Node node) {
    // Activation state is runtime-only.
    return false;
  }

  @override
  String toString() => ':active';
}

/// :hover matches elements that are being hovered by a pointer.
class HoverPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Hover state is runtime pointer state.
    return false;
  }

  @override
  String toString() => ':hover';
}

/// :focus matches the element that currently has keyboard focus.
class FocusPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Focus is a runtime-determined property.
    return false;
  }

  @override
  String toString() => ':focus';
}

/// :defined matches custom elements that have been defined (custom element
/// lifecycle state).
class DefinedPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final tag = (node.localName ?? '').toLowerCase();
    // Custom elements contain a hyphen
    if (!tag.contains('-')) return false;
    // Defining custom elements requires JavaScript registry check; stub.
    return false;
  }

  @override
  String toString() => ':defined';
}

/// :user-valid matches form elements that are valid after user interaction.
class UserValidPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Validity tracking post-interaction is runtime-only.
    return false;
  }

  @override
  String toString() => ':user-valid';
}

/// :picture-in-picture matches media elements in Picture-in-Picture mode.
class PictureInPicturePseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    if (node is! Element) return false;
    final tag = (node.localName ?? '').toLowerCase();
    return tag == 'video' || tag == 'iframe';
  }

  @override
  String toString() => ':picture-in-picture';
}

/// The :state( state-name ) pseudo-class is a CSS device-state indicator.
class StatePseudoClass extends PseudoClassSelector {
  final String stateName;

  StatePseudoClass(this.stateName);

  @override
  bool match(Node node) {
    // Device state is platform/runtime-dependent.
    return false;
  }

  @override
  String toString() => ':state($stateName)';
}

/// The :xr-overlay pseudo-class matches XR overlay elements.
class XROverlayPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // XR/AR/VR context required.
    return false;
  }

  @override
  String toString() => ':xr-overlay';
}

// ============================================================================
// PSEUDO-ELEMENTS
// ============================================================================

/// Classic pseudo-elements

/// ::before pseudo-element matches generated content before an element.
class BeforePseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) => false;

  @override
  String get pseudoElement => 'before';

  @override
  String toString() => '::before';
}

/// ::after pseudo-element matches generated content after an element.
class AfterPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) => false;

  @override
  String get pseudoElement => 'after';

  @override
  String toString() => '::after';
}

/// ::first-letter pseudo-element matches the first letter of a block-level element.
class FirstLetterPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) => false;

  @override
  String get pseudoElement => 'first-letter';

  @override
  String toString() => '::first-letter';
}

/// ::first-line pseudo-element matches the first line of a block-level element.
class FirstLinePseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) => false;

  @override
  String get pseudoElement => 'first-line';

  @override
  String toString() => '::first-line';
}

/// ::target-text pseudo-element matches the text that is targeted by a fragment.
class TargetTextPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) => false;

  @override
  String get pseudoElement => 'target-text';

  @override
  String toString() => '::target-text';
}

/// ::file-selector-button matches the button of a file input element.
class FileSelectorButtonPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Pseudo-elements are matched via rendering context; return false for nodes.
    return false;
  }

  @override
  String get pseudoElement => 'file-selector-button';

  @override
  String toString() => '::file-selector-button';
}

/// ::highlight matches a named highlight overlay.
class HighlightPseudoElement extends PseudoClassSelector {
  final String name;

  HighlightPseudoElement(this.name);

  @override
  bool match(Node node) {
    // Highlight pseudo-element applies via rendering; return false.
    return false;
  }

  @override
  String get pseudoElement => 'highlight';

  @override
  String toString() => '::highlight($name)';
}

/// ::part matches elements with a matching part attribute (Shadow DOM parts).
class PartPseudoElement extends PseudoClassSelector {
  final String partName;

  PartPseudoElement(this.partName);

  @override
  bool match(Node node) {
    // Shadow DOM part styling; return false for node matching.
    return false;
  }

  @override
  String get pseudoElement => 'part';

  @override
  String toString() => '::part($partName)';
}

/// ::slotted matches elements distributed into a shadow tree slot.
class SlottedPseudoElement extends PseudoClassSelector {
  final String? selector;

  SlottedPseudoElement([this.selector]);

  @override
  bool match(Node node) {
    // Slotted content matching requires shadow DOM traversal.
    return false;
  }

  @override
  String get pseudoElement => 'slotted';

  @override
  String toString() => selector == null ? '::slotted' : '::slotted($selector)';
}

/// ::scroll-button pseudo-element for scroll buttons.
class ScrollButtonPseudoElement extends PseudoClassSelector {
  final String? axis;

  ScrollButtonPseudoElement([this.axis]);

  @override
  bool match(Node node) {
    return false;
  }

  @override
  String get pseudoElement => 'scroll-button';

  @override
  String toString() =>
      axis == null ? '::scroll-button' : '::scroll-button($axis)';
}

/// ::scroll-marker matches scroll marker elements.
class ScrollMarkerPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) {
    return false;
  }

  @override
  String get pseudoElement => 'scroll-marker';

  @override
  String toString() => '::scroll-marker';
}

/// ::scroll-marker-group matches scroll marker groups.
class ScrollMarkerGroupPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) {
    return false;
  }

  @override
  String get pseudoElement => 'scroll-marker-group';

  @override
  String toString() => '::scroll-marker-group';
}

/// ::grammar-error marks grammar error locations.
class GrammarErrorPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Grammar errors require document grammar analysis; stub.
    return false;
  }

  @override
  String get pseudoElement => 'grammar-error';

  @override
  String toString() => '::grammar-error';
}

/// ::spelling-error marks spelling error locations.
class SpellingErrorPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Spelling errors require spellcheck runtime.
    return false;
  }

  @override
  String get pseudoElement => 'spelling-error';

  @override
  String toString() => '::spelling-error';
}

/// ::selection matches highlighted/selected text.
class SelectionPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Selection state depends on user selection; static matching returns false.
    return false;
  }

  @override
  String get pseudoElement => 'selection';

  @override
  String toString() => '::selection';
}

/// ::placeholder matches placeholder text in form controls.
class PlaceholderPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Pseudo-element for styling placeholder; node matching returns false.
    return false;
  }

  @override
  String get pseudoElement => 'placeholder';

  @override
  String toString() => '::placeholder';
}

/// ::marker matches list item markers (bullets/numbers).
class MarkerPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Marker pseudo-element applies to list item marker box.
    return false;
  }

  @override
  String get pseudoElement => 'marker';

  @override
  String toString() => '::marker';
}

/// ::backdrop matches backdrop of fullscreen/dialog elements.
class BackdropPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Backdrop rendered by UA; node matching false.
    return false;
  }

  @override
  String get pseudoElement => 'backdrop';

  @override
  String toString() => '::backdrop';
}

/// ::cue matches captions/cues in media elements.
class CuePseudoElement extends PseudoClassSelector {
  /// The optional cue name for selecting specific cues by name.
  final String? name;

  CuePseudoElement([this.name]);

  @override
  bool match(Node node) {
    return false;
  }

  @override
  String get pseudoElement => 'cue';

  @override
  String toString() => name == null ? '::cue' : '::cue($name)';
}

/// ::column pseudo-element for multi-column selectors.
class ColumnPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) {
    return false;
  }

  @override
  String get pseudoElement => 'column';

  @override
  String toString() => '::column';
}

/// View transition pseudo-elements (CSS View Transitions Module).
abstract class ViewTransitionPseudoElement extends PseudoClassSelector {
  final String name;

  ViewTransitionPseudoElement(this.name);

  @override
  bool match(Node node) {
    // View transition pseudo-elements exist in UA layer.
    return false;
  }

  @override
  String get pseudoElement => name;

  @override
  String toString() => '::$name';
}

/// ::view-transition pseudo-element represents the root view transition element.
class ViewTransitionRootPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) {
    return false;
  }

  @override
  String get pseudoElement => 'view-transition';

  @override
  String toString() => '::view-transition';
}

/// ::view-transition-group pseudo-element groups the old and new views during transition.
class ViewTransitionGroupPseudoElement extends PseudoClassSelector {
  final String name;

  ViewTransitionGroupPseudoElement(this.name);

  @override
  bool match(Node node) {
    return false;
  }

  @override
  String get pseudoElement => 'view-transition-group';

  @override
  String toString() => '::view-transition-group($name)';
}

/// ::view-transition-image-pair pseudo-element pairs old and new images during transition.
class ViewTransitionImagePairPseudoElement extends PseudoClassSelector {
  final String name;

  ViewTransitionImagePairPseudoElement(this.name);

  @override
  bool match(Node node) {
    return false;
  }

  @override
  String get pseudoElement => 'view-transition-image-pair';

  @override
  String toString() => '::view-transition-image-pair($name)';
}

/// ::view-transition-old pseudo-element represents the old snapshot during transition.
class ViewTransitionOldPseudoElement extends PseudoClassSelector {
  final String name;

  ViewTransitionOldPseudoElement(this.name);

  @override
  bool match(Node node) {
    return false;
  }

  @override
  String get pseudoElement => 'view-transition-old';

  @override
  String toString() => '::view-transition-old($name)';
}

/// ::view-transition-new pseudo-element represents the new snapshot during transition.
class ViewTransitionNewPseudoElement extends PseudoClassSelector {
  final String name;

  ViewTransitionNewPseudoElement(this.name);

  @override
  bool match(Node node) {
    return false;
  }

  @override
  String get pseudoElement => 'view-transition-new';

  @override
  String toString() => '::view-transition-new($name)';
}

/// ::search-text matches search result highlighting (CSS Search API).
class SearchTextPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) {
    return false;
  }

  @override
  String get pseudoElement => 'search-text';

  @override
  String toString() => '::search-text';
}

/// ::details-content matches content inside `<details>` element.
class DetailsContentPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) {
    return false;
  }

  @override
  String get pseudoElement => 'details-content';

  @override
  String toString() => '::details-content';
}

/// ::picker-icon matches native picker icons.
class PickerIconPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) {
    return false;
  }

  @override
  String get pseudoElement => 'picker-icon';

  @override
  String toString() => '::picker-icon';
}

/// ::picker matches the picker popup itself.
class PickerPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) {
    return false;
  }

  @override
  String get pseudoElement => 'picker';

  @override
  String toString() => '::picker';
}

/// ::checkmark matches checkmark icons in checkboxes/radios.
class CheckmarkPseudoElement extends PseudoClassSelector {
  @override
  bool match(Node node) {
    return false;
  }

  @override
  String get pseudoElement => 'checkmark';

  @override
  String toString() => '::checkmark';
}

/// The nesting selector & matches the parent selector.
///
/// This is a special selector used in nested CSS rules to reference
/// the parent selector(s).
///
/// See: CSS Nesting Module Level 3
class NestingSelectorPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // The & is used in parsing to construct compound selectors;
    // it never directly matches nodes in isolation.
    return false;
  }

  @override
  String toString() => '&';
}

/// Fallback for unknown pseudo-classes. Always returns false.
class UnknownPseudoClass extends PseudoClassSelector {
  final String name;

  UnknownPseudoClass(this.name);

  @override
  bool match(Node node) => false;

  @override
  String toString() => ':$name';
}

// ============================================================================
// SCOPING AND HOST PSEUDO-CLASSES (CSS Scoping Module)
// ============================================================================

/// :host matches the host element of a shadow tree or component.
class HostPseudoClass extends PseudoClassSelector {
  @override
  bool match(Node node) {
    // Shadow host detection requires shadow root context.
    return false;
  }

  @override
  String toString() => ':host';
}

/// :host(selector) matches the host if it matches the selector.
class HostFunctionPseudoClass extends PseudoClassSelector {
  final Sel selector;

  HostFunctionPseudoClass(this.selector);

  @override
  bool match(Node node) {
    // In shadow DOM, host is determined statically via parent, but match requires checking selector.
    return false;
  }

  @override
  Specificity get specificity => selector.specificity;

  @override
  String toString() => ':host($selector)';
}

/// :host-context(selector) matches the host if any ancestor matches the selector.
class HostContextPseudoClass extends PseudoClassSelector {
  final Sel selector;

  HostContextPseudoClass(this.selector);

  @override
  bool match(Node node) {
    // Requires ancestor matching on host ancestors.
    return false;
  }

  @override
  Specificity get specificity => selector.specificity;

  @override
  String toString() => ':host-context($selector)';
}

/// :has-slotted matches elements that have slotted content.
class HasSlottedPseudoClass extends PseudoClassSelector {
  final Sel? selector;

  HasSlottedPseudoClass([this.selector]);

  @override
  bool match(Node node) {
    // Requires shadow DOM slot distribution analysis.
    return false;
  }

  @override
  Specificity get specificity => selector?.specificity ?? Specificity(0, 0, 0);

  @override
  String toString() =>
      selector == null ? ':has-slotted' : ':has-slotted($selector)';
}

// ============================================================================
// NESTING SELECTOR
// ============================================================================

/// The nesting selector & represents the current component's parent selector.
///
/// It is used inside nested rules to reference the selector(s) of the parent.
/// This is not a pseudo-class but a special selector token handled at parse time.
///
/// See: CSS Nesting Module Level 3
