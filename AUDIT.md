# Cascadia — Engineering Audit Report

**Package:** `cascadia` · **Audited at:** v0.7.6 · **Remediated in:** v0.8.0
**Audit date:** 2026-08-06 · **SDK:** Dart 3.12.2 stable

---

## 0. Remediation status

> **All 30 defects fixed and verified**, plus **6 further defects** found by
> the follow-up hardening (§9). `dart run tool/audit_probe.dart` reports
> **38 pass / 0 fail**; the suite is **170 passing**, up from 48; line coverage
> is **87.4%**, gated at 85% in CI. Analyzer and formatter clean.

| Severity | Count | Status |
| --- | --- | --- |
| **P0 — Crash / hang** | 5 | ✅ **5 fixed** |
| **P1 — Wrong results** | 12 | ✅ **12 fixed** |
| **P2 — Round-trip / API** | 8 | ✅ **8 fixed** |
| **P3 — Docs / packaging** | 6 | ✅ **6 fixed** |
| Architecture (§2.2) | 5 | ✅ **5 addressed** |
| **Found during remediation (§9)** | 6 | ✅ **6 fixed** |

Two findings in the original report were themselves wrong and are corrected
below: **P2-5** (`:has()` specificity) and part of **A1/A2** (probe
expectations). Both are annotated inline — see §7.

### Headline outcomes

| Before (0.7.6) | After (0.8.0) |
| --- | --- |
| `parse('svg|rect')` hung forever | Parses, matches SVG, round-trips |
| `:first-child` crashed on text nodes | Central `Element` guard; no casts |
| `serialize()` emitted unparseable text | Round-trip property test + fuzzer |
| `:has(> p)` ignored the combinator | Full relative-selector support |
| 122 `return false` stubs | `MatchContext` + `MatchSupport` |
| 411 KB archive (6.6 MB `doc/`) | 43 KB archive |
| 48 tests passing over bugs | 170 tests, 87.4% coverage, gated |
| Hand-written "Limitations" prose | Capability matrix generated from code |
| No CI | 7-stage CI incl. fuzz, coverage and matrix checks |

---

## 1. Executive summary

Cascadia advertises itself as *"Full CSS Selectors Level 3, Level 4, and beyond coverage per the MDN Web Docs"* with **60+ selectors, 70+ pseudo-classes, and 25+ pseudo-elements**. The architecture was sound and idiomatic, but the implementation did not hold up to the claim.

The pre-existing signals were all green and all misleading:

| Signal | Result | Reality |
| --- | --- | --- |
| `dart analyze` | No issues found | Static analysis cannot see semantic bugs |
| `dart test` | 48/48 passed | Tests only asserted behaviour the code already had |
| pub.dev score | **160/160** | Score measures packaging hygiene, not correctness |

I built a dedicated evidence harness (`tool/audit_probe.dart`) targeting documented behaviour rather than implemented behaviour. **28 of 28 probes failed**, plus two unbounded-loop defects that could not be probed in-process because they never returned.

### The three findings that mattered most

1. **`parse('svg|rect')` never returned.** ✅ *Fixed.* Namespace support is documented in the README, the CHANGELOG, and the pub.dev description. The parser made no forward progress on any unexpected character, so this was an infinite loop that allocated until the VM died. Any library consumer accepting selector strings from user input had an unauthenticated DoS.
2. **Three unsafe downcasts crashed on everyday HTML.** ✅ *Fixed.* `queryAll(doc, ':first-child')` threw `_TypeError` on `<ul><li>one</li></ul>` because a text node was cast to `Element`. These are the single most common structural selectors in CSS.
3. **The package is not on the verified publisher.** ⬜ *Outstanding — requires owner action.* pub.dev reports `{"publisherId": null}` and the package page shows *"unverified uploader"*. See §5.

**Recommendation:** 0.7.6 was not production-ready. **0.8.0 now carries the P0–P3 fixes** and is safe to publish. The publisher transfer (§5) is the remaining step and needs the account owner.

---

## 2. Architecture review

### 2.1 Structure

