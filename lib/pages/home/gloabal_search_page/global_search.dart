// import 'package:flutter/material.dart';

// class GlobalSearch extends StatefulWidget {
//   const GlobalSearch({super.key});

//   @override
//   State<GlobalSearch> createState() => _GlobalSearchState();
// }

// class _GlobalSearchState extends State<GlobalSearch> {

// // Search Functionality
//   final TextEditingController _searchController = TextEditingController();
//   List<dynamic> _searchResults = [];
//   bool _isLoadingSearch = false;
//   String _query = '';

//    @override
//   void initState() {
//     super.initState();
//     // fetchDashboardData();
//     _searchController.addListener(_onSearchChanged);
//   }

//   @override
//   void dispose() {
//     _searchController.removeListener(_onSearchChanged);
//     _searchController.dispose();
//     super.dispose();
//   }

//    Future<void> _fetchSearchResults(String query) async {
//     if (query.isEmpty) {
//       setState(() {
//         _searchResults.clear();
//       });
//       return;
//     }

//     setState(() {
//       _isLoadingSearch = true;
//     });

//     final token = await Storage.getToken();

//     try {
//       final response = await http.get(
//         Uri.parse(
//             'https://api.smartassistapp.in/api/search/global?query=$query'),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );
//       if (response.statusCode == 200) {
//         final Map<String, dynamic> data = json.decode(response.body);
//         setState(() {
//           _searchResults = data['suggestions'] ?? [];
//         });
//       }
//     } catch (e) {
//       showErrorMessage(context, message: 'Something went wrong..!');
//     } finally {
//       setState(() {
//         _isLoadingSearch = false;
//       });
//     }
//   }

//   void _onSearchChanged() {
//     final newQuery = _searchController.text.trim();
//     if (newQuery == _query) return;

//     _query = newQuery;
//     Future.delayed(const Duration(milliseconds: 500), () {
//       if (_query == _searchController.text.trim()) {
//         _fetchSearchResults(_query);
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Global Search'),
//       ),
//       body: SingleChildScrollView(
//         keyboardDismissBehavior:
//                             ScrollViewKeyboardDismissBehavior.onDrag,
//         child: Column(

