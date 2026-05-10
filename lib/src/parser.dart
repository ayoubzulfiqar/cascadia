import 'combined_selector.dart';
import 'matcher.dart';
import 'pseudo_classes.dart';
import 'selectors.dart';

// Pre-compiled regex patterns for performance (avoids repeated allocation in hot paths)
final RegExp _hexCharPattern = RegExp(r'[0-9a-fA-F]');
final RegExp _digitPattern = RegExp(r'[0-9]');

/// Parses CSS selector strings into [Sel] objects.
///
/// The parser follows CSS Selectors Level 3 specification with some
/// Level 4 extensions (such as :where(), :is(), :has(), :focus-visible).
///
/// Example:
/// ```dart
/// final sel = parse('div.foo > p.bar');
/// ```
class Parser {
  final String source;
  int position = 0;
  final bool acceptPseudoElements;

  Parser(this.source, {this.acceptPseudoElements = false});

  /// Parse a complete selector group (comma-separated list).
  ///
  /// Returns a [SelectorGroup] that matches if any selector matches.
  static Sel parseGroup(String source) {
    final parser = Parser(source);
    return parser.parseSelectorGroup();
  }

  /// Parse a complete selector or selector group (comma-separated list).
  ///
  /// Returns a [Sel] that matches if any selector in the group matches.
  static Sel parse(String source) {
    final parser = Parser(source);
    return parser.parseSelectorGroup();
  }

  /// Parse with pseudo-elements enabled.
  static Sel parseWithPseudoElements(String source) {
    final parser = Parser(source, acceptPseudoElements: true);
    return parser.parseSelectorGroup();
  }

  /// Main entry point: parses a selector group and ensures all input is consumed.
  SelectorGroup parseSelectorGroup() {
    final selectors = <Sel>[];
    while (true) {
      selectors.add(parseSelector());
      skipWhitespace();
      if (peek() != ',') break;
      consume(); // consume the comma
      skipWhitespace();
    }
    if (!isAtEnd()) {
      throw FormatException(
          'Unexpected character at position $position: ${source[position]}');
    }
    return SelectorGroup(selectors);
  }

  /// Parse a single selector, possibly including combinators.
  Sel parseSelector() {
    skipWhitespace(); // Skip leading whitespace
    var left = parseSimpleSelectorSequence();

    // Loop to handle combinators (explicit or descendant)
    while (true) {
      skipWhitespace();
      if (isAtEnd()) break;

      final ch = peek();

      if (ch == '>' || ch == '+' || ch == '~') {
        // Explicit combinator
        consume(); // consume combinator
        skipWhitespace(); // skip whitespace after combinator
        final right = parseSimpleSelectorSequence();
        left = CombinedSelector(
          first: left,
          combinator: ch,
          second: right,
        );
      } else if (ch == ',' || ch == ')') {
        // End of this selector (group or pseudo-class)
        break;
      } else {
        // Implicit descendant combinator (space)
        final right = parseSimpleSelectorSequence();
        left = CombinedSelector(
          first: left,
          combinator: ' ',
          second: right,
        );
      }
    }

    return left;
  }

