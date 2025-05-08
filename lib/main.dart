import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/app_database.dart';
import 'repositories/repository_factory.dart';
import 'repositories/transaction_repository.dart';
import 'repositories/remote_transaction_repository.dart';
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
  final prefs = await SharedPreferences.getInstance();
  
  // Determine if we should use remote repository
  // First check env, then shared preferences, default to false
  final useRemote = config.useRemoteRepository || 
      (prefs.getBool('use_remote_repository') ?? false);
  
  // Get API base URL from env or shared preferences
  final apiBaseUrl = config.apiBaseUrl.isNotEmpty ? 
      config.apiBaseUrl : (prefs.getString('api_base_url') ?? '');
  
  // Get API key from env or shared preferences
  final apiKey = config.apiKey.isNotEmpty ? 
      config.apiKey : (prefs.getString('api_key'));
  
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
        '/transactions': (ctx) => TransactionListScreen(db: db, repository: transactionRepository),
        '/add_transaction': (ctx) {
          final tx = ModalRoute.of(ctx)!.settings.arguments as Transaction?;
          return AddTransactionScreen(db: db, transaction: tx, repository: transactionRepository);
        },
        '/settings': (ctx) => SettingsScreen(repository: transactionRepository),
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
