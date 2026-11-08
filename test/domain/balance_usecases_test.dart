import 'package:chia_pay/domain/entities/expense.dart';
import 'package:chia_pay/domain/entities/member.dart';
import 'package:chia_pay/domain/entities/settlement.dart';
import 'package:chia_pay/domain/services/split_calculator.dart';
import 'package:chia_pay/domain/usecases/balance_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

const an = Member(id: 1, groupId: 1, name: 'An');
const binh = Member(id: 2, groupId: 1, name: 'Bình');
const chi = Member(id: 3, groupId: 1, name: 'Chi');
const dung = Member(id: 4, groupId: 1, name: 'Dũng');
const members = [an, binh, chi, dung];

var _nextId = 1;

ExpenseWithDetails expense(Member payer, int amount, List<Member> participants) {
  final id = _nextId++;
  final split = SplitCalculator.equal(amount, participants.map((m) => m.id).toList());
  return ExpenseWithDetails(
    expense: Expense(
      id: id,
      groupId: 1,
      payerId: payer.id,
      name: 'Khoản $id',
      amount: amount,
      date: DateTime(2026, 1, 1),
      category: 'Khác',
      createdAt: DateTime(2026, 1, 1),
    ),
    payer: payer,
    shares: participants
        .map((m) => ExpenseShareWithMember(
              share: ExpenseShare(id: 0, expenseId: id, memberId: m.id, amount: split[m.id]!),
              member: m,
            ))
        .toList(),
  );
}

Settlement settlement(Member from, Member to, int amount) => Settlement(
      id: _nextId++,
      groupId: 1,
      fromMemberId: from.id,
      toMemberId: to.id,
      amount: amount,
      date: DateTime(2026, 1, 2),
      createdAt: DateTime(2026, 1, 2),
    );

int balanceOf(List<MemberBalance> balances, Member m) =>
    balances.firstWhere((b) => b.member.id == m.id).remainingBalance;

/// Ví dụ trong đề tài: An trả khách sạn, Bình trả ăn, Chi trả taxi (không có Bình).
final tripExpenses = [
  expense(an, 600000, members),
  expense(binh, 240000, members),
  expense(chi, 120000, [an, chi, dung]),
];

