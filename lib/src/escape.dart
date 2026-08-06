/// CSS escape handling shared by the parser and the serializers.
///
/// Fixes audit defect **P1-9** — escapes used to be carried around raw
/// (`.foo\.bar` produced a class selector literally named `foo\.bar`).
/// Values are now decoded on parse and re-escaped on serialization, so
/// selectors survive a `parse -> toString -> parse` round trip.
library;

bool _isHexDigit(String ch) {
  final c = ch.codeUnitAt(0);
  return (c >= 0x30 && c <= 0x39) || // 0-9
      (c >= 0x41 && c <= 0x46) || // A-F
      (c >= 0x61 && c <= 0x66); // a-f
}

bool _isCssWhitespace(String ch) =>
    ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' || ch == '\f';

/// Decodes CSS escape sequences in [raw].
///
/// Handles hex escapes (`\26`, `\000026`, with an optional single trailing
/// whitespace terminator) and literal escapes (`\.` -> `.`).
String decodeCssEscapes(String raw) {
  if (!raw.contains(r'\')) return raw;
  final out = StringBuffer();
  var i = 0;
  while (i < raw.length) {
    final ch = raw[i];
    if (ch != r'\') {
      out.write(ch);
      i++;
      continue;
    }
    i++; // consume the backslash
    if (i >= raw.length) {
      out.write('\uFFFD'); // trailing backslash -> replacement char
      break;
    }
    if (_isHexDigit(raw[i])) {
      final hex = StringBuffer();
      var digits = 0;
      while (i < raw.length && digits < 6 && _isHexDigit(raw[i])) {
        hex.write(raw[i]);
        i++;
        digits++;
      }
      // A single whitespace character may terminate a hex escape.
      if (i < raw.length && _isCssWhitespace(raw[i])) {
        if (raw[i] == '\r' && i + 1 < raw.length && raw[i + 1] == '\n') i++;
        i++;
      }
      final cp = int.parse(hex.toString(), radix: 16);
      out.write(cp == 0 || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF)
          ? '\uFFFD'
          : String.fromCharCode(cp));
    } else {
      out.write(raw[i]);
      i++;
    }
  }
  return out.toString();
}

bool _isIdentChar(int code) =>
    (code >= 0x61 && code <= 0x7A) || // a-z
    (code >= 0x41 && code <= 0x5A) || // A-Z
    (code >= 0x30 && code <= 0x39) || // 0-9
    code == 0x2D || // -
    code == 0x5F || // _
    code >= 0x80; // non-ASCII

/// Escapes [value] so it can be emitted as a CSS identifier.
String escapeCssIdent(String value) {
  if (value.isEmpty) return value;
  final out = StringBuffer();
  for (var i = 0; i < value.length; i++) {
    final ch = value[i];
    final code = value.codeUnitAt(i);
    final isDigit = code >= 0x30 && code <= 0x39;
    if (i == 0 && isDigit) {
      out.write('\\3$ch ');
      continue;
    }
    if (i == 0 && ch == '-' && value.length == 1) {
      out.write(r'\-');
      continue;
    }
    if (_isIdentChar(code)) {
      out.write(ch);
    } else if (code <= 0x1F || code == 0x7F) {
      // Control characters have no literal escape: `\` followed by a raw
      // newline is invalid CSS, so a decoded U+000A must be re-emitted as a
      // hex escape. Emitting it raw produced unparseable output for input
      // like `i\av` (found by fuzz_test.dart).
      out.write('\\${code.toRadixString(16)} ');
    } else {
      out.write('\\$ch');
    }
  }
  return out.toString();
}

/// Escapes [value] and wraps it in double quotes for use as a CSS string.
String escapeCssString(String value) {
  final out = StringBuffer('"');
  for (var i = 0; i < value.length; i++) {
    final ch = value[i];
    final code = value.codeUnitAt(i);
    if (ch == '"' || ch == r'\') {
      out.write('\\$ch');
    } else if (code <= 0x1F || code == 0x7F) {
      // Raw control characters are not permitted inside a CSS string.
      out.write('\\${code.toRadixString(16)} ');
    } else {
      out.write(ch);
    }
  }
  out.write('"');
  return out.toString();
}
