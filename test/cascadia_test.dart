import 'package:cascadia/cascadia.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:test/test.dart';

// Re-export common element creation helpers
Element findElement(String tag,
    {String? id, List<String>? classes, Map<String, String>? attrs}) {
  final el = Element.tag(tag);
  if (id != null) el.id = id;
  if (classes != null) el.classes.addAll(classes);
  if (attrs != null) el.attributes.addAll(attrs);
  return el;
}

/// Parse an HTML string into a [Document].
Document parseHTML(String html) {
  return html_parser.parse(html);
}

void main() {
  group('Basic Selectors', () {
    test('Type selector', () {
      final sel = parse('div');
      expect(sel.match(findElement('div')), isTrue);
      expect(sel.match(findElement('span')), isFalse);
    });

    test('Universal selector *', () {
      final sel = parse('*');
      expect(sel.match(findElement('div')), isTrue);
      expect(sel.match(findElement('body')), isTrue);
    });

    test('Class selector', () {
      final sel = parse('.foo');
      expect(sel.match(findElement('div', classes: ['foo'])), isTrue);
      expect(sel.match(findElement('div', classes: ['bar'])), isFalse);
      expect(sel.match(findElement('div', classes: ['foo', 'bar'])), isTrue);
    });

    test('ID selector', () {
      final sel = parse('#header');
      expect(sel.match(findElement('div', id: 'header')), isTrue);
      expect(sel.match(findElement('div', id: 'footer')), isFalse);
    });
  });

  group('Attribute Selectors', () {
    test('Presence [attr]', () {
      final sel = parse('[href]');
      expect(sel.match(findElement('a', attrs: {'href': 'http://example.com'})),
          isTrue);
      expect(sel.match(findElement('a')), isFalse);
    });

    test('Equality [attr=value]', () {
      final sel = parse('[type="text"]');
      expect(sel.match(findElement('input', attrs: {'type': 'text'})), isTrue);
      expect(sel.match(findElement('input', attrs: {'type': 'password'})),
          isFalse);
    });

    test('Includes [attr~=value]', () {
      final sel = parse('[class~="highlighted"]');
      expect(
          sel.match(findElement('div', classes: ['foo', 'highlighted', 'bar'])),
          isTrue);
      expect(
          sel.match(findElement('div', classes: ['highlighted-foo'])), isFalse);
      expect(sel.match(findElement('div', classes: ['foo'])), isFalse);
    });

    test('Dash match [attr|=value]', () {
      final sel = parse('[lang|="en"]');
      expect(sel.match(findElement('div', attrs: {'lang': 'en'})), isTrue);
      expect(sel.match(findElement('div', attrs: {'lang': 'en-US'})), isTrue);
      expect(sel.match(findElement('div', attrs: {'lang': 'en-GB'})), isTrue);
      expect(sel.match(findElement('div', attrs: {'lang': 'fr'})), isFalse);
      expect(
          sel.match(findElement('div', attrs: {'lang': 'english'})), isFalse);
    });

    test('Prefix [attr^=value]', () {
      final sel = parse('[href^="https"]');
      expect(
          sel.match(findElement('a', attrs: {'href': 'https://example.com'})),
          isTrue);
      expect(sel.match(findElement('a', attrs: {'href': 'http://example.com'})),
          isFalse);
    });

    test('Suffix [attr\$=value]', () {
      final sel = parse('[src\$=".png"]');
      expect(sel.match(findElement('img', attrs: {'src': 'logo.png'})), isTrue);
      expect(
          sel.match(findElement('img', attrs: {'src': 'logo.jpg'})), isFalse);
    });

    test('Substring [attr*=value]', () {
      final sel = parse('[title*="warning"]');
      expect(
          sel.match(findElement('div', attrs: {'title': 'Caution: warning!'})),
          isTrue);
      expect(
          sel.match(findElement('div', attrs: {'title': 'Caution'})), isFalse);
    });
  });

  group('Combinators', () {
    test('Descendant (space)', () {
      final matches =
          queryAll(parseHTML('<div><span>Match</span></div>'), 'div span');
      expect(matches, hasLength(1));
      expect(matches.first.text, 'Match');
    });

    test('Child (>)', () {
      final doc = parseHTML('<div><p>Child</p><div><p>Nested</p></div></div>');
      final matches = queryAll(doc, 'div > p');
      // Both <p> elements are direct children of a <div>, so both match.
      expect(matches.map((e) => e.text), ['Child', 'Nested']);
    });

    test('Adjacent sibling (+)', () {
      final matches = queryAll(
          parseHTML('<h1>Title</h1><p>First</p><p>Second</p>'), 'h1 + p');
      expect(matches, hasLength(1));
      expect(matches.first.text, 'First');
    });

    test('General sibling (~)', () {
      final matches = queryAll(
          parseHTML('<h1>Title</h1><div></div><p>First</p><p>Second</p>'),
          'h1 ~ p');
      expect(matches, hasLength(2));
    });
  });

  group('Pseudo-Classes', () {
    test(':first-child', () {
      final result = query(parseHTML('<ul><li>First</li><li>Second</li></ul>'),
          'li:first-child');
      expect(result?.text, 'First');
    });

    test(':last-child', () {
      final result = query(
          parseHTML('<ul><li>First</li><li>Last</li></ul>'), 'li:last-child');
      expect(result?.text, 'Last');
    });

    test(':only-child', () {
      final result =
          query(parseHTML('<div><span>Solo</span></div>'), 'span:only-child');
      expect(result?.text, 'Solo');
    });

    test(':nth-child(odd/even)', () {
      final doc =
          parseHTML('<ul><li>1</li><li>2</li><li>3</li><li>4</li></ul>');
      final oddMatches = queryAll(doc, 'li:nth-child(odd)');
      final evenMatches = queryAll(doc, 'li:nth-child(even)');
      expect(oddMatches.map((e) => e.text), ['1', '3']);
      expect(evenMatches.map((e) => e.text), ['2', '4']);
    });

    test(':nth-child(2n+1)', () {
      final doc = parseHTML(
          '<ul><li>1</li><li>2</li><li>3</li><li>4</li><li>5</li></ul>');
      final matches = queryAll(doc, 'li:nth-child(2n+1)');
      expect(matches.map((e) => e.text), ['1', '3', '5']);
    });

    test(':nth-of-type', () {
      final result = query(
          parseHTML('<div><p>First</p><div>Not p</div><p>Second</p></div>'),
          'p:nth-of-type(2)');
      expect(result?.text, 'Second');
    });

    test(':first-of-type', () {
      final result = query(
          parseHTML(
              '<div><span>Irrelevant</span><p>First p</p><p>Second p</p></div>'),
          'p:first-of-type');
      expect(result?.text, 'First p');
    });

    test(':empty', () {
      final doc = parseHTML('<div><p></p><span></span><b>Not empty</b></div>');
      final root = doc.body ?? doc;
      final matches = queryAll(root, ':empty');
      expect(matches.map((e) => (e.localName ?? '')), ['p', 'span']);
    });

    test(':root', () {
      final result = query(parseHTML('<html><body></body></html>'), ':root');
      expect(result?.localName, 'html');
    });

    test(':not(selector)', () {
      final doc = parseHTML(
          '<div class="included">A</div><div class="excluded">B</div><p class="included">C</p>');
      final matches = queryAll(doc, 'div:not(.excluded)');
      expect(matches.map((e) => e.text), ['A']);
    });

    test(':is(selector)', () {
      final doc = parseHTML('<div>D</div><span>S</span><p>P</p>');
      final matches = queryAll(doc, ':is(div, span)');
      expect(matches.map((e) => (e.localName ?? '')), ['div', 'span']);
    });

    test(':where(selector) specificity', () {
      final sel = parse(':where(.a, .b)');
      expect(sel.specificity, Specificity(0, 0, 0));
    });
  });

  group('Specificity', () {
    test('Simple selectors', () {
      expect(parse('div').specificity, Specificity(0, 0, 1));
      expect(parse('.class').specificity, Specificity(0, 1, 0));
      expect(parse('#id').specificity, Specificity(1, 0, 0));
      expect(parse('[attr]').specificity, Specificity(0, 1, 0));
    });

    test('Compound selector', () {
      expect(parse('div.foo#bar').specificity, Specificity(1, 1, 1));
      expect(parse('a[href].external').specificity, Specificity(0, 2, 1));
    });

    test('Combined selectors', () {
      expect(parse('div > span').specificity, Specificity(0, 0, 2));
      expect(parse('#nav a').specificity, Specificity(1, 0, 1));
    });

    test('Pseudo-classes add B component', () {
      expect(parse('div:first-child').specificity, Specificity(0, 1, 1));
      expect(parse('.foo:hover').specificity, Specificity(0, 2, 0));
    });

    test(':not() and :is() take specificity of argument', () {
      expect(parse('div:not(.a)').specificity, Specificity(0, 1, 1));
      expect(parse('div:is(#x)').specificity, Specificity(1, 0, 1));
    });

    test(':where() always has 0 specificity', () {
      expect(parse(':where(div, #id)').specificity, Specificity(0, 0, 0));
      expect(parse('div:where(.a)').specificity, Specificity(0, 0, 1));
    });

    test('Pseudo-elements add C component', () {
      final sel = parseWithPseudoElements('p::first-line');
      expect(sel.specificity, Specificity(0, 0, 2));
    });
  });

  group('Serialization', () {
    test('Round-trip simple selectors', () {
      final originals = [
        'div',
        '.class',
        '#id',
        '[href]',
        '[href="https://example.com"]',
        '[class~="active"]',
        'a:hover',
        'div.foo#bar',
      ];
      for (final original in originals) {
        final sel = parse(original);
        final back = serialize(sel);
        expect(parse(back).toString(), sel.toString());
      }
    });
  });

  group('Complex Selectors', () {
    test('Multiple combinators', () {
      final doc = parseHTML(
          '<body><div><section><p>No</p></section></div><div><p>Yes</p></div></body>');
      final matches = queryAll(doc, 'body > div > p');
      expect(matches.map((e) => e.text), ['Yes']);
    });

    test('Selector list (comma)', () {
      final doc = parseHTML('<h1>One</h1><h2>Two</h2><p>Three</p>');
      final matches = queryAll(doc, 'h1, h2, h3');
      expect(matches.map((e) => (e.localName ?? '')), ['h1', 'h2']);
    });

    test('Multiple classes', () {
      final doc = parseHTML(
          '<div class="foo bar">A</div><div class="foo">B</div><div class="bar">C</div>');
      expect(query(doc, '.foo.bar')?.text, 'A');
    });

    test('Complex attribute selector', () {
      final doc = parseHTML('''
        <a href="https://example.com">Match</a>
        <a href="http://example.com">No http</a>
        <a href="https://test.com">No example</a>
      ''');
      expect(query(doc, 'a[href^="https"][href*="example"]')?.text, 'Match');
    });
  });

  group('Modern CSS Pseudo-classes', () {
    test(':focus-visible is undecidable without context', () {
      final sel = parse(':focus-visible');
      expect(sel.match(Element.tag('div')), isFalse);
      expect(sel.support, MatchSupport.requiresContext);
      expect(sel.undecidableParts, contains(':focus-visible'));
    });

    test(':focus matches when the context supplies the focused element', () {
      final doc = parseHTML('<input id="a"><input id="b">');
      final b = query(doc, '#b')!;
      final matches = queryAll(doc, ':focus', MatchContext(focused: b));
      expect(matches.map((e) => e.id), ['b']);
    });

    test(':target resolves from the context URL fragment', () {
      final doc = parseHTML('<div id="one"></div><div id="two"></div>');
      final matches = queryAll(
          doc, ':target', MatchContext(currentUrl: Uri.parse('page#two')));
      expect(matches.map((e) => e.id), ['two']);
    });

    test('strict mode throws instead of silently returning false', () {
      expect(
          () => parse(':hover')
              .matchWith(Element.tag('a'), MatchContext.strictEmpty),
          throwsA(isA<UndecidableSelectorError>()));
    });

    test(':any-link', () {
      final doc = parseHTML('''
        <a href="#">Link</a>
        <area href="#">
        <link href="style.css">
        <span>Not link</span>
      ''');
      final matches = queryAll(doc, ':any-link');
      expect(matches.map((e) => (e.localName ?? '')), ['a', 'area', 'link']);
    });

    test(':dir(ltr) matches resolved directionality', () {
      // Per Selectors L4, :dir() reflects an element's *resolved*
      // directionality, which defaults to ltr and is inherited. The previous
      // implementation only compared the literal dir attribute.
      final doc = parseHTML('''
        <div dir="ltr">LTR</div>
        <div dir="rtl">RTL</div>
      ''');
      final ltr = queryAll(doc, 'div:dir(ltr)');
      final rtl = queryAll(doc, 'div:dir(rtl)');
      expect(ltr.map((e) => e.text), ['LTR']);
      expect(rtl.map((e) => e.text), ['RTL']);
    });

    test(':dir(rtl) is inherited from an ancestor', () {
      final doc = parseHTML('<div dir="rtl"><span>inner</span></div>');
      expect(queryAll(doc, 'span:dir(rtl)'), hasLength(1));
      expect(queryAll(doc, 'span:dir(ltr)'), isEmpty);
    });
  });

  group('Edge Cases and Error Handling', () {
    test('Parse error on invalid selector', () {
      expect(() => parse('['), throwsFormatException);
      expect(() => parse('div::before'), throwsFormatException);
    });

    test('Whitespace handling', () {
      final sel = parse('  div  >  .foo  ');
      expect(sel.toString(), 'div > .foo');
    });

    test('Case-insensitive tag matching', () {
      final sel = parse('DIV');
      expect(sel.match(findElement('div')), isTrue);
      expect(sel.match(findElement('DIV')), isTrue);
    });
  });

  group('Nth Complex Expressions', () {
    test('Negative a: -n+3', () {
      final doc =
          parseHTML('<ul><li>1</li><li>2</li><li>3</li><li>4</li></ul>');
      final matches = queryAll(doc, 'li:nth-child(-n+3)');
      expect(matches.map((e) => e.text), ['1', '2', '3']);
    });

    test('Zero a: 0n+3', () {
      final doc =
          parseHTML('<ul><li>1</li><li>2</li><li>3</li><li>4</li></ul>');
      final matches = queryAll(doc, 'li:nth-child(0n+3)');
      expect(matches.map((e) => e.text), ['3']);
    });
  });
}