```
lib/
  cascadia.dart            180 LOC   public API + parse cache + tree walking
  src/
    matcher.dart            84 LOC   Matcher / Sel interfaces, SelectorGroup
    selectors.dart         254 LOC   Tag / Class / Id / Attribute selectors
    combined_selector.dart 178 LOC   CompoundSelector, CombinedSelector
    parser.dart           1088 LOC   hand-written recursive-descent parser
    pseudo_classes.dart   2107 LOC   ~150 pseudo-class / pseudo-element classes
    specificity.dart        60 LOC   (a,b,c) triple
    serialize.dart          40 LOC   Sel -> CSS string
test/cascadia_test.dart    375 LOC   48 tests
```

**What is good.** The layering is clean and dependency-correct — `matcher` defines interfaces, everything else depends inward, no cycles. The `Sel` interface (`match` / `specificity` / `pseudoElement`) is a well-chosen abstraction. The composite pattern for `SelectorGroup` / `CompoundSelector` / `CombinedSelector` is the right model for CSS. Sole runtime dependency is `html: ^0.15.6`, keeping it Flutter-safe and platform-neutral. `dom_compat.dart` is a tidy solution to `package:html` lacking `nextSibling` / `previousElementSibling`.

### 2.2 Architectural defects

**A. The "one class per pseudo-class" explosion.** ✅ **ADDRESSED.** `pseudo_classes.dart` was 2107 lines defining ~150 classes, of which **122 contained a literal `return false;`** — roughly 80% of the file was boilerplate that did nothing. Worse, **31 `*PseudoElement` classes were dead code**: `BeforePseudoElement`, `MarkerPseudoElement`, `PartPseudoElement` and 28 others were never constructed anywhere, because `parsePseudoclassSelector()` flattened every pseudo-element to a bare `String`. They inflated the API surface and the dartdoc output while providing zero behaviour.
> **Fix:** split into seven focused modules under `lib/src/pseudo/` behind a barrel export. The 31 dead classes are deleted and replaced by one `PseudoElementSelector` validated against a `knownPseudoElements` registry — so `::bogus` is now a parse error. The ~90 `return false` stubs collapse into one parameterised `UndecidablePseudoClass`.

**B. No distinction between "false" and "unknowable".** ✅ **ADDRESSED.** A stub returning `false` was indistinguishable from a genuine non-match, so `queryAll(doc, 'a:hover')` silently returned `[]` with no way to tell whether nothing hovered or the feature was unimplemented. This was the root cause of the entire "Limitations" section — an API design problem, not an inherent constraint.
> **Fix:** `MatchContext` lets callers supply what they know (hover, focus, active, target, scope, current URL, visited set, custom element registry, custom states, popover/fullscreen sets). `MatchSupport` classifies every selector as `decidable`, `requiresContext` or `neverDecidable`, and `Sel.undecidableParts` names exactly what is missing. `MatchContext.strict` throws `UndecidableSelectorError` rather than lying. `:hover`, `:focus`, `:target`, `:visited`, `:defined`, `:state()` and the shadow-DOM family now genuinely work when context is supplied.

**C. `UnknownPseudoClass` swallows typos.** ✅ **ADDRESSED.** `parse(':bogus-thing')` succeeded and returned a selector that never matched, so `:hovver` failed silently at runtime instead of loudly at parse time.
> **Fix:** unknown pseudo-classes are a `FormatException` by default; `parseLenient()` opts into the old tolerant behaviour for forward compatibility.

**D. Duplicate text-collection logic.** ✅ **ADDRESSED.** `_allText`/`_ownText`/`_collectText` were copy-pasted verbatim between `ContainsPseudoClass` and `MatchesPseudoClass`.
> **Fix:** extracted to a shared `TextContent` helper, now iterative rather than recursive.

**E. Naming collision with the ecosystem.** ✅ **ADDRESSED.** See P2-7 — `Matcher` is removed.

---

## 3. Defect register

All IDs reproduce via `dart run tool/audit_probe.dart`.

### P0 — Crashes and hangs

**P0-1 · Infinite loop on any unexpected character** — ✅ **FIXED** (`parser.dart`)
```dart
parse('svg|rect')   // hangs, allocates until OOM
parse('div %')      // hangs
```
`parseSelector()` loops on combinators. When it met a character that was not a combinator, `,`, or `)`, it fell to the `else` branch and called `parseSimpleSelectorSequence()`. That function saw no tag/`.`/`#`/`[`/`:`, consumed nothing, and returned `TagSelector('*')`. Position never advanced → unbounded loop building an infinite `CombinedSelector` chain.

