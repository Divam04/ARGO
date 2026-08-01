import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'guards_list_screen.dart';
import 'shelves_screen.dart';
import 'api_keys_list_screen.dart';
import 'bulk_enrol_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'student_database_screen.dart';

class AdminMenuScreen extends StatelessWidget {
  const AdminMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await FirebaseAuth.instance.signOut();
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          leading: BackButton(
            color: AppColors.textOnPrimary,
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pop(context);
            },
          ),
          title: GestureDetector(
            onLongPress: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BulkEnrolScreen()),
              );
            },
            child: const Text('Admin Menu', style: TextStyle(color: AppColors.textOnPrimary)),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.dashboard_customize,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const GuardsListScreen()),
                        );
                      },
                      icon: const Icon(Icons.security, color: Colors.white, size: 28),
                      label: const Text(
                        'GUARDS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ShelvesScreen()),
                        );
                      },
                      icon: const Icon(Icons.shelves, color: Colors.white, size: 28),
                      label: const Text(
                        'SHELVES',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ApiKeysListScreen()),
                        );
                      },
                      icon: const Icon(Icons.vpn_key, color: Colors.white, size: 28),
                      label: const Text(
                        'API KEYS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        _showReminderSettingsDialog(context);
                      },
                      icon: const Icon(Icons.timer, color: Colors.white, size: 28),
                      label: const Text(
                        'REMINDER SETTINGS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const StudentDatabaseScreen()),
                        );
                      },
                      icon: const Icon(Icons.people_alt, color: Colors.white, size: 28),
                      label: const Text(
                        'STUDENT DATABASE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showReminderSettingsDialog(BuildContext context) async {
    int selectedDays = 0;
    int selectedHours = 0;
    int selectedMinutes = 10;
    bool isInitialLoading = true;
    bool isSaving = false;

    // Show dialog immediately with a loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Fetch once
            if (isInitialLoading) {
              FirebaseFirestore.instance.collection('settings').doc('general').get().then((doc) {
                if (doc.exists && doc.data()!.containsKey('reminderIntervalMinutes')) {
                  int totalMinutes = doc.data()!['reminderIntervalMinutes'] as int;
                  selectedDays = totalMinutes ~/ (24 * 60);
                  int remainder = totalMinutes % (24 * 60);
                  selectedHours = remainder ~/ 60;
                  selectedMinutes = remainder % 60;
                }
                setState(() {
                  isInitialLoading = false;
                });
              }).catchError((e) {
                setState(() {
                  isInitialLoading = false;
                });
              });
            }

            return AlertDialog(
              title: const Text('Reminder Settings'),
              content: isInitialLoading
                  ? const SizedBox(
                      height: 150,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Set the reminder interval:'),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Days
                            Column(
                              children: [
                                const Text('Days', style: TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(
                                  height: 150,
                                  width: 70,
                                  child: CupertinoPicker(
                                    scrollController: FixedExtentScrollController(initialItem: selectedDays),
                                    itemExtent: 40,
                                    onSelectedItemChanged: (val) => setState(() => selectedDays = val),
                                    children: List.generate(8, (i) => Center(child: Text('$i'))),
                                  ),
                                ),
                              ],
                            ),
                            const Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            // Hours
                            Column(
                              children: [
                                const Text('Hours', style: TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(
                                  height: 150,
                                  width: 70,
                                  child: CupertinoPicker(
                                    scrollController: FixedExtentScrollController(initialItem: selectedHours),
                                    itemExtent: 40,
                                    onSelectedItemChanged: (val) => setState(() => selectedHours = val),
                                    children: List.generate(24, (i) => Center(child: Text('$i'))),
                                  ),
                                ),
                              ],
                            ),
                            const Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            // Minutes
                            Column(
                              children: [
                                const Text('Minutes', style: TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(
                                  height: 150,
                                  width: 70,
                                  child: CupertinoPicker(
                                    scrollController: FixedExtentScrollController(initialItem: selectedMinutes),
                                    itemExtent: 40,
                                    onSelectedItemChanged: (val) => setState(() => selectedMinutes = val),
                                    children: List.generate(60, (i) => Center(child: Text('$i'))),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
              actions: [
                TextButton(
                  onPressed: (isInitialLoading || isSaving) ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: (isInitialLoading || isSaving)
                      ? null
                      : () async {
                          setState(() {
                            isSaving = true;
                          });
                          int finalVal = (selectedDays * 24 * 60) + (selectedHours * 60) + selectedMinutes;
                          if (finalVal < 1) finalVal = 1;

                          try {
                            await FirebaseFirestore.instance.collection('settings').doc('general').set({
                              'reminderIntervalMinutes': finalVal,
                            }, SetOptions(merge: true));
                          } catch (e) {
                            // ignore
                          }

                          if (context.mounted) Navigator.pop(context);
                        },
                  child: isSaving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
