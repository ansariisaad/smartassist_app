// import 'dart:async';
// import 'dart:math';

// import 'package:external_app_launcher/external_app_launcher.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:smartassist/config/component/font/font.dart';
// import 'package:smartassist/utils/storage.dart';
// import 'package:smartassist/utils/token_manager.dart';
// import 'package:socket_io_client/socket_io_client.dart' as IO;
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'dart:convert';

// class Message {
//   final String body;
//   final bool fromMe;
//   final int timestamp;
//   final String type;
//   final String? mediaUrl;
//   final String? id; // Add this field

//   Message({
//     required this.body,
//     required this.fromMe,
//     required this.timestamp,
//     required this.type,
//     this.mediaUrl,
//     this.id, // Add this field
//   });

//   factory Message.fromJson(Map<String, dynamic> json) {
//     return Message(
//       body: json['body'] ?? '',
//       fromMe: json['fromMe'] ?? false,
//       timestamp:
//           json['timestamp'] ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
//       type: json['type'] ?? 'chat',
//       mediaUrl: json['mediaUrl'],
//       id: json['id'], // Parse the ID
//     );
//   }
// }

// class MessageBubble extends StatefulWidget {
//   final Message message;
//   final String timeString;

//   const MessageBubble({
//     Key? key,
//     required this.message,
//     required this.timeString,
//   }) : super(key: key);

//   @override
//   State<MessageBubble> createState() => _MessageBubbleState();
// }

// class _MessageBubbleState extends State<MessageBubble> {
//   @override
//   Widget build(BuildContext context) {
//     return Align(
//       alignment: widget.message.fromMe
//           ? Alignment.centerRight
//           : Alignment.centerLeft,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 3),
//         constraints: BoxConstraints(
//           maxWidth: MediaQuery.of(context).size.width * 0.75,
//         ),
//         decoration: BoxDecoration(
//           color: widget.message.fromMe
//               ? const Color.fromARGB(255, 198, 210, 248)
//               : Colors.white,
//           borderRadius: BorderRadius.circular(8),
//           boxShadow: [
//             BoxShadow(
//               offset: const Offset(0, 1),
//               blurRadius: 2,
//               color: Colors.black.withOpacity(0.1),
//             ),
//           ],
//         ),
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [
//             if (widget.message.type == 'image' &&
//                 widget.message.mediaUrl != null)
//               ClipRRect(
//                 borderRadius: BorderRadius.circular(6),
//                 child: Image.network(
//                   widget.message.mediaUrl!,
//                   width: double.infinity,
//                   fit: BoxFit.cover,
//                   errorBuilder: (context, error, stackTrace) => Container(
//                     height: 150,
//                     color: Colors.grey[300],
//                     alignment: Alignment.center,
//                     child: const Text("Error loading image"),
//                   ),
//                 ),
//               ),
//             if (widget.message.body.isNotEmpty)
//               Text(widget.message.body, style: const TextStyle(fontSize: 16)),
//             const SizedBox(height: 2),
//             Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   widget.timeString,
//                   style: TextStyle(fontSize: 11, color: Colors.grey[600]),
//                 ),
//                 if (widget.message.fromMe) const SizedBox(width: 3),
//                 if (widget.message.fromMe)
//                   const Icon(
//                     Icons.done_all,
//                     size: 14,
//                     color: Color(0xFF34B7F1),
//                   ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class WhatsappChat extends StatefulWidget {
//   final String chatId;
//   final String userName;

//   const WhatsappChat({super.key, required this.chatId, required this.userName});

//   @override
//   State<WhatsappChat> createState() => _WhatsappChatState();
// }

// class _WhatsappChatState extends State<WhatsappChat>
//     with WidgetsBindingObserver {
//   List<Message> messages = [];
//   bool isLoading = false;
//   bool isWhatsAppLoading = false; // New loading state for WhatsApp client
//   String loadingMessage = ''; // Message to show during loading
//   String spId = '';
//   String email = '';
//   bool isWhatsAppReady = false;
//   bool isCheckingStatus = true;
//   Timer? _reconnectTimer;

//   final TextEditingController _messageController = TextEditingController();
//   late IO.Socket socket;
//   bool isConnected = false;
//   final ScrollController _scrollController = ScrollController();

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this); // Observe app lifecycle
//     loadInitialData();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);
//     print('AppLifecycleState: $state');
//     if (state == AppLifecycleState.resumed) {
//       // App is back in foreground, attempt to reconnect socket immediately
//       _stopReconnectTimer();
//       if (!isConnected) {
//         print('App resumed, forcing socket reconnect');
//         socket.connect();
//         // Delay status check to allow socket connection
//         Future.delayed(Duration(seconds: 1), () {
//           if (mounted && !isWhatsAppReady) {
//             checkWhatsAppStatus();
//           }
//         });
//       }
//     } else if (state == AppLifecycleState.paused ||
//         state == AppLifecycleState.hidden) {
//       // App is in background or hidden, start reconnection attempts
//       print('App paused or hidden, starting reconnect timer');
//       _startReconnectTimer();
//     }
//   }

