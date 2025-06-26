import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';

class SlotCalendar extends StatefulWidget {
  final String label;
  final bool isRequired;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final VoidCallback onTextFieldTap;
  final String vehicleId;
  final TextEditingController? controller; // Optional controller from parent

  const SlotCalendar({
    super.key,
    required this.label,
    this.isRequired = false,
    required this.onChanged,
    this.errorText,
    required this.onTextFieldTap,
    required this.vehicleId,
    this.controller,
  });

  @override
  State<SlotCalendar> createState() => _SlotCalendarState();
}

class _SlotCalendarState extends State<SlotCalendar> {
  DateTime? _selectedDate;
  String? _selectedSlot;
  List<String> availableSlots = []; // To store fetched slots
  bool _isCalendarVisible = false; // To control calendar visibility
  late TextEditingController _internalController;

  @override
  void initState() {
    super.initState();
    // Use provided controller or create internal one
    _internalController = widget.controller ?? TextEditingController();
    _fetchAvailableSlots();
  }

  @override
  void dispose() {
    // Only dispose if we created the internal controller
    if (widget.controller == null) {
      _internalController.dispose();
    }
    super.dispose();
  }

  // Fetch available slots from API
  Future<void> _fetchAvailableSlots() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.smartassistapp.in/api/slots/${widget.vehicleId}/slots/all',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          availableSlots = List<String>.from(data['slots']);
        });
      } else {
        throw Exception('Failed to load slots');
      }
    } catch (e) {
      print('Error fetching slots: $e');
    }
  }

  // Post selected slot and date to API
  Future<void> _selectSlot() async {
    if (_selectedDate != null && _selectedSlot != null) {
      final body = {
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'slot': _selectedSlot,
      };
      try {
        final response = await http.post(
          Uri.parse(
            'https://example.com/select-slot',
          ), // Replace with actual endpoint
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
        if (response.statusCode == 200) {
          final selectedDateFormatted = DateFormat(
            'MMM dd, yyyy',
          ).format(_selectedDate!);
          final displayText = '$_selectedSlot on $selectedDateFormatted';

          // Update controller text
          _internalController.text = displayText;

          // Call parent callback
          widget.onChanged(displayText);

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Slot booked successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception('Failed to book slot');
        }
      } catch (e) {
        print('Error booking slot: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to book slot. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleCalendar() {
    setState(() {
      _isCalendarVisible = !_isCalendarVisible;
    });
    widget.onTextFieldTap(); // Call parent callback
  }

  void _onDateSelected(DateTime selectedDate) {
    setState(() {
      _selectedDate = selectedDate;
      _isCalendarVisible = false; // Hide calendar after date selection
      _selectedSlot = null; // Reset slot selection when date changes
    });

    // Update text field with selected date
    final formattedDate = DateFormat('MMM dd, yyyy').format(selectedDate);
    _internalController.text = 'Selected: $formattedDate';
    widget.onChanged('Selected: $formattedDate');
  }

  // Get controller value for API use
  String get controllerValue => _internalController.text;

  // Get selected date and slot data for API
  Map<String, dynamic>? get selectedBookingData {
    if (_selectedDate != null && _selectedSlot != null) {
      return {
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'slot': _selectedSlot,
        'display_text': _internalController.text,
      };
    }
    return null;
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
                color: Colors.black,
              ),
              children: [
                TextSpan(text: widget.label),
                if (widget.isRequired)
                  const TextSpan(
                    text: " *",
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: _toggleCalendar,
          child: Container(
            height: 45,
            width: double.infinity,
            decoration: BoxDecoration(
              border: widget.errorText != null
                  ? Border.all(color: Colors.red, width: 1.0)
                  : Border.all(color: Colors.grey.shade300, width: 1.0),
              borderRadius: BorderRadius.circular(8),
              color: const Color.fromARGB(255, 248, 247, 247),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _internalController.text.isEmpty
                        ? "Select Date & Slot"
                        : _internalController.text,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _internalController.text.isEmpty
                          ? Colors.grey
                          : Colors.black,
                    ),
                  ),
                ),
                Icon(
                  _isCalendarVisible
                      ? Icons.keyboard_arrow_up
                      : Icons.calendar_month_outlined,
                  color: AppColors.fontColor,
                ),
              ],
            ),
          ),
        ),

        // Calendar Widget - Only show when _isCalendarVisible is true
        if (_isCalendarVisible)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: CalenderWidget(
              onDateSelected: _onDateSelected,
              selectedDate: _selectedDate,
            ),
          ),

        // Slot Selection - Only show when date is selected
        if (_selectedDate != null) ...[
          const SizedBox(height: 15),
          Text('Select Time Slot', style: AppFont.dropDowmLabel(context)),
          const SizedBox(height: 8),
          if (availableSlots.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Loading available slots...',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: availableSlots.map((slot) {
                final isSelected = _selectedSlot == slot;
                return ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedSlot = slot;
                    });
                    _selectSlot();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected
                        ? Colors.blue
                        : Colors.grey.shade200,
                    foregroundColor: isSelected ? Colors.white : Colors.black,
                    elevation: isSelected ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    slot,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],

        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              widget.errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class CalenderWidget extends StatefulWidget {
  final Function(DateTime) onDateSelected;
  final DateTime? selectedDate;

  const CalenderWidget({
    super.key,
    required this.onDateSelected,
    this.selectedDate,
  });

  @override
  State<CalenderWidget> createState() => _CalenderWidgetState();
}

