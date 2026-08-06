// Fuzz tests: the parser must always terminate, and may only fail with a
// FormatException.
//
// Audit P0-1 was an infinite loop reachable from documented input. A property
// test over random and mutated selectors is the cheapest durable guard: it
// does not need to know *which* input hangs, only that none may.
import 'dart:math';

import 'package:cascadia/cascadia.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:test/test.dart';

/// Characters drawn from real CSS selector syntax, so the fuzzer spends its
/// budget near the grammar rather than on unreachable noise.
const _alphabet = r'''abcdivpsan .#[]()>+~*|=^$!:,"'\/-_0123456789 	nth-child'''
    'odd even not is where has lang dir contains matches slotted part';

String _randomSelector(Random rng, int maxLength) {
  final length = rng.nextInt(maxLength) + 1;
  final buffer = StringBuffer();
  for (var i = 0; i < length; i++) {
    buffer.write(_alphabet[rng.nextInt(_alphabet.length)]);
  }
  return buffer.toString();
}

/// Valid selectors used as seeds for mutation.
const _seeds = <String>[
  'div',
  '.cls',
  '#id',
  '*',
  'a[href]',
  r'[src$=".png"]',
  'div p',
  'div > p',
  'h1 + p',
  'h1 ~ p',
  'div.a#b[c]',
  ':nth-child(2n+1)',
  ':not(.a)',
  ':is(h1, h2)',
  ':where(.a)',
  ':has(> p)',
  ':lang(en)',
  'svg|rect',
  '*|a',
  'li:nth-of-type(odd)',
  'input:checked',
  ':matches(/foo/)',
  ':contains("x")',
  'a:hover',
  ':root',
  ':empty',
];

String _mutate(Random rng, String seed) {
  if (seed.isEmpty) return seed;
  final chars = seed.split('');
  final operations = rng.nextInt(3) + 1;
  for (var i = 0; i < operations; i++) {
    if (chars.isEmpty) break;
    switch (rng.nextInt(3)) {
      case 0: // delete
        chars.removeAt(rng.nextInt(chars.length));
      case 1: // insert
        chars.insert(rng.nextInt(chars.length + 1),
            _alphabet[rng.nextInt(_alphabet.length)]);
      case 2: // replace
        chars[rng.nextInt(chars.length)] =
            _alphabet[rng.nextInt(_alphabet.length)];
    }
  }
  return chars.join();
}

/// Parses [selector], allowing only a FormatException.
///
/// Any other exception type is a bug: an unhandled RangeError or StateError
/// escaping the parser means an unvalidated code path. A hang shows up as the
/// enclosing test timing out.
void parseOrFormatException(String selector, void Function(String) parseFn) {
  try {
    parseFn(selector);
  } on FormatException {
    // Expected for invalid input.
  } catch (e) {
    fail('parse(${_show(selector)}) threw ${e.runtimeType}, '
        'expected FormatException or success: $e');
  }
}

String _show(String s) => "'${s.replaceAll('\n', r'\n')}'";

