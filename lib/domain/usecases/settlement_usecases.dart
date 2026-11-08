import 'package:equatable/equatable.dart';
import '../entities/expense.dart';
import '../entities/group.dart';
import '../entities/member.dart';
import '../entities/settlement.dart';
import '../repositories/expense_repository.dart';
import '../repositories/group_repository.dart';
import '../repositories/settlement_repository.dart';
import 'balance_usecases.dart';

class GetSettlementsByGroup {
  final SettlementRepository repository;

  GetSettlementsByGroup(this.repository);

  Future<List<Settlement>> call(int groupId) {
    return repository.getSettlementsByGroup(groupId);
  }
}

/// Đánh dấu một giao dịch đã thanh toán (lưu ngày, số tiền và ghi chú xác nhận).
/// Ứng dụng không tự chuyển tiền; người dùng tự thực hiện giao dịch bên ngoài.
class AddSettlement {
  final SettlementRepository repository;

  AddSettlement(this.repository);

  Future<int> call(Settlement settlement) {
    if (settlement.amount <= 0) {
      throw const DomainException('Số tiền phải lớn hơn 0');
    }
    if (settlement.fromMemberId == settlement.toMemberId) {
      throw const DomainException('Người trả và người nhận phải khác nhau');
    }
    return repository.addSettlement(settlement);
  }
}

/// Hoàn tác khi đánh dấu nhầm.
class DeleteSettlement {
  final SettlementRepository repository;

  DeleteSettlement(this.repository);

  Future<void> call(int id) {
    return repository.deleteSettlement(id);
  }
}

/// Toàn bộ dữ liệu tổng quan của một nhóm, tính lại từ dữ liệu gốc mỗi lần tải.
class GroupOverview extends Equatable {
  final Group group;
  final List<Member> members;
  final List<ExpenseWithDetails> expenses;
  final List<Settlement> settlements;
  final List<MemberBalance> balances;
  final List<SuggestedTransfer> suggestions;
  final SettlementProgress progress;

  const GroupOverview({
    required this.group,
    required this.members,
    required this.expenses,
    required this.settlements,
    required this.balances,
    required this.suggestions,
    required this.progress,
  });

  int get totalExpense => expenses.fold<int>(0, (s, e) => s + e.expense.amount);

  Member? memberById(int id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  MemberBalance? balanceOf(int memberId) {
    for (final b in balances) {
      if (b.member.id == memberId) return b;
    }
    return null;
  }

  @override
  List<Object?> get props => [group, members, expenses, settlements];
}

class GetGroupOverview {
  final GroupRepository groupRepository;
  final ExpenseRepository expenseRepository;
  final SettlementRepository settlementRepository;
  final CalculateBalancesUseCase calculateBalances;
  final GenerateSettlementUseCase generateSettlement;

  GetGroupOverview({
    required this.groupRepository,
    required this.expenseRepository,
    required this.settlementRepository,
    this.calculateBalances = const CalculateBalancesUseCase(),
    this.generateSettlement = const GenerateSettlementUseCase(),
  });

  Future<GroupOverview> call(int groupId) async {
    final group = await groupRepository.getGroupById(groupId);
    final members = await groupRepository.getMembers(groupId);
    final expenses = await expenseRepository.getExpensesByGroup(groupId);
    final settlements = await settlementRepository.getSettlementsByGroup(groupId);
    final balances = calculateBalances(members: members, expenses: expenses, settlements: settlements);
    return GroupOverview(
      group: group,
      members: members,
      expenses: expenses,
      settlements: settlements,
      balances: balances,
      suggestions: generateSettlement(balances),
      progress: SettlementProgress.fromBalances(balances),
    );
  }
}
