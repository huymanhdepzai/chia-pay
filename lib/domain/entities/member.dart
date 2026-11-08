import 'package:equatable/equatable.dart';

class Member extends Equatable {
  final int id;
  final int groupId;
  final String name;

  const Member({
    required this.id,
    required this.groupId,
    required this.name,
  });

  @override
  List<Object?> get props => [id, groupId, name];

  Member copyWith({
    int? id,
    int? groupId,
    String? name,
  }) {
    return Member(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
    );
  }
}
