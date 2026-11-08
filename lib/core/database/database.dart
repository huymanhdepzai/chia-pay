import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'database.g.dart';

class Groups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('VND'))();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Members extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer().references(Groups, #id)();
  TextColumn get name => text()();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer().references(Groups, #id)();
  IntColumn get payerId => integer().references(Members, #id)();
  TextColumn get name => text()();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get category => text()();
  TextColumn get note => text().nullable()();
  TextColumn get splitType => text().withDefault(const Constant('equal'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class ExpenseShares extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get expenseId => integer().references(Expenses, #id)();
  IntColumn get memberId => integer().references(Members, #id)();
  IntColumn get amount => integer()();
  IntColumn get percentBp => integer().nullable()();
}

/// Giao dịch hoàn tiền đã xác nhận giữa hai thành viên (khác với khoản chi).
class Settlements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer().references(Groups, #id)();
  @ReferenceName('sentSettlements')
  IntColumn get fromMemberId => integer().references(Members, #id)();
  @ReferenceName('receivedSettlements')
  IntColumn get toMemberId => integer().references(Members, #id)();
  // ignore: recursive_getters
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Cài đặt ứng dụng dạng key-value (giao diện, tiền tệ mặc định, mã khóa...).
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Groups, Members, Expenses, ExpenseShares, Settlements, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(expenses);
          await m.createTable(expenseShares);
        }
        if (from < 3) {
          if (from >= 2) {
            // Các bảng tạo ở bước trên đã có sẵn cột mới.
            await m.addColumn(expenses, expenses.splitType);
            await m.addColumn(expenseShares, expenseShares.percentBp);
          }
          await m.addColumn(groups, groups.isArchived);
          await m.createTable(settlements);
          await m.createTable(appSettings);
        }
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        if (details.wasCreated || details.hadUpgrade) {
          await customStatement('CREATE INDEX IF NOT EXISTS idx_members_group ON members (group_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_expenses_group ON expenses (group_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_shares_expense ON expense_shares (expense_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_settlements_group ON settlements (group_id)');
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'chia_pay.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
