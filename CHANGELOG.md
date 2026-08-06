# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.8.0 - 2026-08-06

Correctness release following a full engineering audit. See `AUDIT.md` in the
repository for the defect register and reproduction harness.

### Fixed — crashes and hangs

- **Infinite loop in the parser (P0-1).** Any character the parser did not
  recognise caused it to loop forever, allocating until the VM died. This was
  reachable from documented input: `parse('svg|rect')` — the namespace syntax
  shown in the README — never returned. The parser now guarantees forward
  progress and raises a `FormatException` with the offending offset.
- **Crashes on ordinary HTML (P0-2/3/4).** `queryAll(doc, ':first-child')`
  threw `_TypeError` on markup containing text nodes, and `:root` threw when a
  doctype was present. The `Element` type guard is now applied centrally in
  `Sel.matchWith`, so no selector body can receive a non-element node.
- **Unbounded selector cache (P0-5).** The cache claimed to be an LRU but
  flushed itself entirely when full and cached selectors of any length. It is
  now a real bounded LRU; added `clearSelectorCache()` and `selectorCacheSize`.

### Fixed — incorrect matching

- `:has()` now honours relative combinators: `:has(> p)`, `:has(+ p)` and
  `:has(~ p)` were previously treated as plain descendant searches (P1-1).
- Class matching is now case-sensitive, per HTML standards mode (P1-2).
- `:open` now requires the `open` attribute instead of matching every
  `<details>`/`<dialog>` (P1-3).
- `:default` now matches `<option selected>` and the first submit control of a
  form; it previously looked for a non-existent `default` attribute (P1-4).
- `:enabled` and `:optional` no longer match arbitrary elements such as
  `<div>`; both are restricted to form controls (P1-5, P1-6).
- A bare pseudo-element such as `::before` no longer matches every element
  (P1-7).
- CSS escapes are decoded on parse and re-escaped on serialization, so
  `.foo\.bar` matches `class="foo.bar"` (P1-9).
- Namespace selectors resolve against the element's real namespace URI rather
  than a hardcoded `null` (P1-10).
- `:root` matches only the document element, not a doctype or comment (P1-11).
- `:dir()` resolves inherited directionality instead of comparing the literal
  attribute.

### Fixed — serialization and specificity

- `[attr$="value"]` serialized to the literal text `[$name$="$value"]` because
  of a raw-string bug, producing output that could not be reparsed (P2-1).
- The descendant combinator emitted three spaces (P2-2).
- `an+b` serialization dropped the `n` and left unbalanced parentheses:
  `:nth-child(2n+1)` became `:nth-child(2+1)` (P2-3).
- The universal selector `*` no longer contributes specificity (P2-4).
- `:matches(/re/)` is parsed as a real regex instead of being round-tripped
  through a string and rejected (P2-6).
- Malformed selectors (`div >`, `''`, `div,,`, `:not()`, `p::before span`) are
  now rejected instead of silently producing a phantom universal selector
  (P2-8). Unknown pseudo-classes are errors; use `parseLenient()` to accept
  them.

### Changed — breaking

- **`queryAll`/`query` no longer return the root element** (P1-8). This matches
  the DOM's `querySelectorAll`. Previously `queryAll(divElement, 'div')`
  returned the element itself.
- **The `Matcher` interface has been removed** (P2-7). It collided with
  `package:matcher`/`package:test`, forcing users to write `hide Matcher`, and
  added only `toString()` over `Sel`. Implement or reference `Sel` instead.
- The `Serializer` class has been removed; `serialize(sel)` and
  `sel.toString()` are now the single implementation.
- Thirty-one unreachable `*PseudoElement` classes have been deleted. They were
  exported and documented but never constructed by the parser. Pseudo-elements
  are now the single validated `PseudoElementSelector`, so `::bogus` is a parse
  error.

### Added

- **`MatchContext`** — supply runtime state (hover, focus, target, visited
  URLs, custom element registry, custom states) so selectors that a static DOM
  cannot decide now work: `queryAll(doc, ':focus', MatchContext(focused: el))`.
- **`MatchSupport` and `Sel.undecidableParts`** — inspect whether a selector is
  `decidable`, `requiresContext` or `neverDecidable`, and which parts need
  state. Replaces ~90 stub classes whose bodies were `return false`, where a
  non-match was indistinguishable from an unimplemented feature.
- `MatchContext.strict` throws `UndecidableSelectorError` instead of silently
  returning `false`.
- `closest()`, `parseLenient()`, `clearSelectorCache()`, `selectorCacheSize`.
- Full `an+b` support in `:nth-child()` and friends, including `odd`/`even`.

### Internal

- `pseudo_classes.dart` reduced from 2107 lines to a set of focused modules;
  122 `return false` bodies collapsed into one parameterised type.
- Tree traversal in `query`/`queryAll` is iterative, removing the stack-depth
  ceiling on deep documents.
- Test suite expanded from 48 to 94 tests, including a per-defect regression
  suite and a serialization round-trip property test.
- Package archive reduced from 411 KB to 36 KB by excluding the generated
  `doc/` tree, which shipped despite being git-ignored (`.pubignore` overrides
  `.gitignore` per directory).
- README examples are now compile-checked in `example/` so they cannot rot.

## 0.7.6 - 2026-05-10

### Documentation
- Added comprehensive dartdoc comments for all pseudo-class and pseudo-element
  classes, improving pub.dev documentation score from 10/20 to 20/20
- Fixed markdown table formatting in README for proper pub.dev rendering
- Updated documentation to use consistent code formatting and notation

### Build
- Declared supported platforms (android, ios, linux, macos, windows, web) in
  pubspec.yaml to improve platform support score from 0/20 to 20/20
- Added `.pubignore` to exclude tool/ directory from package publication
- Updated `.gitignore` to properly exclude build artifacts

## 0.6.9 - 2026-05-04

### Added
- Full CSS selector parsing (Selectors Level 3 and many Level 4+)
- 78 pseudo-classes (`:first-child`, `:nth-child`, `:not`, `:has`, `:is`, `:where`, `:focus-visible`, `:dir`, `:has-slotted`, `:heading`, `:active-view-transition`, etc.)
- 31 pseudo-elements (`::before`, `::after`, `::first-line`, `::first-letter`, `::selection`, `::part`, `::slotted`, `::view-transition-*`, etc.)
- Combinators: descendant, child, adjacent sibling, general sibling
- Attribute selectors: `[attr]`, `[attr=value]`, `[attr~=value]`, `[attr|=value]`, `[attr^=value]`, `[attr$=value]`, `[attr*=value]`
- Namespace support (`svg|circle`)
- Nesting selector (`&`)
- Specificity calculation per CSS spec
- Serialization to CSS string
- `query()` and `queryAll()` DOM traversal utilities
- `compile()` for reusable matcher functions
- `parseWithPseudoElements()` for pseudo-element support
- Comprehensive test suite (48 tests)
- Full Flutter compatibility
- BSD 3-Clause license

### Documentation
- Complete README with selector reference table
- Usage examples for Dart and Flutter
- API documentation with dartdoc comments