//         ),
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/pages/Leads/single_details_pages/singleLead_followup.dart';
import 'package:smartassist/pages/home/single_details_pages/singleLead_followup.dart';
import 'package:smartassist/pages/home/single_id_screens/single_leads.dart';
import 'package:smartassist/utils/snackbar_helper.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class GlobalSearch extends StatefulWidget {
  const GlobalSearch({super.key});

  @override
  State<GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends State<GlobalSearch> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoadingSearch = false;
  String _query = '';
  bool _isErrorShowing = false;
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

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
      final token = await Storage.getToken();
      final response = await http.get(
        Uri.parse(
          'https://api.smartassistapp.in/api/search/global?query=$query',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _searchResults = data['data']['suggestions'] ?? [];
          _isErrorShowing = false;
        });
      } else {
        // if (!_isErrorShowing) {
        //   setState(() {
        //     _isErrorShowing = true;
        //   });
        //   Get.snackbar(
        //     'Error',
        //     data['message'].toString(),
        //     duration: Duration(seconds: 3),
        //     onTap: (_) {
        //       setState(() {
        //         _isErrorShowing = false;
        //       });
        //     },
        //     isDismissible: true,
        //   );
        // }
      }
    } catch (e) {
      print('Something went wrong..!');
      // showErrorMessage(context, message: 'Something went wrong..!');
    } finally {
      setState(() {
        _isLoadingSearch = false;
      });
    }
  }

  void _onSearchChanged() {
    final newQuery = _searchController.text.trim();
    if (newQuery == _query) return;

    _query = newQuery;

    // Also clear error status when user changes search text
    if (_isErrorShowing) {
      setState(() {
        _isErrorShowing = false;
      });
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (_query == _searchController.text.trim()) {
        _fetchSearchResults(_query);
      }
    });
  }

  // Initialize speech recognition
  void _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done') {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (errorNotification) {
        setState(() {
          _isListening = false;
        });
        showErrorMessage(
          context,
          message: 'Speech recognition error: ${errorNotification.errorMsg}',
        );
      },
    );
    if (!available) {
      showErrorMessage(
        context,
        message: 'Speech recognition not available on this device',
      );
    }
  }

  // Toggle listening
  void _toggleListening(TextEditingController controller) async {
    if (_isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
      });
    } else {
      setState(() {
        _isListening = true;
      });

      await _speech.listen(
        onResult: (result) {
          setState(() {
            controller.text = result.recognizedWords;
          });
        },
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 5),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    }
  }

  // void _onSearchChanged() {
  //   final newQuery = _searchController.text.trim();
  //   if (newQuery == _query) return;

  //   _query = newQuery;
  //   Future.delayed(const Duration(milliseconds: 1500), () {
  //     if (_query == _searchController.text.trim()) {
  //       _fetchSearchResults(_query);
  //     }
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 10, // Removes default space between leading and title
        leadingWidth: 40, // Reduce width of leading to keep it compact
        leading: Padding(
          padding: const EdgeInsets.only(left: 5),
          child: IconButton(
            icon: const Icon(
              Icons.close,
              size: 30,
              // weight: Double(),
              weight: 100,
            ),
            onPressed: () => Get.back(),
          ),
        ),

        // title: Container(
        //   margin: const EdgeInsets.all(10),
        //   child: TextField(
        //     controller: _searchController,
        //     // onChanged: _filterTasks,
        //     decoration: InputDecoration(
        //       enabledBorder: OutlineInputBorder(
        //         borderRadius: BorderRadius.circular(30),
        //         borderSide: BorderSide.none,
        //       ),
        //       focusedBorder: OutlineInputBorder(
        //         // 👈 Add this
        //         borderRadius: BorderRadius.circular(30),
        //         borderSide: BorderSide.none,
        //       ),
        //       filled: true,
        //       fillColor: const Color(0xFFE1EFFF),
        //       contentPadding: const EdgeInsets.fromLTRB(1, 4, 0, 4),
        //       border: InputBorder.none,
        //       hintText: 'Search',
        //       hintStyle: const TextStyle(
        //         color: Colors.grey,
        //         fontWeight: FontWeight.w400,
        //       ),
        //       prefixIcon: const Icon(Icons.search, color: Colors.grey),
        //       suffixIcon: const Icon(Icons.mic, color: Colors.grey),
        //     ),
        //   ),
        // ),
        title: Row(
          children: [
            Expanded(
              // Let the TextField take up available space
              child: TextField(
                minLines: 1,
                maxLines: null,
                autofocus: true,
                controller: _searchController,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.searchBar,
                  hintText: 'Search by name, email or phone ',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 10, right: 6),
                    child: Icon(
                      FontAwesomeIcons.magnifyingGlass,
                      color: AppColors.fontColor,
                      size: 15,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 30),
                  suffixIcon: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _toggleListening(_searchController),
                    icon: const Icon(
                      FontAwesomeIcons.microphone,
                      color: AppColors.fontColor,
                      size: 15,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: _isLoadingSearch
          // ? const Center(child: CircularProgressIndicator())
          // : _searchResults.isEmpty
          //     ? GestureDetector(
          //         onTap: () => FocusScope.of(context).unfocus(),
          //         child: Center(
          //             child: Text("No Matching Record found...!",
          //                 style: AppFont.dropDowmLabel(context))),
          //       )
          ? const Center(child: CircularProgressIndicator())
          : _searchController.text.isEmpty
          ? GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Center(
                child: Text(
                  "Nothing to see here",
                  style: AppFont.dropDowmLabel(context),
                ),
              ),
            )
          : _searchResults.isEmpty
          ? Center(
              child: Text(
                "No Matching Record found...!",
                style: AppFont.dropDowmLabel(context),
              ),
            )
          : ListView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return ListTile(
                  onTap: () {
                    Get.to(() => FollowupsDetails(leadId: result['lead_id']));
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
                  leading: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.containerBg,
                      borderRadius: BorderRadius.all(Radius.circular(30)),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.trending_up, color: AppColors.iconGrey),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
