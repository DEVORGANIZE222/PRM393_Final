import 'package:flutter/material.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, String>> _items = [
    {'id': 'EV01', 'title': 'AI Capstone Kickoff 2026', 'status': 'published'},
    {'id': 'EV02', 'title': 'FinTech Mentorship Session', 'status': 'published'},
    {'id': 'EV03', 'title': 'Proposal Review Workshop', 'status': 'archived'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Entity Management (Events & Topics)',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // Scaffold for creating new item
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Create Entity Dialog')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF107C41),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Create New'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search entities...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final isArchived = item['status'] == 'archived';
                  return ListTile(
                    title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('ID: ${item['id']} · Status: ${item['status']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: Icon(
                            isArchived ? Icons.unarchive : Icons.archive,
                            size: 20,
                            color: isArchived ? Colors.grey : Colors.orange,
                          ),
                          onPressed: () {
                            setState(() {
                              item['status'] = isArchived ? 'published' : 'archived';
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

