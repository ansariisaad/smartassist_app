import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';

class TeamCalllogUserid extends StatefulWidget {
  final Map<String, dynamic>? dashboardData;
  final Map<String, dynamic>? enquiryData;
  final Map<String, dynamic>? coldCallData;
  const TeamCalllogUserid({
    super.key,
    required this.dashboardData,
    this.enquiryData,
    this.coldCallData,
  });

  @override
  State<TeamCalllogUserid> createState() => _TeamCalllogUseridState();
}

class _TeamCalllogUseridState extends State<TeamCalllogUserid>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final List<String> tabTitles = ['Enquiry', 'Cold Calls'];

  String selectedTimeRange = '1D';
  int selectedTabIndex = 0;
  int touchedIndex = -1;
  int _childButtonIndex = 0;

  bool _isLoading = true;

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
    // _fetchDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateSelectedTimeRange(String range) {
    setState(() {
      selectedTimeRange = range;
      // Fetch data when time range changes
      // _fetchDashboardData();
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
    if (widget.dashboardData == null) {
      return {};
    }
    return selectedTabIndex == 0
        ? widget.enquiryData ?? {}
        : widget.coldCallData ?? {};
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

  // Generate table rows based on API data for the selected tab
  List<List<Widget>> get tableData {
    List<List<Widget>> data = [];
    final summary = summarySectionData;

    // Always show these rows even if data is empty
    // Add All Calls row
    data.add([
      const Row(
        children: [
          Icon(Icons.call, size: 16, color: Colors.blue),
          SizedBox(width: 6),
          Text('All Calls'),
        ],
      ),
      Text(
        summary.containsKey('All Calls')
            ? summary['All Calls']['calls']?.toString() ?? '0'
            : '0',
      ),
      Text(
        summary.containsKey('All Calls')
            ? summary['All Calls']['duration']?.toString() ?? '0'
            : '0',
      ),
      Text(
        summary.containsKey('All Calls')
            ? summary['All Calls']['uniqueClients']?.toString() ?? '0'
            : '0',
      ),
    ]);

    // Add Connected row
    data.add([
      const Row(
        children: [
          Icon(Icons.call, size: 16, color: Colors.green),
          SizedBox(width: 6),
          Text('Connected'),
        ],
      ),
      Text(
        summary.containsKey('Connected')
            ? summary['Connected']['calls']?.toString() ?? '0'
            : '0',
      ),
      Text(
        summary.containsKey('Connected')
            ? summary['Connected']['duration']?.toString() ?? '0'
            : '0',
      ),
      Text(
        summary.containsKey('Connected')
            ? summary['Connected']['uniqueClients']?.toString() ?? '0'
            : '0',
      ),
    ]);

    // Add Missed row
    data.add([
      const Row(
        children: [
          Icon(Icons.call_missed, size: 16, color: Colors.redAccent),
          SizedBox(width: 6),
          Text('Missed'),
        ],
      ),
      Text(
        summary.containsKey('Missed')
            ? summary['Missed']['calls']?.toString() ?? '0'
            : '0',
      ),
      Text(
        summary.containsKey('Missed')
            ? summary['Missed']['duration']?.toString() ?? '0'
            : '0',
      ),
      Text(
        summary.containsKey('Missed')
            ? summary['Missed']['uniqueClients']?.toString() ?? '0'
            : '0',
      ),
    ]);

    // Add Rejected row
    data.add([
      Row(
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: Image.asset('assets/incoming.png', fit: BoxFit.contain),
          ),
          // Icon(Icons.call_missed_outgoing_rounded,
          //     size: 16, color: Colors.redAccent),
          SizedBox(width: 6),
          Text('Rejected'),
        ],
      ),
      Text(
        summary.containsKey('Rejected')
            ? summary['Rejected']['calls']?.toString() ?? '0'
            : '0',
      ),
      Text(
        summary.containsKey('Rejected')
            ? summary['Rejected']['duration']?.toString() ?? '0'
            : '0',
      ),
      Text(
        summary.containsKey('Rejected')
            ? summary['Rejected']['uniqueClients']?.toString() ?? '0'
            : '0',
      ),
    ]);

    return data;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dashboardData == null || widget.dashboardData!.isEmpty) {
      return const Center(child: Text('No data available'));
    }
    return SafeArea(
      child: Column(
        children: [
          _buildTabBar(),
          _buildUserStatsCard(),
          const SizedBox(height: 16),
          _buildCallsSummary(),
          const SizedBox(height: 16),
          _buildHourlyAnalysis(),
        ],
      ),
    );
  }

  Widget _buildTimeFilterRow() {
    final timeRanges = ['1D', '1W', '1M', '1Q', '1Y'];

    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(left: 0),
          width: 200,
          // height: 30,
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
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? Colors.blue : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: isActive ? Colors.blue : AppColors.fontColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildUserStatsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(10),
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
          Row(
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
                Colors.blue,
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
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.start,
              ),
            ),
            const SizedBox(width: 3),
            Icon(icon, color: color, size: 20),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: AppFont.smallText12(context),
          textAlign: TextAlign.start,
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(double height) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      height: height,
      width: 0.1,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.backgroundLightGrey)),
      ),
    );
  }

  Widget _buildCallsSummary() {
    return Container(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        // border: Border.all(color: AppColors.sideRed),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [_buildAnalyticsTable()]),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 30,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
    return _buildTableContent();
  }

  Widget _buildTableContent() {
    double screenWidth = MediaQuery.of(context).size.width;

    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(
        horizontalInside: BorderSide(
          color: Colors.grey.withOpacity(0.3),
          width: 0.6,
        ),
        verticalInside: BorderSide.none,
      ),
      columnWidths: {
        0: FixedColumnWidth(screenWidth * 0.33), // Metric
        1: FixedColumnWidth(screenWidth * 0.18), // Calls
        2: FixedColumnWidth(screenWidth * 0.18), // Duration
        3: FixedColumnWidth(screenWidth * 0.18), // Unique client
      },
      children: [
        TableRow(
          children: [
            const SizedBox(), // Empty cell
            Container(
              margin: const EdgeInsets.only(bottom: 10, top: 10),
              child: Text(
                textAlign: TextAlign.start,
                'Calls',
                style: AppFont.smallText10(context),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 10, top: 10),
              child: Text(
                'Duration',
                textAlign: TextAlign.start,
                style: AppFont.smallText10(context),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 10, top: 10, right: 5),
              child: Text(
                textAlign: TextAlign.start,
                'Unique client',
                style: AppFont.smallText10(context),
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
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: isActive ? Colors.white : Colors.blue,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildHourlyAnalysis() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(10),
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
          Text('Hourly Analysis', style: AppFont.dropDowmLabel(context)),
          const SizedBox(height: 10),
          _buildCallStatsRows(),
          const SizedBox(height: 10),
          SizedBox(height: 200, child: _buildCombinedBarChart()),
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
    // int outgoingCalls = 0;
    // String outgoingDuration = "0m";
    int missedCalls = 0;
    String missedDuration = "";

    // Sum up the calls and durations from hourly data
    hourlyAnalysisData.forEach((hour, data) {
      if (data['AllCalls'] != null) {
        allCalls += (data['AllCalls']['calls'] as num?)?.toInt() ?? 0;
        allCallsDuration = data['AllCalls']['duration'] ?? "0m";
      }

      // Connected calls (treating as incoming for now)
      if (data['connected'] != null) {
        incomingCalls += (data['connected']['calls'] as num?)?.toInt() ?? 0;
        incomingDuration = data['connected']['duration']?.toString() ?? "0m";
      }

      // Missed calls
      if (data['missedCalls'] != null) {
        missedCalls = data['missedCalls'] as int;
      }
    });

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.backgroundLightGrey,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildCallStatRow(
                  'All calls',
                  allCalls.toString(),
                  allCallsDuration,
                ),
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
          ),
        ),
      ],
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
              _buildLegendItem('All Calls', Colors.blue),
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
    final List<FlSpot> connectedSpots = [];
    final List<FlSpot> missedSpots = [];

    // Process data to create chart spots
    // Sort keys to ensure hours are in order
    final List<int> sortedHours =
        hourlyAnalysisData.keys.map((e) => int.parse(e)).toList()..sort();

    for (int i = 0; i < sortedHours.length; i++) {
      final hour = sortedHours[i].toString();
      final data = hourlyAnalysisData[hour];

      if (data != null) {
        final double xValue = i.toDouble() * 2; // Spread out the x values

        // All calls
        if (data['AllCalls'] != null) {
          allCallSpots.add(
            FlSpot(xValue, (data['AllCalls']['calls'] ?? 0).toDouble()),
          );
        }

        // Connected calls
        if (data['connected'] != null) {
          connectedSpots.add(
            FlSpot(xValue, (data['connected']['calls'] ?? 0).toDouble()),
          );
        }

        // Missed calls
        if (data['missedCalls'] != null) {
          missedSpots.add(
            FlSpot(xValue, (data['missedCalls'] as int).toDouble()),
          );
        }
      }
    }

    // If no data points, create default ones
    if (allCallSpots.isEmpty) {
      allCallSpots.add(const FlSpot(0, 0));
      allCallSpots.add(const FlSpot(2, 0));
    }
    if (connectedSpots.isEmpty) {
      connectedSpots.add(const FlSpot(0, 0));
      connectedSpots.add(const FlSpot(2, 0));
    }
    if (missedSpots.isEmpty) {
      missedSpots.add(const FlSpot(0, 0));
      missedSpots.add(const FlSpot(2, 0));
    }

    // Find max Y value for the chart
    double maxY = 0;
    for (var spot in [...allCallSpots, ...connectedSpots, ...missedSpots]) {
      if (spot.y > maxY) maxY = spot.y;
    }
    maxY = maxY < 5 ? 5 : (maxY.ceil() + 2); // Add some padding to the max Y

    // Find max X value
    double maxX = 0;
    for (var spot in [...allCallSpots, ...connectedSpots, ...missedSpots]) {
      if (spot.x > maxX) maxX = spot.x;
    }
    maxX = maxX < 2 ? 12 : maxX + 2; // Ensure minimum width and add padding

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  String callType = '';
                  if (spot.barIndex == 0) {
                    callType = 'All Calls';
                  } else if (spot.barIndex == 1) {
                    callType = 'Connected';
                  } else {
                    callType = 'Missed';
                  }
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
                  // Use hourly analysis keys for X axis
                  final int index = value ~/ 2;
                  final style = TextStyle(color: Colors.grey, fontSize: 10);

                  if (index < sortedHours.length) {
                    // Convert 24-hour to 12-hour format
                    int hour = sortedHours[index];
                    String period = hour >= 12 ? 'PM' : 'AM';
                    hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
                    return SideTitleWidget(
                      space: 8,
                      child: Text('$hour$period', style: style),
                      meta: meta,
                    );
                  }
                  return SideTitleWidget(
                    space: 8,
                    child: Text('', style: style),
                    meta: meta,
                  );
                },
                reservedSize: 28,
                interval: 2,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value == 0) {
                    return const SizedBox();
                  }
                  return SideTitleWidget(
                    space: 8,
                    child: Text(
                      value.toInt().toString(),
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                    meta: meta,
                  );
                },
                reservedSize: 28,
                interval: maxY > 10 ? 5 : 1,
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            drawVerticalLine: true,
            horizontalInterval: maxY > 10 ? 5 : 1,
            verticalInterval: 2,
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
            // All Calls Line
            LineChartBarData(
              spots: allCallSpots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.2),
              ),
            ),
            // Connected Calls Line
            LineChartBarData(
              spots: connectedSpots,
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
            // Missed Calls Line (using orange for the outgoing slot)
            LineChartBarData(
              spots: missedSpots,
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
