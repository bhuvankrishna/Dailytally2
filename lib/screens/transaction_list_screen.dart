import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_database.dart';
import 'settings_screen.dart';

class TransactionListScreen extends StatefulWidget {
  final AppDatabase db;
  const TransactionListScreen({Key? key, required this.db}) : super(key: key);

  @override
  _TransactionListScreenState createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  String _currencySymbol = '₹';
  
  @override
  void initState() {
    super.initState();
    _loadCurrencySymbol();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload currency when screen becomes visible again
    _loadCurrencySymbol();
  }
  
  Future<void> _loadCurrencySymbol() async {
    final symbol = await CurrencyService.getCurrencySymbol();
    setState(() {
      _currencySymbol = symbol;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/add_transaction')
                  .then((_) => {});
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Transaction>>(
        stream: widget.db.select(widget.db.transactions).watch(),
        builder: (context, snapshot) {
          final txs = snapshot.data ?? [];
          if (txs.isEmpty) {
            return const Center(child: Text('No transactions yet'));
          }
          return ListView.builder(
            itemCount: txs.length,
            itemBuilder: (context, index) {
              final tx = txs[index];
              final dateStr = DateFormat.yMMMd().format(tx.date);
              final amountStr = NumberFormat.currency(symbol: _currencySymbol, decimalDigits: 2).format(tx.amount);
              final isIncome = tx.type == 'Income';
              return ListTile(
                leading: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isIncome ? Colors.green : Colors.red,
                ),
                title: Text(
                  amountStr,
                  style: TextStyle(
                      color: isIncome ? Colors.green : Colors.red),
                ),
                subtitle: Text('${tx.description}\n$dateStr'),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await widget.db.delete(widget.db.transactions).delete(tx);
                    } else if (value == 'edit') {
                      Navigator.pushNamed(context, '/add_transaction', arguments: tx)
                          .then((_) => {});
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
