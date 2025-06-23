import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smartassist/pages/navbar_page/call_logs.dart';
import 'package:smartassist/utils/storage.dart';

class CallAnalytics extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isFromSM;
  const CallAnalytics({
    super.key,
    required this.userId,
    this.isFromSM = false,
    required this.userName,
  });

  @override
  State<CallAnalytics> createState() => _CallAnalyticsState();
}

class _CallAnalyticsState extends State<CallAnalytics>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final List<String> tabTitles = ['Enquiry', 'Cold Calls'];

  String selectedTimeRange = '1D';
  int selectedTabIndex = 0;
  int touchedIndex = -1;
  int _childButtonIndex = 0;

  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _enquiryData;
  Map<String, dynamic>? _coldCallData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabTitles.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging == false) {
        setState(() {
          selectedTabIndex = _tabController.index;
          // No need to fetch data again as we already have both tab data
        });
      }
    });
    print('this is userid ${widget.userId}');
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final token = await Storage.getToken();

      // Determine period parameter based on selection
      String periodParam = '';
      switch (selectedTimeRange) {
        case '1D':
          periodParam = '?type=DAY';
          break;
        case '1W':
          periodParam = '?type=WEEK';
          break;
        case '1M':
          periodParam = '?type=MTD';
          break;
        case '1Q':
          periodParam = '?type=QTD';
          break;
        case '1Y':
          periodParam = '?type=YTD';
          break;
        default:
          periodParam = '?type=DAY';
      }

      late Uri uri;

      if (widget.isFromSM) {
        uri = Uri.parse(
          // 'https://api.smartassistapp.in/api/users/ps/dashboard/call-analytics$periodParam'?user_id=${widget.userId},
          'https://api.smartassistapp.in/api/users/ps/dashboard/call-analytics$periodParam&user_id=${widget.userId}',
        );
      } else {
        uri = Uri.parse(
          'https://api.smartassistapp.in/api/users/ps/dashboard/call-analytics$periodParam',
        );
      }

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print(uri);
      print(response.body);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        // Check if the widget is still in the widget tree before calling setState
        if (mounted) {
          setState(() {
            _dashboardData = jsonData['data'];
            _enquiryData = jsonData['data']['summaryEnquiry'];
            _coldCallData = jsonData['data']['summaryColdCalls'];
            _isLoading = false;
          });
        }
      } else {
        // Handle unsuccessful status codes
        throw Exception(
          'Failed to load dashboard data. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Check if the widget is still in the widget tree before calling setState
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // Handle different types of errors
      if (e is http.ClientException) {
        debugPrint('Network error: $e');
      } else if (e is FormatException) {
        debugPrint('Error parsing data: $e');
      } else {
        debugPrint('Unexpected error: $e');
      }
    }
  }

  void _updateSelectedTimeRange(String range) {
    setState(() {
      selectedTimeRange = range;
      // Fetch data when time range changes
      _fetchDashboardData();
    });
  }

  void _updateSelectedTab(int index) {
    setState(() {
      selectedTabIndex = index;
      _tabController.animateTo(index);
    });
  }

  // Get current data based on selected tab
  Map<String, dynamic> get currentTabData {
    if (_dashboardData == null) {
      return {};
    }
    return selectedTabIndex == 0 ? _enquiryData ?? {} : _coldCallData ?? {};
  }

  // Get summary data based on selected tab
  Map<String, dynamic> get summarySectionData {
    if (currentTabData.isEmpty) {
      return {};
    }
    return currentTabData['summary'] ?? {};
  }

  // Get hourly analysis data based on selected tab
  Map<String, dynamic> get hourlyAnalysisData {
    if (currentTabData.isEmpty) {
      return {};
    }
    return currentTabData['hourlyAnalysis'] ?? {};
  }

  // Helper method to get responsive dimensions
  bool get _isTablet => MediaQuery.of(context).size.width > 768;
  bool get _isSmallScreen => MediaQuery.of(context).size.width < 400;
  double get _screenWidth => MediaQuery.of(context).size.width;
  double get _screenHeight => MediaQuery.of(context).size.height;

  // Responsive padding
  EdgeInsets get _responsivePadding => EdgeInsets.symmetric(
    horizontal: _isTablet ? 20 : (_isSmallScreen ? 8 : 10),
    vertical: _isTablet ? 12 : 8,
  );

  // Responsive font sizes
  double get _titleFontSize => _isTablet ? 20 : (_isSmallScreen ? 16 : 18);
  double get _bodyFontSize => _isTablet ? 16 : (_isSmallScreen ? 12 : 14);
  double get _smallFontSize => _isTablet ? 14 : (_isSmallScreen ? 10 : 12);

  // Generate table rows based on API data for the selected tab
  List<List<Widget>> get tableData {
    List<List<Widget>> data = [];
    final summary = summarySectionData;

    // Always show these rows even if data is empty
    // Add All Calls row
    data.add([
      Row(
        children: [
          Icon(
            Icons.call,
            size: _isSmallScreen ? 14 : 16,
            color: AppColors.colorsBlue,
          ),
          SizedBox(width: _isSmallScreen ? 4 : 6),
          Flexible(
            child: Text(
              'All Calls',
              style: TextStyle(fontSize: _smallFontSize),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      Text(
        summary.containsKey('All Calls')
            ? summary['All Calls']['calls']?.toString() ?? '0'
            : '0',
        style: TextStyle(fontSize: _smallFontSize),
      ),
      Text(
        summary.containsKey('All Calls')
            ? summary['All Calls']['duration']?.toString() ?? '0'
            : '0',
        style: TextStyle(fontSize: _smallFontSize),
      ),
      Text(
        summary.containsKey('All Calls')
            ? summary['All Calls']['uniqueClients']?.toString() ?? '0'
            : '0',
        style: TextStyle(fontSize: _smallFontSize),
      ),
    ]);

    // Add Connected row
    data.add([
      Row(
        children: [
          Icon(Icons.call, size: _isSmallScreen ? 14 : 16, color: Colors.green),
          SizedBox(width: _isSmallScreen ? 4 : 6),
          Flexible(
            child: Text(
              'Connected',
              style: TextStyle(fontSize: _smallFontSize),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      Text(
        summary.containsKey('Connected')
            ? summary['Connected']['calls']?.toString() ?? '0'
            : '0',
        style: TextStyle(fontSize: _smallFontSize),
      ),
      Text(
        summary.containsKey('Connected')
            ? summary['Connected']['duration']?.toString() ?? '0'
            : '0',
        style: TextStyle(fontSize: _smallFontSize),
      ),
      Text(
        summary.containsKey('Connected')
            ? summary['Connected']['uniqueClients']?.toString() ?? '0'
            : '0',
        style: TextStyle(fontSize: _smallFontSize),
      ),
    ]);

    // Add Missed row
    data.add([
      Row(
        children: [
          Icon(
            Icons.call_missed,
            size: _isSmallScreen ? 14 : 16,
            color: Colors.redAccent,
          ),
          SizedBox(width: _isSmallScreen ? 4 : 6),
          Flexible(
            child: Text(
              'Missed',
              style: TextStyle(fontSize: _smallFontSize),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      Text(
        summary.containsKey('Missed')
            ? summary['Missed']['calls']?.toString() ?? '0'
            : '0',
        style: TextStyle(fontSize: _smallFontSize),
      ),
      Text(
        summary.containsKey('Missed')
            ? summary['Missed']['duration']?.toString() ?? '0'
            : '0',
        style: TextStyle(fontSize: _smallFontSize),
      ),
      Text(
        summary.containsKey('Missed')
            ? summary['Missed']['uniqueClients']?.toString() ?? '0'
            : '0',
        style: TextStyle(fontSize: _smallFontSize),
      ),
    ]);

    // Add Rejected row
    data.add([
      Row(
        children: [
          Icon(
            Icons.call_missed_outgoing_rounded,
            size: _isSmallScreen ? 14 : 16,
            color: Colors.redAccent,
          ),
          SizedBox(width: _isSmallScreen ? 4 : 6),
          Flexible(
            child: Text(
              'Rejected',
              style: TextStyle(fontSize: _smallFontSize),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      Text(
        summary.containsKey('Rejected')
            ? summary['Rejected']['calls']?.toString() ?? '0'
            : '0',
        style: TextStyle(fontSize: _smallFontSize),
      ),
      Text(
        summary.containsKey('Rejected')
            ? summary['Rejected']['duration']?.toString() ?? '0'
            : '0',
        style: TextStyle(fontSize: _smallFontSize),
      ),
      Text(
        summary.containsKey('Rejected')
            ? summary['Rejected']['uniqueClients']?.toString() ?? '0'
            : '0',
        style: TextStyle(fontSize: _smallFontSize),
      ),
    ]);

    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            FontAwesomeIcons.angleLeft,
            color: Colors.white,
            size: _isSmallScreen ? 18 : 20,
          ),
        ),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            widget.isFromSM ? widget.userName : 'Call Analysis',
            style: GoogleFonts.poppins(
              fontSize: _titleFontSize,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: AppColors.colorsBlue,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        children: [
                          _buildTabBar(),
                          _buildUserStatsCard(),
                          SizedBox(height: _isTablet ? 20 : 16),
                          _buildCallsSummary(),
                          SizedBox(height: _isTablet ? 20 : 16),
                          _buildHourlyAnalysis(),
                          // Add bottom padding for FAB on smaller screens
                          if (!widget.isFromSM && !_isTablet)
                            const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: !widget.isFromSM
          ? Container(
              width: _isTablet ? 150 : (_isSmallScreen ? 100 : 120),
              height: _isTablet ? 60 : (_isSmallScreen ? 45 : 56),
              child: FloatingActionButton(
                backgroundColor: AppColors.colorsBlue,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CallLogs()),
                  );
                },
                tooltip: 'Exclude your numbers..',
                child: Text(
                  'Exclude',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _isTablet ? 14 : (_isSmallScreen ? 14 : 16),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: _isTablet
          ? FloatingActionButtonLocation.endFloat
          : FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildTimeFilterRow() {
    final timeRanges = ['1D', '1W', '1M', '1Q', '1Y'];
    double filterWidth = _isTablet ? 250 : (_isSmallScreen ? 180 : 200);

    return Padding(
      padding: EdgeInsets.only(
        top: 5,
        bottom: 10,
        left: _responsivePadding.left,
        right: _responsivePadding.right,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: filterWidth,
          height: _isTablet ? 35 : (_isSmallScreen ? 28 : 30),
          decoration: BoxDecoration(
            color: AppColors.backgroundLightGrey,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              for (final range in timeRanges)
                Expanded(
                  child: _buildTimeFilterChip(
                    range,
                    range == selectedTimeRange,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeFilterChip(String label, bool isActive) {
    return GestureDetector(
      onTap: () => _updateSelectedTimeRange(label),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _isSmallScreen ? 3 : 5,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? AppColors.colorsBlue : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: isActive ? AppColors.colorsBlue : AppColors.fontColor,
            fontSize: _isTablet ? 16 : (_isSmallScreen ? 11 : 14),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildUserStatsCard() {
    return Container(
      margin: _responsivePadding,
      padding: EdgeInsets.all(_isTablet ? 16 : (_isSmallScreen ? 8 : 10)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeFilterRow(),
          SizedBox(height: _isTablet ? 20 : 16),

          // Responsive stats layout
          _isTablet
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _buildStatBox(
                        currentTabData['totalConnected']?.toString() ?? '0',
                        'Total\nConnected',
                        Colors.green,
                        Icons.call,
                      ),
                    ),
                    _buildVerticalDivider(60),
                    Expanded(
                      child: _buildStatBox(
                        currentTabData['conversationTime']?.toString() ?? '0',
                        'Conversation\ntime',
                        AppColors.colorsBlue,
                        Icons.access_time,
                      ),
                    ),
                    _buildVerticalDivider(60),
                    Expanded(
                      child: _buildStatBox(
                        currentTabData['notConnected']?.toString() ?? '0',
                        'Not\nConnected',
                        Colors.red,
                        Icons.call_missed,
                      ),
                    ),
                  ],
                )
              : _isSmallScreen
              ? Column(
                  children: [
                    _buildStatBox(
                      currentTabData['totalConnected']?.toString() ?? '0',
                      'Total Connected',
                      Colors.green,
                      Icons.call,
                    ),
                    const SizedBox(height: 12),
                    _buildStatBox(
                      currentTabData['conversationTime']?.toString() ?? '0',
                      'Conversation time',
                      AppColors.colorsBlue,
                      Icons.access_time,
                    ),
                    const SizedBox(height: 12),
                    _buildStatBox(
                      currentTabData['notConnected']?.toString() ?? '0',
                      'Not Connected',
                      Colors.red,
                      Icons.call_missed,
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatBox(
                      currentTabData['totalConnected']?.toString() ?? '0',
                      'Total\nConnected',
                      Colors.green,
                      Icons.call,
                    ),
                    _buildVerticalDivider(50),
                    _buildStatBox(
                      currentTabData['conversationTime']?.toString() ?? '0',
                      'Conversation\ntime',
                      AppColors.colorsBlue,
                      Icons.access_time,
                    ),
                    _buildVerticalDivider(50),
                    _buildStatBox(
                      currentTabData['notConnected']?.toString() ?? '0',
                      'Not\nConnected',
                      Colors.red,
                      Icons.call_missed,
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, String label, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: _isSmallScreen
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: _isTablet ? 28 : (_isSmallScreen ? 20 : 24),
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(width: _isSmallScreen ? 2 : 3),
            Icon(
              icon,
              color: color,
              size: _isTablet ? 24 : (_isSmallScreen ? 16 : 20),
            ),
          ],
        ),
        SizedBox(height: _isTablet ? 12 : 10),
        Text(
          label,
          style: TextStyle(fontSize: _smallFontSize, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(double height) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: _isSmallScreen ? 3 : 5),
      height: height,
      width: 0.1,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.backgroundLightGrey)),
      ),
    );
  }

  Widget _buildCallsSummary() {
    return Container(
      margin: _responsivePadding,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [_buildAnalyticsTable()]),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: _isTablet ? 40 : (_isSmallScreen ? 25 : 30),
      padding: EdgeInsets.zero,
      margin: EdgeInsets.symmetric(
        horizontal: _responsivePadding.horizontal,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundLightGrey,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          for (int i = 0; i < tabTitles.length; i++)
            Expanded(child: _buildTab(tabTitles[i], i == selectedTabIndex, i)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTable() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(10.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _buildTableContent();
  }

  Widget _buildTableContent() {
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        horizontalInside: BorderSide(
          color: Colors.grey.withOpacity(0.3),
          width: 0.6,
        ),
        verticalInside: BorderSide.none,
      ),
      columnWidths: _isTablet
          ? {
              0: const FlexColumnWidth(2.5), // Metric
              1: const FlexColumnWidth(1.5), // Calls
              2: const FlexColumnWidth(1.5), // Duration
              3: const FlexColumnWidth(2), // Unique client
            }
          : _isSmallScreen
          ? {
              0: const FlexColumnWidth(2), // Metric
              1: const FlexColumnWidth(1), // Calls
              2: const FlexColumnWidth(1), // Duration
              3: const FlexColumnWidth(1.3), // Unique client
            }
          : {
              0: const FlexColumnWidth(2.2), // Metric
              1: const FlexColumnWidth(1.3), // Calls
              2: const FlexColumnWidth(1.3), // Duration
              3: const FlexColumnWidth(1.5), // Unique client
            },
      children: [
        TableRow(
          children: [
            const SizedBox(), // Empty cell
            Container(
              margin: EdgeInsets.only(
                bottom: 10,
                top: 10,
                left: _isSmallScreen ? 2 : 5,
              ),
              child: Text(
                'Calls',
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: _smallFontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(
                bottom: 10,
                top: 10,
                left: _isSmallScreen ? 2 : 5,
              ),
              child: Text(
                'Duration',
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: _smallFontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(
                bottom: 10,
                top: 10,
                right: _isSmallScreen ? 2 : 5,
                left: _isSmallScreen ? 2 : 5,
              ),
              child: Text(
                _isSmallScreen ? 'Clients' : 'Unique client',
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: _smallFontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
        ...tableData.map((row) => _buildTableRow(row)).toList(),
      ],
    );
  }

  Widget _buildTab(String label, bool isActive, int index) {
    return GestureDetector(
      onTap: () => _updateSelectedTab(index),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 0,
          vertical: _isSmallScreen ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.colorsBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: isActive ? Colors.white : AppColors.colorsBlue,
            fontSize: _isTablet ? 14 : (_isSmallScreen ? 14 : 16),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHourlyAnalysis() {
    return Container(
      margin: _responsivePadding,
      padding: EdgeInsets.all(_isTablet ? 16 : (_isSmallScreen ? 8 : 10)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hourly Analysis',
            style: TextStyle(
              fontSize: _bodyFontSize,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: _isTablet ? 15 : 10),
          _buildCallStatsRows(),
          SizedBox(height: _isTablet ? 15 : 10),
          SizedBox(
            height: _isTablet ? 300 : (_isSmallScreen ? 180 : 200),
            child: _buildCombinedBarChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildCallStatsRows() {
    // Calculate totals from hourly analysis data
    int allCalls = 0;
    String allCallsDuration = "0m";
    int incomingCalls = 0;
    String incomingDuration = "0m";
    int missedCalls = 0;
    String missedDuration = "";

    // Sum up the calls and durations from hourly data
    hourlyAnalysisData.forEach((hour, data) {
      if (data['AllCalls'] != null) {
        allCalls += (data['AllCalls']['calls'] as num?)?.toInt() ?? 0;
        allCallsDuration = data['AllCalls']['duration'] ?? "0m";
      }

      // Connected calls (treating as incoming for now)
      if (data['Connected'] != null) {
        incomingCalls += (data['Connected']['calls'] as num?)?.toInt() ?? 0;
        incomingDuration = data['Connected']['duration']?.toString() ?? "0m";
      }

      // Missed calls
      if (data['missedCalls'] != null) {
        missedCalls = data['missedCalls'] as int;
      }
    });

    return Container(
      padding: EdgeInsets.all(_isTablet ? 16 : (_isSmallScreen ? 8 : 10)),
      decoration: BoxDecoration(
        color: AppColors.backgroundLightGrey,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _buildCallStatRow('All calls', allCalls.toString(), allCallsDuration),
          _buildCallStatRow(
            'Connected',
            incomingCalls.toString(),
            incomingDuration,
          ),
          _buildCallStatRow(
            'Missed calls',
            missedCalls.toString(),
            missedDuration,
          ),
        ],
      ),
    );
  }

  Widget _buildCallStatRow(String label, String count, String duration) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppFont.smallText10(context))),
          Text(count, style: AppFont.smallText12(context)),
          const SizedBox(width: 12),
          Text(
            duration,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // Combined chart method
  Widget _buildCombinedBarChart() {
    return Column(
      children: [
        // Legend for the chart
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('All Calls', Color(0xFF1380FE)),
              const SizedBox(width: 16),
              _buildLegendItem('Incoming', Colors.green),
              const SizedBox(width: 16),
              _buildLegendItem('Outgoing', Colors.orange),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Combined chart
        Expanded(child: _buildCombinedLineChart()),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildCombinedLineChart() {
    // Process hourly analysis data to create chart spots
    final List<FlSpot> allCallSpots = [];
    final List<FlSpot> incomingSpots = []; // Renamed from connected
    final List<FlSpot> outgoingSpots = []; // Added for Outgoing

    // Process data to create chart spots
    final List<int> sortedHours =
        hourlyAnalysisData.keys.map((e) => int.parse(e)).toList()..sort();

    for (int i = 0; i < sortedHours.length; i++) {
      final hour = sortedHours[i].toString();
      final data = hourlyAnalysisData[hour];

      if (data != null) {
        final double xValue = i.toDouble(); // Use index directly for x-value

        if (data['AllCalls'] != null) {
          allCallSpots.add(
            FlSpot(xValue, (data['AllCalls']['calls'] ?? 0).toDouble()),
          );
        }
        if (data['incoming'] != null) {
          // Updated key
          incomingSpots.add(
            FlSpot(xValue, (data['incoming']['calls'] ?? 0).toDouble()),
          );
        }
        if (data['outgoing'] != null) {
          // Added key
          outgoingSpots.add(
            FlSpot(xValue, (data['outgoing']['calls'] ?? 0).toDouble()),
          );
        }
      }
    }

    // If no data points, create default ones
    if (allCallSpots.isEmpty) {
      for (int hour = 1; hour <= 12; hour++) {
        allCallSpots.add(FlSpot(hour.toDouble() - 1, 0));
      }
    }
    if (incomingSpots.isEmpty) {
      for (int hour = 1; hour <= 12; hour++) {
        incomingSpots.add(FlSpot(hour.toDouble() - 1, 0));
      }
    }
    if (outgoingSpots.isEmpty) {
      for (int hour = 1; hour <= 12; hour++) {
        outgoingSpots.add(FlSpot(hour.toDouble() - 1, 0));
      }
    }

    // Find max Y value for the chart
    double maxY = [
      allCallSpots,
      incomingSpots,
      outgoingSpots,
    ].expand((e) => e).map((e) => e.y).reduce((a, b) => a > b ? a : b);
    maxY = maxY < 1200 ? 1200 : maxY + 200; // Adjust for 1117 total calls

    // Find max X value
    double maxX = sortedHours.isEmpty ? 11 : sortedHours.length - 1.toDouble();
    maxX = maxX < 12 ? 12 : maxX + 1;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  String callType = [
                    'All Calls',
                    'Incoming',
                    'Outgoing',
                  ][spot.barIndex];
                  return LineTooltipItem(
                    '$callType: ${spot.y.toInt()} calls',
                    const TextStyle(color: Colors.white),
                  );
                }).toList();
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return _getBottomTitleWidget(value, meta, sortedHours);
                },
                reservedSize: 28,
                interval: 1,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return _getLeftTitleWidget(value, meta, maxY);
                },
                reservedSize: 60, // Increased to prevent overlap
                interval: _getYAxisInterval(maxY, selectedTimeRange),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            drawVerticalLine: true,
            horizontalInterval: _getYAxisInterval(maxY, selectedTimeRange),
            verticalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          minX: 0,
          maxX: maxX,
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: allCallSpots,
              isCurved: true,
              color: AppColors.colorsBlue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.2),
              ),
            ),
            LineChartBarData(
              spots: incomingSpots,
              isCurved: true,
              color: Colors.green,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withOpacity(0.2),
              ),
            ),
            LineChartBarData(
              spots: outgoingSpots,
              isCurved: true,
              color: Colors.orange,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.orange.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Updated _getYAxisInterval to handle larger values
  double _getYAxisInterval(double maxY, String timeRange) {
    if (maxY > 1000) return 200; // Larger interval for high values
    switch (timeRange) {
      case '1D':
        return maxY > 20 ? 5 : (maxY > 10 ? 2 : 1);
      case '1W':
        return maxY > 14 ? 3 : 2;
      case '1M':
        return maxY > 16 ? 4 : 2;
      case '1Q':
        return maxY > 9 ? 3 : 1;
      case '1Y':
        return maxY > 24 ? 6 : 3;
      default:
        return maxY > 10 ? 5 : 1;
    }
  }

  // Helper method for bottom titles (X-axis)
  Widget _getBottomTitleWidget(
    double value,
    TitleMeta meta,
    List<int> sortedHours,
  ) {
    final int index = value ~/ 2;
    final style = TextStyle(color: Colors.grey, fontSize: 10);

    if (index < sortedHours.length) {
      String label = _getXAxisLabel(sortedHours[index], selectedTimeRange);
      return SideTitleWidget(
        space: 8,
        child: Text(label, style: style),
        meta: meta,
      );
    }

    return SideTitleWidget(
      space: 8,
      child: Text('', style: style),
      meta: meta,
    );
  }

  // Helper method for left titles (Y-axis)
  Widget _getLeftTitleWidget(double value, TitleMeta meta, double maxY) {
    if (value == 0) {
      return const SizedBox();
    }

    String label = _getYAxisLabel(value, selectedTimeRange, maxY);

    return SideTitleWidget(
      space: 8,
      child: Text(
        label,
        style: const TextStyle(color: Colors.grey, fontSize: 9),
        textAlign: TextAlign.center,
      ),
      meta: meta,
    );
  }

  // Helper method to get X-axis labels based on time range
  String _getXAxisLabel(int hour, String timeRange) {
    switch (timeRange) {
      case '1D':
        // Show hours in 12-hour format
        String period = hour >= 12 ? 'PM' : 'AM';
        int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$displayHour$period';

      case '1W':
        // Show hours for weekly view
        String period = hour >= 12 ? 'PM' : 'AM';
        int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$displayHour$period';

      case '1M':
        // Show hours for monthly view
        String period = hour >= 12 ? 'PM' : 'AM';
        int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$displayHour$period';

      case '1Q':
        // Show hours for quarterly view
        String period = hour >= 12 ? 'PM' : 'AM';
        int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$displayHour$period';

      case '1Y':
        // Show hours for yearly view
        String period = hour >= 12 ? 'PM' : 'AM';
        int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$displayHour$period';

      default:
        return '${hour}H';
    }
  }

  // Helper method to get Y-axis labels with contextual information
  String _getYAxisLabel(double value, String timeRange, double maxY) {
    int intValue = value.toInt();

    switch (timeRange) {
      case '1D':
        return intValue.toString();

      case '1W':
        // Add day context for weekly view
        if (intValue > 0) {
          double ratio = value / maxY;
          if (ratio >= 0.8) return 'Sun\n$intValue';
          if (ratio >= 0.7) return 'Sat\n$intValue';
          if (ratio >= 0.6) return 'Fri\n$intValue';
          if (ratio >= 0.5) return 'Thu\n$intValue';
          if (ratio >= 0.4) return 'Wed\n$intValue';
          if (ratio >= 0.3) return 'Tue\n$intValue';
          if (ratio >= 0.2) return 'Mon\n$intValue';
        }
        return intValue.toString();

      case '1M':
        // Add week context for monthly view
        if (intValue > 0) {
          double ratio = value / maxY;
          if (ratio >= 0.75) return 'W4\n$intValue';
          if (ratio >= 0.5) return 'W3\n$intValue';
          if (ratio >= 0.25) return 'W2\n$intValue';
          if (ratio > 0) return 'W1\n$intValue';
        }
        return intValue.toString();

      case '1Q':
        // Add month context for quarterly view
        if (intValue > 0) {
          double ratio = value / maxY;
          if (ratio >= 0.67) return 'Mar\n$intValue';
          if (ratio >= 0.33) return 'Feb\n$intValue';
          if (ratio > 0) return 'Jan\n$intValue';
        }
        return intValue.toString();

      case '1Y':
        // Add month context for yearly view
        if (intValue > 0) {
          double ratio = value / maxY;
          const months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
          int monthIndex = (ratio * 12).floor();
          if (monthIndex >= 0 && monthIndex < months.length) {
            return '${months[monthIndex]}\n$intValue';
          }
        }
        return intValue.toString();

      default:
        return intValue.toString();
    }
  }

  // Helper method to get appropriate interval based on time range
  // Widget _buildCombinedLineChart() {
  //   // Process hourly analysis data to create chart spots
  //   final List<FlSpot> allCallSpots = [];
  //   final List<FlSpot> connectedSpots = [];
  //   final List<FlSpot> missedSpots = [];

  //   // Process data to create chart spots
  //   // Sort keys to ensure hours are in order
  //   final List<int> sortedHours =
  //       hourlyAnalysisData.keys.map((e) => int.parse(e)).toList()..sort();

  //   for (int i = 0; i < sortedHours.length; i++) {
  //     final hour = sortedHours[i].toString();
  //     final data = hourlyAnalysisData[hour];

  //     if (data != null) {
  //       final double xValue = i.toDouble() * 2; // Spread out the x values

  //       // All calls
  //       if (data['AllCalls'] != null) {
  //         allCallSpots.add(
  //           FlSpot(xValue, (data['AllCalls']['calls'] ?? 0).toDouble()),
  //         );
  //       }

  //       // Connected calls
  //       if (data['connected'] != null) {
  //         connectedSpots.add(
  //           FlSpot(xValue, (data['connected']['calls'] ?? 0).toDouble()),
  //         );
  //       }

  //       // Missed calls
  //       if (data['missedCalls'] != null) {
  //         missedSpots.add(
  //           FlSpot(xValue, (data['missedCalls'] as int).toDouble()),
  //         );
  //       }
  //     }
  //   }

  //   // If no data points, create default ones
  //   if (allCallSpots.isEmpty) {
  //     allCallSpots.add(const FlSpot(0, 0));
  //     allCallSpots.add(const FlSpot(2, 0));
  //   }
  //   if (connectedSpots.isEmpty) {
  //     connectedSpots.add(const FlSpot(0, 0));
  //     connectedSpots.add(const FlSpot(2, 0));
  //   }
  //   if (missedSpots.isEmpty) {
  //     missedSpots.add(const FlSpot(0, 0));
  //     missedSpots.add(const FlSpot(2, 0));
  //   }

  //   // Find max Y value for the chart
  //   double maxY = 0;
  //   for (var spot in [...allCallSpots, ...connectedSpots, ...missedSpots]) {
  //     if (spot.y > maxY) maxY = spot.y;
  //   }
  //   maxY = maxY < 5 ? 5 : (maxY.ceil() + 2); // Add some padding to the max Y

  //   // Find max X value
  //   double maxX = 0;
  //   for (var spot in [...allCallSpots, ...connectedSpots, ...missedSpots]) {
  //     if (spot.x > maxX) maxX = spot.x;
  //   }
  //   maxX = maxX < 2 ? 12 : maxX + 2; // Ensure minimum width and add padding

  //   return Padding(
  //     padding: const EdgeInsets.only(top: 10),
  //     child: LineChart(
  //       LineChartData(
  //         lineTouchData: LineTouchData(
  //           touchTooltipData: LineTouchTooltipData(
  //             getTooltipItems: (List<LineBarSpot> touchedSpots) {
  //               return touchedSpots.map((spot) {
  //                 String callType = '';
  //                 if (spot.barIndex == 0) {
  //                   callType = 'All Calls';
  //                 } else if (spot.barIndex == 1) {
  //                   callType = 'Connected';
  //                 } else {
  //                   callType = 'Missed';
  //                 }
  //                 return LineTooltipItem(
  //                   '$callType: ${spot.y.toInt()} calls',
  //                   const TextStyle(color: Colors.white),
  //                 );
  //               }).toList();
  //             },
  //           ),
  //         ),
  //         titlesData: FlTitlesData(
  //           show: true,
  //           bottomTitles: AxisTitles(
  //             sideTitles: SideTitles(
  //               showTitles: true,
  //               getTitlesWidget: (double value, TitleMeta meta) {
  //                 // Use hourly analysis keys for X axis
  //                 final int index = value ~/ 2;
  //                 final style = TextStyle(color: Colors.grey, fontSize: 10);

  //                 if (index < sortedHours.length) {
  //                   // Convert 24-hour to 12-hour format
  //                   int hour = sortedHours[index];
  //                   String period = hour >= 12 ? 'PM' : 'AM';
  //                   hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
  //                   return SideTitleWidget(
  //                     space: 8,
  //                     child: Text('$hour$period', style: style),
  //                     meta: meta,
  //                   );
  //                 }
  //                 return SideTitleWidget(
  //                   space: 8,
  //                   child: Text('', style: style),
  //                   meta: meta,
  //                 );
  //               },
  //               reservedSize: 28,
  //               interval: 2,
  //             ),
  //           ),
  //           leftTitles: AxisTitles(
  //             sideTitles: SideTitles(
  //               showTitles: true,
  //               getTitlesWidget: (double value, TitleMeta meta) {
  //                 if (value == 0) {
  //                   return const SizedBox();
  //                 }
  //                 return SideTitleWidget(
  //                   space: 8,
  //                   child: Text(
  //                     value.toInt().toString(),
  //                     style: const TextStyle(color: Colors.grey, fontSize: 10),
  //                   ),
  //                   meta: meta,
  //                 );
  //               },
  //               reservedSize: 28,
  //               interval: maxY > 10 ? 5 : 1,
  //             ),
  //           ),
  //           topTitles: const AxisTitles(
  //             sideTitles: SideTitles(showTitles: false),
  //           ),
  //           rightTitles: const AxisTitles(
  //             sideTitles: SideTitles(showTitles: false),
  //           ),
  //         ),
  //         borderData: FlBorderData(show: false),
  //         gridData: FlGridData(
  //           show: true,
  //           drawHorizontalLine: true,
  //           drawVerticalLine: true,
  //           horizontalInterval: maxY > 10 ? 5 : 1,
  //           verticalInterval: 2,
  //           getDrawingHorizontalLine: (value) {
  //             return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
  //           },
  //           getDrawingVerticalLine: (value) {
  //             return FlLine(
  //               color: Colors.grey.shade200,
  //               strokeWidth: 1,
  //               dashArray: [5, 5],
  //             );
  //           },
  //         ),
  //         minX: 0,
  //         maxX: maxX,
  //         minY: 0,
  //         maxY: maxY,
  //         lineBarsData: [
  //           // All Calls Line
  //           LineChartBarData(
  //             spots: allCallSpots,
  //             isCurved: true,
  //             color: AppColors.colorsBlue,
  //             barWidth: 3,
  //             isStrokeCapRound: true,
  //             dotData: const FlDotData(show: true),
  //             belowBarData: BarAreaData(
  //               show: true,
  //               color: Colors.blue.withOpacity(0.2),
  //             ),
  //           ),
  //           // Connected Calls Line
  //           LineChartBarData(
  //             spots: connectedSpots,
  //             isCurved: true,
  //             color: Colors.green,
  //             barWidth: 3,
  //             isStrokeCapRound: true,
  //             dotData: const FlDotData(show: true),
  //             belowBarData: BarAreaData(
  //               show: true,
  //               color: Colors.green.withOpacity(0.2),
  //             ),
  //           ),
  //           // Missed Calls Line (using orange for the outgoing slot)
  //           LineChartBarData(
  //             spots: missedSpots,
  //             isCurved: true,
  //             color: Colors.orange,
  //             barWidth: 3,
  //             isStrokeCapRound: true,
  //             dotData: const FlDotData(show: true),
  //             belowBarData: BarAreaData(
  //               show: true,
  //               color: Colors.orange.withOpacity(0.2),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  TableRow _buildTableRow(List<Widget> widgets) {
    return TableRow(
      children: widgets.map((widget) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 5.0),
          child: widget, // Use the widget directly here
        );
      }).toList(),
    );
  }
}
