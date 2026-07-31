import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';

class ShelvesScreen extends StatefulWidget {
  const ShelvesScreen({super.key});

  @override
  State<ShelvesScreen> createState() => _ShelvesScreenState();
}

class _ShelvesScreenState extends State<ShelvesScreen> {
  final Map<String, String> _pendingRenames = {};
  
  Future<bool> _onWillPop() async {
    // Save pending renames
    if (_pendingRenames.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      _pendingRenames.forEach((id, newLabel) {
        batch.update(FirebaseFirestore.instance.collection('racks').doc(id), {
          'label': newLabel,
        });
      });
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rack labels saved.')));
      }
    }
    return true;
  }

  void _editLabel(BuildContext context, String rackId, String currentLabel) {
    final ctrl = TextEditingController(text: _pendingRenames[rackId] ?? currentLabel);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename Rack', style: TextStyle(color: AppColors.primary)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'RACK LABEL'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _pendingRenames[rackId] = ctrl.text;
              });
              Navigator.pop(c);
            },
            child: const Text('CONFIRM', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          leading: BackButton(
            color: AppColors.textOnPrimary,
            onPressed: () async {
              await _onWillPop();
              if (mounted) Navigator.pop(context);
            },
          ),
          title: const Text('Shelves', style: TextStyle(color: AppColors.textOnPrimary)),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('racks').orderBy('order').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            final racks = snapshot.data?.docs ?? [];
            if (racks.isEmpty) return const Center(child: Text('No racks configured.'));

            return GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: racks.length,
              itemBuilder: (context, index) {
                final rackData = racks[index].data() as Map<String, dynamic>;
                final rackId = racks[index].id;
                final label = _pendingRenames[rackId] ?? rackData['label'] ?? rackId;
                final capacity = rackData['capacity'] ?? 10;
                final occupied = rackData['occupied'] ?? 0;
                final fillRatio = occupied / capacity;
                
                final isFull = occupied >= capacity;

                return GestureDetector(
                  onTap: () => _editLabel(context, rackId, rackData['label'] ?? rackId),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // Fill animation
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          height: (MediaQuery.of(context).size.height / 3) * fillRatio, // relative fill height
                          decoration: BoxDecoration(
                            color: isFull ? Colors.red.shade100 : Colors.cyan.shade100,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$occupied / $capacity',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: isFull ? Colors.red : Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(Icons.edit, size: 16, color: Colors.grey),
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
