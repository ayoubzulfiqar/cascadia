import 'package:html/dom.dart';

import '../dom_compat.dart';
import '../match_context.dart';
import '../matcher.dart';
import 'base.dart';

/// Elements that `:enabled`/`:disabled` may apply to.
const Set<String> formControlTags = {
  'button',
  'input',
  'select',
  'textarea',
  'optgroup',
  'option',
  'fieldset',
};

/// Elements that accept user-entered values.
const Set<String> _editableTags = {'input', 'select', 'textarea'};

bool _inDisabledFieldset(Element element) {
  for (var p = element.parentNode; p != null; p = p.parentNode) {
    if (p is! Element) continue;
    if (p.tagName != 'fieldset' || !p.attributes.containsKey('disabled')) {
      continue;
    }
    // The first <legend> of a disabled fieldset is not itself disabled.
    final legend = p.children.where((c) => c.tagName == 'legend').firstOrNull;
    if (legend != null &&
        (identical(legend, element) || _isWithin(element, legend))) {
      continue;
    }
    return true;
  }
  return false;
}

bool _isWithin(Element element, Element ancestor) {
  for (var p = element.parentNode; p != null; p = p.parentNode) {
    if (identical(p, ancestor)) return true;
  }
  return false;
}

/// `:enabled` — a form control that is not disabled.
class EnabledPseudoClass extends PseudoClassSelector {
  /// Creates an `:enabled` selector.
  const EnabledPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    // Audit P1-5: this used to end in a blanket `return true`, so `:enabled`
    // matched <div>, <p> and every other non-form element.
    if (!formControlTags.contains(element.tagName)) return false;
    if (element.attributes.containsKey('disabled')) return false;
    return !_inDisabledFieldset(element);
  }

  @override
  String toString() => ':enabled';
}

/// `:disabled` — a form control that is disabled.
class DisabledPseudoClass extends PseudoClassSelector {
  /// Creates a `:disabled` selector.
  const DisabledPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    if (!formControlTags.contains(element.tagName)) return false;
    if (element.attributes.containsKey('disabled')) return true;
    return _inDisabledFieldset(element);
  }

  @override
  String toString() => ':disabled';
}

/// `:checked` — a checked checkbox/radio or a selected option.
class CheckedPseudoClass extends PseudoClassSelector {
  /// Creates a `:checked` selector.
  const CheckedPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    switch (element.tagName) {
      case 'input':
        final type = (element.attributes['type'] ?? '').toLowerCase();
        return (type == 'checkbox' || type == 'radio') &&
            element.attributes.containsKey('checked');
      case 'option':
        return element.attributes.containsKey('selected');
      default:
        return false;
    }
  }

  @override
  String toString() => ':checked';
}

/// `:default` — the default control within a form.
class DefaultPseudoClass extends PseudoClassSelector {
  /// Creates a `:default` selector.
  const DefaultPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    // Audit P1-4: the old version looked for a non-existent `default`
    // attribute and checked `checked` on <option> instead of `selected`.
    switch (element.tagName) {
      case 'option':
        return element.attributes.containsKey('selected');
      case 'input':
        final type = (element.attributes['type'] ?? '').toLowerCase();
        if (type == 'checkbox' || type == 'radio') {
          return element.attributes.containsKey('checked');
        }
        if (type == 'submit' || type == 'image') {
          return _isFirstSubmitOfForm(element);
        }
        return false;
      case 'button':
        final type = (element.attributes['type'] ?? 'submit').toLowerCase();
        return type == 'submit' && _isFirstSubmitOfForm(element);
      default:
        return false;
    }
  }

  bool _isFirstSubmitOfForm(Element element) {
    Element? form;
    for (var p = element.parentNode; p != null; p = p.parentNode) {
      if (p is Element && p.tagName == 'form') {
        form = p;
        break;
      }
    }
    if (form == null) return false;

    final stack = <Element>[...form.children];
    final queue = <Element>[];
    while (stack.isNotEmpty) {
      final el = stack.removeAt(0);
      queue.add(el);
      stack.insertAll(0, el.children);
    }
    for (final candidate in queue) {
      final tag = candidate.tagName;
      final type =
          (candidate.attributes['type'] ?? (tag == 'button' ? 'submit' : ''))
              .toLowerCase();
      final isSubmit = (tag == 'button' && type == 'submit') ||
          (tag == 'input' && (type == 'submit' || type == 'image'));
      if (isSubmit) return identical(candidate, element);
    }
    return false;
  }

  @override
  String toString() => ':default';
}

