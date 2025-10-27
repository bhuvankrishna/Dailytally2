import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/app_database.dart';
import 'repositories/repository_factory.dart';
import 'repositories/transaction_repository.dart';
import 'config/env_config.dart';
import 'screens/category_list_screen.dart';
import 'screens/add_category_screen.dart';
import 'screens/transaction_list_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment configuration
  final config = EnvConfig();
  await config.init();

  // Initialize database
  final db = AppDatabase();
  await db.seedDefaultCategories();

  // Initialize repository factory
  final repositoryFactory = RepositoryFactory(db);

  // Get repository configuration from environment variables
  // with fallback to shared preferences for backward compatibility
  // Load SharedPreferences for potential fallback or storing user-specific settings.
  final prefs = await SharedPreferences.getInstance();

  // Determine if remote repository should be used: checks environment config first, then SharedPreferences for backward compatibility or user preference.
  // Determine if we should use remote repository
  // First check env, then shared preferences, default to false
  final useRemote = config.useRemoteRepository ||
      (prefs.getBool('use_remote_repository') ?? false);

  // Get API base URL: checks environment config first, then SharedPreferences.
  // Get API base URL from env or shared preferences
  final apiBaseUrl = config.apiBaseUrl.isNotEmpty
      ? config.apiBaseUrl
      : (prefs.getString('api_base_url') ?? '');

  // Get API key: checks environment config first, then SharedPreferences.
  // Get API key from env or shared preferences
  final apiKey =
      config.apiKey.isNotEmpty ? config.apiKey : (prefs.getString('api_key'));

  // Get remote source type from env or shared preferences
  final sourceType = config.remoteSourceType;

  // Get the appropriate repository based on configuration
  final transactionRepository = repositoryFactory.getRepository(
    useRemote: useRemote,
    sourceType: sourceType,
    baseUrl: apiBaseUrl,
    apiKey: apiKey,
  );

  runApp(MyApp(db: db, transactionRepository: transactionRepository));
}

class MyApp extends StatelessWidget {
  final AppDatabase db;
  final TransactionRepository transactionRepository;

  const MyApp({
    Key? key,
    required this.db,
    required this.transactionRepository,
  }) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Tally',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: '/',
      routes: {
        '/': (ctx) => MainScreen(db: db, repository: transactionRepository),
        '/categories': (ctx) => CategoryListScreen(db: db),
        '/add_category': (ctx) {
          final cat = ModalRoute.of(ctx)!.settings.arguments as Category?;
          return AddCategoryScreen(db: db, category: cat);
        },
        '/transactions': (ctx) =>
            TransactionListScreen(db: db, repository: transactionRepository),
        '/add_transaction': (ctx) {
          final tx = ModalRoute.of(ctx)!.settings.arguments as Transaction?;
          return AddTransactionScreen(
              db: db, transaction: tx, repository: transactionRepository);
        },
        '/settings': (ctx) => SettingsScreen(repository: transactionRepository),
      },
    );
  }
}
