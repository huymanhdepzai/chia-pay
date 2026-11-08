import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/utils/app_format.dart';
import '../../core/utils/report_builder.dart';
import '../../core/utils/share_helper.dart';
import '../../domain/entities/expense.dart';
import '../../domain/usecases/settlement_usecases.dart';
import '../../injection.dart';
import '../blocs/group_detail/group_detail_cubit.dart';
import '../blocs/group_detail/group_detail_state.dart';
import 'group_detail_page.dart';

/// Bảng màu phân loại cố định theo thứ tự (không xoay vòng), mỗi chế độ sáng/tối một bộ bước.
const _seriesLight = [Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A), Color(0xFFEDA100), Color(0xFFE87BA4), Color(0xFF008300), Color(0xFF6250D6)];
const _seriesDark = [Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70), Color(0xFFC98500), Color(0xFFD55181), Color(0xFF008300), Color(0xFF9085E9)];

Color _series(BuildContext context, int slot) => (context.isDark ? _seriesDark : _seriesLight)[slot % _seriesLight.length];

/// Thống kê và báo cáo: theo danh mục, thành viên, thời gian; lọc theo người thanh toán; xuất CSV.
class StatisticsPage extends StatelessWidget {
  final int groupId;
  final int initialTab;

  const StatisticsPage({super.key, required this.groupId, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<GroupDetailCubit>()..loadGroupDetail(groupId),
      child: BlocBuilder<GroupDetailCubit, GroupDetailState>(
        builder: (context, state) {
          return switch (state) {
            GroupDetailLoaded(:final overview) => _StatisticsView(overview: overview, initialTab: initialTab),
            GroupDetailError(:final message) => Scaffold(body: Center(child: Text(message))),
            _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
          };
        },
      ),
    );
  }
}

class _StatisticsView extends StatefulWidget {
  final GroupOverview overview;
  final int initialTab;

  const _StatisticsView({required this.overview, required this.initialTab});