/// `:required` and `:optional`.
class RequiredPseudoClass extends PseudoClassSelector {
  /// Whether this is `:required` (true) or `:optional` (false).
  final bool required;

  /// Creates a requiredness selector.
  const RequiredPseudoClass({required this.required});

  @override
  bool matchElement(Element element, MatchContext context) {
    // Audit P1-6: `:optional` used to negate `required` for ANY element, so
    // it matched <div>. Both only apply to controls that can be required.
    if (!_editableTags.contains(element.tagName)) return false;
    return element.attributes.containsKey('required') == required;
  }

  @override
  String toString() => required ? ':required' : ':optional';
}

/// `:read-only` and `:read-write`.
class ReadOnlyPseudoClass extends PseudoClassSelector {
  /// Whether this is `:read-write` (true) or `:read-only` (false).
  final bool readWrite;

  /// Creates an editability selector.
  const ReadOnlyPseudoClass({required this.readWrite});

  @override
  bool matchElement(Element element, MatchContext context) {
    final tag = element.tagName;
    final disabled = element.attributes.containsKey('disabled');
    final readonly = element.attributes.containsKey('readonly');
    var editable = false;
    if (tag == 'input') {
      final type = (element.attributes['type'] ?? 'text').toLowerCase();
      const nonEditable = {
        'hidden',
        'checkbox',
        'radio',
        'button',
        'submit',
        'reset',
        'image',
        'range',
        'color',
        'file'
      };
      editable = !nonEditable.contains(type) && !disabled && !readonly;
    } else if (tag == 'textarea') {
      editable = !disabled && !readonly;
    } else if (element.attributes.containsKey('contenteditable')) {
      final v = (element.attributes['contenteditable'] ?? '').toLowerCase();
      editable = v != 'false';
    }
    return editable == readWrite;
  }

  @override
  String toString() => readWrite ? ':read-write' : ':read-only';
}

/// `:placeholder-shown` — a control displaying its placeholder text.
class PlaceholderShownPseudoClass extends PseudoClassSelector {
  /// Creates a `:placeholder-shown` selector.
  const PlaceholderShownPseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    final tag = element.tagName;
    if (tag != 'input' && tag != 'textarea') return false;
    final placeholder = element.attributes['placeholder'];
    if (placeholder == null || placeholder.isEmpty) return false;
    // The placeholder shows only while the control has no value.
    final value = element.attributes['value'];
    return value == null || value.isEmpty;
  }

  @override
  String toString() => ':placeholder-shown';
}

/// `:indeterminate` — requires runtime state supplied via [MatchContext].
class IndeterminatePseudoClass extends PseudoClassSelector {
  /// Creates an `:indeterminate` selector.
  const IndeterminatePseudoClass();

  @override
  bool matchElement(Element element, MatchContext context) {
    if (context.indeterminate.contains(element)) return true;
    // A radio group with no checked member is indeterminate.
    if (element.tagName == 'input' &&
        (element.attributes['type'] ?? '').toLowerCase() == 'radio') {
      final name = element.attributes['name'];
      if (name != null && name.isNotEmpty) {
        Node? root = element;
        while (root?.parentNode != null) {
          root = root!.parentNode;
        }
        if (root is Element || root is Document) {
          return !_radioGroupHasChecked(root!, name);
        }
      }
    }
    if (context.strict) {
      throw UndecidableSelectorError(':indeterminate',
          'indeterminate is a DOM property, not an attribute');
    }
    return false;
  }

  bool _radioGroupHasChecked(Node root, String name) {
    final stack = <Node>[root];
    while (stack.isNotEmpty) {
      final n = stack.removeLast();
      if (n is Element &&
          n.tagName == 'input' &&
          n.attributes['name'] == name &&
          n.attributes.containsKey('checked')) {
        return true;
      }
      stack.addAll(n.nodes);
    }
    return false;
  }

  @override
  MatchSupport get support => MatchSupport.requiresContext;

  @override
  Set<String> get undecidableParts => {':indeterminate'};

  @override
  String toString() => ':indeterminate';
}
