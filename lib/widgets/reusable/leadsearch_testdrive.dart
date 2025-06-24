import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/services/api_srv.dart';

typedef VehicleSelectedCallback =
    void Function(Map<String, dynamic> selectedVehicle);

class LeadsearchTestdrive extends StatefulWidget {
  final String? errorText;
  final bool isRequired;
  final ValueChanged<String> onChanged;
  final Function(String leadId, String leadName)? onLeadSelected;
  final VoidCallback? onClearSelection;
  final VehicleSelectedCallback? onVehicleSelected;

  const LeadsearchTestdrive({
    super.key,
    this.onLeadSelected,
    this.onClearSelection,
    required this.errorText,
    required this.onChanged,
    this.isRequired = false,
    this.onVehicleSelected,
  });

  @override
  State<LeadsearchTestdrive> createState() => _LeadsearchTestdriveState();
}

class _LeadsearchTestdriveState extends State<LeadsearchTestdrive> {
  // Controllers and Focus
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _searchController1 = TextEditingController();
  final FocusNode _vehicleFocusNode = FocusNode();

  bool _isLoadingVehicles = false;
  bool _hasLoadedVehicles = false;
  List<Map<String, dynamic>> _filteredVehicles = [];
  List<Map<String, dynamic>> _allVehicles = []; // Store all vehicles

  Map<String, dynamic>? selectedVehicle; // Store entire vehicle object
  String? selectedVehicleName;
  String? vehicleBrand;

  // Search state
  bool _isLoadingSearch = false;
  List<dynamic> _searchResults = [];
  bool _showResults = false;
  bool _hasSearched = false;

  // Selected lead state
  String? selectedLeads;
  String? selectedLeadsName;
  String? selectedLeadPMI; // Store PMI from selected lead

