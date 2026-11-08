import 'dart:convert';
import '../../core/database/database.dart' as db;
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final db.AppDatabase _database;

  SettingsRepositoryImpl(this._database);

  @override
  Future<String?> get(String key) async {
    final row = await (_database.select(_database.appSettings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> set(String key, String value) async {
    await _database.into(_database.appSettings).insertOnConflictUpdate(
          db.AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  @override
  Future<void> remove(String key) async {
    await (_database.delete(_database.appSettings)..where((t) => t.key.equals(key))).go();
  }
}

class BackupRepositoryImpl implements BackupRepository {
  static const _format = 'chiapay-backup';
  static const _version = 1;

  final db.AppDatabase _database;

  BackupRepositoryImpl(this._database);

  @override
  Future<String> exportJson() async {
    // Không sao lưu bảng cài đặt để không mang theo mã khóa ứng dụng.
    final data = {
      'format': _format,
      'version': _version,
      'exportedAt': DateTime.now().toIso8601String(),
      'groups': (await _database.select(_database.groups).get()).map((r) => r.toJson()).toList(),
      'members': (await _database.select(_database.members).get()).map((r) => r.toJson()).toList(),
      'expenses': (await _database.select(_database.expenses).get()).map((r) => r.toJson()).toList(),
      'expenseShares': (await _database.select(_database.expenseShares).get()).map((r) => r.toJson()).toList(),
      'settlements': (await _database.select(_database.settlements).get()).map((r) => r.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  @override
  Future<void> importJson(String json) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const FormatException('File không phải JSON hợp lệ');
    }
    if (decoded is! Map<String, dynamic> || decoded['format'] != _format) {
      throw const FormatException('File không phải bản sao lưu ChiaPay');
    }
    if ((decoded['version'] as int? ?? 0) > _version) {
      throw const FormatException('Bản sao lưu được tạo bởi phiên bản ChiaPay mới hơn');
    }

    List<T> rows<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      final list = decoded as Map<String, dynamic>;
      return (list[key] as List? ?? const []).cast<Map<String, dynamic>>().map(fromJson).toList();
    }

    final List<db.Group> groups;
    final List<db.Member> members;
    final List<db.Expense> expenses;
    final List<db.ExpenseShare> shares;
    final List<db.Settlement> settlements;
    try {
      groups = rows('groups', db.Group.fromJson);
      members = rows('members', db.Member.fromJson);
      expenses = rows('expenses', db.Expense.fromJson);
      shares = rows('expenseShares', db.ExpenseShare.fromJson);
      settlements = rows('settlements', db.Settlement.fromJson);
    } catch (_) {
      throw const FormatException('Dữ liệu trong bản sao lưu bị hỏng');
    }

    await _database.transaction(() async {
      await _database.delete(_database.expenseShares).go();
      await _database.delete(_database.settlements).go();
      await _database.delete(_database.expenses).go();
      await _database.delete(_database.members).go();
      await _database.delete(_database.groups).go();
      await _database.batch((b) {
        b.insertAll(_database.groups, groups);
        b.insertAll(_database.members, members);
        b.insertAll(_database.expenses, expenses);
        b.insertAll(_database.expenseShares, shares);
        b.insertAll(_database.settlements, settlements);
      });
    });
  }
}