  /// Parse a simple selector sequence: optional type selector followed by
  /// zero or more attribute, class, ID, or pseudo-class selectors.
  ///
  /// A simple selector sequence represents conditions that all apply to
  /// the same element.
  Sel parseSimpleSelectorSequence() {
    final selectors = <Sel>[];
    String? pseudoElement;

    // Check if we have a type selector (tag name), universal selector, or nesting selector
    final firstCh = peek();
    if (firstCh == '*' || _isNameStart(firstCh)) {
      // Type selector or universal
      if (firstCh == '*') {
        consume();
        // Universal selector - no tag constraint
      } else {
        final tag = parseTypeSelector();
        selectors.add(TagSelector(tag));
      }
    } else if (firstCh == '&') {
      // Nesting selector - references parent selector(s)
      consume();
      selectors.add(NestingSelectorPseudoClass());
    }
    // else: no type selector (starts with . # [ :), which is valid

    // Parse any number of attribute selectors, class selectors, ID selectors,
    // or pseudo-classes/pseudo-elements
    while (!isAtEnd()) {
      final ch = peek();
      if (ch == '[') {
        selectors.add(parseAttributeSelector());
      } else if (ch == '.') {
        consume();
        selectors.add(ClassSelector(parseIdentifier()));
      } else if (ch == '#') {
        consume();
        selectors.add(IdSelector(parseName()));
      } else if (ch == ':') {
        final result = parsePseudoclassSelector();
        final (pseudoName, pseudoArg, pseudoNeg) = result;
        if (pseudoName == null) {
          // It's a pseudo-element
          if (!acceptPseudoElements) {
            throw FormatException(
                'Pseudo-element ::$pseudoArg not allowed here (use parseWithPseudoElements)');
          }
          if (pseudoElement != null) {
            throw FormatException(
                'Only one pseudo-element per selector allowed');
          }
          pseudoElement = pseudoArg;
        } else {
          // Normal pseudo-class
          selectors.add(_createPseudoClass(pseudoName, pseudoArg, pseudoNeg));
        }
      } else {
        break; // end of simple selector sequence
      }
    }

    // Handle universal selector explicitly: if no selectors at all, it's "*"
    if (selectors.isEmpty && pseudoElement == null) {
      return TagSelector('*'); // universal matches any element
    }

    // If we have multiple selectors, combine them into a CompoundSelector
    if (selectors.length == 1 && pseudoElement == null) {
      return selectors.first;
    }

    return CompoundSelector(
      selectors: selectors,
      pseudoElement: pseudoElement ?? '',
    );
  }

  /// Parse a type selector (tag name).
  String parseTypeSelector() {
    // Tag names are case-insensitive in HTML; lowercase them for comparison
    return parseIdentifier().toLowerCase();
  }

  /// Parse an identifier (used for class names, tag names).
  ///
  /// An identifier starts with a letter, underscore, or hyphen (if not
  /// followed by a digit), followed by letters, digits, hyphens, underscores.
  /// Supports escape sequences like `\1234` (hex) or `\` followed by char.
  String parseIdentifier() {
    final start = position;
    if (isAtEnd()) {
      throw FormatException('Unexpected end of input in identifier');
    }

    final first = source[position];
    if (!_isNameStart(first)) {
      throw FormatException('Expected identifier start character at $position');
    }
    consume();

    while (!isAtEnd()) {
      final ch = peek();
      if (_isNameChar(ch)) {
        consume();
      } else if (ch == '\\') {
        // Escape sequence
        consume();
        if (isAtEnd()) break;
        final next = source[position];
        if (next == '\n') {
          throw FormatException('Invalid escape: newline');
        } else if (_hexCharPattern.hasMatch(next)) {
          // Hex escape: consume up to 6 hex digits, followed by whitespace or non-hex
          consume();
          for (var i = 0; i < 5; i++) {
            if (isAtEnd()) break;
            final ch2 = peek();
            if (_hexCharPattern.hasMatch(ch2)) {
              consume();
            } else {
              break;
            }
          }
          // Hex escape consumed
        } else {
          // Any other character escaped
          consume();
        }
      } else {
        break;
      }
    }

    return source.substring(start, position);
  }

  /// Parse a name (used for IDs, attribute values).
  ///
  /// Similar to identifier but first character can be more flexible.
  String parseName() {
    final start = position;
    while (!isAtEnd()) {
      final ch = peek();
      if (_isNameChar(ch) || ch == '\\') {
        if (ch == '\\') {
          consume();
          if (!isAtEnd() && source[position] != '\n') {
            consume();
          }
        } else {
          consume();
        }
      } else {
        break;
      }
    }
    if (start == position) {
      throw FormatException('Expected name at position $position');
    }
    return source.substring(start, position);
  }

