import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/services/api_srv.dart';
import 'package:smartassist/utils/snackbar_helper.dart';
import 'package:smartassist/utils/storage.dart';

// class VehiclesearchTextfield extends StatefulWidget {
//   final Function(String selectedVehicleName) onVehicleSelected;
//   const VehiclesearchTextfield({super.key, required this.onVehicleSelected});

//   @override
//   State<VehiclesearchTextfield> createState() => _VehiclesearchTextfieldState();
// }

// class _VehiclesearchTextfieldState extends State<VehiclesearchTextfield> {
//   bool _isLoadingSearch1 = false;
//   String? selectedVehicleName;
//   List<dynamic> vehicleList = [];
//   List<String> uniqueVehicleNames = [];
//   List<dynamic> _searchResults1 = [];
//   String _query1 = '';

//   final TextEditingController _searchController1 = TextEditingController();

//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     _searchController1.addListener(_onSearchChanged1);
//   }

//   void _onSearchChanged1() {
//     final newQuery = _searchController1.text.trim();
//     if (newQuery == _query1) return;

//     _query1 = newQuery; // This should be updated to use _query1
//     Future.delayed(const Duration(milliseconds: 500), () {
//       if (_query1 == _searchController1.text.trim()) {
//         fetchVehicleData(_query1); // Pass the correct query1 here
//       }
//     });
//   }

//   //  Future<void> fetchVehicleData(String query) async {
//   //   if (query.isEmpty) {
//   //     setState(() {
//   //       _searchResults1 = [];
//   //       _isLoadingSearch1 = false;
//   //     });
//   //     return;
//   //   }

//   //   final token = await Storage.getToken();

//   //   setState(() {
//   //     _isLoadingSearch1 = true;
//   //   });

//   //   try {
//   //     final response = await http.get(
//   //       Uri.parse(
//   //         'https://dev.smartassistapp.in/api/search/vehicles?vehicle=${Uri.encodeComponent(query)}',
//   //       ),
//   //       headers: {
//   //         'Authorization': 'Bearer $token',
//   //         'Content-Type': 'application/json',
//   //       },
//   //     );

//   //     if (response.statusCode == 200) {
//   //       final Map<String, dynamic> data = json.decode(response.body);
//   //       final List<dynamic> results = data['data']['suggestions'] ?? [];

//   //       final Set<String> seenNames = {};
//   //       final List<dynamic> uniqueResults = [];

//   //       for (var vehicle in results) {
//   //         final name = vehicle['vehicle_name'];
//   //         if (name != null && seenNames.add(name)) {
//   //           uniqueResults.add(vehicle);
//   //         }
//   //       }

//   //       if (_searchResults1 != uniqueResults) {
//   //         // Avoid unnecessary updates
//   //         setState(() {
//   //           _searchResults1 = uniqueResults;
//   //         });
//   //       }
//   //     } else {
//   //       print("Failed to load data: ${response.statusCode}");
//   //     }
//   //   } catch (e) {
//   //     print("Error fetching data: $e");
//   //   } finally {
//   //     setState(() {
//   //       _isLoadingSearch1 = false;
//   //     });
//   //   }
//   // }

//   Future<void> fetchVehicleData(String query) async {
//     if (query.isEmpty) {
//       setState(() {
//         _searchResults1 = [];
//         _isLoadingSearch1 = false;
//       });
//       return;
//     }

//     setState(() {
//       _isLoadingSearch1 = true;
//     });

//     try {
//       final result = await LeadsSrv.vehicleSearch(query);

