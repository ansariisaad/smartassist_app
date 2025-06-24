import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartassist/services/api_srv.dart';
import 'package:smartassist/utils/snackbar_helper.dart';
import 'package:smartassist/widgets/google_location.dart';
import 'package:smartassist/widgets/popups_widget/leadSearch_textfield.dart';
import 'package:smartassist/widgets/popups_widget/vehicleSearch_textfield.dart';
import 'package:smartassist/widgets/remarks_field.dart';
import 'package:smartassist/widgets/reusable/date_button.dart';
import 'package:smartassist/widgets/reusable/leadsearch_testdrive.dart';
import 'package:smartassist/widgets/reusable/slot_calendar.dart';

class CreateTestdrive extends StatefulWidget {
  final Function onFormSubmit;
  final Function(int)? onTabChange;
  const CreateTestdrive({
    super.key,
    required this.onFormSubmit,
    this.onTabChange,
  });

  @override
  State<CreateTestdrive> createState() => _CreateTestdriveState();
}

class _CreateTestdriveState extends State<CreateTestdrive> {
  String? _leadId;
  String? _leadName;
  bool isSubmitting = false;
  String? selectedVehicleName;
  String? selectedBrand;
  Map<String, dynamic>? selectedVehicleData;
  // final PageController _pageController = PageController();
  List<Map<String, String>> dropdownItems = [];
  bool isLoading = false;
  Map<String, String> _errors = {};

  String? selectedLeads;
  String? selectedLeadsName;
  String? selectedPriority;
  List<dynamic> vehicleList = [];
  List<String> uniqueVehicleNames = [];
  // String? selectedVehicleName;
  // List<dynamic> _searchResults = [];
  List<String> colorOptions = [];
  String? selectedColor;
  String? selectedExteriorColor;
  String? selectedInteriorColor;
  List<String> exteriorOptions = [];
  List<String> interiorOptions = [];

  // List<dynamic> _searchResults = [];
  List<dynamic> vehicleName = [];

  // Google Maps API key
  final String _googleApiKey = "AIzaSyCaFZ4RXQIy86v9B24wz5l0vgDKbQSP5LE";

  final TextEditingController _locationController = TextEditingController();
  TextEditingController startDateController = TextEditingController();
  TextEditingController endDateController = TextEditingController();
  TextEditingController startTimeController = TextEditingController();
  TextEditingController endTimeController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
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

      if (selectedVehicleName == null || selectedVehicleName!.isEmpty) {
        _errors['select_vehicle'] = 'Please select an action';
        isValid = false;
      }