  /// Parse an attribute value (quoted string or unquoted token).
  String parseAttributeValue() {
    skipWhitespace();
    final ch = peek();
    if (ch == '"' || ch == "'") {
      return parseString();
    } else {
      final start = position;
      while (!isAtEnd()) {
        final ch2 = peek();
        if (ch2 == ']' ||
            ch2 == ' ' ||
            ch2 == '\t' ||
            ch2 == '\n' ||
            ch2 == '\r') {
          break;
        }
        consume();
      }
      return source.substring(start, position);
    }
  }

  /// Parse a quoted string with escape handling.
  String parseString() {
    final quote = consume(); // opening quote
    final start = position;
    final buffer = StringBuffer();
    while (!isAtEnd()) {
      final ch = peek();
      if (ch == quote) {
        consume(); // closing quote
        return buffer.toString();
      } else if (ch == '\\') {
        consume();
        if (!isAtEnd()) {
          final esc = source[position];
          if (esc == '\n') {
            throw FormatException('Invalid escape in string');
          }
          buffer.write(esc);
          consume();
        }
      } else {
        buffer.write(ch);
        consume();
      }
    }
    throw FormatException('Unclosed string starting at position $start');
  }

  /// Parse a regular expression in attribute selector or :matches pseudo-class.
  ///
  /// Format is: /pattern/flags where flags are optional.
  /// In the original Cascadia, regexes are delimited by `/.../`.
  RegExp parseRegex() {
    final delimiter = consume(); // should be '/'
    if (delimiter != '/') {
      throw FormatException('Expected / to start regex at position $position');
    }
    final start = position;
    while (!isAtEnd() && peek() != '/') {
      if (peek() == '\\') {
        consume(); // skip escape
        if (!isAtEnd()) consume();
      } else {
        consume();
      }
    }
    if (isAtEnd()) {
      throw FormatException('Unclosed regex');
    }
    final pattern = source.substring(start, position);
    consume(); // consume closing '/'

    // Optional flags: may include 'i' for case-insensitive
    String? flags;
    if (!isAtEnd() && (peek() == 'i' || peek() == 'g' || peek() == 'm')) {
      final flag = consume();
      // We only support 'i' flag for case-insensitivity
      if (flag == 'i') {
        flags = 'i';
      }
      // ignore 'g', 'm' for now as dart:core RegExp doesn't support them the same way
    }

    try {
      return RegExp(pattern, caseSensitive: flags != 'i');
    } on FormatException catch (e) {
      throw FormatException('Invalid regex pattern: ${e.message}');
    }
  }

  /// Parse an integer from the current position.
  int parseInteger() {
    skipWhitespace();
    final start = position;
    while (!isAtEnd() && _digitPattern.hasMatch(peek())) {
      consume();
    }
    if (start == position) {
      throw FormatException('Expected integer at position $position');
    }
    return int.parse(source.substring(start, position));
  }

