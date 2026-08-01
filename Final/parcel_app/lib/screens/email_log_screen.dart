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
  DateTime? _selectedDate;

  void _toggleFilter(String type) {
    setState(() {
      if (_filters.contains(type)) {
        _filters.remove(type);
      } else {
        _filters.add(type);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _clearDate() {
    setState(() {
      _selectedDate = null;
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
                const Spacer(),
                if (_selectedDate != null)
                  Chip(
                    label: Text('${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: _clearDate,
                    backgroundColor: Colors.blue.shade50,
                  ),
                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  onPressed: _pickDate,
                  tooltip: 'Filter by date',
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

                  final typeMatch = _filters.contains(type.toUpperCase()) || _filters.contains(type); // fallback
                  if (!typeMatch) return false;

                  if (_selectedDate != null) {
                    final timestamp = data['sentAt'] as Timestamp?;
                    if (timestamp == null) return false;
                    
                    final date = timestamp.toDate().toLocal();
                    if (date.year != _selectedDate!.year || 
                        date.month != _selectedDate!.month || 
                        date.day != _selectedDate!.day) {
                      return false;
                    }
                  }

                  return true;
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
