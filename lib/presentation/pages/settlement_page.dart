import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/app_format.dart';
import '../../core/utils/report_builder.dart';
import '../../core/utils/share_helper.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/usecases/settlement_usecases.dart';
import '../../injection.dart';
import '../blocs/group_detail/group_detail_cubit.dart';
import '../blocs/group_detail/group_detail_state.dart';

/// Màn hình Quyết toán: số dư, giao dịch đề xuất, đánh dấu đã trả và lịch sử hoàn tiền.
class SettlementPage extends StatelessWidget {
  final int groupId;

  const SettlementPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<GroupDetailCubit>()..loadGroupDetail(groupId),
      child: BlocBuilder<GroupDetailCubit, GroupDetailState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              title: const Text('Quyết toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              centerTitle: true,
              leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => context.pop()),
              actions: [
                if (state is GroupDetailLoaded)
                  Builder(
                    builder: (buttonContext) => IconButton(
                      tooltip: 'Chia sẻ bảng quyết toán',
                      icon: const Icon(Icons.ios_share_rounded),
                      onPressed: () => ShareHelper.shareText(
                        buttonContext,
                        ReportBuilder.settlementText(state.overview),
                        subject: 'Quyết toán ${state.group.name}',
                      ),
                    ),
                  ),
              ],
            ),
            body: switch (state) {
              GroupDetailLoaded(:final overview) => _SettlementBody(overview: overview),
              GroupDetailError(:final message) => Center(child: Text(message, style: const TextStyle(color: Colors.red))),
              _ => const Center(child: CircularProgressIndicator()),
            },
          );
        },
      ),
    );
  }
}

class _SettlementBody extends StatelessWidget {
  final GroupOverview overview;

  const _SettlementBody({required this.overview});

  String get currency => overview.group.currency;

