// Regression tests: one per defect ID in AUDIT.md.
//
// Every test here fails on v0.7.6 and passes after the fix, so the register
// cannot silently regress.
import 'package:cascadia/cascadia.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:test/test.dart';

Document doc(String html) => html_parser.parse(html);

/// Guards against a re-introduced infinite loop: a parse must never hang.
void mustTerminate(String selector) {
  try {
    parse(selector);
  } on FormatException {
    // Rejecting invalid input is fine; hanging is not.
  }
}

void main() {
  group('P0-1 parser makes progress (was an infinite loop)', () {
    test('svg|rect parses and round-trips', () {
      expect(parse('svg|rect').toString(), 'svg|rect');
    });

    test('namespace selector matches a real SVG element', () {
      expect(queryAll(doc('<svg><rect/></svg>'), 'svg|rect'), hasLength(1));
      expect(queryAll(doc('<svg><rect/></svg>'), 'math|rect'), isEmpty);
    });

    test('*|a and |a forms parse', () {
      expect(parse('*|a').toString(), '*|a');
      expect(parse('|a').toString(), '|a');
    });

    test('unexpected characters raise FormatException, never hang', () {
      for (final bad in [r'div %', r'a $ b', '@media', 'div!', 'div|']) {
        mustTerminate(bad);
        expect(() => parse(bad), throwsFormatException, reason: bad);
      }
    });
  });

  group('P0-2/3/4 no unsafe casts on non-element nodes', () {
    test(':first-child over text nodes does not throw', () {
      expect(
          queryAll(doc('<ul><li>one</li><li>two</li></ul>'), 'li:first-child')
              .map((e) => e.text),
          ['one']);
    });

    test(':only-child over text nodes does not throw', () {
      expect(queryAll(doc('<div><span>x</span></div>'), 'span:only-child'),
          hasLength(1));
    });

    test(':root with a doctype present does not throw', () {
      expect(
          query(doc('<!DOCTYPE html><html><body></body></html>'), ':root')
              ?.localName,
          'html');
    });

    test('comments and doctypes are skipped safely', () {
      final d = doc('<!DOCTYPE html><!--c--><div>x</div>');
      expect(queryAll(d, 'div'), hasLength(1));
    });
  });

  group('P0-5 selector cache is bounded and LRU', () {
    test('cache does not grow without bound', () {
      clearSelectorCache();
      for (var i = 0; i < 2000; i++) {
        parse('.c$i');
      }
      expect(selectorCacheSize, lessThanOrEqualTo(512));
    });

    test('oversized selectors are not cached', () {
      clearSelectorCache();
      parse(List.filled(200, 'div').join(' > '));
      expect(selectorCacheSize, 0);
    });
  });

  group('P1-1 :has() honours relative combinators', () {
    test(':has(> p) is child-only', () {
      final d = doc('<div><p>x</p></div><div><span><p>y</p></span></div>');
      expect(queryAll(d, 'div:has(> p)'), hasLength(1));
    });

    test(':has(+ p) is next-sibling', () {
      expect(queryAll(doc('<h1>a</h1><p>b</p>'), 'h1:has(+ p)'), hasLength(1));
      expect(queryAll(doc('<h1>a</h1><div></div>'), 'h1:has(+ p)'), isEmpty);
    });

    test(':has(~ p) is subsequent-sibling', () {
      expect(queryAll(doc('<h1>a</h1><div></div><p>b</p>'), 'h1:has(~ p)'),
          hasLength(1));
    });

    test(':has(p) still searches all descendants', () {
      expect(queryAll(doc('<div><span><p>y</p></span></div>'), 'div:has(p)'),
          hasLength(1));
    });
  });

  group('P1-2 class matching is case-sensitive', () {
    test('.foo does not match class="Foo"', () {
      expect(queryAll(doc('<div class="Foo">x</div>'), '.foo'), isEmpty);
      expect(queryAll(doc('<div class="Foo">x</div>'), '.Foo'), hasLength(1));
    });
  });

  group('P1-3/4/5/6 form pseudo-classes', () {
    test(':open honours the open attribute', () {
      final d = doc('<details></details><details open></details>');
      expect(queryAll(d, 'details:open'), hasLength(1));
    });

    test(':default matches the selected option', () {
      final d = doc('<select><option selected>a</option><option>b</option>'
          '</select>');
      expect(queryAll(d, 'option:default'), hasLength(1));
    });

    test(':enabled only applies to form controls', () {
      expect(queryAll(doc('<div>x</div>'), 'div:enabled'), isEmpty);
      expect(queryAll(doc('<input>'), 'input:enabled'), hasLength(1));
      expect(queryAll(doc('<input disabled>'), 'input:enabled'), isEmpty);
    });

    test(':optional only applies to form controls', () {
      expect(queryAll(doc('<div>x</div>'), 'div:optional'), isEmpty);
      expect(queryAll(doc('<input>'), 'input:optional'), hasLength(1));
      expect(queryAll(doc('<input required>'), 'input:optional'), isEmpty);
    });

    test(':disabled is inherited from a disabled fieldset', () {
      final d = doc('<fieldset disabled><input></fieldset>');
      expect(queryAll(d, 'input:disabled'), hasLength(1));
    });
  });

  group('P1-7 bare pseudo-elements never match elements', () {
    test('::before does not match a real element', () {
      final el = doc('<div></div>').body!.children.first;
      expect(parseWithPseudoElements('::before').match(el), isFalse);
    });
  });

  group('P1-8 queryAll excludes the root', () {
    test('root element is not returned', () {
      final d = doc('<div id="a"><div id="b"></div></div>');
      final a = query(d, '#a')!;
      expect(queryAll(a, 'div').map((e) => e.id), ['b']);
    });

    test('closest() does include the node itself', () {
      final d = doc('<div id="a"><span id="b"></span></div>');
      final b = query(d, '#b')!;
      expect(closest(b, 'span')?.id, 'b');
      expect(closest(b, 'div')?.id, 'a');
    });
  });

  group('P1-9 CSS escapes are decoded', () {
    test('escaped dot in a class name', () {
      expect(queryAll(doc('<div class="foo.bar">x</div>'), r'.foo\.bar'),
          hasLength(1));
    });

    test('hex escape resolves to the right character', () {
      expect(queryAll(doc('<div class="a b">x</div>'), r'.a\62 '), isEmpty);
      expect(parse(r'.\41 ').toString(), r'.A');
    });
  });

  group('P1-11 :root is the document element only', () {
    test('only <html> matches', () {
      expect(
          queryAll(doc('<html><body><div></div></body></html>'), ':root')
              .map((e) => e.localName),
          ['html']);
    });
  });

  group('P2-1/2/3 serialization round-trips', () {
    const corpus = <String>[
      'div',
      '.cls',
      '#id',
      '*',
      'a[href]',
      r'[src$=".png"]',
      '[href^="https"]',
      '[title*="x"]',
      '[lang|="en"]',
      '[class~="a"]',
      'div p',
      'div > p',
      'h1 + p',
      'h1 ~ p',
      'div.a#b[c]',
      ':nth-child(2n+1)',
      ':nth-child(n)',
      ':nth-child(-n+3)',
      ':nth-child(3)',
      ':nth-last-of-type(2n)',
      ':first-child',
      ':last-of-type',
      ':only-child',
      ':empty',
      ':root',
      ':not(.a)',
      ':is(h1, h2)',
      ':where(.a)',
      ':has(> p)',
      ':has(+ p)',
      ':lang(en)',
      ':dir(rtl)',
      'svg|rect',
      '*|a',
      'a:hover',
      'input:checked',
      'li:nth-of-type(odd)',
    ];

    test('every selector survives parse -> toString -> parse', () {
      for (final css in corpus) {
        final once = parse(css);
        final text = once.toString();
        late Sel twice;
        expect(() => twice = parse(text), returnsNormally,
            reason: 'reparse failed for "$css" -> "$text"');
        expect(twice.toString(), text, reason: 'unstable for "$css"');
      }
    });

    test('specificity is preserved across a round trip', () {
      for (final css in corpus) {
        final a = parse(css);
        expect(parse(a.toString()).specificity, a.specificity, reason: css);
      }
    });

    test('descendant combinator uses exactly one space', () {
      expect(parse('div p').toString(), 'div p');
    });

    test('suffix attribute selector serializes correctly', () {
      expect(parse(r'[src$=".png"]').toString(), r'[src$=".png"]');
    });
  });

  group('P2-4/5 specificity follows Selectors L4 §15', () {
    test('universal selector is ignored', () {
      expect(parse('*').specificity, Specificity.zero);
      expect(parse('*.foo').specificity, Specificity(0, 1, 0));
    });

    test('spec worked examples', () {
      expect(parse(':is(em, #foo)').specificity, Specificity(1, 0, 0));
      expect(parse(':not(em, strong#foo)').specificity, Specificity(1, 0, 1));
      expect(parse('.qux:where(#a#b#c)').specificity, Specificity(0, 1, 0));
    });

    test(':has() replaces, not adds', () {
      expect(parse('div:has(p)').specificity, Specificity(0, 0, 2));
    });
  });

  group('P2-6 :matches() accepts a regex', () {
    test('parses and matches text content', () {
      expect(parse(':matches(/foo/)').toString(), ':matches(/foo/)');
      expect(queryAll(doc('<p>foobar</p>'), 'p:matches(/oob/)'), hasLength(1));
      expect(queryAll(doc('<p>xyz</p>'), 'p:matches(/oob/)'), isEmpty);
    });

    test('case-insensitive flag is honoured', () {
      expect(queryAll(doc('<p>FOO</p>'), 'p:matches(/foo/i)'), hasLength(1));
    });
  });

  group('P2-8 malformed selectors are rejected', () {
    const invalid = <String>[
      'div >',
      '> ',
      '',
      '   ',
      'div,,',
      'div,',
      ':not()',
      '[',
      '[a',
      'div::bogus-element',
      ':bogus-thing',
      ':nth-child()',
      ':nth-child(foo)',
      ':lang()',
      'a::before span',
      ':dir(sideways)',
    ];

    test('each raises FormatException without hanging', () {
      for (final css in invalid) {
        mustTerminate(css);
        expect(() => parseWithPseudoElements(css), throwsFormatException,
            reason: 'expected "$css" to be rejected');
      }
    });

    test('lenient mode tolerates unknown pseudo-classes', () {
      expect(parseLenient(':bogus-thing').toString(), ':bogus-thing');
      expect(parseLenient(':bogus-thing').match(Element.tag('div')), isFalse);
    });
  });

  group('§2.2B undecidable selectors are honest', () {
    test('support is reported', () {
      expect(parse('div').support, MatchSupport.decidable);
      expect(parse(':hover').support, MatchSupport.requiresContext);
    });

    test('undecidableParts names what is missing', () {
      expect(parse('a:hover').undecidableParts, {':hover'});
      expect(parse('div.a').undecidableParts, isEmpty);
    });

    test(':hover matches ancestors of the hovered element', () {
      final d = doc('<div id="outer"><a id="inner">x</a></div>');
      final inner = query(d, '#inner')!;
      final matches = queryAll(d, ':hover', MatchContext(hovered: inner));
      expect(matches.map((e) => e.id), containsAll(['outer', 'inner']));
    });

    test(':visited uses the supplied visited set', () {
      final d = doc('<a href="/seen">a</a><a href="/new">b</a>');
      final ctx = MatchContext(
          currentUrl: Uri.parse('https://x.test/p'),
          visitedUrls: {'https://x.test/seen'});
      expect(queryAll(d, 'a:visited', ctx).map((e) => e.text), ['a']);
      expect(queryAll(d, 'a:link', ctx).map((e) => e.text), ['b']);
    });
  });

  group('fuzz-discovered regressions', () {
    test('string arguments do not grow on each round trip', () {
      // ':contains("x")' stored the raw slice including quotes, so toString()
      // re-quoted it and the selector grew without bound.
      for (final css in [
        ':contains("x")',
        ':containsown("a b")',
        r':contains("say \"hi\"")',
        ':lang(en)',
        ':state(private)',
      ]) {
        final once = parse(css).toString();
        expect(parse(once).toString(), once, reason: css);
        expect(parse(parse(once).toString()).toString(), once, reason: css);
      }
    });

    test('mismatched quoting in a string argument is rejected', () {
      expect(() => parse(':contains("x"s)'), throwsFormatException);
      expect(() => parse(':lang(en fr)'), throwsFormatException);
    });

    test('a quote inside a regex argument is literal', () {
      expect(parse(':matches(/a"b/)').toString(), ':matches(/a"b/)');
      expect(queryAll(doc('<p>a"b</p>'), 'p:matches(/a"b/)'), hasLength(1));
    });

    test('control characters re-serialize as hex escapes', () {
      // '\a' decodes to U+000A; emitting it raw produced '\<newline>', which
      // is invalid CSS and could not be reparsed.
      for (final css in [r'i\av', r'.a\9 b', r'#x\1f y']) {
        final text = parse(css).toString();
        expect(() => parse(text), returnsNormally,
            reason: '$css serialized to $text');
        expect(parse(text).toString(), text, reason: css);
      }
    });
  });

  group('performance guards', () {
    test('wide sibling lists stay fast', () {
      final sb = StringBuffer('<div>');
      for (var i = 0; i < 3000; i++) {
        sb.write('<p class="c$i">t</p>');
      }
      sb.write('</div>');
      final d = doc(sb.toString());
      final sw = Stopwatch()..start();
      expect(queryAll(d, 'div:has(.c2999)'), hasLength(1));
      expect(queryAll(d, 'p:nth-child(2n+1)'), hasLength(1500));
      sw.stop();
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('deeply nested documents do not overflow the stack', () {
      final d = doc('<div>' * 2000);
      expect(queryAll(d, 'div').length, greaterThan(1000));
    });
  });
}