void main() {
  // A fixed seed keeps failures reproducible; bump it to explore new inputs.
  const seed = 20260806;

  group('fuzz: random input', () {
    test('10k random selectors terminate without unexpected exceptions', () {
      final rng = Random(seed);
      for (var i = 0; i < 10000; i++) {
        parseOrFormatException(_randomSelector(rng, 24), parse);
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('long random selectors terminate', () {
      final rng = Random(seed + 1);
      for (var i = 0; i < 500; i++) {
        parseOrFormatException(_randomSelector(rng, 300), parse);
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('fuzz: mutated valid selectors', () {
    test('20k mutations of known-good selectors terminate', () {
      final rng = Random(seed + 2);
      for (var i = 0; i < 20000; i++) {
        final mutated = _mutate(rng, _seeds[rng.nextInt(_seeds.length)]);
        parseOrFormatException(mutated, parse);
      }
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('mutations terminate with pseudo-elements enabled', () {
      final rng = Random(seed + 3);
      for (var i = 0; i < 5000; i++) {
        final mutated = _mutate(rng, _seeds[rng.nextInt(_seeds.length)]);
        parseOrFormatException(mutated, parseWithPseudoElements);
      }
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('mutations terminate in lenient mode', () {
      final rng = Random(seed + 4);
      for (var i = 0; i < 5000; i++) {
        final mutated = _mutate(rng, _seeds[rng.nextInt(_seeds.length)]);
        parseOrFormatException(mutated, parseLenient);
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('fuzz: structural edge cases', () {
    test('unbalanced and nested delimiters terminate', () {
      final cases = <String>[
        '(',
        ')',
        '((((',
        '))))',
        '[',
        ']',
        '[[[[',
        ':not(',
        ':not((',
        ':not(:not(',
        ':has(> ',
        ':is(,',
        '"',
        "'",
        r'\',
        r'\\',
        '/*',
        '/* unterminated',
        ':nth-child(',
        ':nth-child(2n+',
        '[a=',
        '[a="',
        ':lang(',
        '::',
        ':::',
        '&&&',
        '|||',
        ',,,',
        '>>>',
        '~~~',
        '+++',
        '***',
        '###',
        '...',
        '::part(',
        '::slotted(',
      ];
      for (final css in cases) {
        parseOrFormatException(css, parseWithPseudoElements);
      }
    });

    test('deeply nested functional pseudo-classes terminate', () {
      for (final depth in [10, 50, 200]) {
        final nested = '${':not(' * depth}div${')' * depth}';
        parseOrFormatException(nested, parse);
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('pathological repetition terminates', () {
      parseOrFormatException('div' * 2000, parse);
      parseOrFormatException('.a' * 2000, parse);
      parseOrFormatException('div ' * 1000, parse);
      parseOrFormatException('${'div,' * 1000}div', parse);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('unicode and control characters terminate', () {
      final cases = <String>[
        'div\u0000',
        'div\u00a0p',
        '.日本語',
        '#\u2603',
        'div\u{1F600}',
        '\u0001\u0002',
        'div\r\np',
        '.a\tb',
      ];
      for (final css in cases) {
        parseOrFormatException(css, parse);
      }
    });
  });

  group('fuzz: successfully parsed selectors are well-behaved', () {
    test('anything that parses also serializes and reparses', () {
      final rng = Random(seed + 5);
      var parsed = 0;
      for (var i = 0; i < 20000; i++) {
        final css = _mutate(rng, _seeds[rng.nextInt(_seeds.length)]);
        Sel? sel;
        try {
          sel = parse(css);
        } on FormatException {
          continue;
        }
        parsed++;
        final text = sel.toString();
        late Sel again;
        try {
          again = parse(text);
        } catch (e) {
          fail('parse(${_show(css)}) serialized to ${_show(text)}, '
              'which failed to reparse: $e');
        }
        expect(again.toString(), text,
            reason: 'unstable serialization for ${_show(css)}');
        expect(again.specificity, sel.specificity,
            reason: 'specificity drift for ${_show(css)}');
      }
      // Guard against the corpus degenerating into all-invalid input, which
      // would make this test vacuous.
      expect(parsed, greaterThan(1000),
          reason: 'too few mutations parsed; the fuzz corpus may be broken');
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('anything that parses can be matched without throwing', () {
      final doc =
          html_parser.parse('<html><body><div id="a" class="x y"><p>t</p>'
              '<input type="checkbox" checked><a href="/l">L</a>'
              '</div></body></html>');
      final rng = Random(seed + 6);
      for (var i = 0; i < 5000; i++) {
        final css = _mutate(rng, _seeds[rng.nextInt(_seeds.length)]);
        try {
          final sel = parse(css);
          queryAll(doc, css);
          sel.match(doc);
        } on FormatException {
          continue;
        } catch (e) {
          fail('matching ${_show(css)} threw ${e.runtimeType}: $e');
        }
      }
    }, timeout: const Timeout(Duration(seconds: 120)));
  });
}