  /// Parse an an+b expression for :nth-child and related pseudo-classes.
  ///
  /// Supports:
  /// - `odd` => 2n+1
  /// - `even` => 2n
  /// - `n` => 1n+0
  /// - `3` => 0n+3 (just a number)
  /// - `2n+1`, `-n+3`, `5n-2`, `-2n`, etc.
  (int a, int b) parseNth() {
    skipWhitespace();

    // Check for keywords
    if (!isAtEnd()) {
      final remaining = source.substring(position);
      if (remaining.startsWith('odd')) {
        position += 3;
        return (2, 1);
      }
      if (remaining.startsWith('even')) {
        position += 4;
        return (2, 0);
      }
    }

    // Parse optional sign for a part
    bool aIsPositive = true;
    if (!isAtEnd()) {
      final ch = peek();
      if (ch == '+') {
        consume();
      } else if (ch == '-') {
        consume();
        aIsPositive = false;
      }
    }

    // Parse digits before 'n'
    final numStart = position;
    while (!isAtEnd() && _digitPattern.hasMatch(peek())) {
      consume();
    }
    final numEnd = position; // Position after digits, before 'n'

    bool hasN = false;
    if (!isAtEnd() && (peek() == 'n' || peek() == 'N')) {
      consume();
      hasN = true;
    }

    int a;
    int b;

    if (hasN) {
      // This is an "an" expression
      if (numEnd > numStart) {
        a = int.parse(source.substring(numStart, numEnd));
      } else {
        // Just "n" without a number => a = 1
        a = 1;
      }
      if (!aIsPositive) a = -a;

      // Parse optional b part
      b = 0;
      skipWhitespace();
      if (!isAtEnd()) {
        final signCh = peek();
        if (signCh == '+' || signCh == '-') {
          consume();
          final bIsPositive = signCh == '+';
          skipWhitespace();
          final bStart = position;
          while (!isAtEnd() && _digitPattern.hasMatch(peek())) {
            consume();
          }
          if (position > bStart) {
            b = int.parse(source.substring(bStart, position));
            if (!bIsPositive) b = -b;
          } else {
            throw FormatException(
                'Expected number after $signCh in nth expression at $position');
          }
        }
      }
    } else {
      // Not an "an" expression: it's a pure number => b, a = 0
      if (position > numStart) {
        b = int.parse(source.substring(numStart, position));
        if (!aIsPositive) b = -b;
      } else {
        throw FormatException('Expected number in nth expression at $position');
      }
      a = 0;
    }

    return (a, b);
  }

  /// Parse an attribute selector like [attr], [attr=value], [attr~=value], etc.
  Sel parseAttributeSelector() {
    consume(); // consume '['

    final attrName = parseName();
    skipWhitespace();

    AttrOp operation = AttrOp.present;
    String? value;
    RegExp? regexp;
    bool caseInsensitive = false;

    // Check for operator
    if (!isAtEnd() && !source[position].contains(']')) {
      final opStart = position;
      final op = consume();
      switch (op) {
        case '=':
          operation = AttrOp.equal;
          break;
        case '~':
          if (peek() == '=') {
            consume();
            operation = AttrOp.includes;
          } else {
            throw FormatException('Expected ~= at $position');
          }
          break;
        case '|':
          if (peek() == '=') {
            consume();
            operation = AttrOp.dashMatch;
          } else {
            throw FormatException('Expected |= at $position');
          }
          break;
        case '^':
          if (peek() == '=') {
            consume();
            operation = AttrOp.prefix;
          } else {
            throw FormatException('Expected ^= at $position');
          }
          break;
        case '\$':
          if (peek() == '=') {
            consume();
            operation = AttrOp.suffix;
          } else {
            throw FormatException('Expected \$= at $position');
          }
          break;
        case '*':
          if (peek() == '=') {
            consume();
            operation = AttrOp.substring;
          } else {
            throw FormatException('Expected *= at $position');
          }
          break;
        case '!':
          if (peek() == '=') {
            consume();
            operation = AttrOp.notEqual;
          } else {
            throw FormatException('Expected != at $position');
          }
          break;
        case '#':
          if (peek() == '=') {
            consume();
            operation = AttrOp.regexMatch;
          } else {
            throw FormatException('Expected #= at $position');
          }
          break;
        default:
          throw FormatException(
              'Unknown attribute operator "$op" at position $opStart');
      }
      skipWhitespace();

      // Parse the value
      if (operation == AttrOp.regexMatch) {
        regexp = parseRegex();
      } else {
        value = parseAttributeValue();
      }
    }

    // Check for case-insensitive flag 'i'
    skipWhitespace();
    if (!isAtEnd() && peek() == 'i') {
      consume();
      caseInsensitive = true;
    }

    // Consume closing ]
    if (isAtEnd() || peek() != ']') {
      throw FormatException(
          'Expected ] to close attribute selector at position $position');
    }
    consume();

    return AttributeSelector(
      attributeName: attrName,
      operation: operation,
      value: value,
      regexp: regexp,
      caseInsensitive: caseInsensitive,
    );
  }