//   void _startReconnectTimer() {
//     _reconnectTimer?.cancel();
//     int attempt = 0;
//     const maxAttempts = 10;
//     const baseDelay = 2000; // Start with 2 seconds
//     const maxDelay = 10000; // Cap at 10 seconds

//     _reconnectTimer = Timer.periodic(Duration(milliseconds: baseDelay), (
//       timer,
//     ) async {
//       if (!isConnected && mounted && attempt < maxAttempts) {
//         print(
//           'Attempting to reconnect socket... (Attempt ${attempt + 1}/$maxAttempts)',
//         );
//         socket.connect();
//         attempt++;
//         // Increase delay with exponential backoff
//         final delay = (baseDelay * pow(1.5, attempt)).toInt().clamp(
//           baseDelay,
//           maxDelay,
//         );
//         if (delay > baseDelay) {
//           timer.cancel();
//           _reconnectTimer = Timer.periodic(Duration(milliseconds: delay), (t) {
//             if (!isConnected && mounted && attempt < maxAttempts) {
//               print(
//                 'Attempting to reconnect socket... (Attempt ${attempt + 1}/$maxAttempts)',
//               );
//               socket.connect();
//               attempt++;
//             } else {
//               t.cancel();
//             }
//           });
//         }
//       } else {
//         timer.cancel();
//       }
//     });
//   }

//   void _stopReconnectTimer() {
//     _reconnectTimer?.cancel();
//     _reconnectTimer = null;
//   }

//   Future<void> loadInitialData() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     spId = prefs.getString('user_id') ?? '';
//     email = await TokenManager.getUserEmail() ?? '';
//     print('this is spid $spId');
//     initSocket(); // Initialize socket first
//     await checkWhatsAppStatus(); // Check status after socket is initialized
//   }

//   Future<void> checkWhatsAppStatus() async {
//     setState(() {
//       isCheckingStatus = true;
//     });
//     try {
//       final url = Uri.parse(
//         'https://api.smartassistapp.in/api/check-wa-status',
//       );
//       final token = await Storage.getToken();
//       final response = await http.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         body: json.encode({'sessionId': spId}),
//       );

