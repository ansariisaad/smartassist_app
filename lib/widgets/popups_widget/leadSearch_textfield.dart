import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/services/leads_srv.dart';
import 'package:smartassist/utils/snackbar_helper.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:http/http.dart' as http;

class LeadTextfield extends StatefulWidget {
  final Function(String leadId, String leadName)? onLeadSelected;
  const LeadTextfield({super.key, this.onLeadSelected});

  @override
  State<LeadTextfield> createState() => _LeadTextfieldState();
}

class _LeadTextfieldState extends State<LeadTextfield> {
  bool _isLoadingSearch = false;
  String? selectedLeads;
  String? selectedLeadsName;
  List<dynamic> _searchResults = [];
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    // TODO: implement initState
    _searchController.addListener(_onSearchChanged);
    super.initState();
  }

  void _onSearchChanged() {
    final newQuery = _searchController.text.trim();
    if (newQuery == _query) return;

    _query = newQuery;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_query == _searchController.text.trim()) {
        _fetchSearchResults(_query);
      }
    });
  }

  /// Fetch search results from API
  // Future<void> _fetchSearchResults(String query) async {
  //   if (query.isEmpty) {
  //     setState(() {
  //       _searchResults.clear();
  //     });
  //     return;
  //   }

  //   setState(() {
  //     _isLoadingSearch = true;
  //   });

  //   final token = await Storage.getToken();

  //   try {
  //     final response = await http.get(
  //       Uri.parse(
  //           'https://api.smartassistapp.in/api/search/global?query=$query'),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Content-Type': 'application/json',
  //       },
  //     );
  //     if (response.statusCode == 200) {
  //       final Map<String, dynamic> data = json.decode(response.body);
  //       setState(() {
  //         _searchResults = data['data']['suggestions'] ?? [];
  //       });
  //     }
  //   } catch (e) {
  //     showErrorMessage(context, message: 'Something went wrong..!');
  //   } finally {
  //     setState(() {
  //       _isLoadingSearch = false;
  //     });
  //   }
  // }

  Future<void> _fetchSearchResults(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isLoadingSearch = true;
    });

    try {
      final result = await LeadsSrv.globalSearch(query);

      if (result['success']) {
        setState(() {
          _searchResults = result['data'];
        });
      } else {
        showErrorMessage(
          context,
          message: result['error'] ?? 'Something went wrong..!',
        );
      }
    } catch (e) {
      showErrorMessage(context, message: 'Something went wrong..!');
    } finally {
      setState(() {
        _isLoadingSearch = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Lead', style: AppFont.dropDowmLabel(context)),
        const SizedBox(height: 5),
        Container(
          height: MediaQuery.of(context).size.height * 0.055,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: AppColors.containerBg,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.containerBg,
                    hintText: selectedLeadsName ?? 'Type name, email or phone',
                    hintStyle: TextStyle(
                      color: selectedLeadsName != null
                          ? Colors.black
                          : Colors.grey,
                    ),
                    prefixIcon: const Icon(
                      FontAwesomeIcons.magnifyingGlass,
                      size: 15,
                      color: AppColors.fontColor,
                    ),
                    // suffixIcon: IconButton(
                    //   icon: const Icon(
                    //     FontAwesomeIcons.microphone,
                    //     color: AppColors.fontColor,
                    //     size: 15,
                    //   ),
                    //   onPressed: () {
                    //     print('Microphone button pressed');
                    //   },
                    // ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 10,
                    ),
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Show loading indicator
        if (_isLoadingSearch)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Center(child: CircularProgressIndicator()),
          ),

        // Show search results
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return ListTile(
                  onTap: () {
                    setState(() {
                      FocusScope.of(context).unfocus();
                      selectedLeads = result['lead_id'];
                      selectedLeadsName = result['lead_name'];
                      _searchController.clear();
                      _searchResults.clear();
                    });
                    if (widget.onLeadSelected != null) {
                      widget.onLeadSelected!(
                        selectedLeads!,
                        selectedLeadsName!,
                      );
                    }
                  },
                  title: Row(
                    children: [
                      Text(
                        result['lead_name'] ?? 'No Name',
                        style: AppFont.dropDowmLabel(context),
                      ),
                      const SizedBox(width: 5),
                      // Divider Replacement: A Thin Line
                      Container(
                        width: .5, // Set width for the divider
                        height: 15, // Make it a thin horizontal line
                        color: Colors.black,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        result['PMI'] ?? 'Discovery Sport',
                        style: AppFont.tinytext(context),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    result['email'] ?? 'No Email',
                    style: AppFont.smallText(context),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