  /// Parse a pseudo-class selector, including its arguments if any.
  ///
  /// Returns a tuple of (name, argument, negationArgument) where:
  /// - name: the pseudo-class name (e.g., 'not', 'nth-child'), null if it's a pseudo-element
  /// - argument: the argument string/selector for pseudo-classes that take one
  /// - negationArgument: for :not() style that takes a selector list (null otherwise)
  (String? name, String? argument, Sel? negationArgument)
      parsePseudoclassSelector() {
    consume(); // consume ':'

    // Check if it's a double colon (pseudo-element)
    final isPseudoElement = peek() == ':';
    if (isPseudoElement) {
      consume(); // consume second ':'
    }

    final nameStart = position;
    while (!isAtEnd()) {
      final ch = peek();
      if (_isNameChar(ch) || ch == '-') {
        consume();
      } else {
        break;
      }
    }
    final name = source.substring(nameStart, position);

    String? argument;
    Sel? negationArgument;

    // Check for parentheses (function pseudo-classes)
    if (!isAtEnd() && peek() == '(') {
      consume(); // '('
      // Find the matching closing parenthesis to properly handle nested parens
      final openParenPos = position - 1;
      final closingParenPos = _findMatchingParen(openParenPos);
      final argString = source.substring(position, closingParenPos);

      if (name == 'not' ||
          name == 'has' ||
          name == 'haschild' ||
          name == 'is' ||
          name == 'where' ||
          name == 'host' ||
          name == 'host-context' ||
          name == 'has-slotted' ||
          name == 'slotted' ||
          name == 'cue') {
        // These take a selector list as argument
        final argParser = Parser(argString);
        try {
          final group = argParser.parseSelectorGroup();
          negationArgument = group;
          argument = null;
        } catch (e) {
          throw FormatException('Invalid selector in :$name(): $e');
        }
      } else if (name == 'nth-child' ||
          name == 'nth-last-child' ||
          name == 'nth-of-type' ||
          name == 'nth-last-of-type') {
        // Parse the an+b expression
        try {
          final argParser = Parser(argString);
          final (a, b) = argParser.parseNth();
          argument =
              '$a/$b'; // encode as "a/b" for later parsing in pseudo-class ctor
        } catch (e) {
          throw FormatException('Invalid nth expression in :$name(): $e');
        }
      } else if (name == 'heading') {
        try {
          final argParser = Parser(argString);
          final (a, b) = argParser.parseNth();
          argument = '$a/$b';
        } catch (e) {
          throw FormatException('Invalid nth expression in :$name(): $e');
        }
      } else if (name == 'lang') {
        final argParser = Parser(argString);
        argParser.skipWhitespace();
        argument = argParser.parseName();
      } else if (name == 'contains' || name == 'containsown') {
        final argParser = Parser(argString);
        argParser.skipWhitespace();
        argument = argParser.parseAttributeValue();
      } else if (name == 'matches' || name == 'matchesown') {
        // Parse regex pattern
        try {
          final argParser = Parser(argString);
          final regex = argParser.parseRegex();
          argument = regex.pattern; // store pattern, flags handled later
        } catch (e) {
          throw FormatException('Invalid regex in :$name(): $e');
        }
      } else {
        // Unknown pseudo-class - store raw argument
        final argParser = Parser(argString);
        argParser.skipWhitespace();
        argument = argParser.parseName();
      }

      // Move position to after the closing ')'
      position = closingParenPos + 1;
    }

    if (isPseudoElement) {
      // Build full pseudo-element name including any arguments.
      String fullName = name;
      if (argument != null) {
        fullName = '$name($argument)';
      } else if (negationArgument != null) {
        fullName = '$name($negationArgument)';
      }
      return (null, fullName, null);
    } else {
      return (name, argument, negationArgument);
    }
  }

