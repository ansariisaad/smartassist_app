import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartassist/services/api_srv.dart';
import 'package:smartassist/utils/snackbar_helper.dart';
import 'package:smartassist/widgets/popups_widget/leadSearch_textfield.dart';
import 'package:smartassist/widgets/remarks_field.dart';
import 'package:smartassist/widgets/reusable/action_button.dart';
import 'package:smartassist/widgets/reusable/date_button.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AppointmentPopup extends StatefulWidget {
  final Function onFormSubmit;
  final Function(int)? onTabChange;
  const AppointmentPopup({
    super.key,
    required this.onFormSubmit,
    this.onTabChange,
  });

  @override
  State<AppointmentPopup> createState() => _AppointmentPopupState();
}

class _AppointmentPopupState extends State<AppointmentPopup> {
  String? _leadId;
  String? _leadName;
  // final PageController _pageController = PageController();
  List<Map<String, String>> dropdownItems = [];
  bool isLoading = false;
  int _currentStep = 0;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  Map<String, String> _errors = {};
  bool isSubmitting = false;

  bool _isLoadingSearch = false;
  String _query = '';
  String? selectedLeads;
  String _selectedSubject = '';
  String? selectedLeadsName;
  String? selectedPriority;

  List<dynamic> _searchResults = [];

  final TextEditingController _searchController = TextEditingController();
  TextEditingController startDateController = TextEditingController();
  TextEditingController endDateController = TextEditingController();
  TextEditingController startTimeController = TextEditingController();
  TextEditingController endTimeController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // fetchDropdownData();

    _speech = stt.SpeechToText();
    _initSpeech();
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

  /// Fetch search results from API
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

