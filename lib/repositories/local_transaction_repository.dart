import '../models/app_database.dart';
import 'transaction_repository.dart';

/// Local implementation of TransactionRepository using Drift database
class LocalTransactionRepository implements TransactionRepository {
  final AppDatabase _db;

  LocalTransactionRepository(this._db);

  @override
  Future<List<Transaction>> getAllTransactions() async {
    return await _db.select(_db.transactions).get();
  }

  @override
  Future<Transaction?> getTransactionById(int id) async {
    final query = _db.select(_db.transactions)
      ..where((tbl) => tbl.id.equals(id));
    final results = await query.get();
    return results.isEmpty ? null : results.first;
  }

  @override
  Future<int> addTransaction(TransactionsCompanion transaction) async {
    return await _db.into(_db.transactions).insert(transaction);
  }

  @override
  Future<bool> updateTransaction(Transaction transaction) async {
    return await _db.update(_db.transactions).replace(transaction);
  }

  @override
  Future<bool> deleteTransaction(int id) async {
    final rowsAffected = await (_db.delete(_db.transactions)
      ..where((tbl) => tbl.id.equals(id)))
      .go();
    return rowsAffected > 0;
  }

  @override
  Future<List<Transaction>> getTransactionsByType(String type) async {
    final query = _db.select(_db.transactions)
      ..where((tbl) => tbl.type.equals(type));
    return await query.get();
  }

  @override
  Future<List<Transaction>> getTransactionsByCategory(String category) async {
    final query = _db.select(_db.transactions)
      ..where((tbl) => tbl.category.equals(category));
    return await query.get();
  }

  @override
  Future<List<Transaction>> getTransactionsByDateRange(
      DateTime startDate, DateTime endDate) async {
    final query = _db.select(_db.transactions)
      ..where((tbl) => tbl.date.isBiggerThanValue(
          startDate.subtract(const Duration(seconds: 1))))
      ..where((tbl) => tbl.date.isSmallerThanValue(
          endDate.add(const Duration(seconds: 1))));
    return await query.get();
  }

  @override
  Stream<List<Transaction>> watchAllTransactions() {
    return _db.select(_db.transactions).watch();
  }
}
