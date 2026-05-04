import 'package:cascadia/cascadia.dart';
import 'package:html/parser.dart' as html_parser;

/// Demonstrates basic Cascadia selector usage.
///
/// This example works in pure Dart and in Flutter apps.
void main() {
  final htmlString = '''
    <!DOCTYPE html>
    <html>
      <head><title>Example Page</title></head>
      <body>
        <div class="container">
          <h1>Welcome</h1>
          <p class="intro">This is an introduction.</p>
          <p>Regular paragraph.</p>
          <ul>
            <li class="item">Item 1</li>
            <li class="item special">Item 2 (special)</li>
            <li>Item 3</li>
          </ul>
          <a href="https://example.com" class="external">External Link</a>
          <a href="/page" class="internal">Internal Link</a>
          <input type="text" disabled />
          <input type="checkbox" checked />
        </div>
      </body>
    </html>
  ''';

  // Parse the HTML document
  final doc = html_parser.parse(htmlString);

  print('=== Cascadia Selector Demo ===\n');

  // 1. Basic type selector
  final allParagraphs = queryAll(doc, 'p');
  print('1. All paragraphs: ${allParagraphs.length}'); // 2

  // 2. Class selector
  final intros = queryAll(doc, '.intro');
  print('2. Intro elements: ${intros.length}'); // 1

  // 3. Descendant combinator
  final listItems = queryAll(doc, 'ul li');
  print('3. List items: ${listItems.length}'); // 3

  // 4. Child combinator
  final directChildren = queryAll(doc, 'ul > li');
  print('4. Direct li children of ul: ${directChildren.length}'); // 3

  // 5. Attribute selector
  final hrefs = queryAll(doc, 'a[href]');
  print('5. Links with href: ${hrefs.length}'); // 2

  // 6. Pseudo-class :first-child
  final firstChild = query(doc, 'li:first-child');
  print('6. First li: ${firstChild?.text}'); // Item 1

  // 7. Pseudo-class :nth-child(odd/even)
  final oddItems = queryAll(doc, 'li:nth-child(odd)');
  print('7. Odd-positioned li items: ${oddItems.length}'); // 2

  // 8. Pseudo-class :last-of-type
  final lastP = query(doc, 'p:last-of-type');
  print('8. Last paragraph: ${lastP?.text}'); // Regular paragraph

  // 9. Pseudo-class :not()
  final notDisabled = queryAll(doc, 'input:not([disabled])');
  print('9. Enabled inputs: ${notDisabled.length}'); // 1 (checkbox)

  // 10. Pseudo-class :checked
  final checked = query(doc, 'input:checked');
  print('10. Checked input: ${checked?.attributes['type']}'); // checkbox

  // 11. Compound selector
  final specialItem = query(doc, 'li.item.special');
  print('11. Special item: ${specialItem?.text}'); // Item 2 (special)

  // 12. Multiple selectors (list)
  final headings = queryAll(doc, 'h1, h2, h3');
  print('12. Headings: ${headings.length}'); // 1

  // 13. Serialization round-trip
  final selector = parse('div.container > p.intro');
  final serialized = serialize(selector);
  print('13. Serialized: $serialized'); // div.container > p.intro

  // 14. Specificity
  final highSpecificity = parse('div#main.content[data-role="main"]');
  print('14. Specificity: ${highSpecificity.specificity}'); // (1,2,1)

  // 15. Pseudo-element with parseWithPseudoElements
  final withPseudo = parseWithPseudoElements('p::first-letter');
  print('15. Pseudo-element: $withPseudo'); // p::first-letter

  print('\n=== Demo Complete ===');
}
