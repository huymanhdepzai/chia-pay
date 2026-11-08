import '../entities/expense.dart';

abstract class ExpenseRepository {
  Future<List<ExpenseWithDetails>> getExpensesByGroup(int groupId);
  Future<ExpenseWithDetails> getExpenseById(int id);
  Future<int> addExpense(Expense expense, List<ExpenseShare> shares);
  Future<void> updateExpense(Expense expense, List<ExpenseShare> shares);
  Future<void> deleteExpense(int id);
}
