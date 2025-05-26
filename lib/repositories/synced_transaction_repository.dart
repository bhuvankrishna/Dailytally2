import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import '../models/app_database.dart';
import 'transaction_repository.dart';
import 'local_transaction_repository.dart';
import 'remote_transaction_repository.dart';

/// Sync status for tracking local changes
enum SyncStatus {
  synced,
  pendingUpload,
  pendingDelete,
  error,
}

/// Wrapper repository that manages synchronization between local and remote data sources
class SyncedTransactionRepository implements TransactionRepository {
  final LocalTransactionRepository _localRepository;
  final RemoteTransactionRepository _remoteRepository;
  final _syncController = StreamController<bool>.broadcast();
  
  // For tracking sync status
  bool _isSyncing = false;
  DateTime _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(0);
  
  // For tracking connectivity
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isOnline = false;
  
  // For tracking pending changes
  final List<Map<String, dynamic>> _pendingChanges = [];
  
  SyncedTransactionRepository({
    required LocalTransactionRepository localRepository,
    required RemoteTransactionRepository remoteRepository,
  }) : 
    _localRepository = localRepository,
    _remoteRepository = remoteRepository {
    // Initialize connectivity monitoring
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }
  
  // Initialize connectivity status
  Future<void> _initConnectivity() async {
    late ConnectivityResult result;
    try {
      result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      _isOnline = false;
    }
  }
  
  // Update connection status and trigger sync if needed
  void _updateConnectionStatus(ConnectivityResult result) {
    final wasOffline = !_isOnline;
    _isOnline = result != ConnectivityResult.none;
    
    // If we just came back online, trigger a sync
    if (wasOffline && _isOnline) {
      syncWithRemote();
    }
  }
  
  // Stream that emits when sync status changes
  Stream<bool> get syncStatus => _syncController.stream;
  
  // Get the last sync time
  DateTime get lastSyncTime => _lastSyncTime;
  
  // Check if currently syncing
  bool get isSyncing => _isSyncing;
  
  // Manually trigger synchronization with remote
  Future<void> syncWithRemote() async {
    if (_isSyncing || !_isOnline) return;
    
    _isSyncing = true;
    _syncController.add(true);
    
    try {
      // Process any pending changes first
      await _processPendingChanges();
      
      // Pull remote changes
      final remoteTransactions = await _remoteRepository.getAllTransactions();
      final localTransactions = await _localRepository.getAllTransactions();
      
      // Create maps for easier lookup
      final localMap = {for (var tx in localTransactions) tx.id: tx};
      final remoteMap = {for (var tx in remoteTransactions) tx.id: tx};
      
      // Find transactions to add/update locally
      for (final remoteTx in remoteTransactions) {
        final localTx = localMap[remoteTx.id];
        
        if (localTx == null) {
          // Transaction exists remotely but not locally - add it
          await _localRepository.addTransaction(
            TransactionsCompanion.insert(
              id: Value(remoteTx.id),
              type: remoteTx.type,
              categoryId: Value(remoteTx.categoryId),
              amount: remoteTx.amount,
              date: remoteTx.date,
              description: remoteTx.description,
            ),
          );
        } else if (_isRemoteNewer(remoteTx, localTx)) {
          // Remote transaction is newer - update local
          await _localRepository.updateTransaction(remoteTx);
        }
      }
      
      // Find transactions to add remotely
      for (final localTx in localTransactions) {
        if (!remoteMap.containsKey(localTx.id)) {
          // Transaction exists locally but not remotely - add it
          try {
            await _remoteRepository.addTransaction(
              TransactionsCompanion.insert(
                id: Value(localTx.id),
                type: localTx.type,
                categoryId: Value(localTx.categoryId),
                amount: localTx.amount,
                date: localTx.date,
                description: localTx.description,
              ),
            );
          } catch (e) {
            // If remote add fails, mark for later sync
            _addPendingChange('add', localTx);
          }
        }
      }
      
      _lastSyncTime = DateTime.now();
    } catch (e) {
      // Log error but don't rethrow to prevent UI crashes
      print('Sync error: $e');
    } finally {
      _isSyncing = false;
      _syncController.add(false);
    }
  }
  
