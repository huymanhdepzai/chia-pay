/// Cách chia một khoản chi.
enum SplitType {
  equal('equal', 'Chia đều'),
  exact('exact', 'Số tiền'),
  percent('percent', 'Phần trăm');

  final String value;
  final String label;

  const SplitType(this.value, this.label);

  static SplitType fromValue(String? value) {
    return SplitType.values.firstWhere((t) => t.value == value, orElse: () => SplitType.equal);
  }
}

class SplitException implements Exception {
  final String message;

  const SplitException(this.message);

  @override
  String toString() => message;
}

/// Tính phần tiền của từng người, luôn đảm bảo tổng các phần bằng đúng số tiền gốc
/// (sai số 0 đồng). Tiền được lưu bằng số nguyên.
class SplitCalculator {
  /// 100% tính theo basis point (1% = 100) để tránh sai số số thực.
  static const int fullPercentBp = 10000;

  const SplitCalculator._();

  /// Chia đều. Phần dư (amount % n) được cộng 1 đơn vị cho những người đầu danh sách.
  /// VD: 100.000 cho 3 người → 33.334, 33.333, 33.333.
  static Map<int, int> equal(int amount, List<int> memberIds) {
    _validateAmount(amount);
    if (memberIds.isEmpty) {
      throw const SplitException('Cần chọn ít nhất một người tham gia');
    }
    final base = amount ~/ memberIds.length;
    final remainder = amount % memberIds.length;
    return {
      for (var i = 0; i < memberIds.length; i++) memberIds[i]: base + (i < remainder ? 1 : 0),
    };
  }

  /// Chia theo số tiền tùy chỉnh. Tổng phải bằng đúng [amount].
  static Map<int, int> exact(int amount, Map<int, int> amounts) {
    _validateAmount(amount);
    final shares = Map.of(amounts)..removeWhere((_, v) => v == 0);
    if (shares.isEmpty) {
      throw const SplitException('Cần nhập số tiền cho ít nhất một người');
    }
    if (shares.values.any((v) => v < 0)) {
      throw const SplitException('Số tiền mỗi người không được âm');
    }
    final total = shares.values.fold<int>(0, (s, v) => s + v);
    if (total != amount) {
      throw SplitException('Tổng các phần ($total) phải bằng số tiền khoản chi ($amount)');
    }
    return shares;
  }

  /// Chia theo tỷ lệ phần trăm (basis point). Tổng tỷ lệ phải bằng 100%.
  /// Phần lẻ được phân bổ theo phương pháp phần dư lớn nhất để tổng khớp tuyệt đối.
  static Map<int, int> percent(int amount, Map<int, int> percentBp) {
    _validateAmount(amount);
    final weights = Map.of(percentBp)..removeWhere((_, v) => v == 0);
    if (weights.isEmpty) {
      throw const SplitException('Cần nhập tỷ lệ cho ít nhất một người');
    }
    if (weights.values.any((v) => v < 0)) {
      throw const SplitException('Tỷ lệ không được âm');
    }
    final totalBp = weights.values.fold<int>(0, (s, v) => s + v);
    if (totalBp != fullPercentBp) {
      throw SplitException('Tổng tỷ lệ phải bằng 100% (hiện tại ${formatPercent(totalBp)}%)');
    }

    final ids = weights.keys.toList();
    final shares = <int, int>{};
    final fractions = <int, int>{};
    var allocated = 0;
    for (final id in ids) {
      final raw = amount * weights[id]!;
      shares[id] = raw ~/ fullPercentBp;
      fractions[id] = raw % fullPercentBp;
      allocated += shares[id]!;
    }

    // Phân bổ phần còn thiếu cho những người có phần lẻ lớn nhất (ổn định theo thứ tự nhập).
    final order = List.of(ids)
      ..sort((a, b) {
        final cmp = fractions[b]!.compareTo(fractions[a]!);
        return cmp != 0 ? cmp : ids.indexOf(a).compareTo(ids.indexOf(b));
      });
    var leftover = amount - allocated;
    for (var i = 0; leftover > 0; i++, leftover--) {
      shares[order[i % order.length]] = shares[order[i % order.length]]! + 1;
    }
    return shares;
  }

  /// Chuyển chuỗi phần trăm người dùng nhập ("33.33" hoặc "33,33") sang basis point.
  static int? parsePercent(String input) {
    final value = double.tryParse(input.trim().replaceAll(',', '.'));
    if (value == null) return null;
    return (value * 100).round();
  }

  static String formatPercent(int bp) {
    final whole = bp ~/ 100;
    final frac = bp % 100;
    if (frac == 0) return '$whole';
    return '$whole.${frac.toString().padLeft(2, '0').replaceAll(RegExp(r'0$'), '')}';
  }

  static void _validateAmount(int amount) {
    if (amount <= 0) {
      throw const SplitException('Số tiền phải lớn hơn 0');
    }
  }
}
