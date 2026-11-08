import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/app_format.dart';
import '../../domain/entities/group.dart';
import '../../domain/usecases/settlement_usecases.dart';
import '../../injection.dart';
import '../blocs/group_list/group_list_cubit.dart';
import '../blocs/group_list/group_list_state.dart';
import '../blocs/settings/settings_cubit.dart';

/// Bảng màu gradient hiện đại, hài hòa cho thẻ nhóm
const List<List<Color>> _groupGradients = [
  [Color(0xFF2563EB), Color(0xFF3B82F6)], // Ocean Blue
  [Color(0xFF059669), Color(0xFF10B981)], // Emerald
  [Color(0xFF7C3AED), Color(0xFF8B5CF6)], // Purple
  [Color(0xFFD97706), Color(0xFFF59E0B)], // Amber
  [Color(0xFF0D9488), Color(0xFF14B8A6)], // Teal
  [Color(0xFFE11D48), Color(0xFFFB7185)], // Coral Rose
];

/// Tự động chọn icon phù hợp dựa theo tên nhóm
IconData _detectGroupIcon(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('du lịch') || lower.contains('đà lạt') || lower.contains('trip') || lower.contains('phượt') || lower.contains('biển')) {
    return Icons.flight_takeoff_rounded;
  }
  if (lower.contains('ăn') || lower.contains('lẩu') || lower.contains('nhậu') || lower.contains('tiệc') || lower.contains('party') || lower.contains('cà phê') || lower.contains('cafe')) {
    return Icons.restaurant_rounded;
  }
  if (lower.contains('trọ') || lower.contains('phòng') || lower.contains('nhà') || lower.contains('ở ghép') || lower.contains('chung cư')) {
    return Icons.home_work_rounded;
  }
  if (lower.contains('gia đình') || lower.contains('family')) {
    return Icons.family_restroom_rounded;
  }
  if (lower.contains('sinh nhật') || lower.contains('kỷ niệm')) {
    return Icons.cake_rounded;
  }
  if (lower.contains('mua sắm') || lower.contains('shop')) {
    return Icons.shopping_bag_rounded;
  }
  return Icons.groups_rounded;
}

class GroupListPage extends StatefulWidget {
  const GroupListPage({super.key});

