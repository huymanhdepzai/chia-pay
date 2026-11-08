import 'package:equatable/equatable.dart';
import '../../../domain/entities/group.dart';
import '../../../domain/usecases/settlement_usecases.dart';

abstract class GroupListState extends Equatable {
  const GroupListState();
  
  @override
  List<Object?> get props => [];
}

class GroupListInitial extends GroupListState {}

class GroupListLoading extends GroupListState {}

class GroupListLoaded extends GroupListState {
  final List<Group> groups;

  /// Tổng chi phí, số thành viên và trạng thái quyết toán của từng nhóm, theo id nhóm.
  final Map<int, GroupOverview> overviews;

  const GroupListLoaded(this.groups, {this.overviews = const {}});

  @override
  List<Object?> get props => [groups, overviews];
}

class GroupListError extends GroupListState {
  final String message;

  const GroupListError(this.message);

  @override
  List<Object?> get props => [message];
}
