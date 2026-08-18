import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:keyspot/keyspot.dart';

void main() {
  group('Rotation', () {
    test('converts degrees to radians', () {
      expect(const Rotation.degrees(180).radians, closeTo(math.pi, 1e-9));
      expect(const Rotation.degrees(-90).radians, closeTo(-math.pi / 2, 1e-9));
    });

    test('converts radians to degrees', () {
      expect(const Rotation.radians(math.pi).degrees, closeTo(180.0, 1e-9));
    });

    test('expresses angles the old magnitude heuristic could not', () {
      // 7 radians is greater than 2*pi, so a "greater than 2*pi means degrees"
      // guess would have silently reinterpreted it.
      expect(const Rotation.radians(7).radians, 7.0);
      expect(const Rotation.degrees(7).radians, closeTo(0.12217, 1e-5));
    });

    test('none is zero', () {
      expect(const Rotation.none().radians, 0.0);
      expect(const Rotation.none().isZero, isTrue);
    });

    test('equality is by angle', () {
      expect(const Rotation.degrees(180), const Rotation.radians(math.pi));
      expect(
        const Rotation.degrees(180).hashCode,
        const Rotation.radians(math.pi).hashCode,
      );
    });

    test('lerp takes the shortest path across the wrap point', () {
      final Rotation result = Rotation.lerp(
        const Rotation.degrees(350),
        const Rotation.degrees(10),
        0.5,
      );
      // Shortest path is +20 degrees, so the midpoint is 360, not 180.
      expect(result.degrees, closeTo(360.0, 1e-6));
    });

    test('lerp endpoints are exact', () {
      const Rotation a = Rotation.degrees(10);
      const Rotation b = Rotation.degrees(90);
      expect(Rotation.lerp(a, b, 0.0).degrees, closeTo(10.0, 1e-9));
      expect(Rotation.lerp(a, b, 1.0).degrees, closeTo(90.0, 1e-9));
    });
  });
}
