import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../repositories/remote_transaction_repository.dart';

/// Configuration class that loads and provides access to environment variables
class EnvConfig {
  /// Singleton instance
  static final EnvConfig _instance = EnvConfig._internal();

  /// Factory constructor to return the singleton instance
  factory EnvConfig() => _instance;

  /// Private constructor
  EnvConfig._internal();

  /// Initialize the environment configuration
  Future<void> init() async {
    await dotenv.load();
  }

  /// Get a string value from the environment
  String getString(String key, {String defaultValue = ''}) {
    return dotenv.env[key] ?? defaultValue;
  }

  /// Get a boolean value from the environment
  bool getBool(String key, {bool defaultValue = false}) {
    final value = dotenv.env[key]?.toLowerCase();
    if (value == null) return defaultValue;
    return value == 'true' || value == '1' || value == 'yes';
  }

  /// Get an integer value from the environment
  int getInt(String key, {int defaultValue = 0}) {
    final value = dotenv.env[key];
    if (value == null) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  /// Get the remote data source type from the environment
  RemoteDataSourceType getRemoteSourceType() {
    final sourceTypeString =
        getString('REMOTE_SOURCE_TYPE', defaultValue: 'restApi');

    switch (sourceTypeString.toLowerCase()) {
      case 'firebase':
        return RemoteDataSourceType.firebase;
      case 'supabase':
        return RemoteDataSourceType.supabase;
      case 'restapi':
      default:
        return RemoteDataSourceType.restApi;
    }
  }

  /// Get whether to use the remote repository
  bool get useRemoteRepository => getBool('USE_REMOTE_REPOSITORY');

  /// Get the API base URL
  String get apiBaseUrl => getString('API_BASE_URL');

  /// Get the API key
  String get apiKey => getString('API_KEY');

  /// Get the remote source type
  RemoteDataSourceType get remoteSourceType => getRemoteSourceType();

  /// Get the auto sync interval in minutes
  int get autoSyncIntervalMinutes =>
      getInt('AUTO_SYNC_INTERVAL_MINUTES', defaultValue: 15);

  /// Get whether to sync on app start
  bool get syncOnAppStart => getBool('SYNC_ON_APP_START', defaultValue: true);

  /// Get Firebase project ID
  String get firebaseProjectId => getString('FIREBASE_PROJECT_ID');

  /// Get Firebase API key
  String get firebaseApiKey => getString('FIREBASE_API_KEY');

  /// Get Supabase URL
  String get supabaseUrl => getString('SUPABASE_URL');

  /// Get Supabase anonymous key
  String get supabaseAnonKey => getString('SUPABASE_ANON_KEY');

  /// Get REST API username
  String get restApiUsername => getString('REST_API_USERNAME');

  /// Get REST API password
  String get restApiPassword => getString('REST_API_PASSWORD');
}
