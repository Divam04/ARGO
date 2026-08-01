import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../theme/app_colors.dart';

class StudentDatabaseScreen extends StatefulWidget {
  const StudentDatabaseScreen({super.key});

  @override
  State<StudentDatabaseScreen> createState() => _StudentDatabaseScreenState();
}

class _StudentDatabaseScreenState extends State<StudentDatabaseScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  Future<String?> _getPhotoUrl(String uid) async {
    final storage = FirebaseStorage.instance;
    final extensions = ['.jpeg', '.jpg', '.png'];
    
    for (var ext in extensions) {
      try {
        final url = await storage.ref('faces/$uid$ext').getDownloadURL();
        return url;
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  Future<void> _deleteStudent(String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text('Are you sure you want to permanently delete $name ($uid)? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('students').doc(uid).delete();
      
      final storage = FirebaseStorage.instance;
      final extensions = ['.jpeg', '.jpg', '.png'];
      for (var ext in extensions) {
        try {
          await storage.ref('faces/$uid$ext').delete();
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name deleted successfully.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete student: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Student Database', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Name or UID',
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('students').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final docs = snapshot.data?.docs ?? [];
          final filteredDocs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final uid = (data['uid'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) || uid.contains(_searchQuery);
          }).toList();
          
          if (filteredDocs.isEmpty) {
            return const Center(
              child: Text(
                'No students found.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
            ),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final student = filteredDocs[index].data() as Map<String, dynamic>;
              final uid = student['uid'] ?? 'N/A';
              final name = student['name'] ?? 'Unknown';
              final email = student['email'] ?? '';

              return Card(
                elevation: 4,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 3,
                            child: FutureBuilder<String?>(
                              future: _getPhotoUrl(uid),
                              builder: (context, photoSnapshot) {
                                if (photoSnapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                if (photoSnapshot.hasData && photoSnapshot.data != null) {
                                  return CircleAvatar(
                                    radius: 60,
                                    backgroundColor: AppColors.surface,
                                    backgroundImage: NetworkImage(photoSnapshot.data!),
                                  );
                                } else {
                                  return const CircleAvatar(
                                    radius: 60,
                                    backgroundColor: AppColors.primary,
                                    child: Icon(Icons.person, size: 60, color: Colors.white),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            uid,
                            style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _deleteStudent(uid, name),
                        tooltip: 'Delete Student',
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