class _CalenderWidgetState extends State<CalenderWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDate;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 15),
      child: TableCalendar(
        firstDay: DateTime.now(), // Prevent selecting past dates
        lastDay: DateTime.utc(2100, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          // Prevent selecting past dates
          if (selectedDay.isBefore(
            DateTime.now().subtract(const Duration(days: 1)),
          )) {
            return;
          }

          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          widget.onDateSelected(selectedDay);
        },
        calendarStyle: CalendarStyle(
          isTodayHighlighted: true,
          selectedDecoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue, width: 1),
            color: Colors.blue.withOpacity(0.1),
          ),
          todayTextStyle: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
          disabledDecoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade200,
          ),
          disabledTextStyle: TextStyle(color: Colors.grey.shade400),
          outsideDaysVisible: false,
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        enabledDayPredicate: (day) {
          // Disable past dates
          return !day.isBefore(
            DateTime.now().subtract(const Duration(days: 1)),
          );
        },
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:smartassist/config/component/font/font.dart';
// import 'dart:convert';

// import 'package:table_calendar/table_calendar.dart';

// class SlotCalendar extends StatefulWidget {
//   final String label;
//   final bool isRequired;
//   final ValueChanged<String> onChanged;
//   final String? errorText;
//   final VoidCallback onTextFieldTap;
//   final String vehicleId;
//   const SlotCalendar({
//     super.key,
//     required this.label,
//     this.isRequired = false,
//     required this.onChanged,
//     this.errorText,
//     required this.onTextFieldTap, required this.vehicleId,
//   });

//   @override
//   State<SlotCalendar> createState() => _SlotCalendarState();
// }

// class _SlotCalendarState extends State<SlotCalendar> {
//   DateTime? _selectedDate;
//   String? _selectedSlot;
//   List<String> availableSlots = []; // To store fetched slots

//   @override
//   void initState() {
//     super.initState();
//     _fetchAvailableSlots();
//   }

