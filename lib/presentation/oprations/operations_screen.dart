import 'package:flutter/material.dart';

import '../../core/services/db_helper.dart';

class OperationsScreen extends StatefulWidget {
  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  List<Map<String, dynamic>> _operations = [];

  @override
  void initState() {
    super.initState();
    _loadOperations();
  }

  Future<void> _loadOperations() async {
    final db = await DBHelper.initDB();
    final data = await db.query('operations', orderBy: "localPerformedAt DESC");
    setState(() {
      _operations = data;
    });
  }

  Color _statusColor(String status) {
    if (status == "synced") return Colors.green;
    return Colors.orange; // pending
  }

  IconData _typeIcon(String type) {
    if (type == "import") return Icons.add_circle;
    return Icons.remove_circle; // export
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Operations History")),
      body: _operations.isEmpty
          ? const Center(child: Text("No operations yet"))
          : ListView.builder(
              itemCount: _operations.length,
              itemBuilder: (context, index) {
                final op = _operations[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: Icon(
                      _typeIcon(op['type']),
                      color: op['type'] == 'import' ? Colors.blue : Colors.red,
                    ),
                    title: Text("${op['itemName']} (${op['quantity']})"),
                    subtitle: Text(
                      "Performed: ${op['localPerformedAt']}\nStatus: ${op['status']}",
                    ),
                    trailing: Icon(
                      Icons.circle,
                      color: _statusColor(op['status']),
                      size: 14,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
