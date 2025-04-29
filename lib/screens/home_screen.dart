import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_database.dart';

class HomeScreen extends StatelessWidget {
  final AppDatabase db;
  const HomeScreen({Key? key, required this.db}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Tally'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              // TODO: Implement date filter
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<List<Transaction>>(
          stream: db.select(db.transactions).watch(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final transactions = snapshot.data ?? [];
            final totalIncome = transactions
                .where((tx) => tx.type == 'Income')
                .fold(0.0, (sum, tx) => sum + tx.amount);
            
            final totalExpense = transactions
                .where((tx) => tx.type == 'Expense')
                .fold(0.0, (sum, tx) => sum + tx.amount);
            
            final balance = totalIncome - totalExpense;
            
            final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Current Balance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormat.format(balance),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: balance >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        elevation: 4,
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text(
                                'Income',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currencyFormat.format(totalIncome),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        elevation: 4,
                        color: Colors.red[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text(
                                'Expenses',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currencyFormat.format(totalExpense),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: transactions.isEmpty
                      ? const Center(
                          child: Text('No transactions yet'),
                        )
                      : ListView.builder(
                          itemCount: transactions.length > 5 ? 5 : transactions.length,
                          itemBuilder: (context, index) {
                            final tx = transactions[index];
                            final isIncome = tx.type == 'Income';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isIncome ? Colors.green : Colors.red,
                                child: Icon(
                                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(tx.description),
                              subtitle: Text(DateFormat.yMMMd().format(tx.date)),
                              trailing: Text(
                                currencyFormat.format(tx.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isIncome ? Colors.green : Colors.red,
                                ),
                              ),
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/add_transaction',
                                  arguments: tx,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add_transaction');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
