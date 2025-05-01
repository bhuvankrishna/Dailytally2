import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_database.dart';

class ExportService {
  final AppDatabase db;
  
  ExportService(this.db);
  
  /// Exports all transactions to a CSV file
  /// Returns the file path if successful, or throws an exception if it fails
  Future<String> exportTransactionsToCSV(String currencySymbol) async {
    // Get all transactions
    final transactions = await db.select(db.transactions).get();
    
    // Get categories for lookup
    final categories = await db.select(db.categories).get();
    final categoryMap = {for (var cat in categories) cat.id: cat.name};
    
    // Create CSV data
    List<List<dynamic>> csvData = [];
    
    // Add header row
    csvData.add([
      'ID', 
      'Date', 
      'Type', 
      'Category', 
      'Description', 
      'Amount ($currencySymbol)'
    ]);
    
    // Format date
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    // Add transaction rows
    for (var tx in transactions) {
      String categoryName = 'Unknown';
      if (tx.categoryId != null) {
        categoryName = categoryMap[tx.categoryId] ?? 'Unknown';
      }
      
      csvData.add([
        tx.id,
        dateFormat.format(tx.date),
        tx.type.toString(),
        categoryName,
        tx.description.isEmpty ? '' : tx.description,
        tx.amount.toStringAsFixed(2),
      ]);
    }
    
    // Convert to CSV string
    String csv = const ListToCsvConverter().convert(csvData, fieldDelimiter: ',');
    
    // Convert string to bytes for file_picker
    final bytes = csv.codeUnits;
    
    // Default filename with timestamp
    final defaultFileName = 'dailytally_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    
    try {
      // Try using file_picker to let user choose save location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save CSV Export',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['csv'],
        lockParentWindow: true,
        bytes: Uint8List.fromList(bytes), // Required for mobile platforms
      );
      
      if (result != null) {
        return result; // Return the path chosen by user
      }
    } catch (e) {
      // Fall through to default save method
    }
    
    // Fallback: Save to app documents directory
    final directory = await getApplicationDocumentsDirectory();
    final outputPath = '${directory.path}/$defaultFileName';
    final file = File(outputPath);
    await file.writeAsString(csv);
    
    return outputPath;
  }
  
  /// Shows a loading dialog while an operation is in progress
  static void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        );
      },
    );
  }
  
  /// Shows a success dialog with the file path
  static void showSuccessDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export Successful'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Transactions exported successfully!'),
              const SizedBox(height: 8),
              Text('File saved to: $filePath', style: const TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
  
  /// Shows an error snackbar
  static void showErrorSnackBar(BuildContext context, String errorMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  }
}
