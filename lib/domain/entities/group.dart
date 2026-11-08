import 'package:equatable/equatable.dart';

class Group extends Equatable {
  final int id;
  final String name;
  final String? description;
  final String currency;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isArchived;
  final DateTime createdAt;

  const Group({
    required this.id,
    required this.name,
    this.description,
    this.currency = 'VND',
    this.startDate,
    this.endDate,
    this.isArchived = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, name, description, currency, startDate, endDate, isArchived, createdAt];

  Group copyWith({
    int? id,
    String? name,
    String? description,
    String? currency,
    DateTime? startDate,
    DateTime? endDate,
    bool? isArchived,
    DateTime? createdAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      currency: currency ?? this.currency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
