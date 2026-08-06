# Cascadia — Implementation Plan

Remediation plan for the defects in [`AUDIT.md`](AUDIT.md). Sequenced so each phase
is independently shippable and every fix lands with a regression test.

**Baseline:** v0.7.6 · 28/28 audit probes failing · 2 unbounded loops · unverified uploader
**Target:** v1.0.0 · full probe suite green · transferred to publisher `ayoubzulfiqar.com`

---

## Guiding principles

1. **No fix without a failing test first.** Every defect gets a test that fails on
   `main` before the fix lands. The current suite passed at 48/48 while the library
   hung on documented input — that must never recur.
2. **Honesty over coverage claims.** A pseudo-class that cannot be decided statically
   should say so, not silently return `false`. Replace the "Limitations" prose with a
   machine-checked capability matrix.
3. **Correct beats complete.** Better to support 40 selectors correctly than to claim
   150 where 122 are `return false`.
4. **Breaking changes are acceptable now.** Pre-1.0, 58 downloads/30 days, 0 likes.
   The cost of fixing the `Matcher` collision and `queryAll` semantics will never be lower.

---

## Phase 0 — Safety net (½ day)

Land the harness before touching library code, so every later phase is measurable.

- [ ] **0.1** Keep `tool/audit_probe.dart` as the living defect ledger.
- [ ] **0.2** Add `.github/workflows/ci.yml` — matrix on Dart `stable` + `3.0.0`:
      `dart pub get` → `dart format --set-exit-if-changed` → `dart analyze --fatal-infos`
      → `dart test`. Blocks merge on failure.
- [ ] **0.3** Add a **1 s watchdog** wrapper in the test suite for every parser test, so
      a future infinite loop fails CI instead of hanging the runner:
      ```dart
      Future<T> noHang<T>(T Function() f) =>
          Future(f).timeout(const Duration(seconds: 1));
      ```
- [ ] **0.4** Add `test/corpus/selectors.txt` — a shared list of ~200 valid and ~80
      invalid selectors, consumed by the parser, round-trip, and fuzz tests.

**Exit:** CI green on `main` with the audit harness reporting 28 known failures.

---

## Phase 1 — Stop the bleeding (P0) → **v0.8.0**

The only phase that must ship before the publisher transfer.

### 1.1 Kill the infinite loop *(P0-1)*

Root cause: `parseSimpleSelectorSequence()` can consume zero characters and return a
phantom `TagSelector('*')`, so `parseSelector()`'s descendant branch never advances.

Fix in `parser.dart`:
- Make `parseSimpleSelectorSequence()` return `Sel?` — `null` when it consumed nothing.
- In `parseSelector()`, treat a `null` right-hand side as a `FormatException`
  (`Unexpected character '%' at position 4`), never as an implicit descendant.
- Add a hard invariant in the combinator loop: capture `position` at the top, and
  `assert`/throw if an iteration ends without advancing. Converts any future
  zero-progress bug from a hang into a loud error.
- Track whether the universal selector was *explicitly written* (`*`) or synthesised, so
  `'div >'`, `''`, `'div,,'`, `':not()'` all raise `FormatException` *(fixes P2-8)*.

### 1.2 Implement namespace parsing properly *(P0-1, P1-10)*

`|` is currently never consumed by `parseTypeSelector`, which is why `svg|rect` hangs.

- Parse `ns|local`, `*|local`, `|local` in `parseTypeSelector()` into an explicit
  `(namespace, localName)` pair on `TagSelector` instead of a `String` with an embedded pipe.
- Resolve the namespace against `Element.namespaceUri` (which `package:html` *does*
  expose) rather than the hardcoded `final nodePrefix = null`.
- Add a `NamespaceResolver` so callers can map prefixes → URIs; default to the HTML,
  SVG, and MathML namespaces.
- If full resolution proves impractical for `package:html`, the fallback is to **reject**
  namespace selectors with a clear `UnsupportedError` and delete the claim from the
  README — silently hanging is the one unacceptable option.

### 1.3 Eliminate the unsafe casts *(P0-2/3/4)*

- `NthPseudoClass.match` / `OnlyChildPseudoClass.match`: replace
  `(node as Element)` with a `if (node is! Element) return false;` guard.
- `query()`: replace `_queryNode(...) as Element?` with a type-safe walk that only
  ever considers `Element` nodes.
- **Systemic fix:** every `Sel.match` must begin with an `Element` check. Add a
  `MatchBase` mixin providing `bool matchElement(Element e)` and a final
  `match(Node n) => n is Element && matchElement(n)`, then migrate all ~150 classes.
  This fixes the class of bug, not just the three reported sites.
