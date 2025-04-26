import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get type => text().withLength(min: 1, max: 10)();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().customConstraint('REFERENCES categories(id)')();
  TextColumn get type => text().withLength(min: 1, max: 10)();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text().withLength(min: 0, max: 200)();
  RealColumn get amount => real()();
}

class BudgetLimits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().customConstraint('REFERENCES categories(id)')();
  RealColumn get limitAmount => real()();
  TextColumn get period => text().withLength(min: 1, max: 20)();
}

class RecurringExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().customConstraint('REFERENCES categories(id)')();
  RealColumn get amount => real()();
  TextColumn get frequency => text().withLength(min: 1, max: 20)();
  DateTimeColumn get nextDueDate => dateTime().named('next_due_date')();
}

@DriftDatabase(tables: [Categories, Transactions, BudgetLimits, RecurringExpenses])
class AppDatabase extends _$AppDatabase {
  AppDatabase()
      : super(
          FlutterQueryExecutor.inDatabaseFolder(
            path: 'dailytally.sqlite',
            logStatements: true,
          ),
        );

  @override
  int get schemaVersion => 1;
}
