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
  Set<String> _top5GrowthIds = {}; // For most positive net growth
  Set<String> _bottom5GrowthIds = {}; // For most negative net growth

  @override
  void initState() {
    super.initState();
    _fetchReportData(); // Start fetching data when the widget initializes
  }

  /// Fetches the shared report metadata and the associated student/group data from Firestore.
  /// Fetches the shared report metadata and the associated student/group data from Firestore.
  Future<void> _fetchReportData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _top5GrowthIds.clear(); // Clear previous highlights
      _bottom5GrowthIds.clear(); // Clear previous highlights
    });

    try {
      // 1. Fetch SharedReport metadata using the provided reportId
      // IMPORTANT: Use the hardcoded app ID 'scoretrackerapp-16051' for public data access
      // in the ReportViewerPage to ensure it can always find the reports.
      final reportDoc = await widget.firestore
          .collection('artifacts')
          .doc('scoretrackerapp-16051') // Hardcoded app ID for public reports
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
      print('DEBUG: Fetched Shared Report for Class ID (from report metadata): ${_sharedReport!.classId}'); // DEBUG PRINT: Report's class ID

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
          .doc('scoretrackerapp-16051') // Hardcoded app ID for public reports
          .collection('public')
          .doc('data')
          .collection('students');

      final QuerySnapshot<Map<String, dynamic>> studentDocs = await studentsRef
          .where('classId', isEqualTo: _sharedReport!.classId)
          .where('isArchived', isEqualTo: false)
      // Ensure this line is NOT present if you want all students: .where('isArchived', isEqualTo: false)
          .get();

      print('DEBUG: Query executed for class ID: ${_sharedReport!.classId}'); // DEBUG PRINT
      print('DEBUG: Number of raw student documents returned by Firestore: ${studentDocs.docs.length}'); // DEBUG PRINT

      // Convert fetched documents to StudentGroup objects with error handling
      final List<StudentGroup> fetchedAndMappedStudents = [];
      for (var doc in studentDocs.docs) {
        try {
          final student = StudentGroup.fromMap(doc.data(), id: doc.id);
          fetchedAndMappedStudents.add(student);
          print('DEBUG: Successfully mapped student: ${student.name} (ID: ${student.id}, Class: ${student.classId}, Archived: ${student.isArchived})'); // DEBUG PRINT
        } catch (e) {
          print('ERROR: Failed to map student document to StudentGroup. Document ID: ${doc.id}. Data: ${doc.data()}. Error: $e'); // CRITICAL DEBUG PRINT
        }
      }
      _studentsInReport = fetchedAndMappedStudents;


      print('DEBUG: Total StudentGroup objects successfully created and added to report: ${_studentsInReport.length}'); // DEBUG PRINT


      // --- Process growth data for highlighting ---
      _calculateGrowthHighlights(); // This will run on the now populated _studentsInReport

      // Sort students by current score descending for the main report display
      _studentsInReport.sort((a, b) => b.score.compareTo(a.score));

      print('DEBUG: Final _studentsInReport list (after sorting):'); // New Debug Print 1
      for (var student in _studentsInReport) {
        print('DEBUG:   - ${student.name} (ID: ${student.id}, Score: ${student.score}, Archived: ${student.isArchived})'); // New Debug Print 2
      }


      setState(() {
        _isLoading = false; // Data loaded successfully
      });
    } catch (e) {
      // Catch and display any errors during data fetching
      setState(() {
        _errorMessage = 'Error loading report: $e';
        _isLoading = false;
      });
      print('CRITICAL ERROR loading report: $e'); // Log error to console for debugging
    }
  }


  /// Calculates net growth for all students and identifies top/bottom 5 for highlighting.
  /// Calculates net growth for all students and identifies top/bottom 5 for highlighting.
  /// The 'bottom 5' will now specifically identify students with the most decrements.
  void _calculateGrowthHighlights() {
    _top5GrowthIds.clear();
    _bottom5GrowthIds.clear(); // This will now be for most decrements

    if (_studentsInReport.isEmpty) {
      print('No students in report to calculate growth highlights.');
      return;
    }

    // Create a temporary list of maps to hold student and their calculated metrics
    List<Map<String, dynamic>> allStudentsMetrics = _studentsInReport.map((item) {
      final metrics = item.calculateGrowthMetrics(); // Use the model's method
      return {
        'item': item,
        'netGrowth': metrics['netGrowth']!,
        'totalDecrement': metrics['totalDecrement']!, // Include totalDecrement for new logic
      };
    }).toList();

    print('Total students considered for growth calculation: ${allStudentsMetrics.length}');

    // Identify top 5 (most positive net growth) - remains the same
    List<Map<String, dynamic>> sortedByNetGrowth = List.from(allStudentsMetrics);
    sortedByNetGrowth.sort((a, b) => (b['netGrowth'] as int).compareTo(a['netGrowth'] as int)); // Sort descending by net growth
    _top5GrowthIds = sortedByNetGrowth.take(5).map((e) => (e['item'] as StudentGroup).id!).toSet();
    print('Top 5 Increased Growth IDs (by Net Growth): $_top5GrowthIds (Count: ${_top5GrowthIds.length})');

    // Identify bottom 5 (most decrements)
    List<Map<String, dynamic>> sortedByDecrement = List.from(allStudentsMetrics);
    // Sort by 'totalDecrement' in ASCENDING order.
    // Since totalDecrement is a negative value (e.g., -20 is more decrement than -5),
    // ascending order will bring the largest absolute negative values to the top.
    sortedByDecrement.sort((a, b) => (a['totalDecrement'] as int).compareTo(b['totalDecrement'] as int));
    _bottom5GrowthIds = sortedByDecrement.take(5).map((e) => (e['item'] as StudentGroup).id!).toSet();
    print('Bottom 5 IDs (by Most Decrements): $_bottom5GrowthIds (Count: ${_bottom5GrowthIds.length})');
  }


  /// Determines the background color for a DataRow based on net growth highlighting.
  Color? _getHighlightColor(StudentGroup item) {
    if (_top5GrowthIds.contains(item.id)) {
      return Colors.green[100]; // Light green for top 5 net growth (Increased)
    } else if (_bottom5GrowthIds.contains(item.id)) {
      return Colors.red[100]; // Light red for bottom 5 net growth (Decreased)
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
          : LayoutBuilder( // Use LayoutBuilder for responsive width for DataTable
        builder: (context, constraints) {
          // Determine a minimum width for the DataTable to ensure it's scrollable if needed
          // Calculate necessary width for all columns to prevent overflow
          final double studentNameColumnWidth = constraints.maxWidth * 0.3; // Approx 30% for name
          final double scoreColumnWidth = 100.0; // Fixed width for score
          final double netGrowthColumnWidth = 100.0; // Fixed width for net growth
          final double totalIncrementColumnWidth = 120.0; // Fixed width for total increment
          final double totalDecrementColumnWidth = 120.0; // Fixed width for total decrement

          final double totalCalculatedWidth =
              studentNameColumnWidth +
                  scoreColumnWidth +
                  netGrowthColumnWidth +
                  totalIncrementColumnWidth +
                  totalDecrementColumnWidth +
                  (25.0 * 4); // Sum of column spacings (4 gaps for 5 columns)

          final double minTableWidth = math.max(constraints.maxWidth, totalCalculatedWidth);

          return SingleChildScrollView( // This is the new VERTICAL SingleChildScrollView
            scrollDirection: Axis.vertical, // Explicitly set to vertical
            child: SingleChildScrollView( // This is the existing HORIZONTAL SingleChildScrollView
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minTableWidth), // Enforce minimum width
                child: DataTable(
                  columnSpacing: 25.0, // Increased column spacing for better readability
                  dataRowHeight: 48.0,
                  headingRowHeight: 56.0,
                  border: TableBorder.all(
                    color: Colors.grey[300]!,
                    borderRadius: BorderRadius.circular(8.0),
                    width: 1.0,
                  ),
                  headingRowColor: MaterialStateProperty.resolveWith<Color?>(
                        (Set<MaterialState> states) => Colors.grey[200], // Header background
                  ),
                  columns: const <DataColumn>[
                    DataColumn(
                      label: Expanded(
                        child: Text(
                          'Student/Group Name',
                          style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
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
                    DataColumn(
                      label: Text(
                        'Total Inc.',
                        style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'Total Dec.',
                        style: TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                  ],
                  rows: _studentsInReport.map((item) {
                    final metrics = item.calculateGrowthMetrics();
                    final int netGrowth = metrics['netGrowth']!;
                    final int totalIncrement = metrics['totalIncrement']!;
                    final int totalDecrement = metrics['totalDecrement']!;

                    return DataRow(
                      color: MaterialStateProperty.resolveWith<Color?>(
                            (Set<MaterialState> states) => _getHighlightColor(item),
                      ),
                      cells: <DataCell>[
                        DataCell(
                          Text(
                            '${item.name} (${item.isGroup ? "Group" : "Student"})',
                            style: TextStyle(
                              color: _getHighlightColor(item) != null ? Colors.black87 : Colors.indigo,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.score.toString(),
                            style: TextStyle(
                              color: _getHighlightColor(item) != null
                                  ? Colors.black87
                                  : (item.score > StudentGroup.fixedInitialScore
                                  ? Colors.green.shade700
                                  : (item.score < StudentGroup.fixedInitialScore
                                  ? Colors.red.shade700
                                  : Colors.black)),
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
                        DataCell(
                          Text(
                            '+${totalIncrement.toString()}',
                            style: TextStyle(
                              color: _getHighlightColor(item) != null ? Colors.black87 : Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            totalDecrement.toString(),
                            style: TextStyle(
                              color: _getHighlightColor(item) != null ? Colors.black87 : Colors.red.shade700,
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
        },
      ),
    );
  }
}
