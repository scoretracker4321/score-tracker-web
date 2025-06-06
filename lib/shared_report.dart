import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull extension
import 'dart:math' as math; // Import for 'math'

// Import models
import 'models.dart'; // Contains StudentGroup, ScoreHistoryEntry, SharedReport models

/// A StatefulWidget that displays a shared report for a specific class.
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

  // Sets to store IDs of students/groups for highlighting
  Set<String> _top5GrowthIds = {};
  Set<String> _bottom5GrowthIds = {};

  @override
  void initState() {
    super.initState();
    _fetchReportData(); // Start fetching data when the widget initializes
  }

  /// Fetches the shared report metadata and the associated student/group data from Firestore.
  Future<void> _fetchReportData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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

      // --- Process growth data for highlighting ---
      _calculateGrowthHighlights();

      // Sort students by current score descending for the main report display
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

  /// Calculates net growth for all students and identifies top/bottom 5 for highlighting.
  void _calculateGrowthHighlights() {
    if (_studentsInReport.isEmpty) {
      _top5GrowthIds.clear();
      _bottom5GrowthIds.clear();
      return;
    }

    // Create a temporary list of maps to hold student and their calculated net growth
    List<Map<String, dynamic>> tempGrowthData = _studentsInReport.map((item) {
      // Assuming history is oldest to newest, so first entry is initial state
      final int initialScore = item.history.isNotEmpty ? item.history.first.score : item.score;
      final int netGrowth = item.score - initialScore;
      return {'item': item, 'netGrowth': netGrowth};
    }).toList();

    // Identify top 5 (most positive net growth)
    tempGrowthData.sort((a, b) => (b['netGrowth'] as int).compareTo(a['netGrowth'] as int)); // Sort descending
    _top5GrowthIds.clear();
    for (int i = 0; i < math.min(5, tempGrowthData.length); i++) {
      _top5GrowthIds.add((tempGrowthData[i]['item'] as StudentGroup).id!);
    }

    // Identify bottom 5 (most negative net growth)
    // Re-sort ascending for bottom 5
    tempGrowthData.sort((a, b) => (a['netGrowth'] as int).compareTo(b['netGrowth'] as int)); // Sort ascending
    _bottom5GrowthIds.clear();
    for (int i = 0; i < math.min(5, tempGrowthData.length); i++) {
      _bottom5GrowthIds.add((tempGrowthData[i]['item'] as StudentGroup).id!);
    }
  }

  /// Determines the background color for a DataRow based on net growth highlighting.
  Color? _getHighlightColor(StudentGroup item) {
    if (_top5GrowthIds.contains(item.id)) {
      return Colors.green[100]; // Light green for top 5 net growth
    } else if (_bottom5GrowthIds.contains(item.id)) {
      return Colors.red[100]; // Light red for bottom 5 net growth
    }
    return null; // No highlight
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
              'Generated: ${DateFormat('MMM dd, EEEE HH:mm').format(_sharedReport!.generatedAt.toLocal())}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _studentsInReport.isEmpty
          ? Center(child: Text('No students or groups found for class "${_sharedReport!.classId}".'))
          : SingleChildScrollView(
        scrollDirection: Axis.horizontal, // Allows horizontal scrolling for wide tables
        child: ConstrainedBox( // Ensures DataTable takes minimum width if needed
          constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
          child: DataTable(
            columnSpacing: 20.0,
            dataRowHeight: 48.0,
            headingRowHeight: 56.0,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8.0),
            ),
            headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) => Colors.grey[200], // Header background
            ),
            columns: const <DataColumn>[
              DataColumn(
                label: Text(
                  'Player Name',
                  style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Total Score',
                  style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                ),
                numeric: true,
              ),
              DataColumn(
                label: Text(
                  'Net Growth',
                  style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                ),
                numeric: true,
              ),
            ],
            rows: _studentsInReport.map((item) {
              final int initialScore = item.history.isNotEmpty ? item.history.first.score : item.score;
              final int netGrowth = item.score - initialScore;

              return DataRow(
                color: MaterialStateProperty.resolveWith<Color?>(
                      (Set<MaterialState> states) => _getHighlightColor(item),
                ),
                cells: <DataCell>[
                  DataCell(
                    Text(
                      '${item.name} (${item.isGroup ? "Group" : "Student"})',
                      style: TextStyle(
                        color: _getHighlightColor(item) != null ? Colors.black87 : Colors.indigo, // Darker text on highlighted rows
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      item.score.toString(),
                      style: TextStyle(
                        color: _getHighlightColor(item) != null ? Colors.black87 : (item.score > 100 ? Colors.green.shade700 : (item.score < 100 ? Colors.red.shade700 : Colors.black)),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      netGrowth.toString(),
                      style: TextStyle(
                        color: _getHighlightColor(item) != null ? Colors.black87 : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
