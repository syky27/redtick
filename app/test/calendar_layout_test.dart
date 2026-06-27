import 'package:flutter_test/flutter_test.dart';
import 'package:redtick/src/ui/screens/calendar_layout.dart';

void main() {
  ({DateTime start, DateTime end}) iv(int sh, int sm, int eh, int em) => (
        start: DateTime(2026, 1, 1, sh, sm),
        end: DateTime(2026, 1, 1, eh, em),
      );

  test('empty input returns empty', () {
    expect(packOverlapColumns(const []), isEmpty);
  });

  test('non-overlapping intervals are all full width (columns: 1)', () {
    final r = packOverlapColumns([iv(9, 0, 10, 0), iv(10, 0, 11, 0), iv(11, 0, 12, 0)]);
    expect(r.every((e) => e.columns == 1 && e.col == 0), isTrue);
  });

  test('two overlapping intervals get two side-by-side columns', () {
    final r = packOverlapColumns([iv(9, 0, 10, 0), iv(9, 30, 10, 30)]);
    expect(r[0].columns, 2);
    expect(r[1].columns, 2);
    expect({r[0].col, r[1].col}, {0, 1});
  });

  test('three concurrent intervals get three columns', () {
    final r = packOverlapColumns([iv(9, 0, 10, 0), iv(9, 15, 10, 15), iv(9, 30, 10, 30)]);
    expect(r.every((e) => e.columns == 3), isTrue);
    expect({r[0].col, r[1].col, r[2].col}, {0, 1, 2});
  });

  test('chain A-B-C: A and C disjoint but both overlap B -> two columns, C reuses A column', () {
    final a = iv(9, 0, 10, 0);
    final b = iv(9, 30, 10, 30);
    final c = iv(10, 0, 11, 0); // touches A (no overlap), overlaps B
    final r = packOverlapColumns([a, b, c]);
    expect(r[0].columns, 2);
    expect(r[1].columns, 2);
    expect(r[2].columns, 2);
    expect(r[0].col, 0); // A
    expect(r[1].col, 1); // B
    expect(r[2].col, 0); // C reuses A's freed column
  });

  test('touching intervals (end == start) are not overlapping', () {
    final r = packOverlapColumns([iv(9, 0, 10, 0), iv(10, 0, 11, 0)]);
    expect(r.every((e) => e.columns == 1 && e.col == 0), isTrue);
  });

  test('results are aligned to input order regardless of sort order', () {
    final later = iv(9, 30, 10, 30);
    final earlier = iv(9, 0, 10, 0);
    final r = packOverlapColumns([later, earlier]); // out of order on purpose
    expect(r[0].columns, 2);
    expect(r[1].columns, 2);
    expect(r[1].col, 0); // earlier sorts first -> column 0
    expect(r[0].col, 1); // later -> column 1
  });

  test('a lone entry inside the same day is still full width', () {
    final r = packOverlapColumns([iv(14, 0, 15, 0)]);
    expect(r.single.columns, 1);
    expect(r.single.col, 0);
  });

  group('packOverlapColumnsIgnoringShort', () {
    ({DateTime start, DateTime end}) sec(int h, int m, int s, int durSec) {
      final start = DateTime(2026, 1, 1, h, m, s);
      return (start: start, end: start.add(Duration(seconds: durSec)));
    }

    const min1 = Duration(seconds: 60);

    test('few-second blips do not narrow a long overlapping entry', () {
      // The real Jun-25 case: a ~15min entry with 11s and 6s blips on its tail.
      final long = sec(22, 34, 37, 935);
      final blip1 = sec(22, 49, 55, 11);
      final blip2 = sec(22, 50, 0, 6);
      final r = packOverlapColumnsIgnoringShort([long, blip1, blip2], min1);
      expect(r[0].columns, 1, reason: 'long entry stays full width');
      expect(r[0].col, 0);
      expect(r[1].columns, 1, reason: 'blip is full width, claims no column');
      expect(r[2].columns, 1);
    });

    test('two long, genuinely-overlapping entries still split into columns', () {
      final r = packOverlapColumnsIgnoringShort(
          [iv(9, 0, 10, 0), iv(9, 30, 10, 30)], min1);
      expect(r[0].columns, 2);
      expect(r[1].columns, 2);
      expect({r[0].col, r[1].col}, {0, 1});
    });

    test('only long overlappers count toward the column total', () {
      final a = iv(9, 0, 11, 0); // long
      final b = iv(9, 30, 10, 30); // long, overlaps a
      final blip = sec(9, 45, 0, 10); // 10s, inside both
      final r = packOverlapColumnsIgnoringShort([a, b, blip], min1);
      expect(r[0].columns, 2);
      expect(r[1].columns, 2);
      expect(r[2].columns, 1, reason: 'blip stays full width');
      expect(r[2].col, 0);
    });

    test('an exactly-threshold entry still participates', () {
      final a = iv(9, 0, 10, 0);
      final b = sec(9, 30, 0, 60); // exactly 60s, overlaps a
      final r = packOverlapColumnsIgnoringShort([a, b], min1);
      expect(r[0].columns, 2);
      expect(r[1].columns, 2);
    });
  });
}
