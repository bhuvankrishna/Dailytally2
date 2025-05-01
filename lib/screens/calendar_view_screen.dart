import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/app_database.dart';
import '../services/currency_service.dart';

class CalendarViewScreen extends StatefulWidget {
  final AppDatabase db;
  const CalendarViewScreen({Key? key, required this.db}) : super(key: key);

  @override
  _CalendarViewScreenState createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends State<CalendarViewScreen> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  late Map<DateTime, List<Transaction>> _transactionsByDay;
  String _currencySymbol = '₹';
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    _transactionsByDay = {};
    _loadCurrencySymbol();
    _loadTransactions();
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
  
  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get all transactions
      final transactions = await widget.db.select(widget.db.transactions).get();
      
      // Group transactions by day
      final Map<DateTime, List<Transaction>> transactionsByDay = {};
      
      for (final tx in transactions) {
        // Normalize date to remove time component
        final date = DateTime(tx.date.year, tx.date.month, tx.date.day);
        
        if (!transactionsByDay.containsKey(date)) {
          transactionsByDay[date] = [];
        }
        
        transactionsByDay[date]!.add(tx);
      }
      
      setState(() {
        _transactionsByDay = transactionsByDay;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading transactions: $e')),
      );
    }
  }
  
  List<Transaction> _getTransactionsForDay(DateTime day) {
    // Normalize date to remove time component
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _transactionsByDay[normalizedDay] ?? [];
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar View'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCalendar(),
                const Divider(),
                Expanded(
                  child: _buildTransactionList(),
                ),
              ],
            ),
    );
  }
  
  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: CalendarFormat.month,
      eventLoader: _getTransactionsForDay,
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarStyle: const CalendarStyle(
        markersMaxCount: 3,
        markerSize: 8,
        markerDecoration: BoxDecoration(
          color: Colors.deepPurple,
          shape: BoxShape.circle,
        ),
      ),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
    );
  }
  
  Widget _buildTransactionList() {
    final transactions = _getTransactionsForDay(_selectedDay);
    
    if (transactions.isEmpty) {
      return Center(
        child: Text(
          'No transactions on ${DateFormat('MMMM d, yyyy').format(_selectedDay)}',
          style: const TextStyle(fontSize: 16),
        ),
      );
    }
    
    // Get categories for lookup
    return FutureBuilder<List<Category>>(
      future: widget.db.select(widget.db.categories).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final categories = snapshot.data!;
        final categoryMap = {for (var cat in categories) cat.id: cat.name};
        
        return ListView.builder(
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final tx = transactions[index];
            final isIncome = tx.type.toLowerCase() == 'income';
            final categoryName = tx.categoryId != null 
                ? categoryMap[tx.categoryId] ?? 'Unknown' 
                : 'Unknown';
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(
                  tx.description.isEmpty ? 'No description' : tx.description,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Category: $categoryName'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_currencySymbol ${tx.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isIncome ? Colors.green[700] : Colors.red[700],
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      DateFormat('h:mm a').format(tx.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
