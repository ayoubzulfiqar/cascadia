import 'matcher.dart';
import 'parser.dart';
import 'parser_attributes.dart';
import 'pseudo_classes.dart';

/// Pseudo-classes that take a selector list argument.
const Set<String> selectorArgPseudoClasses = {
  'not',
  'is',
  'where',
  'matches-any',
  'any',
  'has',
  'haschild',
  'has-child',
  'host',
  'host-context',
  'has-slotted',
};

/// Pseudo-classes that take an `an+b` argument.
const Set<String> anBPseudoClasses = {
  'nth-child',
  'nth-last-child',
  'nth-of-type',
  'nth-last-of-type',
  'heading',
};

/// Argument-less pseudo-classes that cannot be decided from a static DOM,
/// mapped to the reason why.
const Map<String, String> undecidablePseudoClasses = {
  'buffering': 'media buffering is runtime state',
  'seeking': 'media seeking is runtime state',
  'stalled': 'media network state is runtime-only',
  'volume-locked': 'volume lock is runtime state',
  'current': 'view-timeline position is runtime state',
  'past': 'view-timeline position is runtime state',
  'future': 'view-timeline position is runtime state',
  'target-current': 'view transition state is runtime-only',
  'target-before': 'view transition state is runtime-only',
  'target-after': 'view transition state is runtime-only',
  'active-view-transition': 'view transition state is runtime-only',
  'left': 'paged media page side is runtime-only',
  'right': 'paged media page side is runtime-only',
  'first': 'paged media page position is runtime-only',
  'in-range': 'range validity requires value evaluation',
  'out-of-range': 'range validity requires value evaluation',
  'valid': 'constraint validation is runtime-only',
  'invalid': 'constraint validation is runtime-only',
  'user-valid': 'requires user-interaction tracking',
  'user-invalid': 'requires user-interaction tracking',
  'blank': 'requires user-input state',
  'autofill': 'browser autofill state is runtime-only',
  'picture-in-picture': 'picture-in-picture is runtime state',
  'xr-overlay': 'requires an XR session',
  'interest-source': 'Interest API state is runtime-only',
  'interest-target': 'Interest API state is runtime-only',
  'in-container': 'container query context is runtime-only',
  'has-anchor': 'anchor positioning is runtime-only',
  'ancestor': 'relative selector placeholder',
  'parent': 'relative selector placeholder',
  'prev-sibling': 'relative selector placeholder',
  'next-sibling': 'relative selector placeholder',
};

