import 'combined_selector.dart';
import 'matcher.dart';
import 'parser_attributes.dart';
import 'parser_pseudo.dart';
import 'pseudo_classes.dart';
import 'scanner.dart';
import 'selectors.dart';

/// Parses CSS selector text into [Sel] objects.
///
/// Covers Selectors Level 3 plus the widely-implemented Level 4 additions.
class Parser extends Scanner {
  /// Whether pseudo-elements are permitted in this parse.
  final bool acceptPseudoElements;

  /// Whether unrecognised pseudo-classes are tolerated instead of rejected.
  final bool allowUnknownPseudoClasses;

  /// Creates a parser over [source].
  Parser(
    super.source, {
    this.acceptPseudoElements = false,
    this.allowUnknownPseudoClasses = false,
  });

  /// Parses [source] as a selector list.
  static Sel parse(String source, {bool allowUnknownPseudoClasses = false}) =>
      Parser(source, allowUnknownPseudoClasses: allowUnknownPseudoClasses)
          .parseSelectorGroup();

  /// Parses [source] as a selector list. Same as [parse].
  static Sel parseGroup(String source) => Parser.parse(source);

  /// Parses [source], allowing pseudo-elements.
  static Sel parseWithPseudoElements(String source,
          {bool allowUnknownPseudoClasses = false}) =>
      Parser(source,
              acceptPseudoElements: true,
              allowUnknownPseudoClasses: allowUnknownPseudoClasses)
          .parseSelectorGroup();

  /// Parses a complete selector list and asserts all input was consumed.
  SelectorGroup parseSelectorGroup() {
    final selectors = <Sel>[parseSelector()];
    skipWhitespace();
    while (peek() == ',') {
      consume();
      skipWhitespace();
      if (isAtEnd()) {
        throw FormatException(
            'Trailing comma in selector list', source, position);
      }
      selectors.add(parseSelector());
      skipWhitespace();
    }
    if (!isAtEnd()) {
      throw FormatException(
          'Unexpected character "${peek()}"', source, position);
    }
    return SelectorGroup(selectors);
  }

  /// Parses one complex selector, including combinators.
  Sel parseSelector() {
    skipWhitespace();
    var left = parseSimpleSelectorSequence();
    if (left == null) {
      throw FormatException(
          isAtEnd()
              ? 'Expected a selector but found end of input'
              : 'Expected a selector but found "${peek()}"',
          source,
          position);
    }

    while (true) {
      // Audit P0-1: capture the offset each iteration. Previously an
      // unrecognised character fell through to an implicit descendant
      // combinator that consumed nothing, looping forever on inputs such as
      // `svg|rect` and `div %`.
      final loopStart = position;
      final hadWhitespace = _skipWhitespaceReporting();
      if (isAtEnd()) break;

      final ch = peek();
      if (ch == ',' || ch == ')') break;

      String combinator;
      if (ch == '>' || ch == '+' || ch == '~') {
        consume();
        combinator = ch;
        skipWhitespace();
      } else if (hadWhitespace) {
        combinator = ' ';
      } else {
        throw FormatException('Unexpected character "$ch"', source, position);
      }

      final right = parseSimpleSelectorSequence();
      if (right == null) {
        throw FormatException(
            combinator == ' '
                ? 'Expected a selector after whitespace'
                : 'Expected a selector after "$combinator"',
            source,
            position);
      }
      if (left!.pseudoElement.isNotEmpty) {
        throw FormatException(
            'A pseudo-element must be the last component of a selector',
            source,
            position);
      }
      left =
          CombinedSelector(first: left, combinator: combinator, second: right);

      if (position == loopStart) {
        // Defensive: no rule may complete an iteration without progress.
        throw StateError(
            'Parser made no progress at offset $position in "$source"');
      }
    }
    return left!;
  }

  bool _skipWhitespaceReporting() {
    final before = position;
    skipWhitespace();
    return position != before;
  }

  /// Parses a compound selector, or returns null if nothing matched here.
  ///
  /// Returning null rather than a phantom universal selector is what lets
  /// [parseSelector] reject malformed input instead of looping (audit P0-1)
  /// and is also what makes `div >`, `''` and `div,,` errors (audit P2-8).
  Sel? parseSimpleSelectorSequence() {
    final parts = <Sel>[];
    String? pseudoElement;
    var sawUniversal = false;
    String? namespacePrefix;

    // Leading namespace prefix, universal selector, or type selector.
    final nsPrefix = _tryParseNamespacePrefix();
    if (nsPrefix != null) namespacePrefix = nsPrefix;

    if (peek() == '*') {
      consume();
      sawUniversal = true;
      if (namespacePrefix != null) {
        parts.add(UniversalSelector(namespacePrefix: namespacePrefix));
      }
    } else if (atIdentifierStart()) {
      parts.add(
          TagSelector(parseIdentifier(), namespacePrefix: namespacePrefix));
    } else if (namespacePrefix != null) {
      throw FormatException('Expected a tag name or "*" after namespace prefix',
          source, position);
    }

    while (!isAtEnd()) {
      final ch = peek();
      if (ch == '.') {
        consume();
        parts.add(ClassSelector(parseIdentifier()));
      } else if (ch == '#') {
        consume();
        parts.add(IdSelector(parseIdentifier()));
      } else if (ch == '[') {
        parts.add(parseAttributeSelector());
      } else if (ch == '&') {
        consume();
        parts.add(const NestingSelector());
      } else if (ch == ':') {
        if (pseudoElement != null) {
          throw FormatException(
              'Nothing may follow a pseudo-element', source, position);
        }
        final parsed = parsePseudoSelector();
        if (parsed is PseudoElementSelector) {
          if (!acceptPseudoElements) {
            throw FormatException(
                'Pseudo-element "$parsed" is not allowed here; '
                'use parseWithPseudoElements()',
                source,
                position);
          }
          pseudoElement = parsed.pseudoElement;
        } else {
          parts.add(parsed);
        }
      } else {
        break;
      }
    }

    if (parts.isEmpty && pseudoElement == null) {
      return sawUniversal ? const UniversalSelector() : null;
    }
    if (parts.length == 1 && pseudoElement == null) return parts.first;
    if (parts.isEmpty && sawUniversal && pseudoElement != null) {
      return CompoundSelector(
          selectors: [const UniversalSelector()], pseudoElement: pseudoElement);
    }
    return CompoundSelector(
        selectors: parts, pseudoElement: pseudoElement ?? '');
  }

  /// Parses a namespace prefix if one is present at the current position.
  ///
  /// Audit **P0-1/P1-10**: `|` was never consumed, which is why the
  /// documented `svg|rect` hung the parser.
  String? _tryParseNamespacePrefix() {
    final start = position;
    if (peek() == '|') {
      // `|tag` — explicitly no namespace.
      if (peekAt(1) == '=') return null; // not ours; attribute operator
      consume();
      return '';
    }
    if (peek() == '*' && peekAt(1) == '|') {
      consume();
      consume();
      return '*';
    }
    if (!atIdentifierStart()) return null;
    // Look ahead for `ident|` that is not `ident|=`.
    final save = position;
    try {
      final ident = parseIdentifier();
      if (peek() == '|' && peekAt(1) != '=') {
        consume();
        return ident;
      }
    } on FormatException {
      // fall through and rewind
    }
    position = save == start ? start : save;
    return null;
  }
}
