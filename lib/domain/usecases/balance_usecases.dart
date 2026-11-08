import '../entities/expense.dart';
import '../entities/member.dart';
import '../entities/settlement.dart';

/// Tính số dư của từng thành viên từ dữ liệu gốc (khoản chi, phần chia và giao dịch đã xác nhận).
/// Không phụ thuộc database hay giao diện, để có thể kiểm thử độc lập.
class CalculateBalancesUseCase {
  const CalculateBalancesUseCase();

  List<MemberBalance> call({
    required List<Member> members,
    required List<ExpenseWithDetails> expenses,
    List<Settlement> settlements = const [],
  }) {
    final paid = <int, int>{for (final m in members) m.id: 0};
    final share = <int, int>{for (final m in members) m.id: 0};
    final sent = <int, int>{for (final m in members) m.id: 0};
    final received = <int, int>{for (final m in members) m.id: 0};

    for (final e in expenses) {
      if (paid.containsKey(e.expense.payerId)) {
        paid[e.expense.payerId] = paid[e.expense.payerId]! + e.expense.amount;
      }
      for (final s in e.shares) {
        if (share.containsKey(s.share.memberId)) {
          share[s.share.memberId] = share[s.share.memberId]! + s.share.amount;
        }
      }
    }

    for (final s in settlements) {
      if (sent.containsKey(s.fromMemberId)) sent[s.fromMemberId] = sent[s.fromMemberId]! + s.amount;
      if (received.containsKey(s.toMemberId)) received[s.toMemberId] = received[s.toMemberId]! + s.amount;
    }

    return members
        .map((m) => MemberBalance(
              member: m,
              paid: paid[m.id]!,
              share: share[m.id]!,
              sent: sent[m.id]!,
              received: received[m.id]!,
            ))
        .toList();
  }
}

/// Đề xuất danh sách giao dịch hoàn tiền ít hơn so với hoàn tiền theo từng hóa đơn.
///
/// Chia thành viên thành người nhận (số dư dương) và người trả (số dư âm), rồi ghép người
/// trả nợ nhiều nhất với người cần nhận nhiều nhất, số tiền bằng giá trị nhỏ hơn giữa hai bên.
/// Lặp lại tới khi mọi số dư được xử lý. Với n người có số dư khác 0, kết quả có tối đa n - 1 giao dịch.
class GenerateSettlementUseCase {
  const GenerateSettlementUseCase();

  List<SuggestedTransfer> call(List<MemberBalance> balances, {bool useRemaining = true}) {
    int balanceOf(MemberBalance b) => useRemaining ? b.remainingBalance : b.theoreticalBalance;

    final creditors = <_Entry>[];
    final debtors = <_Entry>[];
    for (final b in balances) {
      final value = balanceOf(b);
      if (value > 0) creditors.add(_Entry(b.member, value));
      if (value < 0) debtors.add(_Entry(b.member, -value));
    }

    // Sắp xếp giảm dần; khi bằng nhau giữ theo id để kết quả ổn định.
    int byAmountDesc(_Entry a, _Entry b) {
      final cmp = b.amount.compareTo(a.amount);
      return cmp != 0 ? cmp : a.member.id.compareTo(b.member.id);
    }

    creditors.sort(byAmountDesc);
    debtors.sort(byAmountDesc);

    final result = <SuggestedTransfer>[];
    var i = 0;
    var j = 0;
    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];
      final amount = debtor.amount < creditor.amount ? debtor.amount : creditor.amount;
      if (amount > 0) {
        result.add(SuggestedTransfer(from: debtor.member, to: creditor.member, amount: amount));
      }
      debtor.amount -= amount;
      creditor.amount -= amount;
      if (debtor.amount == 0) i++;
      if (creditor.amount == 0) j++;
    }
    return result;
  }
}

/// Tiến độ quyết toán của nhóm.
class SettlementProgress {
  /// Tổng số tiền cần chuyển theo số dư lý thuyết.
  final int totalToSettle;

  /// Số tiền còn phải chuyển.
  final int remaining;

  const SettlementProgress({required this.totalToSettle, required this.remaining});

  factory SettlementProgress.fromBalances(List<MemberBalance> balances) {
    final total = balances.fold<int>(0, (s, b) => s + (b.theoreticalBalance > 0 ? b.theoreticalBalance : 0));
    final remaining = balances.fold<int>(0, (s, b) => s + (b.remainingBalance > 0 ? b.remainingBalance : 0));
    return SettlementProgress(totalToSettle: total, remaining: remaining);
  }

  int get settled => (totalToSettle - remaining).clamp(0, totalToSettle);

  double get ratio => totalToSettle == 0 ? (remaining == 0 ? 1 : 0) : settled / totalToSettle;

  bool get isComplete => remaining == 0;
}

class _Entry {
  final Member member;
  int amount;

  _Entry(this.member, this.amount);
}
