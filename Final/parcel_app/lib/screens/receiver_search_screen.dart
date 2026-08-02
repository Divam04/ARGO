import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'face_scan_screen.dart';

class ReceiverSearchScreen extends StatefulWidget {
  final Map<String, dynamic> parcelData;
  final String? ownerUid;

  const ReceiverSearchScreen({Key? key, required this.parcelData, this.ownerUid}) : super(key: key);

  @override
  _ReceiverSearchScreenState createState() => _ReceiverSearchScreenState();
}

class _ReceiverSearchScreenState extends State<ReceiverSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<DocumentSnapshot> _results = [];
  DocumentSnapshot? _ownerDoc;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.ownerUid != null) {
      _loadOwner();
    }
  }

  Future<void> _loadOwner() async {
    final doc = await FirebaseFirestore.instance.collection('students').doc(widget.ownerUid).get();
    if (doc.exists && mounted) {
      setState(() {
        _ownerDoc = doc;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    final qLower = query.toLowerCase();
    
    // Using a basic query and sorting locally as per ranking rules
    // Rule 1: Prefix UID
    // Rule 2: Prefix Name
    // Rule 3: Substring
    final snapshot = await FirebaseFirestore.instance.collection('students').get();
    
    final allDocs = snapshot.docs;
    List<DocumentSnapshot> matched = [];
    
    for (var doc in allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name']?.toString() ?? '').toLowerCase();
      final uid = (data['uid']?.toString() ?? doc.id).toLowerCase();
      
      if (uid.contains(qLower) || name.contains(qLower)) {
        matched.add(doc);
      }
    }
    
    // Sort
    matched.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;
      final nameA = (dataA['name']?.toString() ?? '').toLowerCase();
      final uidA = (dataA['uid']?.toString() ?? a.id).toLowerCase();
      final nameB = (dataB['name']?.toString() ?? '').toLowerCase();
      final uidB = (dataB['uid']?.toString() ?? b.id).toLowerCase();
      
      int scoreA = _getScore(uidA, nameA, qLower);
      int scoreB = _getScore(uidB, nameB, qLower);
      
      if (scoreA != scoreB) return scoreA.compareTo(scoreB);
      
      int parcelsA = dataA['parcelsWaiting'] ?? 0;
      int parcelsB = dataB['parcelsWaiting'] ?? 0;
      return parcelsB.compareTo(parcelsA); // Descending
    });

    if (mounted) {
      setState(() {
        _results = matched.take(8).toList();
        _isLoading = false;
      });
    }
  }

  int _getScore(String uid, String name, String query) {
    if (uid.startsWith(query)) return 1;
    if (name.startsWith(query)) return 2;
    return 3;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Enter Student ID of receiver'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Handing over Parcel #${widget.parcelData['monthlySequenceNumber'] ?? '?'}', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                    const SizedBox(height: 8),
                    Text('${widget.parcelData['deliveryService'] ?? 'Unknown Courier'} • AWB: ${widget.parcelData['trackingNumber'] ?? 'N/A'}', 
                      style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by UID or Name',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 24),
              Text(
                isSearching ? 'Suggested' : 'Recent Searches / Shortcuts',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (!isSearching && _ownerDoc != null)
                _buildStudentTile(_ownerDoc!, isOwner: true)
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      return _buildStudentTile(_results[index], isOwner: _results[index].id == widget.ownerUid);
                    },
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentTile(DocumentSnapshot doc, {bool isOwner = false}) {
    final data = doc.data() as Map<String, dynamic>;
    final parcelsWaiting = data['parcelsWaiting'] ?? 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade200,
          child: const Icon(Icons.person, color: Colors.grey),
        ),
        title: Row(
          children: [
            Text(data['name']?.toString() ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isOwner) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Owner', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12)),
              ),
            ]
          ],
        ),
        subtitle: Text(data['uid']?.toString() ?? doc.id),
        trailing: parcelsWaiting > 0
            ? Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  parcelsWaiting.toString(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FaceScanScreen(
                parcelData: widget.parcelData,
                receiverDoc: doc,
                isOwner: isOwner,
              ),
            ),
          );
        },
      ),
    );
  }
}