/// Builds the [Sel] for a pseudo-class name and its parsed argument.
///
/// Audit **P2-8**: unknown names now raise a [FormatException] unless the
/// parser was created with `allowUnknownPseudoClasses: true`, so `:hovver`
/// fails loudly instead of silently never matching.
Sel buildPseudoClass(
  Parser parser,
  String name,
  String? rawArgument, {
  required bool allowUnknown,
}) {
  String requireArg() {
    if (rawArgument == null) {
      throw FormatException(':$name requires an argument', parser.source);
    }
    return rawArgument;
  }

  Sel parseSelectorArg() =>
      Parser(requireArg(), allowUnknownPseudoClasses: allowUnknown)
          .parseSelectorGroup();

  (int, int) parseAnBArg() {
    final sub = Parser(requireArg());
    final result = sub.parseAnB();
    sub.skipWhitespace();
    if (!sub.isAtEnd()) {
      throw FormatException(
          'Invalid an+b expression in :$name()', parser.source);
    }
    return result;
  }

  switch (name) {
    // Logical
    case 'not':
      return NotPseudoClass(parseSelectorArg());
    case 'is':
    case 'matches-any':
    case 'any':
      return IsPseudoClass(parseSelectorArg());
    case 'where':
      return WherePseudoClass(parseSelectorArg());
    case 'has':
      return HasPseudoClass(
          Parser(requireArg(), allowUnknownPseudoClasses: allowUnknown)
              .parseRelativeSelectorList());
    case 'haschild':
    case 'has-child':
      return HasChildPseudoClass(parseSelectorArg());

    // Text
    case 'contains':
      return ContainsPseudoClass(requireArg(), false);
    case 'containsown':
      return ContainsPseudoClass(requireArg(), true);
    case 'matches':
      return MatchesPseudoClass(Parser(requireArg()).parseRegex(), false);
    case 'matchesown':
      return MatchesPseudoClass(Parser(requireArg()).parseRegex(), true);

    // Structural
    case 'nth-child':
    case 'nth-last-child':
    case 'nth-of-type':
    case 'nth-last-of-type':
      final (a, b) = parseAnBArg();
      return NthPseudoClass(
        a: a,
        b: b,
        last: name.contains('last'),
        ofType: name.endsWith('of-type'),
      );
    case 'first-child':
      return NthPseudoClass.first();
    case 'last-child':
      return NthPseudoClass.last();
    case 'first-of-type':
      return NthPseudoClass.firstOfType();
    case 'last-of-type':
      return NthPseudoClass.lastOfType();
    case 'only-child':
      return const OnlyChildPseudoClass(ofType: false);
    case 'only-of-type':
      return const OnlyChildPseudoClass(ofType: true);
    case 'empty':
      return const EmptyPseudoClass();
    case 'root':
      return const RootPseudoClass();
    case 'heading':
      if (rawArgument == null) return const HeadingPseudoClass();
      final (ha, hb) = parseAnBArg();
      return HeadingPseudoClass(a: ha, b: hb);

    // Links and location
    case 'any-link':
      return const AnyLinkPseudoClass();
    case 'link':
      return const LinkPseudoClass();
    case 'visited':
      return const VisitedPseudoClass();
    case 'local-link':
      return const LocalLinkPseudoClass();
    case 'target':
      return const TargetPseudoClass();
    case 'target-within':
      return const TargetWithinPseudoClass();
    case 'scope':
      return const ScopePseudoClass();

    // Interaction
    case 'hover':
    case 'active':
    case 'focus':
    case 'focus-visible':
    case 'focus-within':
      return InteractionPseudoClass(':$name');

    // Forms
    case 'enabled':
      return const EnabledPseudoClass();
    case 'disabled':
      return const DisabledPseudoClass();
    case 'checked':
      return const CheckedPseudoClass();
    case 'default':
      return const DefaultPseudoClass();
    case 'required':
      return const RequiredPseudoClass(required: true);
    case 'optional':
      return const RequiredPseudoClass(required: false);
    case 'read-only':
      return const ReadOnlyPseudoClass(readWrite: false);
    case 'read-write':
      return const ReadOnlyPseudoClass(readWrite: true);
    case 'placeholder-shown':
      return const PlaceholderShownPseudoClass();
    case 'indeterminate':
      return const IndeterminatePseudoClass();
    case 'input':
      return const InputPseudoClass();

    // Display state
    case 'open':
      return const OpenPseudoClass();
    case 'modal':
      return const ModalPseudoClass();
    case 'fullscreen':
      return const FullscreenPseudoClass();
    case 'popover-open':
      return const PopoverOpenPseudoClass();
    case 'defined':
      return const DefinedPseudoClass();
    case 'state':
      return StatePseudoClass(requireArg());

    // Linguistic
    case 'lang':
      return LangPseudoClass(requireArg());
    case 'dir':
      final dir = requireArg().toLowerCase();
      if (dir != 'ltr' && dir != 'rtl') {
        throw FormatException(':dir() requires "ltr" or "rtl"', parser.source);
      }
      return DirPseudoClass(dir);

    // Media
    case 'muted':
    case 'paused':
    case 'playing':
      return MediaStatePseudoClass(':$name');

    // Shadow DOM
    case 'host':
      return HostPseudoClass(rawArgument == null ? null : parseSelectorArg());
    case 'host-context':
      return HostContextPseudoClass(parseSelectorArg());
    case 'has-slotted':
      return HasSlottedPseudoClass(
          rawArgument == null ? null : parseSelectorArg());

    // Anchor positioning
    case 'anchor':
      return UndecidablePseudoClass(
          rawArgument == null ? ':anchor' : ':anchor($rawArgument)',
          'anchor resolution is runtime-only');
    case 'active-view-transition-type':
      return UndecidablePseudoClass(
          ':active-view-transition-type(${requireArg()})',
          'view transition types are runtime state');

    default:
      final reason = undecidablePseudoClasses[name];
      if (reason != null) return UndecidablePseudoClass(':$name', reason);
      if (allowUnknown) return UnknownPseudoClass(name);
      throw FormatException(
          'Unknown pseudo-class ":$name". Pass '
          'allowUnknownPseudoClasses: true to accept it.',
          parser.source);
  }
}
