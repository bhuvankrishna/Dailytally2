import 'package:intl/intl.dart';
import '../models/app_database.dart';
import '../repositories/transaction_repository.dart';

enum ReportPeriod {
  daily,
  weekly,
  monthly,
  quarterly
}

class ReportData {
  final DateTime startDate;
  final DateTime endDate;
  final double totalIncome;
  final double totalExpense;
  final Map<String, double> categoryTotals;
  final List<Transaction> transactions;

  ReportData({
    required this.startDate,
    required this.endDate,
    required this.totalIncome,
    required this.totalExpense,
    required this.categoryTotals,
    required this.transactions,
  });

  double get balance => totalIncome - totalExpense;
  
  String get periodLabel {
    final dateFormat = DateFormat('MMM d, yyyy');
    return '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}';
  }
}

class ReportService {
  final AppDatabase db;
  final TransactionRepository repository;
  
  ReportService(this.db, this.repository);
  
  // Get report data for a specific period
  Future<ReportData> getReportData(ReportPeriod period, [DateTime? customDate]) async {
    final now = customDate ?? DateTime.now();
    DateTime startDate;
    DateTime endDate;
    
    // Calculate start and end dates based on period
    switch (period) {
      case ReportPeriod.daily:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case ReportPeriod.weekly:
        // Find the start of the week (Monday)
        final weekday = now.weekday;
        startDate = DateTime(now.year, now.month, now.day - weekday + 1);
        endDate = DateTime(startDate.year, startDate.month, startDate.day + 6, 23, 59, 59);
        break;
      case ReportPeriod.monthly:
        startDate = DateTime(now.year, now.month, 1);
        // Last day of the month
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        endDate = DateTime(now.year, now.month, lastDay, 23, 59, 59);
        break;
      case ReportPeriod.quarterly:
        final quarter = ((now.month - 1) ~/ 3);
        final startMonth = quarter * 3 + 1;
        startDate = DateTime(now.year, startMonth, 1);
        final endMonth = startMonth + 2;
        final lastDay = DateTime(now.year, endMonth + 1, 0).day;
        endDate = DateTime(now.year, endMonth, lastDay, 23, 59, 59);
        break;
    }
    
    // Get all transactions for the period using repository
    final allTransactions = await repository.getAllTransactions();
    
    // Filter transactions by date manually
    final transactions = allTransactions.where((tx) => 
      !tx.date.isBefore(startDate) && !tx.date.isAfter(endDate)).toList();
    
    // Calculate totals
    double totalIncome = 0;
    double totalExpense = 0;
    Map<String, double> categoryTotals = {};
    
    // Get all categories for lookup
    final categories = await db.select(db.categories).get();
    final categoryMap = {for (var cat in categories) cat.id: cat};
    
    for (final tx in transactions) {
      if (tx.type.toLowerCase() == 'income') {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }
      
      // Add to category totals
      if (tx.categoryId != null) {
        final category = categoryMap[tx.categoryId];
        if (category != null) {
          final categoryName = category.name;
          categoryTotals[categoryName] = (categoryTotals[categoryName] ?? 0) + tx.amount;
        }
      }
    }
    
    return ReportData(
      startDate: startDate,
      endDate: endDate,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      categoryTotals: categoryTotals,
      transactions: transactions,
    );
  }
  
  // Get a list of reports for the past periods (e.g., last 7 days, last 12 months)
  Future<List<ReportData>> getHistoricalReports(ReportPeriod period, int count) async {
    final List<ReportData> reports = [];
    final now = DateTime.now();
    
    for (int i = 0; i < count; i++) {
      DateTime customDate;
      
      switch (period) {
        case ReportPeriod.daily:
          customDate = DateTime(now.year, now.month, now.day - i);
          break;
        case ReportPeriod.weekly:
          customDate = DateTime(now.year, now.month, now.day - (i * 7));
          break;
        case ReportPeriod.monthly:
          customDate = DateTime(now.year, now.month - i, 1);
          break;
        case ReportPeriod.quarterly:
          customDate = DateTime(now.year, now.month - (i * 3), 1);
          break;
      }
      
      final report = await getReportData(period, customDate);
      reports.add(report);
    }
    
    return reports;
  }
}