//       if (result['success']) {
//         setState(() {
//           _searchResults1 = result['data'];
//         });
//       } else {
//         showErrorMessage(context,
//             message: result['message'] ?? 'Something went wrong..!');
//       }
//     } catch (e) {
//       print("Error fetching data: $e");
//     } finally {
//       setState(() {
//         _isLoadingSearch1 = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const SizedBox(height: 10),
//         Text('Select Vehicle', style: AppFont.dropDowmLabel(context)),
//         const SizedBox(height: 10),
//         Container(
//           height: MediaQuery.of(context).size.height * 0.055,
//           width: double.infinity,
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(5),
//             color: AppColors.containerBg,
//           ),
//           child: Row(
//             children: [
//               Expanded(
//                 child: TextField(
//                   controller: _searchController1,
//                   decoration: InputDecoration(
//                     filled: true,
//                     fillColor: AppColors.containerBg,
//                     hintText: selectedVehicleName ?? 'Select',
//                     hintStyle: TextStyle(
//                       // fontSize: 12,
//                       color: selectedVehicleName != null
//                           ? Colors.black
//                           : Colors.grey,
//                     ),
//                     prefixIcon: const Icon(
//                       FontAwesomeIcons.magnifyingGlass,
//                       size: 15,
//                       color: AppColors.iconGrey,
//                     ),
//                     contentPadding:
//                         const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(5),
//                       borderSide: BorderSide.none,
//                     ),
//                   ),
//                   style: GoogleFonts.poppins(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                     color: Colors.black,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),

//         // Show loading indicator
//         if (_isLoadingSearch1)
//           const Padding(
//             padding: EdgeInsets.only(top: 8.0),
//             child: Center(child: CircularProgressIndicator()),
//           ),

//         // Show search results
//         if (_searchResults1.isNotEmpty)
//           Container(
//             margin: const EdgeInsets.only(top: 8),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(5),
//               boxShadow: const [
//                 BoxShadow(color: AppColors.iconGrey, blurRadius: 4)
//               ],
//             ),
//             child: ListView.builder(
//               shrinkWrap: true,
//               physics: const NeverScrollableScrollPhysics(),
//               itemCount: _searchResults1.length,
//               itemBuilder: (context, index) {
//                 final result1 = _searchResults1[index];
//                 return ListTile(
//                   onTap: () {
//                     setState(() {
//                       FocusScope.of(context).unfocus();
//                       selectedVehicleName =
//                           result1['vehicle_name']; // Ensure this is not null
//                       _searchController1.clear();
//                       _searchResults1.clear();
//                     });
//                     if (widget.onVehicleSelected != null) {
//                       widget.onVehicleSelected!(selectedVehicleName!);
//                     }
//                     // ✅ Call the color-fetching function here!
//                     // if (selectedVehicleName != null) {
//                     //   fetchVehicleColors(
//                     //       selectedVehicleName!); // Ensure vehicleName is not null
//                     // }
//                   },
//                   title: Text(
//                     result1['vehicle_name'] ?? 'No Name',
//                     style: TextStyle(
//                       color: selectedVehicleName == result1['vehicle_name']
//                           ? Colors.black
//                           : AppColors.fontBlack,
//                     ),
//                   ),
//                   leading: const Icon(Icons.directions_car),
//                 );
//               },
//             ),
//           ),
//       ],
//     );
//   }
// }

typedef VehicleSelectedCallback =
    void Function(Map<String, dynamic> selectedVehicle);

// Updated VehiclesearchTextfield widget
class VehiclesearchTextfield extends StatefulWidget {
  final VehicleSelectedCallback? onVehicleSelected;

  const VehiclesearchTextfield({Key? key, this.onVehicleSelected})
    : super(key: key);

  @override
  _VehiclesearchTextfieldState createState() => _VehiclesearchTextfieldState();
}

class _VehiclesearchTextfieldState extends State<VehiclesearchTextfield> {
  bool _isLoadingVehicles = false;
  bool _hasLoadedVehicles = false;
  List<Map<String, dynamic>> _filteredVehicles = [];
  List<Map<String, dynamic>> _allVehicles = []; // Store all vehicles
  final TextEditingController _searchController1 = TextEditingController();

  Map<String, dynamic>? selectedVehicle; // Store entire vehicle object
  String? selectedVehicleName;

