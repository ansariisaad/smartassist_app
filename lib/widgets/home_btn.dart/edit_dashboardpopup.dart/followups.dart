import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartassist/utils/snackbar_helper.dart';
import 'package:smartassist/widgets/remarks_field.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class FollowupsEdit extends StatefulWidget {
  final String taskId;
  final Function onFormSubmit;

  const FollowupsEdit({
    super.key,
    required this.onFormSubmit,
    required this.taskId,
  });

  @override
  State<FollowupsEdit> createState() => _FollowupsEditState();
}

class _FollowupsEditState extends State<FollowupsEdit> {
  Map<String, String> _errors = {};
  TextEditingController startTimeController = TextEditingController();
  TextEditingController startDateController = TextEditingController();
  TextEditingController endTimeController = TextEditingController();
  TextEditingController endDateController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  TextEditingController modelInterestController = TextEditingController();
  final TextEditingController statusController = TextEditingController();

  List<dynamic> _searchResults = [];
  bool _isLoadingSearch = false;
  String? selectedLeads;
  String? selectedLeadsName;
  String? selectedStatus;
  late stt.SpeechToText _speech;
  bool _isListening = false;

  bool isButtonEnabled = false;

  // Store initial values for comparison
  String? _initialStatus;
  String? _initialRemarks;
  String? _initialDeferredReason;

  // New variables for nested dropdown
  String? selectedDeferredReason;

  @override
  void initState() {
    super.initState();
    _fetchDataId();
    _speech = stt.SpeechToText();
    _initSpeech();
    // Add listener to descriptionController for real-time change detection
    descriptionController.addListener(_checkIfFormIsComplete);
  }

