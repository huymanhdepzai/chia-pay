import 'package:drift/drift.dart';
import '../../core/database/database.dart' as db;
import '../../domain/entities/expense.dart' as entity;
import '../../domain/entities/member.dart' as entity;
import '../../domain/repositories/expense_repository.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final db.AppDatabase _database;

  ExpenseRepositoryImpl(this._database);

  entity.Member _toMember(db.Member m) => entity.Member(id: m.id, groupId: m.groupId, name: m.name);

  entity.Expense _toExpense(db.Expense e) => entity.Expense(
        id: e.id,
        groupId: e.groupId,
        payerId: e.payerId,
        name: e.name,
        amount: e.amount,
        date: e.date,
        category: e.category,
        note: e.note,
        splitType: e.splitType,
        createdAt: e.createdAt,
      );

  /// Đọc khoản chi kèm người trả và các phần chia. Phần chia được lấy bằng một truy vấn
  /// cho toàn bộ danh sách thay vì một truy vấn cho mỗi khoản chi.
  Future<List<entity.ExpenseWithDetails>> _load(Expression<bool> filter) async {
    final query = _database.select(_database.expenses).join([
      innerJoin(_database.members, _database.members.id.equalsExp(_database.expenses.payerId)),
    ])
      ..where(filter)
      ..orderBy([OrderingTerm.desc(_database.expenses.date), OrderingTerm.desc(_database.expenses.id)]);

    final rows = await query.get();
    if (rows.isEmpty) return [];

    final ids = rows.map((r) => r.readTable(_database.expenses).id).toList();
    final sharesQuery = _database.select(_database.expenseShares).join([
      innerJoin(_database.members, _database.members.id.equalsExp(_database.expenseShares.memberId)),
    ])
      ..where(_database.expenseShares.expenseId.isIn(ids))
      ..orderBy([OrderingTerm.asc(_database.expenseShares.id)]);

    final sharesByExpense = <int, List<entity.ExpenseShareWithMember>>{};
    for (final sr in await sharesQuery.get()) {
      final shareRow = sr.readTable(_database.expenseShares);
      sharesByExpense.putIfAbsent(shareRow.expenseId, () => []).add(entity.ExpenseShareWithMember(
            share: entity.ExpenseShare(
              id: shareRow.id,
              expenseId: shareRow.expenseId,
              memberId: shareRow.memberId,
              amount: shareRow.amount,
              percentBp: shareRow.percentBp,
            ),
            member: _toMember(sr.readTable(_database.members)),
          ));
    }

    return rows.map((row) {
      final expenseRow = row.readTable(_database.expenses);
      return entity.ExpenseWithDetails(
        expense: _toExpense(expenseRow),
        payer: _toMember(row.readTable(_database.members)),
        shares: sharesByExpense[expenseRow.id] ?? const [],
      );
    }).toList();
  }

  @override
  Future<List<entity.ExpenseWithDetails>> getExpensesByGroup(int groupId) {
    return _load(_database.expenses.groupId.equals(groupId));
  }

  @override
  Future<entity.ExpenseWithDetails> getExpenseById(int id) async {
    final result = await _load(_database.expenses.id.equals(id));
    if (result.isEmpty) throw StateError('Không tìm thấy khoản chi $id');
    return result.first;
  }

  Future<void> _insertShares(int expenseId, List<entity.ExpenseShare> shares) async {
    for (final share in shares) {
      await _database.into(_database.expenseShares).insert(
            db.ExpenseSharesCompanion.insert(
              expenseId: expenseId,
              memberId: share.memberId,
              amount: share.amount,
              percentBp: Value(share.percentBp),
            ),
          );
    }
  }

  @override
  Future<int> addExpense(entity.Expense expense, List<entity.ExpenseShare> shares) async {
    return await _database.transaction(() async {
      final expenseId = await _database.into(_database.expenses).insert(
            db.ExpensesCompanion.insert(
              groupId: expense.groupId,
              payerId: expense.payerId,
              name: expense.name,
              amount: expense.amount,
              date: expense.date,
              category: expense.category,
              note: Value(expense.note),
              splitType: Value(expense.splitType),
              createdAt: Value(expense.createdAt),
            ),
          );
      await _insertShares(expenseId, shares);
      return expenseId;
    });
  }

  @override
  Future<void> updateExpense(entity.Expense expense, List<entity.ExpenseShare> shares) async {
    return await _database.transaction(() async {
      await _database.update(_database.expenses).replace(
            db.ExpensesCompanion(
              id: Value(expense.id),
              groupId: Value(expense.groupId),
              payerId: Value(expense.payerId),
              name: Value(expense.name),
              amount: Value(expense.amount),
              date: Value(expense.date),
              category: Value(expense.category),
              note: Value(expense.note),
              splitType: Value(expense.splitType),
              createdAt: Value(expense.createdAt),
            ),
          );

      // Xóa shares cũ và thêm mới (cách đơn giản nhất để update)
      await (_database.delete(_database.expenseShares)..where((t) => t.expenseId.equals(expense.id))).go();
      await _insertShares(expense.id, shares);
    });
  }

  @override
  Future<void> deleteExpense(int id) async {
    await _database.transaction(() async {
      await (_database.delete(_database.expenseShares)..where((t) => t.expenseId.equals(id))).go();
      await (_database.delete(_database.expenses)..where((t) => t.id.equals(id))).go();
    });
  }
}
