import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _currencyPrefKey = 'currency_code';
  static const String _currencySymbolPrefKey = 'currency_symbol';
  
  String _selectedCurrencyCode = 'INR';
  String _selectedCurrencySymbol = '₹';
  
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
    setState(() {
      _selectedCurrencyCode = prefs.getString(_currencyPrefKey) ?? 'INR';
      _selectedCurrencySymbol = prefs.getString(_currencySymbolPrefKey) ?? '₹';
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyPrefKey, _selectedCurrencyCode);
    await prefs.setString(_currencySymbolPrefKey, _selectedCurrencySymbol);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved. Please navigate to other screens to see changes.'),
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Currency'),
            subtitle: Text('Select your preferred currency'),
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