//       print(
//         'Check WA Status Response: ${response.statusCode} - ${response.body}',
//       );

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         setState(() {
//           isWhatsAppReady = data['isReady'] ?? false;
//           isCheckingStatus = false;
//         });
//         // Remove direct socket.emit; rely on socket's onConnect
//       } else {
//         print('Failed to check WhatsApp status: ${response.body}');
//         setState(() {
//           isWhatsAppReady = false;
//           isCheckingStatus = false;
//         });
//         Get.snackbar(
//           'Error',
//           'Failed to check WhatsApp status',
//           backgroundColor: Colors.red,
//           colorText: Colors.white,
//         );
//       }
//     } catch (e) {
//       print('Error checking WhatsApp status: $e');
//       setState(() {
//         isWhatsAppReady = false;
//         isCheckingStatus = false;
//       });
//       Get.snackbar(
//         'Error',
//         'Failed to check WhatsApp status',
//         backgroundColor: Colors.red,
//         colorText: Colors.white,
//       );
//     }
//   }

//   Future<void> initWhatsAppChat(BuildContext context) async {
//     if (isWhatsAppReady || isLoading) return;
//     setState(() {
//       isLoading = true;
//     });
//     try {
//       final url = Uri.parse('https://api.smartassistapp.in/api/init-wa');
//       final token = await Storage.getToken();
//       final response = await http.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         body: json.encode({'sessionId': spId, 'email': email}),
//       );

//       print(url.toString());

//       print('Init WA Response: ${response.statusCode} - ${response.body}');

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         if (data['isReady'] == true) {
//           setState(() {
//             isWhatsAppReady = true;
//           });
//           socket.emit('get_messages', {
//             'sessionId': spId,
//             'chatId': widget.chatId,
//           });
//         } else {
//           await launchWhatsAppScanner();
//         }
//       } else {
//         final errorMessage =
//             json.decode(response.body)['message'] ?? 'Unknown error';
//         Get.snackbar(
//           'Error',
//           errorMessage,
//           backgroundColor: Colors.red,
//           colorText: Colors.white,
//         );
//       }
//     } catch (e) {
//       print('Error initializing WhatsApp chat: $e');
//       Get.snackbar(
//         'Error',
//         'Failed to initialize WhatsApp chat',
//         backgroundColor: Colors.red,
//         colorText: Colors.white,
//       );
//     } finally {
//       setState(() {
//         isLoading = false;
//       });
//     }
//   }

//   Future<void> launchWhatsAppScanner() async {
//     try {
//       await LaunchApp.openApp(
//         androidPackageName: 'com.whatsapp',
//         iosUrlScheme: 'whatsapp://',
//         appStoreLink:
//             'https://play.google.com/store/apps/details?id=com.whatsapp',
//       );
//       print('WhatsApp launched successfully');
//     } catch (e) {
//       print('Error launching WhatsApp: $e');
//       Get.snackbar(
//         'Error',
//         e.toString().contains('not installed')
//             ? 'Please install WhatsApp to continue'
//             : 'Failed to open WhatsApp',
//         backgroundColor: Colors.red,
//         colorText: Colors.white,
//       );
//     }
//   }

//   String formatTimestamp(int timestamp) {
//     final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
//       timestamp * 1000,
//     );
//     final now = DateTime.now();
//     final today = DateTime(now.year, now.month, now.day);
//     final yesterday = today.subtract(const Duration(days: 1));
//     final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

//     final timeFormat = DateFormat('HH:mm');
//     if (messageDate == today) {
//       return timeFormat.format(dateTime);
//     } else if (messageDate == yesterday) {
//       return 'Yesterday, ${timeFormat.format(dateTime)}';
//     } else {
//       return DateFormat('MMM d, HH:mm').format(dateTime);
//     }
//   }

//   void initSocket() {
//     socket = IO.io('wss://api.smartassistapp.in', <String, dynamic>{
//       'transports': ['websocket'],
//       'autoConnect': true,
//       'reconnection': true,
//       'reconnectionAttempts': 10,
//       'reconnectionDelay': 1000,
//       'reconnectionDelayMax': 5000,
//       'timeout': 20000,
//     });

//     socket.onConnect((_) {
//       print('Socket connected');
//       _stopReconnectTimer();
//       socket.emit('register_session', {'sessionId': spId});
//       print('Emitted register_session: sessionId=$spId');
//       setState(() {
//         isConnected = true;
//       });
//       if (isWhatsAppReady) {
//         socket.emit('get_messages', {
//           'sessionId': spId,
//           'chatId': widget.chatId,
//         });
//         print('Requesting messages for chat ID: ${widget.chatId}');
//       }
//     });

//     socket.onDisconnect((_) {
//       print('Socket disconnected');
//       setState(() {
//         isConnected = false;
//       });
//       _startReconnectTimer();
//     });

//     socket.onConnectError((error) {
//       print('Connection error: $error');
//       setState(() {
//         isConnected = false;
//       });
//       _startReconnectTimer();
//     });

//     // New socket listener for WhatsApp loading started
//     socket.on('wa_loading_started', (data) {
//       print('WA Loading Started: $data');
//       setState(() {
//         isWhatsAppLoading = true;
//         loadingMessage = data['message'] ?? 'Starting WhatsApp client...';
//       });
//     });

//     socket.on('wa_login_success', (data) {
//       print('WA Login Success: $data');
//       setState(() {
//         isWhatsAppReady = true;
//         isWhatsAppLoading = false; // Stop loading when login is successful
//         loadingMessage = '';
//       });
//       socket.emit('get_messages', {'sessionId': spId, 'chatId': widget.chatId});
//     });

//     socket.on('wa_auth_failure', (data) {
//       print('WA Auth Failure: $data');
//       setState(() {
//         isWhatsAppReady = false;
//         isWhatsAppLoading = false; // Stop loading on failure
//         loadingMessage = '';
//       });
//       Get.snackbar(
//         'Error',
//         data['error'] ?? 'WhatsApp authentication failed',
//         backgroundColor: Colors.red,
//         colorText: Colors.white,
//       );
//     });

//     socket.on('wa_disconnected', (data) {
//       print('WA Disconnected: $data');
//       setState(() {
//         isWhatsAppReady = false;
//         isWhatsAppLoading = false; // Stop loading on disconnect
//         loadingMessage = '';
//       });
//       Get.snackbar(
//         'Disconnected',
//         data['message'] ?? 'WhatsApp disconnected',
//         backgroundColor: Colors.red,
//         colorText: Colors.white,
//       );
//     });

//     // Add wa_logout handler
//     socket.on('wa_logout', (data) {
//       print('WA Logout: $data');
//       setState(() {
//         isWhatsAppReady = false;
//         isWhatsAppLoading = false; // Stop loading on logout
//         loadingMessage = data['message'] ?? 'whatsapp logout client...';
//       });
//       // No snackbar to avoid error popup
//     });

//     socket.on('chat_messages', (data) {
//       print('Received initial messages: $data');
//       if (data != null && mounted) {
//         try {
//           final List<Message> initialMessages = (data['messages'] as List)
//               .map((msg) => Message.fromJson(msg))
//               .toList();
//           setState(() {
//             messages = initialMessages;
//           });
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             _scrollToBottom();
//           });
//         } catch (e) {
//           print('Error parsing chat messages: $e');
//         }
//       }
//     });

//     socket.on('new_message', (data) {
//       print('New message received: $data');
//       if (data != null && mounted) {
//         try {
//           final messageData = data['message'];
//           if (messageData != null) {
//             final newMessage = Message.fromJson(messageData);
//             if (data['chatId'] == widget.chatId &&
//                 !messages.any((m) => m.id == newMessage.id)) {
//               setState(() {
//                 messages.add(newMessage);
//               });
//               WidgetsBinding.instance.addPostFrameCallback((_) {
//                 _scrollToBottom();
//               });
//             }
//           }
//         } catch (e) {
//           print('Error parsing new message: $e');
//         }
//       }
//     });

//     socket.on('message_sent', (data) {
//       print('Message sent confirmation: $data');
//     });

//     socket.on('wa_error', (data) {
//       print('WebSocket error: $data');
//       setState(() {
//         isWhatsAppLoading = false; // Stop loading on error
//         loadingMessage = '';
//       });
//       Get.snackbar(
//         'Error',
//         data['error'] ?? 'Unknown error',
//         backgroundColor: Colors.red,
//         colorText: Colors.white,
//       );
//     });
//   }

//   void _scrollToBottom() {
//     if (_scrollController.hasClients) {
//       _scrollController.animateTo(
//         _scrollController.position.maxScrollExtent,
//         duration: Duration(milliseconds: 300),
//         curve: Curves.easeOut,
//       );
//     }
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _stopReconnectTimer();
//     socket.off('connect');
//     socket.off('disconnect');
//     socket.off('new_message');
//     socket.off('chat_messages');
//     socket.off('message_sent');
//     socket.off('wa_error');
//     socket.off('connect_error');
//     socket.off('wa_login_success');
//     socket.off('wa_auth_failure');
//     socket.off('wa_disconnected');
//     socket.off('wa_loading_started'); // Clean up the new listener
//     socket.disconnect();
//     _messageController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   void disconnectSocket() {
//     _stopReconnectTimer();
//     socket.disconnect();
//     setState(() {
//       isConnected = false;
//     });
//     print('Socket manually disconnected');
//   }

//   void sendMessage() {
//     if (_messageController.text.trim().isEmpty || !isWhatsAppReady) return;

//     final message = {
//       'chatId': widget.chatId,
//       'message': _messageController.text,
//       'sessionId': spId,
//     };

//     print('Sending message: ${jsonEncode(message)}');
//     socket.emit('send_message', message);

//     final localMessage = Message(
//       body: _messageController.text,
//       fromMe: true,
//       timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
//       type: 'chat',
//       mediaUrl: null,
//     );

//     setState(() {
//       messages.add(localMessage);
//     });

//     _messageController.clear();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _scrollToBottom();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: AppColors.colorsBlueButton,
//         leadingWidth: 40,
//         leading: IconButton(
//           icon: const Icon(
//             Icons.arrow_back_ios_new_rounded,
//             color: Colors.white,
//           ),
//           onPressed: () {
//             disconnectSocket();
//             Navigator.pop(context);
//           },
//         ),
//         title: Row(
//           children: [
//             const SizedBox(width: 10),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   widget.userName,
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 Text(
//                   isWhatsAppLoading
//                       ? 'Initializing...'
//                       : isWhatsAppReady
//                       ? (isConnected ? 'Online' : 'Connecting...')
//                       : 'Not Connected',
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: Colors.white.withOpacity(0.8),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(
//               isConnected && isWhatsAppReady ? Icons.wifi : Icons.wifi_off,
//               color: Colors.white,
//             ),
//             onPressed: () {
//               if (!isConnected || !isWhatsAppReady) {
//                 socket.connect();
//                 checkWhatsAppStatus();
//                 Get.snackbar(
//                   'Info',
//                   'Reconnecting...',
//                   backgroundColor: Colors.blue,
//                   colorText: Colors.white,
//                 );
//               }
//             },
//           ),
//         ],
//       ),
//       body: isCheckingStatus
//           ? const Center(child: CircularProgressIndicator())
//           : Column(
//               children: [
//                 Expanded(
//                   child: isWhatsAppReady
//                       ? messages.isEmpty
//                             ? const Center(child: Text('No messages yet'))
//                             : ListView.builder(
//                                 controller: _scrollController,
//                                 padding: const EdgeInsets.symmetric(
//                                   vertical: 10,
//                                   horizontal: 10,
//                                 ),
//                                 itemCount: messages.length,
//                                 itemBuilder: (context, index) {
//                                   final message = messages[index];
//                                   final showDate =
//                                       index == 0 ||
//                                       DateTime.fromMillisecondsSinceEpoch(
//                                             messages[index].timestamp * 1000,
//                                           ).day !=
//                                           DateTime.fromMillisecondsSinceEpoch(
//                                             messages[index - 1].timestamp *
//                                                 1000,
//                                           ).day;

//                                   return Column(
//                                     children: [
//                                       if (showDate)
//                                         Container(
//                                           margin: const EdgeInsets.symmetric(
//                                             vertical: 10,
//                                           ),
//                                           padding: const EdgeInsets.symmetric(
//                                             horizontal: 15,
//                                             vertical: 5,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: Colors.grey[300],
//                                             borderRadius: BorderRadius.circular(
//                                               10,
//                                             ),
//                                           ),
//                                           child: Text(
//                                             DateFormat('EEEE, MMM d').format(
//                                               DateTime.fromMillisecondsSinceEpoch(
//                                                 message.timestamp * 1000,
//                                               ),
//                                             ),
//                                             style: const TextStyle(
//                                               fontSize: 12,
//                                               color: Colors.black54,
//                                             ),
//                                           ),
//                                         ),
//                                       MessageBubble(
//                                         message: message,
//                                         timeString: formatTimestamp(
//                                           message.timestamp,
//                                         ),
//                                       ),
//                                     ],
//                                   );
//                                 },
//                               )
//                       : Center(
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               // Show different UI based on loading states
//                               if (isWhatsAppLoading)
//                                 Column(
//                                   children: [
//                                     const CircularProgressIndicator(
//                                       color: AppColors.colorsBlueButton,
//                                     ),
//                                     const SizedBox(height: 16),
//                                     Text(
//                                       loadingMessage.isNotEmpty
//                                           ? loadingMessage
//                                           : 'Starting WhatsApp client...',
//                                       style: const TextStyle(
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.w500,
//                                       ),
//                                       textAlign: TextAlign.center,
//                                     ),
//                                     const SizedBox(height: 8),
//                                     Text(
//                                       'Please wait while we initialize your WhatsApp connection',
//                                       style: TextStyle(
//                                         color: Colors.grey[600],
//                                         fontSize: 14,
//                                       ),
//                                       textAlign: TextAlign.center,
//                                     ),
//                                   ],
//                                 )
//                               else
//                                 Column(
//                                   children: [
//                                     InkWell(
//                                       onTap: () {
//                                         initWhatsAppChat(context);
//                                         print('Connect WhatsApp clicked');
//                                       },
//                                       child: Container(
//                                         padding: const EdgeInsets.all(10),
//                                         decoration: BoxDecoration(
//                                           color: AppColors.colorsBlueButton,
//                                           borderRadius: BorderRadius.circular(
//                                             10,
//                                           ),
//                                         ),
//                                         child: Text(
//                                           isLoading
//                                               ? 'Connecting...'
//                                               : 'Connect your WhatsApp',
//                                           style: AppFont.appbarfontWhite(
//                                             context,
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                     if (!isConnected && !isLoading)
//                                       Padding(
//                                         padding: const EdgeInsets.only(
//                                           top: 8.0,
//                                         ),
//                                         child: Text(
//                                           'Click to connect',
//                                           style: TextStyle(
//                                             color: Colors.grey[600],
//                                             fontSize: 12,
//                                           ),
//                                         ),
//                                       ),
//                                   ],
//                                 ),
//                             ],
//                           ),
//                         ),
//                 ),
//                 if (isWhatsAppReady)
//                   Container(
//                     margin: EdgeInsets.only(bottom: 10),
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8.0,
//                       vertical: 5.0,
//                     ),
//                     color: Colors.white,
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(horizontal: 15),
//                             decoration: BoxDecoration(
//                               color: Colors.grey[200],
//                               borderRadius: BorderRadius.circular(25),
//                             ),
//                             child: TextField(
//                               controller: _messageController,
//                               decoration: const InputDecoration(
//                                 hintText: 'Type a message',
//                                 border: InputBorder.none,
//                               ),
//                               maxLines: null,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         Container(
//                           decoration: const BoxDecoration(
//                             color: AppColors.colorsBlue,
//                             shape: BoxShape.circle,
//                           ),
//                           child: IconButton(
//                             icon: const Icon(Icons.send),
//                             color: Colors.white,
//                             onPressed: sendMessage,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//               ],
//             ),
//     );
//   }
// }

import 'dart:async';
import 'dart:math';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/utils/token_manager.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

class Message {
  final String body;
  final bool fromMe;
  final int timestamp;
  final String type;
  final String? mediaUrl;
  final String? id; // Add this field

  Message({
    required this.body,
    required this.fromMe,
    required this.timestamp,
    required this.type,
    this.mediaUrl,
    this.id, // Add this field
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      body: json['body'] ?? '',
      fromMe: json['fromMe'] ?? false,
      timestamp:
          json['timestamp'] ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      type: json['type'] ?? 'chat',
      mediaUrl: json['mediaUrl'],
      id: json['id'], // Parse the ID
    );
  }
}

class MessageBubble extends StatefulWidget {
  final Message message;
  final String timeString;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.timeString,
  }) : super(key: key);

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.message.fromMe
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: widget.message.fromMe
              ? const Color.fromARGB(255, 198, 210, 248)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 1),
              blurRadius: 2,
              color: Colors.black.withOpacity(0.1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.message.type == 'image' &&
                widget.message.mediaUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  widget.message.mediaUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    color: Colors.grey[300],
                    alignment: Alignment.center,
                    child: const Text("Error loading image"),
                  ),
                ),
              ),
            if (widget.message.body.isNotEmpty)
              Text(widget.message.body, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.timeString,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                if (widget.message.fromMe) const SizedBox(width: 3),
                if (widget.message.fromMe)
                  const Icon(
                    Icons.done_all,
                    size: 14,
                    color: Color(0xFF34B7F1),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WhatsappChat extends StatefulWidget {
  final String chatId;
  final String userName;

  const WhatsappChat({super.key, required this.chatId, required this.userName});

  @override
  State<WhatsappChat> createState() => _WhatsappChatState();
}

class _WhatsappChatState extends State<WhatsappChat>
    with WidgetsBindingObserver {
  List<Message> messages = [];
  bool isLoading = false;
  bool isWhatsAppLoading = false; // New loading state for WhatsApp client
  String loadingMessage = ''; // Message to show during loading
  String spId = '';
  String email = '';
  bool isWhatsAppReady = false;
  bool isCheckingStatus = true;
  bool isLoggedOut = false; // Track if user has logged out
  Timer? _reconnectTimer;

  final TextEditingController _messageController = TextEditingController();
  late IO.Socket socket;
  bool isConnected = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Observe app lifecycle
    loadInitialData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('AppLifecycleState: $state');
    if (state == AppLifecycleState.resumed) {
      // App is back in foreground, attempt to reconnect socket immediately
      _stopReconnectTimer();
      if (!isConnected) {
        print('App resumed, forcing socket reconnect');
        socket.connect();
        // Delay status check to allow socket connection
        Future.delayed(Duration(seconds: 1), () {
          if (mounted && !isWhatsAppReady && !isLoggedOut) {
            checkWhatsAppStatus();
          }
        });
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // App is in background or hidden, start reconnection attempts
      print('App paused or hidden, starting reconnect timer');
      _startReconnectTimer();
    }
  }

  void _startReconnectTimer() {
    _reconnectTimer?.cancel();
    int attempt = 0;
    const maxAttempts = 10;
    const baseDelay = 2000; // Start with 2 seconds
    const maxDelay = 10000; // Cap at 10 seconds

    _reconnectTimer = Timer.periodic(Duration(milliseconds: baseDelay), (
      timer,
    ) async {
      if (!isConnected && mounted && attempt < maxAttempts) {
        print(
          'Attempting to reconnect socket... (Attempt ${attempt + 1}/$maxAttempts)',
        );
        socket.connect();
        attempt++;
        // Increase delay with exponential backoff
        final delay = (baseDelay * pow(1.5, attempt)).toInt().clamp(
          baseDelay,
          maxDelay,
        );
        if (delay > baseDelay) {
          timer.cancel();
          _reconnectTimer = Timer.periodic(Duration(milliseconds: delay), (t) {
            if (!isConnected && mounted && attempt < maxAttempts) {
              print(
                'Attempting to reconnect socket... (Attempt ${attempt + 1}/$maxAttempts)',
              );
              socket.connect();
              attempt++;
            } else {
              t.cancel();
            }
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Future<void> loadInitialData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    spId = prefs.getString('user_id') ?? '';
    email = await TokenManager.getUserEmail() ?? '';
    print('this is spid $spId');
    initSocket(); // Initialize socket first
    await checkWhatsAppStatus(); // Check status after socket is initialized
  }

  Future<void> checkWhatsAppStatus() async {
    setState(() {
      isCheckingStatus = true;
    });
    try {
      final url = Uri.parse(
        'https://api.smartassistapp.in/api/check-wa-status',
      );
      final token = await Storage.getToken();
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'sessionId': spId}),
      );

      print(
        'Check WA Status Response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          isWhatsAppReady = data['isReady'] ?? false;
          isCheckingStatus = false;
          // Reset logout flag if WhatsApp is ready
          if (isWhatsAppReady) {
            isLoggedOut = false;
          }
        });
        // Remove direct socket.emit; rely on socket's onConnect
      } else {
        print('Failed to check WhatsApp status: ${response.body}');
        setState(() {
          isWhatsAppReady = false;
          isCheckingStatus = false;
        });
        // Get.snackbar(
        //   'Error',
        //   'Failed to check WhatsApp status',
        //   backgroundColor: Colors.red,
        //   colorText: Colors.white,
        // );
      }
    } catch (e) {
      print('Error checking WhatsApp status: $e');
      setState(() {
        isWhatsAppReady = false;
        isCheckingStatus = false;
      });
      Get.snackbar(
        'Error',
        'Failed to check WhatsApp status',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> initWhatsAppChat(BuildContext context) async {
    if (isWhatsAppReady || isLoading) return;
    setState(() {
      isLoading = true;
      isLoggedOut = false; // Reset logout flag when trying to reconnect
    });
    try {
      final url = Uri.parse('https://api.smartassistapp.in/api/init-wa');
      final token = await Storage.getToken();
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'sessionId': spId, 'email': email}),
      );

      print(url.toString());

      print('Init WA Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['isReady'] == true) {
          setState(() {
            isWhatsAppReady = true;
            isLoggedOut = false;
          });
          socket.emit('get_messages', {
            'sessionId': spId,
            'chatId': widget.chatId,
          });
        } else {
          await launchWhatsAppScanner();
        }
      } else {
        final errorMessage =
            json.decode(response.body)['message'] ?? 'Unknown error';
        Get.snackbar(
          'Error',
          errorMessage,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('Error initializing WhatsApp chat: $e');
      Get.snackbar(
        'Error',
        'Failed to initialize WhatsApp chat',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> launchWhatsAppScanner() async {
    try {
      await LaunchApp.openApp(
        androidPackageName: 'com.whatsapp',
        iosUrlScheme: 'whatsapp://',
        appStoreLink:
            'https://play.google.com/store/apps/details?id=com.whatsapp',
      );
      print('WhatsApp launched successfully');
    } catch (e) {
      print('Error launching WhatsApp: $e');
      Get.snackbar(
        'Error',
        e.toString().contains('not installed')
            ? 'Please install WhatsApp to continue'
            : 'Failed to open WhatsApp',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  String formatTimestamp(int timestamp) {
    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
      timestamp * 1000,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeFormat = DateFormat('HH:mm');
    if (messageDate == today) {
      return timeFormat.format(dateTime);
    } else if (messageDate == yesterday) {
      return 'Yesterday, ${timeFormat.format(dateTime)}';
    } else {
      return DateFormat('MMM d, HH:mm').format(dateTime);
    }
  }

  void initSocket() {
    socket = IO.io('wss://api.smartassistapp.in', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 5000,
      'timeout': 20000,
    });

    socket.onConnect((_) {
      print('Socket connected');
      _stopReconnectTimer();
      socket.emit('register_session', {'sessionId': spId});
      print('Emitted register_session: sessionId=$spId');
      setState(() {
        isConnected = true;
      });
      // Only get messages if WhatsApp is ready and not logged out
      if (isWhatsAppReady && !isLoggedOut) {
        socket.emit('get_messages', {
          'sessionId': spId,
          'chatId': widget.chatId,
        });
        print('Requesting messages for chat ID: ${widget.chatId}');
      }
    });

    socket.onDisconnect((_) {
      print('Socket disconnected');
      setState(() {
        isConnected = false;
      });
      _startReconnectTimer();
    });

    socket.onConnectError((error) {
      print('Connection error: $error');
      setState(() {
        isConnected = false;
      });
      _startReconnectTimer();
    });

    // New socket listener for WhatsApp loading started
    socket.on('wa_loading_started', (data) {
      print('WA Loading Started: $data');
      setState(() {
        isWhatsAppLoading = true;
        loadingMessage = data['message'] ?? 'Starting WhatsApp client...';
      });
    });

    socket.on('wa_login_success', (data) {
      print('WA Login Success: $data');
      setState(() {
        isWhatsAppReady = true;
        isWhatsAppLoading = false; // Stop loading when login is successful
        loadingMessage = '';
        isLoggedOut = false; // Reset logout flag on successful login
      });
      socket.emit('get_messages', {'sessionId': spId, 'chatId': widget.chatId});
    });

    socket.on('wa_auth_failure', (data) {
      print('WA Auth Failure: $data');
      setState(() {
        isWhatsAppReady = false;
        isWhatsAppLoading = false; // Stop loading on failure
        loadingMessage = '';
        isLoggedOut = true; // Set logout flag on auth failure
        messages.clear(); // Clear messages on auth failure
      });
      Get.snackbar(
        'Error',
        data['error'] ?? 'WhatsApp authentication failed',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    });

    socket.on('wa_disconnected', (data) {
      print('WA Disconnected: $data');
      setState(() {
        isWhatsAppReady = false;
        isWhatsAppLoading = false; // Stop loading on disconnect
        loadingMessage = '';
      });
      Get.snackbar(
        'Disconnected',
        data['message'] ?? 'WhatsApp disconnected',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    });

    // Updated wa_logout handler to show connect button
    socket.on('wa_logout', (data) {
      print('WA Logout: $data');
      setState(() {
        isWhatsAppReady = false;
        isWhatsAppLoading = false; // Stop loading on logout
        loadingMessage = '';
        isLoggedOut = true; // Set logout flag to show connect button
        messages.clear(); // Clear messages on logout
      });
      // Show a snackbar to inform user about logout
      Get.snackbar(
        'WhatsApp Logged Out',
        data['message'] ??
            'WhatsApp session has been logged out. Please reconnect.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
      );
    });

    socket.on('chat_messages', (data) {
      print('Received initial messages: $data');
      if (data != null && mounted) {
        try {
          final List<Message> initialMessages = (data['messages'] as List)
              .map((msg) => Message.fromJson(msg))
              .toList();
          setState(() {
            messages = initialMessages;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        } catch (e) {
          print('Error parsing chat messages: $e');
        }
      }
    });

    socket.on('new_message', (data) {
      print('New message received: $data');
      if (data != null && mounted) {
        try {
          final messageData = data['message'];
          if (messageData != null) {
            final newMessage = Message.fromJson(messageData);
            if (data['chatId'] == widget.chatId &&
                !messages.any((m) => m.id == newMessage.id)) {
              setState(() {
                messages.add(newMessage);
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom();
              });
            }
          }
        } catch (e) {
          print('Error parsing new message: $e');
        }
      }
    });

    socket.on('message_sent', (data) {
      print('Message sent confirmation: $data');
    });

    socket.on('wa_error', (data) {
      print('WebSocket error: $data');
      setState(() {
        isWhatsAppLoading = false; // Stop loading on error
        loadingMessage = '';
      });
      Get.snackbar(
        'Error',
        data['error'] ?? 'Unknown error',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopReconnectTimer();
    socket.off('connect');
    socket.off('disconnect');
    socket.off('new_message');
    socket.off('chat_messages');
    socket.off('message_sent');
    socket.off('wa_error');
    socket.off('connect_error');
    socket.off('wa_login_success');
    socket.off('wa_auth_failure');
    socket.off('wa_disconnected');
    socket.off('wa_loading_started'); // Clean up the new listener
    socket.off('wa_logout'); // Clean up the logout listener
    socket.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void disconnectSocket() {
    _stopReconnectTimer();
    socket.disconnect();
    setState(() {
      isConnected = false;
    });
    print('Socket manually disconnected');
  }

  void sendMessage() {
    if (_messageController.text.trim().isEmpty || !isWhatsAppReady) return;

    final message = {
      'chatId': widget.chatId,
      'message': _messageController.text,
      'sessionId': spId,
    };

    print('Sending message: ${jsonEncode(message)}');
    socket.emit('send_message', message);

    final localMessage = Message(
      body: _messageController.text,
      fromMe: true,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      type: 'chat',
      mediaUrl: null,
    );

    setState(() {
      messages.add(localMessage);
    });

    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.colorsBlueButton,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            disconnectSocket();
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  isWhatsAppLoading
                      ? 'Initializing...'
                      : isLoggedOut
                      ? 'Logged Out'
                      : isWhatsAppReady
                      ? (isConnected ? 'Online' : 'Connecting...')
                      : 'Not Connected',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isConnected && isWhatsAppReady ? Icons.wifi : Icons.wifi_off,
              color: Colors.white,
            ),
            onPressed: () {
              if (!isConnected || !isWhatsAppReady) {
                socket.connect();
                checkWhatsAppStatus();
                Get.snackbar(
                  'Info',
                  'Reconnecting...',
                  backgroundColor: Colors.blue,
                  colorText: Colors.white,
                );
              }
            },
          ),
        ],
      ),
      body: isCheckingStatus
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: isWhatsAppReady && !isLoggedOut
                      ? messages.isEmpty
                            ? const Center(child: Text('No messages yet'))
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 10,
                                ),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final showDate =
                                      index == 0 ||
                                      DateTime.fromMillisecondsSinceEpoch(
                                            messages[index].timestamp * 1000,
                                          ).day !=
                                          DateTime.fromMillisecondsSinceEpoch(
                                            messages[index - 1].timestamp *
                                                1000,
                                          ).day;

                                  return Column(
                                    children: [
                                      if (showDate)
                                        Container(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 15,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            DateFormat('EEEE, MMM d').format(
                                              DateTime.fromMillisecondsSinceEpoch(
                                                message.timestamp * 1000,
                                              ),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                      MessageBubble(
                                        message: message,
                                        timeString: formatTimestamp(
                                          message.timestamp,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Show different UI based on loading states
                              if (isWhatsAppLoading)
                                Column(
                                  children: [
                                    const CircularProgressIndicator(
                                      color: AppColors.colorsBlueButton,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      loadingMessage.isNotEmpty
                                          ? loadingMessage
                                          : 'Starting WhatsApp client...',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Please wait while we initialize your WhatsApp connection',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  children: [
                                    // Show different icon and text based on logout state
                                    if (isLoggedOut)
                                      Column(
                                        children: [
                                          Icon(
                                            Icons.account_circle_outlined,
                                            size: 80,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'WhatsApp Logged Out',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Your WhatsApp session has ended.\nPlease reconnect to continue chatting.',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 24),
                                        ],
                                      )
                                    else
                                      Column(
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline,
                                            size: 80,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    InkWell(
                                      onTap: () {
                                        initWhatsAppChat(context);
                                        print('Connect WhatsApp clicked');
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.colorsBlueButton,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          isLoading
                                              ? 'Connecting...'
                                              : isLoggedOut
                                              ? 'Reconnect WhatsApp'
                                              : 'Connect your WhatsApp',
                                          style: AppFont.appbarfontWhite(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (!isConnected && !isLoading)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Text(
                                          'Click to connect',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                ),
                if (isWhatsAppReady && !isLoggedOut)
                  Container(
                    margin: EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 5.0,
                    ),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'Type a message',
                                border: InputBorder.none,
                              ),
                              maxLines: null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: const BoxDecoration(
                            color: AppColors.colorsBlue,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.send),
                            color: Colors.white,
                            onPressed: sendMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