- Sweep for the same pattern: `grep -n "as Element" lib/`.

### 1.4 Make the cache honest and bounded *(P0-5)*

- Either implement real LRU (`dart:collection` `LinkedHashMap` with
  `remove`/re-`put` on hit and eviction of `.keys.first` when full), or rename to
  `_maxCacheEntries` with a comment stating it is a bounded flush cache.
- Expose `clearSelectorCache()` publicly for long-lived hosts.
- Do **not** cache selectors above a length threshold, to blunt cache-thrash attacks.

**Exit criteria:** probes A1–A3, E1–E4, E6–E7 green; `--include-fatal` completes in
milliseconds; watchdog tests pass. **Ship 0.8.0.**

---

## Phase 2 — Correctness (P1) → **v0.9.0**

### 2.1 Relative selectors in `:has()` *(P1-1)*

Highest-value functional fix; `:has()` is the flagship L4 selector.

- Add `Parser.parseRelativeSelectorList()`: accepts an optional leading `>`, `+`, `~`
  and produces a `RelativeSelector(combinator, selector)`.
- `HasPseudoClass.match` dispatches on the combinator:
  | Combinator | Search space |
  | --- | --- |
  | *(none)* | all descendants |
  | `>` | direct element children |
  | `+` | next element sibling |
  | `~` | all following element siblings |
- Guard against pathological nesting with a configurable depth limit.

### 2.2 Fix the wrong-answer pseudo-classes *(P1-2 … P1-12)*

| Fix | Change |
| --- | --- |
| `.class` case *(P1-2)* | Drop `toLowerCase()`; compare exactly. Add `caseSensitive: false` opt-in for quirks mode. |
| `:open` *(P1-3)* | Require the `open` attribute on `details`/`dialog`; `select` is runtime-only → report as undecidable. |
| `:default` *(P1-4)* | `option` → `selected`; `input[type=checkbox\|radio]` → `checked`; `button[type=submit]`/first submit control in a form. |
| `:enabled` *(P1-5)* | Restrict to `button, input, select, textarea, optgroup, option, fieldset` + form-associated custom elements; drop the blanket `return true`. |
| `:optional` *(P1-6)* | Restrict to `input, select, textarea` before negating `required`. |
| Bare pseudo-elements *(P1-7)* | `CompoundSelector.match` returns `false` when `selectors.isEmpty && pseudoElement.isNotEmpty`. |
| `:root` *(P1-11)* | Require `node is Element && node.parentNode is Document`. |
| `:picture-in-picture` *(P1-12)* | Demote to undecidable rather than matching all `video`/`iframe`. |
| `:visited` | Keep `false` — correct, privacy-mandated. Document as intentional. |

### 2.3 `queryAll` / `query` descendant semantics *(P1-8)*

- Exclude the root from results, matching `querySelectorAll`.
- **Breaking** — call out in CHANGELOG with a migration note; add `includeSelf: false`
  as an opt-in escape hatch for anyone relying on current behaviour.
- Convert the recursive walkers to an explicit stack to remove the stack-overflow
  ceiling on deep documents.

### 2.4 CSS escape decoding *(P1-9)*

- Add `_decodeEscapes(String)`: hex escapes (`\26` / `\000026`, optional trailing
  space) → code point; `\X` → literal `X`.
- Apply in `parseIdentifier`, `parseName`, and `parseString`.
- **Store decoded values, serialize re-escaped** — add `_escapeIdent()` for `toString()`
  so `.foo\.bar` survives a round trip.

**Exit criteria:** probes C1–C10 green. **Ship 0.9.0.**

---

## Phase 3 — API, serialization, specificity (P2) → **v1.0.0-dev**

### 3.1 Serialization round-trip *(P2-1/2/3)*

- **P2-1:** change `r'[$name$="$value"]'` to a normal interpolated string. One character.
- **P2-2:** in both `CombinedSelector.toString` and `Serializer.serialize`, emit
  `'$first $second'` for descendant and `'$first $comb $second'` otherwise.
- **P2-3:** rewrite `NthPseudoClass.toString` and `HeadingPseudoClass.toString` to emit
  canonical `an+b` (`2n+1`, `-n+3`, `n`, `3`, `odd`/`even` preserved) with balanced parens.
- **Delete `Serializer` entirely.** It duplicates every `toString()` and re-implements
  the same bugs. Keep the top-level `serialize(sel) => sel.toString()` for compatibility.
- **Property test:** for every selector in the corpus,
  `serialize(parse(s))` must parse, and `parse(serialize(parse(s)))` must equal
  `parse(s)` structurally. Non-negotiable gate.

