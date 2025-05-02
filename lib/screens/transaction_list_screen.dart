import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_database.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../services/currency_service.dart';
import 'calendar_view_screen.dart';

class TransactionListScreen extends StatefulWidget {
  final AppDatabase db;
  const TransactionListScreen({Key? key, required this.db}) : super(key: key);

  @override
  _TransactionListScreenState createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  String _currencySymbol = '₹';
  
  // Pagination variables
  final int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMoreTransactions = true;
  List<Transaction> _displayedTransactions = [];
  List<Transaction> _allTransactions = [];
  List<Transaction> _filteredTransactions = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  
  // Search variables
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Category> _categories = [];
  
  @override
  void initState() {
    super.initState();
    _loadCurrencySymbol();
    _loadCategories();
    _scrollController.addListener(_scrollListener);
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
  
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMoreTransactions) {
      _loadMoreTransactions();
    }
  }
  
  void _loadMoreTransactions() {
    if (_isLoading || !_hasMoreTransactions) return;
    
    setState(() {
      _isLoading = true;
    });
    
    // Calculate the next page of transactions
    final nextPageStart = (_currentPage + 1) * _pageSize;
    final nextPageEnd = nextPageStart + _pageSize;
    
    if (nextPageStart >= _filteredTransactions.length) {
      setState(() {
        _hasMoreTransactions = false;
        _isLoading = false;
      });
      return;
    }
    
    final nextPageItems = _filteredTransactions.sublist(
      nextPageStart,
      nextPageEnd > _filteredTransactions.length ? _filteredTransactions.length : nextPageEnd
    );
    
    setState(() {
      _displayedTransactions.addAll(nextPageItems);
      _currentPage++;
      _hasMoreTransactions = nextPageEnd < _filteredTransactions.length;
      _isLoading = false;
    });
  }
  
  void _resetPagination() {
    _currentPage = 0;
    _hasMoreTransactions = true;
    _displayedTransactions = [];
  }
  
  Future<void> _loadCategories() async {
    try {
      final cats = await widget.db.select(widget.db.categories).get();
      setState(() {
        _categories = cats;
      });
    } catch (e) {
      // Handle error
      print('Error loading categories: $e');
    }
  }
  
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _applySearch();
    });
  }
  
  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredTransactions = List.from(_allTransactions);
    } else {
      _filteredTransactions = _allTransactions.where((tx) {
        // Search by description
        final descriptionMatch = tx.description.toLowerCase().contains(_searchQuery);
        
        // Search by amount (convert amount to string and check if it contains the query)
        final amountStr = tx.amount.toString();
        final amountMatch = amountStr.contains(_searchQuery);
        
        // Search by category name
        bool categoryMatch = false;
        if (tx.categoryId != null) {
          final category = _categories.firstWhere(
            (cat) => cat.id == tx.categoryId,
            orElse: () => Category(id: -1, name: '', type: ''),
          );
          categoryMatch = category.name.toLowerCase().contains(_searchQuery);
        }
        
        return descriptionMatch || amountMatch || categoryMatch;
      }).toList();
    }
    
    // Reset pagination with filtered results
    _resetPagination();
    final firstPageEnd = _pageSize > _filteredTransactions.length ? _filteredTransactions.length : _pageSize;
    _displayedTransactions = _filteredTransactions.sublist(0, firstPageEnd);
    _hasMoreTransactions = firstPageEnd < _filteredTransactions.length;
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload currency when screen becomes visible again
    _loadCurrencySymbol();
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
  
  Future<void> _exportTransactionsToCSV() async {
    try {
      // Create export service
      final exportService = ExportService(widget.db);
      
      // Show loading indicator
      ExportService.showLoadingDialog(context, 'Exporting transactions...');
      
      // Export transactions to CSV
      final filePath = await exportService.exportTransactionsToCSV(_currencySymbol);
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show success message with file path
      ExportService.showSuccessDialog(context, filePath);
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      ExportService.showErrorSnackBar(context, 'Error exporting data: $e');
    }
  }
  
  Future<void> _importTransactionsFromCSV() async {
    try {
      // Create import service
      final importService = ImportService(widget.db);
      
      // Show loading indicator
      ImportService.showLoadingDialog(context, 'Importing transactions...');
      
      // Import transactions from CSV
      final result = await importService.importTransactionsFromCSV();
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show result dialog
      ImportService.showResultDialog(context, result);
      
      // Reset pagination to show new transactions
      setState(() {
        _resetPagination();
        _loadMoreTransactions();
      });
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      ImportService.showErrorSnackBar(context, 'Error importing data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
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
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export to CSV',
            onPressed: () => _exportTransactionsToCSV(),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import from CSV',
            onPressed: () => _importTransactionsFromCSV(),
          ),
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
          if (snapshot.connectionState == ConnectionState.waiting && _allTransactions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final txs = snapshot.data ?? [];
          if (txs.isEmpty) {
            return const Center(child: Text('No transactions yet'));
          }
          
          // Sort transactions by date (newest first)
          txs.sort((a, b) => b.date.compareTo(a.date));
          
          // Update all transactions and reset pagination if data changed
          if (_allTransactions.isEmpty || _allTransactions.length != txs.length) {
            _allTransactions = txs;
            _filteredTransactions = txs;
            
            // Apply search if there's an active search query
            if (_searchQuery.isNotEmpty) {
              _applySearch();
            } else {
              _resetPagination();
              
              // Load first page
              final firstPageEnd = _pageSize > _filteredTransactions.length ? _filteredTransactions.length : _pageSize;
              _displayedTransactions = _filteredTransactions.sublist(0, firstPageEnd);
              _currentPage = 0;
              _hasMoreTransactions = firstPageEnd < _filteredTransactions.length;
            }
          }
          
          return RefreshIndicator(
            onRefresh: () async {
              _resetPagination();
              final firstPageEnd = _pageSize > _filteredTransactions.length ? _filteredTransactions.length : _pageSize;
              setState(() {
                _displayedTransactions = _filteredTransactions.sublist(0, firstPageEnd);
                _currentPage = 0;
                _hasMoreTransactions = firstPageEnd < _filteredTransactions.length;
              });
            },
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by description, category, or amount',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                  ),
                ),
                // Display message when search has no results
                if (_searchQuery.isNotEmpty && _filteredTransactions.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No transactions match your search'),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _displayedTransactions.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _displayedTransactions.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      
                      final tx = _displayedTransactions[index];
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
                  ),
                ),
                if (_isLoading && _displayedTransactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          );
        },
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