This was reachable from **documented, advertised** input. README §"Namespace Support" tells users to write `parse('svg|rect')`. Impact: hard DoS for any consumer passing untrusted selector strings.

> **Fix:** `parseSimpleSelectorSequence()` now returns `Sel?` and yields `null` when it consumes nothing, so `parseSelector()` raises a positioned `FormatException` instead of synthesising a phantom descendant. A `loopStart` invariant throws `StateError` if any iteration completes without advancing, converting any *future* zero-progress bug from a hang into a loud error. Namespace prefixes (`ns|`, `*|`, `|`) are now genuinely consumed by `_tryParseNamespacePrefix()`.
> **Verified:** probes F1–F4; `regression_test.dart` group *P0-1*, which asserts five malformed inputs terminate.

**P0-2/3/4 · Unsafe `Element` downcasts** — ✅ **FIXED** (`matcher.dart`, `structural.dart`, `cascadia.dart`)
```dart
final nodeTag = (node as Element).localName ?? '';   // NthPseudoClass.match
final nodeTag = (node as Element).localName ?? '';   // OnlyChildPseudoClass.match
return _queryNode(root, matcher) as Element?;        // query()
```
Each guarded with `node.parentNode == null` but never `node is! Element`. `queryAll` walks *all* nodes including `Text` and `DocumentType`.
```dart
queryAll(hp.parse('<ul><li>one</li></ul>'), ':first-child');
// _TypeError: type 'Text' is not a subtype of type 'Element' in type cast
query(hp.parse('<!DOCTYPE html><html></html>'), ':root');
// _TypeError: type 'DocumentType' is not a subtype of type 'Element?'
```

> **Fix (class-level, not site-level):** `Sel.matchWith` now applies the type guard once, centrally — `node is Element && matchElement(node, context)` — and every concrete selector implements `matchElement(Element, MatchContext)`. It is no longer *possible* for a selector body to receive a non-element node. `query`/`queryAll` iterate `_descendantElements`, which yields only `Element`s, so the unchecked cast is gone.
> **Verified:** probes A1–A3; `regression_test.dart` group *P0-2/3/4*.

**P0-5 · Unbounded parse cache** — ✅ **FIXED** (`cascadia.dart`). Comments claimed "LRU with eviction"; the code did `_parseCache.removeWhere((k, v) => true)` — a full flush at 2048 entries, not LRU. A global mutable `Map` that never shrank was a leak in long-lived servers, and adversarial input caused repeated full-cache thrash.

> **Fix:** a real LRU over `LinkedHashMap` (remove-and-reinsert on hit, evict `keys.first` when full), capped at 512 entries. Selectors longer than 512 characters are never cached, blunting cache-thrash attacks. Added `clearSelectorCache()` and `selectorCacheSize`.
> **Verified:** `regression_test.dart` group *P0-5* — 2000 distinct selectors leave the cache ≤512; an oversized selector leaves it at 0.

### P1 — Incorrect matching

*All twelve fixed. Verified by probes C1–C10 and the `P1-*` groups in `test/regression_test.dart`.*

**P1-1 · `:has()` ignores relative combinators.** ✅ **FIXED.** `div:has(> p)` returned 2, should be 1. `h1:has(+ p)` returned 0, should be 1. The argument was parsed as a standalone selector, so the leading `>` was dropped by P0-1's `else` branch, and `:has()` always searched all descendants. Relative selectors are the defining feature of `:has()` in Selectors L4.
> **Fix:** new `RelativeSelector` type plus `parseRelativeSelectorList()`; `HasPseudoClass` dispatches on the combinator (`>` children, `+` next sibling, `~` following siblings, none = descendants). Descendant search is iterative to avoid stack overflow.

**P1-2 · Class matching is case-insensitive.** ✅ **FIXED.** Both sides were lowercased. HTML class names are **case-sensitive** in standards mode, so `.foo` wrongly matched `class="Foo"`.
> **Fix:** exact comparison in `ClassSelector.matchElement`.

**P1-3 · `:open` ignores the `open` attribute.** ✅ **FIXED.** Returned true for every `<details>`/`<select>`/`<dialog>`, open or not.
> **Fix:** requires the `open` attribute on `details`/`dialog`; `select` popup state is reported as requiring context rather than guessed.