  /// Create a pseudo-class selector based on the parsed name and arguments.
  ///
  /// This maps the parser output to the concrete pseudo-class selector classes
  /// defined in [pseudo_classes.dart].
  Sel _createPseudoClass(String name, String? argument, Sel? negationArgument) {
    switch (name) {
      case 'not':
        if (negationArgument == null) {
          throw ArgumentError(':not() requires a selector argument');
        }
        return NotPseudoClass(negationArgument);
      case 'has':
        if (negationArgument == null) {
          throw ArgumentError(':has() requires a selector argument');
        }
        return HasPseudoClass(negationArgument);
      case 'haschild':
        if (negationArgument == null) {
          throw ArgumentError(':haschild() requires a selector argument');
        }
        return HasChildPseudoClass(negationArgument);
      case 'is':
        if (negationArgument == null) {
          throw ArgumentError(':is() requires a selector argument');
        }
        return IsPseudoClass(negationArgument);
      case 'where':
        if (negationArgument == null) {
          throw ArgumentError(':where() requires a selector argument');
        }
        return WherePseudoClass(negationArgument);
      case 'contains':
        if (argument == null) {
          throw ArgumentError(':contains() requires a string argument');
        }
        return ContainsPseudoClass(argument, false);
      case 'containsown':
        if (argument == null) {
          throw ArgumentError(':containsown() requires a string argument');
        }
        return ContainsPseudoClass(argument, true);
      case 'matches':
        // argument is regex pattern string from parser
        // Pattern stored as the raw string; if it contains '/' it was parsed as "pattern/flags"
        if (argument != null && argument.contains('/')) {
          final parts = argument.split('/');
          final pattern = parts[0];
          final flags = parts.length > 1 ? parts[1] : '';
          return MatchesPseudoClass(
            RegExp(pattern, caseSensitive: !flags.contains('i')),
            false,
          );
        }
        throw ArgumentError(':matches() requires a regex pattern');
      case 'matchesown':
        if (argument != null && argument.contains('/')) {
          final parts = argument.split('/');
          final pattern = parts[0];
          final flags = parts.length > 1 ? parts[1] : '';
          return MatchesPseudoClass(
            RegExp(pattern, caseSensitive: !flags.contains('i')),
            true,
          );
        }
        throw ArgumentError(':matchesown() requires a regex pattern');
      case 'nth-child':
      case 'nth-last-child':
      case 'nth-of-type':
      case 'nth-last-of-type':
        if (argument == null) {
          throw ArgumentError(':$name requires an an+b expression');
        }
        // argument is encoded as "a/b"
        final parts = argument.split('/');
        final a = int.parse(parts[0]);
        final b = int.parse(parts[1]);
        final isLast = name.contains('last');
        final ofType = name.contains('of-type');
        return NthPseudoClass(a: a, b: b, last: isLast, ofType: ofType);
      case 'first-child':
        return NthPseudoClass.first();
      case 'last-child':
        return NthPseudoClass.last();
      case 'first-of-type':
        return NthPseudoClass.firstOfType();
      case 'last-of-type':
        return NthPseudoClass.lastOfType();
      case 'only-child':
        return OnlyChildPseudoClass(ofType: false);
      case 'only-of-type':
        return OnlyChildPseudoClass(ofType: true);
      case 'empty':
        return EmptyPseudoClass();
      case 'root':
        return RootPseudoClass();
      case 'link':
        return LinkPseudoClass();
      case 'visited':
        return VisitedPseudoClass();
      case 'lang':
        if (argument == null) {
          throw ArgumentError(':lang() requires a language argument');
        }
        return LangPseudoClass(argument);
      case 'input':
        return InputPseudoClass();
      case 'enabled':
        return EnabledPseudoClass();
      case 'disabled':
        return DisabledPseudoClass();
      case 'checked':
        return CheckedPseudoClass();
      // Modern CSS pseudo-classes (Level 4)
      case 'focus-visible':
        return FocusVisiblePseudoClass();
      case 'focus-within':
        return FocusWithinPseudoClass();
      case 'target':
        return TargetPseudoClass();
      case 'target-within':
        return TargetWithinPseudoClass();
      case 'any-link':
        return AnyLinkPseudoClass();
      case 'local-link':
        return LocalLinkPseudoClass();
      case 'scope':
        return ScopePseudoClass();
      case 'dir':
        if (argument == null || (argument != 'ltr' && argument != 'rtl')) {
          throw ArgumentError(':dir() requires "ltr" or "rtl" argument');
        }
        return DirPseudoClass(argument);
      case 'valid':
        return ValidityPseudoClass(ValidityState.valid);
      case 'invalid':
        return ValidityPseudoClass(ValidityState.invalid);
      case 'required':
        return RequiredPseudoClass(RequiredState.required);
      case 'optional':
        return RequiredPseudoClass(RequiredState.optional);
      case 'read-only':
        return ReadOnlyPseudoClass(ReadOnlyState.readOnly);
      case 'read-write':
        return ReadOnlyPseudoClass(ReadOnlyState.readWrite);
      case 'in-range':
        return RangePseudoClass(RangeState.inRange);
      case 'out-of-range':
        return RangePseudoClass(RangeState.outOfRange);
      case 'default':
        return DefaultPseudoClass();
      case 'placeholder-shown':
        return PlaceholderShownPseudoClass();
      case 'autofill':
        return AutofillPseudoClass();
      case 'indeterminate':
        return IndeterminatePseudoClass();
      case 'blank':
        return BlankPseudoClass();
      case 'user-invalid':
        return UserInvalidPseudoClass();
      case 'user-valid':
        return UserValidPseudoClass();
      case 'modal':
        return ModalPseudoClass();
      case 'fullscreen':
        return FullscreenPseudoClass();
      case 'open':
        return OpenPseudoClass();
      // Additional UI and interaction pseudo-classes (CSS Selectors Level 4 & other modules)
      case 'active':
        return ActivePseudoClass();
      case 'hover':
        return HoverPseudoClass();
      case 'focus':
        return FocusPseudoClass();
      case 'defined':
        return DefinedPseudoClass();
      case 'buffering':
        return BufferingPseudoClass();
      case 'seeking':
        return SeekingPseudoClass();
      case 'stalled':
        return StalledPseudoClass();
      case 'paused':
        return PausedPseudoClass();
      case 'playing':
        return PlayingPseudoClass();
      case 'muted':
        return MutedPseudoClass();
      case 'volume-locked':
        return VolumeLockedPseudoClass();
      case 'future':
        return FuturePseudoClass();
      case 'past':
        return PastPseudoClass();
      case 'current':
        return CurrentPseudoClass();
      case 'target-current':
        return TargetCurrentPseudoClass();
      case 'target-before':
        return TargetBeforePseudoClass();
      case 'target-after':
        return TargetAfterPseudoClass();
      case 'left':
        return LeftPseudoClass();
      case 'right':
        return RightPseudoClass();
      case 'first':
        return FirstPseudoClass();
      case 'popover-open':
        return PopoverOpenPseudoClass();
      case 'interest-source':
        return InterestSourcePseudoClass();
      case 'interest-target':
        return InterestTargetPseudoClass();
      case 'state':
        if (argument == null) {
          throw ArgumentError(':state() requires a state name argument');
        }
        return StatePseudoClass(argument);
      case 'xr-overlay':
        return XROverlayPseudoClass();
      case 'anchor':
        return AnchorPseudoClass(argument);
      case 'has-anchor':
        return HasAnchorPseudoClass();
      case 'host':
        if (negationArgument != null) {
          return HostFunctionPseudoClass(negationArgument);
        } else {
          return HostPseudoClass();
        }
      case 'host-context':
        if (negationArgument == null) {
          throw ArgumentError(':host-context() requires a selector argument');
        }
        return HostContextPseudoClass(negationArgument);
      case 'has-slotted':
        return HasSlottedPseudoClass(negationArgument);
      case 'in-container':
        return InContainerPseudoClass();
      case 'ancestor':
        return AncestorPseudoClass();
      case 'parent':
        return ParentPseudoClass();
      case 'prev-sibling':
        return PrevSiblingPseudoClass();
      case 'next-sibling':
        return NextSiblingPseudoClass();
      case 'picture-in-picture':
        return PictureInPicturePseudoClass();
      case 'heading':
        if (argument == null) {
          return HeadingPseudoClass();
        } else {
          final parts = argument.split('/');
          final a = int.parse(parts[0]);
          final b = int.parse(parts[1]);
          return HeadingPseudoClass(a: a, b: b);
        }
      case 'active-view-transition':
        return ActiveViewTransitionPseudoClass();
      case 'active-view-transition-type':
        if (argument == null) {
          throw ArgumentError(
              ':active-view-transition-type() requires an argument');
        }
        return ActiveViewTransitionTypePseudoClass(argument);
      default:
        return UnknownPseudoClass(name);
    }
  }

