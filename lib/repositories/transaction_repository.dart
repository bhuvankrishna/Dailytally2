import '../models/app_database.dart';

/// Abstract base class for transaction repositories
abstract class TransactionRepository {
  /// Get all transactions
  Future<List<Transaction>> getAllTransactions();

  /// Get transaction by ID
  Future<Transaction?> getTransactionById(int id);

  /// Add a new transaction
  Future<int> addTransaction(TransactionsCompanion transaction);

  /// Update an existing transaction
  Future<bool> updateTransaction(Transaction transaction);

  /// Delete a transaction
  Future<bool> deleteTransaction(int id);

  /// Get transactions filtered by type (income/expense)
  Future<List<Transaction>> getTransactionsByType(String type);

  /// Get transactions filtered by category
  Future<List<Transaction>> getTransactionsByCategory(String category);

  /// Get transactions within a date range
  Future<List<Transaction>> getTransactionsByDateRange(
      DateTime startDate, DateTime endDate);

  /// Stream of all transactions (for reactive UI updates)
  Stream<List<Transaction>> watchAllTransactions();
}