  @override
  State<_StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<_StatisticsView> {
  /// null = tất cả người thanh toán.
  int? _payerId;

  GroupOverview get o => widget.overview;
  String get currency => o.group.currency;

  List<ExpenseWithDetails> get _filtered =>
      _payerId == null ? o.expenses : o.expenses.where((e) => e.expense.payerId == _payerId).toList();

  Future<void> _exportCsv(BuildContext buttonContext) async {
    final name = ShareHelper.safeFileName(o.group.name);
    final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
    try {
      await ShareHelper.shareFile(buttonContext, 'chiapay_${name}_$stamp.csv',
          ReportBuilder.expensesCsv(o, payerId: _payerId), mimeType: 'text/csv');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không xuất được CSV: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text('Thống kê', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          centerTitle: true,
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => context.pop()),
          actions: [
            Builder(
              builder: (buttonContext) => IconButton(
                tooltip: 'Xuất CSV',
                icon: const Icon(Icons.file_download_outlined),
                onPressed: o.expenses.isEmpty ? null : () => _exportCsv(buttonContext),
              ),
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'Biểu đồ'), Tab(text: 'Khoản chi')]),
        ),
        body: Column(
          children: [
            _buildPayerFilter(context),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCharts(context),
                  _buildExpenseList(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayerFilter(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Tất cả'),
              selected: _payerId == null,
              onSelected: (_) => setState(() => _payerId = null),
            ),
          ),
          ...o.members.map((m) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: const Icon(Icons.person_outline, size: 16),
                  label: Text('${m.name} trả'),
                  selected: _payerId == m.id,
                  onSelected: (_) => setState(() => _payerId = _payerId == m.id ? null : m.id),
                ),
              )),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required String title, String? subtitle, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 12, color: context.textSecondary)),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildCharts(BuildContext context) {
    final expenses = _filtered;
    if (expenses.isEmpty) {
      return Center(child: Text('Không có khoản chi phù hợp.', style: TextStyle(color: Colors.grey[500])));
    }
    final total = expenses.fold<int>(0, (s, e) => s + e.expense.amount);
    final days = expenses.map((e) => DateUtils.dateOnly(e.expense.date)).toSet().length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Row(
          children: [
            Expanded(child: _statTile(context, 'Tổng chi', formatMoney(total, currency))),
            const SizedBox(width: 12),
            Expanded(child: _statTile(context, 'Số khoản chi', '${expenses.length}')),
            const SizedBox(width: 12),
            Expanded(child: _statTile(context, 'TB / ngày', formatMoney(total ~/ math.max(days, 1), currency))),
          ],
        ),
        const SizedBox(height: 16),
        _card(context, title: 'Theo danh mục', subtitle: 'Tỷ trọng trên tổng chi', child: _buildCategoryBars(context, expenses, total)),
        _card(
          context,
          title: 'Theo thành viên',
          subtitle: 'Đã ứng so với phần phải chịu',
          child: _buildMemberChart(context, expenses),
        ),
        _card(context, title: 'Chi tiêu theo ngày', child: _buildDailyChart(context, expenses)),
      ],
    );
  }

  Widget _statTile(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  /// Thanh ngang theo danh mục; màu gắn với danh mục (theo thứ tự cố định), nhãn và số tiền ghi rõ.
  Widget _buildCategoryBars(BuildContext context, List<ExpenseWithDetails> expenses, int total) {
    final byCategory = <String, int>{};
    for (final e in expenses) {
      byCategory[e.expense.category] = (byCategory[e.expense.category] ?? 0) + e.expense.amount;
    }
    final categories = expenseCategories.keys.toList();
    final entries = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: entries.map((entry) {
        final slot = categories.contains(entry.key) ? categories.indexOf(entry.key) : categories.length - 1;
        final color = _series(context, slot);
        final ratio = total == 0 ? 0.0 : entry.value / total;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(categoryIcon(entry.key), size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(formatMoney(entry.value, currency), style: const TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(
                    width: 48,
                    child: Text('${(ratio * 100).round()}%',
                        textAlign: TextAlign.right, style: TextStyle(color: context.textSecondary, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: context.textPrimary.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary)),
      ],
    );
  }

  String _compact(double v) => NumberFormat.compact(locale: 'vi').format(v);

  FlTitlesData _titles(BuildContext context, {required Widget Function(double, TitleMeta) bottom, double bottomSize = 28}) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          getTitlesWidget: (value, meta) {
            if (value == meta.max && value != 0) return const SizedBox.shrink();
            return Text(_compact(value), style: TextStyle(fontSize: 10, color: context.textSecondary));
          },
        ),
      ),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: bottomSize, getTitlesWidget: bottom)),
    );
  }

  FlGridData _grid(BuildContext context) => FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: context.textPrimary.withValues(alpha: 0.06), strokeWidth: 1),
      );

  /// Hai cột cạnh nhau cho mỗi thành viên, chung một trục: đã ứng (xanh) và phải chịu (cam).
  Widget _buildMemberChart(BuildContext context, List<ExpenseWithDetails> expenses) {
    final paidColor = _series(context, 0);
    final shareColor = _series(context, 1);
    final paid = {for (final m in o.members) m.id: 0};
    final share = {for (final m in o.members) m.id: 0};
    for (final e in expenses) {
      paid[e.expense.payerId] = (paid[e.expense.payerId] ?? 0) + e.expense.amount;
      for (final s in e.shares) {
        share[s.member.id] = (share[s.member.id] ?? 0) + s.share.amount;
      }
    }
    final maxY = o.members.fold<int>(0, (m, mem) => math.max(m, math.max(paid[mem.id]!, share[mem.id]!)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 16, children: [_legendDot(context, paidColor, 'Đã ứng'), _legendDot(context, shareColor, 'Phải chịu')]),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxY == 0 ? 1 : maxY * 1.15,
              gridData: _grid(context),
              borderData: FlBorderData(show: false),
              titlesData: _titles(context, bottom: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= o.members.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(o.members[i].name, style: TextStyle(fontSize: 11, color: context.textSecondary), overflow: TextOverflow.ellipsis),
                );
              }),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => context.isDark ? const Color(0xFF2B3240) : const Color(0xFF1F2937),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                    '${o.members[group.x].name}\n${rodIndex == 0 ? 'Đã ứng' : 'Phải chịu'}: ${formatMoney(rod.toY.round(), currency)}',
                    const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < o.members.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 2,
                    barRods: [
                      BarChartRodData(
                        toY: paid[o.members[i].id]!.toDouble(),
                        color: paidColor,
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: share[o.members[i].id]!.toDouble(),
                        color: shareColor,
                        width: 12,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyChart(BuildContext context, List<ExpenseWithDetails> expenses) {
    final byDay = <DateTime, int>{};
    for (final e in expenses) {
      final d = DateUtils.dateOnly(e.expense.date);
      byDay[d] = (byDay[d] ?? 0) + e.expense.amount;
    }
    final days = byDay.keys.toList()..sort();
    final maxY = byDay.values.fold<int>(0, math.max);
    final color = _series(context, 0);
    // Tránh nhãn trục X chồng nhau khi có nhiều ngày.
    final labelEvery = math.max(1, (days.length / 6).ceil());

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY * 1.15,
          gridData: _grid(context),
          borderData: FlBorderData(show: false),
          titlesData: _titles(context, bottom: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= days.length || i % labelEvery != 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(formatShortDate(days[i]), style: TextStyle(fontSize: 10, color: context.textSecondary)),
            );
          }),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => context.isDark ? const Color(0xFF2B3240) : const Color(0xFF1F2937),
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${formatDate(days[group.x])}\n${formatMoney(rod.toY.round(), currency)}',
                const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: byDay[days[i]]!.toDouble(),
                  color: color,
                  width: days.length > 20 ? 6 : 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseList(BuildContext context) {
    final expenses = _filtered;
    if (expenses.isEmpty) {
      return Center(child: Text('Không có khoản chi phù hợp.', style: TextStyle(color: Colors.grey[500])));
    }
    final total = expenses.fold<int>(0, (s, e) => s + e.expense.amount);
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
          child: Text('${expenses.length} khoản chi · ${formatMoney(total, currency)}',
              style: TextStyle(color: context.textSecondary, fontWeight: FontWeight.w600)),
        ),
        ...expenses.map((e) => ExpenseTile(
              expenseData: e,
              currency: currency,
              onEdit: () async {
                final result = await context.push('/add-expense', extra: {
                  'group': o.group,
                  'members': o.members,
                  'expenseToEdit': e,
                });
                if (result == true && context.mounted) context.read<GroupDetailCubit>().reload();
              },
            )),
      ],
    );
  }
}