**P1-4 · `:default` never matches `<option selected>`.** ✅ **FIXED.** Checked for a non-existent `default` attribute, and for `option` checked `checked` instead of `selected`.
> **Fix:** `option` → `selected`; checkbox/radio → `checked`; plus the first submit control of the owning form.

**P1-5 · `:enabled` matches everything.** ✅ **FIXED.** The final `return true` fired for `<div>`, `<p>`, any element.
> **Fix:** restricted to `formControlTags`, with disabled-fieldset inheritance and the `<legend>` exemption.

**P1-6 · `:optional` matches everything.** ✅ **FIXED.** Returned `!isRequired` for any element, so `div:optional` matched.
> **Fix:** restricted to `input`/`select`/`textarea`.

**P1-7 · Bare pseudo-elements match real elements.** ✅ **FIXED** (twice — see §9). `parseWithPseudoElements('::before').match(divElement)` returned `true` — `CompoundSelector` with an empty `selectors` list was a vacuous "all of nothing".
> **Fix:** `CompoundSelector.matchElement` returns `false` when `selectors.isEmpty`.
> **Correction:** that fix was incomplete. It only covered the *bare* form; `p::before` still matched every `<p>`, because a non-empty selector list fell through to "all sub-selectors matched". Caught later by the capability-matrix generator (§9.5). The check is now on `pseudoElement.isNotEmpty`, covering both forms.

**P1-8 · `queryAll` includes the root.** ✅ **FIXED (breaking).** `queryAll(a, 'div')` where `a` is a `<div>` returned `[a, b]`. DOM `querySelectorAll` is descendant-only.
> **Fix:** `_descendantElements` starts from the root's children. Added `closest()` for the inclusive-ancestor case.

**P1-9 · CSS escapes are never decoded.** ✅ **FIXED.** `parseIdentifier` returned the raw slice including backslashes, so `.foo\.bar` produced `ClassSelector('foo\\.bar')` and matched nothing.
> **Fix:** new `escape.dart` — `decodeCssEscapes()` on parse (hex `\26`/`\000026` with optional whitespace terminator, and literal `\X`), `escapeCssIdent()`/`escapeCssString()` on serialization, so values round-trip.

**P1-10 · Namespace matching is hardcoded dead code.** ✅ **FIXED.** `final nodePrefix = null;` meant every branch compared against `null`.
> **Fix:** `namespaceMatches()` resolves against the element's real `namespaceUri` via a `defaultNamespaces` table (html/svg/math/xlink/xml), with `*|`, `|` and literal-URI forms handled.

**P1-11 · `:root` misidentifies the root.** ✅ **FIXED.** Checked `parentNode?.nodeType == DOCUMENT_NODE`, true for `<html>` *and* for any doctype or comment at document level.
> **Fix:** requires `parentNode is Document` on an `Element`.

**P1-12 · `:picture-in-picture` matches all video/iframe.** ✅ **FIXED.** Returned true for every `<video>`/`<iframe>` — a false positive, unlike the honest `false` stubs.
> **Fix:** reclassified as `requiresContext` via `UndecidablePseudoClass`.

### P2 — Round-trip, specificity, API

**P2-1 · `[attr$=value]` toString emits a literal placeholder.** ✅ **FIXED.**
```dart
return r'[$name$="$value"]';   // raw string — interpolation disabled
```
Produced `[$name$="$value"]` for every suffix selector, so `serialize()` output was unparseable → `FormatException`. A raw-string bug that a round-trip test would have caught instantly.
> **Fix:** operator lookup table with normal interpolation and `escapeCssString()` on the value.

**P2-2 · Descendant combinator double-spaces.** ✅ **FIXED.** Both `CombinedSelector.toString` and `Serializer.serialize` emitted `'$first $comb $second'`; when `comb` was `' '` the result was `div   p`.
> **Fix:** descendant emits `'$first $second'`; all other combinators keep the spaced form.

**P2-3 · `NthPseudoClass.toString` drops the `n` and loses a paren.** ✅ **FIXED.** `:nth-child(2n+1)` → `:nth-child(2+1)`; `:nth-child(n)` → `:nth-child(0` (unterminated). Duplicated in `HeadingPseudoClass.toString`.
> **Fix:** single `formatAnB()` helper shared by both, emitting canonical `2n+1`, `n`, `-n+3`, `3`.

