import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/config/getX/fab.controller.dart';
//
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartassist/pages/Home/single_details_pages/singleLead_followup.dart';
import 'package:smartassist/services/api_srv.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/widgets/google_location.dart';
import 'package:smartassist/widgets/popups_widget/vehicleSearch_textfield.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class CreateLeads extends StatefulWidget {
  final Function onFormSubmit;
  const CreateLeads({super.key, required this.onFormSubmit});

  @override
  State<CreateLeads> createState() => _CreateLeadsState();
}

class _CreateLeadsState extends State<CreateLeads> {
  String? selectedVehicleName;
  String? selectedBrand;
  Map<String, dynamic>? selectedVehicleData;
  final PageController _pageController = PageController();
  List<Map<String, String>> dropdownItems = [];
  // final _formKey = GlobalKey<FormState>();
  bool isLoading = true;
  bool _isLoading = true;
  int _currentStep = 0;
  List<dynamic> vehicleList = [];
  List<String> uniqueVehicleNames = [];
  // String? selectedVehicleName;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool isSubmitting = false;

  bool _isLoadingColor = false;
  String _ColorQuery = '';
  List<dynamic> _searchResultsColor = [];
  String? selectedColorName;
  String? selectedVehicleColorId;
  String? selectedUrl;
  // String? selectedColormail;

  List<dynamic> _searchResults = [];
  // List<String> colorOptions = [];
  // String? selectedColor;
  // String? selectedExteriorColor;
  // String? selectedInteriorColor;
  // List<String> exteriorOptions = [];
  // List<String> interiorOptions = [];

  // Form error tracking
  Map<String, String> _errors = {};
  bool _isLoadingSearch = false;
  String _selectedBrand = '';
  String _selectedType = '';
  String _selectedFuel = '';
  String _selectedPurchaseType = '';
  String _selectedEnquiryType = '';
  Map<String, dynamic>? _existingLeadData;

  // Define constants
  final double _minValue = 4000000; // 40 lakhs
  final double _maxValue = 20000000; // 200 lakhs (2 crore)

  // Initialize range values within min-max bounds
  late RangeValues _rangeAmount;
  List<dynamic> vehicleName = [];
  String selectedSubType = 'Retail';
  String? _locationErrorText;

  // Google Maps API key
  final String _googleApiKey = "AIzaSyA_SWIvFPfChqL33bKtLyZ5YOFSXrsk1Qs";

  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _searchControllerVehicleColor =
      TextEditingController();
  TextEditingController startDateController = TextEditingController();
  TextEditingController endDateController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController mobileController = TextEditingController();
  TextEditingController locationController = TextEditingController();
  TextEditingController modelInterestController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool consentValue = false;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _rangeAmount = RangeValues(_minValue, _maxValue);
    // fetchVehicleData();
    _searchController.addListener(_onSearchChanged);
    _searchControllerVehicleColor.addListener(_onVehicleColorSearchChanged);
    // Initialize speech recognition
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchControllerVehicleColor.removeListener(_onVehicleColorSearchChanged);

    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
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