      if (startDateController == null || startDateController.text!.isEmpty) {
        _errors['date'] = 'Please select an action';
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
      firstDate: DateTime(2000),
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
              'Create Test Drive',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LeadTextfield(
              //   isRequired: true,
              //   onChanged: (value) {
              //     if (_errors.containsKey('select lead name')) {
              //       setState(() {
              //         _errors.remove('select lead name');
              //       });
              //     }
              //     print("select lead name : $value");
              //   },
              //   errorText: _errors['select lead name'],
              //   onLeadSelected: (leadId, leadName) {
              //     setState(() {
              //       _leadId = leadId;
              //       _leadName = leadName;
              //     });
              //   },
              // ),
              LeadsearchTestdrive(
                errorText: '', // Empty error text as provided
                onChanged: (String value) {
                  if (_errors.containsKey('select lead name')) {
                    setState(() {
                      _errors.remove('select lead name');
                    });
                  }
                  // Handle lead search input changes
                  print('Lead search input changed: $value');
                },
                isRequired: true, // Set to true if lead selection is mandatory
                // onLeadSelected: (String leadId, String leadName) {
                onLeadSelected: (leadId, leadName) {
                  setState(() {
                    _leadId = leadId;
                    _leadName = leadName;
                  });

                  // Handle lead selection
                  print('Lead selected: ID = $leadId, Name = $leadName');
                },
                onClearSelection: () {
                  // Handle clearing of lead selection
                  print('Lead selection cleared');
                },
                onVehicleSelected: (Map<String, dynamic> selectedVehicle) {
                  setState(() {
                    selectedVehicleData = selectedVehicle;
                    selectedVehicleName = selectedVehicle['vehicle_name'];
                    selectedBrand =
                        selectedVehicle['brand'] ?? ''; // Handle null brand
                  });
                },
              ),

              // VehiclesearchTextfield(
              //   errorText: _errors['select_vehicle'],
              //   onVehicleSelected: (selectedVehicle) {
              //     setState(() {
              //       if (_errors.containsKey('select vehicle ')) {
              //         setState(() {
              //           _errors.remove('select vehicle');
              //         });
              //       }
              //       selectedVehicleData = selectedVehicle;
              //       selectedVehicleName = selectedVehicle['vehicle_name'];
              //       selectedBrand =
              //           selectedVehicle['brand'] ?? ''; // Handle null brand
              //     });

              //     print("Selected Vehicle: $selectedVehicleName");
              //     print("Selected Brand: ${selectedBrand ?? 'No Brand'}");
              //   },
              //   //  errorText: _errors['select lead name'],
              // ),
              const SizedBox(height: 5),
              CustomGooglePlacesField(
                controller: _locationController,
                hintText: 'Enter location',
                label: 'Location',
                onChanged: (value) {
                  // if (_locationErrorText != null) {
                  //   _validateLocation();
                  // }
                },
                googleApiKey: _googleApiKey,
                isRequired: true,
              ),
              const SizedBox(height: 15),

              // DateButton(
              //   errorText: _errors['date'],
              //   isRequired: true,
              //   label: 'Start',
              //   dateController: startDateController,
              //   timeController: startTimeController,
              //   onDateTap: _pickStartDate,
              //   onTimeTap: _pickStartTime,
              //   onChanged: (String value) {},
              // ),
              // SlotCalendar(label: 'Select Slot', onChanged: (value) {}, onTextFieldTap: () {  }, vehicleId: '',),

              DateButton(
                errorText: _errors['date'],
                isRequired: true,
                label: 'Start',
                dateController: startDateController,
                timeController: startTimeController,
                onDateTap: _pickStartDate,
                onTimeTap: _pickStartTime,
                onChanged: (String value) {},
              ),
              const SizedBox(height: 10),
              // _buildTextField(
              //   label: 'Remarks :',
              //   controller: descriptionController,
              //   hint: 'Type or speak...',
              // ),
              EnhancedSpeechTextField(
                isRequired: false,
                // contentPadding: EdgeInsets.zero,
                label: 'Remarks:',
                controller: descriptionController,
                hint: 'Type or speak... ',
                onChanged: (text) {
                  print('Text changed: $text');
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
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

  Future<void> submitForm() async {
    // Retrieve sp_id from SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    final spId = prefs.getString('user_id');

    // Parse and format the selected dates/times.
    final rawStartDate = DateFormat(
      'dd MMM yyyy',
    ).parse(startDateController.text);
    final rawEndDate = DateFormat(
      'dd MMM yyyy',
    ).parse(endDateController.text); // Automatically set

    final rawStartTime = DateFormat('hh:mm a').parse(startTimeController.text);
    final rawEndTime = DateFormat(
      'hh:mm a',
    ).parse(endTimeController.text); // Automatically set

    // Format for API
    final formattedStartDate = DateFormat('dd/MM/yyyy').format(rawStartDate);
    final formattedEndDate = DateFormat(
      'dd/MM/yyyy',
    ).format(rawEndDate); // Automatically set

    // final formattedStartTime = DateFormat('HH:mm:ss').format(rawStartTime);
    final formattedStartTime = DateFormat('hh:mm a').format(rawStartTime);
    final formattedEndTime = DateFormat(
      'HH:mm:ss',
    ).format(rawEndTime); // Automatically set

    // Prepare the appointment data.
    final testdriveData = {
      'start_date': formattedStartDate,
      'end_date': formattedEndDate,
      'start_time': formattedStartTime,
      'end_time': formattedEndTime,
      'PMI': selectedVehicleName,
      'location': _locationController.text,
      'sp_id': spId,
      'remarks': descriptionController.text,
    };

    // Call the service to submit the appointment.
    final success = await LeadsSrv.submitTestDrive(testdriveData, _leadId!);

    if (success) {
      if (context.mounted) {
        Navigator.pop(context, true); // Close the modal on success.
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Form Submit Successful.')));
      widget.onFormSubmit?.call(); // Refresh dashboard data
      widget.onTabChange?.call(2);
    } else {
      showErrorMessage(context, message: 'Failed to submit appointment.');
    }
  }
}
