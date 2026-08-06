import 'package:html/dom.dart';

/// Runtime facts a caller can supply so that otherwise-undecidable selectors
/// can be evaluated.
///
/// Addresses audit finding **§2.2B**: a static DOM cannot know what is hovered,
/// focused, visited or targeted, so the library used to return `false` for
/// those selectors. `false` is indistinguishable from a genuine non-match, so
/// callers could not tell "nothing matched" from "not implemented".
///
/// With a context the caller supplies what it knows and gets correct answers:
///
/// ```dart
/// final ctx = MatchContext(focused: someElement);
/// parse(':focus').matchWith(element, ctx);
/// ```
class MatchContext {
  /// The element currently hovered by a pointer, if any.
  ///
  /// `:hover` matches this element and all of its ancestors, per CSS.
  final Element? hovered;

  /// The element that currently has keyboard focus.
  final Element? focused;

  /// Whether [focused] should also satisfy `:focus-visible`.
  final bool focusVisible;

  /// The element currently being activated (mouse/keyboard down).
  final Element? active;

  /// The URL fragment target element.
  ///
  /// When null, [currentUrl]'s fragment is matched against element IDs.
  final Element? target;

  /// The `:scope` element for a scoped query.
  final Element? scope;

  /// The document's current URL, used by `:target`, `:local-link` and `:visited`.
  final Uri? currentUrl;

  /// URLs known to have been visited, used by `:visited`.
  final Set<String> visitedUrls;

  /// Custom element tag names registered in the custom element registry.
  final Set<String> definedElements;

  /// Custom states per element, used by `:state(name)`.
  final Map<Element, Set<String>> customStates;

  /// Active view transition type names.
  final Set<String> activeViewTransitionTypes;

  /// Whether a view transition is currently running.
  final bool inViewTransition;

  /// Elements that are currently in an indeterminate state.
  final Set<Element> indeterminate;

  /// Elements the user agent has autofilled.
  final Set<Element> autofilled;

  /// Elements the user has interacted with, used by `:user-valid`/`:user-invalid`.
  final Set<Element> userInteracted;

  /// Elements currently rendered fullscreen.
  final Set<Element> fullscreen;

  /// Elements currently displayed as an open popover.
  final Set<Element> openPopovers;

  /// When true, evaluating a selector that cannot be decided with the
  /// information available throws [UndecidableSelectorError] instead of
  /// silently returning `false`.
  final bool strict;

  /// Creates a matching context. Every field is optional.
  const MatchContext({
    this.hovered,
    this.focused,
    this.focusVisible = true,
    this.active,
    this.target,
    this.scope,
    this.currentUrl,
    this.visitedUrls = const <String>{},
    this.definedElements = const <String>{},
    this.customStates = const <Element, Set<String>>{},
    this.activeViewTransitionTypes = const <String>{},
    this.inViewTransition = false,
    this.indeterminate = const <Element>{},
    this.autofilled = const <Element>{},
    this.userInteracted = const <Element>{},
    this.fullscreen = const <Element>{},
    this.openPopovers = const <Element>{},
    this.strict = false,
  });

  /// A context carrying no runtime information.
  static const MatchContext empty = MatchContext();

  /// A context that throws on selectors it cannot decide.
  static const MatchContext strictEmpty = MatchContext(strict: true);
}

/// Thrown when a selector cannot be decided and [MatchContext.strict] is set.
class UndecidableSelectorError extends Error {
  /// The selector that could not be decided, e.g. `:hover`.
  final String selector;

  /// Why it could not be decided.
  final String reason;

  /// Creates the error.
  UndecidableSelectorError(this.selector, this.reason);

  @override
  String toString() =>
      'UndecidableSelectorError: cannot evaluate "$selector" — $reason. '
      'Supply the required state via MatchContext, or set strict: false to '
      'treat it as a non-match.';
}
