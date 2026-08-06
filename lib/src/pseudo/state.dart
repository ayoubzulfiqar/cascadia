import 'package:html/dom.dart';

import '../dom_compat.dart';
import '../escape.dart';
import '../match_context.dart';
import '../matcher.dart';
import 'base.dart';

const Set<String> _linkTags = {'a', 'area', 'link'};

/// `:any-link` — any element with an `href`.
class AnyLinkPseudoClass extends PseudoClassSelector {
  /// Creates an `:any-link` selector.
  const AnyLinkPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) =>
      _linkTags.contains(element.tagName) &&
      element.attributes.containsKey('href');

  @override
  String toString() => ':any-link';
}

/// `:link` — a link that has not been visited.
class LinkPseudoClass extends PseudoClassSelector {
  /// Creates a `:link` selector.
  const LinkPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    if (!_linkTags.contains(element.tagName)) return false;
    final href = element.attributes['href'];
    if (href == null) return false;
    if (context.visitedUrls.isEmpty) return true;
    return !context.visitedUrls.contains(_resolve(href, context));
  }

  @override
  String toString() => ':link';
}

String _resolve(String href, MatchContext context) {
  final base = context.currentUrl;
  if (base == null) return href;
  try {
    return base.resolve(href).toString();
  } on FormatException {
    return href;
  }
}

/// `:visited` — a link the user has visited.
///
/// Browsers deliberately restrict this for privacy. It matches only when the
/// caller supplies [MatchContext.visitedUrls].
class VisitedPseudoClass extends PseudoClassSelector {
  /// Creates a `:visited` selector.
  const VisitedPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    if (!_linkTags.contains(element.tagName)) return false;
    final href = element.attributes['href'];
    if (href == null) return false;
    if (context.visitedUrls.isEmpty) {
      if (context.strict) {
        throw UndecidableSelectorError(
            ':visited', 'visited state is privacy-restricted');
      }
      return false;
    }
    return context.visitedUrls.contains(_resolve(href, context));
  }

  @override
  MatchSupport get support => MatchSupport.requiresContext;

  @override
  Set<String> get undecidableParts => {':visited'};

  @override
  String toString() => ':visited';
}

/// `:local-link` — a link pointing at the current document's URL.
class LocalLinkPseudoClass extends PseudoClassSelector {
  /// Creates a `:local-link` selector.
  const LocalLinkPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    final current = context.currentUrl;
    if (current == null) {
      if (context.strict) {
        throw UndecidableSelectorError(
            ':local-link', 'no currentUrl supplied in MatchContext');
      }
      return false;
    }
    if (!_linkTags.contains(element.tagName)) return false;
    final href = element.attributes['href'];
    if (href == null) return false;
    final target = current.resolve(href);
    return target.origin == current.origin && target.path == current.path;
  }

  @override
  MatchSupport get support => MatchSupport.requiresContext;

  @override
  Set<String> get undecidableParts => {':local-link'};

  @override
  String toString() => ':local-link';
}

/// `:target` — the element referenced by the URL fragment.
class TargetPseudoClass extends PseudoClassSelector {
  /// Creates a `:target` selector.
  const TargetPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    if (context.target != null) return identical(context.target, element);
    final fragment = context.currentUrl?.fragment;
    if (fragment == null || fragment.isEmpty) {
      if (context.strict) {
        throw UndecidableSelectorError(
            ':target', 'no target or currentUrl fragment in MatchContext');
      }
      return false;
    }
    return element.attributes['id'] == fragment;
  }

  @override
  MatchSupport get support => MatchSupport.requiresContext;

  @override
  Set<String> get undecidableParts => {':target'};

  @override
  String toString() => ':target';
}

/// `:target-within` — an element containing (or being) the fragment target.
class TargetWithinPseudoClass extends PseudoClassSelector {
  /// Creates a `:target-within` selector.
  const TargetWithinPseudoClass();

  static const TargetPseudoClass _target = TargetPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    if (_target.matchElement(element, context)) return true;
    final stack = <Element>[...element.children];
    while (stack.isNotEmpty) {
      final el = stack.removeLast();
      if (_target.matchElement(el, context)) return true;
      stack.addAll(el.children);
    }
    return false;
  }

  @override
  MatchSupport get support => MatchSupport.requiresContext;

  @override
  Set<String> get undecidableParts => {':target-within'};

  @override
  String toString() => ':target-within';
}