  // Add this helper method for showing error messages
  void showErrorMessage(BuildContext context, {required String message}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> fetchVehicleData(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoadingSearch = false;
      });
      return;
    }

    final token = await Storage.getToken();

    setState(() {
      _isLoadingSearch = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.smartassistapp.in/api/search/vehicles?vehicle=${Uri.encodeComponent(query)}',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> results = data['data']['suggestions'] ?? [];

        final Set<String> seenNames = {};
        final List<dynamic> uniqueResults = [];

        for (var vehicle in results) {
          final name = vehicle['vehicle_name'];
          if (name != null && seenNames.add(name)) {
            uniqueResults.add(vehicle);
          }
        }

        setState(() {
          _searchResults = uniqueResults;
        });
      } else {
        print("Failed to load data: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching data: $e");
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
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_query == _searchController.text.trim()) {
        fetchVehicleData(_query);
      }
    });
  }

  Future<void> _fetchVehicleColorSearchResults(String query) async {
    print(
      "Inside _fetchAssigneeSearchResults with query: '$query'",
    ); // Debug print

    if (query.isEmpty) {
      setState(() {
        _searchResultsColor.clear();
      });
      return;
    }

    setState(() {
      _isLoadingColor = true;
    });

    try {
      final token = await Storage.getToken();

      final apiUrl =
          'https://api.smartassistapp.in/api/search/vehicle-color?color=$query';
      print("API URL: $apiUrl"); // Debug URL

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print(
        "API Response status: ${response.statusCode}",
      ); // Debug response code
      print("API Response body: ${response.body}"); // Debug response data

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          // _searchResultsAssignee = data['data']['suggestions'] ?? [];
          _searchResultsColor = data['data']['results'] ?? [];

          print(
            "Search results loaded: ${_searchResultsColor.length}",
          ); // Debug results
        });
      } else {
        print("API error: ${response.statusCode} - ${response.body}");
        showErrorMessage(context, message: 'API Error: ${response.statusCode}');
      }
    } catch (e) {
      print("Exception during API call: $e"); // Debug exception
      showErrorMessage(context, message: 'Something went wrong..! $e');
    } finally {
      setState(() {
        _isLoadingColor = false;
      });
    }
  }

  void _onVehicleColorSearchChanged() {
    final newQuery = _searchControllerVehicleColor.text.trim();
    if (newQuery == _ColorQuery) return;

    _ColorQuery = newQuery;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_ColorQuery == _searchControllerVehicleColor.text.trim()) {
        _fetchVehicleColorSearchResults(_ColorQuery);
      }
    });
  }

  // Future<void> fetchVehicleColors(String vehicleName) async {
  //   final token = await Storage.getToken();
  //   final encodedName = Uri.encodeComponent(vehicleName);

  //   final url =
  //       'https://api.smartassistapp.in/api/users/vehicles/all?vehicle_name=$encodedName';

  //   try {
  //     final response = await http.get(
  //       Uri.parse(url),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Content-Type': 'application/json',
  //       },
  //     );

  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body);
  //       final List<dynamic> vehicles = data['data']['rows'] ?? [];

  //       if (vehicles.isNotEmpty) {
  //         final vehicle = vehicles.first;
  //         final String? exterior = vehicle['exterior_color'];
  //         final String? interior = vehicle['interior_color'];

  //         setState(() {
  //           exteriorOptions =
  //               (exterior != null && exterior.isNotEmpty) ? [exterior] : [];
  //           interiorOptions =
  //               (interior != null && interior.isNotEmpty) ? [interior] : [];
  //           selectedExteriorColor = null;
  //           selectedInteriorColor = null;
  //         });
  //       }
  //     } else {
  //       print('Failed to fetch color data: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     print('Error fetching colors: $e');
  //   }
  // }

  // Method to check if lead exists
  Future<void> _checkExistingLead(String mobileNumber) async {
    // if (_isLoading) return;

    // setState(() {
    //   _isLoading = true;
    // });

    final token = await Storage.getToken();

    // Add the country code before making the API call
    if (!mobileNumber.startsWith('+91')) {
      mobileNumber = '+91' + mobileNumber;
      print('Adding country code: $mobileNumber');
    }

    // URL encode the phone number to handle the + symbol
    final encodedMobile = Uri.encodeComponent(mobileNumber);

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.smartassistapp.in/api/leads/existing-check?mobile=$encodedMobile',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('this is body');
        print(response.body);

        // Check if lead exists based on the API response structure
        if (data['status'] == 200 && data['data'] != null) {
          setState(() {
            _existingLeadData = {
              'name': data['data']['lead_name'] ?? 'Unknown',
              'mobile': data['data']['mobile'] ?? mobileNumber,
              'PMI': data['data']['PMI'] ?? 'Unknown',
              'lead_owner': data['data']['lead_owner'] ?? 'Unknown',
            };
          });
          print("Existing lead found: ${_existingLeadData}");
        } else {
          setState(() {
            _existingLeadData = null;
          });
          print("No existing lead found");
        }
      }
    } catch (e) {
      print('Error checking existing lead: $e');
      setState(() {
        _existingLeadData = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate({required bool isStartDate}) async {
    FocusScope.of(context).unfocus();
    final DateTime today = DateTime.now();
    final DateTime initialDate = today;
    final DateTime lastDate = DateTime(2100);
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: lastDate,
    );

    if (pickedDate != null) {
      String formattedDate = DateFormat('dd/MM/yyyy').format(pickedDate);
      setState(() {
        if (isStartDate) {
          startDateController.text = formattedDate;
          _errors.remove('startDate');
        } else {
          endDateController.text = formattedDate;
        }
      });
    }
  }

  // Validate page 1 fields
  bool _validatePage1() {
    bool isValid = true;
    setState(() {
      _errors = {}; // Clear previous errors

      String fname = firstNameController.text.trim();
      String lname = lastNameController.text.trim();
      // Validate first name
      if (fname.isEmpty) {
        _errors['firstName'] = 'First name is required';
        isValid = false;
      } else if (!_isValidFirst(fname)) {
        _errors['firstName'] = 'Invalid first name format';
        isValid = false;
      }

      // Validate last name
      if (lname.isEmpty) {
        _errors['lastName'] = 'Last name is required';
        isValid = false;
      } else if (!_isValidSecond(lname)) {
        _errors['lastName'] = 'Invalid last name format';
        isValid = false;
      }

      // Validate email
      if (emailController.text.trim().isEmpty) {
        _errors['email'] = 'Email is required';
        isValid = false;
      } else if (!_isValidEmail(emailController.text.trim())) {
        _errors['email'] = 'Please enter a valid email';
        isValid = false;
      }

      // Validate mobile
      if (mobileController.text.trim().isEmpty) {
        _errors['mobile'] = 'Mobile number is required';
        isValid = false;
      } else if (!_isValidMobile(mobileController.text.trim())) {
        _errors['mobile'] =
            'Please enter a valid 10-digit Indian mobile number';
        isValid = false;
      }

      if (_selectedType.isEmpty) {
        _errors['leadSource'] = 'Please select a lead source';
        isValid = false;
      }
    });

    return isValid;
  }

  // Validate page 2 fields
  bool _validatePage2() {
    bool isValid = true;
    setState(() {
      _errors = {}; // Clear previous errors

      // Validate brand
      // if (_selectedBrand.isEmpty) {
      //   _errors['brand'] = 'Please select a brand';
      //   isValid = false;
      // }

      // Validate fuel type
      // if (_selectedFuel.isEmpty) {
      //   _errors['fuel'] = 'Please select a fuel type';
      //   isValid = false;
      // }

      // Validate purchase type
      if (_selectedPurchaseType.isEmpty) {
        _errors['purchaseType'] = 'Please select a purchase type';
        isValid = false;
      }

      // Validate enquiry type
      if (_selectedEnquiryType.isEmpty) {
        _errors['enquiryType'] = 'Please select an enquiry type';
        isValid = false;
      }

      // Validate primary model interest
      // if (modelInterestController.text.trim().isEmpty) {
      //   _errors['model'] = 'Primary model interest is required';
      //   isValid = false;
      // }

      // Validate expected purchase date
      // if (endDateController.text.trim().isEmpty) {
      //   _errors['purchaseDate'] = 'Expected purchase date is required';
      //   isValid = false;
      // }
    });

    return isValid;
  }

  bool _validatePage3() {
    bool isValid = true;

    // Example checks — replace with your actual fields
    // if (selectedExteriorColor == null || selectedExteriorColor!.isEmpty) {
    //   isValid = false;
    //   _errors['exteriorColor'] = 'select ';
    // }

    // if (selectedInteriorColor == null || selectedInteriorColor!.isEmpty) {
    //   isValid = false;
    //   _errors['interiorColor'] = 'select';
    // }

    // You can add more field checks here if needed

    setState(() {}); // Update UI to show error messages if needed
    return isValid;
  }

  // Email validation
  bool _isValidEmail(String email) {
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

    // First character should not be uppercase
    // if (email.isEmpty || email[0] == email[0].toUpperCase()) {
    //   return false;
    // }

    return emailRegExp.hasMatch(email);
  }

  // bool _isValidName(String name) {
  //   final nameRegExp = RegExp(r'^[a-zA-Z0-9]+( [a-zA-Z0-9]+)*$');

  //   return nameRegExp.hasMatch(name);
  // }

  bool _isValidFirst(String name) {
    final nameRegExp = RegExp(r'^[A-Z][a-zA-Z0-9]*( [a-zA-Z0-9]+)*$');
    return nameRegExp.hasMatch(name);
  }

  bool _isValidSecond(String name) {
    final nameRegExp = RegExp(r'^[A-Z][a-zA-Z0-9]*( [a-zA-Z0-9]+)*$');
    return nameRegExp.hasMatch(name);
  }

  bool _isValidMobile(String mobile) {
    // Remove any non-digit characters
    String digitsOnly = mobile.replaceAll(RegExp(r'\D'), '');

    // Check if it's a valid Indian number: 10 digits and starts with 6-9
    return RegExp(r'^[6-9]\d{9}$').hasMatch(digitsOnly);
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_validatePage1()) {
        setState(() => _currentStep++);
        // No need for PageController navigation with IndexedStack
      } else {
        String errorMessage = _errors.values.join('\n');
        Get.snackbar(
          'Error',
          errorMessage,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } else if (_currentStep == 1) {
      if (_validatePage2()) {
        setState(() => _currentStep++);
        // No need for PageController navigation with IndexedStack
      } else {
        String errorMessage = _errors.values.join('\n');
        Get.snackbar(
          'Error',
          errorMessage,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } else {
      if (_validatePage3()) {
        _submitForm(); // ✅ API will hit now
      } else {
        String errorMessage = _errors.values.join('\n');
        Get.snackbar(
          'Error',
          errorMessage,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (isSubmitting) return;

    setState(() => isSubmitting = true);

    try {
      await submitForm(); // Your actual API call
    } catch (e) {
      Get.snackbar(
        'Error',
        'Submission failed: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void _validateLocation() {
    if (_locationController.text.trim().isEmpty) {
      setState(() {
        _locationErrorText = 'Location is required';
      });
    } else {
      setState(() {
        _locationErrorText = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 1;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(left: 10),
                child: Text(
                  'Add New Enquiry',
                  style: AppFont.popupTitleBlack(context),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                // Step indicators with line
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Step 1 indicator column
                      Column(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _currentStep == 0
                                  ? AppColors.colorsBlue
                                  : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '1',
                                style: TextStyle(
                                  color: _currentStep == 0
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Contact \nDetails',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _currentStep == 0
                                  ? AppColors.colorsBlue
                                  : Colors.grey,
                              fontWeight: _currentStep == 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),

                      // Connector line
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(
                            bottom: 17,
                          ), // Move line up to align with circles
                          height: 2,
                          color: _currentStep == 1
                              ? Colors.grey.shade300
                              : Colors.grey.shade300,
                        ),
                      ),

                      // Step 2 indicator column
                      Column(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _currentStep == 1
                                  ? AppColors.colorsBlue
                                  : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '2',
                                style: TextStyle(
                                  color: _currentStep == 1
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Vehicle \nDetails',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _currentStep == 1
                                  ? AppColors.colorsBlue
                                  : Colors.grey,
                              fontWeight: _currentStep == 1
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),

                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(
                            bottom: 17,
                          ), // Move line up to align with circles
                          height: 2,
                          color: _currentStep == 2
                              ? Colors.grey.shade300
                              : Colors.grey.shade300,
                        ),
                      ),

                      // Step 3 indicator column
                      Column(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _currentStep == 2
                                  ? AppColors.colorsBlue
                                  : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '3',
                                style: TextStyle(
                                  color: _currentStep == 2
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'More \n Details',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _currentStep == 2
                                  ? AppColors.colorsBlue
                                  : Colors.grey,
                              fontWeight: _currentStep == 2
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            IndexedStack(
              index: _currentStep,
              // physics: const NeverScrollableScrollPhysics(),
              children: [
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              isRequired: true,
                              label: 'First Name',
                              controller: firstNameController,
                              hintText: 'First name',
                              errorText: _errors['firstName'],
                              onChanged: (value) {
                                if (_errors.containsKey('firstName')) {
                                  setState(() {
                                    _errors.remove('firstName');
                                  });
                                }
                                print("firstName : $value");
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(
                              isRequired: true,
                              label: 'Last Name',
                              errorText: _errors['lastName'],
                              controller: lastNameController,
                              hintText: 'Last name',
                              onChanged: (value) {
                                if (_errors.containsKey('lastName')) {
                                  setState(() {
                                    _errors.remove('lastName');
                                  });
                                }
                                print("lastName : $value");
                              },
                            ),
                          ),
                        ],
                      ),

                      _buildNumberWidget(
                        isRequired: true,
                        label: 'Mobile No',
                        controller: mobileController,
                        errorText: _errors['mobile'],
                        hintText: '+91',
                        onChanged: (value) {
                          if (_errors.containsKey('mobile')) {
                            setState(() {
                              _errors.remove('mobile');
                            });
                          }
                          print("mobile: $value");
                        },
                      ),
                      //////////////////////////////////////////////////////////////
                      _buildTextField(
                        isRequired: true,
                        label: 'Email',
                        controller: emailController,
                        hintText: 'Email',
                        errorText: _errors['email'],
                        onChanged: (value) {
                          if (_errors.containsKey('email')) {
                            setState(() {
                              _errors.remove('email');
                            });
                          }
                          print("email : $value");
                        },
                      ),

                      const SizedBox(height: 10),
                      // _buildButtons
                      _buildButtonsFloat1(
                        isRequired: true,
                        label: 'Lead Source',
                        options: {
                          "Email": "Email",
                          "Existing Customer": "Existing Customer",
                          "Field Visit": "Field Visit",
                          "Phone-in": "Phone-in",
                          "Phone-out": "Phone-out",
                          "Purchased List": "Purchased List",
                          "Referral": "Referral",
                          "Retailer Experience": "Retailer Experience",
                          "SMS": "SMS",
                          "Social (Retailer)": "Social (Retailer)",
                          "Walk-in": "Walk-in",
                          "Other": "Other",
                        },
                        groupValue: _selectedType,
                        errorText: _errors['leadSource'],
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value;
                            if (_errors.containsKey('leadSource')) {
                              _errors.remove('leadSource');
                            }
                          });
                        },
                      ),
                      // _buildAmountRange(),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAmountRange(isRequired: true),
                      VehiclesearchTextfield(
                        onVehicleSelected: (selectedVehicle) {
                          setState(() {
                            selectedVehicleData = selectedVehicle;
                            selectedVehicleName =
                                selectedVehicle['vehicle_name'];
                            selectedBrand =
                                selectedVehicle['brand'] ??
                                ''; // Handle null brand
                          });

                          print("Selected Vehicle: $selectedVehicleName");
                          print(
                            "Selected Brand: ${selectedBrand ?? 'No Brand'}",
                          );
                        },
                      ),
                      // _buildSearchField(
                      //   errorText: _errors['model'],
                      //   onChanged: (value) {
                      //     if (_errors.containsKey('model')) {
                      //       setState(() {
                      //         _errors.remove('model');
                      //       });
                      //     }
                      //   },
                      //   // onChanged: (value) {
                      //   //   setState(() {
                      //   //     modelInterestController = value;
                      //   //     if (_errors.containsKey('model')) {
                      //   //       _errors.remove('model');
                      //   //     }
                      //   //   });
                      //   // },
                      // ),
                      const SizedBox(height: 10),
                      _buildVehicleColorSearch(),
                      const SizedBox(height: 10),
                      // _buildButtonsFloat(
                      //   isRequired: true,
                      //   options: {
                      //     "Jaguar": "Jaguar",
                      //     "Land Rover": "Land Rover",
                      //   },
                      //   groupValue: _selectedBrand,
                      //   label: 'Brand',
                      //   errorText: _errors['brand'],
                      //   onChanged: (value) {
                      //     setState(() {
                      //       _selectedBrand = value;
                      //       if (_errors.containsKey('brand')) {
                      //         _errors.remove('brand');
                      //       }
                      //     });
                      //   },
                      // ),
                      const SizedBox(height: 10),
                      // const SizedBox(
                      //   height: 10,
                      // ),

                      // _buildButtonsFloat(
                      //     isRequired: true,
                      //     options: {
                      //       // "EV": "EV",
                      //       "Petrol": "Petrol",
                      //       "Diesel": "Diesel",
                      //     },
                      //     groupValue: _selectedFuel,
                      //     label: 'Fuel Type',
                      //     errorText: _errors['fuel'],
                      //     onChanged: (value) {
                      //       setState(() {
                      //         if (_errors.containsKey('fuel')) {
                      //           _errors.remove('fuel');
                      //         }
                      //         _selectedFuel = value;
                      //       });
                      //     }),
                      // const SizedBox(height: 10),
                      _buildButtonsFloat(
                        isRequired: true,
                        options: {
                          "New": "New Vehicle",
                          "Pre-Owned": "Used Vehicle",
                        },
                        groupValue: _selectedPurchaseType,
                        label: 'Purchase Type',
                        errorText: _errors['purchaseType'],
                        onChanged: (value) {
                          setState(() {
                            _selectedPurchaseType = value;
                            if (_errors.containsKey('purchaseType')) {
                              _errors.remove('purchaseType');
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      _buildButtonsFloat(
                        isRequired: true,
                        options: {
                          "KMI": "KMI",
                          "Generic": "(Generic) Purchase intent within 90 days",
                        },
                        groupValue: _selectedEnquiryType,
                        label: 'Enquiry Type',
                        errorText: _errors['enquiryType'],
                        onChanged: (value) {
                          setState(() {
                            _selectedEnquiryType = value;
                            if (_errors.containsKey('enquiryType')) {
                              _errors.remove('enquiryType');
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 5),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomGooglePlacesField(
                        controller: _locationController,
                        hintText: 'Enter location',
                        label: 'Location',
                        onChanged: (value) {
                          // if (_locationErrorText != null) {
                          //   _validateLocation();
                          // }
                        },
                        googleApiKey:
                            _googleApiKey, // Replace with your actual API key
                        isRequired: true,
                        // errorText: _locationError,
                      ),
                      _buildDatePicker(
                        // isRequired: true,
                        label: 'Expected purchase date',
                        controller: endDateController,
                        errorText: _errors['purchaseDate'],
                        onTap: () => _pickDate(isStartDate: false),
                      ),
                      // const SizedBox(
                      //   height: 10,
                      // ),
                      // _consentTick(
                      //   isRequired: true,
                      //   text: "Agreed with these terms",
                      //   value: consentValue,
                      //   onChanged: (newValue) {
                      //     setState(() {
                      //       consentValue = newValue;
                      //     });
                      //   },
                      // ),
                    ],
                  ),
                ),
              ],
            ),

            // ✅ Updated Button Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(217, 217, 217, 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    onPressed: () {
                      if (_currentStep == 0) {
                        Navigator.pop(context); // Close if on first page
                      } else {
                        // _pageController.previousPage(
                        //   duration: const Duration(milliseconds: 300),
                        //   curve: Curves.easeInOut,
                        // );
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_pageController.hasClients) {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        });
                        setState(() => _currentStep--);
                      }
                    },
                    child: Text(
                      _currentStep == 0 ? "Cancel" : "Previous",
                      style: AppFont.buttons(context),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.colorsBlueButton,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    onPressed: _nextStep,
                    child: Text(
                      _currentStep == 2 ? "Create" : "Continue",
                      style: AppFont.buttons(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField({
    required ValueChanged<String> onChanged,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // const SizedBox(height: 10),
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
                TextSpan(
                  text: 'Primary Model Interest',
                  style: AppFont.dropDowmLabel(context),
                ),
                // if (isRequired)
                const TextSpan(
                  text: " *",
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
        // Text('Primary Model Interest', style: AppFont.dropDowmLabel(context)),
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
                    hintText: selectedVehicleName ?? 'Vehicle Name',
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
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(
                        color: errorText != null
                            ? Colors.red
                            : Colors.transparent,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(
                        color: errorText != null
                            ? Colors.red
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    errorText:
                        null, // omit this if you don't want error message text below
                  ),

                  // decoration: InputDecoration(
                  //   filled: true,
                  //   fillColor: AppColors.containerBg,
                  //   hintText: selectedVehicleName ?? 'Vehicle Name',
                  //   hintStyle: TextStyle(
                  //     color: selectedVehicleName != null
                  //         ? Colors.black
                  //         : Colors.grey,
                  //   ),
                  //   prefixIcon: const Icon(
                  //     FontAwesomeIcons.magnifyingGlass,
                  //     size: 15,
                  //     color: AppColors.iconGrey,
                  //   ),
                  //   contentPadding:
                  //       const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                  //   border: OutlineInputBorder(
                  //     borderRadius: BorderRadius.circular(5),
                  //     borderSide: BorderSide.none,
                  //   ),
                  // ),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  // onChanged: onChanged,
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
                      // selectedLeads = result['lead_id'];
                      selectedVehicleName = result['vehicle_name'];
                      _searchController.text =
                          result['vehicle_name']; //new added for validation
                      modelInterestController.text =
                          result['vehicle_name']; //new added for validation
                      _searchController.clear();
                      _searchResults.clear();

                      if (_errors.containsKey('model')) {
                        _errors.remove('model'); // 🔥 remove error key
                      }
                    });
                    // ✅ Call the color-fetching function here!
                    // fetchVehicleColors(result['vehicle_name']);
                  },
                  title: Text(
                    result['vehicle_name'] ?? 'No Name',
                    style: TextStyle(
                      color: selectedVehicleName == result['vehicle_name']
                          ? Colors.black
                          : AppColors.fontBlack,
                    ),
                  ),
                  leading: const Icon(Icons.directions_car),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildNumberWidget({
    required TextEditingController controller,
    required String hintText,
    required String label,
    required ValueChanged<String> onChanged,
    bool isRequired = false,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 5),
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              children: [
                TextSpan(text: label),
                if (isRequired)
                  const TextSpan(
                    text: " *",
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: const Color.fromARGB(255, 248, 247, 247),
            border: errorText != null
                ? Border.all(color: Colors.red, width: 1.0)
                : null,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextField(
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              controller: controller,
              style: AppFont.dropDowmLabel(context),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontSize: 12,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: InputBorder.none,
              ),
              // onChanged: (value) {
              //   onChanged(value);

              //   // Clear existing lead data if input length is not 10
              //   if (value.length != 10) {
              //     setState(() {
              //       _existingLeadData = null;
              //       _isLoading = false;
              //     });
              //   }

              //   // Check for existing lead only when mobile number is exactly 10 digits
              //   if (value.length == 10) {
              //     _checkExistingLead(value);
              //   }
              // },
              onChanged: (value) {
                onChanged(value);

                // For debugging
                print("Current mobile input: $value, length: ${value.length}");

                // Clear existing lead data if input length is not 10
                if (value.length != 10) {
                  setState(() {
                    _existingLeadData = null;
                    _isLoading = false;
                  });
                }

                // Check for existing lead only when mobile number is exactly 10 digits
                if (value.length == 10) {
                  print("Checking for existing lead with number: $value");
                  _checkExistingLead(value);
                }
              },
            ),
          ),
        ),

        // Show loader only when API is being called
        // if (_isLoading)
        //   Padding(
        //     padding: const EdgeInsets.only(top: 8.0),
        //     child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        //   ),

        // Show this only if an existing lead is found
        if (_existingLeadData != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'Lead already exists',
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${_existingLeadData!['name']}',
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              height: 15,
                              width: 0.1,
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: AppColors.fontColor),
                                ),
                              ),
                            ),
                            Text(
                              '${_existingLeadData!['PMI']}',
                              style: AppFont.smallText(context),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '${_existingLeadData!['mobile']}',
                              style: GoogleFonts.poppins(
                                color: Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              height: 15,
                              width: 0.1,
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: AppColors.fontColor),
                                ),
                              ),
                            ),
                            Text(
                              'by ${_existingLeadData!['lead_owner']}',
                              style: AppFont.smallText(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildVehicleColorSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color', style: AppFont.dropDowmLabel(context)),
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
                  controller: _searchControllerVehicleColor,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.containerBg,
                    hintText: selectedColorName ?? 'Search Color',
                    hintStyle: TextStyle(
                      color: selectedColorName != null
                          ? Colors.black
                          : Colors.grey,
                    ),
                    prefixIcon: const Icon(
                      FontAwesomeIcons.magnifyingGlass,
                      size: 15,
                      color: AppColors.fontColor,
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
                  onTap: () {
                    // If there is a selected lead, populate the text field with its name
                    // if (selectedColorName != null &&
                    //     _searchControllerVehicleColor.text.isEmpty) {
                    //   _searchControllerVehicleColor.text = selectedColorName!;
                    //   _searchControllerVehicleColor.selection =
                    //       TextSelection.fromPosition(
                    //     TextPosition(
                    //         offset: _searchControllerVehicleColor.text.length),
                    //   );
                    // }
                  },
                  onChanged: (value) {
                    if (value.isEmpty && selectedColorName != null) {
                      setState(() {
                        selectedColorName = null;
                        selectedVehicleColorId = null;
                        selectedUrl = null;
                      });
                    }
                    // print("TextField onChanged: '$value'"); // Additional debug
                  },
                ),
              ),
            ],
          ),
        ),

        // Show loading indicator
        if (_isLoadingColor)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Center(child: CircularProgressIndicator()),
          ),

        // Show search results
        if (_searchResultsColor.isNotEmpty)
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
              itemCount: _searchResultsColor.length,
              itemBuilder: (context, index) {
                final result = _searchResultsColor[index];
                final imageUrl = result['image_url'];

                return ListTile(
                  onTap: () {
                    setState(() {
                      FocusScope.of(context).unfocus();
                      selectedVehicleColorId = result['color_id'];
                      selectedColorName = result['color_name'];
                      selectedUrl =
                          result['image_url']; // Save the selected URL

                      // _searchControllerVehicleColor.clear();
                      _searchControllerVehicleColor.text =
                          result['color_name'] ?? '';

                      _searchResultsColor.clear();
                    });
                  },
                  title: Text(
                    result['color_name'] ?? 'No Name',
                    style: GoogleFonts.poppins(
                      color: selectedVehicleColorId == result['color_id']
                          ? Colors.black
                          : AppColors.fontBlack,
                    ),
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade200, // Fallback color
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.error_outline,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value:
                                            loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                            : null,
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                            )
                          : const Center(
                              child: Icon(
                                Icons.invert_colors_rounded,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _consentTick({
    bool isRequired = false,
    required String text,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? checkboxFillColor,
    Color? borderColor,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 5),
          child: Align(
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.fontBlack,
                ),
                children: [
                  TextSpan(
                    text: 'Consent',
                    style: AppFont.dropDowmLabel(context),
                  ),
                  if (isRequired)
                    const TextSpan(
                      text: " *",
                      style: TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Align(
        //   alignment: Alignment.centerLeft,
        //   child: Text(
        //     'Consent',
        //     style: AppFont.dropDowmLabel(context),
        //   ),
        // ),
        // const SizedBox(
        //   height: 10,
        // ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: const Color.fromARGB(255, 248, 247, 247),
            border: borderColor != null
                ? Border.all(color: borderColor, width: 1.0)
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: value,
                  onChanged: (newValue) {
                    if (newValue != null) {
                      onChanged(newValue);
                    }
                  },
                  fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (states.contains(MaterialState.selected)) {
                      return checkboxFillColor ?? Colors.blue;
                    }
                    return Colors.transparent;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required String label,
    required ValueChanged<String> onChanged,
    bool isRequired = false,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),
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
                TextSpan(text: label),
                if (isRequired)
                  const TextSpan(
                    text: " *",
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: const Color.fromARGB(255, 248, 247, 247),
            border: errorText != null
                ? Border.all(color: Colors.red, width: 1.0)
                : null,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: controller,
              style: AppFont.dropDowmLabel(context),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontSize: 12,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: InputBorder.none,
              ),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker({
    bool isRequired = false,
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),
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
                TextSpan(text: label),
                if (isRequired)
                  const TextSpan(
                    text: " *",
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 45,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              // color: AppColors.containerPopBg,
              border: errorText != null
                  ? Border.all(color: Colors.red)
                  : Border.all(color: Colors.black, width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? "DD / MM / YY" : controller.text,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: controller.text.isEmpty
                          ? AppColors.fontColor
                          : Colors.black,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.fontBlack,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButtonsFloat({
    bool isRequired = false,
    required Map<String, String> options,
    required String groupValue,
    required String label,
    required ValueChanged<String> onChanged,
    String? errorText,
  }) {
    List<String> optionKeys = options.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          // margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 248, 247, 247),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
            border: errorText != null
                ? Border.all(color: Colors.red, width: 1.0)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6.0,
                        horizontal: 5,
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.fontBlack,
                          ),
                          children: [
                            TextSpan(text: label),
                            if (isRequired)
                              const TextSpan(
                                text: " *",
                                style: TextStyle(color: Colors.red),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // SizedBox(
                    //   child: RichText(
                    //     text: TextSpan(
                    //       style: AppFont.dropDowmLabel(context),
                    //       children: [
                    //         TextSpan(text: label),
                    //       ],
                    //     ),
                    //     textAlign: TextAlign.left,
                    //   ),
                    // ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildOptionButton(
                                optionKeys[0],
                                options,
                                groupValue,
                                onChanged,
                              ),
                              const SizedBox(width: 5),
                              _buildOptionButton(
                                optionKeys[1],
                                options,
                                groupValue,
                                onChanged,
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
        ),
        // if (errorText != null)
        //   Padding(
        //     padding: const EdgeInsets.only(left: 5, top: 0),
        //     child: Text(
        //       errorText,
        //       style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 12),
        //     ),
        //   ),
      ],
    );
  }

  Widget _buildButtonsFloat1({
    bool isRequired = false,
    required Map<String, String> options,
    required String groupValue,
    required String label,
    required ValueChanged<String> onChanged,
    String? errorText,
  }) {
    List<String> optionKeys = options.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          // margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          // padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 248, 247, 247),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
            border: errorText != null
                ? Border.all(color: Colors.red, width: 1.0)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0, left: 5),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.fontBlack,
                      ),
                      children: [
                        TextSpan(text: label),
                        if (isRequired)
                          const TextSpan(
                            text: " *",
                            style: TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                  ),
                ),
                // SizedBox(
                //   child: RichText(
                //     text: TextSpan(
                //       style: AppFont.dropDowmLabel(context),
                //       children: [
                //         TextSpan(text: label),
                //       ],
                //     ),
                //     textAlign: TextAlign.left,
                //   ),
                // ),
                // const SizedBox(width: 10),
                Wrap(
                  spacing: 2,
                  runSpacing: 10,
                  // mainAxisAlignment: MainAxisAlignment.start,
                  children: options.keys.map((shortText) {
                    bool isSelected = groupValue == options[shortText];

                    return GestureDetector(
                      onTap: () {
                        onChanged(options[shortText]!);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0,
                        ),
                        // margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? AppColors.colorsBlue
                                : AppColors.fontColor,
                            width: .5,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          color: isSelected
                              ? AppColors.colorsBlue.withOpacity(0.2)
                              : AppColors.innerContainerBg,
                        ),
                        child: Text(
                          shortText, // ✅ Only show short text
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.colorsBlue
                                : AppColors.fontColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        // if (errorText != null)
        //   Padding(
        //     padding: const EdgeInsets.only(left: 5, top: 0),
        //     child: Text(
        //       errorText,
        //       style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 12),
        //     ),
        //   ),
      ],
    );
  }

  // Widget _buildButtonsFloat({
  //   required Map<String, String> options,
  //   required String groupValue,
  //   required String label,
  //   required ValueChanged<String> onChanged,
  //   String? errorText,
  // }) {
  //   List<String> optionKeys = options.keys.toList();

  //   return Container(
  //     decoration: BoxDecoration(
  //         color: const Color.fromARGB(255, 248, 247, 247),
  //         borderRadius: const BorderRadius.all(Radius.circular(5)),
  //         border: errorText != null
  //             ? Border.all(color: Colors.red, width: 1.0)
  //             : null),
  //     child: Padding(
  //       padding: const EdgeInsets.all(8.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Row(
  //             crossAxisAlignment: CrossAxisAlignment
  //                 .center, // ✅ Aligns label and buttons properly
  //             children: [
  //               // 🔹 Brand Label (Left Side, Vertically Centered)
  //               SizedBox(
  //                 child: Align(
  //                   alignment:
  //                       Alignment.centerRight, // ✅ Ensures proper alignment
  //                   child: Text(
  //                     label,
  //                     style: AppFont.dropDowmLabel(context),
  //                     textAlign: TextAlign.left,
  //                   ),
  //                 ),
  //               ),

  //               const SizedBox(width: 10),

  //               // 🔹 Right Side: Brand Options in Two Rows
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment:
  //                       CrossAxisAlignment.start, // Align buttons left
  //                   children: [
  //                     Row(
  //                       mainAxisAlignment:
  //                           MainAxisAlignment.end, // ✅ Align left
  //                       children: [
  //                         _buildOptionButton(
  //                             optionKeys[0], options, groupValue, onChanged),
  //                         const SizedBox(width: 5),
  //                         _buildOptionButton(
  //                             optionKeys[1], options, groupValue, onChanged),
  //                       ],
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildAmountRange({bool isRequired = false}) {
    // Convert to lakhs for display (no decimal)
    final int startLakh = (_rangeAmount.start / 100000).round();
    final int endLakh = (_rangeAmount.end / 100000).round();

    final startText = startLakh.toString();
    final endText = endLakh.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 5),
        Text("Budget", style: AppFont.dropDowmLabel(context)),
        const SizedBox(height: 5),

        // 🔹 Show Selected Range as Text
        Padding(
          padding: const EdgeInsets.only(left: 5),
          child: Text(
            "INR:$startText lakh - INR:$endText lakh",
            style: AppFont.smallText(context),
          ),
        ),

        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.colorsBlue,
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
            thumbColor: AppColors.colorsBlue,
            overlayColor: Colors.blue.withOpacity(0.2),
            showValueIndicator: ShowValueIndicator.always,
          ),
          child: RangeSlider(
            values: _rangeAmount,
            min: _minValue,
            max: _maxValue,
            divisions: 160, // 160 steps from 40L to 200L in 1L steps
            labels: RangeLabels("INR:${startText}L", "INR:${endText}L"),
            onChanged: (RangeValues values) {
              // Round to nearest lakh
              final double newStart = (values.start / 100000).round() * 100000;
              final double newEnd = (values.end / 100000).round() * 100000;

              // Clamp values
              final clampedStart = newStart.clamp(_minValue, _maxValue);
              final clampedEnd = newEnd.clamp(_minValue, _maxValue);

              setState(() {
                _rangeAmount = RangeValues(clampedStart, clampedEnd);
              });
            },
          ),
        ),
      ],
    );
  }

  // Widget _buildAmountRange({
  //   bool isRequired = false,
  // }) {
  //   // Convert to lakhs for display
  //   final double startLakh = _rangeAmount.start / 100000;
  //   final double endLakh = _rangeAmount.end / 100000;

  //   // Format with one decimal place
  //   final startText = startLakh.toStringAsFixed(1);
  //   final endText = endLakh.toStringAsFixed(1);

  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       const SizedBox(height: 5),

  //       Padding(
  //         padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 5),
  //         child: RichText(
  //           text: TextSpan(
  //             style: GoogleFonts.poppins(
  //               fontSize: 14,
  //               fontWeight: FontWeight.w500,
  //               color: AppColors.fontBlack,
  //             ),
  //             children: [
  //               TextSpan(text: 'Budget'),
  //               // if (isRequired)
  //               //   const TextSpan(
  //               //     text: " *",
  //               //     style: TextStyle(color: Colors.red),
  //               //   ),
  //             ],
  //           ),
  //         ),
  //       ),

  //       const SizedBox(height: 5),

  //       // 🔹 Show Selected Range as Text
  //       Padding(
  //         padding: const EdgeInsets.only(left: 5),
  //         child: Text(
  //           "INR:$startText lakh - INR:$endText lakh",
  //           style: AppFont.smallText(context),
  //         ),
  //       ),

  //       // const SizedBox(height: 5),

  //       // 🔹 Range Slider
  //       SliderTheme(
  //         data: SliderTheme.of(context).copyWith(
  //           activeTrackColor: AppColors.colorsBlue,
  //           inactiveTrackColor: Colors.grey.withOpacity(0.3),
  //           thumbColor: AppColors.colorsBlue,
  //           overlayColor: Colors.blue.withOpacity(0.2),
  //           showValueIndicator: ShowValueIndicator.always,
  //         ),
  //         child: RangeSlider(
  //           values: _rangeAmount,
  //           min: _minValue,
  //           max: _maxValue,
  //           divisions: 180, // (200-40) increments of 1 lakh each
  //           labels: RangeLabels(
  //             "INR:${startText}L",
  //             "INR:${endText}L",
  //           ),
  //           onChanged: (RangeValues values) {
  //             // Round to nearest lakh
  //             final double newStart = (values.start / 100000).round() * 100000;
  //             final double newEnd = (values.end / 100000).round() * 100000;

  //             // Ensure values are within bounds
  //             final clampedStart = newStart.clamp(_minValue, _maxValue);
  //             final clampedEnd = newEnd.clamp(_minValue, _maxValue);

  //             setState(() {
  //               _rangeAmount = RangeValues(clampedStart, clampedEnd);
  //             });
  //           },
  //         ),
  //       ),
  //     ],
  //   );
  // }

  // ✅ Button Builder Function
  Widget _buildOptionButton(
    String shortText,
    Map<String, String> options,
    String groupValue,
    ValueChanged<String> onChanged,
  ) {
    bool isSelected = groupValue == options[shortText];

    return GestureDetector(
      onTap: () {
        onChanged(options[shortText]!);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.colorsBlue : Colors.grey,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(15),
          color: isSelected
              ? AppColors.colorsBlue.withOpacity(0.1)
              : AppColors.innerContainerBg,
        ),
        child: Center(
          child: Text(
            shortText,
            style: TextStyle(
              color: isSelected ? AppColors.colorsBlue : AppColors.fontColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtons({
    bool isRequired = false,
    required Map<String, String> options,
    required String groupValue,
    required String label,
    String? errorText,
    required ValueChanged<String> onChanged,
  }) {
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
                TextSpan(text: label),
                if (isRequired)
                  const TextSpan(
                    text: " *",
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 2,
          runSpacing: 10,
          // mainAxisAlignment: MainAxisAlignment.start,
          children: options.keys.map((shortText) {
            bool isSelected = groupValue == options[shortText];

            return GestureDetector(
              onTap: () {
                onChanged(options[shortText]!);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 0,
                ),
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? AppColors.colorsBlue
                        : AppColors.fontColor,
                    width: .5,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  color: isSelected
                      ? AppColors.colorsBlue.withOpacity(0.2)
                      : AppColors.innerContainerBg,
                ),
                child: Text(
                  shortText, // ✅ Only show short text
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.colorsBlue
                        : AppColors.fontColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  Widget _buildButtons1({
    required Map<String, String> options,
    required String groupValue,
    String? errorText,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5.0, left: 5),
          child: Wrap(
            spacing: 5, // Space between buttons
            runSpacing: 10,
            // mainAxisAlignment: MainAxisAlignment.start,
            children: options.keys.map((shortText) {
              bool isSelected = groupValue == options[shortText];

              return GestureDetector(
                onTap: () {
                  onChanged(options[shortText]!);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 0,
                  ),
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? AppColors.colorsBlue
                          : AppColors.fontColor,
                      width: .5,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    color: isSelected
                        ? AppColors.colorsBlue.withOpacity(0.2)
                        : AppColors.innerContainerBg,
                  ),
                  child: Text(
                    shortText, // ✅ Only show short text
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.colorsBlue
                          : AppColors.fontColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  Future<void> submitForm() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? spId = prefs.getString('user_id');

      if (spId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User ID not found. Please log in again.'),
            ),
          );
        }
        print("Error: User ID not found."); // ✅ Print error in console
        return;
      }

      // When preparing the leadData:
      String mobileNumber = mobileController.text;

      // Ensure the mobile number always includes the country code
      if (!mobileNumber.startsWith('+91')) {
        // print(mobileNumber);

        mobileNumber = '+91' + mobileNumber;
      }

      final double highestBudgetValue = _rangeAmount.end;

      final leadData = {
        'fname': firstNameController.text,
        'lname': lastNameController.text,
        'email': emailController.text,
        'mobile': mobileNumber,
        'purchase_type': _selectedPurchaseType,
        'brand': selectedBrand ?? '',
        'type': 'Product',
        'sub_type': selectedSubType,
        // 'sp_id': spId,
        'chat_id': "91${mobileController.text}@c.us",
        'PMI': selectedVehicleName,
        'expected_date_purchase': endDateController.text,
        'fuel_type': _selectedFuel,
        'enquiry_type': _selectedEnquiryType,
        'lead_source': _selectedType,
        'consent': consentValue,
        'budget': highestBudgetValue,
        'location': _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        'exterior_color': selectedColorName,
      };

      print(
        "Submitting lead data: $leadData",
      ); // ✅ Print lead data before submission

      Map<String, dynamic>? response = await LeadsSrv.submitLead(leadData);

      if (response != null) {
        print("Response received: $response");

        if (response.containsKey('data')) {
          // ✅ Form submitted successfully
          String leadId = response['data']['lead_id'];

          if (context.mounted) {
            // Disable the FAB
            Get.find<FabController>().temporarilyDisableFab();

            Navigator.pop(context);
            // widget.onFormSubmit();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FollowupsDetails(
                  leadId: leadId,
                  isFromFreshlead: true,
                  isFromManager: false,
                ),
              ),
            );
          }

          String successMessage =
              response['message'] ?? 'Form submitted successfully';
          Get.snackbar(
            'Success',
            successMessage,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );

          widget.onFormSubmit();
        } else if (response.containsKey('error') ||
            response.containsKey('message')) {
          String errorMessage =
              response['error'] ??
              response['message'] ??
              'Something went wrong';

          if (response['errors'] != null && response['errors'] is Map) {
            Map<String, dynamic> errorDetails = response['errors'];

            if (errorDetails.isNotEmpty) {
              setState(() {
                _errors = errorDetails.map(
                  (key, value) => MapEntry(key, value.toString()),
                );
              });

              // Show first error message
              String firstFieldError = errorDetails.entries.first.value
                  .toString();
              Get.snackbar(
                'Validation Error',
                firstFieldError,
                backgroundColor: Colors.red,
                colorText: Colors.white,
              );
            }
          } else {
            // If it's a generic error (like "Not a valid email")
            Get.snackbar(
              'Error',
              errorMessage,
              backgroundColor: Colors.red,
              colorText: Colors.white,
            );
          }
        }
      } else {
        print("Error: API response is null");

        Get.snackbar(
          'Error',
          'Something went wrong. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e, stackTrace) {
      print("Exception Occurred: $e"); // ✅ Log any unexpected exceptions
      print("Stack Trace: $stackTrace"); // ✅ Print stack trace for debugging

      Get.snackbar(
        'Error',
        'An error occurred: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