  void _showMessage(BuildContext context, String? error, {String? success}) {
    final text = error ?? success;
    if (text == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: error != null ? Colors.redAccent : positiveColor,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (overview.expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calculate_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Chưa có khoản chi để quyết toán', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _buildProgressCard(context).animate().fadeIn().slideY(begin: 0.1),
        const SizedBox(height: 28),
        _sectionTitle(context, 'Giao dịch đề xuất', Icons.swap_horiz_rounded,
            trailing: overview.suggestions.isEmpty ? null : '${overview.suggestions.length} giao dịch'),
        const SizedBox(height: 12),
        if (overview.suggestions.isEmpty)
          _buildAllSettled(context)
        else
          ...overview.suggestions.asMap().entries.map((e) => _buildSuggestionCard(context, e.value)
              .animate()
              .fadeIn(delay: Duration(milliseconds: 80 * e.key))
              .slideX(begin: 0.1)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: context.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ChiaPay không tự chuyển tiền. Hãy chuyển khoản bên ngoài rồi đánh dấu đã trả.',
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle(context, 'Số dư từng người', Icons.account_balance_wallet_outlined),
        const SizedBox(height: 12),
        _buildBalanceTable(context),
        const SizedBox(height: 28),
        _sectionTitle(context, 'Lịch sử thanh toán', Icons.history_rounded,
            trailing: overview.settlements.isEmpty ? null : '${overview.settlements.length}'),
        const SizedBox(height: 12),
        if (overview.settlements.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Chưa có giao dịch nào được xác nhận.', style: TextStyle(color: Colors.grey[500]))),
          )
        else
          ...overview.settlements.map((s) => _buildHistoryItem(context, s)),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title, IconData icon, {String? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.textSecondary),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        if (trailing != null) Text(trailing, style: TextStyle(color: context.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildProgressCard(BuildContext context) {
    final progress = overview.progress;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: progress.isComplete
              ? [const Color(0xFF16A34A), const Color(0xFF15803D)]
              : [Theme.of(context).primaryColor, const Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(progress.isComplete ? Icons.verified_rounded : Icons.timelapse_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                progress.isComplete ? 'Nhóm đã quyết toán xong' : 'Tiến độ quyết toán',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text('${(progress.ratio * 100).round()}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.ratio.toDouble(),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _progressStat('Đã hoàn trả', formatMoney(progress.settled, currency))),
              Expanded(child: _progressStat('Còn lại', formatMoney(progress.remaining, currency))),
              Expanded(child: _progressStat('Tổng cần chuyển', formatMoney(progress.totalToSettle, currency))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildAllSettled(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: positiveColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(Icons.celebration_rounded, color: positiveColor),
          SizedBox(width: 12),
          Expanded(
            child: Text('Mọi người đã cân bằng, không cần chuyển thêm tiền.',
                style: TextStyle(color: positiveColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, Member m, Color color) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: color.withValues(alpha: 0.12),
      child: Text(m.name.substring(0, 1).toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSuggestionCard(BuildContext context, SuggestedTransfer t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _avatar(context, t.from, negativeColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: t.from.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: '  chuyển cho  ', style: TextStyle(color: context.textSecondary, fontSize: 13)),
                        TextSpan(text: t.to.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    const SizedBox(height: 4),
                    Text(formatMoney(t.amount, currency),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: negativeColor)),
                  ],
                ),
              ),
              _avatar(context, t.to, positiveColor),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: positiveColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Đánh dấu đã trả', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _showMarkPaidSheet(context, t),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceTable(BuildContext context) {
    final headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textSecondary);
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 14,
          horizontalMargin: 16,
          headingRowHeight: 44,
          columns: [
            DataColumn(label: Text('Thành viên', style: headerStyle)),
            DataColumn(label: Text('Đã ứng', style: headerStyle), numeric: true),
            DataColumn(label: Text('Phải chịu', style: headerStyle), numeric: true),
            DataColumn(label: Text('Lý thuyết', style: headerStyle), numeric: true),
            DataColumn(label: Text('Còn lại', style: headerStyle), numeric: true, tooltip: 'Số tiền còn chưa quyết toán'),
          ],
          rows: overview.balances.map((b) {
            String signed(int v) => v == 0 ? '0' : '${v > 0 ? '+' : '−'}${formatNumber(v.abs())}';
            return DataRow(cells: [
              DataCell(Text(b.member.name, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(formatNumber(b.paid))),
              DataCell(Text(formatNumber(b.share))),
              DataCell(Text(signed(b.theoreticalBalance), style: TextStyle(color: balanceColor(b.theoreticalBalance)))),
              DataCell(Text(signed(b.remainingBalance),
                  style: TextStyle(fontWeight: FontWeight.bold, color: balanceColor(b.remainingBalance)))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, Settlement s) {
    final from = overview.memberById(s.fromMemberId)?.name ?? '?';
    final to = overview.memberById(s.toMemberId)?.name ?? '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0x1A16A34A),
          child: Icon(Icons.check_rounded, color: positiveColor),
        ),
        title: Text('$from → $to', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [formatDate(s.date), if (s.note != null && s.note!.isNotEmpty) s.note!].join(' · '),
          style: TextStyle(color: context.textSecondary, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatMoney(s.amount, currency), style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              tooltip: 'Hoàn tác',
              icon: const Icon(Icons.undo_rounded, color: Colors.redAccent),
              onPressed: () => _confirmUndo(context, s, '$from → $to'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmUndo(BuildContext context, Settlement s, String label) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hoàn tác giao dịch?'),
        content: Text('Bỏ đánh dấu "$label: ${formatMoney(s.amount, currency)}". Số tiền này sẽ được tính lại là chưa thanh toán.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final error = await context.read<GroupDetailCubit>().deleteSettlement(s.id);
              if (context.mounted) _showMessage(context, error, success: 'Đã hoàn tác giao dịch');
            },
            child: const Text('Hoàn tác', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Xác nhận giao dịch: cho phép sửa số tiền (thanh toán một phần), ngày và ghi chú.
  void _showMarkPaidSheet(BuildContext context, SuggestedTransfer t) {
    final cubit = context.read<GroupDetailCubit>();
    final amountController = TextEditingController(text: formatNumber(t.amount));
    final noteController = TextEditingController();
    var date = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(builder: (sheetContext, setSheetState) {
          final amount = parseAmount(amountController.text);
          final invalid = amount == null || amount <= 0;
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 20,
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
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Xác nhận đã thanh toán', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('${t.from.name} đã chuyển cho ${t.to.name}', style: TextStyle(color: sheetContext.textSecondary)),
                const SizedBox(height: 20),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setSheetState(() {}),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Số tiền',
                    suffixText: currency,
                    helperText: amount != null && amount < t.amount
                        ? 'Thanh toán một phần, còn lại ${formatMoney(t.amount - amount, currency)}'
                        : null,
                    filled: true,
                    fillColor: sheetContext.fieldColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    prefixIcon: Icon(Icons.payments_outlined, color: Colors.grey[400]),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: sheetContext,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setSheetState(() => date = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                    decoration: BoxDecoration(color: sheetContext.fieldColor, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, color: Colors.grey[400], size: 20),
                        const SizedBox(width: 14),
                        const Text('Ngày thanh toán'),
                        const Spacer(),
                        Text(formatDate(date), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'Ghi chú xác nhận (VD: Chuyển khoản MoMo)',
                    filled: true,
                    fillColor: sheetContext.fieldColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    prefixIcon: Icon(Icons.sticky_note_2_outlined, color: Colors.grey[400]),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: positiveColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    onPressed: invalid
                        ? null
                        : () async {
                            Navigator.pop(sheetContext);
                            final note = noteController.text.trim();
                            final error = await cubit.addSettlement(Settlement(
                              id: 0,
                              groupId: overview.group.id,
                              fromMemberId: t.from.id,
                              toMemberId: t.to.id,
                              amount: amount,
                              date: date,
                              note: note.isEmpty ? null : note,
                              createdAt: DateTime.now(),
                            ));
                            if (context.mounted) _showMessage(context, error, success: 'Đã ghi nhận thanh toán');
                          },
                    child: const Text('Xác nhận', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        });
      },
    );
  }
}
