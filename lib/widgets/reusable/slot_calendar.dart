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