//   // Fetch available slots from API
//   Future<void> _fetchAvailableSlots() async {
//     try {
//       final response = await http.get(Uri.parse('https://api.smartassistapp.in/api/slots/${vehicleId}/slots/all'
// ));
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         setState(() {
//           availableSlots = List<String>.from(data['slots']);
//         });
//       } else {
//         throw Exception('Failed to load slots');
//       }
//     } catch (e) {
//       print('Error fetching slots: $e');
//     }
//   }

//   // Post selected slot and date to API
//   Future<void> _selectSlot() async {
//     if (_selectedDate != null && _selectedSlot != null) {
//       final body = {
//         'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
//         'slot': _selectedSlot,
//       };
//       try {
//         final response = await http.post(
//           Uri.parse('https://example.com/select-slot'),
//           headers: {'Content-Type': 'application/json'},
//           body: jsonEncode(body),
//         );
//         if (response.statusCode == 200) {
//           widget.onChanged(
//             'Slot booked: $_selectedSlot on ${_selectedDate!.toLocal()}',
//           );
//         } else {
//           throw Exception('Failed to book slot');
//         }
//       } catch (e) {
//         print('Error booking slot: $e');
//       }
//     }
//   }

//   @override
//   Widget  build(BuildContext context, dynamic controller) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 5),
//           child: RichText(
//             text: TextSpan(
//               style: GoogleFonts.poppins(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w500,
//                 color: Colors.black,
//               ),
//               children: [
//                 TextSpan(text: widget.label),
//                 if (widget.isRequired)
//                   const TextSpan(
//                     text: " *",
//                     style: TextStyle(color: Colors.red),
//                   ),
//               ],
//             ),
//           ),
//         ),
//         GestureDetector(
//           // onTap: //
//           // ,
//           child: Container(
//             height: 45,
//             width: double.infinity,
//             decoration: BoxDecoration(
//               border: widget.errorText != null
//                   ? Border.all(color: Colors.red, width: 1.0)
//                   : null,
//               borderRadius: BorderRadius.circular(8),
//               color: const Color.fromARGB(255, 248, 247, 247),
//             ),
//             padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Expanded(
//                   child: Text(
//                     controller.text.isEmpty ? "Select" : controller.text,
//                     style: GoogleFonts.poppins(
//                       fontSize: 14,
//                       fontWeight: FontWeight.w500,
//                       color: controller.text.isEmpty
//                           ? Colors.grey
//                           : Colors.black,
//                     ),
//                   ),
//                 ),
//                 Icon(Icons.calendar_month_outlined, color: AppColors.fontColor),
//               ],
//             ),
//           ),
//         ),
//         CalenderWidget(
//           onDateSelected: (date) {
//             setState(() {
//               _selectedDate = date;
//             });
//           },
//         ),
//         const SizedBox(height: 10),
//         Text('Select Slot', style: AppFont.dropDowmLabel(context)),
//         Container(margin: EdgeInsets.symmetric(vertical: 5)),
//         Wrap(
//           spacing: 8.0,
//           children: availableSlots.map((slot) {
//             return ElevatedButton(
//               onPressed: _selectedDate == null
//                   ? null
//                   : () {
//                       setState(() {
//                         _selectedSlot = slot;
//                       });
//                       _selectSlot();
//                     },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: _selectedSlot == slot ? Colors.blue : null,
//               ),
//               child: Text(slot),
//             );
//           }).toList(),
//         ),
//         if (widget.errorText != null)
//           Text(widget.errorText!, style: TextStyle(color: Colors.red)),
//       ],
//     );
//   }
// }

// class CalenderWidget extends StatefulWidget {
//   final Function(DateTime) onDateSelected;

//   const CalenderWidget({super.key, required this.onDateSelected});

//   @override
//   State<CalenderWidget> createState() => _CalenderWidgetState();
// }

// class _CalenderWidgetState extends State<CalenderWidget> {
//   DateTime _focusedDay = DateTime.now();
//   DateTime? _selectedDay;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: Colors.white,
//       padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 15),
//       child: TableCalendar(
//         firstDay: DateTime.utc(2000, 1, 1),
//         lastDay: DateTime.utc(2100, 12, 31),
//         focusedDay: _focusedDay,
//         selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
//         onDaySelected: (selectedDay, focusedDay) {
//           setState(() {
//             _selectedDay = selectedDay;
//             _focusedDay = focusedDay;
//           });
//           widget.onDateSelected(selectedDay);
//         },
//         calendarStyle: CalendarStyle(
//           isTodayHighlighted: true,
//           selectedDecoration: const BoxDecoration(
//             color: Colors.blue,
//             shape: BoxShape.circle,
//           ),
//           todayDecoration: BoxDecoration(
//             shape: BoxShape.circle,
//             border: Border.all(color: Colors.black, width: 2),
//           ),
//           todayTextStyle: const TextStyle(color: Colors.black),
//         ),
//         headerStyle: const HeaderStyle(
//           formatButtonVisible: false,
//           titleCentered: true,
//         ),
//       ),
//     );
//   }
// }
