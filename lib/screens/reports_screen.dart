import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_database.dart';
import '../services/report_service.dart';
import '../services/currency_service.dart';
import 'calendar_view_screen.dart';

class ReportsScreen extends StatefulWidget {
  final AppDatabase db;
  const ReportsScreen({Key? key, required this.db}) : super(key: key);

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ReportPeriod _currentPeriod = ReportPeriod.daily;
  late ReportService _reportService;
  String _currencySymbol = '₹';
  ReportData? _currentReport;
  bool _isLoading = true;
  
  // Date selection variables
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedQuarter = DateTime(DateTime.now().year, ((DateTime.now().month - 1) ~/ 3) * 3 + 1, 1);
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _reportService = ReportService(widget.db);
    _tabController.addListener(_handleTabChange);
    _loadCurrencySymbol();
    _loadReportData();
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }
  
  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _currentPeriod = ReportPeriod.daily;
            break;
          case 1:
            _currentPeriod = ReportPeriod.weekly;
            break;
          case 2:
            _currentPeriod = ReportPeriod.monthly;
            break;
          case 3:
            _currentPeriod = ReportPeriod.quarterly;
            break;
        }
        _loadReportData();
      });
    }
  }
  
  Future<void> _loadCurrencySymbol() async {
    try {
      final symbol = await CurrencyService.getCurrencySymbol();
      setState(() {
        _currencySymbol = symbol;
      });
    } catch (e) {
      // Fallback to default if there's an error
      setState(() {
        _currencySymbol = '₹';
      });
    }
  }
  
  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Use the selected date based on the current period
      DateTime customDate;
      switch (_currentPeriod) {
        case ReportPeriod.daily:
          customDate = _selectedDate;
          break;
        case ReportPeriod.weekly:
          customDate = _selectedWeekStart;
          break;
        case ReportPeriod.monthly:
          customDate = _selectedMonth;
          break;
        case ReportPeriod.quarterly:
          customDate = _selectedQuarter;
          break;
      }
      
      final report = await _reportService.getReportData(_currentPeriod, customDate);
      setState(() {
        _currentReport = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading report data: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Calendar View',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CalendarViewScreen(db: widget.db),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
            Tab(text: 'Quarterly'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentReport == null
              ? const Center(child: Text('No data available'))
              : _buildReportContent(),
    );
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _loadReportData();
      });
    }
  }

  Future<void> _selectWeek(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedWeekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      selectableDayPredicate: (DateTime date) {
        // Only allow Mondays to be selected
        return date.weekday == DateTime.monday;
      },
      helpText: 'SELECT WEEK STARTING ON MONDAY',
    );
    if (picked != null && picked != _selectedWeekStart) {
      setState(() {
        _selectedWeekStart = picked;
        _loadReportData();
      });
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      selectableDayPredicate: (DateTime date) {
        // Only allow 1st day of month to be selected
        return date.day == 1;
      },
      helpText: 'SELECT MONTH',
    );
    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked;
        _loadReportData();
      });
    }
  }

  Future<void> _selectQuarter(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedQuarter,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      selectableDayPredicate: (DateTime date) {
        // Only allow first day of quarters (Jan 1, Apr 1, Jul 1, Oct 1)
        return date.day == 1 && (date.month == 1 || date.month == 4 || date.month == 7 || date.month == 10);
      },
      helpText: 'SELECT QUARTER',
    );
    if (picked != null && picked != _selectedQuarter) {
      setState(() {
        _selectedQuarter = picked;
        _loadReportData();
      });
    }
  }
  
  Widget _buildReportContent() {
    final report = _currentReport!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportHeader(report),
          const SizedBox(height: 24),
          _buildSummaryCards(report),
          const SizedBox(height: 24),
          _buildCategoryBreakdown(report),
          const SizedBox(height: 24),
          _buildTransactionList(report),
        ],
      ),
    );
  }
  
  Widget _buildReportHeader(ReportData report) {
    String periodTitle;
    IconData calendarIcon;
    Function() selectDateFunction;
    String dateFormat;
    String dateText;
    
    switch (_currentPeriod) {
      case ReportPeriod.daily:
        periodTitle = 'Daily Report';
        calendarIcon = Icons.calendar_today;
        selectDateFunction = () => _selectDate(context);
        dateFormat = 'MMM d, yyyy';
        dateText = DateFormat(dateFormat).format(_selectedDate);
        break;
      case ReportPeriod.weekly:
        periodTitle = 'Weekly Report';
        calendarIcon = Icons.date_range;
        selectDateFunction = () => _selectWeek(context);
        dateText = 'Week of ${DateFormat('MMM d, yyyy').format(_selectedWeekStart)}';
        break;
      case ReportPeriod.monthly:
        periodTitle = 'Monthly Report';
        calendarIcon = Icons.calendar_month;
        selectDateFunction = () => _selectMonth(context);
        dateText = DateFormat('MMMM yyyy').format(_selectedMonth);
        break;
      case ReportPeriod.quarterly:
        periodTitle = 'Quarterly Report';
        calendarIcon = Icons.calendar_today_outlined;
        selectDateFunction = () => _selectQuarter(context);
        final quarterNumber = (_selectedQuarter.month - 1) ~/ 3 + 1;
        dateText = 'Q$quarterNumber ${_selectedQuarter.year}';
        break;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              periodTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            IconButton(
              icon: Icon(calendarIcon),
              onPressed: selectDateFunction,
              tooltip: 'Select date',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.date_range, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              dateText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          report.periodLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }
  
  Widget _buildSummaryCards(ReportData report) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Income',
            report.totalIncome,
            Colors.green[100]!,
            Colors.green[800]!,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Expenses',
            report.totalExpense,
            Colors.red[100]!,
            Colors.red[800]!,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Balance',
            report.balance,
            Colors.blue[100]!,
            Colors.blue[800]!,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSummaryCard(String title, double amount, Color bgColor, Color textColor) {
    return Card(
      color: bgColor,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_currencySymbol ${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCategoryBreakdown(ReportData report) {
    if (report.categoryTotals.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Sort categories by amount (descending)
    final sortedCategories = report.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category Breakdown',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...sortedCategories.map((entry) => _buildCategoryItem(entry.key, entry.value)),
      ],
    );
  }
  
  Widget _buildCategoryItem(String category, double amount) {
    // Calculate percentage of total expenses
    final percentage = _currentReport!.totalExpense > 0
        ? (amount / _currentReport!.totalExpense) * 100
        : 0.0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '$_currencySymbol ${amount.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              HSLColor.fromAHSL(1.0, (percentage * 1.2) % 360, 0.7, 0.5).toColor(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTransactionList(ReportData report) {
    if (report.transactions.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transactions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...report.transactions.map((tx) {
          final isIncome = tx.type.toLowerCase() == 'income';
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tx.description ?? 'No description'),
            subtitle: Text(dateFormat.format(tx.date)),
            trailing: Text(
              '$_currencySymbol ${tx.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isIncome ? Colors.green[700] : Colors.red[700],
              ),
            ),
          );
        }),
      ],
    );
  }
}
