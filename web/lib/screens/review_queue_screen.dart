import 'package:flutter/material.dart';

class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  final List<Map<String, String>> _submissions = [
    {
      'id': 'reg_01',
      'studentName': 'Hoang Dang',
      'email': 'danghoang862@gmail.com',
      'team': 'Team AI-04',
      'status': 'pending',
    },
    {
      'id': 'reg_02',
      'studentName': 'Khanh Vo',
      'email': 'khanhvo@fpt.edu.vn',
      'team': 'FinTech Guard',
      'status': 'pending',
    },
  ];

  void _reviewItem(int index, bool approve) {
    final item = _submissions[index];
    if (!approve) {
      // Reason dialog for rejection
      final reasonCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rejection Reason'),
          content: TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(hintText: 'Enter reason for rejection...'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => item['status'] = 'rejected');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Rejected ${item['studentName']}')),
                );
              },
              child: const Text('Confirm Reject'),
            ),
          ],
        ),
      );
    } else {
      setState(() => item['status'] = 'approved');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approved ${item['studentName']}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review Queue (Cross-Role Approval)',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Approve or reject team registrations submitted from the mobile app.',
            style: TextStyle(color: Colors.black54),
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
                itemCount: _submissions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _submissions[index];
                  final status = item['status']!;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: status == 'approved'
                          ? Colors.green.shade100
                          : status == 'rejected'
                              ? Colors.red.shade100
                              : Colors.orange.shade100,
                      child: Icon(
                        status == 'approved'
                            ? Icons.check
                            : status == 'rejected'
                                ? Icons.close
                                : Icons.hourglass_top,
                        color: status == 'approved'
                            ? Colors.green
                            : status == 'rejected'
                                ? Colors.red
                                : Colors.orange,
                      ),
                    ),
                    title: Text(item['studentName']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${item['email']} · Target: ${item['team']}'),
                    trailing: status == 'pending'
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton(
                                onPressed: () => _reviewItem(index, false),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Reject'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _reviewItem(index, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF107C41),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Approve'),
                              ),
                            ],
                          )
                        : Chip(
                            label: Text(status.toUpperCase()),
                            backgroundColor: status == 'approved'
                                ? Colors.green.shade50
                                : Colors.red.shade50,
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

