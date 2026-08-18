import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyspot/keyspot.dart';

void main() {
  const Rect rect = Rect.fromLTWH(100.0, 200.0, 80.0, 40.0);

  group('Anchor.key', () {
    test('resolves all nine Alignment constants', () {
      final Map<Alignment, Offset> expected = <Alignment, Offset>{
        Alignment.topLeft: const Offset(100.0, 200.0),
        Alignment.topCenter: const Offset(140.0, 200.0),
        Alignment.topRight: const Offset(180.0, 200.0),
        Alignment.centerLeft: const Offset(100.0, 220.0),
        Alignment.center: const Offset(140.0, 220.0),
        Alignment.centerRight: const Offset(180.0, 220.0),
        Alignment.bottomLeft: const Offset(100.0, 240.0),
        Alignment.bottomCenter: const Offset(140.0, 240.0),
        Alignment.bottomRight: const Offset(180.0, 240.0),
      };
      expected.forEach((Alignment alignment, Offset point) {
        final Anchor anchor = Anchor.key(GlobalKey(), alignment: alignment);
        expect(
          anchor.resolveWithin(rect, TextDirection.ltr),
          point,
          reason: '$alignment',
        );
      });
    });

    test('AlignmentDirectional flips with text direction', () {
      final Anchor anchor = Anchor.key(
        GlobalKey(),
        alignment: AlignmentDirectional.centerStart,
      );
      expect(
        anchor.resolveWithin(rect, TextDirection.ltr),
        const Offset(100.0, 220.0),
      );
      expect(
        anchor.resolveWithin(rect, TextDirection.rtl),
        const Offset(180.0, 220.0),
      );
    });

    test('is keyed', () {
      expect(Anchor.key(GlobalKey()).isKeyed, isTrue);
    });
  });

  group('Anchor.offset', () {
    test('ignores the rect', () {
      const Anchor anchor = Anchor.offset(Offset(7.0, 9.0));
      expect(anchor.resolveWithin(rect, TextDirection.ltr),
          const Offset(7.0, 9.0));
      expect(anchor.isKeyed, isFalse);
    });
  });

  group('KeyspotAnchorX', () {
    test('builds an equivalent anchor', () {
      final GlobalKey key = GlobalKey();
      expect(key.anchor(), Anchor.key(key));
      expect(
        key.anchor(Alignment.bottomCenter),
        Anchor.key(key, alignment: Alignment.bottomCenter),
      );
    });
  });
}