  // Process any pending changes that couldn't be synced previously
  Future<void> _processPendingChanges() async {
    if (_pendingChanges.isEmpty || !_isOnline) return;
    
    final changes = List.from(_pendingChanges);
    for (final change in changes) {
      try {
        if (change['action'] == 'add') {
          final tx = change['transaction'] as Transaction;
          await _remoteRepository.addTransaction(
            TransactionsCompanion.insert(
              id: Value(tx.id),
              type: tx.type,
              categoryId: Value(tx.categoryId),
              amount: tx.amount,
              date: tx.date,
              description: tx.description,
            ),
          );
        } else if (change['action'] == 'update') {
          final tx = change['transaction'] as Transaction;
          await _remoteRepository.updateTransaction(tx);
        } else if (change['action'] == 'delete') {
          final id = change['id'] as int;
          await _remoteRepository.deleteTransaction(id);
        }
        
        // Remove from pending changes if successful
        _pendingChanges.remove(change);
      } catch (e) {
        // Keep in pending changes if failed
        print('Failed to process pending change: $e');
      }
    }
  }
  
  // Add a pending change to be processed later
  void _addPendingChange(String action, [Transaction? transaction, int? id]) {
    final change = {
      'action': action,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    if (transaction != null) {
      change['transaction'] = transaction;
    }
    
    if (id != null) {
      change['id'] = id;
    }
    
    _pendingChanges.add(change);
  }
  
  // Check if remote transaction is newer than local
  // In a real app, you might want to add a 'lastModified' field to transactions
  bool _isRemoteNewer(Transaction remoteTx, Transaction localTx) {
    // This is a simplified comparison
    // In a real app, you'd compare timestamps or version numbers
    return remoteTx != localTx;
  }

  @override
  Future<List<Transaction>> getAllTransactions() async {
    // Always fetch from local for performance
    return await _localRepository.getAllTransactions();
  }

  @override
  Future<Transaction?> getTransactionById(int id) async {
    return await _localRepository.getTransactionById(id);
  }

  @override
  Future<int> addTransaction(TransactionsCompanion transaction) async {
    // Add to local first
    final id = await _localRepository.addTransaction(transaction);
    
    // Then try to sync with remote
    if (_isOnline) {
      try {
        await _remoteRepository.addTransaction(transaction);
      } catch (e) {
        // If remote add fails, mark for later sync
        final localTx = await _localRepository.getTransactionById(id);
        if (localTx != null) {
          _addPendingChange('add', localTx);
        }
      }
    } else {
      // If offline, get the transaction and mark for later sync
      final localTx = await _localRepository.getTransactionById(id);
      if (localTx != null) {
        _addPendingChange('add', localTx);
      }
    }
    
    return id;
  }

  @override
  Future<bool> updateTransaction(Transaction transaction) async {
    // Update local first
    final success = await _localRepository.updateTransaction(transaction);
    
    // Then try to sync with remote
    if (success && _isOnline) {
      try {
        await _remoteRepository.updateTransaction(transaction);
      } catch (e) {
        // If remote update fails, mark for later sync
        _addPendingChange('update', transaction);
      }
    } else if (success) {
      // If offline, mark for later sync
      _addPendingChange('update', transaction);
    }
    
    return success;
  }

  @override
  Future<bool> deleteTransaction(int id) async {
    // Delete from local first
    final success = await _localRepository.deleteTransaction(id);
    
    // Then try to sync with remote
    if (success && _isOnline) {
      try {
        await _remoteRepository.deleteTransaction(id);
      } catch (e) {
        // If remote delete fails, mark for later sync
        _addPendingChange('delete', null, id);
      }
    } else if (success) {
      // If offline, mark for later sync
      _addPendingChange('delete', null, id);
    }
    
    return success;
  }

  @override
  Future<List<Transaction>> getTransactionsByType(String type) async {
    return await _localRepository.getTransactionsByType(type);
  }

  @override
  Future<List<Transaction>> getTransactionsByCategory(String category) async {
    return await _localRepository.getTransactionsByCategory(category);
  }

  @override
  Future<List<Transaction>> getTransactionsByDateRange(
      DateTime startDate, DateTime endDate) async {
    return await _localRepository.getTransactionsByDateRange(startDate, endDate);
  }

  @override
  Stream<List<Transaction>> watchAllTransactions() {
    return _localRepository.watchAllTransactions();
  }
  
  // Clean up resources
  void dispose() {
    _connectivitySubscription.cancel();
    _syncController.close();
  }
}
