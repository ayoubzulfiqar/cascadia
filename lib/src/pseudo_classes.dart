/// Pseudo-class and pseudo-element selectors.
///
/// Audit **§2.2A**: this was a single 2107-line file defining ~150 classes,
/// 122 of whose bodies were a literal `return false` and 31 of which were
/// never constructed at all. It is now split by concern, with undecidable
/// selectors collapsed into [UndecidablePseudoClass] and pseudo-elements into
/// the single validated [PseudoElementSelector].
library;

export 'pseudo/base.dart';
export 'pseudo/elements.dart';
export 'pseudo/forms.dart';
export 'pseudo/logical.dart';
export 'pseudo/shadow.dart';
export 'pseudo/state.dart';
export 'pseudo/structural.dart';
