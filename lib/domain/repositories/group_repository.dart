import '../entities/group.dart';
import '../entities/member.dart';

/// Lỗi nghiệp vụ có thông điệp hiển thị được cho người dùng.
class DomainException implements Exception {
  final String message;

  const DomainException(this.message);

  @override
  String toString() => message;
}

abstract class GroupRepository {
  Future<List<Group>> getGroups({bool archived = false});
  Future<Group> getGroupById(int id);
  Future<int> createGroup(String name, String? description, String currency, DateTime? startDate, DateTime? endDate);
  Future<void> updateGroup(Group group);
  Future<void> deleteGroup(int id);
  Future<void> setGroupArchived(int id, bool archived);
  
  Future<List<Member>> getMembers(int groupId);
  Future<int> addMember(int groupId, String name);
  Future<void> updateMember(Member member);
  Future<void> deleteMember(int id);
}