    final token = await Storage.getToken();

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.smartassistapp.in/api/search/global?query=$query',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = data['data']['suggestions'] ?? [];
        });
      }
    } catch (e) {
      showErrorMessage(context, message: 'Something went wrong..!');
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
        _fetchSearchResults(_query);
      }
    });
  }

  Future<void> _pickDate({required bool isStartDate}) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        DateTime combinedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        String formattedDateTime = DateFormat(
          'dd/MM/yyyy hh:mm a',
        ).format(combinedDateTime);
        setState(() {
          if (isStartDate) {
            startDateController.text = formattedDateTime;
          } else {
            endDateController.text = formattedDateTime;
          }
        });
      }
    }
  }

  void _submit() async {
    if (isSubmitting) return;

    bool isValid = true;

    setState(() {
      isSubmitting = true;
      _errors = {};

      if (_leadId == null || _leadId!.isEmpty) {
        _errors['select lead name'] = 'Please select a lead name';
        isValid = false;
      }

      if (_selectedSubject == null || _selectedSubject!.isEmpty) {
        _errors['subject'] = 'Please select an action';
        isValid = false;
      }

      if (startDateController.text.isEmpty) {
        _errors['date'] = 'Please select a date';
        isValid = false;
      }

      if (startTimeController.text.isEmpty) {
        _errors['time'] = 'Please select a time';
        isValid = false;
      }
    });

    // 💡 Check validity before calling the API
    if (!isValid) {
      setState(() => isSubmitting = false);
      return;
    }

    try {
      await submitForm(); // ✅ Only call if valid
      // Show snackbar or do post-submit work here
    } catch (e) {
      print(e.toString());
      // Get.snackbar(
      //   'Error',
      //   'Submission failed: ${e.toString()}',
      //   backgroundColor: Colors.red,
      //   colorText: Colors.white,
      // );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  Future<void> _pickStartDate() async {
    FocusScope.of(context).unfocus();

    // Get current start date or use today
    DateTime initialDate;
    try {
      if (startDateController.text.isNotEmpty) {
        initialDate = DateFormat('dd MMM yyyy').parse(startDateController.text);
      } else {
        initialDate = DateTime.now();
      }
    } catch (e) {
      initialDate = DateTime.now();
    }

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      String formattedDate = DateFormat('dd MMM yyyy').format(pickedDate);

      setState(() {
        // Set start date
        startDateController.text = formattedDate;

        // Set end date to the same as start date but not visible in the UI
        // (Only passed to API)
        endDateController.text = formattedDate;
      });
    }
  }

  Future<void> _pickStartTime() async {
    FocusScope.of(context).unfocus();

    // Get current time from startTimeController or use current time
    TimeOfDay initialTime;
    try {
      if (startTimeController.text.isNotEmpty) {
        final parsedTime = DateFormat(
          'hh:mm a',
        ).parse(startTimeController.text);
        initialTime = TimeOfDay(
          hour: parsedTime.hour,
          minute: parsedTime.minute,
        );
      } else {
        initialTime = TimeOfDay.now();
      }
    } catch (e) {
      initialTime = TimeOfDay.now();
    }

    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime != null) {
      // Check if the selected date is today
      DateTime selectedDate;
      try {
        if (startDateController.text.isNotEmpty) {
          selectedDate = DateFormat(
            'dd MMM yyyy',
          ).parse(startDateController.text);
        } else {
          selectedDate = DateTime.now();
        }
      } catch (e) {
        selectedDate = DateTime.now();
      }

      // If the selected date is today, check if the time is in the past
      bool isToday =
          selectedDate.year == DateTime.now().year &&
          selectedDate.month == DateTime.now().month &&
          selectedDate.day == DateTime.now().day;

      if (isToday) {
        final now = DateTime.now();
        final selectedDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // If selected time is in the past, show error and return
        if (selectedDateTime.isBefore(now)) {
          Get.snackbar(
            'Error',
            'Please select a future time',
            colorText: Colors.white,
            backgroundColor: Colors.red[400],
          );
          return;
        }
      }

      // Create a temporary DateTime to format the time
      final now = DateTime.now();
      final time = DateTime(
        now.year,
        now.month,
        now.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      String formattedTime = DateFormat('hh:mm a').format(time);

      // Calculate end time (1 hour later)
      final endHour = (pickedTime.hour + 1) % 24;
      final endTime = DateTime(
        now.year,
        now.month,
        now.day,
        endHour,
        pickedTime.minute,
      );
      String formattedEndTime = DateFormat('hh:mm a').format(endTime);

      setState(() {
        // Set start time
        startTimeController.text = formattedTime;

        // Set end time to 1 hour later but not visible in the UI
        // (Only passed to API)
        endTimeController.text = formattedEndTime;
      });
    }
  }

  // Future<void> _pickStartTime() async {
  //   FocusScope.of(context).unfocus();

  //   // Get current time from startTimeController or use current time
  //   TimeOfDay initialTime;
  //   try {
  //     if (startTimeController.text.isNotEmpty) {
  //       final parsedTime = DateFormat(
  //         'hh:mm a',
  //       ).parse(startTimeController.text);
  //       initialTime = TimeOfDay(
  //         hour: parsedTime.hour,
  //         minute: parsedTime.minute,
  //       );
  //     } else {
  //       initialTime = TimeOfDay.now();
  //     }
  //   } catch (e) {
  //     initialTime = TimeOfDay.now();
  //   }

  //   TimeOfDay? pickedTime = await showTimePicker(
  //     context: context,
  //     initialTime: initialTime,
  //   );

  //   if (pickedTime != null) {
  //     // Create a temporary DateTime to format the time
  //     final now = DateTime.now();
  //     final time = DateTime(
  //       now.year,
  //       now.month,
  //       now.day,
  //       pickedTime.hour,
  //       pickedTime.minute,
  //     );
  //     String formattedTime = DateFormat('hh:mm a').format(time);

  //     // Calculate end time (1 hour later)
  //     final endHour = (pickedTime.hour + 1) % 24;
  //     final endTime = DateTime(
  //       now.year,
  //       now.month,
  //       now.day,
  //       endHour,
  //       pickedTime.minute,
  //     );
  //     String formattedEndTime = DateFormat('hh:mm a').format(endTime);

  //     setState(() {
  //       // Set start time
  //       startTimeController.text = formattedTime;

  //       // Set end time to 1 hour later but not visible in the UI
  //       // (Only passed to API)
  //       endTimeController.text = formattedEndTime;
  //     });
  //   }
  // }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.fontBlack,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: AppColors.containerBg,
          ),
          child: Row(
            children: [
              // Expanded TextField that adjusts height
              Expanded(
                child: TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: controller,
                  maxLines:
                      null, // This allows the TextField to expand vertically based on content
                  minLines: 1, // Minimum 1 line of height
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    border: InputBorder.none,
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              // Microphone icon with speech recognition
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => _toggleListening(controller),
                  icon: Icon(
                    _isListening
                        ? FontAwesomeIcons.stop
                        : FontAwesomeIcons.microphone,
                    color: _isListening ? Colors.red : AppColors.fontColor,
                    size: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Create Appointment',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // _buildSearchField(),
              LeadTextfield(
                resions:
                    'This enquiry has no number associated to it, please add one before creating a Appointment',

                isRequired: true,
                onChanged: (value) {
                  if (_errors.containsKey('select lead name')) {
                    setState(() {
                      _errors.remove('select lead name');
                    });
                  }
                  print("select lead name : $value");
                },
                errorText: _errors['select lead name'],
                onLeadSelected: (leadId, leadName) {
                  setState(() {
                    _leadId = leadId;
                    _leadName = leadName;
                  });
                },
              ),
              const SizedBox(height: 15),
              DateButton(
                isRequired: true,
                label: 'When?',
                dateController: startDateController,
                timeController: startTimeController,
                onDateTap: _pickStartDate,
                onTimeTap: _pickStartTime,
                onChanged: (String value) {},
                dateErrorText: _errors['date'],
                timeErrorText: _errors['time'],
              ),
              // Row(
              //   children: [
              //     Text('When ?', style: AppFont.dropDowmLabel(context)),
              //     const SizedBox(width: 10),
              //     Expanded(
              //       child: _buildDatePicker(
              //         controller: startDateController,
              //         onTap: _pickStartDate,
              //       ),
              //     ),
              //     const SizedBox(width: 10),
              //     Expanded(
              //       child: _buildDatePicker1(
              //         controller: startTimeController,
              //         onTap: _pickStartTime,
              //       ),
              //     ),
              //   ],
              // ),
              // const SizedBox(height: 15),
              // Row(
              //   children: [
              //     Text(
              //       'End  ',
              //       style: AppFont.dropDowmLabel(context),
              //     ),
              //     const SizedBox(width: 10),

              //     // End Date Picker - fills half remaining space
              //     Expanded(
              //       child: _buildDatePicker(
              //         controller: endDateController,
              //         onTap: _pickEndDate,
              //       ),
              //     ),
              //     const SizedBox(width: 10),

              //     // End Time Picker - fills other half
              //     Expanded(
              //       child: _buildDatePicker(
              //         controller: endTimeController,
              //         onTap: _pickEndTime,
              //       ),
              //     ),
              //   ],
              // ),
              // _buildDatePicker(
              //     label: 'Start Date',
              //     controller: startDateController,
              //     onTap: () => _pickDate(isStartDate: true)),
              // _buildDatePicker(
              //     label: 'End Date',
              //     controller: endDateController,
              //     onTap: () => _pickDate(isStartDate: false)),
              const SizedBox(height: 10),

              // _buildButtons(
              //   options: {
              //     "Meeting": "Meeting",
              //     "Vehicle selection": "Vehicle Selection",
              //     "Showroom appointment": "Showroom appointment",
              //     "Trade in evaluation": "Trade in evaluation",
              //   },
              //   groupValue: _selectedSubject,
              //   label: 'Action:',
              //   onChanged: (value) {
              //     setState(() {
              //       _selectedSubject = value;
              //       if (_errors.containsKey('subject')) {
              //         _errors.remove('subject');
              //       }
              //     });
              //   },
              //   errorText: _errors['subject'],
              // ),
              ActionButton(
                label: "Action:",
                isRequired: true,
                options: {
                  "Meeting": "Meeting",
                  "Vehicle selection": "Vehicle Selection",
                  "Showroom appointment": "Showroom appointment",
                  "Trade in evaluation": "Trade in evaluation",
                },
                groupValue: _selectedSubject,
                onChanged: (value) {
                  setState(() {
                    _selectedSubject = value;
                    if (_errors.containsKey('subject')) {
                      _errors.remove('subject');
                    }
                  });
                },
                errorText: _errors['subject'],
              ),

              const SizedBox(height: 10),
              // _buildTextField(
              //   label: 'Remarks:',
              //   controller: descriptionController,
              //   hint: 'Type or speak...',
              // ),
              EnhancedSpeechTextField(
                isRequired: false,
                error: false,
                // contentPadding: EdgeInsets.zero,
                label: 'Remarks:',
                controller: descriptionController,
                hint: 'Type or speak... ',
                onChanged: (text) {
                  print('Text changed: $text');
                },
              ),
              // EnhancedSpeechTextField(
              //   isRequired: false,
              //   // contentPadding: EdgeInsets.zero,
              //   label: 'Remarks:',
              //   controller: descriptionController,
              //   hint: 'Type or speak... ',
              //   onChanged: (text) {
              //     print('Text changed: $text');
              //   },
              // ),
              const SizedBox(height: 10),
            ],
          ),
          // const SizedBox(height: ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color.fromRGBO(217, 217, 217, 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: AppFont.buttons(context)),
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
                  onPressed: _submit,
                  child: Text("Create", style: AppFont.buttons(context)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Lead', style: AppFont.dropDowmLabel(context)),
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
                  controller: _searchController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.containerBg,
                    hintText:
                        selectedLeadsName ?? 'Search by name, email or phone',
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
                    suffixIcon: IconButton(
                      icon: const Icon(
                        FontAwesomeIcons.microphone,
                        color: AppColors.fontColor,
                        size: 15,
                      ),
                      onPressed: () {
                        print('Microphone button pressed');
                      },
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
                // return ListTile(
                //   onTap: () {
                //     setState(() {
                //       FocusScope.of(context).unfocus();
                //       selectedLeads = result['lead_id'];
                //       selectedLeadsName = result['lead_name'];
                //       _searchController.clear();
                //       _searchResults.clear();
                //     });
                //   },
                //   title: Text(
                //     result['lead_name'] ?? 'No Name',
                //     style: TextStyle(
                //       color: selectedLeads == result['lead_id']
                //           ? Colors.black
                //           : AppColors.fontBlack,
                //     ),
                //   ),
                //   leading: const Icon(Icons.person),
                // );
                return ListTile(
                  onTap: () {
                    setState(() {
                      FocusScope.of(context).unfocus();
                      selectedLeads = result['lead_id'];
                      selectedLeadsName = result['lead_name'];
                      _searchController.clear();
                      _searchResults.clear();
                    });
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

  // Widget _buildSearchField() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text('Choose Lead', style: AppFont.dropDowmLabel(context)),
  //       const SizedBox(height: 5),
  //       SizedBox(
  //         height: MediaQuery.of(context).size.height * .05,
  //         child: TextField(
  //           controller: _searchController,
  //           onTap: () => FocusScope.of(context).unfocus(),
  //           decoration: InputDecoration(
  //             filled: true,
  //             alignLabelWithHint: true,
  //             fillColor: AppColors.containerBg,
  //             hintText: selectedLeadsName ?? 'Select New Leads',
  //             hintStyle: AppFont.dropDown(context),
  //             prefixIcon:
  //                 const Icon(FontAwesomeIcons.magnifyingGlass, size: 15),
  //             border: OutlineInputBorder(
  //                 borderRadius: BorderRadius.circular(5),
  //                 borderSide: BorderSide.none),
  //           ),
  //         ),
  //       ),
  //       if (_isLoadingSearch) const Center(child: CircularProgressIndicator()),
  //       if (_searchResults.isNotEmpty)
  //         Positioned(
  //           top: 50,
  //           left: 20,
  //           right: 20,
  //           child: Material(
  //             elevation: 5,
  //             child: Container(
  //               height: MediaQuery.of(context).size.height * .2,
  //               // margin: const EdgeInsets.only(top: 5),
  //               decoration: BoxDecoration(
  //                   color: Colors.white,
  //                   borderRadius: BorderRadius.circular(5)),
  //               child: ListView.builder(
  //                 itemCount: _searchResults.length,
  //                 itemBuilder: (context, index) {
  //                   final result = _searchResults[index];
  //                   return ListTile(
  //                     onTap: () {
  //                       setState(() {
  //                         FocusScope.of(context).unfocus();
  //                         selectedLeads = result['lead_id'];
  //                         selectedLeadsName = result['lead_name'];
  //                         _searchController.clear();
  //                         _searchResults.clear();
  //                       });
  //                     },
  //                     title: Text(result['lead_name'] ?? 'No Name',
  //                         style: const TextStyle(
  //                           color: AppColors.fontBlack,
  //                         )),
  //                     // subtitle: Text(result['email'] ?? 'No Email'),
  //                     leading: const Icon(Icons.person),
  //                   );
  //                 },
  //               ),
  //             ),
  //           ),
  //         ),
  //     ],
  //   );
  // }

  Widget _buildButtons({
    required Map<String, String> options, // ✅ Short display & actual value
    required String groupValue,
    required String label,
    required ValueChanged<String> onChanged,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0.0, 5, 0, 5),
            child: Text(label, style: AppFont.dropDowmLabel(context)),
          ),
        ),
        const SizedBox(height: 5),

        // ✅ Wrap ensures buttons move to next line when needed
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: errorText != null
                ? Border.all(color: Colors.red, width: 1.0)
                : null,
          ),
          child: Wrap(
            spacing: 10, // Space between buttons
            runSpacing: 10, // Space between lines
            children: options.keys.map((shortText) {
              bool isSelected =
                  groupValue == options[shortText]; // ✅ Compare actual value

              return GestureDetector(
                onTap: () {
                  onChanged(
                    options[shortText]!,
                  ); // ✅ Pass actual value on selection
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? AppColors.colorsBlue : Colors.black,
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
                      color: isSelected ? AppColors.colorsBlue : Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
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

  // Widget _buildDropdown({
  //   required String label,
  //   required String? value,
  //   required List<dynamic> items,
  //   required ValueChanged<String?> onChanged,
  // }) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Padding(
  //         padding: const EdgeInsets.symmetric(vertical: 5.0),
  //         child: Text(
  //           label,
  //           style: GoogleFonts.poppins(
  //               fontSize: 14,
  //               fontWeight: FontWeight.w500,
  //               color: AppColors.fontBlack),
  //         ),
  //       ),
  //       Container(
  //         height: 45,
  //         width: double.infinity,
  //         decoration: BoxDecoration(
  //           borderRadius: BorderRadius.circular(5),
  //           color: AppColors.containerPopBg,
  //         ),
  //         child: DropdownButton<String>(
  //           value: value,
  //           hint: Padding(
  //             padding: const EdgeInsets.only(left: 10),
  //             child: Text(
  //               "Select",
  //               style: GoogleFonts.poppins(
  //                   fontSize: 14,
  //                   fontWeight: FontWeight.w500,
  //                   color: Colors.grey),
  //             ),
  //           ),
  //           icon: const Padding(
  //             padding: EdgeInsets.all(8.0),
  //             child: Icon(Icons.keyboard_arrow_down_sharp, size: 30),
  //           ),
  //           isExpanded: true,
  //           underline: const SizedBox.shrink(),
  //           items: items.map((item) {
  //             return DropdownMenuItem<String>(
  //               value: item is String ? item : item['id'].toString(),
  //               child: Padding(
  //                 padding: const EdgeInsets.only(left: 10.0),
  //                 child: Text(
  //                   item is String ? item : item['name'].toString(),
  //                   style: GoogleFonts.poppins(
  //                       fontSize: 14,
  //                       fontWeight: FontWeight.w500,
  //                       color: Colors.black),
  //                 ),
  //               ),
  //             );
  //           }).toList(),
  //           onChanged: onChanged,
  //         ),
  //       ),
  //     ],
  //   );
  // }

  // Widget _buildDatePicker(
  //     {required String label,
  //     required TextEditingController controller,
  //     required VoidCallback onTap}) {
  //   return GestureDetector(
  //       onTap: onTap,
  //       child: TextField(
  //           controller: controller,
  //           readOnly: true,
  //           decoration: InputDecoration(labelText: label)));
  // }

  Widget _buildDatePicker({
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 45,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color.fromARGB(255, 248, 247, 247),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? "Date" : controller.text,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: controller.text.isEmpty
                          ? Colors.grey
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

  Widget _buildDatePicker1({
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 45,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color.fromARGB(255, 248, 247, 247),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? "Time" : controller.text,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: controller.text.isEmpty
                          ? Colors.grey
                          : Colors.black,
                    ),
                  ),
                ),
                const Icon(
                  Icons.watch_later_outlined,
                  color: AppColors.fontBlack,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> submitForm() async {
    final prefs = await SharedPreferences.getInstance();
    final spId = prefs.getString('user_id');

    // if (selectedLeads == null) {
    //   showErrorMessage(context, message: 'Please select a lead.');
    //   return;
    // }

    // final leadId = selectedLeads!;

    try {
      // Parse raw date and time
      final rawStartDate = DateFormat(
        'dd MMM yyyy',
      ).parse(startDateController.text);
      final rawEndDate = DateFormat(
        'dd MMM yyyy',
      ).parse(endDateController.text); // Automatically set

      final rawStartTime = DateFormat(
        'hh:mm a',
      ).parse(startTimeController.text);
      final rawEndTime = DateFormat(
        'hh:mm a',
      ).parse(endTimeController.text); // Automatically set

      // Format for API
      final formattedStartDate = DateFormat('dd/MM/yyyy').format(rawStartDate);
      final formattedEndDate = DateFormat(
        'dd/MM/yyyy',
      ).format(rawEndDate); // Automatically set

      // final formattedStartTime = DateFormat('HH:mm:ss').format(rawStartTime);

      // final formattedStartTime = DateFormat('hh:mm a').format(rawStartTime);
      final formattedStartTime = DateFormat('hh:mm a').format(rawStartTime);
      final formattedEndTime = DateFormat(
        'HH:mm:ss',
      ).format(rawEndTime); // Automatically set

      final appointmentData = {
        'due_date': formattedStartDate,
        // 'end_date': formattedEndDate, // Automatically passed to API
        'time': formattedStartTime,
        // 'end_time': formattedEndTime, // Automatically passed to API
        'priority': selectedPriority,
        'subject': _selectedSubject,
        'sp_id': spId,
        'remarks': descriptionController.text,
      };

      final success = await LeadsSrv.submitAppoinment(
        appointmentData,
        _leadId!,
      );

      if (success) {
        if (context.mounted) {
          Navigator.pop(context, true);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Appointment created successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        // widget.onFormSubmit();
        widget.onFormSubmit?.call(); // Refresh dashboard data
        widget.onTabChange?.call(1);
      } else {
        showErrorMessage(context, message: 'Failed to submit appointment.');
      }
    } catch (e) {
      print(e.toString());
    }
  }
}
