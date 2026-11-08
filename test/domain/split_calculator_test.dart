import 'package:chia_pay/domain/services/split_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

int sum(Map<int, int> m) => m.values.fold(0, (s, v) => s + v);

void main() {
  group('SplitCalculator.equal', () {
    test('chia hết', () {
      expect(SplitCalculator.equal(240000, [1, 2, 3, 4]), {1: 60000, 2: 60000, 3: 60000, 4: 60000});
    });

    test('100.000đ cho 3 người: phân bổ phần dư, tổng khớp tuyệt đối', () {
      final shares = SplitCalculator.equal(100000, [1, 2, 3]);
      expect(shares, {1: 33334, 2: 33333, 3: 33333});
      expect(sum(shares), 100000);
    });

    test('số tiền nhỏ hơn số người', () {
      final shares = SplitCalculator.equal(2, [1, 2, 3]);
      expect(shares, {1: 1, 2: 1, 3: 0});
      expect(sum(shares), 2);
    });

    test('không có người tham gia hoặc số tiền <= 0 thì báo lỗi', () {
      expect(() => SplitCalculator.equal(100, []), throwsA(isA<SplitException>()));
      expect(() => SplitCalculator.equal(0, [1]), throwsA(isA<SplitException>()));
    });
  });

  group('SplitCalculator.exact', () {
    test('tổng khớp thì hợp lệ, bỏ qua người có phần 0', () {
      expect(SplitCalculator.exact(100, {1: 70, 2: 30, 3: 0}), {1: 70, 2: 30});
    });

    test('tổng lệch thì báo lỗi', () {
      expect(() => SplitCalculator.exact(100, {1: 70, 2: 20}), throwsA(isA<SplitException>()));
    });

    test('phần âm thì báo lỗi', () {
      expect(() => SplitCalculator.exact(100, {1: 120, 2: -20}), throwsA(isA<SplitException>()));
    });
  });

  group('SplitCalculator.percent', () {
    test('50/30/20', () {
      expect(SplitCalculator.percent(200000, {1: 5000, 2: 3000, 3: 2000}), {1: 100000, 2: 60000, 3: 40000});
    });

    test('33.33/33.33/33.34 với số lẻ vẫn khớp tổng', () {
      final shares = SplitCalculator.percent(100001, {1: 3333, 2: 3333, 3: 3334});
      expect(sum(shares), 100001);
      expect(shares[3], greaterThanOrEqualTo(shares[1]!));
    });

    test('phân bổ phần lẻ theo phần dư lớn nhất', () {
      // 10 * 1/3 = 3.333, 10 * 1/3 = 3.333, 10 * 1/3 = 3.334 -> người 3 có phần dư lớn nhất.
      final shares = SplitCalculator.percent(10, {1: 3333, 2: 3333, 3: 3334});
      expect(shares, {1: 3, 2: 3, 3: 4});
    });

    test('tổng tỷ lệ khác 100% thì báo lỗi', () {
      expect(() => SplitCalculator.percent(100, {1: 5000, 2: 4000}), throwsA(isA<SplitException>()));
    });

    test('parse và format phần trăm', () {
      expect(SplitCalculator.parsePercent('33,33'), 3333);
      expect(SplitCalculator.parsePercent('50'), 5000);
      expect(SplitCalculator.parsePercent('abc'), isNull);
      expect(SplitCalculator.formatPercent(3333), '33.33');
      expect(SplitCalculator.formatPercent(5000), '50');
      expect(SplitCalculator.formatPercent(1250), '12.5');
    });
  });
}
