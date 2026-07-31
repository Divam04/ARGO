import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';

class EmailLogScreen extends StatefulWidget {
  const EmailLogScreen({super.key});

  @override
  State<EmailLogScreen> createState() => _EmailLogScreenState();
}

class _EmailLogScreenState extends State<EmailLogScreen> {
  final Set<String> _filters = {'COLLECTED', 'STORED'};

  void _toggleFilter(String type) {
    setState(() {
      if (_filters.contains(type)) {
        _filters.remove(type);
      } else {
        _filters.add(type);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: const BackButton(color: AppColors.textOnPrimary),
        title: const Text('Email Log', style: TextStyle(color: AppColors.textOnPrimary)),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Text('Filters:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 16),

                FilterChip(
                  label: const Text('STORED'),
                  selected: _filters.contains('STORED'),
                  onSelected: (_) => _toggleFilter('STORED'),
                  selectedColor: Colors.green.shade100,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('COLLECTED'),
                  selected: _filters.contains('COLLECTED'),
                  onSelected: (_) => _toggleFilter('COLLECTED'),
                  selectedColor: Colors.pink.shade100,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('emails')
                  .orderBy('sentAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                final emails = snapshot.data?.docs ?? [];
                
                final filteredEmails = emails.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  String type = data['type'] as String? ?? '';
                  final subject = data['subject'] as String? ?? '';
                  
                  // Legacy email support: infer type from subject
                  if (type.isEmpty) {
                    if (subject.toLowerCase().contains('arrived')) {
                      type = 'STORED';
                    } else if (subject.toLowerCase().contains('collected')) {
                      type = 'COLLECTED';
                    }
                  }

                  return _filters.contains(type.toUpperCase()) || _filters.contains(type); // fallback
                }).toList();

                if (filteredEmails.isEmpty) {
                  return const Center(child: Text('No emails match filters.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredEmails.length,
                  itemBuilder: (context, index) {
                    final doc = filteredEmails[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    String type = data['type'] ?? '';
                    final subject = data['subject'] ?? '';
                    if (type.isEmpty) {
                      if (subject.toLowerCase().contains('arrived')) {
                        type = 'STORED';
                      } else if (subject.toLowerCase().contains('collected')) {
                        type = 'COLLECTED';
                      } else {
                        type = 'UNKNOWN';
                      }
                    }
                    
                    final to = data['to'] ?? '';
                    final status = data['status'] ?? 'pending';
                    final timestamp = data['sentAt'] as Timestamp?;
                    final dateStr = timestamp != null 
                        ? DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch).toLocal().toString()
                        : 'Pending';

                    Color statusColor;
                    switch (status) {
                      case 'sent': statusColor = Colors.green; break;
                      case 'failed': statusColor = Colors.red; break;
                      case 'bounced': statusColor = Colors.orange; break;
                      default: statusColor = Colors.grey;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1,
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: type == 'PIN' ? Colors.cyan : type == 'STORED' ? Colors.green : Colors.pink,
                          child: Text(type.substring(0, 1), style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('To: $to • $dateStr'),
                        trailing: Chip(
                          label: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                          backgroundColor: statusColor,
                        ),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            width: double.infinity,
                            color: Colors.grey.shade50,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Message ID: ${data['smtpMessageId'] ?? 'N/A'}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('Parcel Ref: ${data['parcelId'] ?? 'N/A'}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                                if (data['error'] != null) ...[
                                  const SizedBox(height: 8),
                                  Text('Error: ${data['error']}', style: const TextStyle(color: Colors.red)),
                                ],
                                const Divider(height: 24),
                                const Text('Email Body (Plain Text):', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(data['text'] ?? 'No plain text body.'),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
