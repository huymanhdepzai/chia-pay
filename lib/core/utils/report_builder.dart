import '../../domain/usecases/settlement_usecases.dart';
import 'app_format.dart';

/// Tạo nội dung chia sẻ cho người khác (thành viên không đồng bộ dữ liệu giữa các máy).
class ReportBuilder {
  const ReportBuilder._();

  /// Bảng quyết toán dạng văn bản để gửi qua ứng dụng nhắn tin.
  static String settlementText(GroupOverview o) {
    final c = o.group.currency;
    final buf = StringBuffer()
      ..writeln('💰 ChiaPay – ${o.group.name}')
      ..writeln('Tổng chi tiêu: ${formatMoney(o.totalExpense, c)} (${o.expenses.length} khoản chi)')
      ..writeln()
      ..writeln('📊 Số dư từng người:');
    for (final b in o.balances) {
      final r = b.remainingBalance;
      final status = r > 0 ? 'cần nhận ${formatMoney(r, c)}' : (r < 0 ? 'cần trả ${formatMoney(-r, c)}' : 'đã cân bằng');
      buf.writeln('• ${b.member.name}: đã ứng ${formatMoney(b.paid, c)}, phải chịu ${formatMoney(b.share, c)} → $status');
    }
    buf.writeln();
    if (o.suggestions.isEmpty) {
      buf.writeln('✅ Nhóm đã quyết toán xong.');
    } else {
      buf.writeln('🔁 Cần chuyển:');
      for (final t in o.suggestions) {
        buf.writeln('• ${t.from.name} → ${t.to.name}: ${formatMoney(t.amount, c)}');
      }
    }
    if (o.settlements.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('✔️ Đã thanh toán:');
      for (final s in o.settlements) {
        final from = o.memberById(s.fromMemberId)?.name ?? '?';
        final to = o.memberById(s.toMemberId)?.name ?? '?';
        buf.writeln('• ${formatDate(s.date)} $from → $to: ${formatMoney(s.amount, c)}${s.note != null ? ' (${s.note})' : ''}');
      }
    }
    return buf.toString().trimRight();
  }

  /// Danh sách khoản chi dạng CSV, mỗi thành viên một cột phần chia.
  static String expensesCsv(GroupOverview o, {int? payerId}) {
    final expenses = payerId == null ? o.expenses : o.expenses.where((e) => e.expense.payerId == payerId);
    final rows = <List<String>>[
      ['Ngày', 'Tên khoản chi', 'Danh mục', 'Người trả', 'Số tiền', 'Cách chia', 'Ghi chú', ...o.members.map((m) => m.name)],
    ];
    for (final e in expenses) {
      final shareOf = {for (final s in e.shares) s.member.id: s.share.amount};
      rows.add([
        formatDate(e.expense.date),
        e.expense.name,
        e.expense.category,
        e.payer.name,
        '${e.expense.amount}',
        e.expense.splitType,
        e.expense.note ?? '',
        ...o.members.map((m) => '${shareOf[m.id] ?? 0}'),
      ]);
    }
    rows
      ..add([])
      ..add(['Thành viên', 'Đã ứng', 'Phải chịu', 'Số dư lý thuyết', 'Đã trả', 'Đã nhận', 'Còn lại']);
    for (final b in o.balances) {
      rows.add([
        b.member.name,
        '${b.paid}',
        '${b.share}',
        '${b.theoreticalBalance}',
        '${b.sent}',
        '${b.received}',
        '${b.remainingBalance}',
      ]);
    }
    return rows.map((r) => r.map(_escape).join(',')).join('\r\n');
  }

  static String _escape(String value) {
    if (value.contains(RegExp(r'[",\r\n]'))) return '"${value.replaceAll('"', '""')}"';
    return value;
  }
}
