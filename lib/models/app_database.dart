import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get type => text().withLength(min: 1, max: 10)();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get type => text().withLength(min: 1, max: 10)();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text().withLength(min: 0, max: 200)();
  RealColumn get amount => real()();
}

class BudgetLimits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  RealColumn get limitAmount => real()();
  TextColumn get period => text().withLength(min: 1, max: 20)();
}

class RecurringExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  RealColumn get amount => real()();
  TextColumn get frequency => text().withLength(min: 1, max: 20)();
  DateTimeColumn get nextDueDate => dateTime().named('next_due_date')();
}

// Opens the database in the device's file system asynchronously.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'dailytally.sqlite'));
    return NativeDatabase(file, logStatements: true);
  });
}

@DriftDatabase(tables: [Categories, Transactions, BudgetLimits, RecurringExpenses])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  /// Seeds default categories if table is empty
  Future<void> seedDefaultCategories() async {
    final existing = await select(categories).get();
    if (existing.isEmpty) {
      await batch((b) {
        b.insertAll(categories, [
          CategoriesCompanion.insert(name: 'Salary', type: 'Income'),
          CategoriesCompanion.insert(name: 'Freelance', type: 'Income'),
          CategoriesCompanion.insert(name: 'Investments', type: 'Income'),
          CategoriesCompanion.insert(name: 'Rent', type: 'Income'),
          CategoriesCompanion.insert(name: 'Other Income', type: 'Income'),
          CategoriesCompanion.insert(name: 'Wallet', type: 'Income'),

          CategoriesCompanion.insert(name: 'Food', type: 'Expense'),
          CategoriesCompanion.insert(name: 'Transport', type: 'Expense'),
          CategoriesCompanion.insert(name: 'Utilities', type: 'Expense'),
          CategoriesCompanion.insert(name: 'Entertainment', type: 'Expense'),
          CategoriesCompanion.insert(name: 'Utilities', type: 'Expense'),
          CategoriesCompanion.insert(name: 'Rent', type: 'Expense'),
          CategoriesCompanion.insert(name: 'Shopping', type: 'Expense'),
          CategoriesCompanion.insert(name: 'Healthcare', type: 'Expense'),
          CategoriesCompanion.insert(name: 'Education', type: 'Expense'),
          CategoriesCompanion.insert(name: 'Other expenses', type: 'Expense'),
          CategoriesCompanion.insert(name: 'Fast Tag', type: 'Expense'),
          CategoriesCompanion.insert(name: 'Fuel', type: 'Expense'),
          CategoriesCompanion.insert(name: 'Groceries', type: 'Expense'),
          CategoriesCompanion.insert(name: 'Home loan', type: 'Expense'),
          CategoriesCompanion.insert(name: 'Electricity', type: 'Expense'),
          CategoriesCompanion.insert(name: 'Water', type: 'Expense'),
        ]);
      });
    }
  }
}
