import 'combined_selector.dart';
import 'matcher.dart';
import 'parser.dart';
import 'selectors.dart';

/// Attribute-selector and `an+b` parsing.
extension AttributeParsing on Parser {
  /// Parses `[attr]`, `[attr=value]`, `[attr^=value i]` and friends.
  Sel parseAttributeSelector() {
    expect('[');
    skipWhitespace();

    String? nsPrefix;
    if (peek() == '|') {
      consume();
      nsPrefix = '';
    } else if (peek() == '*' && peekAt(1) == '|') {
      consume();
      consume();
      nsPrefix = '*';
    }

    var name = parseIdentifier();
    if (nsPrefix == null && peek() == '|' && peekAt(1) != '=') {
      consume();
      name = parseIdentifier();
    }
    skipWhitespace();

    if (peek() == ']') {
      consume();
      return AttributeSelector(attributeName: name, operation: AttrOp.present);
    }

    final operation = _parseAttrOperator();
    skipWhitespace();

    String? value;
    RegExp? regexp;
    if (operation == AttrOp.regexMatch) {
      regexp = parseRegex();
    } else {
      value = _parseAttributeValue();
    }

    skipWhitespace();
    var caseInsensitive = false;
    // The flag must be a standalone `i`/`s` immediately before `]`.
    final flag = peek().toLowerCase();
    if ((flag == 'i' || flag == 's') && !isNameChar(peekAt(1))) {
      consume();
      caseInsensitive = flag == 'i';
      skipWhitespace();
    }

    if (peek() != ']') {
      throw FormatException(
          'Expected "]" to close attribute selector', source, position);
    }
    consume();

    return AttributeSelector(
      attributeName: name,
      operation: operation,
      value: value,
      regexp: regexp,
      caseInsensitive: caseInsensitive,
    );
  }

  AttrOp _parseAttrOperator() {
    final ch = peek();
    switch (ch) {
      case '=':
        consume();
        return AttrOp.equal;
      case '~':
      case '|':
      case '^':
      case r'$':
      case '*':
      case '!':
      case '#':
        consume();
        if (peek() != '=') {
          throw FormatException(
              'Expected "$ch=" in attribute selector', source, position);
        }
        consume();
        return switch (ch) {
          '~' => AttrOp.includes,
          '|' => AttrOp.dashMatch,
          '^' => AttrOp.prefix,
          r'$' => AttrOp.suffix,
          '*' => AttrOp.substring,
          '!' => AttrOp.notEqual,
          _ => AttrOp.regexMatch,
        };
      default:
        throw FormatException(
            'Unknown attribute operator "$ch"', source, position);
    }
  }

  String _parseAttributeValue() {
    final ch = peek();
    if (ch == '"' || ch == "'") return parseString();
    if (ch == ']') {
      throw FormatException(
          'Expected a value in attribute selector', source, position);
    }
    return parseIdentifier();
  }

  /// Parses a `/pattern/flags` regular expression.
  RegExp parseRegex() {
    if (peek() != '/') {
      throw FormatException('Expected "/" to start a regex', source, position);
    }
    consume();
    final buffer = StringBuffer();
    while (!isAtEnd() && peek() != '/') {
      if (peek() == r'\') {
        consume();
        if (isAtEnd()) break;
        buffer.write(r'\');
      }
      buffer.write(consume());
    }
    if (isAtEnd()) {
      throw FormatException('Unterminated regex', source, position);
    }
    consume(); // closing '/'

    var caseSensitive = true;
    var multiLine = false;
    while (!isAtEnd()) {
      final flag = peek();
      if (flag == 'i') {
        caseSensitive = false;
        consume();
      } else if (flag == 'm') {
        multiLine = true;
        consume();
      } else if (flag == 's' || flag == 'g') {
        consume();
      } else {
        break;
      }
    }
    try {
      return RegExp(buffer.toString(),
          caseSensitive: caseSensitive, multiLine: multiLine);
    } on FormatException catch (e) {
      throw FormatException('Invalid regex: ${e.message}', source, position);
    }
  }

  /// Parses an `an+b` expression, including `odd` and `even`.
  (int, int) parseAnB() {
    skipWhitespace();
    final lower = source.substring(position).toLowerCase();
    if (lower.startsWith('odd') && !isNameChar(peekAt(3))) {
      position += 3;
      return (2, 1);
    }
    if (lower.startsWith('even') && !isNameChar(peekAt(4))) {
      position += 4;
      return (2, 0);
    }

    var aSign = 1;
    if (peek() == '+') {
      consume();
    } else if (peek() == '-') {
      consume();
      aSign = -1;
    }

    final digitsStart = position;
    while (!isAtEnd() && _isDigit(peek())) {
      consume();
    }
    final digits = source.substring(digitsStart, position);

    if (peek() == 'n' || peek() == 'N') {
      consume();
      final a = aSign * (digits.isEmpty ? 1 : int.parse(digits));
      skipWhitespace();
      var b = 0;
      if (peek() == '+' || peek() == '-') {
        final bSign = consume() == '+' ? 1 : -1;
        skipWhitespace();
        final bStart = position;
        while (!isAtEnd() && _isDigit(peek())) {
          consume();
        }
        if (position == bStart) {
          throw FormatException(
              'Expected a number in an+b expression', source, position);
        }
        b = bSign * int.parse(source.substring(bStart, position));
      }
      return (a, b);
    }

    if (digits.isEmpty) {
      throw FormatException(
          'Expected a number in an+b expression', source, position);
    }
    return (0, aSign * int.parse(digits));
  }

  bool _isDigit(String ch) {
    if (ch.isEmpty) return false;
    final c = ch.codeUnitAt(0);
    return c >= 0x30 && c <= 0x39;
  }

  /// Parses a relative selector list for `:has()`.
  ///
  /// Audit **P1-1**: supports the leading `>`, `+` and `~` combinators that
  /// were previously discarded.
  List<RelativeSelector> parseRelativeSelectorList() {
    final result = <RelativeSelector>[];
    while (true) {
      skipWhitespace();
      var combinator = ' ';
      final ch = peek();
      if (ch == '>' || ch == '+' || ch == '~') {
        consume();
        combinator = ch;
        skipWhitespace();
      }
      result.add(
          RelativeSelector(combinator: combinator, selector: parseSelector()));
      skipWhitespace();
      if (peek() != ',') break;
      consume();
    }
    return result;
  }
}