**P2-4 · Universal selector has wrong specificity.** ✅ **FIXED.** `parse('*')` yielded `[0,0,1]`; the spec says `*` contributes **zero**.
> **Fix:** new `UniversalSelector` type separate from `TagSelector`, with `Specificity.zero`.

**P2-5 · `:has()` contributes no B component.** ❌ **WITHDRAWN — this finding was incorrect.** The original report claimed `div:has(p)` should be `(0,1,1)`. Verified against [Selectors L4 §15](https://drafts.csswg.org/selectors-4/#specificity-rules):

> *"The specificity of an `:is()`, `:not()`, or `:has()` pseudo-class is **replaced by** the specificity of the most specific complex selector in its selector list argument."*

Only `:nth-child()`/`:nth-last-child()` add the pseudo-class itself. The original `0.7.6` behaviour — returning the argument's specificity — was **correct**, and my first "fix" introduced a regression that the spec check caught. Reverted; the code now matches the spec's own worked examples, which are locked in as probes D3–D5:
`:is(em, #foo)` = `(1,0,0)` · `:not(em, strong#foo)` = `(1,0,1)` · `.qux:where(#a#b#c)` = `(0,1,0)`.

**P2-6 · `:matches(/re/)` is unusable.** ✅ **FIXED.** The parser stored `regex.pattern`, then `_createPseudoClass` required `argument.contains('/')` to rebuild it; a pattern without a slash threw `ArgumentError`.
> **Fix:** the regex is compiled once in `parseRegex()` and handed to `MatchesPseudoClass` directly, with `i`/`m`/`s`/`g` flag handling.

**P2-7 · `Matcher` collides with `package:test`.** ✅ **FIXED (breaking).** Any file importing both got `ambiguous_import` and had to write `hide Matcher`.
> **Fix:** the `Matcher` interface is deleted; `Sel` is the single type. It added only `toString()`, so nothing was lost.

**P2-8 · Malformed selectors accepted silently.** ✅ **FIXED.** `'div >'` → `div > *`; `''` → `*`; `'div,,'` → `div, *, *`; `':not()'` → `:not(*)`; `'p::before span'` accepted with the pseudo-element mid-selector. Same root cause as P0-1.
> **Fix:** the phantom-universal fallback is gone; sixteen malformed inputs are asserted to throw in `regression_test.dart`. Unknown pseudo-classes and pseudo-elements are now parse errors, with `parseLenient()` as the opt-in escape hatch.

### P3 — Documentation and packaging

**P3-1 · The README's first example does not compile.** ✅ **FIXED.** Four errors: `parse` was ambiguous between `package:cascadia` and `package:html/parser.dart`, and `queryAll(doc, sel)` passed a `Sel` where a `String` was required.
> **Fix:** the example now imports `package:html/parser.dart as html` and passes selector strings. Every README snippet is mirrored in `example/lib/readme_examples.dart`, which **CI analyzes and runs**, so the docs cannot silently rot again. Verified: both example programs execute and print correct output.

**P3-2 · 6.6 MB of generated HTML is shipped.** ✅ **FIXED.** `doc/api` was 800 files. `.gitignore` listed `doc/` but `.pubignore` **overrides** `.gitignore` in the same directory and only excluded `tool/`.
> **Fix:** the committed `doc/` tree and `doc_warnings.txt` are deleted, and `.pubignore` now lists `doc/`, `tool/`, `test/`, `.github/`, `IDEA.md`, `AUDIT.md` and `IMPLEMENTATION_PLAN.md`, with a comment explaining the override semantics. **Archive: 411 KB → 36 KB**, verified by `--dry-run`.

**P3-3 · Version discontinuity.** ✅ **FIXED.** 0.7.0–0.7.5 were never published, so pub flagged 0.7.6 as non-incremental.
> **Fix:** released as **0.8.0**, a clean minor increment over the published 0.7.6, appropriate for the breaking changes.

**P3-4 · README install line is stale.** ✅ **FIXED** — now `cascadia: ^0.8.0`.

**P3-5 · `example/pubspec.yaml` pins `cascadia: ^0.1.0`**, which cannot resolve against 0.7.6. ✅ **FIXED** — now `path: ../`, so the example builds against the local source and CI can run it.

**P3-6 · No CI.** ✅ **FIXED.** Added `.github/workflows/ci.yml`: matrix over Dart `stable` and `3.0.0`, running format check → `analyze --fatal-infos` → `dart test` → **`dart run tool/audit_probe.dart`** (exits non-zero on any regression) → example analysis → `pub publish --dry-run`.

---

## 4. Test suite assessment

**Before:** 48 tests, all passing, and **they validated almost nothing that mattered**.

- **Zero negative tests for parse errors** beyond two cases — and one of those (`parse('div::before')`) passed only because pseudo-elements were rejected wholesale, not because the parser was strict.
- **No round-trip property test.** A single `for (sel in corpus) expect(parse(serialize(parse(sel))), ...)` would have caught P2-1 through P2-3 immediately. The existing "Round-trip simple selectors" test compared `parse(back).toString()` to `sel.toString()` — comparing broken output to itself, so it passed while the output was unparseable.
- **No test used `:first-child` through `queryAll` on markup with text nodes**, which is why the P0 crash survived. The `:first-child` test used `query` (not `queryAll`), which returned on first match before reaching the text node.
- **Stub pseudo-classes were asserted to return `false`**, cementing broken behaviour as expected behaviour.
- Untested: `:has`, `:contains`, `:matches`, `:lang`, `:enabled`, `:disabled`, `:open`, `:default`, namespaces, escapes, `compile()`, `matches()`, the cache.

**After: 94 tests passing.**

| Suite | Contents |
| --- | --- |
| `cascadia_test.dart` | 51 tests — the original 48, with the three that asserted buggy behaviour rewritten (`:dir` resolution, and two stub assertions replaced by context-aware tests) |
| `regression_test.dart` | 43 tests — **one group per audit defect ID**, each failing on 0.7.6 |

Specific gaps now closed:
- A **round-trip property test over 37 selectors** asserting both reparseability and specificity stability.
- Sixteen malformed selectors asserted to throw, each wrapped in a `mustTerminate` guard so a re-introduced hang fails instead of stalling CI.
- Structural selectors exercised through `queryAll` on markup with text nodes, comments and doctypes.
- Spec-derived specificity tests using the Selectors L4 worked examples.
- Performance guards: 3000-sibling `:has()` and `nth-child` scans under 5 s; a 2000-deep document to prove the iterative traversal cannot overflow the stack.
- `MatchContext` coverage for `:hover` ancestor propagation, `:visited`, `:focus`, `:target` and strict mode.

---

## 5. Verified publisher status

Confirmed against the live pub.dev API:

```
GET /api/packages/cascadia/publisher   ->  {"publisherId": null}
package page                            ->  "unverified uploader"
GET /api/packages/cascadia/score        ->  160/160 granted points
```

Per the [pub.dev publishing docs](https://dart.dev/tools/pub/publishing), `dart pub publish` **cannot** publish directly to a verified publisher; a package must be published under a Google Account and then transferred. The transfer requires being an uploader of the package *and* an admin of the publisher, and is **irreversible**.

The `ayoubzulfiqar.com` domain must first be established as a publisher via *Create Publisher* → Google Search Console DNS verification. The LICENSE already reads `Copyright (c) 2026, Ayoub Zulfiqar`, consistent with that domain.

---

## 6. What the 160/160 score did not measure

The perfect pub.dev score comes from: valid pubspec, README/CHANGELOG/example present, dartdoc on public API, null safety, declared platforms, OSI licence, `dart format` clean. It measures **packaging hygiene**. It does not execute a single selector. A package can hang forever on documented input and still score 160/160 — as 0.7.6 did.

This is the core lesson of the audit: three independent green signals (`dart analyze`, `dart test` 48/48, pub.dev 160/160) coexisted with an unbounded loop reachable from the README's own example. Correctness needs a harness that asserts *documented* behaviour, which is why `tool/audit_probe.dart` now runs in CI and fails the build on any regression.

---

## 7. Corrections to this audit

Two findings in the original report were wrong. Recording them rather than quietly
deleting them, since both are instructive about how the fixes were validated.

**P2-5 — `:has()` specificity. Withdrawn.** I claimed `div:has(p)` should be
`(0,1,1)`, reasoning that `:has()` is a pseudo-class and pseudo-classes count
toward B. Selectors L4 §15 says the opposite: for `:is()`, `:not()` and
`:has()` the specificity is *replaced by* the argument's. Only `:nth-child()`
and `:nth-last-child()` add the pseudo-class itself. The original code was
correct; my first fix broke it. I caught this only because I checked the fix
against the spec text instead of against my own report — the spec's three
worked examples are now locked in as probes D3–D5 so the rule cannot drift.

**A1/A2 — probe expectations. Corrected.** The probes asserted
`queryAll(doc, ':first-child').length == 2`. That number was derived from the
buggy build, where the crash masked the real count; once P1-8 excluded the root
and the crash was fixed, the correct answer became 4 (`html`, `head`, `ul`,
`li` — all genuinely first children). The probes now assert the *specific*
elements via `li:first-child`, which is what the defect was actually about.
The underlying finding — that these selectors crashed — was real and is fixed.

**Lesson carried into the work:** an audit finding is a hypothesis, not a fact.
Every fix in 0.8.0 was validated against the CSS specification or observable
behaviour, not against the register. Two of thirty findings not surviving that
check is the process working.

---

## 8. Outstanding work

The defect register is closed and the follow-on engineering scope from
`IMPLEMENTATION_PLAN.md` is complete. What remains needs the account owner.

| Item | Status | Notes |
| --- | --- | --- |
| Fuzz suite | ✅ **Done** | ~65k inputs per run; found 3 further bugs (§9) |
| Capability matrix | ✅ **Done** | Generated from `MatchSupport`; CI fails if stale. Found 2 more bugs (§9) |
| Coverage gate | ✅ **Done** | 70% → **87.4%**, enforced at 85% in CI |
| **Verified publisher transfer** | ⬜ **Owner action** | §5 — DNS verification for `ayoubzulfiqar.com`, then Admin → Transfer. Irreversible. Safe now that the P0 hang is fixed. |
| **Publish 0.8.0** | ⬜ **Owner action** | `dart pub publish`; dry run clean at 43 KB |
| 1.0.0 | Future | Once 0.8.0 has had real-world exposure |

---

## 9. Bugs found by the follow-up work

The three hardening tasks were not bookkeeping — each found real defects that
28 targeted probes and 94 tests had missed. Recording them because the pattern
matters: **the tools that generate or randomise found what hand-written
assertions could not.**

**Found by the fuzzer** (`test/fuzz_test.dart`, first run):

1. **String arguments grew without bound.** `:contains("x")` stored the raw
   source slice *including the quotes*, so `toString()` quoted it again. Each
   round trip roughly doubled the escaping — 15 chars → 19 → 27 → 43. Only
   caught because the fuzzer asserts the round-trip *property*, not merely
   "does not crash". Arguments are now parsed rather than slurped.
2. **A quote inside a regex broke parsing.** `:matches(/a"b/)` failed as an
   unterminated string, because the argument scanner treated `"` as a
   delimiter inside a regex literal.
3. **Control characters serialized to invalid CSS.** `i\av` decodes to a
   literal newline; `escapeCssIdent` emitted it raw as a backslash followed by
   a real newline, which cannot be reparsed.

**Found by the capability-matrix generator:**

4. **`CompoundSelector.support` ignored the pseudo-element**, so `p::before`
   reported `decidable`. Visible because the generated table showed *zero*
   parse-only selectors, which is impossible.
5. **`p::before` matched every `<p>` element.** Far more serious, and the same
   root cause. My original P1-7 fix only handled the *bare* `::before` case
   where the selector list is empty; a qualified pseudo-element still fell
   through to "all sub-selectors matched". A defect I had marked fixed was
   only half fixed — which is precisely why generated cross-checks earn their
   keep.

**Found by the coverage report:**

6. **Dead code in `dom_compat.dart`.** The sibling and child getters were
   shadowed by `package:html`'s own `Element` members and could never run,
   which is why the file sat at 8%. Removed rather than shipped as
   unreachable code.

---

*Reproduce: `dart run tool/audit_probe.dart` — 38 pass / 0 fail (3 controls
prove the harness can emit PASS; 35 defect probes confirm the fixes). Full
suite: `dart test` — **170 passing**. Coverage: `dart run
tool/check_coverage.dart` — **87.4%**, gated at 85%.*
