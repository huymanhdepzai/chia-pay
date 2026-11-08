import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/app_format.dart';
import '../../domain/entities/group.dart';
import '../../injection.dart';
import '../blocs/group_list/group_list_cubit.dart';
import '../blocs/group_list/group_list_state.dart';

/// Danh sách nhóm đã lưu trữ: xem lại, khôi phục hoặc xóa hẳn.
class ArchivedGroupsPage extends StatelessWidget {
  const ArchivedGroupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<GroupListCubit>()..loadGroups(archived: true),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text('Nhóm đã lưu trữ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => context.pop()),
        ),
        body: BlocBuilder<GroupListCubit, GroupListState>(
          builder: (context, state) {
            if (state is GroupListError) {
              return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
            }
            if (state is! GroupListLoaded) return const Center(child: CircularProgressIndicator());
            if (state.groups.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('Chưa có nhóm nào được lưu trữ', style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: state.groups.length,
              itemBuilder: (context, index) {
                final group = state.groups[index];
                final overview = state.overviews[group.id];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    onTap: () async {
                      await context.push('/group/${group.id}');
                      if (context.mounted) context.read<GroupListCubit>().loadGroups();
                    },
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.withValues(alpha: 0.15),
                      child: Icon(Icons.inventory_2_rounded, color: context.textSecondary),
                    ),
                    title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: overview == null
                        ? null
                        : Text(
                            '${formatMoney(overview.totalExpense, group.currency)} · ${overview.members.length} thành viên'
                            '${overview.progress.isComplete ? ' · Đã quyết toán' : ''}',
                            style: TextStyle(fontSize: 12, color: context.textSecondary),
                          ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Khôi phục',
                          icon: const Icon(Icons.unarchive_outlined),
                          onPressed: () => context.read<GroupListCubit>().setArchived(group.id, false),
                        ),
                        IconButton(
                          tooltip: 'Xóa vĩnh viễn',
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          onPressed: () => _confirmDelete(context, group),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Group group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa vĩnh viễn?'),
        content: Text('Nhóm "${group.name}" cùng toàn bộ khoản chi và lịch sử quyết toán sẽ bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              context.read<GroupListCubit>().deleteGroup(group.id);
              Navigator.pop(ctx);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
