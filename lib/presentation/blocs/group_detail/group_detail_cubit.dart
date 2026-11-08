import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/member.dart';
import '../../../domain/entities/settlement.dart';
import '../../../domain/usecases/expense_usecases.dart';
import '../../../domain/usecases/group_usecases.dart';
import '../../../domain/usecases/member_usecases.dart';
import '../../../domain/usecases/settlement_usecases.dart';
import 'group_detail_state.dart';

/// Quản lý trạng thái chi tiết nhóm: thành viên, khoản chi, số dư và quyết toán.
///
/// Các thao tác ghi trả về thông báo lỗi (hoặc null nếu thành công) để giao diện hiển thị
/// SnackBar, thay vì chuyển cả màn hình sang trạng thái lỗi.
class GroupDetailCubit extends Cubit<GroupDetailState> {
  final GetGroupOverview getGroupOverview;
  final AddMember addMemberUseCase;
  final UpdateMember updateMemberUseCase;
  final DeleteMember deleteMemberUseCase;
  final DeleteExpense deleteExpenseUseCase;
  final AddSettlement addSettlementUseCase;
  final DeleteSettlement deleteSettlementUseCase;
  final SetGroupArchived setGroupArchivedUseCase;

  int? _groupId;

  GroupDetailCubit({
    required this.getGroupOverview,
    required this.addMemberUseCase,
    required this.updateMemberUseCase,
    required this.deleteMemberUseCase,
    required this.deleteExpenseUseCase,
    required this.addSettlementUseCase,
    required this.deleteSettlementUseCase,
    required this.setGroupArchivedUseCase,
  }) : super(GroupDetailInitial());

  Future<void> loadGroupDetail(int groupId) async {
    _groupId = groupId;
    if (state is! GroupDetailLoaded) emit(GroupDetailLoading());
    try {
      emit(GroupDetailLoaded(await getGroupOverview(groupId)));
    } catch (e) {
      emit(GroupDetailError(e.toString()));
    }
  }

  Future<void> reload() async {
    if (_groupId != null) await loadGroupDetail(_groupId!);
  }

  Future<String?> _run(Future<void> Function() action) async {
    try {
      await action();
      await reload();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> addMember(int groupId, String name) => _run(() => addMemberUseCase(groupId, name));

  Future<String?> updateMember(Member member) => _run(() => updateMemberUseCase(member));

  Future<String?> deleteMember(int groupId, int memberId) => _run(() => deleteMemberUseCase(memberId));

  Future<String?> deleteExpense(int groupId, int expenseId) => _run(() => deleteExpenseUseCase(expenseId));

  Future<String?> addSettlement(Settlement settlement) => _run(() => addSettlementUseCase(settlement));

  Future<String?> deleteSettlement(int settlementId) => _run(() => deleteSettlementUseCase(settlementId));

  Future<String?> setArchived(int groupId, bool archived) => _run(() => setGroupArchivedUseCase(groupId, archived));
}