### 3.2 Specificity *(P2-4/5)*

- Model the universal selector as a distinct `UniversalSelector` with `(0,0,0)`,
  separate from `TagSelector`.
- `:has()` → `Specificity(0,1,0) + argument.specificity`.
- Verify `:is()`/`:not()` take the **maximum** across the argument list (currently
  delegated to `SelectorGroup.specificity`, which is correct — add tests to lock it).
- Add a table-driven test against the worked examples in the Selectors L4 spec.

### 3.3 `:matches()` regex plumbing *(P2-6)*

- Stop round-tripping the pattern through a `String`. Have `parsePseudoclassSelector`
  return a typed payload (a small sealed `PseudoArg` hierarchy: `NthArg`, `RegexArg`,
  `SelectorArg`, `IdentArg`, `StringArg`) instead of `(String?, String?, Sel?)`.
- Removes the `argument.contains('/')` heuristic and the `'a/b'` string encoding for
  nth — both are fragile stringly-typed hacks.

### 3.4 Resolve the `Matcher` collision *(P2-7)*

- Delete the `Matcher` interface; fold `match`/`specificity`/`pseudoElement` into `Sel`.
  `Sel extends Matcher` adds only `toString()`, so nothing is lost.
- If an external name is still wanted, export it as `CascadiaMatcher`.
- **Breaking** — document in the 1.0.0 migration notes.

### 3.5 Represent undecidable selectors honestly *(§2.2B)*

The structural fix for the entire "Limitations" section.

- Introduce `MatchContext`: optional runtime facts a caller can supply —
  `hoveredElement`, `focusedElement`, `currentUrl`, `visitedUrls`, `customElementRegistry`,
  `shadowRoots`, `viewTransitionTypes`.
- Extend the interface with `bool matchWith(Node, MatchContext)`; keep
  `match(node) => matchWith(node, MatchContext.empty)`.
- Give every selector a `MatchSupport` classification:
  `decidable` · `requiresContext` · `neverDecidable` (e.g. `:visited`).
- Add `Sel.undecidableParts` so callers can inspect what a selector needs, and an
  optional `strict: true` mode that throws instead of silently returning `false`.
- `:hover`, `:focus`, `:target`, `:lang` (via context), `:local-link`, `:defined`, and
  the shadow-DOM family become genuinely usable when the caller supplies context.

### 3.6 Collapse the pseudo-class explosion *(§2.2A)*

- Delete the **31 dead `*PseudoElement` classes** (never constructed) and model
  pseudo-elements as a single `PseudoElementSelector(name, argument)` with a validated
  name registry — this also fixes the fact that `::bogus` is currently accepted unchecked.
- Replace the ~90 identical `return false` stubs with one
  `UndecidablePseudoClass(name, reason)` parameterised by name.
- Reject unknown pseudo-classes at parse time; add `allowUnknownPseudoClasses: true`
  for forward compatibility *(fixes P2-8 / §2.2C)*.
- Extract shared `_allText`/`_ownText` into a `TextContent` helper *(§2.2D)*.
- Expected: `pseudo_classes.dart` from **2107 → ~600 LOC** with more real behaviour.

---

## Phase 4 — Tests, docs, packaging (P3) → **v1.0.0**

### 4.1 Test suite rebuild

Target **≥90% line coverage** on `lib/src`, verified in CI via `dart test --coverage`.

| Suite | Content |
| --- | --- |
| `parser_test.dart` | Valid corpus parses; **invalid corpus all throw `FormatException`**; every test watchdogged |
| `roundtrip_test.dart` | Property test from §3.1 |
| `specificity_test.dart` | Table-driven against the L4 spec |
| `matching_test.dart` | Every *decidable* pseudo-class, positive **and negative**, exercised through `queryAll` on markup **containing text nodes, comments, and a doctype** |
| `context_test.dart` | `MatchContext`-dependent selectors |
| `fuzz_test.dart` | Random strings + mutated corpus; asserts terminate-or-throw, never hang |
| `regression_test.dart` | One test per audit ID (`P0-1` … `P3-6`) |

Remove the tests that assert stubs return `false`; replace with capability assertions.

### 4.2 Documentation *(P3-1, P3-4)*

- **Fix the README's first example** — it does not compile today. Use
  `import 'package:html/parser.dart' as html;` and pass a `String` to `queryAll`.
- **Compile-check the docs:** move every snippet into `example/` and add a CI step that
  analyzes them, so documentation cannot rot again.
- Correct the API reference: `queryAll(Node, String) → List<Element>`,
  `compile(String) → Selector`, `query(Node, String) → Element?`.
