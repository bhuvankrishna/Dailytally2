import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

enum CategoryType { Income, Expense }
enum BudgetPeriod { Monthly, Weekly, Yearly }

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get type => text().map(const EnumNameConverter<CategoryType>(CategoryType.values))();
}

class Transactions extends Table {
  @Index(['categoryId'])
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id, onDelete: KeyAction.setNull)();
  TextColumn get type => text().withLength(min: 1, max: 10)();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text().withLength(min: 0, max: 200)();
  RealColumn get amount => real()();
}

class BudgetLimits extends Table {
  @Index(['categoryId'])
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id, onDelete: KeyAction.setNull)();
  RealColumn get limitAmount => real()();
  TextColumn get period => text().map(const EnumNameConverter<BudgetPeriod>(BudgetPeriod.values))();
}

class RecurringExpenses extends Table {
  @Index(['categoryId'])
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id, onDelete: KeyAction.setNull)();
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
          CategoriesCompanion.insert(name: 'Salary', type: CategoryType.Income.name),
          CategoriesCompanion.insert(name: 'Freelance', type: CategoryType.Income.name),
          CategoriesCompanion.insert(name: 'Investments', type: CategoryType.Income.name),
          CategoriesCompanion.insert(name: 'Rent', type: CategoryType.Income.name),
          CategoriesCompanion.insert(name: 'Other Income', type: CategoryType.Income.name),
          CategoriesCompanion.insert(name: 'Wallet', type: CategoryType.Income.name),

          CategoriesCompanion.insert(name: 'Food', type: CategoryType.Expense.name),
          CategoriesCompanion.insert(name: 'Transport', type: CategoryType.Expense.name),
          CategoriesCompanion.insert(name: 'Utilities', type: CategoryType.Expense.name),
          CategoriesCompanion.insert(name: 'Entertainment', type: CategoryType.Expense.name),
          CategoriesCompanion.insert(name: 'Utilities', type: CategoryType.Expense.name),
          CategoriesCompanion.insert(name: 'Rent', type: CategoryType.Expense.name),
          CategoriesCompanion.insert(name: 'Shopping', type: CategoryType.Expense.name),
          CategoriesCompanion.insert(name: 'Healthcare', type: CategoryType.Expense.name),
          CategoriesCompanion.insert(name: 'Education', type: CategoryType.Expense.name),
          CategoriesCompanion.insert(name: 'Other expenses', type: CategoryType.Expense.name),
          CategoriesCompanion.insert(name: 'Fast Tag', type: CategoryType.Expense.name),
          CategoriesCompanion.insert(name: 'Fuel', type: CategoryType.Expense.name),
          CategoriesCompanion.insert(name: 'Groceries', type: CategoryType.Expense.name),
          CategoriesCompanion.insert(name: 'Home loan', type: CategoryType.Expense.name),
          CategoriesCompanion.insert(name: 'Electricity', type: CategoryType.Expense.name),
          CategoriesCompanion.insert(name: 'Water', type: CategoryType.Expense.name),
        ]);
      });
    }
  }
}
