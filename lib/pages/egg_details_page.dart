import 'package:flutter/material.dart';

class EggDetailsPage extends StatelessWidget {
  final String slot;
  final String date;
  final String expiry;

  const EggDetailsPage({
    super.key,
    required this.slot,
    required this.date,
    required this.expiry,
  });

  String getEggStatus() {
    DateTime expiryDate = DateTime.parse(expiry);
    DateTime today = DateTime.now();

    if (today.isAfter(expiryDate)) {
      return 'Expired';
    } else {
      return 'Fresh';
    }
  }

  Color getStatusColor(String status) {
    return status == 'Expired' ? Colors.red : Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final status = getEggStatus();

    return Scaffold(
      appBar: AppBar(
        title: Text('Egg Slot $slot Details'),
        backgroundColor: const Color(0xFF66A6FF),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.egg, size: 100, color: Colors.orange),
                  const SizedBox(height: 24),
                  Text(
                    'Slot Number: $slot',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Stored Date: $date',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Expiry Date: $expiry',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Status: $status',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: getStatusColor(status),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
