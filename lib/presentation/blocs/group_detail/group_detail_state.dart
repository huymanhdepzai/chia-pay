import 'package:equatable/equatable.dart';
import '../../../domain/entities/group.dart';
import '../../../domain/entities/member.dart';
import '../../../domain/entities/expense.dart';
import '../../../domain/usecases/settlement_usecases.dart';

abstract class GroupDetailState extends Equatable {
  const GroupDetailState();

  @override
  List<Object?> get props => [];
}

class GroupDetailInitial extends GroupDetailState {}

class GroupDetailLoading extends GroupDetailState {}

class GroupDetailLoaded extends GroupDetailState {
  final GroupOverview overview;

  const GroupDetailLoaded(this.overview);

  Group get group => overview.group;
  List<Member> get members => overview.members;
  List<ExpenseWithDetails> get expenses => overview.expenses;

  @override
  List<Object?> get props => [overview];
}

class GroupDetailError extends GroupDetailState {
  final String message;

  const GroupDetailError(this.message);

  @override
  List<Object?> get props => [message];
}
