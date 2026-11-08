import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/group_usecases.dart';
import '../../../domain/usecases/settlement_usecases.dart';
import '../../../domain/entities/group.dart';
import 'group_list_state.dart';

class GroupListCubit extends Cubit<GroupListState> {
  final GetGroups getGroups;
  final CreateGroup createGroupUseCase;
  final UpdateGroup updateGroupUseCase;
  final DeleteGroup deleteGroupUseCase;
  final SetGroupArchived setGroupArchivedUseCase;
  final GetGroupOverview getGroupOverview;

  /// true: hiển thị các nhóm đã lưu trữ thay vì các nhóm đang hoạt động.
  bool _archived = false;

  GroupListCubit({
    required this.getGroups,
    required this.createGroupUseCase,
    required this.updateGroupUseCase,
    required this.deleteGroupUseCase,
    required this.setGroupArchivedUseCase,
    required this.getGroupOverview,
  }) : super(GroupListInitial());

  Future<void> loadGroups({bool? archived}) async {
    _archived = archived ?? _archived;
    if (state is! GroupListLoaded) emit(GroupListLoading());
    try {
      final groups = await getGroups(archived: _archived);
      final overviews = <int, GroupOverview>{};
      for (final g in groups) {
        overviews[g.id] = await getGroupOverview(g.id);
      }
      emit(GroupListLoaded(groups, overviews: overviews));
    } catch (e) {
      emit(GroupListError(e.toString()));
    }
  }

  Future<void> createGroup(String name, String? description, String currency, DateTime? startDate, DateTime? endDate) async {
    try {
      await createGroupUseCase(name, description, currency: currency, startDate: startDate, endDate: endDate);
      await loadGroups();
    } catch (e) {
      emit(GroupListError(e.toString()));
    }
  }

  Future<void> updateGroup(Group group) async {
    try {
      await updateGroupUseCase(group);
      await loadGroups();
    } catch (e) {
      emit(GroupListError(e.toString()));
    }
  }

  Future<void> deleteGroup(int id) async {
    try {
      await deleteGroupUseCase(id);
      await loadGroups();
    } catch (e) {
      emit(GroupListError(e.toString()));
    }
  }

  Future<void> setArchived(int id, bool archived) async {
    try {
      await setGroupArchivedUseCase(id, archived);
      await loadGroups();
    } catch (e) {
      emit(GroupListError(e.toString()));
    }
  }
}
