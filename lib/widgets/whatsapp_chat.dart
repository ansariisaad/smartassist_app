import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:smartassist/utils/storage.dart';
import 'package:smartassist/utils/token_manager.dart';
import 'package:smartassist/widgets/reusable/whatsapp_fullscreen.dart'
    as fullscreen;
import 'package:smartassist/widgets/reusable/whatsapp_video.dart';
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
  final String? id;
  final Map<String, dynamic>? media;

  Message({
    required this.body,
    required this.fromMe,
    required this.timestamp,
    required this.type,
    this.mediaUrl,
    this.id,
    this.media,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    String? mediaUrl;

    // Handle media data from server
    if (json['media'] != null && json['media']['base64'] != null) {
      final mediaData = json['media'];
      final base64Data = mediaData['base64'];
      final mimeType = mediaData['mimetype'] ?? '';
      // Convert base64 to data URL for display
      mediaUrl = 'data:$mimeType;base64,$base64Data';
    }

    return Message(
      body: json['body'] ?? '',
      fromMe: json['fromMe'] ?? false,
      timestamp:
          json['timestamp'] ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      type: json['type'] ?? 'chat',
      mediaUrl: mediaUrl ?? json['mediaUrl'],
      id: json['id'],
      media: json['media'],
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
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.message.type == 'image' &&
                widget.message.mediaUrl != null)
              fullscreen.ClickableMessageImage(
                imageUrl: widget.message.mediaUrl!,
                heroTag: widget.message.id ?? widget.message.mediaUrl,
              ),

            // Video handling - ADD THIS NEW SECTION
            if (widget.message.type == 'video' &&
                widget.message.mediaUrl != null)
              ClickableMessageVideo(
                videoUrl: widget.message.mediaUrl!,
                heroTag: widget.message.id ?? widget.message.mediaUrl,
              ),
            // Document handling
            if (widget.message.type == 'document' &&
                widget.message.media != null)
              _buildDocumentWidget(),

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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoWidget() {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video thumbnail placeholder
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.videocam, size: 40, color: Colors.white),
          ),
          // Play button overlay
          Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.play_arrow, color: Colors.white, size: 30),
              onPressed: () {
                // Handle video playback
                _playVideo();
              },
            ),
          ),
          // Duration badge (optional)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Video',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _playVideo() {
    // You can implement video playback here
    // For now, show a message or navigate to video player
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video playback not implemented yet'),
        duration: Duration(seconds: 2),
      ),
    );

    // Or you can implement actual video playback using video_player package
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WhatsappVideo(videoUrl: widget.message.mediaUrl!),
      ),
    );
  }

  Widget _buildDocumentWidget() {
    final media = widget.message.media;
    final filename = media?['filename'] ?? 'Document';
    final mimetype = media?['mimetype'] ?? '';

    // Get appropriate icon based on file type
    IconData getDocumentIcon(String mimetype, String filename) {
      final extension = filename.split('.').last.toLowerCase();

      switch (extension) {
        case 'pdf':
          return Icons.picture_as_pdf;
        case 'doc':
        case 'docx':
          return Icons.description;
        case 'xls':
        case 'xlsx':
          return Icons.table_chart;
        case 'ppt':
        case 'pptx':
          return Icons.slideshow;
        case 'txt':
          return Icons.text_snippet;
        case 'zip':
        case 'rar':
        case '7z':
          return Icons.archive;
        case 'mp3':
        case 'wav':
          return Icons.audio_file;
        case 'mp4':
        case 'avi':
        case 'mov':
          return Icons.video_file;
        default:
          return Icons.insert_drive_file;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            getDocumentIcon(mimetype, filename),
            size: 32,
            color: AppColors.colorsBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Text(
                //   // _getFileTypeLabel(mimetype, filename),
                //   // style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                // ),
              ],
            ),
          ),
        ],
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
  bool isWhatsAppLoading = false;
  String loadingMessage = '';
  String spId = '';
  String email = '';
  bool isWhatsAppReady = false;
  bool isCheckingStatus = true;
  bool isLoggedOut = false;
  Timer? _reconnectTimer;

  final ImagePicker _picker = ImagePicker();
  bool isSendingImage = false;
  bool isSendingDocument = false;

  final TextEditingController _messageController = TextEditingController();
  late IO.Socket socket;
  bool isConnected = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    const maxDelay = 20000; // Cap at 20 seconds

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
        print(errorMessage.toString());
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

  Future<void> resendQR() async {
    if (!isConnected) {
      Get.snackbar(
        'Error',
        'Not connected to server',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      isWhatsAppLoading = true;
      loadingMessage = 'Regenerating QR code...';
    });

    socket.emit('resend_qr', {'sessionId': spId});
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

    socket.on('wa_qr_expired', (data) {
      print('QR Expired: $data');
      setState(() {
        isWhatsAppReady = false;
        isWhatsAppLoading = false;
        loadingMessage = '';
        isLoggedOut = true; // Show reconnect button
      });
      Get.snackbar(
        'QR Code Expired',
        data['message'] ?? 'QR code expired, please rescan.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: Duration(seconds: 4),
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
            // Log media data for debugging
            if (messageData['media'] != null) {
              print(
                'Received media message: ${messageData['type']} - ${messageData['media']['mimetype']}',
              );
            }

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
          print('Message data: $data'); // Add this for debugging
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

    socket.on('QrSend', (data) {
      print('QrSend received: $data');
      setState(() {
        isWhatsAppLoading = true;
        loadingMessage = 'QR code generated, please scan in WhatsApp';
      });
      // Launch WhatsApp for QR code scanning
      launchWhatsAppScanner();
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
    socket.off('wa_loading_started');
    socket.off('wa_logout');
    socket.off('wa_qr_expired');
    socket.disconnect();
    _messageController.dispose();
    _scrollController.dispose();
    socket.disconnect();
    socket.dispose();
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

  void attachment() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 220,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.picture_as_pdf),
                title: Text('Document', style: AppFont.dropDowmLabel(context)),
                onTap: () async {
                  Navigator.pop(
                    context,
                  ); // ✅ This is correct - we're in a modal
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(type: FileType.any, allowMultiple: false);

                  if (result != null && result.files.single.path != null) {
                    final file = XFile(result.files.single.path!);
                    await sendDocumentMessage(file);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.photo),
                title: Text('Photo', style: AppFont.dropDowmLabel(context)),
                onTap: () async {
                  Navigator.pop(
                    context,
                  ); // ✅ This is correct - we're in a modal
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 70,
                  );
                  if (image != null) {
                    await sendImageMessage(image);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.videocam),
                title: Text('Video', style: AppFont.dropDowmLabel(context)),
                onTap: () async {
                  Navigator.pop(
                    context,
                  ); // ✅ This is correct - we're in a modal
                  final XFile? video = await _picker.pickVideo(
                    source: ImageSource.gallery,
                  );
                  if (video != null) {
                    await sendVideoMessage(video);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // void attachment() async {
  //   showModalBottomSheet(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return Container(
  //         height: 220,
  //         child: Column(
  //           children: [
  //             ListTile(
  //               leading: Icon(Icons.picture_as_pdf),
  //               title: Text('Document', style: AppFont.dropDowmLabel(context)),
  //               onTap: () async {
  //                 Navigator.pop(context);
  //                 // Use file_picker for documents instead of image_picker
  //                 FilePickerResult? result = await FilePicker.platform
  //                     .pickFiles(type: FileType.any, allowMultiple: false);

  //                 if (result != null && result.files.single.path != null) {
  //                   final file = XFile(result.files.single.path!);
  //                   await sendDocumentMessage(file);
  //                 }
  //               },
  //             ),
  //             ListTile(
  //               leading: Icon(Icons.photo),
  //               title: Text('Photo', style: AppFont.dropDowmLabel(context)),
  //               onTap: () async {
  //                 Navigator.pop(context);
  //                 final XFile? image = await _picker.pickImage(
  //                   source: ImageSource.gallery,
  //                   imageQuality: 70,
  //                 );
  //                 if (image != null) {
  //                   await sendImageMessage(image);
  //                 }
  //               },
  //             ),
  //             ListTile(
  //               leading: Icon(Icons.videocam),
  //               title: Text('Video', style: AppFont.dropDowmLabel(context)),
  //               onTap: () async {
  //                 Navigator.pop(context);
  //                 final XFile? video = await _picker.pickVideo(
  //                   source: ImageSource.gallery,
  //                 );
  //                 if (video != null) {
  //                   await sendVideoMessage(video);
  //                 }
  //               },
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  Future<void> sendVideoMessage(XFile video) async {
    if (!isWhatsAppReady) return;

    setState(() {
      isSendingImage = true; // You can rename this to isSendingMedia
    });

    try {
      // Read video as bytes
      final bytes = await video.readAsBytes();
      final base64String = base64Encode(bytes);

      // Get file extension and mime type
      final extension = video.path.split('.').last.toLowerCase();
      String mimeType = 'video/mp4'; // default

      switch (extension) {
        case 'mp4':
          mimeType = 'video/mp4';
          break;
        case 'mov':
          mimeType = 'video/quicktime';
          break;
        case 'avi':
          mimeType = 'video/x-msvideo';
          break;
        case 'mkv':
          mimeType = 'video/x-matroska';
          break;
        case '3gp':
          mimeType = 'video/3gpp';
          break;
      }

      final message = {
        'chatId': widget.chatId,
        'message': _messageController.text.trim(), // Caption
        'sessionId': spId,
        'media': {
          'mimetype': mimeType,
          'base64': base64String,
          'filename': video.name,
        },
      };

      print(
        'Sending video message: ${(message['media'] as Map<String, dynamic>)['filename']}',
      );
      socket.emit('send_message', message);

      // Add local message to UI
      final localMessage = Message(
        body: _messageController.text.trim(),
        fromMe: true,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        type: 'video',
        mediaUrl: video.path, // Use local path for immediate display
        media: null,
      );

      setState(() {
        messages.add(localMessage);
      });

      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('Error sending video: $e');
      Get.snackbar(
        'Error',
        'Failed to send video',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        isSendingImage = false;
      });
    }
  }

  Future<void> sendDocumentMessage(XFile document) async {
    if (!isWhatsAppReady) return;

    setState(() {
      isSendingDocument = true;
    });

    try {
      // Read document as bytes
      final bytes = await document.readAsBytes();
      final base64String = base64Encode(bytes);

      // Get file extension and mime type
      final extension = document.path.split('.').last.toLowerCase();
      String mimeType = 'application/octet-stream'; // default

      switch (extension) {
        case 'pdf':
          mimeType = 'application/pdf';
          break;
        case 'doc':
          mimeType = 'application/msword';
          break;
        case 'docx':
          mimeType =
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          break;
        case 'xls':
          mimeType = 'application/vnd.ms-excel';
          break;
        case 'xlsx':
          mimeType =
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          break;
        case 'ppt':
          mimeType = 'application/vnd.ms-powerpoint';
          break;
        case 'pptx':
          mimeType =
              'application/vnd.openxmlformats-officedocument.presentationml.presentation';
          break;
        case 'txt':
          mimeType = 'text/plain';
          break;
        case 'csv':
          mimeType = 'text/csv';
          break;
        case 'zip':
          mimeType = 'application/zip';
          break;
        case 'rar':
          mimeType = 'application/vnd.rar';
          break;
        case '7z':
          mimeType = 'application/x-7z-compressed';
          break;
        case 'mp3':
          mimeType = 'audio/mpeg';
          break;
        case 'mp4':
          mimeType = 'video/mp4';
          break;
        case 'avi':
          mimeType = 'video/x-msvideo';
          break;
        case 'mov':
          mimeType = 'video/quicktime';
          break;
      }

      final mediaInfo = {
        'mimetype': mimeType,
        'base64': base64String,
        'filename': document.name,
      };

      // Fixed: Match the expected socket structure
      final message = {
        'sessionId': spId,
        'chatId': widget.chatId,
        'message': _messageController.text.trim(),
        'media': mediaInfo,
      };

      print('Sending document message: ${document.name}');
      print('Message structure: $message');

      socket.emit('send_message', message);

      // Fixed: Include media info in local message
      final localMessage = Message(
        body: _messageController.text.trim(),
        fromMe: true,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        type: 'document',
        mediaUrl: document.path,
        media: mediaInfo, // Include media info for local display
      );

      setState(() {
        messages.add(localMessage);
      });

      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('Error sending document: $e');
      Get.snackbar(
        'Error',
        'Failed to send document',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        isSendingDocument = false;
      });
    }
  }

  Future<void> sendImageMessage(XFile image) async {
    if (!isWhatsAppReady) return;

    setState(() {
      isSendingImage = true;
    });

    try {
      // Read image as bytes
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);

      // Get file extension and mime type
      final extension = image.path.split('.').last.toLowerCase();
      String mimeType = 'image/jpeg'; // default

      switch (extension) {
        case 'png':
          mimeType = 'image/png';
          break;
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
      }

      final message = {
        'chatId': widget.chatId,
        'message': _messageController.text.trim(), // Caption
        'sessionId': spId,
        'media': {
          'mimetype': mimeType,
          'base64': base64String,
          'filename': image.name,
        },
      };

      print(
        'Sending image message: ${(message['media'] as Map<String, dynamic>)['filename']}',
      );
      socket.emit('send_message', message);

      final localMessage = Message(
        body: _messageController.text.trim(),
        fromMe: true,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        type: 'image',
        mediaUrl: image.path, // Use local path for immediate display
        media: null,
      );

      // );

      setState(() {
        messages.add(localMessage);
      });

      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('Error sending image: $e');
      Get.snackbar(
        'Error',
        'Failed to send image',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        isSendingImage = false;
      });
    }
  }

  void sendMessage() {
    if (_messageController.text.trim().isEmpty || !isWhatsAppReady) return;

    final message = {
      'chatId': widget.chatId,
      'message': _messageController.text,
      'sessionId': spId,
    };

    print('Sending message: ${jsonEncode(message)}');
    final localMessage = Message(
      body: _messageController.text,
      fromMe: true,
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      type: 'chat',
      mediaUrl: null,
      media: null,
    );

    socket.emit('send_message', message);

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
            Navigator.pop(context);
            disconnectSocket();
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
                      // ? 'Initializing...'
                      ? 'Connected'
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
                // Get.snackbar(
                //   'Info',
                //   'Reconnecting...',
                //   backgroundColor: AppColors.colorsBlue,
                //   colorText: Colors.white,
                // );
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
                                          SvgPicture.asset(
                                            'assets/whatsapp.svg', // Replace with your SVG path
                                            width: 80,
                                            height: 80,
                                            color: Colors
                                                .green[400], // Optional: applies color to the SVG
                                            fit: BoxFit.fill,
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    InkWell(
                                      onTap: () {
                                        if (isLoggedOut) {
                                          resendQR(); // Call resendQR if user was logged out
                                          print('Resend QR clicked');
                                        } else {
                                          initWhatsAppChat(
                                            context,
                                          ); // Call normal init for first connection
                                          print('Connect WhatsApp clicked');
                                        }
                                      },
                                      child: Container(
                                        width: double
                                            .infinity, // Makes it full width
                                        constraints: BoxConstraints(
                                          minHeight:
                                              44, // Minimum touch target size
                                          maxWidth:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.9, // Max 90% of screen width
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.04, // 4% of screen width
                                          vertical:
                                              MediaQuery.of(
                                                context,
                                              ).size.height *
                                              0.01, // 1% of screen height
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.colorsBlue,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            isLoading
                                                ? 'Connecting...'
                                                : isLoggedOut
                                                ? 'Reconnect WhatsApp'
                                                : 'WhatsApp not connected, connect now?',
                                            style: AppFont.appbarfontWhite(
                                              context,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines:
                                                2, // Allows text to wrap to 2 lines if needed
                                            overflow: TextOverflow.ellipsis,
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
                        IconButton(
                          onPressed: isSendingImage ? null : attachment,
                          icon: isSendingImage
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.colorsBlueButton,
                                    ),
                                  ),
                                )
                              : Icon(Icons.attachment_sharp),
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
                            color: AppColors.iconGrey,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt_rounded),
                            color: Colors.white,
                            onPressed: () async {
                              // Navigator.pop(context);
                              final XFile? image = await _picker.pickImage(
                                source: ImageSource.camera,
                                imageQuality: 70,
                              );
                              if (image != null) {
                                await sendImageMessage(image);
                              }
                            },
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