/// `:scope` — the reference element of a scoped query.
class ScopePseudoClass extends PseudoClassSelector {
  /// Creates a `:scope` selector.
  const ScopePseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    final scope = context.scope;
    if (scope == null) {
      if (context.strict) {
        throw UndecidableSelectorError(
            ':scope', 'no scope element supplied in MatchContext');
      }
      return false;
    }
    return identical(scope, element);
  }

  @override
  MatchSupport get support => MatchSupport.requiresContext;

  @override
  Set<String> get undecidableParts => {':scope'};

  @override
  String toString() => ':scope';
}

/// A user-interaction state selector: `:hover`, `:focus`, `:active` and kin.
class InteractionPseudoClass extends PseudoClassSelector {
  /// The CSS name, e.g. `:hover`.
  final String name;

  /// Creates an interaction-state selector.
  const InteractionPseudoClass(this.name);

  @override
  bool matchElement(Element element, MatchContext context) {
    Element? subject;
    var includeAncestors = false;
    switch (name) {
      case ':hover':
        subject = context.hovered;
        includeAncestors = true; // :hover applies up the ancestor chain
      case ':active':
        subject = context.active;
        includeAncestors = true;
      case ':focus':
        subject = context.focused;
      case ':focus-visible':
        subject = context.focusVisible ? context.focused : null;
      case ':focus-within':
        subject = context.focused;
        includeAncestors = true;
      default:
        subject = null;
    }
    if (subject == null) {
      if (context.strict) {
        throw UndecidableSelectorError(
            name, 'no corresponding element supplied in MatchContext');
      }
      return false;
    }
    if (identical(subject, element)) return true;
    if (!includeAncestors) return false;
    for (var p = subject.parentNode; p != null; p = p.parentNode) {
      if (identical(p, element)) return true;
    }
    return false;
  }

  @override
  MatchSupport get support => MatchSupport.requiresContext;

  @override
  Set<String> get undecidableParts => {name};

  @override
  String toString() => name;
}

/// `:open` — an open `<details>` or `<dialog>`.
class OpenPseudoClass extends PseudoClassSelector {
  /// Creates an `:open` selector.
  const OpenPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    // Audit P1-3: this used to match every <details>/<select>/<dialog>
    // regardless of whether it was actually open.
    switch (element.tagName) {
      case 'details':
      case 'dialog':
        return element.attributes.containsKey('open');
      case 'select':
        // Popup state is runtime-only.
        if (context.strict) {
          throw UndecidableSelectorError(
              ':open', 'select popup state is runtime-only');
        }
        return false;
      default:
        return false;
    }
  }

  @override
  String toString() => ':open';
}

/// `:modal` — an element blocking interaction with the rest of the page.
class ModalPseudoClass extends PseudoClassSelector {
  /// Creates a `:modal` selector.
  const ModalPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) =>
      element.tagName == 'dialog' &&
      element.attributes.containsKey('open') &&
      element.attributes.containsKey('modal');

  @override
  String toString() => ':modal';
}

/// `:popover-open` — a popover currently being shown.
class PopoverOpenPseudoClass extends PseudoClassSelector {
  /// Creates a `:popover-open` selector.
  const PopoverOpenPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    if (!element.attributes.containsKey('popover')) return false;
    if (context.openPopovers.isNotEmpty) {
      return context.openPopovers.contains(element);
    }
    if (context.strict) {
      throw UndecidableSelectorError(
          ':popover-open', 'popover visibility is runtime state');
    }
    return false;
  }

  @override
  MatchSupport get support => MatchSupport.requiresContext;

  @override
  Set<String> get undecidableParts => {':popover-open'};

  @override
  String toString() => ':popover-open';
}

/// `:fullscreen` — an element currently rendered fullscreen.
class FullscreenPseudoClass extends PseudoClassSelector {
  /// Creates a `:fullscreen` selector.
  const FullscreenPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    if (context.fullscreen.isNotEmpty) {
      return context.fullscreen.contains(element);
    }
    if (context.strict) {
      throw UndecidableSelectorError(
          ':fullscreen', 'fullscreen is runtime state');
    }
    return false;
  }

  @override
  MatchSupport get support => MatchSupport.requiresContext;

  @override
  Set<String> get undecidableParts => {':fullscreen'};

  @override
  String toString() => ':fullscreen';
}

