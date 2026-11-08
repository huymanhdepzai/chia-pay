import '../entities/group.dart';
import '../repositories/group_repository.dart';

class GetGroups {
  final GroupRepository repository;

  GetGroups(this.repository);

  Future<List<Group>> call({bool archived = false}) {
    return repository.getGroups(archived: archived);
  }
}

class CreateGroup {
  final GroupRepository repository;

  CreateGroup(this.repository);

  Future<int> call(String name, String? description, {String currency = 'VND', DateTime? startDate, DateTime? endDate}) {
    return repository.createGroup(name, description, currency, startDate, endDate);
  }
}

class GetGroupById {
  final GroupRepository repository;

  GetGroupById(this.repository);

  Future<Group> call(int id) {
    return repository.getGroupById(id);
  }
}

class UpdateGroup {
  final GroupRepository repository;

  UpdateGroup(this.repository);

  Future<void> call(Group group) {
    return repository.updateGroup(group);
  }
}

class DeleteGroup {
  final GroupRepository repository;

  DeleteGroup(this.repository);

  Future<void> call(int id) {
    return repository.deleteGroup(id);
  }
}

class SetGroupArchived {
  final GroupRepository repository;

  SetGroupArchived(this.repository);

  Future<void> call(int id, bool archived) {
    return repository.setGroupArchived(id, archived);
  }
}