  @override
  void initState() {
    super.initState();
    // Load all vehicles when widget initializes
    loadAllVehicles();

    // Add listener to search controller for real-time filtering
    _searchController1.addListener(() {
      filterVehicles(_searchController1.text);
    });
  }

  // Load all vehicles once
  Future<void> loadAllVehicles() async {
    if (_hasLoadedVehicles) return; // Prevent multiple API calls

    setState(() {
      _isLoadingVehicles = true;
    });

    try {
      final result = await LeadsSrv.getAllVehicles();

      if (result['success']) {
        setState(() {
          _allVehicles = List<Map<String, dynamic>>.from(result['data']);
          _hasLoadedVehicles = true;
        });
      } else {
        // Handle error - you can show a snackbar or error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Failed to load vehicles'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print("Error fetching vehicles: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading vehicles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVehicles = false;
        });
      }
    }
  }

  // Filter vehicles based on search query
  void filterVehicles(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredVehicles = [];
      });
      return;
    }

    setState(() {
      _filteredVehicles = _allVehicles.where((vehicle) {
        final vehicleName =
            vehicle['vehicle_name']?.toString().toLowerCase() ?? '';
        final assetName = vehicle['asset_name']?.toString().toLowerCase() ?? '';
        final vin = vehicle['VIN']?.toString().toLowerCase() ?? '';
        final brand = vehicle['brand']?.toString().toLowerCase() ?? '';
        final searchQuery = query.toLowerCase();

        return vehicleName.contains(searchQuery) ||
            assetName.contains(searchQuery) ||
            vin.contains(searchQuery) ||
            brand.contains(searchQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text('Select Vehicle', style: AppFont.dropDowmLabel(context)),
        const SizedBox(height: 10),
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
                  controller: _searchController1,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.containerBg,
                    hintText: selectedVehicleName ?? 'Search vehicles...',
                    hintStyle: TextStyle(
                      color: selectedVehicleName != null
                          ? Colors.black
                          : Colors.grey,
                    ),
                    prefixIcon: const Icon(
                      FontAwesomeIcons.magnifyingGlass,
                      size: 15,
                      color: AppColors.iconGrey,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide.none,
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

        // Show loading indicator when initially loading vehicles
        if (_isLoadingVehicles && !_hasLoadedVehicles)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Center(
              // child: CircularProgressIndicator()
            ),
          ),

        // Show filtered search results
        if (_filteredVehicles.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              boxShadow: const [
                BoxShadow(color: AppColors.iconGrey, blurRadius: 4),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredVehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = _filteredVehicles[index];
                  return ListTile(
                    onTap: () {
                      setState(() {
                        FocusScope.of(context).unfocus();
                        selectedVehicle =
                            vehicle; // Store entire vehicle object
                        selectedVehicleName = vehicle['vehicle_name'];
                        _searchController1.clear();
                        _filteredVehicles.clear();
                      });

                      // Pass the entire vehicle object to callback
                      if (widget.onVehicleSelected != null) {
                        widget.onVehicleSelected!(vehicle);
                      }
                    },
                    title: Text(
                      vehicle['vehicle_name'] ?? 'No Name',
                      style: TextStyle(
                        color: selectedVehicleName == vehicle['vehicle_name']
                            ? Colors.black
                            : AppColors.fontBlack,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (vehicle['asset_name'] != null)
                          Text(
                            vehicle['asset_name'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        if (vehicle['brand'] != null &&
                            vehicle['brand'].toString().isNotEmpty)
                          Text(
                            'Brand: ${vehicle['brand']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                    leading: const Icon(Icons.directions_car),
                  );
                },
              ),
            ),
          ),

        // Show "No results found" when search has no matches
        if (_searchController1.text.isNotEmpty &&
            _filteredVehicles.isEmpty &&
            _hasLoadedVehicles)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              boxShadow: const [
                BoxShadow(color: AppColors.iconGrey, blurRadius: 4),
              ],
            ),
            child: const Center(
              child: Text(
                'No vehicles found',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController1.dispose();
    super.dispose();
  }
}