/// `:defined` — a built-in element, or a registered custom element.
class DefinedPseudoClass extends PseudoClassSelector {
  /// Creates a `:defined` selector.
  const DefinedPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    final tag = element.tagName;
    // Built-in elements are always defined; only dashed names are custom.
    if (!tag.contains('-')) return true;
    if (context.definedElements.isNotEmpty) {
      return context.definedElements.contains(tag);
    }
    if (context.strict) {
      throw UndecidableSelectorError(
          ':defined', 'no custom element registry supplied in MatchContext');
    }
    return false;
  }

  @override
  MatchSupport get support => MatchSupport.requiresContext;

  @override
  Set<String> get undecidableParts => {':defined'};

  @override
  String toString() => ':defined';
}

/// `:state(name)` — a custom element's internal state.
class StatePseudoClass extends PseudoClassSelector {
  /// The custom state name.
  final String stateName;

  /// Creates a `:state()` selector.
  const StatePseudoClass(this.stateName);

  @override
  bool matchElement(Element element, MatchContext context) {
    final states = context.customStates[element];
    if (states == null) {
      if (context.strict) {
        throw UndecidableSelectorError(
            ':state($stateName)', 'no customStates supplied in MatchContext');
      }
      return false;
    }
    return states.contains(stateName);
  }

  @override
  MatchSupport get support => MatchSupport.requiresContext;

  @override
  Set<String> get undecidableParts => {':state($stateName)'};

  @override
  String toString() => ':state(${escapeCssIdent(stateName)})';
}

/// `:lang(tag)` — matches the element's language, inherited from ancestors.
class LangPseudoClass extends PseudoClassSelector {
  /// The language range to match, e.g. `en` or `en-GB`.
  final String language;

  /// Creates a `:lang()` selector.
  const LangPseudoClass(this.language);

  @override
  bool matchElement(Element element, MatchContext context) {
    for (Node? n = element; n != null; n = n.parentNode) {
      if (n is! Element) continue;
      final lang = n.attributes['lang'] ?? n.attributes['xml:lang'];
      if (lang != null && lang.isNotEmpty) return _matches(lang);
    }
    return false;
  }

  bool _matches(String elementLang) {
    final el = elementLang.toLowerCase();
    final req = language.toLowerCase();
    if (req == '*') return true;
    return el == req || el.startsWith('$req-');
  }

  @override
  String toString() => ':lang(${escapeCssIdent(language)})';
}

/// `:dir(ltr|rtl)` — matches an element's resolved text direction.
class DirPseudoClass extends PseudoClassSelector {
  /// Either `ltr` or `rtl`.
  final String direction;

  /// Creates a `:dir()` selector.
  const DirPseudoClass(this.direction);

  @override
  bool matchElement(Element element, MatchContext context) {
    for (Node? n = element; n != null; n = n.parentNode) {
      if (n is! Element) continue;
      final dir = n.attributes['dir']?.toLowerCase();
      if (dir == 'ltr' || dir == 'rtl') return dir == direction.toLowerCase();
      if (dir == 'auto') break;
    }
    // The default direction for HTML is ltr.
    return direction.toLowerCase() == 'ltr';
  }

  @override
  String toString() => ':dir($direction)';
}

/// `:input` — non-standard; any form control.
class InputPseudoClass extends PseudoClassSelector {
  /// Creates an `:input` selector.
  const InputPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) =>
      const {'input', 'select', 'textarea', 'button'}.contains(element.tagName);

  @override
  String toString() => ':input';
}

/// A media-element state selector such as `:muted` or `:playing`.
class MediaStatePseudoClass extends PseudoClassSelector {
  /// The CSS name, e.g. `:muted`.
  final String name;

  /// Creates a media-state selector.
  const MediaStatePseudoClass(this.name);

  static const Set<String> _mediaTags = {'audio', 'video'};

  @override
  bool matchElement(Element element, MatchContext context) {
    if (!_mediaTags.contains(element.tagName)) return false;
    switch (name) {
      case ':muted':
        return element.attributes.containsKey('muted');
      case ':paused':
        // Media with no autoplay starts paused.
        return element.attributes.containsKey('paused') ||
            !element.attributes.containsKey('autoplay');
      case ':playing':
        return element.attributes.containsKey('autoplay') &&
            !element.attributes.containsKey('paused');
      default:
        if (context.strict) {
          throw UndecidableSelectorError(name, 'media state is runtime-only');
        }
        return false;
    }
  }

  @override
  MatchSupport get support => switch (name) {
        ':muted' || ':paused' || ':playing' => MatchSupport.decidable,
        _ => MatchSupport.requiresContext,
      };

  @override
  Set<String> get undecidableParts =>
      support == MatchSupport.decidable ? const {} : {name};

  @override
  String toString() => name;
}
