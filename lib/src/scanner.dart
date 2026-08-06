import 'escape.dart';

/// Character-level scanning shared by the selector parser.
///
/// Split out of the parser so the position-advancing primitives can be
/// reasoned about in isolation — audit **P0-1** was caused by a parse path
/// that consumed no characters and silently looped forever.
abstract class Scanner {
  /// The selector text being parsed.
  final String source;

  /// The current offset into [source].
  int position = 0;

  /// Creates a scanner over [source].
  Scanner(this.source);

  /// Whether all input has been consumed.
  bool isAtEnd() => position >= source.length;

  /// The current character, or `''` at end of input.
  String peek() => isAtEnd() ? '' : source[position];

  /// The character [offset] positions ahead, or `''` if out of range.
  String peekAt(int offset) {
    final i = position + offset;
    return i >= 0 && i < source.length ? source[i] : '';
  }

  /// Consumes and returns the current character.
  String consume() {
    if (isAtEnd()) {
      throw FormatException('Unexpected end of input', source, position);
    }
    return source[position++];
  }

  /// Consumes [expected], or throws if it is not next.
  void expect(String expected) {
    if (peek() != expected) {
      throw FormatException(
          'Expected "$expected" but found '
          '${isAtEnd() ? 'end of input' : '"${peek()}"'}',
          source,
          position);
    }
    position++;
  }

  /// Skips whitespace and CSS comments.
  void skipWhitespace() {
    while (!isAtEnd()) {
      final ch = source[position];
      if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' || ch == '\f') {
        position++;
      } else if (ch == '/' && peekAt(1) == '*') {
        final end = source.indexOf('*/', position + 2);
        if (end < 0) {
          throw FormatException('Unclosed comment', source, position);
        }
        position = end + 2;
      } else {
        break;
      }
    }
  }

  /// Whether [ch] can start a CSS identifier.
  bool isNameStart(String ch) {
    if (ch.isEmpty) return false;
    final code = ch.codeUnitAt(0);
    return (code >= 0x61 && code <= 0x7A) ||
        (code >= 0x41 && code <= 0x5A) ||
        code == 0x5F ||
        code >= 0x80 ||
        ch == r'\';
  }

  /// Whether [ch] can appear inside a CSS identifier.
  bool isNameChar(String ch) {
    if (ch.isEmpty) return false;
    final code = ch.codeUnitAt(0);
    return (code >= 0x61 && code <= 0x7A) ||
        (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x30 && code <= 0x39) ||
        code == 0x2D ||
        code == 0x5F ||
        code >= 0x80 ||
        ch == r'\';
  }

  /// Whether an identifier can start at the current position.
  bool atIdentifierStart() {
    final ch = peek();
    if (isNameStart(ch)) return true;
    if (ch == '-') {
      final next = peekAt(1);
      return isNameStart(next) || next == '-';
    }
    return false;
  }

  /// Consumes one escape sequence, returning its raw text.
  String _consumeEscape() {
    final start = position;
    position++; // backslash
    if (isAtEnd()) {
      throw FormatException('Trailing backslash', source, start);
    }
    final ch = source[position];
    if (ch == '\n') {
      throw FormatException('Invalid escape: newline', source, position);
    }
    final isHex = RegExp('[0-9a-fA-F]').hasMatch(ch);
    if (!isHex) {
      position++;
      return source.substring(start, position);
    }
    var digits = 0;
    while (!isAtEnd() &&
        digits < 6 &&
        RegExp('[0-9a-fA-F]').hasMatch(source[position])) {
      position++;
      digits++;
    }
    if (!isAtEnd() && RegExp(r'[ \t\n\r\f]').hasMatch(source[position])) {
      position++;
    }
    return source.substring(start, position);
  }

  /// Parses a CSS identifier, decoding escapes.
  ///
  /// Audit **P1-9**: identifiers used to be returned as raw source slices, so
  /// `.foo\.bar` produced a class named `foo\.bar` and never matched.
  String parseIdentifier() {
    final start = position;
    if (peek() == '-') position++;
    if (!isNameStart(peek())) {
      throw FormatException('Expected an identifier', source, position);
    }
    final buffer = StringBuffer(source.substring(start, position));
    while (!isAtEnd()) {
      final ch = source[position];
      if (ch == r'\') {
        buffer.write(_consumeEscape());
      } else if (isNameChar(ch)) {
        buffer.write(ch);
        position++;
      } else {
        break;
      }
    }
    final raw = buffer.toString();
    if (raw.isEmpty || raw == '-') {
      throw FormatException('Expected an identifier', source, start);
    }
    return decodeCssEscapes(raw);
  }

  /// Parses a quoted string, decoding escapes.
  String parseString() {
    final quote = consume();
    final buffer = StringBuffer();
    while (!isAtEnd()) {
      final ch = source[position];
      if (ch == quote) {
        position++;
        return decodeCssEscapes(buffer.toString());
      }
      if (ch == '\n') {
        throw FormatException('Unterminated string', source, position);
      }
      if (ch == r'\') {
        buffer.write(_consumeEscape());
      } else {
        buffer.write(ch);
        position++;
      }
    }
    throw FormatException('Unterminated string', source, position);
  }
}
