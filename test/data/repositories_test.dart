import 'package:chia_pay/core/database/database.dart';
import 'package:chia_pay/data/repositories/expense_repository_impl.dart';
import 'package:chia_pay/data/repositories/group_repository_impl.dart';
import 'package:chia_pay/data/repositories/settings_repository_impl.dart';
import 'package:chia_pay/data/repositories/settlement_repository_impl.dart';
import 'package:chia_pay/domain/entities/expense.dart' as e;
import 'package:chia_pay/domain/entities/settlement.dart' as e;
import 'package:chia_pay/domain/repositories/group_repository.dart';
import 'package:chia_pay/domain/usecases/settlement_usecases.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late GroupRepositoryImpl groups;
  late ExpenseRepositoryImpl expenses;
  late SettlementRepositoryImpl settlements;
  late GetGroupOverview overview;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    groups = GroupRepositoryImpl(db);
    expenses = ExpenseRepositoryImpl(db);
    settlements = SettlementRepositoryImpl(db);
    overview = GetGroupOverview(groupRepository: groups, expenseRepository: expenses, settlementRepository: settlements);
  });

  tearDown(() => db.close());

  Future<int> addExpense(int groupId, int payerId, int amount, Map<int, int> shares) {
    return expenses.addExpense(
      e.Expense(
        id: 0,
        groupId: groupId,
        payerId: payerId,
        name: 'Chi $amount',
        amount: amount,
        date: DateTime(2026, 3, 1),
        category: 'Ăn uống',
        createdAt: DateTime(2026, 3, 1),
      ),
      shares.entries.map((s) => e.ExpenseShare(id: 0, expenseId: 0, memberId: s.key, amount: s.value)).toList(),
    );
  }

  Future<({int group, int an, int binh})> seed() async {
    final g = await groups.createGroup('Đà Lạt', null, 'VND', null, null);
    final an = await groups.addMember(g, 'An');
    final binh = await groups.addMember(g, 'Bình');
    return (group: g, an: an, binh: binh);
  }

  test('lưu khoản chi cùng phần chia và tính số dư từ dữ liệu gốc', () async {
    final s = await seed();
    await addExpense(s.group, s.an, 100000, {s.an: 50000, s.binh: 50000});

    final o = await overview(s.group);
    expect(o.totalExpense, 100000);
    expect(o.balanceOf(s.an)!.remainingBalance, 50000);
    expect(o.suggestions.single.amount, 50000);
  });

  test('đánh dấu đã trả rồi hoàn tác', () async {
    final s = await seed();
    await addExpense(s.group, s.an, 100000, {s.an: 50000, s.binh: 50000});
    final id = await settlements.addSettlement(e.Settlement(
      id: 0,
      groupId: s.group,
      fromMemberId: s.binh,
      toMemberId: s.an,
      amount: 50000,
      date: DateTime(2026, 3, 2),
      note: 'MoMo',
      createdAt: DateTime(2026, 3, 2),
    ));

    var o = await overview(s.group);
    expect(o.progress.isComplete, isTrue);
    expect(o.balanceOf(s.binh)!.theoreticalBalance, -50000);
    expect(o.settlements.single.note, 'MoMo');

    await settlements.deleteSettlement(id);
    o = await overview(s.group);
    expect(o.progress.isComplete, isFalse);
    expect(o.suggestions.single.amount, 50000);
  });

  test('không xóa được thành viên đã có khoản chi, xóa được thành viên mới', () async {
    final s = await seed();
    await addExpense(s.group, s.an, 100000, {s.an: 50000, s.binh: 50000});
    final chi = await groups.addMember(s.group, 'Chi');

    expect(() => groups.deleteMember(s.binh), throwsA(isA<DomainException>()));
    await groups.deleteMember(chi);
    expect((await groups.getMembers(s.group)).length, 2);
  });

  test('xóa nhóm xóa toàn bộ dữ liệu liên quan (foreign key bật)', () async {
    final s = await seed();
    await addExpense(s.group, s.an, 100000, {s.an: 50000, s.binh: 50000});
    await settlements.addSettlement(e.Settlement(
      id: 0, groupId: s.group, fromMemberId: s.binh, toMemberId: s.an,
      amount: 10000, date: DateTime(2026), createdAt: DateTime(2026),
    ));

    await groups.deleteGroup(s.group);
    expect(await db.select(db.groups).get(), isEmpty);
    expect(await db.select(db.members).get(), isEmpty);
    expect(await db.select(db.expenses).get(), isEmpty);
    expect(await db.select(db.expenseShares).get(), isEmpty);
    expect(await db.select(db.settlements).get(), isEmpty);
  });

  test('lưu trữ nhóm ẩn khỏi danh sách đang hoạt động', () async {
    final s = await seed();
    await groups.setGroupArchived(s.group, true);
    expect(await groups.getGroups(), isEmpty);
    expect((await groups.getGroups(archived: true)).single.isArchived, isTrue);
  });

  test('sửa khoản chi thay phần chia cũ', () async {
    final s = await seed();
    final id = await addExpense(s.group, s.an, 100000, {s.an: 50000, s.binh: 50000});
    final old = await expenses.getExpenseById(id);
    await expenses.updateExpense(
      e.Expense(
        id: id, groupId: s.group, payerId: s.an, name: old.expense.name, amount: 90000,
        date: old.expense.date, category: old.expense.category, splitType: 'percent', createdAt: old.expense.createdAt,
      ),
      [e.ExpenseShare(id: 0, expenseId: id, memberId: s.binh, amount: 90000, percentBp: 10000)],
    );
    final updated = await expenses.getExpenseById(id);
    expect(updated.expense.splitType, 'percent');
    expect(updated.shares.single.share.percentBp, 10000);
    expect((await overview(s.group)).balanceOf(s.binh)!.remainingBalance, -90000);
  });

  test('sao lưu rồi khôi phục giữ nguyên dữ liệu', () async {
    final s = await seed();
    await addExpense(s.group, s.an, 100000, {s.an: 50000, s.binh: 50000});
    final backup = BackupRepositoryImpl(db);
    final json = await backup.exportJson();

    await groups.deleteGroup(s.group);
    expect(await groups.getGroups(), isEmpty);

    await backup.importJson(json);
    final o = await overview(s.group);
    expect(o.group.name, 'Đà Lạt');
    expect(o.members.length, 2);
    expect(o.totalExpense, 100000);
    expect(o.expenses.single.shares.length, 2);
  });

  test('khôi phục file không hợp lệ báo lỗi và không làm mất dữ liệu', () async {
    final s = await seed();
    final backup = BackupRepositoryImpl(db);
    expect(() => backup.importJson('{"format":"khac"}'), throwsA(isA<FormatException>()));
    expect(() => backup.importJson('không phải json'), throwsA(isA<FormatException>()));
    expect((await groups.getGroups()).single.id, s.group);
  });

  test('cài đặt dạng key-value', () async {
    final settings = SettingsRepositoryImpl(db);
    expect(await settings.get('theme_mode'), isNull);
    await settings.set('theme_mode', 'dark');
    await settings.set('theme_mode', 'light');
    expect(await settings.get('theme_mode'), 'light');
    await settings.remove('theme_mode');
    expect(await settings.get('theme_mode'), isNull);
  });
}
