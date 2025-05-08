import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart' hide Column;
import 'package:flutter/material.dart' as material show Column;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../models/app_database.dart';
import 'package:drift/drift.dart' show Value;

class ImportService {
  final AppDatabase db;
  
  ImportService(this.db);
  
  /// Imports transactions from a CSV file
  /// Returns a summary of the import operation
  /// Will validate that all categories exist before importing
  Future<ImportResult> importTransactionsFromCSV() async {
    // Let user pick a CSV file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: false,
    );
    
    if (result == null || result.files.isEmpty) {
      throw Exception('No file selected');
    }
    
    final file = File(result.files.first.path!);
    final csvString = await file.readAsString();
    
    // Parse CSV data
    final csvTable = const CsvToListConverter(eol: '\n', fieldDelimiter: ',').convert(csvString);
    
    if (csvTable.isEmpty) {
      throw Exception('CSV file is empty');
    }
    
    // Get existing transactions for duplicate checking
    final existingTransactions = await db.select(db.transactions).get();
    final existingIds = existingTransactions.map((tx) => tx.id).toSet();
    
    // Get categories for lookup
    final categories = await db.select(db.categories).get();
    final categoryNameToId = <String, int>{};
    for (var cat in categories) {
      categoryNameToId[cat.name.toLowerCase()] = cat.id;
    }
    
    // Set to track unknown categories
    final unknownCategories = <String>{};
    
    // Prepare result tracking
    final importResult = ImportResult();
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    // Process header row
    // Print headers for debugging
    print('CSV Headers (raw): ${csvTable[0]}');
    
    // Clean and normalize headers
    final headers = csvTable[0].map((e) {
      String header = e.toString();
      // Remove tabs, trim whitespace, and convert to lowercase
      return header.replaceAll('\t', '').trim().toLowerCase();
    }).toList();
    
    print('Processed headers: $headers');
    final idIndex = headers.indexOf('id');
    final dateIndex = headers.indexOf('date');
    final typeIndex = headers.indexOf('type');
    final categoryIndex = headers.indexOf('category');
    final descriptionIndex = headers.indexOf('description');
    final amountIndex = _findAmountIndex(headers);
    
    // Validate required columns
    if (dateIndex == -1 || typeIndex == -1 || amountIndex == -1) {
      throw Exception('CSV file must contain date, type, and amount columns.\n' +
          'Headers found: $headers\n' +
          'Looking for: date (index $dateIndex), type (index $typeIndex), amount (index $amountIndex)');
    }
    
    // First pass: Check all categories in the CSV file
    for (int i = 1; i < csvTable.length; i++) {
      final row = csvTable[i];
      
      // Skip empty rows
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }
      
