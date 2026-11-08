import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/utils/app_format.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/member.dart';
import '../../injection.dart';
import '../blocs/group_detail/group_detail_cubit.dart';
import '../blocs/group_detail/group_detail_state.dart';

class GroupDetailPage extends StatelessWidget {
  final int groupId;

  const GroupDetailPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<GroupDetailCubit>()..loadGroupDetail(groupId),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: BlocBuilder<GroupDetailCubit, GroupDetailState>(
          builder: (context, state) {
            if (state is GroupDetailLoading || state is GroupDetailInitial) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is GroupDetailLoaded) {
              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(context, state),
                  SliverToBoxAdapter(
                    child: _buildActionButtons(context, state).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                  ),
                  _buildSectionHeader(
                    context,
                    'Các khoản chi gần đây',
                    Icons.receipt_long,
                    action: state.expenses.length > 5
                        ? TextButton(
                            onPressed: () => _openAndReload(context, '/group/$groupId/stats?tab=expenses'),
                            child: Text('Xem tất cả (${state.expenses.length})'),
                          )
                        : null,
                  ),
                  _buildExpenseList(context, state),
                  _buildSectionHeader(context, 'Thành viên & số dư', Icons.group),
                  _buildMemberList(context, state),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)), // Bottom padding
                ],
              );
            } else if (state is GroupDetailError) {
              return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
            }
            return const SizedBox.shrink();
          },
        ),
        floatingActionButton: Builder(
          builder: (context) {
            return FloatingActionButton(
              onPressed: () => _showMemberBottomSheet(context),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.person_add),
            ).animate().scale(delay: 500.ms, curve: Curves.easeOutBack);
          }
        ),
      ),
    );
  }

  Future<void> _openAndReload(BuildContext context, String location, {Object? extra}) async {
    await context.push(location, extra: extra);
    if (!context.mounted) return;
    context.read<GroupDetailCubit>().reload();
  }

  void _showMessage(BuildContext context, String? error, {String? success}) {
    final text = error ?? success;
    if (text == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: error != null ? Colors.redAccent : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _buildSliverAppBar(BuildContext context, GroupDetailLoaded state) {
    final overview = state.overview;
    final group = state.group;
    final hasExpenses = state.expenses.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 270.0,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).primaryColor,
      elevation: 0,
      centerTitle: true,
      title: Text(
        group.name,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => context.pop(),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onSelected: (value) async {
            final cubit = context.read<GroupDetailCubit>();
            if (value == 'archive') {
              final error = await cubit.setArchived(group.id, !group.isArchived);
              if (!context.mounted) return;
              _showMessage(context, error, success: group.isArchived ? 'Đã khôi phục nhóm' : 'Đã lưu trữ nhóm');
              if (error == null && !group.isArchived) context.pop();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'archive',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(group.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
                title: Text(group.isArchived ? 'Khôi phục nhóm' : 'Lưu trữ nhóm'),
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor,
                    const Color(0xFF0D47A1), // Darker modern blue
                  ],
                ),
              ),
            ),
            // Subtle floating background CircleAvatars
            Positioned(
              right: -30,
              top: -30,
              child: CircleAvatar(
                radius: 85,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .move(
                    begin: const Offset(0, 0),
                    end: const Offset(-15, 12),
                    duration: 4000.ms,
                    curve: Curves.easeInOutSine,
                  ),
            ),
            Positioned(
              left: -20,
              bottom: 10,
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .move(
                    begin: const Offset(0, 0),
                    end: const Offset(15, -12),
                    duration: 4800.ms,
                    curve: Curves.easeInOutSine,
                  ),
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'TỔNG CHI TIÊU',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn().slideY(begin: 0.5),
                    const SizedBox(height: 8),
                    Text(
                      formatMoney(overview.totalExpense, group.currency),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ).animate().fadeIn(delay: 100.ms).scale(),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildHeaderChip(Icons.group_rounded, '${state.members.length} thành viên'),
                        if (group.startDate != null)
                          _buildHeaderChip(
                            Icons.date_range_rounded,
                            group.endDate != null
                                ? '${formatShortDate(group.startDate!)} - ${formatShortDate(group.endDate!)}'
                                : 'Từ ${formatShortDate(group.startDate!)}',
                          ),
                        if (hasExpenses)
                          _buildHeaderChip(
                            overview.progress.isComplete ? Icons.verified_rounded : Icons.timelapse_rounded,
                            overview.progress.isComplete
                                ? 'Đã quyết toán'
                                : 'Quyết toán ${(overview.progress.ratio * 100).round()}%',
                          ),
                      ],
                    ).animate().fadeIn(delay: 200.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, GroupDetailLoaded state) {
    final pending = state.overview.suggestions.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              context,
              icon: Icons.add_circle,
              label: 'Thêm chi tiêu',
              color: Theme.of(context).primaryColor,
              onTap: () => _openAndReload(context, '/add-expense', extra: {
                'group': state.group,
                'members': state.members,
              }),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              context,
              icon: Icons.calculate,
              label: 'Quyết toán',
              badge: pending > 0 ? '$pending' : null,
              color: Colors.orange,
              onTap: () => _openAndReload(context, '/group/$groupId/settlement'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              context,
              icon: Icons.bar_chart_rounded,
              label: 'Thống kê',
              color: Colors.teal,
              onTap: () => _openAndReload(context, '/group/$groupId/stats'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap, String? badge}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          children: [
            Badge(
              isLabelVisible: badge != null,
              label: Text(badge ?? ''),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, {Widget? action}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 16, 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ?action,
          ],
        ),
      ).animate().fadeIn(delay: 300.ms),
    );
  }

  Widget _buildExpenseList(BuildContext context, GroupDetailLoaded state) {
    if (state.expenses.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.receipt_long, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Chưa có khoản chi nào.', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final expenseData = state.expenses[index];
          return ExpenseTile(
            expenseData: expenseData,
            currency: state.group.currency,
            onEdit: () => _openAndReload(context, '/add-expense', extra: {
              'group': state.group,
              'members': state.members,
              'expenseToEdit': expenseData,
            }),
            onDelete: () => _showDeleteExpenseConfirm(context, expenseData),
          );
        },
        childCount: state.expenses.length > 5 ? 5 : state.expenses.length,
      ),
    );
  }

  Widget _buildMemberList(BuildContext context, GroupDetailLoaded state) {
    if (state.members.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.group_off, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Chưa có thành viên nào.', style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final member = state.members[index];
          final balance = state.overview.balanceOf(member.id);
          final remaining = balance?.remainingBalance ?? 0;
          final currency = state.group.currency;
          return Slidable(
            key: ValueKey(member.id),
            endActionPane: ActionPane(
              motion: const StretchMotion(),
              children: [
                _circleAction(
                  icon: Icons.edit_rounded,
                  color: Colors.blue,
                  onPressed: (context) => _showMemberBottomSheet(context, member: member),
                ),
                _circleAction(
                  icon: Icons.person_remove_rounded,
                  color: Colors.redAccent,
                  onPressed: (context) => _showDeleteMemberConfirm(context, member),
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    member.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Đã ứng ${formatMoney(balance?.paid ?? 0, currency)} · Phải chịu ${formatMoney(balance?.share ?? 0, currency)}',
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      remaining == 0 ? 'Cân bằng' : formatMoney(remaining.abs(), currency),
                      style: TextStyle(fontWeight: FontWeight.bold, color: balanceColor(remaining)),
                    ),
                    if (remaining != 0)
                      Text(
                        remaining > 0 ? 'cần nhận' : 'cần trả',
                        style: TextStyle(fontSize: 11, color: balanceColor(remaining)),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: state.members.length,
      ),
    );
  }

  void _showMemberBottomSheet(BuildContext context, {Member? member}) {
    final nameController = TextEditingController(text: member?.name ?? '');
    final cubit = context.read<GroupDetailCubit>();
    final isEditing = member != null;

    Future<void> submit(BuildContext sheetContext) async {
      final name = nameController.text.trim();
      if (name.isEmpty) return;
      Navigator.pop(sheetContext);
      final error = isEditing ? await cubit.updateMember(member.copyWith(name: name)) : await cubit.addMember(groupId, name);
      if (context.mounted) _showMessage(context, error);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: 24, right: 24, top: 20,
          ),
          decoration: BoxDecoration(
            color: sheetContext.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                isEditing ? 'Sửa tên thành viên' : 'Thêm thành viên',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: isEditing ? 'Tên thành viên' : 'Tên thành viên (VD: An, Bình)',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: sheetContext.fieldColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  prefixIcon: Icon(isEditing ? Icons.person : Icons.person_add, color: Colors.grey[400]),
                ),
                onSubmitted: (_) => submit(sheetContext),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: Theme.of(sheetContext).primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  onPressed: () => submit(sheetContext),
                  child: Text(isEditing ? 'Cập nhật' : 'Hoàn tất', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteMemberConfirm(BuildContext context, Member member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa thành viên?'),
        content: Text('Bạn có chắc muốn xóa "${member.name}" khỏi nhóm?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final error = await context.read<GroupDetailCubit>().deleteMember(member.groupId, member.id);
              if (context.mounted) _showMessage(context, error);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteExpenseConfirm(BuildContext context, ExpenseWithDetails expenseData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa khoản chi?'),
        content: Text('Bạn có chắc muốn xóa khoản chi "${expenseData.expense.name}"? Số dư của nhóm sẽ được tính lại.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final error = await context.read<GroupDetailCubit>().deleteExpense(expenseData.expense.groupId, expenseData.expense.id);
              if (context.mounted) _showMessage(context, error);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

Widget _circleAction({required IconData icon, required Color color, required void Function(BuildContext) onPressed}) {
  return CustomSlidableAction(
    onPressed: onPressed,
    backgroundColor: Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Center(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    ),
  );
}

/// Một dòng khoản chi, vuốt sang trái để sửa/xóa. Dùng chung cho tổng quan nhóm và thống kê.
class ExpenseTile extends StatelessWidget {
  final ExpenseWithDetails expenseData;
  final String currency;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ExpenseTile({super.key, required this.expenseData, required this.currency, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final expense = expenseData.expense;
    final participants = expenseData.shares.where((s) => s.share.amount > 0).map((s) => s.member.name).join(', ');
    final tile = Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
          child: Icon(categoryIcon(expense.category), color: Theme.of(context).primaryColor),
        ),
        title: Text(expense.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'Trả bởi: ${expenseData.payer.name}\nChia cho: $participants',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.textSecondary, fontSize: 12.5),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(expense.amount, currency),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: context.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              formatShortDate(expense.date),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );

    if (onEdit == null && onDelete == null) return tile;
    return Slidable(
      key: ValueKey(expense.id),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          if (onEdit != null) _circleAction(icon: Icons.edit_rounded, color: Colors.blue, onPressed: (_) => onEdit!()),
          if (onDelete != null) _circleAction(icon: Icons.delete_rounded, color: Colors.redAccent, onPressed: (_) => onDelete!()),
        ],
      ),
      child: tile,
    );
  }
}