  /// Check if a character is valid as the first character of a CSS identifier.
  ///
  /// Per CSS Syntax Module Level 3:
  /// - ASCII letters, underscore, or non-ASCII characters
  /// - Hyphen if not followed by a digit or hyphen
  /// - Escape sequences
  bool _isNameStart(String ch) {
    if (ch.length != 1) return false;
    final code = ch.codeUnitAt(0);
    // a-z, A-Z, underscore
    if ((code >= 0x61 && code <= 0x7A) ||
        (code >= 0x41 && code <= 0x5A) ||
        code == 0x5F) {
      return true;
    }
    // non-ASCII (>= 0x80)
    if (code >= 0x80) return true;
    // hyphen if not followed by digit or another hyphen (checked by caller)
    if (ch == '-' && position + 1 < source.length) {
      final next = source[position + 1];
      if (RegExp(r'[0-9-]').hasMatch(next)) return false;
      return true;
    }
    // escape
    if (ch == '\\') return true;
    return false;
  }

  /// Check if a character is valid within a CSS identifier (not first char).
  bool _isNameChar(String ch) {
    if (ch.length != 1) return false;
    final code = ch.codeUnitAt(0);
    // a-z, A-Z, 0-9, underscore, hyphen
    if ((code >= 0x61 && code <= 0x7A) ||
        (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x30 && code <= 0x39) ||
        code == 0x2D || // hyphen-minus
        code == 0x5F || // underscore
        code >= 0x80) {
      return true;
    }
    // escape
    if (ch == '\\') return true;
    return false;
  }

