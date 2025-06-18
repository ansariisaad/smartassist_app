import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/home_btn.dart/leads.dart';
import 'package:smartassist/widgets/home_btn.dart/order.dart';
import 'package:smartassist/widgets/home_btn.dart/test_drive.dart';

import 'package:http/http.dart' as http;

class BottomBtnSecond extends StatefulWidget {
  const BottomBtnSecond({super.key});

  @override
  State<BottomBtnSecond> createState() => _BottomBtnSecondState();
}

class _BottomBtnSecondState extends State<BottomBtnSecond> {
  int _childButtonIndex = 0; // 0:MTD, 1:QTD, 2:YTD
  int _leadButton = 0; // 0:Enquiry, 1:Test Drive, 2:Orders

  bool _isLoading = true;
  Map<String, dynamic>? _mtdData;
  Map<String, dynamic>? _qtdData;
  Map<String, dynamic>? _ytdData;
  Widget? currentWidget;

  @override
  void initState() {
    super.initState();
    _fetchAllPeriodData().then((_) {
      _setInitialWidget();
    });
  }

  // Fetch data for all periods (MTD, QTD, YTD)
  Future<void> _fetchAllPeriodData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Fetch MTD data
      await _fetchDashboardData('MTD').then((data) {
        if (mounted) {
          setState(() {
            _mtdData = data;
          });
        }
      });

      // Fetch QTD data
      await _fetchDashboardData('QTD').then((data) {
        if (mounted) {
          setState(() {
            _qtdData = data;
          });
        }
      });

      // Fetch YTD data
      await _fetchDashboardData('YTD').then((data) {
        if (mounted) {
          setState(() {
            _ytdData = data;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('Error fetching all period data: $e');
    }
  }

  // Fetch dashboard data for a specific period
  Future<Map<String, dynamic>?> _fetchDashboardData(String period) async {
    try {
      final token = await Storage.getToken();

      final uri = Uri.parse(
        'https://api.smartassistapp.in/api/users/dashboard/analytics?type=$period',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print(uri);
      // print('hiii');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        throw Exception(
          'Failed to load $period dashboard data. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching $period data: $e');
      return null;
    }
  }

  void _setInitialWidget() {
    if (_isLoading ||
        _mtdData == null ||
        _qtdData == null ||
        _ytdData == null) {
      return;
    }

    if (_leadButton == 0) {
      _updateLeadsWidget();
    } else if (_leadButton == 1) {
      _updateTestDriveWidget();
    } else if (_leadButton == 2) {
      _updateOrdersWidget();
    }
  }

  void _updateLeadsWidget() {
    setState(() {
      currentWidget = Leads(
        MtdData: _mtdData!,
        QtdData: _qtdData!,
        YtdData: _ytdData!,
      );
    });
  }

  void _updateTestDriveWidget() {
    setState(() {
      currentWidget = TestDrive(
        MtdData: _mtdData!,
        QtdData: _qtdData!,
        YtdData: _ytdData!,
      );
    });
  }

  void _updateOrdersWidget() {
    setState(() {
      currentWidget = Order(
        MtdData: _mtdData!,
        QtdData: _qtdData!,
        YtdData: _ytdData!,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        border: Border.all(color: Colors.black.withOpacity(.1)),
        borderRadius: const BorderRadius.all(Radius.circular(5)),
      ),
      child: _isLoading
          ? _buildSkeletonLoader()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 10,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: SizedBox(
                      height: MediaQuery.sizeOf(context).height * .05,
                      width: double.infinity,
                      child: Row(
                        children: [
                          // Leads Button
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _leadButton = 0;
                                  _updateLeadsWidget();
                                });
                              },
                              style: _buttonStyle(_leadButton == 0),
                              child: Text(
                                'Enquiries',
                                textAlign: TextAlign.center,
                                style: AppFont.buttonwhite(context),
                              ),
                            ),
                          ),

                          // Test Drive Button
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _leadButton = 1;
                                  _updateTestDriveWidget();
                                });
                              },
                              style: _buttonStyle(_leadButton == 1),
                              child: Text(
                                'Test Drives',
                                textAlign: TextAlign.center,
                                style: AppFont.buttonwhite(context),
                              ),
                            ),
                          ),

                          // Orders Button
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _leadButton = 2;
                                  _updateOrdersWidget();
                                });
                              },
                              style: _buttonStyle(_leadButton == 2),
                              child: Text(
                                'Orders',
                                textAlign: TextAlign.center,
                                style: AppFont.buttonwhite(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                currentWidget ?? const SizedBox(height: 10),
                const SizedBox(height: 5),
              ],
            ),
    );
  }

  // Button Style
  ButtonStyle _buttonStyle(bool isSelected) {
    return TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 8),
      minimumSize: const Size(0, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      backgroundColor: isSelected
          ? const Color(0xFF1380FE)
          : Colors.transparent,
      foregroundColor: isSelected ? Colors.white : AppColors.fontColor,
      textStyle: AppFont.threeBtn(context),
    );
  }

  Widget _buildSkeletonLoader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: [
            // Top tab section
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  // Other tabs
                  Container(
                    width: MediaQuery.of(context).size.width * 0.33,
                    color: Colors.white,
                  ),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.33,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // MTD/QTD/YTD tabs row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Metrics section with colored numbers
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column with color indicators and metrics
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Fourth metric row
                      Row(
                        children: [
                          Container(
                            width: MediaQuery.sizeOf(context).width * 0.5,
                            // height: 30,
                            height: MediaQuery.sizeOf(context).height * 0.2,
                            decoration: BoxDecoration(
                              color: Colors.green[400],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: 16,
                              height: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: MediaQuery.sizeOf(context).width * 0.3,
                            // height: 30,
                            height: MediaQuery.sizeOf(context).height * 0.2,
                            decoration: BoxDecoration(
                              color: Colors.green[400],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: 16,
                              height: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
