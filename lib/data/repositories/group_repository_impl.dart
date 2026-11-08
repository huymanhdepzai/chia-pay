import 'package:drift/drift.dart';
import '../../core/database/database.dart' hide Group, Member;
import '../../core/database/database.dart' as db;
import '../../domain/entities/group.dart' as entity;
import '../../domain/entities/member.dart' as entity;
import '../../domain/repositories/group_repository.dart';

class GroupRepositoryImpl implements GroupRepository {
  final AppDatabase _database;

  GroupRepositoryImpl(this._database);

  entity.Group _toEntity(db.Group g) => entity.Group(
        id: g.id,
        name: g.name,
        description: g.description,
        currency: g.currency,
        startDate: g.startDate,
        endDate: g.endDate,
        isArchived: g.isArchived,
        createdAt: g.createdAt,
      );

  @override
  Future<List<entity.Group>> getGroups({bool archived = false}) async {
    final query = _database.select(_database.groups)
      ..where((t) => t.isArchived.equals(archived))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    final groups = await query.get();
    return groups.map(_toEntity).toList();
  }

  @override
  Future<entity.Group> getGroupById(int id) async {
    final g = await (_database.select(_database.groups)..where((t) => t.id.equals(id))).getSingle();
    return _toEntity(g);
  }

  @override
  Future<int> createGroup(String name, String? description, String currency, DateTime? startDate, DateTime? endDate) async {
    return await _database.into(_database.groups).insert(
      db.GroupsCompanion.insert(
        name: name,
        description: Value(description),
        currency: Value(currency),
        startDate: Value(startDate),
        endDate: Value(endDate),
      ),
    );
  }

  @override
  Future<void> updateGroup(entity.Group group) async {
    await _database.update(_database.groups).replace(
      db.GroupsCompanion(
        id: Value(group.id),
        name: Value(group.name),
        description: Value(group.description),
        currency: Value(group.currency),
        startDate: Value(group.startDate),
        endDate: Value(group.endDate),
        isArchived: Value(group.isArchived),
        createdAt: Value(group.createdAt),
      ),
    );
  }

  @override
  Future<void> deleteGroup(int id) async {
    // Xóa theo thứ tự phụ thuộc khóa ngoại: phần chia -> khoản chi -> quyết toán -> thành viên -> nhóm.
    await _database.transaction(() async {
      final expenseIds = _database.selectOnly(_database.expenses)
        ..addColumns([_database.expenses.id])
        ..where(_database.expenses.groupId.equals(id));
      await (_database.delete(_database.expenseShares)..where((t) => t.expenseId.isInQuery(expenseIds))).go();
      await (_database.delete(_database.expenses)..where((t) => t.groupId.equals(id))).go();
      await (_database.delete(_database.settlements)..where((t) => t.groupId.equals(id))).go();
      await (_database.delete(_database.members)..where((t) => t.groupId.equals(id))).go();
      await (_database.delete(_database.groups)..where((t) => t.id.equals(id))).go();
    });
  }

  @override
  Future<void> setGroupArchived(int id, bool archived) async {
    await (_database.update(_database.groups)..where((t) => t.id.equals(id)))
        .write(db.GroupsCompanion(isArchived: Value(archived)));
  }

  @override
  Future<List<entity.Member>> getMembers(int groupId) async {
    final members = await (_database.select(_database.members)..where((t) => t.groupId.equals(groupId))).get();
    return members.map((m) => entity.Member(
      id: m.id,
      groupId: m.groupId,
      name: m.name,
    )).toList();
  }

  @override
  Future<int> addMember(int groupId, String name) async {
    return await _database.into(_database.members).insert(
      db.MembersCompanion.insert(
        groupId: groupId,
        name: name,
      ),
    );
  }

  @override
  Future<void> updateMember(entity.Member member) async {
    await _database.update(_database.members).replace(
      db.MembersCompanion(
        id: Value(member.id),
        groupId: Value(member.groupId),
        name: Value(member.name),
      ),
    );
  }

  @override
  Future<void> deleteMember(int id) async {
    await _database.transaction(() async {
      final paid = await (_database.select(_database.expenses)..where((t) => t.payerId.equals(id))..limit(1)).get();
      final shares = await (_database.select(_database.expenseShares)..where((t) => t.memberId.equals(id))..limit(1)).get();
      final settlements = await (_database.select(_database.settlements)
            ..where((t) => t.fromMemberId.equals(id) | t.toMemberId.equals(id))
            ..limit(1))
          .get();
      if (paid.isNotEmpty || shares.isNotEmpty || settlements.isNotEmpty) {
        throw const DomainException(
            'Không thể xóa thành viên đã có khoản chi hoặc giao dịch quyết toán. Hãy sửa/xóa các khoản đó trước.');
      }
      await (_database.delete(_database.members)..where((t) => t.id.equals(id))).go();
    });
  }
}
