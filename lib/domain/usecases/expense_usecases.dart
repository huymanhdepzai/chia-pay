import '../entities/expense.dart';
import '../repositories/expense_repository.dart';

class GetExpensesByGroup {
  final ExpenseRepository repository;

  GetExpensesByGroup(this.repository);

  Future<List<ExpenseWithDetails>> call(int groupId) {
    return repository.getExpensesByGroup(groupId);
  }
}

class AddExpense {
  final ExpenseRepository repository;

  AddExpense(this.repository);

  Future<int> call(Expense expense, List<ExpenseShare> shares) {
    return repository.addExpense(expense, shares);
  }
}

class UpdateExpense {
  final ExpenseRepository repository;

  UpdateExpense(this.repository);

  Future<void> call(Expense expense, List<ExpenseShare> shares) {
    return repository.updateExpense(expense, shares);
  }
}

class DeleteExpense {
  final ExpenseRepository repository;

  DeleteExpense(this.repository);

  Future<void> call(int id) {
    return repository.deleteExpense(id);
  }
}
