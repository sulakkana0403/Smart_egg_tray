import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EggSummaryPage extends StatelessWidget {
  const EggSummaryPage({super.key});

  Map<String, dynamic> calculateExpiryAndStatus(String storedDate) {
    DateTime stored = DateTime.parse(storedDate);
    DateTime expiry = stored.add(const Duration(days: 7));
    DateTime today = DateTime.now();

    String status = today.isAfter(expiry) ? 'Expired' : 'Fresh';
    return {'expiry': expiry.toIso8601String().split('T')[0], 'status': status};
  }

  @override
  Widget build(BuildContext context) {
    final CollectionReference eggsCollection = FirebaseFirestore.instance
        .collection('eggs');

    final List<String> allSlots = ['1', '2', '3', '4', '5', '6', '7', '8'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Egg Summary'),
        backgroundColor: const Color(0xFF66A6FF),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: eggsCollection.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final eggs = snapshot.data!.docs;
          Map<String, Map<String, dynamic>> eggMap = {};

          for (var eggDoc in eggs) {
            var data = eggDoc.data() as Map<String, dynamic>;
            if (data.containsKey('slot')) {
              eggMap[data['slot'].toString()] = data;
            }
          }

          int totalSlots = 8;
          int emptySlots = 0;
          int freshCount = 0;
          int expiredCount = 0;

          for (var slot in allSlots) {
            if (!eggMap.containsKey(slot)) {
              emptySlots++;
            } else {
              var eggData = eggMap[slot]!;
              if (eggData['date'] != null &&
                  eggData['date'].toString().isNotEmpty) {
                var expiryStatus = calculateExpiryAndStatus(eggData['date']);
                if (expiryStatus['status'] == 'Fresh') {
                  freshCount++;
                } else {
                  expiredCount++;
                }
              } else {
                emptySlots++;
              }
            }
          }

          int totalEggs = totalSlots - emptySlots;

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                summaryCard(
                  icon: Icons.egg,
                  label: 'Total Eggs',
                  value: '$totalEggs',
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),
                summaryCard(
                  icon: Icons.check_circle,
                  label: 'Fresh Eggs',
                  value: '$freshCount',
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                summaryCard(
                  icon: Icons.warning,
                  label: 'Expired Eggs',
                  value: '$expiredCount',
                  color: Colors.red,
                ),
                const SizedBox(height: 12),
                summaryCard(
                  icon: Icons.remove_circle_outline,
                  label: 'Empty Slots',
                  value: '$emptySlots',
                  color: Colors.grey,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
