import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive_io.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/face_recognition_service.dart';
import '../theme/app_colors.dart';

class BulkEnrolScreen extends StatefulWidget {
  const BulkEnrolScreen({super.key});

  @override
  State<BulkEnrolScreen> createState() => _BulkEnrolScreenState();
}

class _BulkEnrolScreenState extends State<BulkEnrolScreen> {
  bool _isProcessing = false;
  String _statusMessage = 'Select faces.zip to begin.';
  double _progress = 0;
  final List<String> _logs = [];

  void _addLog(String msg) {
    setState(() {
      _logs.add(msg);
      _statusMessage = msg;
    });
    print(msg);
  }

  Future<void> _startEnrolment() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any, // .zip
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) return;
    
    final zipFile = File(result.files.single.path!);
    if (!zipFile.path.toLowerCase().endsWith('.zip')) {
      _addLog('ERROR: Please select a valid ZIP file.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _logs.clear();
    });

    _addLog('Extracting ZIP file...');
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      final tempDir = await getTemporaryDirectory();
      final targetDir = Directory('${tempDir.path}/faces_unzipped_${DateTime.now().millisecondsSinceEpoch}');
      await targetDir.create();

      File? csvFile;
      List<File> images = [];

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File('${targetDir.path}/$filename');
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(data);
          
          if (filename.toLowerCase().endsWith('students.csv')) {
            csvFile = outFile;
          } else if (filename.toLowerCase().contains('photos/')) {
            images.add(outFile);
          }
        }
      }

      if (csvFile == null) {
        _addLog('ERROR: students.csv not found in the ZIP.');
        setState(() => _isProcessing = false);
        return;
      }

      _addLog('Parsing students.csv...');
      final csvString = await csvFile.readAsString();
      final rows = const CsvToListConverter().convert(csvString);
      
      int total = images.length;
      int success = 0;
      int failed = 0;

      final faceService = FaceRecognitionService();
      await faceService.init();

      _addLog('Processing $total images...');
      
      for (int i = 0; i < images.length; i++) {
        final imgFile = images[i];
        final filename = imgFile.path.split(Platform.pathSeparator).last;
        final uid = filename.split('.').first;
        
        try {
          final embedding = await faceService.extractEmbedding(imgFile);
          
          if (embedding != null) {
            await FirebaseFirestore.instance.collection('students').doc(uid).set({
              'faceEmbedding': embedding,
              'faceEnrolledAt': FieldValue.serverTimestamp(),
              'faceSource': 'seed_import'
            }, SetOptions(merge: true));
            success++;
            _addLog('SUCCESS: $uid enrolled.');
          } else {
            failed++;
            _addLog('FAILED: No face detected in $filename.');
          }
        } catch (e) {
          failed++;
          _addLog('ERROR: Failed processing $filename: $e');
        }

        setState(() {
          _progress = (i + 1) / total;
        });
      }

      faceService.dispose();
      
      // Cleanup temp dir
      await targetDir.delete(recursive: true);
      
      _addLog('DONE! Successfully enrolled $success, failed $failed.');

    } catch (e) {
      _addLog('CRITICAL ERROR: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: const BackButton(color: AppColors.textOnPrimary),
        title: const Text('Bulk Face Enrolment', style: TextStyle(color: AppColors.textOnPrimary)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Upload a faces.zip containing students.csv and a photos/ folder named by UID.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: _isProcessing ? null : _startEnrolment,
                      icon: const Icon(Icons.upload_file, color: AppColors.textOnPrimary),
                      label: const Text('SELECT ZIP', style: TextStyle(color: AppColors.textOnPrimary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_isProcessing || _progress > 0) ...[
              LinearProgressIndicator(value: _progress, color: AppColors.primary),
              const SizedBox(height: 8),
              Text('${(_progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    Color c = Colors.white;
                    if (log.contains('ERROR') || log.contains('FAILED')) c = Colors.redAccent;
                    if (log.contains('SUCCESS') || log.contains('DONE')) c = Colors.greenAccent;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(log, style: TextStyle(color: c, fontFamily: 'monospace')),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
