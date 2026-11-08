import 'package:chia_pay/core/database/database.dart';
import 'package:chia_pay/data/repositories/group_repository_impl.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Schema v2 (trước khi có quyết toán, lưu trữ nhóm và kiểu chia), kèm dữ liệu mẫu.
const _v2Schema = [
  "CREATE TABLE groups (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, description TEXT NULL, "
      "currency TEXT NOT NULL DEFAULT 'VND', start_date INTEGER NULL, end_date INTEGER NULL, "
      "created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)))",
  'CREATE TABLE members (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, group_id INTEGER NOT NULL REFERENCES groups (id), name TEXT NOT NULL)',
  'CREATE TABLE expenses (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, group_id INTEGER NOT NULL REFERENCES groups (id), '
      'payer_id INTEGER NOT NULL REFERENCES members (id), name TEXT NOT NULL, amount INTEGER NOT NULL, date INTEGER NOT NULL, '
      "category TEXT NOT NULL, note TEXT NULL, created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)))",
  'CREATE TABLE expense_shares (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, expense_id INTEGER NOT NULL REFERENCES expenses (id), '
      'member_id INTEGER NOT NULL REFERENCES members (id), amount INTEGER NOT NULL)',
  "INSERT INTO groups (id, name) VALUES (1, 'Nhóm cũ')",
  "INSERT INTO members (id, group_id, name) VALUES (1, 1, 'An'), (2, 1, 'Bình')",
  "INSERT INTO expenses (id, group_id, payer_id, name, amount, date, category) VALUES (1, 1, 1, 'Ăn tối', 200000, 1767225600, 'Ăn uống')",
  'INSERT INTO expense_shares (expense_id, member_id, amount) VALUES (1, 1, 100000), (1, 2, 100000)',
  'PRAGMA user_version = 2',
];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('nâng cấp từ schema v2 lên v3 giữ nguyên dữ liệu cũ', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      for (final sql in _v2Schema) {
        raw.execute(sql);
      }
    }));
    addTearDown(db.close);

    final groups = await GroupRepositoryImpl(db).getGroups();
    expect(groups.single.name, 'Nhóm cũ');
    expect(groups.single.isArchived, isFalse);

    final expense = await db.select(db.expenses).getSingle();
    expect(expense.splitType, 'equal');
    expect(expense.amount, 200000);

    final shares = await db.select(db.expenseShares).get();
    expect(shares.map((s) => s.percentBp), [null, null]);

    // Bảng mới dùng được ngay sau khi nâng cấp.
    await db.into(db.settlements).insert(SettlementsCompanion.insert(
          groupId: 1, fromMemberId: 2, toMemberId: 1, amount: 100000, date: DateTime(2026)));
    expect(await db.select(db.settlements).get(), hasLength(1));
    await db.into(db.appSettings).insert(AppSettingsCompanion.insert(key: 'k', value: 'v'));
  });

  test('schema mới từ chối giao dịch quyết toán có số tiền <= 0', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final g = await db.into(db.groups).insert(GroupsCompanion.insert(name: 'G'));
    final a = await db.into(db.members).insert(MembersCompanion.insert(groupId: g, name: 'A'));
    final b = await db.into(db.members).insert(MembersCompanion.insert(groupId: g, name: 'B'));
    expect(
      () => db.into(db.settlements).insert(SettlementsCompanion.insert(
            groupId: g, fromMemberId: a, toMemberId: b, amount: 0, date: DateTime(2026))),
      throwsA(anything),
    );
  });
}
