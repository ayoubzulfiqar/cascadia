/// Represents CSS selector specificity as a triple [A, B, C] where:
/// - A: number of ID selectors
/// - B: number of class selectors, attribute selectors, and pseudo-classes
/// - C: number of type selectors and pseudo-elements
///
/// Specificity is compared lexicographically: A > B > C.
class Specificity implements Comparable<Specificity> {
  final int a;
  final int b;
  final int c;

  const Specificity(this.a, this.b, this.c);

  /// The specificity of a universal selector (*) or pseudo-element (:where)
  static const universal = Specificity(0, 0, 0);

  /// The specificity of a type selector (div, p, etc.)
  static const typeSelector = Specificity(0, 0, 1);

  /// The specificity of a class, attribute, or pseudo-class selector
  static const classSelector = Specificity(0, 1, 0);

  /// The specificity of an ID selector
  static const idSelector = Specificity(1, 0, 0);

  /// Compare specificities lexicographically.
  ///
  /// Returns a negative integer if this < other,
  /// zero if equal, positive if this > other.
  @override
  int compareTo(Specificity other) {
    if (a != other.a) return a - other.a;
    if (b != other.b) return b - other.b;
    return c - other.c;
  }

  /// Add two specificities component-wise.
  Specificity operator +(Specificity other) {
    return Specificity(a + other.a, b + other.b, c + other.c);
  }

  /// Check if this specificity is less than another.
  bool operator <(Specificity other) => compareTo(other) < 0;

  /// Check if this specificity is greater than another.
  bool operator >(Specificity other) => compareTo(other) > 0;

  /// Check if this specificity equals another.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Specificity && a == other.a && b == other.b && c == other.c;
  }

  @override
  int get hashCode => Object.hash(a, b, c);

  @override
  String toString() => '[$a, $b, $c]';
}
