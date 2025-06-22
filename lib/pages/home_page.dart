import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'egg_details_page.dart';
import 'egg_summary_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Map<String, dynamic> calculateExpiryAndStatus(String storedDate) {
    DateTime stored = DateTime.parse(storedDate);
    DateTime expiry = stored.add(const Duration(days: 7));
    DateTime today = DateTime.now();

    String status = today.isAfter(expiry) ? 'Expired' : 'Fresh';
    String expiryString = expiry.toIso8601String().split('T')[0];

    return {'expiry': expiryString, 'status': status};
  }

  @override
  Widget build(BuildContext context) {
    final CollectionReference eggsCollection = FirebaseFirestore.instance
        .collection('eggs');

    final List<String> allSlots = ['1', '2', '3', '4', '5', '6', '7', '8'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Egg Tray Status'),
        backgroundColor: const Color(0xFF66A6FF),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Egg Summary',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EggSummaryPage()),
              );
            },
          ),
        ],
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

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: allSlots.length,
            itemBuilder: (context, index) {
              final slotNumber = allSlots[index];
              final data = eggMap[slotNumber];

              if (data == null ||
                  data['date'] == null ||
                  data['date'].toString().isEmpty) {
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.grey,
                      size: 40,
                    ),
                    title: Text('Slot: $slotNumber'),
                    subtitle: const Text('No Egg Available'),
                  ),
                );
              } else {
                var expiryStatus = calculateExpiryAndStatus(data['date']);
                DateTime expiryDate = DateTime.parse(expiryStatus['expiry']);
                int daysLeft = expiryDate.difference(DateTime.now()).inDays;

                IconData? warningIcon;
                Color iconColor = Colors.transparent;
                String notificationMessage = '';

                if (daysLeft < 0) {
                  warningIcon = Icons.warning;
                  iconColor = Colors.red;
                  notificationMessage = 'Egg in Slot $slotNumber is EXPIRED!';
                } else if (daysLeft <= 3) {
                  warningIcon = Icons.warning_amber;
                  iconColor = Colors.orange;
                  notificationMessage =
                      (daysLeft == 0)
                          ? 'Egg in Slot $slotNumber will expire TODAY!'
                          : 'Egg in Slot $slotNumber will expire in $daysLeft day(s).';
                }

                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.egg,
                      color: Colors.orange,
                      size: 40,
                    ),
                    title: Text('Slot: ${data['slot']}'),
                    subtitle: Text('Stored Date: ${data['date']}'),
                    trailing:
                        (warningIcon != null)
                            ? IconButton(
                              icon: Icon(warningIcon, color: iconColor),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: const Text('Expiry Alert'),
                                        content: Text(notificationMessage),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(context),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                );
                              },
                            )
                            : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => EggDetailsPage(
                                slot: data['slot'],
                                date: data['date'],
                                expiry: expiryStatus['expiry'],
                              ),
                        ),
                      );
                    },
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
