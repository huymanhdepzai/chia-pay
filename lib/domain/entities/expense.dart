import 'package:equatable/equatable.dart';
import 'member.dart';

class Expense extends Equatable {
  final int id;
  final int groupId;
  final int payerId;
  final String name;
  final int amount;
  final DateTime date;
  final String category;
  final String? note;
  final String splitType;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.groupId,
    required this.payerId,
    required this.name,
    required this.amount,
    required this.date,
    required this.category,
    this.note,
    this.splitType = 'equal',
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, groupId, payerId, name, amount, date, category, note, splitType, createdAt];
}

class ExpenseShare extends Equatable {
  final int id;
  final int expenseId;
  final int memberId;
  final int amount;
  /// Tỷ lệ phần trăm (basis point) khi chia theo phần trăm, để khôi phục lại khi sửa.
  final int? percentBp;

  const ExpenseShare({
    required this.id,
    required this.expenseId,
    required this.memberId,
    required this.amount,
    this.percentBp,
  });

  @override
  List<Object?> get props => [id, expenseId, memberId, amount, percentBp];
}

class ExpenseWithDetails extends Equatable {
  final Expense expense;
  final Member payer;
  final List<ExpenseShareWithMember> shares;

  const ExpenseWithDetails({
    required this.expense,
    required this.payer,
    required this.shares,
  });

  @override
  List<Object?> get props => [expense, payer, shares];
}

class ExpenseShareWithMember extends Equatable {
  final ExpenseShare share;
  final Member member;

  const ExpenseShareWithMember({
    required this.share,
    required this.member,
  });

  @override
  List<Object?> get props => [share, member];
}
