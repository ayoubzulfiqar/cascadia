# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