  // Debouncing
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 800);

  // Error handling
  bool _isErrorShowing = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchController1.addListener(_onVehicleSearchChanged);
    _focusNode.addListener(_onFocusChanged);
    _vehicleFocusNode.addListener(_onVehicleFocusChanged);
    // Load vehicles initially
    loadAllVehicles();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController1.removeListener(_onVehicleSearchChanged);
    _searchController.dispose();
    _searchController1.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _vehicleFocusNode.removeListener(_onVehicleFocusChanged);
    _vehicleFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _showResults) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() {
            _showResults = false;
          });
        }
      });
    }
  }

  void _onVehicleFocusChanged() {
    if (!_vehicleFocusNode.hasFocus && _filteredVehicles.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_vehicleFocusNode.hasFocus) {
          setState(() {
            _filteredVehicles.clear();
          });
        }
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    if (_isErrorShowing) {
      setState(() {
        _isErrorShowing = false;
      });
    }

    if (query.isEmpty && selectedLeadsName != null) {
      _clearSelection();
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (mounted) {
        _performSearch(query);
      }
    });
  }

  void _onVehicleSearchChanged() {
    final query = _searchController1.text.trim();

    if (query.isEmpty && selectedVehicleName != null) {
      setState(() {
        selectedVehicle = null;
        selectedVehicleName = null;
        vehicleBrand = null;
        _filteredVehicles.clear();
      });
      widget.onVehicleSelected?.call({});
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (mounted) {
        filterVehicles(query);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      selectedLeads = null;
      selectedLeadsName = null;
      selectedLeadPMI = null;
      _searchController.text = '';
      _searchResults.clear();
      _showResults = false;
      _hasSearched = false;
      // Clear vehicle selection as well
      selectedVehicle = null;
      selectedVehicleName = null;
      vehicleBrand = null;
      _searchController1.text = '';
      _filteredVehicles.clear();
    });
    widget.onClearSelection?.call();
    widget.onVehicleSelected?.call({});
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _showResults = false;
        _hasSearched = false;
      });
      return;
    }

    if (query == selectedLeadsName) {
      return;
    }

    setState(() {
      _isLoadingSearch = true;
      _showResults = true;
    });

    try {
      final result = await LeadsSrv.globalSearch(query);

      if (!mounted) return;

      setState(() {
        _hasSearched = true;
        _isLoadingSearch = false;

        if (result['success'] == true) {
          _searchResults = result['data'] ?? [];
          _isErrorShowing = false;
        } else {
          _searchResults.clear();
          _showSearchError('Lead not found' ?? 'Search failed');
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingSearch = false;
        _searchResults.clear();
        _hasSearched = true;
      });

      _showSearchError('Network error occurred');
      debugPrint('Search error: $e');
    }
  }

  void _showSearchError(String message) {
    if (!_isErrorShowing) {
      setState(() {
        _isErrorShowing = true;
      });

      Get.snackbar(
        'Search Error',
        message,
        duration: const Duration(seconds: 3),
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        onTap: (_) {
          setState(() {
            _isErrorShowing = false;
          });
        },
        isDismissible: true,
      );
    }
  }

  Future<void> loadAllVehicles() async {
    if (_hasLoadedVehicles) return;

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
        print('this is the result data ${result.toString()} ');
      } else {
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

  void _onLeadSelected(Map<String, dynamic> lead) {
    final leadId = lead['lead_id']?.toString() ?? '';
    final leadName = lead['lead_name']?.toString() ?? '';
    final pmi = lead['pmi']?.toString();

    setState(() {
      FocusScope.of(context).unfocus();
      selectedLeads = leadId;
      selectedLeadsName = leadName;
      selectedLeadPMI = pmi;
      _searchController.text = leadName;
      _searchResults.clear();
      _showResults = false;
      _hasSearched = false;

      // Auto-fill vehicle search with PMI and trigger search
      if (pmi != null && pmi.isNotEmpty) {
        _searchController1.text = pmi;
        filterVehicles(pmi);
      } else {
        _searchController1.text = '';
        _filteredVehicles.clear();
        selectedVehicle = null;
        selectedVehicleName = null;
        vehicleBrand = null;
      }
    });

    widget.onChanged(leadName);
    widget.onLeadSelected?.call(leadId, leadName);
  }

  Widget _buildSearchResults() {
    if (!_showResults) return const SizedBox.shrink();

    if (_isLoadingSearch) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_searchResults.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        constraints: const BoxConstraints(maxHeight: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            final result = _searchResults[index];
            return ListTile(
              dense: true,
              onTap: () => _onLeadSelected(result),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      result['lead_name']?.toString() ?? 'No Name',
                      style: AppFont.dropDowmLabel(context),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (result['pmi'] != null) ...[
                    Container(
                      width: 1,
                      height: 15,
                      color: Colors.grey.shade400,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    Text(
                      result['pmi'].toString(),
                      style: AppFont.tinytext(context),
                    ),
                  ],
                ],
              ),
              subtitle: result['email'] != null
                  ? Text(
                      result['email'].toString(),
                      style: AppFont.smallText(context),
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: Colors.grey.shade400,
              ),
            );
          },
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 5),
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.fontBlack,
              ),
              children: [
                TextSpan(text: 'Select Lead'),
                if (widget.isRequired)
                  const TextSpan(
                    text: " *",
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
        Container(
          height: MediaQuery.of(context).size.height * 0.055,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.transparent),
            //  widget.errorText != null
            //     ? Border.all(color: Colors.red, width: 1.0)
            //     : Border.all(color: Colors.grey.shade300, width: 1.0),
            borderRadius: BorderRadius.circular(5),
            color: AppColors.containerBg,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.containerBg,
                    hintText: selectedLeadsName ?? 'Type name, email or phone',
                    hintStyle: TextStyle(
                      color: selectedLeadsName != null
                          ? Colors.black87
                          : Colors.grey.shade500,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      FontAwesomeIcons.magnifyingGlass,
                      size: 15,
                      color: AppColors.fontColor,
                    ),
                    suffixIcon: selectedLeadsName != null
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Colors.grey.shade600,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _clearSelection();
                            },
                            tooltip: 'Clear selection',
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 10,
                    ),
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  onTap: () {
                    if (_searchResults.isNotEmpty) {
                      setState(() {
                        _showResults = true;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        _buildSearchResults(),

        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 0.0, left: 5),
          child: Text('Select Vehicle', style: AppFont.dropDowmLabel(context)),
        ),
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
                  focusNode: _vehicleFocusNode,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(
                        color:
                            widget.errorText != null &&
                                widget.errorText!.isNotEmpty
                            ? Colors.red
                            : Colors.transparent,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(
                        color:
                            widget.errorText != null &&
                                widget.errorText!.isNotEmpty
                            ? Colors.red
                            : Colors.transparent,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(
                        color:
                            widget.errorText != null &&
                                widget.errorText!.isNotEmpty
                            ? Colors.red
                            : Colors.transparent,
                      ),
                    ),
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
                    suffixIcon: selectedVehicleName != null
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Colors.grey.shade600,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController1.clear();
                              setState(() {
                                selectedVehicle = null;
                                selectedVehicleName = null;
                                vehicleBrand = null;
                                _filteredVehicles.clear();
                              });
                              widget.onVehicleSelected?.call({});
                            },
                            tooltip: 'Clear vehicle selection',
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 10,
                    ),
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  onTap: () {
                    if (_filteredVehicles.isNotEmpty) {
                      setState(() {
                        _filteredVehicles = _allVehicles;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        if (_isLoadingVehicles && !_hasLoadedVehicles)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Center(child: CircularProgressIndicator()),
          ),

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
                        selectedVehicle = vehicle;
                        selectedVehicleName = vehicle['vehicle_name'];
                        vehicleBrand = vehicle['brand'];
                        _searchController1.text = vehicle['vehicle_name'] ?? '';
                        _filteredVehicles.clear();
                      });

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

        // if (_searchController1.text.isNotEmpty &&
        //     _filteredVehicles.isEmpty &&
        //     _hasLoadedVehicles)
        //   Container(
        //     margin: const EdgeInsets.only(top: 8),
        //     padding: const EdgeInsets.all(16),
        //     decoration: BoxDecoration(
        //       color: Colors.white,
        //       borderRadius: BorderRadius.circular(5),
        //       boxShadow: const [
        //         BoxShadow(color: AppColors.iconGrey, blurRadius: 4),
        //       ],
        //     ),
        //     child: const Center(
        //       child: Text(
        //         'No vehicles found',
        //         style: TextStyle(color: Colors.grey),
        //       ),
        //     ),
        //   ),
      ],
    );
  }
}
