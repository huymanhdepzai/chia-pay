import 'package:equatable/equatable.dart';
import 'member.dart';

/// Giao dịch hoàn tiền đã được xác nhận: [fromMemberId] đã trả [amount] cho [toMemberId].
/// Khác với khoản chi (sự kiện mua sắm), đây là việc hoàn trả giữa hai người.
class Settlement extends Equatable {
  final int id;
  final int groupId;
  final int fromMemberId;
  final int toMemberId;
  final int amount;
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  const Settlement({
    required this.id,
    required this.groupId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    required this.date,
    this.note,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, groupId, fromMemberId, toMemberId, amount, date, note, createdAt];
}

/// Giao dịch được thuật toán đề xuất (chưa thực hiện).
class SuggestedTransfer extends Equatable {
  final Member from;
  final Member to;
  final int amount;

  const SuggestedTransfer({required this.from, required this.to, required this.amount});

  @override
  List<Object?> get props => [from, to, amount];
}

/// Số dư của một thành viên trong nhóm.
///
/// - [paid]: tổng tiền đã ứng cho các khoản chi.
/// - [share]: tổng phần chi phí phải chịu.
/// - [sent] / [received]: tiền đã hoàn trả / đã nhận qua các giao dịch quyết toán.
class MemberBalance extends Equatable {
  final Member member;
  final int paid;
  final int share;
  final int sent;
  final int received;

  const MemberBalance({
    required this.member,
    required this.paid,
    required this.share,
    this.sent = 0,
    this.received = 0,
  });

  /// Số dư lý thuyết, chỉ tính từ khoản chi. Dương = cần nhận, âm = cần trả.
  int get theoreticalBalance => paid - share;

  /// Số tiền còn chưa quyết toán sau khi trừ các giao dịch đã xác nhận.
  int get remainingBalance => paid - share + sent - received;

  @override
  List<Object?> get props => [member, paid, share, sent, received];
}