- Replace the prose "Limitations" section with a generated capability matrix
  (selector · support level · notes) driven by the §3.5 classification, so the docs
  cannot drift from the code.
- Update the install line to the current version; add a 0.x → 1.0 migration guide
  covering `queryAll` root exclusion, `Matcher` removal, and class-name case sensitivity.

### 4.3 Packaging *(P3-2/3/5)*

- **`.pubignore`** — add `doc/`, `IDEA.md`, `doc_warnings.txt`, `test/`, `.github/`.
  Note that `.pubignore` *overrides* `.gitignore` per directory, which is exactly why
  `doc/` ships today despite being git-ignored. Verify with `--dry-run`; expect the
  archive to fall from **411 KB → well under 50 KB**.
- Delete the committed `doc/api` tree (800 files) and `doc_warnings.txt`; regenerate on
  demand. Decide whether `IDEA.md` belongs in the repo at all.
- **`example/pubspec.yaml`** — replace `cascadia: ^0.1.0` with a
  `path: ../` dependency so the example actually resolves and CI can run it.
- Version: go **0.8.0 → 0.9.0 → 1.0.0**, keeping increments explicable after the
  0.6.9 → 0.7.6 jump pub flagged.
- Add `topics: [css, selector, html, parser, dom]` and an `issue_tracker` URL to
  `pubspec.yaml`.
- Run `dart format .` — `lib/src/combined_selector.dart` is currently unformatted
  (trailing whitespace at line 123).

---

## Phase 5 — Verified publisher transfer

Do this **only after Phase 1 ships**, since the transfer is irreversible.

1. **Create the publisher.** pub.dev → user menu → *Create Publisher* → enter
   `ayoubzulfiqar.com` → complete Google Search Console DNS verification.
   Allow a few hours for DNS propagation.
2. **Verify prerequisites.** You must be an uploader of `cascadia` *and* an admin of the
   publisher.
3. **Transfer.** `https://pub.dev/packages/cascadia` → *Admin* tab → enter
   `ayoubzulfiqar.com` → **Transfer to Publisher**.
   ⚠️ Irreversible — a package cannot be transferred back to an individual account.
4. **Confirm.** `GET /api/packages/cascadia/publisher` should return
   `{"publisherId":"ayoubzulfiqar.com"}` and the page should show the verified badge
   instead of *"unverified uploader"*.
5. **Invite a second admin** — pub.dev explicitly recommends this so the org retains
   access.
6. Subsequent releases publish normally with `dart pub publish`.

> Note: `dart pub publish` cannot publish a *new* package directly to a publisher —
> transfer is the documented path, and `cascadia` is already published, so step 3 applies.

---

## Sequencing and effort

| Phase | Scope | Effort | Version | Breaking |
| --- | --- | --- | --- | --- |
| 0 | CI + harness + watchdog | 0.5 d | — | no |
| 1 | Hangs, crashes, cache | 2–3 d | **0.8.0** | minor |
| 2 | Matching correctness | 3–4 d | **0.9.0** | yes (`queryAll`) |
| 3 | API, serialization, specificity | 4–6 d | 1.0.0-dev | yes (`Matcher`) |
| 4 | Tests, docs, packaging | 3–4 d | **1.0.0** | no |
| 5 | Publisher transfer | 0.5 d + DNS | — | no |

**Total ≈ 13–18 engineering days.** Phases 1 and 2 deliver most of the user-visible
value; Phase 3 is the investment that makes the 1.0 API stable enough to commit to.

### Risk register

| Risk | Mitigation |
| --- | --- |
| `package:html` cannot resolve namespaces adequately | Fall back to explicit `UnsupportedError` + doc correction (§1.2); never hang |
| `queryAll` change breaks existing users | Small user base; `includeSelf` escape hatch; loud CHANGELOG entry |
| `MatchContext` over-engineers the API | Keep `match(node)` working unchanged; context is purely additive |
| Publisher transfer done too early | Gate on Phase 1 — do not attach a verified identity to a package that hangs |

---

## Definition of done

- [ ] `dart run tool/audit_probe.dart` → **28 pass / 0 fail**
- [ ] `--include-fatal` completes in milliseconds
- [ ] `dart analyze --fatal-infos` clean; `dart format --set-exit-if-changed` clean
- [ ] Coverage ≥90% on `lib/src`
- [ ] Fuzz suite: 100k inputs, zero hangs, zero non-`FormatException` throws
- [ ] Every README snippet compiles in CI
- [ ] `--dry-run` archive < 50 KB with no `doc/`, `IDEA.md`, or `doc_warnings.txt`
- [ ] `/api/packages/cascadia/publisher` → `{"publisherId":"ayoubzulfiqar.com"}`
