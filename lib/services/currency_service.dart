import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService {
  // Default currency is INR
  static const String _defaultCurrencySymbol = '₹';
  
  // Get currency symbol
  static Future<String> getCurrencySymbol() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('currency_symbol') ?? _defaultCurrencySymbol;
    } catch (e) {
      // Fallback to default if there's an error
      return _defaultCurrencySymbol;
    }
  }
  
  // Format amount with currency symbol
  static String formatAmount(double amount, String symbol) {
    return '$symbol ${amount.toStringAsFixed(2)}';
  }
}
