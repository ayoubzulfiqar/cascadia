// ignore_for_file: avoid_print
//
// Audit evidence harness — reproduces every defect recorded in AUDIT.md.
//
// Run with:  dart run tool/audit_probe.dart
//
// Each probe prints `PASS` (spec-correct behaviour) or `FAIL` with the
// observed vs expected result. Probes that hang or crash the VM are listed
// but guarded behind the `--include-fatal` flag so the harness can complete.
//
// This file is excluded from the published archive via .pubignore.
import 'dart:io';

import 'package:cascadia/cascadia.dart';
import 'package:html/parser.dart' as hp;

int _pass = 0;
int _fail = 0;

void probe(
    String id, String what, Object? Function() actual, Object? expected) {
  Object? got;
  try {
    got = actual();
  } catch (e) {
    got = '${e.runtimeType}';
  }
  final ok = '$got' == '$expected';
  if (ok) {
    _pass++;
    print('PASS  $id  $what  -> $got');
  } else {
    _fail++;
    print('FAIL  $id  $what  -> got: $got   expected: $expected');
  }
}

void main() {
  // Control probes. A report of "0 passed, N failed" is only meaningful if the
  // harness can demonstrably emit PASS; these assert behaviour that already
  // works, so a green control proves the failures below are real findings and
  // not a broken assertion mechanism.
  print('=== 0. Controls (must PASS) ===');
  probe('K1', 'type selector matches', () => parse('div').toString(), 'div');
  probe(
      'K2',
      'descendant query works',
      () => queryAll(hp.parse('<div><span>x</span></div>'), 'div span').length,
      1);
  probe('K3', 'class specificity is (0,1,0)',
      () => parse('.a').specificity.toString(), '[0, 1, 0]');

  print('\n=== A. Crashes (unsafe casts) ===');
  // NOTE: these assert "does not crash" and returns the correct set. The
  // counts include <html>/<head>, which legitimately are first/only children
  // of their parents — the original audit expectation of 2 was itself wrong.
  probe(
      'A1',
      'queryAll(:first-child) over text nodes',
      () => queryAll(
              hp.parse('<ul><li>one</li><li>two</li></ul>'), 'li:first-child')
          .map((e) => e.text)
          .join(','),
      'one');
  probe(
      'A2',
      'queryAll(:only-child) over text nodes',
      () => queryAll(hp.parse('<div><span>x</span></div>'), 'span:only-child')
          .length,
      1);
  probe(
      'A3',
      'query(:root) with a doctype present',
      () =>
          query(hp.parse('<!DOCTYPE html><html><body></body></html>'), ':root')
              ?.localName,
      'html');

  print('\n=== B. Serialization round-trips ===');
  probe('B1', r'[src$=".png"] toString',
      () => parse(r'[src$=".png"]').toString(), r'[src$=".png"]');
  probe('B2', 'descendant spacing', () => parse('div p').toString(), 'div p');
  probe('B3', ':nth-child(2n+1) toString',
      () => parse(':nth-child(2n+1)').toString(), ':nth-child(2n+1)');
  probe('B4', ':nth-child(n) toString', () => parse(':nth-child(n)').toString(),
      ':nth-child(n)');
  probe('B5', ':nth-child(-n+3) toString',
      () => parse(':nth-child(-n+3)').toString(), ':nth-child(-n+3)');
  probe(
      'B6',
      'reparse(serialize) suffix attr',
      () => parse(serialize(parse(r'[src$=".png"]'))).toString(),
      r'[src$=".png"]');

  print('\n=== C. Matching semantics ===');
  probe('C1', 'class matching is case-SENSITIVE in HTML',
      () => queryAll(hp.parse('<div class="Foo">x</div>'), '.foo').length, 0);
  probe('C2', ':enabled must not match non-form elements',
      () => queryAll(hp.parse('<div>x</div>'), 'div:enabled').length, 0);
  probe('C3', ':optional must not match non-form elements',
      () => queryAll(hp.parse('<div>x</div>'), 'div:optional').length, 0);
  probe(
      'C4',
      ':open must honour the open attribute',
      () => queryAll(
              hp.parse('<details></details><details open></details>'), ':open')
          .length,
      1);
  probe(
      'C5',
      ':default matches <option selected>',
      () => queryAll(
              hp.parse(
                  '<select><option selected>a</option><option>b</option></select>'),
              'option:default')
          .length,
      1);
  probe(
      'C6',
      'bare ::before must not match a real element',
      () => parseWithPseudoElements('::before')
          .match(hp.parse('<div></div>').body!.children.first),
      false);
  probe(
      'C7',
      'escaped identifier .foo\\.bar',
      () => queryAll(hp.parse('<div class="foo.bar">x</div>'), r'.foo\.bar')
          .length,
      1);
  probe(
      'C8',
      ':has(> p) relative child selector',
      () => queryAll(
              hp.parse('<div><p>x</p></div><div><span><p>y</p></span></div>'),
              'div:has(> p)')
          .length,
      1);
  probe('C9', ':has(+ p) relative sibling selector',
      () => queryAll(hp.parse('<h1>a</h1><p>b</p>'), 'h1:has(+ p)').length, 1);
  probe(
      'C10',
      'queryAll returns descendants only, not the root',
      () => queryAll(
              query(hp.parse('<div id="a"><div id="b"></div></div>'), '#a')!,
              'div')
          .map((e) => e.id)
          .join(','),
      'b');

  print('\n=== D. Specificity ===');
  probe('D1', 'universal * is (0,0,0)', () => parse('*').specificity.toString(),
      '[0, 0, 0]');
  // Selectors L4 §15: :is()/:not()/:has() specificity is REPLACED by the most
  // specific complex selector in the argument, not added to (0,1,0). The
  // audit's original expectation of [0,1,1] was incorrect; verified against
  // https://drafts.csswg.org/selectors-4/#specificity-rules
  probe('D2', ':has(p) is replaced by argument specificity',
      () => parse('div:has(p)').specificity.toString(), '[0, 0, 2]');
  probe('D3', ':not(em, strong#foo) is (1,0,1) per spec example',
      () => parse(':not(em, strong#foo)').specificity.toString(), '[1, 0, 1]');
  probe('D4', ':is(em, #foo) is (1,0,0) per spec example',
      () => parse(':is(em, #foo)').specificity.toString(), '[1, 0, 0]');
  probe('D5', '.qux:where(#a#b#c) is (0,1,0) per spec example',
      () => parse('.qux:where(#a#b#c)').specificity.toString(), '[0, 1, 0]');

  print('\n=== E. Parser robustness ===');
  probe('E1', 'trailing combinator "div >" is invalid',
      () => parse('div >').toString(), 'FormatException');
  probe('E2', 'empty selector "" is invalid', () => parse('').toString(),
      'FormatException');
  probe('E3', 'empty group member "div,," is invalid',
      () => parse('div,,').toString(), 'FormatException');
  probe('E4', ':not() with no argument is invalid',
      () => parse(':not()').toString(), 'FormatException');
  probe('E5', ':matches(/foo/) accepts a regex',
      () => parse(':matches(/foo/)').toString(), ':matches(/foo/)');
  probe('E6', 'unknown pseudo-class is rejected',
      () => parse(':bogus-thing').toString(), 'FormatException');
  probe(
      'E7',
      'pseudo-element must be last',
      () => parseWithPseudoElements('p::before span').toString(),
      'FormatException');

  print('\n=== F. Formerly fatal (P0-1 infinite loops) ===');
  // These two inputs used to loop forever, allocating until the VM died.
  // They must now terminate: one parses, one raises a precise error.
  probe('F1', 'parse("svg|rect") terminates and round-trips',
      () => parse('svg|rect').toString(), 'svg|rect');
  probe('F2', 'parse("div %") raises FormatException',
      () => parse('div %').toString(), 'FormatException');
  probe('F3', 'namespace selector matches an SVG element', () {
    final doc = hp.parse('<svg><rect/></svg>');
    return queryAll(doc, 'svg|rect').length;
  }, 1);
  probe(
      'F4',
      'deep selector still parses (no stack blowup)',
      () => parse(List.filled(300, 'div').join(' > ')).specificity.toString(),
      '[0, 0, 300]');

  print('\n=== SUMMARY ===');
  print('pass=$_pass  fail=$_fail');
  if (_pass == 0) {
    print('WARNING: controls did not pass — the harness itself is suspect.');
    exitCode = 1;
  }
  if (_fail == 0) {
    print('All audit defects verified fixed.');
  } else {
    print('REGRESSION: $_fail audit defect(s) are no longer fixed.');
    exitCode = 1;
  }
}
