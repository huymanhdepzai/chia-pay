import '../entities/member.dart';
import '../repositories/group_repository.dart';

class GetMembers {
  final GroupRepository repository;

  GetMembers(this.repository);

  Future<List<Member>> call(int groupId) {
    return repository.getMembers(groupId);
  }
}

class AddMember {
  final GroupRepository repository;

  AddMember(this.repository);

  Future<int> call(int groupId, String name) {
    return repository.addMember(groupId, name);
  }
}

class UpdateMember {
  final GroupRepository repository;

  UpdateMember(this.repository);

  Future<void> call(Member member) {
    return repository.updateMember(member);
  }
}

class DeleteMember {
  final GroupRepository repository;

  DeleteMember(this.repository);

  Future<void> call(int id) {
    return repository.deleteMember(id);
  }
}
