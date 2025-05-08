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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Income'),
              Tab(text: 'Expense'),
            ],
          ),
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
        body: TabBarView(
          children: [
            // Income tab
            StreamBuilder<List<Category>>(
              stream: widget.db.select(widget.db.categories).watch(),
              builder: (context, snapshot) {
                final cats = (snapshot.data ?? [])
                    .where((c) => c.type.toLowerCase() == 'income')
                    .toList();
                return ListView.builder(
                  itemCount: cats.length,
                  itemBuilder: (context, index) {
                    final cat = cats[index];
                    return ListTile(
                      title: Text(cat.name),
                      subtitle: Text(cat.type),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/add_category',
                                arguments: cat,
                              ).then((_) => setState(() {}));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await widget.db.delete(widget.db.categories).delete(cat);
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            // Expense tab
            StreamBuilder<List<Category>>(
              stream: widget.db.select(widget.db.categories).watch(),
              builder: (context, snapshot) {
                final cats = (snapshot.data ?? [])
                    .where((c) => c.type.toLowerCase() == 'expense')
                    .toList();
                return ListView.builder(
                  itemCount: cats.length,
                  itemBuilder: (context, index) {
                    final cat = cats[index];
                    return ListTile(
                      title: Text(cat.name),
                      subtitle: Text(cat.type),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/add_category',
                                arguments: cat,
                              ).then((_) => setState(() {}));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await widget.db.delete(widget.db.categories).delete(cat);
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
