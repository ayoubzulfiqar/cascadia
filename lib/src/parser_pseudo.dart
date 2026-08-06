import 'matcher.dart';
import 'parser.dart';
import 'pseudo_classes.dart';
import 'pseudo_registry.dart';

/// Pseudo-class and pseudo-element parsing.
extension PseudoParsing on Parser {
  /// Parses `:pseudo-class`, `:pseudo-class(arg)` or `::pseudo-element`.
  Sel parsePseudoSelector() {
    expect(':');
    final isElement = peek() == ':';
    if (isElement) consume();

    if (!atIdentifierStart()) {
      throw FormatException(
          'Expected a pseudo-class name after ":"', source, position);
    }
    final name = parseIdentifier().toLowerCase();

    String? argument;
    if (peek() == '(') {
      argument = _parseParenArgument();
    }

    // Legacy single-colon pseudo-elements from CSS2.
    const legacyElements = {'before', 'after', 'first-line', 'first-letter'};
    if (isElement || (legacyElements.contains(name) && acceptPseudoElements)) {
      return _buildPseudoElement(name, argument);
    }

    return buildPseudoClass(this, name, argument,
        allowUnknown: allowUnknownPseudoClasses);
  }

  String _parseParenArgument() {
    expect('(');
    final start = position;
    var depth = 1;
    while (!isAtEnd()) {
      final ch = source[position];
      if (ch == '"' || ch == "'") {
        parseString();
        continue;
      }
      if (ch == r'\') {
        position += 2;
        continue;
      }
      if (ch == '(') depth++;
      if (ch == ')') {
        depth--;
        if (depth == 0) break;
      }
      position++;
    }
    if (depth != 0) {
      throw FormatException('Unclosed "("', source, start - 1);
    }
    final raw = source.substring(start, position);
    consume(); // ')'
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw FormatException('Empty argument list', source, start);
    }
    return trimmed;
  }

  Sel _buildPseudoElement(String name, String? argument) {
    final arity = knownPseudoElements[name];
    if (arity == null) {
      if (allowUnknownPseudoClasses) {
        return PseudoElementSelector(name, argument);
      }
      throw FormatException(
          'Unknown pseudo-element "::$name"', source, position);
    }
    if (arity == 'required' && argument == null) {
      throw FormatException('::$name requires an argument', source, position);
    }
    if (arity == 'none' && argument != null) {
      throw FormatException(
          '::$name does not take an argument', source, position);
    }
    return PseudoElementSelector(name, argument);
  }
}
