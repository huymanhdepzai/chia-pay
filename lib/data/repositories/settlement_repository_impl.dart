import 'package:drift/drift.dart';
import '../../core/database/database.dart' as db;
import '../../domain/entities/settlement.dart' as entity;
import '../../domain/repositories/settlement_repository.dart';

class SettlementRepositoryImpl implements SettlementRepository {
  final db.AppDatabase _database;

  SettlementRepositoryImpl(this._database);

  @override
  Future<List<entity.Settlement>> getSettlementsByGroup(int groupId) async {
    final rows = await (_database.select(_database.settlements)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.desc(t.date), (t) => OrderingTerm.desc(t.id)]))
        .get();
    return rows
        .map((s) => entity.Settlement(
              id: s.id,
              groupId: s.groupId,
              fromMemberId: s.fromMemberId,
              toMemberId: s.toMemberId,
              amount: s.amount,
              date: s.date,
              note: s.note,
              createdAt: s.createdAt,
            ))
        .toList();
  }

  @override
  Future<int> addSettlement(entity.Settlement settlement) {
    return _database.into(_database.settlements).insert(
          db.SettlementsCompanion.insert(
            groupId: settlement.groupId,
            fromMemberId: settlement.fromMemberId,
            toMemberId: settlement.toMemberId,
            amount: settlement.amount,
            date: settlement.date,
            note: Value(settlement.note),
          ),
        );
  }

  @override
  Future<void> deleteSettlement(int id) async {
    await (_database.delete(_database.settlements)..where((t) => t.id.equals(id))).go();
  }
}
