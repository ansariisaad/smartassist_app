import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartassist/config/component/color/colors.dart';
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

class WhatsappChat extends StatefulWidget {
  final String chatId;
  final String userName;
  // final String email;
  // final String sessionId;
  const WhatsappChat({
    super.key,
    required this.chatId,
    required this.userName,
    // required this.email,
    // required this.sessionId,
  });

  @override
  State<WhatsappChat> createState() => _WhatsappChatState();
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

class _WhatsappChatState extends State<WhatsappChat> {
  List<Message> messages = [];
  bool isLoading = false;
  String spId = '';
  String email = '';

  Future<void> initwhatsappChat(BuildContext context) async {
    setState(() {
      isLoading = true;
    });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      spId = prefs.getString('user_id') ?? '';
      email = await TokenManager.getUserEmail() ?? '';
      // String? user_email = prefs.getString('user_email');
      final url = Uri.parse('https://dev.smartassistapp.in/api/init-wa');
      final token = await Storage.getToken();

      // Create the request body
      final requestBody = {'sessionId': spId};
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(requestBody),
      );

      // Print the response
      print('API Response status: ${response.statusCode}');
      print('API Response body: ${response.body}');

      if (response.statusCode == 200) {
        final errorMessage =
            json.decode(response.body)['message'] ?? 'Unknown error';

        Get.snackbar(
          'Success',
          errorMessage,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        Navigator.pop(context); // Dismiss the dialog after success

        // Launch WhatsApp scanner after successful API call
        await launchWhatsAppScanner();
      } else {
        // Error handling
        final errorMessage =
            json.decode(response.body)['message'] ?? 'Unknown error';
        print('Failed to submit feedback');
        Get.snackbar(
          'Error',
          errorMessage, // Show the backend error message
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        Navigator.pop(context); // Dismiss the dialog on error
      }
    } catch (e) {
      print('Error fetching WhatsApp chat: $e');
      Get.snackbar(
        'Error',
        'Failed to fetch WhatsApp chat',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  launchWhatsAppScanner() async {
    try {
      // Try to launch WhatsApp directly
      await LaunchApp.openApp(
        androidPackageName: 'com.whatsapp',
        iosUrlScheme: 'whatsapp://',
        appStoreLink:
            'https://play.google.com/store/apps/details?id=com.whatsapp',
      );

      print('WhatsApp launched successfully');
    } catch (e) {
      print('Error launching WhatsApp: $e');

      // Handle different error cases
      if (e.toString().contains('not installed') ||
          e.toString().contains('not found')) {
        Get.snackbar(
          'WhatsApp Not Found',
          'Please install WhatsApp to continue',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error',
          'Failed to open WhatsApp',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  final TextEditingController _messageController = TextEditingController();
  late IO.Socket socket;
  bool isConnected = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadInitialData();
    // print(email);
    print('this is spid $spId ');
    initSocket();
  }

  Future<void> loadInitialData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    spId = prefs.getString('user_id') ?? '';

    print('this is spid $spId');
    initSocket(); // Now spId is available before socket emits
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
    socket = IO.io('wss://dev.smartassistapp.in', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
    });

    socket.onConnect((_) {
      socket.emit('register_session', {'sessionId': spId});
      print('Emitted register_session: sessionId=$spId');
      print('Socket connected');
      if (mounted) {
        setState(() {
          isConnected = true;
        });
      }

      // Request initial messages for the specific chat
      socket.emit('get_messages', {'sessionId': spId, 'chatId': widget.chatId});
      print('Requesting messages for chat ID: ${widget.chatId}');
    });

    socket.onDisconnect((_) {
      print('Socket disconnected');
      if (mounted) {
        setState(() {
          isConnected = false;
        });
      }
    });

    socket.onConnectError((error) {
      print('Connection error: $error');
      Future.delayed(Duration(seconds: 3), () {
        if (!isConnected && mounted) {
          socket.connect();
        }
      });
    });

    // Listen for initial messages
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

          // Scroll to the bottom after initial messages are loaded
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        } catch (e) {
          print('Error parsing chat messages: $e');
        }
      }
    });

    // Listen for new messages (single listener with duplicate check)
    socket.on('new_message', (data) {
      print('New message received: $data');
      if (data != null && mounted) {
        try {
          final messageData = data['message'];
          if (messageData != null) {
            final newMessage = Message.fromJson(messageData);

            // Check if this message belongs to the current chat and isn't a duplicate
            if (data['chatId'] == widget.chatId &&
                !messages.any((m) => m.id == newMessage.id)) {
              setState(() {
                messages.add(newMessage);
              });

              // Scroll to bottom
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

    // Listen for message sent confirmation
    socket.on('message_sent', (data) {
      print('Message sent confirmation: $data');
      // Update message status if needed (e.g., update read receipt)
    });

    // Listen for errors
    socket.on('wa_error', (data) {
      print('WebSocket error: $data');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${data['error'] ?? 'Unknown error'}')),
        );
      }
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
    // Remove all event listeners
    socket.off('connect');
    socket.off('disconnect');
    socket.off('new_message');
    socket.off('chat_messages');
    socket.off('message_sent');
    socket.off('wa_error');
    socket.off('connect_error');

    // Disconnect the socket
    socket.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Function to handle socket disconnection
  void disconnectSocket() {
    print('ttttttttttttttttttttttttttttttttttttttttttttttttttttttttt');
    // Disconnect the socket
    socket.disconnect();

    // Optionally update the UI to reflect that the socket is disconnected
    if (mounted) {
      setState(() {
        isConnected = false;
      });
    }

    print('Socket manually disconnected');
  }

  void sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    // Create message payload matching what the backend expects
    final message = {
      'chatId': widget.chatId,
      'message': _messageController.text,
      'sessionId': spId,
    };

    print('Sending message: ${jsonEncode(message)}');

    // Emit with the correct structure
    socket.emit('send_message', message);

    // Create a local message object for optimistic UI update
    final localMessage = Message(
      body: _messageController.text,
      fromMe: true,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      type: 'chat',
      mediaUrl: null,
    );

    // Add to local message list (optimistic update)
    setState(() {
      messages.add(localMessage);
    });

    _messageController.clear();

    // Scroll to bottom after sending
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.colorsBlue,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          // onPressed: () => Navigator.pop(context),
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
                  isConnected ? 'Online' : 'Connecting...',
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
              isConnected ? Icons.wifi : Icons.wifi_off,
              color: Colors.white,
            ),
            onPressed: () {
              if (!isConnected) {
                // Try to reconnect if disconnected
                socket.connect();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Reconnecting...')));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () {
                            initwhatsappChat(context);
                            print('clicked');
                          },
                          child: Text('Connect your whatsapp'),
                        ),
                        if (!isConnected)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: InkWell(
                              child: Text(
                                'click to connect',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                // Center(
                //   child: Column(
                //     mainAxisAlignment: MainAxisAlignment.center,
                //     children: [
                //       Text('No messages yet'),
                //       if (!isConnected)
                //         Padding(
                //           padding: const EdgeInsets.only(top: 8.0),
                //           child: Text(
                //             'Waiting for connection...',
                //             style: TextStyle(
                //               color: Colors.grey[600],
                //               fontSize: 12,
                //             ),
                //           ),
                //         ),
                //     ],
                //   ),
                // )
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
                                messages[index - 1].timestamp * 1000,
                              ).day;

                      return Column(
                        children: [
                          if (showDate)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
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
                            timeString: formatTimestamp(message.timestamp),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  color: Colors.grey[600],
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  color: Colors.grey[600],
                  onPressed: () {},
                ),
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

// import 'package:external_app_launcher/external_app_launcher.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:smartassist/utils/storage.dart';
// import 'package:smartassist/utils/token_manager.dart';
// import 'package:socket_io_client/socket_io_client.dart' as IO;
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'dart:convert';

// // Message class remains unchanged
// class Message {
//   final String body;
//   final bool fromMe;
//   final int timestamp;
//   final String type;
//   final String? mediaUrl;
//   final String? id;

//   Message({
//     required this.body,
//     required this.fromMe,
//     required this.timestamp,
//     required this.type,
//     this.mediaUrl,
//     this.id,
//   });

//   factory Message.fromJson(Map<String, dynamic> json) {
//     return Message(
//       body: json['body'] ?? '',
//       fromMe: json['fromMe'] ?? false,
//       timestamp:
//           json['timestamp'] ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
//       type: json['type'] ?? 'chat',
//       mediaUrl: json['mediaUrl'],
//       id: json['id'],
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

// // MessageBubble remains unchanged
// class MessageBubble extends StatelessWidget {
//   final Message message;
//   final String timeString;

//   const MessageBubble({
//     Key? key,
//     required this.message,
//     required this.timeString,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Align(
//       alignment: message.fromMe ? Alignment.centerRight : Alignment.centerLeft,
//       child: Container(
//         margin: const EdgeInsets.symmetric(vertical: 3),
//         constraints: BoxConstraints(
//           maxWidth: MediaQuery.of(context).size.width * 0.75,
//         ),
//         decoration: BoxDecoration(
//           color: message.fromMe
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
//             if (message.type == 'image' && message.mediaUrl != null)
//               ClipRRect(
//                 borderRadius: BorderRadius.circular(6),
//                 child: Image.network(
//                   message.mediaUrl!,
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
//             if (message.body.isNotEmpty)
//               Text(message.body, style: const TextStyle(fontSize: 16)),
//             const SizedBox(height: 2),
//             Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   timeString,
//                   style: TextStyle(fontSize: 11, color: Colors.grey[600]),
//                 ),
//                 if (message.fromMe) const SizedBox(width: 3),
//                 if (message.fromMe)
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

// class _WhatsappChatState extends State<WhatsappChat> {
//   List<Message> messages = [];
//   bool isLoading = false;
//   String spId = '';
//   bool isWhatsAppScanned = false;
//   final TextEditingController _messageController = TextEditingController();
//   late IO.Socket socket;
//   bool isConnected = false;
//   final ScrollController _scrollController = ScrollController();

//   @override
//   void initState() {
//     super.initState();
//     _initialize();
//   }

//   Future<void> _initialize() async {
//     await _loadInitialData();
//     await _checkWhatsAppScanStatus();
//     _initSocket();
//   }

//   Future<void> _loadInitialData() async {
//     final prefs = await SharedPreferences.getInstance();
//     spId = prefs.getString('user_id') ?? '';
//   }

//   Future<void> _checkWhatsAppScanStatus() async {
//     try {
//       final url = Uri.parse(
//         'https://dev.smartassistapp.in/api/check-wa-status',
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

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         setState(() {
//           isWhatsAppScanned = data['isScanned'] ?? false;
//         });
//       }
//     } catch (e) {
//       print('Error checking WhatsApp status: $e');
//     }
//   }

//   Future<void> _initWhatsAppChat() async {
//     if (isLoading) return;

//     setState(() => isLoading = true);

//     try {
//       final url = Uri.parse('https://dev.smartassistapp.in/api/init-wa');
//       final token = await Storage.getToken();
//       final response = await http.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         body: json.encode({'sessionId': spId}),
//       );

//       if (response.statusCode == 200) {
//         Get.snackbar(
//           'Success',
//           'WhatsApp initialization successful',
//           backgroundColor: Colors.green,
//           colorText: Colors.white,
//         );
//         await _launchWhatsAppScanner();
//         await _checkWhatsAppScanStatus();
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
//       Get.snackbar(
//         'Error',
//         'Failed to initialize WhatsApp',
//         backgroundColor: Colors.red,
//         colorText: Colors.white,
//       );
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   Future<void> _launchWhatsAppScanner() async {
//     try {
//       await LaunchApp.openApp(
//         androidPackageName: 'com.whatsapp',
//         iosUrlScheme: 'whatsapp://',
//         appStoreLink:
//             'https://play.google.com/store/apps/details?id=com.whatsapp',
//       );
//     } catch (e) {
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

//   void _initSocket() {
//     socket = IO.io('wss://dev.smartassistapp.in', {
//       'transports': ['websocket'],
//       'autoConnect': true,
//       'reconnection': true,
//       'reconnectionAttempts': 5,
//       'reconnectionDelay': 1000,
//     });

//     socket.onConnect((_) {
//       setState(() => isConnected = true);
//       socket.emit('get_messages', {'sessionId': spId, 'chatId': widget.chatId});
//     });

//     socket.onDisconnect((_) => setState(() => isConnected = false));

//     socket.onConnectError((error) {
//       print('Connection error: $error');
//       Future.delayed(Duration(seconds: 3), () {
//         if (!isConnected && mounted) socket.connect();
//       });
//     });

//     socket.on('chat_messages', (data) {
//       if (!mounted || data == null) return;
//       try {
//         final List<Message> initialMessages = (data['messages'] as List)
//             .map((msg) => Message.fromJson(msg))
//             .toList();
//         setState(() => messages = initialMessages);
//         WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
//       } catch (e) {
//         print('Error parsing messages: $e');
//       }
//     });

//     socket.on('new_message', (data) {
//       if (!mounted || data == null || data['chatId'] != widget.chatId) return;
//       try {
//         final newMessage = Message.fromJson(data['message']);
//         if (!messages.any((m) => m.id == newMessage.id)) {
//           setState(() => messages.add(newMessage));
//           WidgetsBinding.instance.addPostFrameCallback(
//             (_) => _scrollToBottom(),
//           );
//         }
//       } catch (e) {
//         print('Error parsing new message: $e');
//       }
//     });

//     socket.on('wa_error', (data) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error: ${data['error'] ?? 'Unknown error'}')),
//         );
//       }
//     });
//   }

//   String _formatTimestamp(int timestamp) {
//     final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
//     final now = DateTime.now();
//     final today = DateTime(now.year, now.month, now.day);
//     final yesterday = today.subtract(const Duration(days: 1));
//     final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

//     final timeFormat = DateFormat('HH:mm');

//     if (messageDate == today) return timeFormat.format(dateTime);
//     if (messageDate == yesterday)
//       return 'Yesterday, ${timeFormat.format(dateTime)}';
//     return DateFormat('MMM d, HH:mm').format(dateTime);
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

//   void _sendMessage() {
//     if (_messageController.text.trim().isEmpty || !isWhatsAppScanned) return;

//     final message = {
//       'chatId': widget.chatId,
//       'message': _messageController.text,
//       'sessionId': spId,
//     };

//     socket.emit('send_message', message);

//     setState(() {
//       messages.add(
//         Message(
//           body: _messageController.text,
//           fromMe: true,
//           timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
//           type: 'chat',
//           mediaUrl: null,
//         ),
//       );
//     });

//     _messageController.clear();
//     WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
//   }

//   @override
//   void dispose() {
//     // socket.off();
//     socket.disconnect();
//     _messageController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: AppColors.colorsBlue,
//         leading: IconButton(
//           icon: const Icon(
//             Icons.arrow_back_ios_new_rounded,
//             color: Colors.white,
//           ),
//           onPressed: () {
//             socket.disconnect();
//             Navigator.pop(context);
//           },
//         ),
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               widget.userName,
//               style: const TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.white,
//               ),
//             ),
//             Text(
//               isConnected && isWhatsAppScanned ? 'Online' : 'Connecting...',
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.white.withOpacity(0.8),
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             icon: Icon(
//               isConnected ? Icons.wifi : Icons.wifi_off,
//               color: Colors.white,
//             ),
//             onPressed: () {
//               if (!isConnected) {
//                 socket.connect();
//                 ScaffoldMessenger.of(
//                   context,
//                 ).showSnackBar(SnackBar(content: Text('Reconnecting...')));
//               }
//             },
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: isWhatsAppScanned && messages.isNotEmpty
//                 ? ListView.builder(
//                     controller: _scrollController,
//                     padding: const EdgeInsets.symmetric(
//                       vertical: 10,
//                       horizontal: 10,
//                     ),
//                     itemCount: messages.length,
//                     itemBuilder: (context, index) {
//                       final message = messages[index];
//                       final showDate =
//                           index == 0 ||
//                           DateTime.fromMillisecondsSinceEpoch(
//                                 messages[index].timestamp * 1000,
//                               ).day !=
//                               DateTime.fromMillisecondsSinceEpoch(
//                                 messages[index - 1].timestamp * 1000,
//                               ).day;

//                       return Column(
//                         children: [
//                           if (showDate)
//                             Container(
//                               margin: const EdgeInsets.symmetric(vertical: 10),
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 15,
//                                 vertical: 5,
//                               ),
//                               decoration: BoxDecoration(
//                                 color: Colors.grey[300],
//                                 borderRadius: BorderRadius.circular(10),
//                               ),
//                               child: Text(
//                                 DateFormat('EEEE, MMM d').format(
//                                   DateTime.fromMillisecondsSinceEpoch(
//                                     message.timestamp * 1000,
//                                   ),
//                                 ),
//                                 style: const TextStyle(
//                                   fontSize: 12,
//                                   color: Colors.black54,
//                                 ),
//                               ),
//                             ),
//                           MessageBubble(
//                             message: message,
//                             timeString: _formatTimestamp(message.timestamp),
//                           ),
//                         ],
//                       );
//                     },
//                   )
//                 : Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         if (!isWhatsAppScanned)
//                           ElevatedButton(
//                             onPressed: _initWhatsAppChat,
//                             child: Text(
//                               isLoading
//                                   ? 'Connecting...'
//                                   : 'Connect your WhatsApp',
//                             ),
//                           ),
//                         if (!isWhatsAppScanned && !isConnected)
//                           Padding(
//                             padding: const EdgeInsets.only(top: 8.0),
//                             child: Text(
//                               'Click to connect',
//                               style: TextStyle(
//                                 color: Colors.grey[600],
//                                 fontSize: 12,
//                               ),
//                             ),
//                           ),
//                         if (isWhatsAppScanned && messages.isEmpty)
//                           Text(
//                             'No messages yet',
//                             style: TextStyle(color: Colors.grey[600]),
//                           ),
//                       ],
//                     ),
//                   ),
//           ),
//           if (isWhatsAppScanned)
//             Container(
//               padding: const EdgeInsets.symmetric(
//                 horizontal: 8.0,
//                 vertical: 5.0,
//               ),
//               color: Colors.white,
//               child: Row(
//                 children: [
//                   IconButton(
//                     icon: const Icon(Icons.emoji_emotions_outlined),
//                     color: Colors.grey[600],
//                     onPressed: () {},
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.attach_file),
//                     color: Colors.grey[600],
//                     onPressed: () {},
//                   ),
//                   Expanded(
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 15),
//                       decoration: BoxDecoration(
//                         color: Colors.grey[200],
//                         borderRadius: BorderRadius.circular(25),
//                       ),
//                       child: TextField(
//                         controller: _messageController,
//                         decoration: const InputDecoration(
//                           hintText: 'Type a message',
//                           border: InputBorder.none,
//                         ),
//                         maxLines: null,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   Container(
//                     decoration: const BoxDecoration(
//                       color: AppColors.colorsBlue,
//                       shape: BoxShape.circle,
//                     ),
//                     child: IconButton(
//                       icon: const Icon(Icons.send),
//                       color: Colors.white,
//                       onPressed: _sendMessage,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
