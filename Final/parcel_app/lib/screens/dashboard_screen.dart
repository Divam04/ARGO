import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../theme/app_colors.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _error;
  Map<dynamic, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('dashboardStats').call();
      setState(() {
        _stats = result.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _exportToExcel() async {
    if (_stats == null) return;
    
    final excel = Excel.createExcel();
    final sheet = excel['Parcels In Storage'];
    
    sheet.appendRow([
      TextCellValue('Parcel ID'),
      TextCellValue('Delivery Service'),
      TextCellValue('Tracking Number'),
      TextCellValue('Recipient Name'),
      TextCellValue('Rack'),
      TextCellValue('Received At'),
    ]);

    final storedParcels = _stats!['storedParcels'] as List<dynamic>? ?? [];
    for (var p in storedParcels) {
      sheet.appendRow([
        TextCellValue(p['id']?.toString() ?? ''),
        TextCellValue(p['deliveryService']?.toString() ?? ''),
        TextCellValue(p['trackingNumber']?.toString() ?? ''),
        TextCellValue(p['recipientName']?.toString() ?? ''),
        TextCellValue(p['rack']?.toString() ?? ''),
        TextCellValue(p['receivedAt']?.toString() ?? ''),
      ]);
    }

    try {
      // Save directly to Downloads folder on Android
      // On Windows/desktop, we use getDownloadsDirectory
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getDownloadsDirectory();
      }
      
      if (dir == null) throw Exception("Could not find downloads directory");
      
      final filePath = '${dir.path}/Parcels_Storage_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      
      final bytes = excel.save();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to: $filePath')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export: $e')));
      }
    }
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: const BackButton(color: AppColors.textOnPrimary),
        title: const Text('Dashboard', style: TextStyle(color: AppColors.textOnPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textOnPrimary),
            onPressed: _loadStats,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.download, color: AppColors.textOnPrimary),
            onPressed: _stats == null ? null : _exportToExcel,
            tooltip: 'Download Excel',
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _error != null
          ? Center(child: Text('Error: $_error', style: const TextStyle(color: Colors.red)))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final total = _stats!['total'] ?? 0;
    final collected = _stats!['collected'] ?? 0;
    final uncollected = _stats!['uncollected'] ?? 0;
    final avgDays = (_stats!['avgDays'] ?? 0).toStringAsFixed(1);
    final unmatched = _stats!['unmatched'] ?? 0;
    
    final dailyIntake = _stats!['dailyIntake'] as List<dynamic>? ?? [];
    final storedParcels = _stats!['storedParcels'] as List<dynamic>? ?? [];

    List<BarChartGroupData> barGroups = [];
    List<String> xLabels = [];
    
    double maxY = 0;
    
    for (int i = 0; i < dailyIntake.length; i++) {
      final dayData = dailyIntake[i];
      final received = (dayData['received'] as num).toDouble();
      final coll = (dayData['collected'] as num).toDouble();
      final dateStr = dayData['date'].toString();
      
      if (received > maxY) maxY = received;
      if (coll > maxY) maxY = coll;
      
      xLabels.add(dateStr.substring(5)); // MM-DD
      
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(toY: received, color: Colors.blue, width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            BarChartRodData(toY: coll, color: Colors.green, width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
          ],
        )
      );
    }
    
    // Sort xLabels to be ascending order (oldest first). Wait, the backend initializes from 6 days ago to 0, so it's already in chronological order.

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildStatCard('TOTAL PARCELS', '$total', Colors.blue),
                    _buildStatCard('COLLECTED', '$collected', Colors.green),
                    _buildStatCard('UNCOLLECTED', '$uncollected', Colors.orange),
                    _buildStatCard('AVG DAYS', avgDays, Colors.purple),
                    _buildStatCard('UNMATCHED', '$unmatched', Colors.red),
                  ],
                ),
                const SizedBox(height: 32),
                
                const Text('Daily Parcel Intake vs Collection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.square, color: Colors.blue, size: 16), SizedBox(width: 4), Text('Received'),
                    SizedBox(width: 16),
                    Icon(Icons.square, color: Colors.green, size: 16), SizedBox(width: 4), Text('Collected'),
                  ],
                ),
                const SizedBox(height: 16),
                
                Container(
                  height: 300,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: BarChart(
                    BarChartData(
                      maxY: maxY + (maxY * 0.2) + 1,
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              if (val.toInt() >= 0 && val.toInt() < xLabels.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(xLabels[val.toInt()], style: const TextStyle(fontSize: 10)),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: barGroups,
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                const Text('Parcels in Storage', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final p = storedParcels[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
                child: Card(
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.inventory_2, color: Colors.white)),
                    title: Text('${p['recipientName']} • ${p['deliveryService']}'),
                    subtitle: Text('AWB: ${p['trackingNumber']} • Received: ${p['receivedAt']?.toString().substring(0, 10)}'),
                    trailing: Text(
                      '#${p['monthlySequenceNumber'] ?? '?'} (Rack ${p['rack'] ?? ''})', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                  ),
                ),
              );
            },
            childCount: storedParcels.length,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    ));
  }
}
