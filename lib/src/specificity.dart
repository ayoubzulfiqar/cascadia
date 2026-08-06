/// CSS selector specificity as a triple `(a, b, c)`:
///
/// - `a` — ID selectors
/// - `b` — class, attribute and pseudo-class selectors
/// - `c` — type selectors and pseudo-elements
///
/// Compared lexicographically, `a` before `b` before `c`.
class Specificity implements Comparable<Specificity> {
  /// The ID-selector count.
  final int a;

  /// The class/attribute/pseudo-class count.
  final int b;

  /// The type-selector/pseudo-element count.
  final int c;

  /// Creates a specificity triple.
  const Specificity(this.a, this.b, this.c);

  /// Zero specificity, contributed by `:where()` and the universal selector.
  ///
  /// Audit **P2-4**: `*` used to be modelled as a type selector and wrongly
  /// scored `(0,0,1)`.
  static const zero = Specificity(0, 0, 0);

  /// Zero specificity. Prefer [zero].
  static const universal = zero;

  /// The specificity of a type selector or pseudo-element, `(0,0,1)`.
  static const typeSelector = Specificity(0, 0, 1);

  /// The specificity of a class, attribute or pseudo-class, `(0,1,0)`.
  static const classSelector = Specificity(0, 1, 0);

  /// The specificity of an ID selector, `(1,0,0)`.
  static const idSelector = Specificity(1, 0, 0);

  @override
  int compareTo(Specificity other) {
    if (a != other.a) return a - other.a;
    if (b != other.b) return b - other.b;
    return c - other.c;
  }

  /// Component-wise addition.
  Specificity operator +(Specificity other) =>
      Specificity(a + other.a, b + other.b, c + other.c);

  /// Whether this specificity is lower than [other].
  bool operator <(Specificity other) => compareTo(other) < 0;

  /// Whether this specificity is higher than [other].
  bool operator >(Specificity other) => compareTo(other) > 0;

  /// Whether this specificity is at most [other].
  bool operator <=(Specificity other) => compareTo(other) <= 0;

  /// Whether this specificity is at least [other].
  bool operator >=(Specificity other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Specificity && a == other.a && b == other.b && c == other.c;

  @override
  int get hashCode => Object.hash(a, b, c);

  @override
  String toString() => '[$a, $b, $c]';
}