  @override
  void dispose() {
    _searchController.dispose();
    descriptionController.removeListener(_checkIfFormIsComplete);
    descriptionController.dispose();
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
            _checkIfFormIsComplete();
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    }
  }

  Future<void> _fetchDataId() async {
    setState(() {
      _isLoadingSearch = true;
    });

    final token = await Storage.getToken();

    try {
      final response = await http.get(
        Uri.parse('https://api.smartassistapp.in/api/tasks/${widget.taskId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String comment = data['data']['remarks'] ?? '';
        final String status = data['data']['status'] ?? '';
        final String deferredReason = data['data']['deferred_reason'] ?? '';

        setState(() {
          descriptionController.text = comment;
          _initialRemarks = comment;

          if (items.contains(status)) {
            selectedValue = status;
            _initialStatus = status;
          }

          // Set deferred reason if status is deferred
          if (status == 'Deferred' &&
              deferredReasons.contains(deferredReason)) {
            selectedDeferredReason = deferredReason;
            _initialDeferredReason = deferredReason;
          }

          _checkIfFormIsComplete();
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

  bool get _hasRemarksError => descriptionController.text.trim().isEmpty;
  bool get _hasDeferredError =>
      selectedValue == 'Deferred' && selectedDeferredReason == null;

  // void _checkIfFormIsComplete() {
  //   setState(() {
  //     bool statusChanged = selectedValue != _initialStatus;
  //     // bool remarksChanged =
  //     //     descriptionController.text.trim() != (_initialRemarks ?? '').trim();
  //     bool deferredReasonChanged =
  //         selectedDeferredReason != _initialDeferredReason;

  //     // Check if deferred is selected but no reason is chosen
  //     bool isDeferredValid =
  //         selectedValue != 'Deferred' || selectedDeferredReason != null;

  //     // Check if remarks field is valid (not empty when required)
  //     bool remarksValid = descriptionController.text.trim().isNotEmpty;

  //     // Enable button if any field changed and all validations pass
  //     isButtonEnabled =
  //         (statusChanged || deferredReasonChanged) && isDeferredValid;
  //   });
  // }

  void _checkIfFormIsComplete() {
    setState(() {
      bool statusChanged = selectedValue != _initialStatus;
      bool remarksChanged =
          descriptionController.text.trim() != (_initialRemarks ?? '').trim();
      bool deferredReasonChanged =
          selectedDeferredReason != _initialDeferredReason;

      // Check if deferred is selected but no reason is chosen
      bool isDeferredValid =
          selectedValue != 'Deferred' || selectedDeferredReason != null;

      // Enable button if any field changed and all validations pass
      isButtonEnabled =
          (statusChanged || remarksChanged || deferredReasonChanged) &&
          isDeferredValid;
    });
  }

  void _submit() {
    // Validate deferred reason if deferred is selected
    if (selectedValue == 'Deferred' && selectedDeferredReason == null) {
      showErrorMessage(
        context,
        message: 'Please select a reason for deferring',
      );
      return;
    }

    // Validate remarks field
    // if (descriptionController.text.trim().isEmpty) {
    //   showErrorMessage(context, message: 'Please enter remarks');
    //   return;
    // }

    FocusScope.of(context).unfocus(); // Close keyboard
    submitForm();
  }

  Future<void> submitForm() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? spId = prefs.getString('user_id');
    final token = await Storage.getToken();

    if (spId == null) {
      showErrorMessage(
        context,
        message: 'User ID not found. Please log in again.',
      );
      return;
    }

    final newTaskForLead = {
      'comments': descriptionController.text,
      'status': selectedValue,
      'sp_id': spId,
      if (selectedValue == 'Deferred' && selectedDeferredReason != null)
        'deferred_reason': selectedDeferredReason,
    };

    print('Sending PUT request body: ${jsonEncode(newTaskForLead)}');

    try {
      final response = await http.put(
        Uri.parse(
          'https://api.smartassistapp.in/api/tasks/${widget.taskId}/update',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(newTaskForLead),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        Navigator.pop(context, true);
        showSuccessMessage(context, message: 'Follow-up updated successfully');
        widget.onFormSubmit();
      } else {
        final Map<String, dynamic> responseData = json.decode(response.body);
        String message =
            responseData['message'] ?? 'Submission failed. Try again.';
        showErrorMessage(context, message: message);
      }
    } catch (e) {
      showErrorMessage(
        context,
        message: 'Something went wrong. Please try again.',
      );
      print('Error during PUT request: $e');
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: AppColors.containerBg,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    _checkIfFormIsComplete();
                  },
                  controller: controller,
                  maxLines: null,
                  minLines: 1,
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

  final List<String> items = ['Completed', 'Deferred'];
  final List<String> deferredReasons = [
    'Client unreacheable',
    'Not interested',
  ];
  String? selectedValue;

  List<DropdownMenuItem<String>> _addDividersAfterItems(List<String> items) {
    final List<DropdownMenuItem<String>> menuItems = [];
    for (final String item in items) {
      menuItems.addAll([
        DropdownMenuItem<String>(
          value: item,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(item, style: AppFont.dropDowmLabel(context)),
          ),
        ),
        if (item != items.last)
          const DropdownMenuItem<String>(enabled: false, child: Divider()),
      ]);
    }
    return menuItems;
  }

  List<DropdownMenuItem<String>> _addDividersAfterDeferredReasons(
    List<String> reasons,
  ) {
    final List<DropdownMenuItem<String>> menuItems = [];
    for (final String reason in reasons) {
      menuItems.addAll([
        DropdownMenuItem<String>(
          value: reason,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(reason, style: AppFont.dropDowmLabel(context)),
          ),
        ),
        if (reason != reasons.last)
          const DropdownMenuItem<String>(enabled: false, child: Divider()),
      ]);
    }
    return menuItems;
  }

  List<double> _getCustomItemsHeights() {
    final List<double> itemsHeights = [];
    for (int i = 0; i < (items.length * 2) - 1; i++) {
      if (i.isEven) {
        itemsHeights.add(40);
      }
      if (i.isOdd) {
        itemsHeights.add(4);
      }
    }
    return itemsHeights;
  }

  List<double> _getCustomDeferredItemsHeights() {
    final List<double> itemsHeights = [];
    for (int i = 0; i < (deferredReasons.length * 2) - 1; i++) {
      if (i.isEven) {
        itemsHeights.add(40);
      }
      if (i.isOdd) {
        itemsHeights.add(4);
      }
    }
    return itemsHeights;
  }

  Widget _buildDeferredReasonDropdown() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: selectedValue == 'Deferred' ? null : 0,
      child: selectedValue == 'Deferred'
          ? Column(
              children: [
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 5),

                          // child: Text(
                          //   'Reason :',
                          //   style: AppFont.dropDowmLabel(context),
                          // ),
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.fontBlack,
                              ),
                              children: [
                                TextSpan(text: 'Reason :'),
                                const TextSpan(
                                  text: " *",
                                  style: TextStyle(color: Colors.red),
                                ),
                                // TextSpan(text: ':'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLightGrey,
                          borderRadius: BorderRadius.circular(10),
                          border: _hasDeferredError
                              ? Border.all(
                                  color: Colors.red.withOpacity(0.5),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton2<String>(
                            style: const TextStyle(color: AppColors.fontColor),
                            isExpanded: true,
                            hint: Text(
                              'Select Reason',
                              style: AppFont.dropDowmLabelLightcolors(context),
                            ),
                            items: _addDividersAfterDeferredReasons(
                              deferredReasons,
                            ),
                            value: selectedDeferredReason,
                            onChanged: (String? value) {
                              setState(() {
                                selectedDeferredReason = value;
                                _checkIfFormIsComplete();
                              });
                            },
                            buttonStyleData: const ButtonStyleData(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              height: 40,
                              width: double.infinity,
                            ),
                            dropdownStyleData: const DropdownStyleData(
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(2),
                                ),
                              ),
                              maxHeight: 200,
                            ),
                            menuItemStyleData: MenuItemStyleData(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              customHeights: _getCustomDeferredItemsHeights(),
                            ),
                            iconStyleData: const IconStyleData(
                              openMenuIcon: Icon(Icons.arrow_drop_down),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // if (_hasDeferredError)
                //   Container(
                //     margin: const EdgeInsets.only(top: 5),
                //     alignment: Alignment.centerLeft,
                //     child: Text(
                //       'Please select a reason for deferring',
                //       style: TextStyle(
                //         color: Colors.red,
                //         fontSize: 12,
                //         fontWeight: FontWeight.w400,
                //       ),
                //     ),
                //   ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Update Follow up',
                      style: AppFont.popupTitleBlack(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        // child: Text(
                        //   'Status :',
                        //   style: AppFont.dropDowmLabel(context),
                        // ),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                            children: [
                              TextSpan(text: 'Status :'),
                              // if (widget.isRequired)
                              const TextSpan(
                                text: " *",
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLightGrey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton2<String>(
                          style: const TextStyle(color: AppColors.fontColor),
                          isExpanded: true,
                          hint: Text(
                            'Select status',
                            style: AppFont.dropDowmLabelLightcolors(context),
                          ),
                          items: _addDividersAfterItems(items),
                          value: selectedValue,
                          onChanged: (String? value) {
                            setState(() {
                              selectedValue = value;
                              // Reset deferred reason when status changes
                              if (value != 'Deferred') {
                                selectedDeferredReason = null;
                              }
                              _checkIfFormIsComplete();
                            });
                          },
                          buttonStyleData: const ButtonStyleData(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            height: 40,
                            width: double.infinity,
                          ),
                          dropdownStyleData: const DropdownStyleData(
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.all(
                                Radius.circular(2),
                              ),
                            ),
                            maxHeight: 200,
                          ),
                          menuItemStyleData: MenuItemStyleData(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            customHeights: _getCustomItemsHeights(),
                          ),
                          iconStyleData: const IconStyleData(
                            openMenuIcon: Icon(Icons.arrow_drop_down),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Nested dropdown for deferred reasons
              _buildDeferredReasonDropdown(),
              const SizedBox(height: 10),
              EnhancedSpeechTextField(
                isRequired: false,
                error: _hasRemarksError,
                label: 'Remarks :',
                controller: descriptionController,
                hint: 'Type or speak... ',
                onChanged: (text) {
                  _checkIfFormIsComplete();
                  print('Text changed: $text');
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.cancelButton,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        textAlign: TextAlign.center,
                        style: AppFont.buttons(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: isButtonEnabled
                            ? AppColors.colorsBlue
                            : AppColors.cancelButton,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      onPressed: isButtonEnabled ? _submit : null,
                      child: Text("Update", style: AppFont.buttons(context)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
