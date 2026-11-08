import '../entities/settlement.dart';

abstract class SettlementRepository {
  Future<List<Settlement>> getSettlementsByGroup(int groupId);
  Future<int> addSettlement(Settlement settlement);
  Future<void> deleteSettlement(int id);
}