void main() {
  const calculate = CalculateBalancesUseCase();
  const generate = GenerateSettlementUseCase();

  group('CalculateBalancesUseCase', () {
    test('ví dụ chuyến du lịch 4 người', () {
      final balances = calculate(members: members, expenses: tripExpenses);

      expect(balances.map((b) => b.paid), [600000, 240000, 120000, 0]);
      expect(balances.map((b) => b.share), [250000, 210000, 250000, 250000]);
      expect(balances.map((b) => b.theoreticalBalance), [350000, 30000, -130000, -250000]);
    });

    test('tổng số dư toàn nhóm luôn bằng 0, kể cả khi chia không hết', () {
      final balances = calculate(
        members: members,
        expenses: [...tripExpenses, expense(dung, 100000, [an, binh, chi])],
      );
      expect(balances.fold<int>(0, (s, b) => s + b.theoreticalBalance), 0);
    });

    test('người trả nhưng không tham gia khoản chi', () {
      final balances = calculate(members: members, expenses: [expense(dung, 120000, [an, binh, chi])]);
      expect(balanceOf(balances, dung), 120000);
      expect(balanceOf(balances, an), -40000);
    });

    test('thành viên mới thêm sau khi đã có hóa đơn có số dư 0', () {
      const em = Member(id: 5, groupId: 1, name: 'Em');
      final balances = calculate(members: [...members, em], expenses: tripExpenses);
      expect(balanceOf(balances, em), 0);
    });

    test('giao dịch đã xác nhận làm giảm số tiền còn chưa quyết toán, số dư lý thuyết giữ nguyên', () {
      final balances = calculate(
        members: members,
        expenses: tripExpenses,
        settlements: [settlement(dung, an, 250000)],
      );
      final dungBalance = balances.firstWhere((b) => b.member.id == dung.id);
      expect(dungBalance.theoreticalBalance, -250000);
      expect(dungBalance.remainingBalance, 0);
      expect(balanceOf(balances, an), 100000);
    });

    test('hoàn tác giao dịch (xóa) khôi phục số dư', () {
      final before = calculate(members: members, expenses: tripExpenses);
      final after = calculate(members: members, expenses: tripExpenses, settlements: const []);
      expect(after.map((b) => b.remainingBalance), before.map((b) => b.remainingBalance));
    });

    test('sửa hoặc xóa khoản chi được tính lại từ dữ liệu gốc', () {
      final withoutTaxi = calculate(members: members, expenses: tripExpenses.sublist(0, 2));
      expect(withoutTaxi.map((b) => b.theoreticalBalance), [390000, 30000, -210000, -210000]);
    });
  });

  group('GenerateSettlementUseCase', () {
    test('ví dụ chuyến du lịch: 3 giao dịch, cân bằng toàn bộ', () {
      final balances = calculate(members: members, expenses: tripExpenses);
      final transfers = generate(balances);

      expect(transfers, const [
        SuggestedTransfer(from: dung, to: an, amount: 250000),
        SuggestedTransfer(from: chi, to: an, amount: 100000),
        SuggestedTransfer(from: chi, to: binh, amount: 30000),
      ]);
    });

    test('áp dụng các giao dịch đề xuất thì mọi số dư về 0', () {
      final expenses = [
        ...tripExpenses,
        expense(dung, 100000, [an, binh, chi]),
        expense(binh, 77777, members),
      ];
      final balances = calculate(members: members, expenses: expenses);
      final transfers = generate(balances);
      final settlements = transfers.map((t) => settlement(t.from, t.to, t.amount)).toList();
      final after = calculate(members: members, expenses: expenses, settlements: settlements);

      expect(after.every((b) => b.remainingBalance == 0), isTrue);
      expect(transfers.length, lessThanOrEqualTo(members.length - 1));
    });

    test('một người vừa cần nhận ở khoản này vừa cần trả ở khoản khác chỉ xuất hiện một chiều', () {
      final expenses = [expense(an, 300000, [an, binh, chi]), expense(binh, 600000, [an, binh, chi])];
      final transfers = generate(calculate(members: [an, binh, chi], expenses: expenses));
      // An cần nhận 200.000 ở khoản 1 nhưng cần trả 200.000 ở khoản 2 -> bù trừ về 0.
      expect(transfers, const [SuggestedTransfer(from: chi, to: binh, amount: 300000)]);
      for (final t in transfers) {
        expect(transfers.any((o) => o.from == t.to && o.to == t.from), isFalse);
      }
    });

    test('đã thanh toán một phần thì đề xuất phần còn lại', () {
      final balances = calculate(
        members: members,
        expenses: tripExpenses,
        settlements: [settlement(dung, an, 100000)],
      );
      final transfers = generate(balances);
      expect(transfers.first, const SuggestedTransfer(from: dung, to: an, amount: 150000));
    });

    test('nhóm đã cân bằng thì không có giao dịch', () {
      expect(generate(calculate(members: members, expenses: const [])), isEmpty);
    });
  });

  group('SettlementProgress', () {
    test('tiến độ theo số tiền đã chuyển', () {
      final balances = calculate(
        members: members,
        expenses: tripExpenses,
        settlements: [settlement(dung, an, 250000)],
      );
      final progress = SettlementProgress.fromBalances(balances);
      expect(progress.totalToSettle, 380000);
      expect(progress.remaining, 130000);
      expect(progress.settled, 250000);
      expect(progress.isComplete, isFalse);
    });

    test('nhóm không có khoản chi coi như đã hoàn tất', () {
      final progress = SettlementProgress.fromBalances(calculate(members: members, expenses: const []));
      expect(progress.isComplete, isTrue);
      expect(progress.ratio, 1);
    });
  });
}
