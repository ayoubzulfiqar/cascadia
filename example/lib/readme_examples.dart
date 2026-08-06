// ignore_for_file: avoid_print
// Compile-checked copies of the README's code samples.
//
// Audit P3-1: the README's headline example did not compile. These live in
// example/ so `dart analyze` fails CI if the documentation drifts again.
import 'package:cascadia/cascadia.dart';
import 'package:html/parser.dart' as html;

void basicQueries() {
  final doc = html.parse('''
    <div class="container">
      <p class="intro">Hello</p>
      <p>World</p>
      <ul>
        <li>Item 1</li>
        <li>Item 2</li>
      </ul>
    </div>
  ''');

  final intros = queryAll(doc, 'p.intro');
  print('Found ${intros.length} matching nodes');

  final first = query(doc, 'li');
  print('First item: ${first?.text}');

  final isListItem = compile('li');
  final allLis = doc.querySelectorAll('*').where(isListItem);
  print('List items: ${allLis.length}');
}

void pseudoElements() {
  final sel = parseWithPseudoElements('p::first-letter');
  print(sel.pseudoElement); // first-letter
}

void combinators() {
  final doc = html.parse('<div><p>a</p></div><ul><li>b</li></ul>');
  print(queryAll(doc, 'div p').length);
  print(queryAll(doc, 'ul > li').length);
  print(queryAll(doc, 'h1 + p').length);
  print(queryAll(doc, 'h1 ~ p').length);
}

void specificityAndSerialization() {
  print(parse('div.foo#bar[href]').specificity); // [1, 2, 1]
  print(parse(':where(.a, .b)').specificity); // [0, 0, 0]
  print(serialize(parse('div.foo > p'))); // div.foo > p
}

void namespaces() {
  final doc = html.parse('<svg><rect/></svg>');
  print(queryAll(doc, 'svg|rect').length); // 1
  print(parse('*|a')); // *|a
}

void runtimeContext() {
  final doc = html.parse('<a href="/seen">a</a><a href="/new">b</a>');
  final ctx = MatchContext(
    currentUrl: Uri.parse('https://example.com/page'),
    visitedUrls: {'https://example.com/seen'},
  );
  print(queryAll(doc, 'a:visited', ctx).length); // 1

  // Inspect what a selector needs before trusting its result.
  final sel = parse('a:hover');
  print(sel.support); // MatchSupport.requiresContext
  print(sel.undecidableParts); // {:hover}
}

void flutterUsage() {
  final document = html.parse('<article class="post"><h2>T</h2></article>');
  final posts = queryAll(document, 'article.post');
  for (final el in posts) {
    print(el.querySelector('h2')?.text ?? '');
  }
}

void main() {
  basicQueries();
  pseudoElements();
  combinators();
  specificityAndSerialization();
  namespaces();
  runtimeContext();
  flutterUsage();
}
