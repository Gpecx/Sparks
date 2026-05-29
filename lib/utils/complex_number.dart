import 'dart:math' as math;

class Complex {
  final double re;
  final double im;

  const Complex(this.re, this.im);

  static const Complex zero = Complex(0, 0);

  factory Complex.polar(double magnitude, double angleRadians) {
    return Complex(
      magnitude * math.cos(angleRadians),
      magnitude * math.sin(angleRadians),
    );
  }

  factory Complex.polarDegrees(double magnitude, double angleDegrees) {
    return Complex.polar(magnitude, angleDegrees * math.pi / 180.0);
  }

  double get magnitude => math.sqrt(re * re + im * im);

  double get angleRadians => math.atan2(im, re);

  double get angleDegrees => angleRadians * 180.0 / math.pi;

  Complex operator +(Complex other) => Complex(re + other.re, im + other.im);

  Complex operator -(Complex other) => Complex(re - other.re, im - other.im);

  Complex operator *(Complex other) =>
      Complex(re * other.re - im * other.im, re * other.im + im * other.re);

  Complex scale(double factor) => Complex(re * factor, im * factor);

  Complex divideBy(double divisor) => Complex(re / divisor, im / divisor);

  @override
  String toString() => '($re${im >= 0 ? '+' : ''}${im}j)';
}

// Operadores rotacionais para componentes simétricas
// a = 1∠120°, a² = 1∠240°
final Complex operatorA = Complex.polarDegrees(1, 120);
final Complex operatorA2 = Complex.polarDegrees(1, 240);