  @override
  State<GroupListPage> createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: Tất cả, 1: Đang quyết toán, 2: Đã quyết toán
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Group> _filterGroups(List<Group> groups, Map<int, GroupOverview> overviews) {
    return groups.where((g) {
      // Tìm kiếm theo tên hoặc mô tả
      if (_searchQuery.isNotEmpty) {
        final nameMatch = g.name.toLowerCase().contains(_searchQuery);
        final descMatch = (g.description ?? '').toLowerCase().contains(_searchQuery);
        if (!nameMatch && !descMatch) return false;
      }

      // Bộ lọc trạng thái
      final overview = overviews[g.id];
      if (_selectedFilterIndex == 1) {
        // Đang quyết toán: có chi phí và chưa hoàn tất
        if (overview == null || overview.expenses.isEmpty || overview.progress.isComplete) {
          return false;
        }
      } else if (_selectedFilterIndex == 2) {
        // Đã quyết toán: hoàn tất hoặc chưa có chi phí
        if (overview == null || overview.expenses.isEmpty || !overview.progress.isComplete) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<GroupListCubit>()..loadGroups(),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: BlocBuilder<GroupListCubit, GroupListState>(
          builder: (context, state) {
            return RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.lightImpact();
                await context.read<GroupListCubit>().loadGroups();
              },
              color: Theme.of(context).primaryColor,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  _buildSliverAppBar(context, state),
                  if (state is GroupListLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
                    )
                  else if (state is GroupListLoaded) ...[
                    if (state.groups.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(context),
                      )
                    else ...[
                      // Thẻ tổng quan tài chính các nhóm
                      SliverToBoxAdapter(
                        child: _buildQuickOverviewCard(context, state.groups, state.overviews),
                      ),

                      // Thanh tìm kiếm & bộ lọc
                      SliverToBoxAdapter(
                        child: _buildFilterSection(context, state.groups),
                      ),

                      // Danh sách các nhóm
                      _buildGroupListSliver(context, state),
                    ],
                  ] else if (state is GroupListError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline_rounded, size: 48, color: Colors.red[300]),
                            const SizedBox(height: 12),
                            Text(state.message, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => context.read<GroupListCubit>().loadGroups(),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding cho FAB
                ],
              ),
            );
          },
        ),
        floatingActionButton: Builder(
          builder: (context) {
            return FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showCreateGroupBottomSheet(context);
              },
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded, size: 24),
              label: const Text(
                'Tạo nhóm mới',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.2),
              ),
            ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack);
          },
        ),
      ),
    );
  }

  /// AppBar hiện đại, gọn gàng với nhận diện thương hiệu và phím chức năng
  Widget _buildSliverAppBar(BuildContext context, GroupListState state) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Theme.of(context).primaryColor.withValues(alpha: 0.08),
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E63FF), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E63FF).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.wallet_rounded, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'ChiaPay',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -0.5,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'OFFLINE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Quản lý & chia tiền nhóm',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Tìm kiếm',
          icon: Icon(
            _showSearchBar ? Icons.search_off_rounded : Icons.search_rounded,
            color: context.textPrimary,
          ),
          onPressed: () {
            setState(() {
              _showSearchBar = !_showSearchBar;
              if (!_showSearchBar) {
                _searchController.clear();
              }
            });
          },
        ),
        IconButton(
          tooltip: 'Nhóm lưu trữ',
          icon: Icon(Icons.inventory_2_outlined, color: context.textPrimary),
          onPressed: () async {
            final cubit = context.read<GroupListCubit>();
            await context.push('/archived');
            cubit.loadGroups();
          },
        ),
        IconButton(
          tooltip: 'Cài đặt',
          icon: Icon(Icons.settings_outlined, color: context.textPrimary),
          onPressed: () async {
            final cubit = context.read<GroupListCubit>();
            await context.push('/settings');
            cubit.loadGroups();
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// Thẻ tổng quan nhanh các nhóm đang hoạt động
  Widget _buildQuickOverviewCard(BuildContext context, List<Group> groups, Map<int, GroupOverview> overviews) {
    int totalExpense = 0;
    int pendingSettlementCount = 0;
    int completedSettlementCount = 0;
    String currency = 'đ';

    for (final g in groups) {
      final overview = overviews[g.id];
      if (overview != null) {
        totalExpense += overview.totalExpense;
        currency = overview.group.currency;
        if (overview.expenses.isNotEmpty) {
          if (overview.progress.isComplete) {
            completedSettlementCount++;
          } else {
            pendingSettlementCount++;
          }
        }
      }
    }

    final isDark = context.isDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : const Color(0xFF2563EB)).withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pie_chart_outline_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'TỔNG CHI TIÊU CÁC NHÓM',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${groups.length} nhóm',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              formatMoney(totalExpense, currency),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: Icons.check_circle_rounded,
                    iconColor: const Color(0xFF4ADE80),
                    label: 'Đã xong',
                    value: '$completedSettlementCount nhóm',
                  ),
                  Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.2)),
                  _buildStatItem(
                    icon: Icons.timelapse_rounded,
                    iconColor: const Color(0xFFFBBF24),
                    label: 'Cần chuyển',
                    value: '$pendingSettlementCount nhóm',
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w500),
            ),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  /// Khu vực tìm kiếm và bộ lọc nhóm
  Widget _buildFilterSection(BuildContext context, List<Group> groups) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ô tìm kiếm (bật/tắt)
          if (_showSearchBar) ...[
            Container(
              decoration: BoxDecoration(
                color: context.fieldColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm nhóm...',
                  hintStyle: TextStyle(color: context.textSecondary, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: context.textSecondary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.2),
            const SizedBox(height: 12),
          ],

          // Thanh lọc trạng thái
          Row(
            children: [
              Text(
                'Danh sách nhóm',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const Spacer(),
              _buildFilterChip(0, 'Tất cả'),
              const SizedBox(width: 6),
              _buildFilterChip(1, 'Cần trả'),
              const SizedBox(width: 6),
              _buildFilterChip(2, 'Đã xong'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    final primary = Theme.of(context).primaryColor;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilterIndex = index);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? primary : context.fieldColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primary : context.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : context.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Danh sách nhóm hiển thị dưới dạng SliverList
  Widget _buildGroupListSliver(BuildContext context, GroupListLoaded state) {
    final filtered = _filterGroups(state.groups, state.overviews);

    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'Không tìm thấy nhóm phù hợp',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Thử đổi từ khóa hoặc bộ lọc khác',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final group = filtered[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AnimatedGroupCard(
                group: group,
                overview: state.overviews[group.id],
                onEdit: (g) => _showCreateGroupBottomSheet(context, groupToEdit: g),
                onDelete: (g) => _showDeleteGroupConfirm(context, g),
                onArchive: (g) => context.read<GroupListCubit>().setArchived(g.id, true),
                onReturn: () => context.read<GroupListCubit>().loadGroups(),
              ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideY(begin: 0.1, curve: Curves.easeOutCubic),
            );
          },
          childCount: filtered.length,
        ),
      ),
    );
  }

  /// Giao diện khi chưa có nhóm nào được tạo
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_3_rounded,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text(
              'Chưa có nhóm chi tiêu nào',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Tạo nhóm để bắt đầu ghi chép các khoản chi tiêu,\ntự động tính tiền và thanh toán sòng phẳng cùng nhau.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showCreateGroupBottomSheet(context);
              },
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Tạo nhóm đầu tiên', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 2,
              ),
            ).animate().fadeIn(delay: 200.ms).scale(),
          ],
        ),
      ),
    );
  }

  /// Modal tạo / sửa nhóm hiện đại với các gợi ý nhanh
  void _showCreateGroupBottomSheet(BuildContext context, {Group? groupToEdit}) {
    final nameController = TextEditingController(text: groupToEdit?.name ?? '');
    final descController = TextEditingController(text: groupToEdit?.description ?? '');
    String selectedCurrency = groupToEdit?.currency ?? sl<SettingsCubit>().state.defaultCurrency;
    DateTime? startDate = groupToEdit?.startDate;
    DateTime? endDate = groupToEdit?.endDate;
    final cubit = context.read<GroupListCubit>();

    final quickCategories = [
      {'name': 'Du lịch Đà Lạt', 'desc': 'Chuyến đi cùng bạn bè'},
      {'name': 'Liên hoan ăn uống', 'desc': 'Ăn lẩu & tụ tập cuối tuần'},
      {'name': 'Tiền nhà ở ghép', 'desc': 'Chi phí sinh hoạt phòng trọ'},
      {'name': 'Cà phê cuối tuần', 'desc': 'Họp nhóm & trà sữa'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
                  left: 20,
                  right: 20,
                  top: 16,
                ),
                decoration: BoxDecoration(
                  color: modalContext.cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(modalContext).primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              groupToEdit == null ? Icons.group_add_rounded : Icons.edit_note_rounded,
                              color: Theme.of(modalContext).primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            groupToEdit == null ? 'Tạo nhóm mới' : 'Chỉnh sửa nhóm',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: modalContext.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Gợi ý nhanh cho nhóm mới
                      if (groupToEdit == null) ...[
                        Text(
                          'Gợi ý nhanh chủ đề:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: modalContext.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: quickCategories.map((cat) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ActionChip(
                                  label: Text(cat['name']!, style: const TextStyle(fontSize: 12)),
                                  avatar: Icon(_detectGroupIcon(cat['name']!), size: 16),
                                  backgroundColor: modalContext.fieldColor,
                                  side: BorderSide(color: modalContext.borderColor),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onPressed: () {
                                    setModalState(() {
                                      nameController.text = cat['name']!;
                                      descController.text = cat['desc']!;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Tên nhóm
                      TextField(
                        controller: nameController,
                        autofocus: groupToEdit == null,
                        style: TextStyle(fontWeight: FontWeight.w600, color: modalContext.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Tên nhóm chi tiêu *',
                          labelStyle: TextStyle(color: modalContext.textSecondary),
                          hintText: 'VD: Du lịch Đà Lạt, Ăn uống...',
                          filled: true,
                          fillColor: modalContext.fieldColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          prefixIcon: Icon(Icons.group_rounded, color: Theme.of(modalContext).primaryColor),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),

                      // Mô tả
                      TextField(
                        controller: descController,
                        style: TextStyle(color: modalContext.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Ghi chú / Mô tả (tùy chọn)',
                          labelStyle: TextStyle(color: modalContext.textSecondary),
                          hintText: 'Thêm mục đích chuyến đi...',
                          filled: true,
                          fillColor: modalContext.fieldColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          prefixIcon: Icon(Icons.notes_rounded, color: Colors.grey[400]),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tiền tệ
                      DropdownButtonFormField<String>(
                        value: selectedCurrency,
                        decoration: InputDecoration(
                          labelText: 'Đơn vị tiền tệ',
                          labelStyle: TextStyle(color: modalContext.textSecondary),
                          filled: true,
                          fillColor: modalContext.fieldColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          prefixIcon: Icon(Icons.payments_rounded, color: Colors.grey[400]),
                        ),
                        dropdownColor: modalContext.cardColor,
                        items: SettingsCubit.supportedCurrencies
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedCurrency = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Ngày bắt đầu và ngày kết thúc
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              modalContext,
                              label: 'Ngày bắt đầu',
                              value: startDate,
                              onPick: (d) => setModalState(() {
                                startDate = d;
                                if (d != null && endDate != null && endDate!.isBefore(d)) {
                                  endDate = d;
                                }
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildDateField(
                              modalContext,
                              label: 'Ngày kết thúc',
                              value: endDate,
                              firstDate: startDate,
                              onPick: (d) => setModalState(() => endDate = d),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Nút hành động
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(modalContext).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                          ),
                          onPressed: () {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(modalContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Vui lòng nhập tên nhóm'),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            if (groupToEdit == null) {
                              cubit.createGroup(
                                name,
                                descController.text.trim(),
                                selectedCurrency,
                                startDate,
                                endDate,
                              );
                            } else {
                              cubit.updateGroup(Group(
                                id: groupToEdit.id,
                                name: name,
                                description: descController.text.trim(),
                                currency: selectedCurrency,
                                startDate: startDate,
                                endDate: endDate,
                                isArchived: groupToEdit.isArchived,
                                createdAt: groupToEdit.createdAt,
                              ));
                            }
                            Navigator.pop(sheetContext);
                          },
                          child: Text(
                            groupToEdit == null ? 'Hoàn tất & Tạo nhóm' : 'Lưu cập nhật',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateField(
    BuildContext context, {
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onPick,
    DateTime? firstDate,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? firstDate ?? DateTime.now(),
          firstDate: firstDate ?? DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: context.fieldColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 18, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: context.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    value == null ? 'Chọn ngày' : formatDate(value),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: value == null ? Colors.grey[400] : context.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onPick(null),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: Colors.grey[400]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteGroupConfirm(BuildContext context, Group group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[400]),
            const SizedBox(width: 8),
            const Text('Xóa nhóm?'),
          ],
        ),
        content: Text('Bạn có chắc chắn muốn xóa nhóm "${group.name}"?\nToàn bộ dữ liệu chi tiêu và thành viên sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: TextStyle(color: context.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              context.read<GroupListCubit>().deleteGroup(group.id);
              Navigator.pop(ctx);
            },
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
  }
}

/// Thẻ nhóm được thiết kế lại theo phong cách hiện đại, trực quan, thân thiện
class AnimatedGroupCard extends StatefulWidget {
  final Group group;
  final GroupOverview? overview;
  final void Function(Group) onEdit;
  final void Function(Group) onDelete;
  final void Function(Group) onArchive;
  final VoidCallback onReturn;

  const AnimatedGroupCard({
    super.key,
    required this.group,
    this.overview,
    required this.onEdit,
    required this.onDelete,
    required this.onArchive,
    required this.onReturn,
  });

  @override
  State<AnimatedGroupCard> createState() => _AnimatedGroupCardState();
}

class _AnimatedGroupCardState extends State<AnimatedGroupCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final overview = widget.overview;

    // Chọn gradient theo ID nhóm
    final gradient = _groupGradients[group.id % _groupGradients.length];
    final activeColor = gradient.first;
    final groupIcon = _detectGroupIcon(group.name);

    final hasExpenses = overview != null && overview.expenses.isNotEmpty;
    final isSettled = overview != null && overview.progress.isComplete && hasExpenses;
    final pendingCount = overview?.suggestions.length ?? 0;

    return Slidable(
      key: ValueKey(group.id),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          CustomSlidableAction(
            onPressed: (_) => widget.onEdit(group),
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildActionButton(
              icon: Icons.edit_rounded,
              color: const Color(0xFF2563EB),
              tooltip: 'Sửa',
            ),
          ),
          CustomSlidableAction(
            onPressed: (_) => widget.onArchive(group),
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildActionButton(
              icon: Icons.archive_rounded,
              color: const Color(0xFFD97706),
              tooltip: 'Lưu trữ',
            ),
          ),
          CustomSlidableAction(
            onPressed: (_) => widget.onDelete(group),
            backgroundColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildActionButton(
              icon: Icons.delete_outline_rounded,
              color: const Color(0xFFDC2626),
              tooltip: 'Xóa',
            ),
          ),
        ],
      ),
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          setState(() => _isPressed = true);
        },
        onTapUp: (_) async {
          setState(() => _isPressed = false);
          await context.push('/group/${group.id}');
          widget.onReturn();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: context.borderColor,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: activeColor.withValues(alpha: context.isDark ? 0.05 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hàng tiêu đề: Icon phân loại + Tên nhóm + Menu 3 chấm
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(groupIcon, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          (group.description != null && group.description!.isNotEmpty)
                              ? group.description!
                              : 'Chưa có mô tả',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Nút menu 3 chấm tiện lợi (dành cho người không quen vuốt)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz_rounded, color: Colors.grey[400]),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (val) {
                      if (val == 'edit') widget.onEdit(group);
                      if (val == 'archive') widget.onArchive(group);
                      if (val == 'delete') widget.onDelete(group);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Chỉnh sửa'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Lưu trữ nhóm'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                            SizedBox(width: 10),
                            Text('Xóa nhóm', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Thông tin tài chính & thành viên
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.fieldColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tổng đã chi',
                          style: TextStyle(fontSize: 11, color: context.textSecondary, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          overview != null ? formatMoney(overview.totalExpense, group.currency) : '0 ${group.currency}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Thành viên',
                          style: TextStyle(fontSize: 11, color: context.textSecondary, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.people_alt_rounded, size: 16, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 5),
                            Text(
                              '${overview?.members.length ?? 0}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Hàng chân thẻ: Trạng thái quyết toán & Thời gian
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Trạng thái quyết toán
                  if (!hasExpenses)
                    _buildStatusChip(
                      icon: Icons.info_outline_rounded,
                      label: 'Chưa có khoản chi',
                      color: Colors.grey,
                    )
                  else if (isSettled)
                    _buildStatusChip(
                      icon: Icons.check_circle_rounded,
                      label: 'Đã quyết toán xong',
                      color: positiveColor,
                    )
                  else
                    _buildStatusChip(
                      icon: Icons.sync_rounded,
                      label: 'Còn $pendingCount giao dịch',
                      color: const Color(0xFFD97706),
                    ),

                  // Ngày tháng nếu có
                  if (group.startDate != null)
                    Row(
                      children: [
                        Icon(Icons.date_range_rounded, size: 13, color: context.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          group.endDate != null
                              ? '${formatShortDate(group.startDate!)} - ${formatShortDate(group.endDate!)}'
                              : formatShortDate(group.startDate!),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: context.textSecondary),
                        ),
                      ],
                    )
                  else
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey[400]),
                ],
              ),
            ],
          ),
        ).animate(target: _isPressed ? 1 : 0).scale(
          begin: const Offset(1, 1),
          end: const Offset(0.98, 0.98),
          duration: 100.ms,
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required String tooltip}) {
    return Center(
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildStatusChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
