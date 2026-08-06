// Behavioural coverage for the pseudo-class modules.
//
// The audit found that a green suite proves nothing if it never exercises the
// code. These tests target the modules the coverage report showed were
// largely untested: shadow.dart, forms.dart, state.dart and elements.dart.
import 'package:cascadia/cascadia.dart';
// `matches` collides with package:matcher's string matcher, so the library's
// version is reached through a prefix here.
import 'package:cascadia/cascadia.dart' as cascadia show matches;
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:test/test.dart';

Document doc(String html) => html_parser.parse(html);
Element el(Document d, String selector) => query(d, selector)!;

void main() {
  group('shadow DOM pseudo-classes', () {
    test(':host matches only the scope element', () {
      final d = doc('<my-card><p>x</p></my-card>');
      final host = el(d, 'my-card');
      final ctx = MatchContext(scope: host);
      expect(parse(':host').matchWith(host, ctx), isTrue);
      expect(parse(':host').matchWith(el(d, 'p'), ctx), isFalse);
    });

    test(':host without a scope does not match', () {
      final d = doc('<my-card></my-card>');
      expect(parse(':host').match(el(d, 'my-card')), isFalse);
    });

    test(':host(selector) filters the host', () {
      final d = doc('<my-card class="a"></my-card>');
      final host = el(d, 'my-card');
      final ctx = MatchContext(scope: host);
      expect(parse(':host(.a)').matchWith(host, ctx), isTrue);
      expect(parse(':host(.b)').matchWith(host, ctx), isFalse);
    });

    test(':host-context matches on an ancestor', () {
      final d = doc('<div class="dark"><my-card></my-card></div>');
      final host = el(d, 'my-card');
      final ctx = MatchContext(scope: host);
      expect(parse(':host-context(.dark)').matchWith(host, ctx), isTrue);
      expect(parse(':host-context(.light)').matchWith(host, ctx), isFalse);
    });

    test(':has-slotted matches a slot with content', () {
      final d = doc('<slot><span>fallback</span></slot><slot></slot>');
      final slots = queryAll(d, 'slot');
      expect(parse(':has-slotted').match(slots[0]), isTrue);
      expect(parse(':has-slotted').match(slots[1]), isFalse);
      expect(parse(':has-slotted(span)').match(slots[0]), isTrue);
      expect(parse(':has-slotted(div)').match(slots[0]), isFalse);
    });

    test('shadow selectors report their specificity', () {
      expect(parse(':host').specificity, Specificity(0, 1, 0));
      expect(parse(':host(.a)').specificity, Specificity(0, 2, 0));
      expect(parse(':host-context(#x)').specificity, Specificity(1, 1, 0));
    });

    test('strict mode throws without a scope', () {
      final d = doc('<my-card></my-card>');
      expect(
          () => parse(':host')
              .matchWith(el(d, 'my-card'), MatchContext.strictEmpty),
          throwsA(isA<UndecidableSelectorError>()));
    });
  });

  group('form pseudo-classes', () {
    test(':disabled and :enabled on each control type', () {
      final d = doc('<form><button></button><input><select></select>'
          '<textarea></textarea><option></option>'
          '<button disabled></button><input disabled></form>');
      expect(queryAll(d, ':enabled').length, greaterThanOrEqualTo(4));
      expect(queryAll(d, ':disabled'), hasLength(2));
    });

    test('a disabled fieldset exempts its first legend', () {
      final d = doc('<fieldset disabled>'
          '<legend><input id="a"></legend>'
          '<input id="b">'
          '</fieldset>');
      expect(parse(':disabled').match(el(d, '#a')), isFalse);
      expect(parse(':disabled').match(el(d, '#b')), isTrue);
    });

    test(':checked covers checkbox, radio and option', () {
      final d = doc('<input type="checkbox" checked id="c">'
          '<input type="radio" checked id="r">'
          '<input type="text" id="t">'
          '<select><option selected id="o"></option></select>');
      expect(parse(':checked').match(el(d, '#c')), isTrue);
      expect(parse(':checked').match(el(d, '#r')), isTrue);
      expect(parse(':checked').match(el(d, '#t')), isFalse);
      expect(parse(':checked').match(el(d, '#o')), isTrue);
    });

    test(':default finds the first submit control in a form', () {
      final d = doc('<form><input type="text"><button id="s1">a</button>'
          '<button id="s2">b</button></form>');
      expect(parse(':default').match(el(d, '#s1')), isTrue);
      expect(parse(':default').match(el(d, '#s2')), isFalse);
    });

    test(':read-only and :read-write', () {
      final d = doc('<input id="a"><input id="b" readonly>'
          '<textarea id="c"></textarea><p id="d">x</p>'
          '<div id="e" contenteditable="true"></div>');
      expect(parse(':read-write').match(el(d, '#a')), isTrue);
      expect(parse(':read-only').match(el(d, '#b')), isTrue);
      expect(parse(':read-write').match(el(d, '#c')), isTrue);
      expect(parse(':read-only').match(el(d, '#d')), isTrue);
      expect(parse(':read-write').match(el(d, '#e')), isTrue);
    });

    test(':read-only for non-editable input types', () {
      final d = doc('<input type="checkbox" id="a"><input type="hidden" id="b">'
          '<input type="range" id="c">');
      for (final id in ['#a', '#b', '#c']) {
        expect(parse(':read-only').match(el(d, id)), isTrue, reason: id);
      }
    });

    test(':placeholder-shown requires an empty value', () {
      final d = doc('<input placeholder="p" id="a">'
          '<input placeholder="p" value="v" id="b">'
          '<input id="c"><textarea placeholder="p" id="d"></textarea>');
      expect(parse(':placeholder-shown').match(el(d, '#a')), isTrue);
      expect(parse(':placeholder-shown').match(el(d, '#b')), isFalse);
      expect(parse(':placeholder-shown').match(el(d, '#c')), isFalse);
      expect(parse(':placeholder-shown').match(el(d, '#d')), isTrue);
    });

    test(':indeterminate for an unchecked radio group', () {
      final unchecked = doc('<input type="radio" name="g" id="a">'
          '<input type="radio" name="g" id="b">');
      expect(parse(':indeterminate').match(el(unchecked, '#a')), isTrue);

      final checked = doc('<input type="radio" name="g" id="a" checked>'
          '<input type="radio" name="g" id="b">');
      expect(parse(':indeterminate').match(el(checked, '#b')), isFalse);
    });

    test(':indeterminate honours the context set', () {
      final d = doc('<input type="checkbox" id="a">');
      final target = el(d, '#a');
      expect(
          parse(':indeterminate')
              .matchWith(target, MatchContext(indeterminate: {target})),
          isTrue);
    });
  });

  group('state and link pseudo-classes', () {
    test(':link and :any-link', () {
      final d =
          doc('<a href="/x">a</a><a>b</a><area href="/y"><link href="z">');
      expect(queryAll(d, ':any-link'), hasLength(3));
      expect(queryAll(d, ':link'), hasLength(3));
    });

    test(':local-link compares origin and path', () {
      final d = doc('<a href="/page" id="a">x</a>'
          '<a href="/other" id="b">y</a>'
          '<a href="https://elsewhere.test/page" id="c">z</a>');
      final ctx = MatchContext(currentUrl: Uri.parse('https://x.test/page'));
      expect(parse(':local-link').matchWith(el(d, '#a'), ctx), isTrue);
      expect(parse(':local-link').matchWith(el(d, '#b'), ctx), isFalse);
      expect(parse(':local-link').matchWith(el(d, '#c'), ctx), isFalse);
    });

    test(':target via an explicit element and via the URL', () {
      final d = doc('<div id="one"></div><div id="two"></div>');
      final two = el(d, '#two');
      expect(
          parse(':target').matchWith(two, MatchContext(target: two)), isTrue);
      expect(
          parse(':target')
              .matchWith(two, MatchContext(currentUrl: Uri.parse('p#two'))),
          isTrue);
    });

    test(':target-within matches an ancestor of the target', () {
      final d = doc('<section id="s"><p id="t">x</p></section>');
      final ctx = MatchContext(target: el(d, '#t'));
      expect(parse(':target-within').matchWith(el(d, '#s'), ctx), isTrue);
      expect(parse(':target-within').matchWith(el(d, '#t'), ctx), isTrue);
    });

    test(':scope matches the reference element', () {
      final d = doc('<div id="a"><p id="b"></p></div>');
      final a = el(d, '#a');
      expect(parse(':scope').matchWith(a, MatchContext(scope: a)), isTrue);
      expect(parse(':scope').matchWith(el(d, '#b'), MatchContext(scope: a)),
          isFalse);
    });

    test(':active and :focus-within propagate to ancestors', () {
      final d = doc('<div id="outer"><button id="inner">x</button></div>');
      final inner = el(d, '#inner');
      expect(
          parse(':active')
              .matchWith(el(d, '#outer'), MatchContext(active: inner)),
          isTrue);
      expect(
          parse(':focus-within')
              .matchWith(el(d, '#outer'), MatchContext(focused: inner)),
          isTrue);
    });

    test(':focus-visible respects the context flag', () {
      final d = doc('<input id="a">');
      final a = el(d, '#a');
      expect(
          parse(':focus-visible')
              .matchWith(a, MatchContext(focused: a, focusVisible: true)),
          isTrue);
      expect(
          parse(':focus-visible')
              .matchWith(a, MatchContext(focused: a, focusVisible: false)),
          isFalse);
    });

    test(':modal, :fullscreen and :popover-open', () {
      final d = doc('<dialog open modal id="m"></dialog>'
          '<dialog open id="d"></dialog>'
          '<div popover id="p"></div>');
      expect(parse(':modal').match(el(d, '#m')), isTrue);
      expect(parse(':modal').match(el(d, '#d')), isFalse);

      final p = el(d, '#p');
      expect(parse(':popover-open').match(p), isFalse);
      expect(
          parse(':popover-open').matchWith(p, MatchContext(openPopovers: {p})),
          isTrue);

      final m = el(d, '#m');
      expect(parse(':fullscreen').matchWith(m, MatchContext(fullscreen: {m})),
          isTrue);
    });

    test(':defined distinguishes built-ins from custom elements', () {
      final d = doc('<div id="a"></div><my-el id="b"></my-el>');
      expect(parse(':defined').match(el(d, '#a')), isTrue);
      expect(parse(':defined').match(el(d, '#b')), isFalse);
      expect(
          parse(':defined')
              .matchWith(el(d, '#b'), MatchContext(definedElements: {'my-el'})),
          isTrue);
    });

    test(':state reads the context map', () {
      final d = doc('<my-el id="a"></my-el>');
      final a = el(d, '#a');
      expect(
          parse(':state(ready)').matchWith(
              a,
              MatchContext(customStates: {
                a: {'ready'}
              })),
          isTrue);
      expect(
          parse(':state(busy)').matchWith(
              a,
              MatchContext(customStates: {
                a: {'ready'}
              })),
          isFalse);
    });

    test(':lang inherits and supports wildcards', () {
      final d = doc('<div lang="en-GB"><p id="a">x</p></div>'
          '<div lang="fr"><p id="b">y</p></div>');
      expect(parse(':lang(en)').match(el(d, '#a')), isTrue);
      expect(parse(':lang(en-GB)').match(el(d, '#a')), isTrue);
      expect(parse(':lang(fr)').match(el(d, '#a')), isFalse);
      expect(parse(':lang(fr)').match(el(d, '#b')), isTrue);
    });

    test(':dir stops at dir=auto and defaults to ltr', () {
      final d = doc('<div dir="rtl"><span dir="auto"><i id="a">x</i></span>'
          '</div><p id="b">y</p>');
      expect(parse(':dir(ltr)').match(el(d, '#a')), isTrue);
      expect(parse(':dir(ltr)').match(el(d, '#b')), isTrue);
    });

    test('media state pseudo-classes', () {
      final d = doc('<video id="a" muted></video>'
          '<video id="b" autoplay></video><video id="c"></video>'
          '<div id="d"></div>');
      expect(parse(':muted').match(el(d, '#a')), isTrue);
      expect(parse(':playing').match(el(d, '#b')), isTrue);
      expect(parse(':paused').match(el(d, '#c')), isTrue);
      expect(parse(':muted').match(el(d, '#d')), isFalse);
      expect(parse(':muted').support, MatchSupport.decidable);
      expect(parse(':seeking').support, MatchSupport.requiresContext);
    });

    test(':input matches all form controls', () {
      final d = doc('<input><select></select><textarea></textarea>'
          '<button></button><div></div>');
      expect(queryAll(d, ':input'), hasLength(4));
    });
  });

  group('pseudo-elements', () {
    test('functional pseudo-elements carry their argument', () {
      final sel = parseWithPseudoElements('::part(header)');
      expect(sel.pseudoElement, 'part(header)');
      expect(sel.toString(), '::part(header)');
    });

    test('arity is validated', () {
      expect(() => parseWithPseudoElements('::part'), throwsFormatException);
      expect(
          () => parseWithPseudoElements('::before(x)'), throwsFormatException);
      expect(
          () => parseWithPseudoElements('::nonsense'), throwsFormatException);
    });

    test('legacy single-colon forms are accepted', () {
      for (final css in [':before', ':after', ':first-line', ':first-letter']) {
        final sel = parseWithPseudoElements('p$css');
        expect(sel.pseudoElement, css.substring(1), reason: css);
      }
    });

    test('the nesting selector reports its needs', () {
      final sel = parse('&');
      expect(sel.support, MatchSupport.requiresContext);
      expect(sel.specificity, Specificity.zero);
      expect(sel.toString(), '&');
    });

    test('the nesting selector matches the scope', () {
      final d = doc('<div id="a"><p id="b"></p></div>');
      final a = el(d, '#a');
      expect(parse('&').matchWith(a, MatchContext(scope: a)), isTrue);
      expect(
          parse('&').matchWith(el(d, '#b'), MatchContext(scope: a)), isFalse);
    });
  });

  group('undecidable selectors', () {
    test('each reports itself and never matches silently', () {
      const cases = [
        ':buffering',
        ':seeking',
        ':stalled',
        ':volume-locked',
        ':current',
        ':past',
        ':future',
        ':left',
        ':right',
        ':first',
        ':in-range',
        ':out-of-range',
        ':valid',
        ':invalid',
        ':user-valid',
        ':user-invalid',
        ':blank',
        ':autofill',
        ':picture-in-picture',
        ':xr-overlay',
      ];
      final e = Element.tag('input');
      for (final css in cases) {
        final sel = parse(css);
        expect(sel.support, MatchSupport.requiresContext, reason: css);
        expect(sel.undecidableParts, contains(css), reason: css);
        expect(sel.match(e), isFalse, reason: css);
        expect(() => sel.matchWith(e, MatchContext.strictEmpty),
            throwsA(isA<UndecidableSelectorError>()),
            reason: css);
      }
    });

    test('the error message names the selector and the reason', () {
      try {
        parse(':valid')
            .matchWith(Element.tag('input'), MatchContext.strictEmpty);
        fail('expected a throw');
      } on UndecidableSelectorError catch (e) {
        expect(e.selector, ':valid');
        expect(e.reason, isNotEmpty);
        expect(e.toString(), contains(':valid'));
        expect(e.toString(), contains('MatchContext'));
      }
    });

    test('undecidability propagates through combinators and groups', () {
      expect(parse('div a:hover').support, MatchSupport.requiresContext);
      expect(parse('div a:hover').undecidableParts, {':hover'});
      expect(parse('div, a:hover').undecidableParts, {':hover'});
      expect(parse(':not(:hover)').undecidableParts, {':hover'});
      expect(parse('div > p').support, MatchSupport.decidable);
    });
  });

  group('API surface', () {
    test('compile and matches work on strings', () {
      final d = doc('<div class="a"></div>');
      final isA = compile('.a');
      expect(isA(el(d, 'div')), isTrue);
      expect(cascadia.matches(el(d, 'div'), '.a'), isTrue);
      expect(cascadia.matches(el(d, 'div'), '.b'), isFalse);
    });

    test('asFunctionWith binds a context', () {
      final d = doc('<a href="/x" id="a">l</a>');
      final a = el(d, '#a');
      final fn = parse(':hover').asFunctionWith(MatchContext(hovered: a));
      expect(fn(a), isTrue);
    });

    test('parseGroup and serialize round-trip a list', () {
      final sel = parseGroup('h1, h2, .x');
      expect(serialize(sel), 'h1, h2, .x');
      expect(sel.specificity, Specificity(0, 1, 0));
    });

    test('the cache returns equivalent selectors', () {
      clearSelectorCache();
      expect(selectorCacheSize, 0);
      final a = parse('div.x');
      final b = parse('div.x');
      expect(identical(a, b), isTrue);
      expect(selectorCacheSize, 1);
      clearSelectorCache();
      expect(selectorCacheSize, 0);
    });

    test('specificity comparison operators', () {
      const low = Specificity(0, 0, 1);
      const high = Specificity(1, 0, 0);
      expect(low < high, isTrue);
      expect(high > low, isTrue);
      expect(low <= low, isTrue);
      expect(high >= low, isTrue);
      expect(low.compareTo(low), 0);
      expect(low.hashCode, Specificity(0, 0, 1).hashCode);
    });
  });

  group('logical pseudo-class edge cases', () {
    test(':is/:where/:not propagate support and parts', () {
      expect(parse(':is(:hover, .a)').support, MatchSupport.requiresContext);
      expect(parse(':where(:focus)').undecidableParts, {':focus'});
      expect(parse(':where(:focus)').specificity, Specificity.zero);
      expect(parse(':haschild(:hover)').undecidableParts, {':hover'});
    });

    test(':has reports support from its relative arguments', () {
      expect(parse(':has(> :hover)').support, MatchSupport.requiresContext);
      expect(parse(':has(> p)').support, MatchSupport.decidable);
      expect(parse(':has(.a, > .b)').toString(), ':has(.a, > .b)');
    });

    test(':haschild only looks one level down', () {
      final d = doc('<div id="a"><p>x</p></div>'
          '<div id="b"><span><p>y</p></span></div>');
      expect(queryAll(d, 'div:haschild(p)').map((e) => e.id), ['a']);
    });

    test(':contains and :containsown differ on descendants', () {
      final d = doc('<div id="a">plain</div>'
          '<div id="b"><span>nested</span></div>');
      expect(
          queryAll(d, ':contains("nested")').map((e) => e.id), contains('b'));
      expect(queryAll(d, 'div:containsown("nested")'), isEmpty);
      expect(queryAll(d, 'div:containsown("plain")').map((e) => e.id), ['a']);
    });

    test(':contains is case-insensitive; :matches respects flags', () {
      final d = doc('<p>HeLLo</p>');
      expect(queryAll(d, 'p:contains("hello")'), hasLength(1));
      expect(queryAll(d, 'p:matches(/hello/)'), isEmpty);
      expect(queryAll(d, 'p:matches(/hello/i)'), hasLength(1));
    });

    test(':matchesown ignores descendant text', () {
      final d = doc('<div id="a"><span>abc</span></div>');
      expect(queryAll(d, 'div:matches(/abc/)').map((e) => e.id), ['a']);
      expect(queryAll(d, 'div:matchesown(/abc/)'), isEmpty);
    });

    test('logical selectors serialize their arguments', () {
      for (final css in [
        ':not(.a)',
        ':is(h1, h2)',
        ':where(.a)',
        ':has(> p)',
        ':haschild(p)',
        ':contains("x")',
        ':matchesown(/x/i)',
      ]) {
        expect(parse(css).toString(), parse(parse(css).toString()).toString(),
            reason: css);
      }
    });
  });

  group('structural edge cases', () {
    test('nth against an element with no parent', () {
      final orphan = Element.tag('li');
      expect(parse(':first-child').match(orphan), isFalse);
      expect(parse(':only-child').match(orphan), isFalse);
      expect(parse(':nth-child(1)').match(orphan), isFalse);
    });

    test('nth-last variants count from the end', () {
      final d = doc('<ul><li>1</li><li>2</li><li>3</li><li>4</li></ul>');
      expect(queryAll(d, 'li:nth-last-child(1)').map((e) => e.text), ['4']);
      expect(
          queryAll(d, 'li:nth-last-child(2n)').map((e) => e.text), ['1', '3']);
      expect(queryAll(d, 'li:nth-last-of-type(2)').map((e) => e.text), ['3']);
    });

    test('negative and zero coefficients', () {
      final d = doc('<ul><li>1</li><li>2</li><li>3</li><li>4</li></ul>');
      expect(queryAll(d, 'li:nth-child(-n+2)').map((e) => e.text), ['1', '2']);
      expect(queryAll(d, 'li:nth-child(0n+2)').map((e) => e.text), ['2']);
      expect(queryAll(d, 'li:nth-child(-1n+1)').map((e) => e.text), ['1']);
    });

    test(':heading with and without a formula', () {
      final d = doc('<div><h1>a</h1><p>x</p><h2>b</h2><h3>c</h3></div>');
      expect(queryAll(d, ':heading'), hasLength(3));
      expect(queryAll(d, ':heading(1)').map((e) => e.text), ['a']);
      expect(queryAll(d, ':heading(2n)').map((e) => e.text), ['b']);
      expect(parse(':heading').toString(), ':heading');
      expect(parse(':heading(2n+1)').toString(), ':heading(2n+1)');
    });

    test(':heading does not match non-headings', () {
      expect(queryAll(doc('<p>x</p>'), ':heading'), isEmpty);
    });

    test(':only-of-type counts only matching tags', () {
      final d = doc('<div><p id="a">1</p><span>2</span><span>3</span></div>');
      expect(queryAll(d, ':only-of-type').map((e) => e.id), contains('a'));
    });

    test(':empty treats whitespace and comments as empty', () {
      final d = doc('<div id="a"></div><div id="b">   </div>'
          '<div id="c"><!--x--></div><div id="d">t</div>');
      final ids = queryAll(d, 'div:empty').map((e) => e.id).toList();
      expect(ids, containsAll(['a', 'b', 'c']));
      expect(ids, isNot(contains('d')));
    });
  });

  group('DOM traversal helpers', () {
    test('sibling getters', () {
      final d = doc('<ul><li id="a">1</li><li id="b">2</li>'
          '<li id="c">3</li></ul>');
      final b = el(d, '#b');
      expect(b.previousElementSibling?.id, 'a');
      expect(b.nextElementSibling?.id, 'c');
      expect(el(d, '#a').previousElementSibling, isNull);
      expect(el(d, '#c').nextElementSibling, isNull);
    });

    test('sibling getters skip non-element nodes', () {
      final d = doc('<ul><li id="a">1</li><!--c--> text '
          '<li id="b">2</li></ul>');
      expect(el(d, '#b').previousElementSibling?.id, 'a');
      expect(el(d, '#a').nextElementSibling?.id, 'b');
    });

    test('tagName is lowercased', () {
      expect(el(doc('<DIV></DIV>'), 'div').tagName, 'div');
    });
  });
}
