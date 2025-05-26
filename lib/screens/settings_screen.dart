import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/remote_transaction_repository.dart';

class SettingsScreen extends StatefulWidget {
  final TransactionRepository repository;

  const SettingsScreen({
    Key? key,
    required this.repository,
  }) : super(key: key);

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  String _selectedCurrencyCode = 'INR';
  String _selectedCurrencySymbol = '₹';

  // Remote repository settings
  bool _useRemoteRepository = false;
  String _apiBaseUrl = '';
  String _apiKey = '';
  RemoteDataSourceType _remoteSourceType = RemoteDataSourceType.restApi;

  // Define currencies list
  final List<Map<String, String>> _currencies = [
    {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹'},
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£'},
    {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
    {'code': 'CNY', 'name': 'Chinese Yuan', 'symbol': '¥'},
    {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': 'CA\$'},
    {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': 'A\$'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('currency_code') ?? 'INR';
    final symbol = prefs.getString('currency_symbol') ?? '₹';
    final useRemote = prefs.getBool('use_remote_repository') ?? false;
    final apiBaseUrl = prefs.getString('api_base_url') ?? '';
    final apiKey = prefs.getString('api_key') ?? '';
    final sourceTypeString = prefs.getString('remote_source_type') ?? 'restApi';

    // Convert string to enum
    RemoteDataSourceType sourceType;
    switch (sourceTypeString.toLowerCase()) {
      case 'firebase':
        sourceType = RemoteDataSourceType.firebase;
        break;
      case 'supabase':
        sourceType = RemoteDataSourceType.supabase;
        break;
      default:
        sourceType = RemoteDataSourceType.restApi;
    }

    setState(() {
      _selectedCurrencyCode = code;
      _selectedCurrencySymbol = symbol;
      _useRemoteRepository = useRemote;
      _apiBaseUrl = apiBaseUrl;
      _apiKey = apiKey;
      _remoteSourceType = sourceType;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency_code', _selectedCurrencyCode);
    await prefs.setString('currency_symbol', _selectedCurrencySymbol);

    // Save remote repository settings
    await prefs.setBool('use_remote_repository', _useRemoteRepository);
    await prefs.setString('api_base_url', _apiBaseUrl);
    await prefs.setString('api_key', _apiKey);

    // Convert enum to string
    String sourceTypeString;
    switch (_remoteSourceType) {
      case RemoteDataSourceType.firebase:
        sourceTypeString = 'firebase';
        break;
      case RemoteDataSourceType.supabase:
        sourceTypeString = 'supabase';
        break;
      default:
        sourceTypeString = 'restApi';
    }
    await prefs.setString('remote_source_type', sourceTypeString);

    if (!mounted) return; // Check mounted before using context
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Settings saved. Please restart the app for repository changes to take effect.'),
        duration: Duration(seconds: 3),
      ),
    );

    // Force rebuild of other screens
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text(
              'Currency Settings',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Currency'),
            subtitle: const Text('Select your preferred currency'),
            trailing: DropdownButton<String>(
              value: _selectedCurrencyCode,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedCurrencyCode = newValue;
                    // Find the matching symbol
                    final currency = _currencies.firstWhere(
                      (c) => c['code'] == newValue,
                      orElse: () => {'symbol': '₹'},
                    );
                    _selectedCurrencySymbol = currency['symbol'] ?? '₹';
                  });
                }
              },
              items: _currencies.map<DropdownMenuItem<String>>((currency) {
                return DropdownMenuItem<String>(
                  value: currency['code'],
                  child: Text('${currency['name']} (${currency['symbol']})'),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(height: 20),
          const ListTile(
            title: Text(
              'Repository Settings',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Use Remote Repository'),
            subtitle: const Text('Enable cloud synchronization'),
            value: _useRemoteRepository,
            onChanged: (bool value) {
              setState(() {
                _useRemoteRepository = value;
              });
            },
          ),
          if (_useRemoteRepository) ...[
            ListTile(
              title: const Text('Remote Source Type'),
              trailing: DropdownButton<RemoteDataSourceType>(
                value: _remoteSourceType,
                onChanged: (RemoteDataSourceType? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _remoteSourceType = newValue;
                    });
                  }
                },
                items: RemoteDataSourceType.values
                    .map<DropdownMenuItem<RemoteDataSourceType>>((type) {
                  return DropdownMenuItem<RemoteDataSourceType>(
                    value: type,
                    child: Text(type.toString().split('.').last),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'https://api.example.com',
                ),
                onChanged: (value) {
                  _apiBaseUrl = value;
                },
                controller: TextEditingController(text: _apiBaseUrl),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Enter your API key',
                ),
                obscureText: true,
                onChanged: (value) {
                  _apiKey = value;
                },
                controller: TextEditingController(text: _apiKey),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: _savePreferences,
              child: const Text('Save Settings'),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class to access currency settings throughout the app
class CurrencyService {
  static const String _currencyPrefKey = 'currency_code';
  static const String _currencySymbolPrefKey = 'currency_symbol';

  static Future<String> getCurrencyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currencyPrefKey) ?? 'INR';
  }

  static Future<String> getCurrencySymbol() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currencySymbolPrefKey) ?? '₹';
  }

  // Format amount with the saved currency symbol
  static Future<String> formatAmount(double amount) async {
    final symbol = await getCurrencySymbol();
    return '$symbol${amount.toStringAsFixed(2)}';
  }
}
