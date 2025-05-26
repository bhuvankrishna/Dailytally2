import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/app_database.dart';
import 'transaction_repository.dart';

/// Remote data source type
enum RemoteDataSourceType {
  firebase,
  supabase,
  restApi,
}

/// Remote implementation of TransactionRepository
class RemoteTransactionRepository implements TransactionRepository {
  final RemoteDataSourceType sourceType;
  final String baseUrl;
  final String? apiKey;
  
  // For streaming updates
  final _transactionsStreamController = StreamController<List<Transaction>>.broadcast();
  
  RemoteTransactionRepository({
    required this.sourceType,
    required this.baseUrl,
    this.apiKey,
  });
  
  // Helper to get appropriate headers based on the source type
  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (apiKey != null) {
      switch (sourceType) {
        case RemoteDataSourceType.firebase:
          headers['Authorization'] = 'Bearer $apiKey';
          break;
        case RemoteDataSourceType.supabase:
          headers['apikey'] = apiKey!;
          headers['Authorization'] = 'Bearer $apiKey';
          break;
        case RemoteDataSourceType.restApi:
          headers['X-API-Key'] = apiKey!;
          break;
      }
    }
    
    return headers;
  }
  
  // Helper to get the endpoint based on source type
  String _getEndpoint(String path) {
    switch (sourceType) {
      case RemoteDataSourceType.firebase:
        return '$baseUrl/$path.json';
      case RemoteDataSourceType.supabase:
        return '$baseUrl/$path';
      case RemoteDataSourceType.restApi:
        return '$baseUrl/$path';
    }
  }
  
  // Helper to convert JSON to Transaction
  Transaction _fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      type: json['type'],
      categoryId: json['categoryId'],
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      description: json['description'] ?? '',
    );
  }
  
  // Helper to convert Transaction to JSON
  Map<String, dynamic> _toJson(Transaction transaction) {
    return {
      'id': transaction.id,
      'type': transaction.type,
      'categoryId': transaction.categoryId,
      'amount': transaction.amount,
      'date': transaction.date.toIso8601String(),
      'description': transaction.description,
    };
  }

  @override
  Future<List<Transaction>> getAllTransactions() async {
    try {
      final response = await http.get(
        Uri.parse(_getEndpoint('transactions')),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle different response formats based on source type
        if (sourceType == RemoteDataSourceType.firebase) {
          if (data == null) return [];
          
          final List<Transaction> transactions = [];
          data.forEach((key, value) {
            final transaction = _fromJson({...value, 'id': int.parse(key)});
            transactions.add(transaction);
          });
          return transactions;
        } else {
          final List<dynamic> items = data;
          return items.map((item) => _fromJson(item)).toList();
        }
      } else {
        throw Exception('Failed to load transactions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load transactions: $e');
    }
  }

  @override
  Future<Transaction?> getTransactionById(int id) async {
    try {
      final endpoint = sourceType == RemoteDataSourceType.firebase
          ? _getEndpoint('transactions/$id')
          : '${_getEndpoint('transactions')}/$id';
          
      final response = await http.get(
        Uri.parse(endpoint),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        if (response.body == 'null' || response.body.isEmpty) return null;
        
        final data = json.decode(response.body);
        return _fromJson(sourceType == RemoteDataSourceType.firebase 
            ? {...data, 'id': id}
            : data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load transaction: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load transaction: $e');
    }
  }

  @override
  Future<int> addTransaction(TransactionsCompanion transaction) async {
    try {
      // Convert TransactionsCompanion to a regular map
      final transactionData = {
        'type': transaction.type.value,
        'categoryId': transaction.categoryId.value,
        'amount': transaction.amount.value,
        'date': transaction.date.value.toIso8601String(),
        'description': transaction.description.value,
      };
      
      final response = await http.post(
        Uri.parse(_getEndpoint('transactions')),
        headers: _headers,
        body: json.encode(transactionData),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        
        int newId;
        if (sourceType == RemoteDataSourceType.firebase) {
          // Firebase returns a name field with the key
          newId = int.parse(data['name']);
        } else if (sourceType == RemoteDataSourceType.supabase) {
          // Supabase returns an array with the inserted item
          newId = data[0]['id'];
        } else {
          // Generic REST API might return the ID directly or in an object
          newId = data is Map ? (data['id'] ?? -1) : -1;
        }
        
        // Notify listeners about the new transaction
        _refreshTransactions();
        
        return newId;
      } else {
        throw Exception('Failed to add transaction: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to add transaction: $e');
    }
  }

  @override
  Future<bool> updateTransaction(Transaction transaction) async {
    try {
      final endpoint = sourceType == RemoteDataSourceType.firebase
          ? _getEndpoint('transactions/${transaction.id}')
          : '${_getEndpoint('transactions')}/${transaction.id}';
          
      final response = await http.put(
        Uri.parse(endpoint),
        headers: _headers,
        body: json.encode(_toJson(transaction)),
      );
      
      if (response.statusCode == 200) {
        // Notify listeners about the updated transaction
        _refreshTransactions();
        return true;
      } else {
        throw Exception('Failed to update transaction: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update transaction: $e');
    }
  }

  @override
  Future<bool> deleteTransaction(int id) async {
    try {
      final endpoint = sourceType == RemoteDataSourceType.firebase
          ? _getEndpoint('transactions/$id')
          : '${_getEndpoint('transactions')}/$id';
          
      final response = await http.delete(
        Uri.parse(endpoint),
        headers: _headers,
      );
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        // Notify listeners about the deleted transaction
        _refreshTransactions();
        return true;
      } else {
        throw Exception('Failed to delete transaction: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  @override
  Future<List<Transaction>> getTransactionsByType(String type) async {
    // For simplicity, we'll fetch all and filter client-side
    // In a real implementation, you might want to use server-side filtering
    final allTransactions = await getAllTransactions();
    return allTransactions
        .where((transaction) => transaction.type.toLowerCase() == type.toLowerCase())
        .toList();
  }

  @override
  Future<List<Transaction>> getTransactionsByCategory(String category) async {
    // For simplicity, we'll fetch all and filter client-side
    final allTransactions = await getAllTransactions();
    return allTransactions
        .where((transaction) => transaction.categoryId == category)
        .toList();
  }

  @override
  Future<List<Transaction>> getTransactionsByDateRange(
      DateTime startDate, DateTime endDate) async {
    // For simplicity, we'll fetch all and filter client-side
    final allTransactions = await getAllTransactions();
    return allTransactions
        .where((transaction) => 
            !transaction.date.isBefore(startDate) && 
            !transaction.date.isAfter(endDate))
        .toList();
  }

  @override
  Stream<List<Transaction>> watchAllTransactions() {
    // Initial load
    _refreshTransactions();
    return _transactionsStreamController.stream;
  }
  
  // Helper to refresh the transactions stream
  Future<void> _refreshTransactions() async {
    try {
      final transactions = await getAllTransactions();
      _transactionsStreamController.add(transactions);
    } catch (e) {
      _transactionsStreamController.addError(e);
    }
  }
  
  // Clean up resources
  void dispose() {
    _transactionsStreamController.close();
  }
}
