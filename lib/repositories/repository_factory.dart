import '../models/app_database.dart';
import 'transaction_repository.dart';
import 'local_transaction_repository.dart';
import 'remote_transaction_repository.dart';
import 'synced_transaction_repository.dart';

/// Factory class to create repositories
class RepositoryFactory {
  final AppDatabase _db;

  // Singleton pattern
  static RepositoryFactory? _instance;

  // Cached repositories
  LocalTransactionRepository? _localRepository;
  RemoteTransactionRepository? _remoteRepository;
  SyncedTransactionRepository? _syncedRepository;

  RepositoryFactory._internal(this._db);

  factory RepositoryFactory(AppDatabase db) {
    _instance ??= RepositoryFactory._internal(db);
    return _instance!;
  }

  /// Get a local repository that uses Drift
  LocalTransactionRepository getLocalRepository() {
    _localRepository ??= LocalTransactionRepository(_db);
    return _localRepository!;
  }

  /// Get a remote repository
  RemoteTransactionRepository getRemoteRepository({
    required RemoteDataSourceType sourceType,
    required String baseUrl,
    String? apiKey,
  }) {
    _remoteRepository ??= RemoteTransactionRepository(
      sourceType: sourceType,
      baseUrl: baseUrl,
      apiKey: apiKey,
    );
    return _remoteRepository!;
  }

  /// Get a synced repository that manages both local and remote
  SyncedTransactionRepository getSyncedRepository({
    required RemoteDataSourceType sourceType,
    required String baseUrl,
    String? apiKey,
  }) {
    if (_syncedRepository == null) {
      final localRepo = getLocalRepository();
      final remoteRepo = getRemoteRepository(
        sourceType: sourceType,
        baseUrl: baseUrl,
        apiKey: apiKey,
      );

      _syncedRepository = SyncedTransactionRepository(
        localRepository: localRepo,
        remoteRepository: remoteRepo,
      );
    }

    return _syncedRepository!;
  }

  /// Get the appropriate repository based on configuration
  TransactionRepository getRepository({
    bool useRemote = false,
    RemoteDataSourceType sourceType = RemoteDataSourceType.restApi,
    String baseUrl = '',
    String? apiKey,
  }) {
    if (!useRemote) {
      return getLocalRepository();
    } else {
      return getSyncedRepository(
        sourceType: sourceType,
        baseUrl: baseUrl,
        apiKey: apiKey,
      );
    }
  }

  /// Dispose all repositories
  void dispose() {
    _remoteRepository?.dispose();
    _syncedRepository?.dispose();
  }
}
