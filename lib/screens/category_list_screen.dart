import 'package:flutter/material.dart';
import '../models/app_database.dart';

class CategoryListScreen extends StatefulWidget {
  final AppDatabase db;
  const CategoryListScreen({Key? key, required this.db}) : super(key: key);

  @override
  _CategoryListScreenState createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/add_category')
                  .then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Category>>(
        stream: widget.db.select(widget.db.categories).watch(),
        builder: (context, snapshot) {
          final categories = snapshot.data ?? [];
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return ListTile(
                title: Text(cat.name),
                subtitle: Text(cat.type),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.pushNamed(context, '/add_category', arguments: cat)
                        .then((_) => setState(() {}));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