      // Check if the category exists
      if (categoryIndex != -1 && row.length > categoryIndex) {
        final categoryStr = row[categoryIndex].toString().trim();
        if (categoryStr.isNotEmpty) {
          final categoryId = categoryNameToId[categoryStr.toLowerCase()];
          if (categoryId == null) {
            unknownCategories.add(categoryStr);
          }
        }
      }
    }
    
    // If unknown categories found, stop import and return them
    if (unknownCategories.isNotEmpty) {
      importResult.unknownCategories = unknownCategories.toList()..sort();
      return importResult;
    }
    
    // Process data rows for actual import
    for (int i = 1; i < csvTable.length; i++) {
      final row = csvTable[i];
      
      // Skip empty rows
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }
      
      try {
        // Extract values
        final id = idIndex != -1 ? _parseId(row[idIndex].toString()) : null;
        final dateStr = row[dateIndex].toString();
        final typeStr = row[typeIndex].toString();
        final categoryStr = categoryIndex != -1 ? row[categoryIndex].toString() : '';
        final description = descriptionIndex != -1 ? row[descriptionIndex].toString() : '';
        final amountStr = row[amountIndex].toString().replaceAll(RegExp(r'[^\d.-]'), '');
        
        // Parse values
        DateTime date;
        try {
          // Try different date formats
          date = _parseDate(dateStr);
        } catch (e) {
          throw Exception('Invalid date format: $dateStr. Use YYYY-MM-DD format.');
        }
        
        final type = _normalizeType(typeStr);
        
        double amount;
        try {
          amount = double.parse(amountStr);
        } catch (e) {
          throw Exception('Invalid amount format: $amountStr');
        }
        
        // Find category ID
        int? categoryId;
        if (categoryStr.isNotEmpty) {
          categoryId = categoryNameToId[categoryStr.toLowerCase()];
          
          // If category doesn't exist, create it
          if (categoryId == null) {
            final newCategory = await db.into(db.categories).insertReturning(
              CategoriesCompanion.insert(
                name: categoryStr,
                type: type,
              ),
            );
            categoryId = newCategory.id;
            categoryNameToId[categoryStr.toLowerCase()] = categoryId;
            importResult.categoriesCreated++;
          }
        }
        
        // Check for duplicate ID
        if (id != null && existingIds.contains(id)) {
          importResult.duplicates.add(i);
          continue;
        }
        
        // Create transaction
        await db.into(db.transactions).insert(
          TransactionsCompanion(
            id: id != null ? Value(id) : const Value.absent(),
            categoryId: categoryId != null ? Value(categoryId) : const Value.absent(),
            type: Value(type),
            date: Value(date),
            description: Value(description),
            amount: Value(amount),
          ),
        );
        
        importResult.imported++;
      } catch (e) {
        importResult.errors.add(ImportError(i, e.toString()));
      }
    }
    
    return importResult;
  }
  
  /// Find the index of the amount column, which might have different names
  int _findAmountIndex(List<String> headers) {
    // Print each header for debugging
    for (int i = 0; i < headers.length; i++) {
      print('Header $i: "${headers[i]}"');
    }
    
    // First try exact match
    final exactIndex = headers.indexOf('amount');
    if (exactIndex != -1) {
      print('Found amount column at index $exactIndex (exact match)');
      return exactIndex;
    }
    
    // Then try various possible formats
    final possibleNames = ['amount', 'amount(', 'amount (', 'value', 'sum'];
    
    for (final name in possibleNames) {
      final index = headers.indexWhere((h) => h.contains(name));
      if (index != -1) {
        print('Found amount column at index $index (contains "$name")');
        return index;
      }
    }
    
    // If still not found, try the last column as a fallback
    if (headers.isNotEmpty) {
      print('Using last column (${headers.length - 1}) as amount column fallback');
      return headers.length - 1;
    }
    
    return -1;
  }
  
  /// Parse ID value, handling various formats
  int? _parseId(String value) {
    if (value.isEmpty) return null;
    try {
      return int.parse(value);
    } catch (_) {
      return null;
    }
  }
  
  /// Normalize transaction type to match app's format
  String _normalizeType(String type) {
    final lowercaseType = type.toLowerCase().trim();
    if (lowercaseType.contains('income') || 
        lowercaseType.contains('revenue') || 
        lowercaseType == 'in' || 
        lowercaseType == 'i') {
      return 'income';
    } else {
      return 'expense';
    }
  }
  
  /// Parse date from various formats
  DateTime _parseDate(String dateStr) {
    // Try different date formats
    final formats = [
      'yyyy-MM-dd',  // 2025-05-03
      'dd/MM/yyyy',  // 03/05/2025
      'MM/dd/yyyy',  // 05/03/2025
      'dd-MM-yyyy',  // 03-05-2025
      'yyyy/MM/dd',  // 2025/05/03
      'dd.MM.yyyy',  // 03.05.2025
    ];
    
    for (final format in formats) {
      try {
        return DateFormat(format).parse(dateStr.trim());
      } catch (_) {
        // Try next format
      }
    }
    
    // If all formats fail, throw an exception
    throw Exception('Unsupported date format: $dateStr');
  }
  
  /// Shows a loading dialog while an operation is in progress
  static void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: material.Column(
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
  
  /// Shows a result dialog with import summary
  static void showResultDialog(BuildContext context, ImportResult result) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(result.unknownCategories.isEmpty ? 'Import Results' : 'Import Failed'),
          content: material.Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.unknownCategories.isNotEmpty) ...[  
                const Text(
                  'Import failed because the following categories in your CSV file do not exist in the app:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 100,
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: result.unknownCategories.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(result.unknownCategories[index],
                            style: const TextStyle(fontSize: 12)),
                      );
                    },
                  ),
                ),
              
                const SizedBox(height: 8),
                const Text(
                  'Please add these categories to your app before importing, or update your CSV file to use existing categories.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ] else ... [  
                Text('Transactions imported: ${result.imported}'),
                if (result.categoriesCreated > 0)
                  Text('New categories created: ${result.categoriesCreated}'),
                if (result.duplicates.isNotEmpty)
                  Text('Duplicate IDs skipped: ${result.duplicates.length}'),
                if (result.errors.isNotEmpty)
                  Text('Errors encountered: ${result.errors.length}'),
                if (result.duplicates.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Duplicate IDs were found in these rows:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(result.duplicates.join(', '), style: const TextStyle(fontSize: 12)),
              ],
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Errors occurred in these rows:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  height: 100,
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: result.errors.length,
                    itemBuilder: (context, index) {
                      final error = result.errors[index];
                      return Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Text('Row ${error.row}: ${error.message}',
                            style: const TextStyle(fontSize: 12)),
                      );
                    },
                  ),
                ),
              ],
              ]
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

/// Represents the result of an import operation
class ImportResult {
  int imported = 0;
  int categoriesCreated = 0;
  List<int> duplicates = [];
  List<ImportError> errors = [];
  List<String> unknownCategories = [];
}

/// Represents an error during import
class ImportError {
  final int row;
  final String message;
  
  ImportError(this.row, this.message);
}
