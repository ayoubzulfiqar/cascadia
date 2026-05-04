# Cascadia Dart

[![Flutter Compatible](https://img.shields.io/badge/Flutter-Compatible-blue.svg)](https://flutter.dev)
[![Pub Package](https://img.shields.io/pub/v/cascadia.svg)](https://pub.dev/packages/cascadia)

A Dart implementation of the CSS Selector Library, Writte and Extended with **Full CSS Selectors Level 3, Level 4, and beyond** coverage per the [MDN Web Docs](https://developer.mozilla.org/en-US/docs/Web/CSS).

**Flutter-Compatible** — works in Dart VM, browsers, and Flutter apps. No browser-specific APIs; pure Dart.

## Features

- **Complete CSS Selector Support** — 60+ selectors, 70+ pseudo-classes, and 25+ pseudo-elements from MDN
- **Full parsing** with robust error handling
- **Selector matching** against DOM trees (package:html)
- **Specificity calculation** per CSS Selectors spec
- **Serialization** back to CSS string representation
- **Combinators** — descendant, child, adjacent sibling, general sibling, namespace
- **Pseudo-elements** via `parseWithPseudoElements()`
- **Nesting selector** (`&`) for CSS Nesting Module
- **Shadow DOM** selectors (`:host`, `:host()`, `:host-context()`, `:has-slotted()`, `::slotted()`, `::part()`)
- **View Transitions** pseudo-classes and pseudo-elements
- **Container Queries** and scoping selectors
- **Anchor Positioning** pseudo-classes
- **Media state** pseudo-classes (:playing, :paused, :muted, etc.)
- **Text-content** selectors (`:contains()`, `:containsown()`, `:matches()`)
- **Form validation** pseudo-classes
- All with null safety and Dart best practices

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  cascadia: ^0.6.9
```

## Usage

### Basic Queries

```dart
import 'package:cascadia/cascadia.dart';
import 'package:html/parser.dart';

void main() {
  final html = '''
    <div class="container">
      <p class="intro">Hello</p>
      <p>World</p>
      <ul>
        <li>Item 1</li>
        <li>Item 2</li>
      </ul>
    </div>
  ''';

  final doc = parse(html);

  // Parse a selector
  final sel = parse('p.intro');

  // Find all matching nodes
  final results = queryAll(doc, sel);
  print('Found ${results.length} matching nodes'); // 1

  // Or use compile for repeated matching
  final matcher = compile('li');
  final allLis = queryAll(doc, matcher);
  print('List items: ${allLis.length}'); // 2
}
```

### Working with Pseudo-elements

```dart
// Enable pseudo-elements in parsing
final sel = parseWithPseudoElements('p::first-letter');
```

### Combinators

```dart
// Descendant
final descendants = parse('div p');  // all p inside div

// Child
const children = parse('ul > li');   // direct li children of ul

// Adjacent sibling
final adjacent = parse('h1 + p');    // p immediately after h1

// General sibling
const general = parse('h1 ~ p');     // any p after h1
```

### Pseudo-classes

```dart
// Structural
parse(':first-child');
parse(':nth-child(2n+1)');
parse(':nth-of-type(3)');
parse(':only-of-type');

// Relational
parse(':has(.error)');           // has descendant with class "error"
parse(':has-child(input)');      // has immediate child input
parse(':is(h1, h2, h3)');        // matches any of these
parse(':where(.foo, .bar)');     // zero specificity
parse(':not(.disabled)');        // negation

// Link
parse(':any-link');              // both visited & unvisited
parse(':local-link');            // same-origin links
parse(':link');                  // unvisited
parse(':visited');               // visited (stub)

// Form
parse(':enabled');
parse(':disabled');
parse(':checked');
parse(':required');
parse(':optional');
parse(':read-only');
parse(':read-write');
parse(':valid');
parse(':invalid');
parse(':in-range');
parse(':out-of-range');
parse(':placeholder-shown');
parse(':autofill');
parse(':indeterminate');
parse(':blank');
parse(':user-valid');
parse(':user-invalid');

// Interaction
parse(':focus');
parse(':focus-visible');
parse(':focus-within');
parse(':hover');                 // stub
parse(':active');                // stub
parse(':target');
parse(':target-within');         // stub

// Element state
parse(':open');                  // details, select, dialog[open]
parse(':modal');                 // dialog[open] modal
parse(':fullscreen');            // fullscreen element
parse(':popover-open');          // popover showing
parse(':default');               // default option/button

// Linguistic
parse(':lang(en)');
parse(':dir(ltr)');
parse(':dir(rtl)');

// Media playback
parse(':playing');
parse(':paused');
parse(':buffering');
parse(':seeking');
parse(':stalled');
parse(':muted');
parse(':volume-locked');
parse(':picture-in-picture');

// Temporal (view timelines)
parse(':current');
parse(':past');
parse(':future');

// View transitions
parse(':target-current');
parse(':target-before');
parse(':target-after');
parse(':active-view-transition');
parse(':active-view-transition-type(slide)');

// Paged media
parse(':left');                  // left-hand page
parse(':right');                 // right-hand page
parse(':first');                 // first page

// Custom element
parse(':defined');

// Other
parse(':root');
parse(':empty');
parse(':heading');               // any h1–h6
parse(':heading(2n+1)');         // headings by position
parse(':interest-source');       // experimental
parse(':interest-target');
parse(':state(private)');        // custom state
parse(':xr-overlay');            // XR overlay

// Shadow DOM
parse(':host');
parse(':host(.foo)');
parse(':host-context(.theme-dark)');
parse(':has-slotted(*)');
```

### Pseudo-elements

```dart
// Classic typographic
parseWithPseudoElements('p::first-line');
parseWithPseudoElements('p::first-letter');

// Generated content
parseWithPseudoElements('a::before');
parseWithPseudoElements('a::after');

// Form controls
parseWithPseudoElements('input::file-selector-button');
parseWithPseudoElements('input::placeholder');
parseWithPseudoElements('select::picker-icon');

// Tree-abiding
parseWithPseudoElements('li::marker');
parseWithPseudoElements('details::details-content');

// Shadow DOM
parseWithPseudoElements('::part(header)');
parseWithPseudoElements('::slotted(span)');

// Highlights
parseWithPseudoElements('::selection');
parseWithPseudoElements('::spelling-error');
parseWithPseudoElements('::grammar-error');
parseWithPseudoElements('::highlight(custom)');
parseWithPseudoElements('::search-text');
```

### Specificity

```dart
final sel = parse('div.foo#bar[href]');
print(sel.specificity); // (1, 1, 1) — IDs, classes/attributes/pseudo-classes, type selectors

final low = parse(':where(.a, .b)');
print(low.specificity); // (0, 0, 0) — zero specificity
```

### Serialization

```dart
final sel = parse('div.foo > p::first-line');
final css = serialize(sel);  // "div.foo > p::first-line"
```

### Namespace Support

```dart
// Namespace prefix with pipe separator
parse('svg|rect');           // rect in any namespace
parse('|a');                 // a with no namespace
parse('*|a');                // a in any namespace
```

### Nesting Selector

```dart
// The & selector references parent selector(s) in nested CSS
final nesting = parse('.card &');  // parent selector inside nested rule
```

## Flutter Integration

Cascadia works seamlessly in Flutter apps—pure Dart, no browser dependencies. Use it to parse and query HTML/XML data fetched from networks, assets, or generated locally.

### With `package:html` (Pure Dart)

```dart
import 'package:cascadia/cascadia.dart';
import 'package:html/parser.dart';

Future<List<Element>> fetchArticles(String htmlString) async {
  final document = parse(htmlString);
  // Select all article elements with class "post"
  return queryAll(document, 'article.post');
}

// Use in a Flutter widget:
FutureBuilder<List<Element>>(
  future: fetchArticles(htmlResponse),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return ListView(
        children: snapshot.data!
            .map((el) => ListTile(
                  title: Text(el.querySelector('h2')?.text ?? ''),
                  subtitle: Text(el.querySelector('p')?.text ?? ''),
                ))
            .toList(),
      );
    }
    return CircularProgressIndicator();
  },
);
```

### With `flutter_html` package

If you're using the [`flutter_html`](https://pub.dev/packages/flutter_html) package to render HTML in Flutter, you can pre-process the HTML with Cascadia to manipulate or extract data before rendering.

```dart
import 'package:cascadia/cascadia.dart';
import 'package:html/parser.dart';
import 'package:flutter_html/flutter_html.dart';

HtmlData processHtml(String rawHtml) {
  final doc = parse(rawHtml);

  // Remove all ads using CSS selector
  final ads = queryAll(doc, '.ad, .Advertisement, [id*="ad-"]');
  for (final ad in ads) {
    ad.remove();
  }

  // Extract all links
  final links = queryAll(doc, 'a[href]');
  final hrefs = links.map((a) => a.attributes['href']).toList();

  // Convert back to HTML string for flutter_html
  final cleanedHtml = doc.outerHtml;
  return HtmlData(
    html: cleanedHtml,
    linkCount: hrefs.length,
  );
}
```

Cascadia's selector engine is fast, supports full CSS selectors, and works entirely offline—ideal for Flutter mobile/desktop apps.

## Supported Selectors

### Type, Class, ID, Universal

| Selector            | Example    | Description              |
| ------------------- | ---------- | ------------------------ | ------------------------ |
| Type selector       | `div`      | Element by tag name      |
| Universal selector  | `*`        | Any element              |
| Class selector      | `.warning` | Class attribute contains |
| ID selector         | `#header`  | ID attribute matches     |
| Namespace separator | `svg       | circle`                  | Namespace-qualified name |

### Attribute Selectors

| Selector        | Example             | Description                     |
| --------------- | ------------------- | ------------------------------- | ------- | ------------------------- |
| `[attr]`        | `[disabled]`        | Attribute present               |
| `[attr=value]`  | `[type="text"]`     | Exact value                     |
| `[attr~=value]` | `[class~="active"]` | Whitespace-separated word       |
| `[attr          | =value]`            | `[lang                          | ="en"]` | Value or `value-*` prefix |
| `[attr^=value]` | `[href^="https"]`   | Starts with                     |
| `[attr$=value]` | `[src$=".png"]`     | Ends with                       |
| `[attr*=value]` | `[title*="info"]`   | Contains substring              |
| `[attr!=value]` | `[lang!="fr"]`      | Not equal                       |
| `[attr#=regex]` | `[id#="^test-"]`    | Regex match (non-standard)      |
| `[attr=i]`      | `[lang=i]`          | Case-insensitive (non-standard) |

### Combinators

| Selector         | Example   | Description            |
| ---------------- | --------- | ---------------------- |
| Descendant       | `A B`     | B anywhere inside A    |
| Child            | `A > B`   | B direct child of A    |
| Adjacent sibling | `A + B`   | B immediately after A  |
| General sibling  | `A ~ B`   | B anywhere after A     |
| Selector list    | `A, B, C` | Matches if any matches |

### Pseudo-classes

#### Tree-structural

`:root`, `:empty`, `:first-child`, `:last-child`, `:only-child`, `:nth-child(an+b)`, `:nth-last-child(an+b)`, `:first-of-type`, `:last-of-type`, `:only-of-type`, `:nth-of-type(an+b)`, `:nth-last-of-type(an+b)`

#### Relational

`:has(selector)`, `:haschild(selector)`, `:is(selector)`, `:where(selector)`, `:not(selector)`, `:matches(regex)` / `:matchesown(regex)`, `:contains(text)` / `:containsown(text)`

#### Link & Location

`:link`, `:visited`, `:any-link`, `:local-link`, `:target`, `:scope`

#### User Interaction

`:hover`, `:active`, `:focus`, `:focus-visible`, `:focus-within`

#### Input & Form

`:enabled`, `:disabled`, `:checked`, `:default`, `:indeterminate`, `:placeholder-shown`, `:autofill`, `:required`, `:optional`, `:read-only`, `:read-write`, `:valid`, `:invalid`, `:in-range`, `:out-of-range`, `:user-valid`, `:user-invalid`, `:blank`, `:input`

#### Element Display State

`:open`, `:modal`, `:fullscreen`, `:popover-open`, `:picture-in-picture`

#### Linguistic

`:lang(language)`, `:dir(ltr|rtl)`

#### Media Playback

`:playing`, `:paused`, `:buffering`, `:seeking`, `:stalled`, `:muted`, `:volume-locked`

#### Temporal (View Timelines)

`:current`, `:past`, `:future`

#### View Transitions

`:target-current`, `:target-before`, `:target-after`, `:active-view-transition`, `:active-view-transition-type(type)`

#### Paged Media

`:left`, `:right`, `:first`

#### Custom State

`:state(state-name)`

#### Custom Element

`:defined`

#### XR (AR/VR)

`:xr-overlay`

#### Anchor Positioning

`:anchor(name?)`, `:has-anchor`

#### Container Queries & Scoping

`:in-container`, `:ancestor`, `:parent`, `:prev-sibling`, `:next-sibling`

#### Miscellaneous

`:heading` (any h1–h6) and `:heading(an+b)` (position-based)

### Pseudo-elements

#### Typographic

`::first-line`, `::first-letter`, `::cue` / `::cue(name)`

#### Generated Content

`::before`, `::after`

#### Form-related

`::placeholder`, `::file-selector-button`, `::picker` / `::picker()`, `::picker-icon`, `::checkmark`, `::details-content`

#### Tree-abiding

`::marker`, `::backdrop`, `::column`, `::scroll-button()` / `::scroll-button(axis?)`, `::scroll-marker`, `::scroll-marker-group`

#### Shadow DOM

`::part(name)`, `::slotted(selector?)`

#### Highlight

`::selection`, `::spelling-error`, `::grammar-error`, `::target-text`, `::search-text`, `::highlight(name)`

#### View Transitions

`::view-transition`, `::view-transition-group(name)`, `::view-transition-image-pair(name)`, `::view-transition-old(name)`, `::view-transition-new(name)`

## API Reference

### Top-level Functions

#### `parse(String selector) → Sel`

Parse a CSS selector string (without pseudo-elements). Returns a selector object.

#### `parseGroup(String selector) → Sel`

Parse a comma-separated selector list. Returns a `SelectorGroup`.

#### `parseWithPseudoElements(String selector) → Sel`

Parse with pseudo-elements enabled. Throws if pseudo-elements appear without this API.

#### `compile(String selector) → Sel`

Shorthand for `parse()`. Pre-compiles selector for repeated matching.

#### `query(Node root, Sel selector) → Node?`

Find first matching node in the tree.

#### `queryAll(Node root, Sel selector) → List<Node>`

Find all matching nodes in the tree.

### Classes

#### `Sel`

Base interface for all selector objects:

- `bool match(Node node)` — test if a node matches
- `Specificity get specificity` — specificity weight
- `String toString()` — CSS representation

#### `Specificity`

Triple (a, b, c) representing selector weight:

- `a` — ID selectors
- `b` — class, attribute, pseudo-class selectors
- `c` — type selectors and pseudo-elements

#### `SelectorGroup`

Combines multiple selectors; matches if any constituent matches.

#### `CompoundSelector`

Multiple simple selectors on the same element (e.g., `div.foo#bar`).

#### `CombinedSelector`

Two selectors joined by a combinator (descendant, child, +, ~).

### Selector Types

- `TagSelector` — type selector (`div`, `svg|rect`, `*`)
- `ClassSelector` — `.className`
- `IdSelector` — `#idValue`
- `AttributeSelector` — `[attr=value]`, `[attr~=value]`, etc.
- `PseudoClassSelector` — all pseudo-classes
- `PseudoElement` — pseudo-elements (via `pseudoElement` getter)

## Limitations

- **Runtime-dependent pseudo-classes** such as `:hover`, `:focus`, `:active`, `:valid`, `:indeterminate`, `:autofill`, `:in-range`, `:out-of-range`, `:buffering`, `:seeking`, `:stalled`, `:current`, `:past`, `:future`, `:target`, `:scope`, `:local-link`, `:anchor`, `:has-anchor`, `:in-container`, `:parent`, `:prev-sibling`, `:next-sibling`, `:xr-overlay`, `:state()`, and view transition pseudo-classes **stub to `false`** because static DOM analysis cannot determine runtime state. These are correctly rejected at compile-time rather than causing runtime exceptions.

- **Shadow DOM traversal** for `:host`, `:host()`, `:host-context()`, `:has-slotted()` and `::slotted()` returns false without a shadow root context.

- **Namespace prefix resolution** in `TagSelector` uses the element's prefix where available; for `package:html` this is typically `null`. Fully correct namespace matching may require extensions.

- **Custom element definition** (`:defined`) returns false without access to the custom element registry.

- **Interest API**, **XR overlay**, **paged media**, **container queries** require runtime context unavailable in static analysis.

- Pseudo-elements represent rendered fragments; matching them directly against a node returns `false`. You can detect their presence in selectors and serialize them.

## Design Notes

- **Specificity** follows CSS Selectors Level 3: `:not()` and `:is()` take the maximum specificity of their arguments; `:where()` is zero; `:has()` takes the specificity of its contents.

- **Combinator parsing** treats whitespace as descendant combinator; explicit combinators are `>`, `+`, `~`.

- **Selector list** (`, separated`) groups alternatives with maximum specificity across all.

- **String escaping** supports hex escapes (`\1234`), standard backslash escapes, and quoted strings for attribute values.

- **Text-content selectors** (`:contains`, `:containsown`, `:matches`, `:matchesown`) collect text via DOM traversal.

- The library cover almost complete MDN coverage.

## Contributing

Contributions are welcome! Please open issues and PRs on the [GitHub repository](https://github.com/ayoubzulfiqar/cascadia).

## Testing

```bash
dart test
```

## License

BSD 3-Clause
