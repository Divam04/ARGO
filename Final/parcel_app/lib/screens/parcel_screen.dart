import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'receiver_search_screen.dart';

class ParcelScreen extends StatelessWidget {
  final Map<String, dynamic> parcelData;

  const ParcelScreen({Key? key, required this.parcelData}) : super(key: key);

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Unknown';
    try {
      final DateTime dt = DateTime.parse(isoString).toLocal();
      return DateFormat('dd-MM-yyyy hh:mm a').format(dt);
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Parcel Found'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('DELIVERY SERVICE', parcelData['deliveryService'] ?? 'Unknown'),
              const SizedBox(height: 16),
              _buildDetailRow('DATE OF DELIVERY', _formatDate(parcelData['dateOfDelivery'])),
              const SizedBox(height: 16),
              _buildDetailRow('NAME ON LABEL', parcelData['recipientName'] ?? 'Unknown'),
              const SizedBox(height: 16),
              if (parcelData['trackingNumber'] != null && parcelData['trackingNumber'].toString().isNotEmpty)
                _buildDetailRow('TRACKING NO.', parcelData['trackingNumber']),
              const Divider(height: 32),
              _buildDetailRow('LOCATION', '${parcelData['rack'] ?? 'Unknown Rack'} (Parcel #${parcelData['monthlySequenceNumber'] ?? '?'})'),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('BACK', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReceiverSearchScreen(
                              parcelData: parcelData,
                              ownerUid: parcelData['studentUid'],
                            ),
                          ),
                        );
                      },
                      child: const Text('PROCEED', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
