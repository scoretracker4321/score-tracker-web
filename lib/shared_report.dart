import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull extension
import 'dart:math' as math; // Import for 'math'

// Import models
import 'models.dart'; // Contains StudentGroup, ScoreHistoryEntry, SharedReport models

/// A StatelessWidget that displays a shared report for a specific class.
/// It fetches the report metadata and student/group data from Firestore.
class ReportViewerPage extends StatefulWidget {
  final String reportId;
  final FirebaseFirestore firestore;

  const ReportViewerPage({
    super.key,
    required this.reportId,
    required this.firestore,
  });

  @override
  _ReportViewerPageState createState() => _ReportViewerPageState();
}

class _ReportViewerPageState extends State<ReportViewerPage> {
  SharedReport? _sharedReport;
  List<StudentGroup> _studentsInReport = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchReportData(); // Start fetching data when the widget initializes
  }

  /// Fetches the shared report metadata and the associated student/group data from Firestore.
  Future<void> _fetchReportData() async {
    try {
      // 1. Fetch SharedReport metadata using the provided reportId
      // IMPORTANT: Use the hardcoded app ID 'scoretrackerapp-16051' for public data access
      // in the ReportViewerPage to ensure it can always find the reports.
      final reportDoc = await widget.firestore
          .collection('artifacts')
          .doc('scoretrackerapp-16051')
          .collection('public')
          .doc('data')
          .collection('sharedReports')
          .doc(widget.reportId)
          .get();

      // Check if report exists and has data
      if (!reportDoc.exists || reportDoc.data() == null) {
        setState(() {
          _errorMessage = 'Report not found or has no data. It might have been deleted or never existed.';
          _isLoading = false;
        });
        return;
      }

      _sharedReport = SharedReport.fromMap(reportDoc.data()!, id: reportDoc.id);

      // Check if the report is active
      if (!_sharedReport!.active) {
        setState(() {
          _errorMessage = 'This report has been deactivated by the creator.';
          _isLoading = false;
        });
        return;
      }

      // 2. Fetch student/group data for the specified classId from the fetched report
      // Explicitly type the CollectionReference to ensure QuerySnapshot is also correctly typed.
      CollectionReference<Map<String, dynamic>> studentsRef = widget.firestore
          .collection('artifacts')
          .doc('scoretrackerapp-16051')
          .collection('public')
          .doc('data')
          .collection('students');

      final QuerySnapshot<Map<String, dynamic>> studentDocs = await studentsRef
          .where('classId', isEqualTo: _sharedReport!.classId)
          .where('isArchived', isEqualTo: false) // Only show non-archived students in the report
          .get();

      // Convert fetched documents to StudentGroup objects
      _studentsInReport = studentDocs.docs
          .map((doc) => StudentGroup.fromMap(doc.data(), id: doc.id))
          .toList();

      // Sort students by score descending for the report display
      _studentsInReport.sort((a, b) => b.score.compareTo(a.score));

      setState(() {
        _isLoading = false; // Data loaded successfully
      });
    } catch (e) {
      // Catch and display any errors during data fetching
      setState(() {
        _errorMessage = 'Error loading report: $e';
        _isLoading = false;
      });
      print('Error loading report: $e'); // Log error to console for debugging
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Report...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show error message if any occurred
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),
      );
    }

    // Fallback if _sharedReport is null (shouldn't happen with proper error handling, but for safety)
    if (_sharedReport == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report Error')),
        body: const Center(child: Text('Report data not available.')),
      );
    }

    // Calculate net growth for each student/group to identify those with least growth
    List<Map<String, dynamic>> growthData = _studentsInReport.map((item) {
      final int initialScore = item.history.isNotEmpty ? item.history.first.score : item.score;
      final int netGrowth = item.score - initialScore;
      return {
        'item': item,
        'netGrowth': netGrowth,
      };
    }).toList();

    // Sort by net growth ascending to find the "least growth" (most negative change)
    growthData.sort((a, b) => a['netGrowth'].compareTo(b['netGrowth']));

    // Get the top 5 students/groups with the least net growth to highlight
    Set<String> leastGrowthIds = {};
    for (int i = 0; i < math.min(5, growthData.length); i++) {
      leastGrowthIds.add((growthData[i]['item'] as StudentGroup).id!);
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report for Class: ${_sharedReport!.classId}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Generated: ${DateFormat('MMM dd,EEEE HH:mm').format(_sharedReport!.generatedAt.toLocal())}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _studentsInReport.isEmpty
          ? Center(child: Text('No students or groups found for class "${_sharedReport!.classId}".'))
          : ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _studentsInReport.length,
        itemBuilder: (context, index) {
          final item = _studentsInReport[index];
          // Check if the current item is one of the top 5 with least net growth
          final bool isLeastGrowth = leastGrowthIds.contains(item.id);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            color: isLeastGrowth ? Colors.red.shade100 : Colors.white, // Highlight least growth in red
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.name} (${item.isGroup ? "Group" : "Student"})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isLeastGrowth ? Colors.red.shade800 : Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current Score: ${item.score}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: item.score > 100
                          ? Colors.green.shade700
                          : item.score < 100
                          ? Colors.red.shade700
                          : Colors.black,
                    ),
                  ),
                  if (item.history.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recent Score History:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          // Display last 3 history entries, oldest first within this section
                          // Calculate change from previous entry and color based on it
                          ... (item.history.length > 3 ? item.history.sublist(item.history.length - 3) : item.history)
                              .map((entry) {
                            final int indexInFullHistory = item.history.indexOf(entry);
                            // Calculate change from previous entry (or assume 100 if it's the first entry)
                            final int previousScore = indexInFullHistory > 0 ? item.history[indexInFullHistory - 1].score : 100;
                            final int scoreChange = entry.score - previousScore;
                            final Color textColor = scoreChange < 0 ? Colors.red.shade700 : Colors.black; // Red for negative changes

                            final now = DateTime.now();
                            final ts = entry.timestamp.toLocal();
                            String timeString = TimeOfDay.fromDateTime(ts).format(context);
                            String dateString = (ts.day == now.day && ts.month == now.month && ts.year == now.year)
                                ? "today"
                                : DateFormat('dd/MM/yyyy').format(ts);
                            String reasonText = entry.reason != null && entry.reason!.isNotEmpty ? 'Reason: ${entry.reason}' : '';
                            String commentText = entry.customComment != null && entry.customComment!.isNotEmpty ? 'Comment: ${entry.customComment}' : '';
                            String separator = (reasonText.isNotEmpty && commentText.isNotEmpty) ? ', ' : '';

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                  "Score: ${entry.score} (Change: ${scoreChange > 0 ? '+' : ''}$scoreChange), Time: $timeString $dateString"
                                      "${reasonText.isNotEmpty ? ', $reasonText' : ''}"
                                      "${commentText.isNotEmpty ? '$separator$commentText' : ''}",
                                  style: TextStyle(fontSize: 13, color: textColor)),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