  /// Return current character without consuming it.
  String peek() {
    if (isAtEnd()) return '';
    return source[position];
  }

  /// Consume and return the current character.
  String consume() {
    if (isAtEnd()) throw RangeError('Called consume() at end of input');
    return source[position++];
  }

  /// Skip whitespace characters: space, tab, newline, carriage return.
  void skipWhitespace() {
    while (!isAtEnd()) {
      final ch = peek();
      if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
        consume();
      } else if (ch == '/' &&
          position + 1 < source.length &&
          source[position + 1] == '*') {
        // CSS comment
        consume(); // '/'
        consume(); // '*'
        while (!isAtEnd()) {
          if (peek() == '*' &&
              position + 1 < source.length &&
              source[position + 1] == '/') {
            consume(); // '*'
            consume(); // '/'
            break;
          }
          consume();
        }
      } else {
        break;
      }
    }
  }

  /// Check if we've consumed all input.
  bool isAtEnd() => position >= source.length;

  /// Find the matching closing parenthesis for an opening parenthesis at [openPos].
  ///
  /// This accounts for nested parentheses. Throws [FormatException] if
  /// no matching parenthesis is found.
  int _findMatchingParen(int openPos) {
    int depth = 1;
    int i = openPos + 1;
    while (i < source.length && depth > 0) {
      final ch = source[i];
      if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
      }
      i++;
    }
    if (depth != 0) {
      throw FormatException(
          'Unclosed parenthesis starting at position $openPos');
    }
    return i - 1; // index of the matching ')'
  }
}
