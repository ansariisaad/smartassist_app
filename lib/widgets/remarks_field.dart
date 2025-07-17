// import 'dart:async';
// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:speech_to_text/speech_recognition_result.dart' as stt;
// import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_sound/flutter_sound.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:path_provider/path_provider.dart';

// class EnhancedSpeechTextField extends StatefulWidget {
//   final bool isRequired;
//   final String label;
//   final TextEditingController controller;
//   final String hint;
//   final Function(String)? onChanged;
//   final bool enabled;
//   final int maxLines;
//   final int minLines;
//   final Color? primaryColor;
//   final Color? backgroundColor;
//   final Color? textColor;
//   final double? fontSize;
//   final EdgeInsets? contentPadding;
//   final Duration listenDuration;
//   final Duration pauseDuration;

//   const EnhancedSpeechTextField({
//     Key? key,
//     required this.label,
//     required this.controller,
//     required this.hint,
//     this.onChanged,
//     this.enabled = true,
//     this.maxLines = 5,
//     this.minLines = 1,
//     this.primaryColor,
//     this.backgroundColor,
//     this.textColor,
//     this.fontSize = 14,
//     this.contentPadding,
//     this.listenDuration = const Duration(seconds: 30),
//     this.pauseDuration = const Duration(seconds: 3), // Changed to 3 seconds
//     this.isRequired = false,
//   }) : super(key: key);

//   @override
//   State<EnhancedSpeechTextField> createState() =>
//       _EnhancedSpeechTextFieldState();
// }

// class _EnhancedSpeechTextFieldState extends State<EnhancedSpeechTextField> {
//   stt.SpeechToText? _speech;
//   FlutterSoundRecorder? _recorder;
//   AudioPlayer? _player;

//   bool _isListening = false;
//   bool _speechAvailable = false;
//   bool _recorderInitialized = false;

//   String? _recordedFilePath;
//   Timer? _silenceTimer;

//   bool _isPlaying = false;

//   Color get _primaryColor => widget.primaryColor ?? Colors.blue;

//   @override
//   void initState() {
//     super.initState();
//     _speech = stt.SpeechToText();
//     _player = AudioPlayer();
//     _recorder = FlutterSoundRecorder();

//     _player!.playerStateStream.listen((state) {
//       if (mounted) {
//         setState(() {
//           _isPlaying = state.playing;
//         });
//       }
//     });

//     _initRecorder();
//     _initSpeech();
//   }

//   Future<void> _initRecorder() async {
//     try {
//       await _recorder!.openRecorder();
//       final micStatus = await Permission.microphone.request();
//       if (mounted) {
//         setState(() {
//           _recorderInitialized = micStatus.isGranted;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _recorderInitialized = false;
//         });
//       }
//     }
//   }

//   Future<void> _initSpeech() async {
//     try {
//       bool available = await _speech!.initialize(
//         onStatus: _onSpeechStatus,
//         onError: _onSpeechError,
//       );
//       if (mounted) {
//         setState(() {
//           _speechAvailable = available;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() {
//           _speechAvailable = false;
//         });
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _silenceTimer?.cancel();
//     _speech?.stop();
//     _speech = null;
//     _player?.dispose();
//     _recorder?.closeRecorder();
//     _recorder = null;
//     super.dispose();
//   }

//   void _onSpeechStatus(String status) {
//     print("Speech Status: $status");
//     if (status == 'done' || status == 'notListening') {
//       _stopListeningAndRecording();
//     }
//   }

//   void _onSpeechError(dynamic error) {
//     print("Speech Error: $error");
//     _stopListeningAndRecording();
//   }

//   Future<void> _startListening() async {
//     if (!_speechAvailable || !_recorderInitialized) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Microphone or speech permission not granted'),
//         ),
//       );
//       return;
//     }

//     // Stop any playing audio
//     await _player?.stop();

//     // Delete old recording if exists
//     if (_recordedFilePath != null) {
//       final file = File(_recordedFilePath!);
//       if (file.existsSync()) {
//         await file.delete();
//       }
//     }

//     // Create new recording file
//     final docsDir = await getApplicationDocumentsDirectory();
//     _recordedFilePath =
//         '${docsDir.path}/speech_${DateTime.now().millisecondsSinceEpoch}.aac';

//     try {
//       // Start recording
//       await _recorder!.startRecorder(
//         toFile: _recordedFilePath,
//         codec: Codec.aacADTS,
//       );

//       // Start speech recognition with continuous listening
//       await _speech!.listen(
//         onResult: _onSpeechResult,
//         listenFor: widget.listenDuration,
//         pauseFor: widget.pauseDuration,
//         partialResults: true, // Show partial results as user speaks
//         cancelOnError: false,
//         listenMode: stt.ListenMode.dictation,
//       );

//       setState(() {
//         _isListening = true;
//         _isPlaying = false;
//       });

//       // Start silence timer
//       _startSilenceTimer();
//     } catch (e) {
//       print("Error starting recording/listening: $e");
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Error starting recording: $e')));
//     }
//   }

//   Future<void> _stopListeningAndRecording() async {
//     if (_isListening) {
//       _silenceTimer?.cancel();

//       if (mounted) {
//         setState(() {
//           _isListening = false;
//         });
//       }

//       try {
//         if (_speech!.isListening) {
//           await _speech!.stop();
//         }
//       } catch (e) {
//         print("Error stopping speech: $e");
//       }

//       try {
//         if (_recorder!.isRecording) {
//           await _recorder!.stopRecorder();
//         }
//       } catch (e) {
//         print("Error stopping recorder: $e");
//       }
//     }
//   }

//   void _startSilenceTimer() {
//     _silenceTimer?.cancel();
//     _silenceTimer = Timer(const Duration(seconds: 3), () {
//       if (_isListening && mounted) {
//         _stopListeningAndRecording();
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Stopped due to 3 seconds of silence')),
//         );
//       }
//     });
//   }

//   void _onSpeechResult(stt.SpeechRecognitionResult result) {
//     // Reset silence timer when speech is detected
//     if (result.recognizedWords.isNotEmpty) {
//       _startSilenceTimer();
//     }

//     // Update text field with recognized words (both partial and final)
//     if (result.recognizedWords.isNotEmpty) {
//       _updateText(result.recognizedWords, result.finalResult);
//     }
//   }

//   void _updateText(String newText, bool isFinal) {
//     if (newText.trim().isEmpty) return;

//     String currentText = widget.controller.text;
//     String formatted = newText.trim();

//     // Capitalize first letter
//     if (formatted.isNotEmpty) {
//       formatted = formatted[0].toUpperCase() + formatted.substring(1);
//     }

//     if (isFinal) {
//       // For final results, add proper spacing
//       if (currentText.isEmpty) {
//         widget.controller.text = formatted;
//       } else if (currentText.endsWith(' ')) {
//         widget.controller.text = currentText + formatted;
//       } else {
//         widget.controller.text = currentText + ' ' + formatted;
//       }
//     } else {
//       // For partial results, show live preview
//       if (currentText.isEmpty) {
//         widget.controller.text = formatted;
//       } else {
//         // Find the last sentence boundary and replace from there
//         int lastSentenceEnd = currentText.lastIndexOf('. ');
//         if (lastSentenceEnd == -1) {
//           lastSentenceEnd = currentText.lastIndexOf('? ');
//         }
//         if (lastSentenceEnd == -1) {
//           lastSentenceEnd = currentText.lastIndexOf('! ');
//         }

//         if (lastSentenceEnd != -1) {
//           widget.controller.text =
//               currentText.substring(0, lastSentenceEnd + 2) + formatted;
//         } else {
//           widget.controller.text = formatted;
//         }
//       }
//     }

//     // Move cursor to end
//     widget.controller.selection = TextSelection.fromPosition(
//       TextPosition(offset: widget.controller.text.length),
//     );

//     // Notify parent of change
//     widget.onChanged?.call(widget.controller.text);
//   }

//   Widget _buildAudioPlayerControls() {
//     if (_recordedFilePath == null || !File(_recordedFilePath!).existsSync()) {
//       return const SizedBox.shrink();
//     }

//     return Row(
//       mainAxisAlignment: MainAxisAlignment.start,
//       children: [
//         IconButton(
//           iconSize: 32,
//           icon: Icon(
//             _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
//             color: _primaryColor,
//           ),
//           onPressed: () async {
//             try {
//               if (_isPlaying) {
//                 await _player!.pause();
//               } else {
//                 await _player!.setFilePath(_recordedFilePath!);
//                 await _player!.play();
//               }
//             } catch (e) {
//               print("Error playing audio: $e");
//             }
//           },
//         ),
//         const SizedBox(width: 8),
//         const Text('Play recorded audio', style: TextStyle(fontSize: 16)),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text.rich(
//           TextSpan(
//             text: widget.label,
//             style: TextStyle(
//               fontWeight: FontWeight.w600,
//               fontSize: widget.fontSize,
//               color: Colors.black,
//             ),
//             children: widget.isRequired
//                 ? [
//                     const TextSpan(
//                       text: ' *',
//                       style: TextStyle(color: Colors.red),
//                     ),
//                   ]
//                 : null,
//           ),
//         ),
//         const SizedBox(height: 8),
//         TextField(
//           controller: widget.controller,
//           enabled: widget.enabled && !_isListening,
//           maxLines: widget.maxLines,
//           minLines: widget.minLines,
//           keyboardType: TextInputType.multiline,
//           decoration: InputDecoration(
//             hintText: _isListening
//                 ? 'Listening... (3 sec silence to stop)'
//                 : widget.hint,
//             border: const OutlineInputBorder(),
//             suffixIcon: IconButton(
//               icon: Icon(
//                 _isListening ? Icons.stop : Icons.mic,
//                 color: _isListening ? Colors.red : _primaryColor,
//               ),
//               onPressed: () {
//                 if (_isListening) {
//                   _stopListeningAndRecording();
//                 } else {
//                   _startListening();
//                 }
//               },
//             ),
//           ),
//           style: TextStyle(
//             fontSize: widget.fontSize,
//             color: widget.textColor ?? Colors.black,
//           ),
//           onChanged: widget.onChanged,
//         ),
//         const SizedBox(height: 12),
//         if (!_isListening) _buildAudioPlayerControls(),
//       ],
//     );
//   }
// }

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

class EnhancedSpeechTextField extends StatefulWidget {
  final bool isRequired;
  final String label;
  final TextEditingController controller;
  final String hint;
  final Function(String)? onChanged;
  final bool enabled;
  final int maxLines;
  final int minLines;
  final Color? primaryColor;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final EdgeInsets? contentPadding;
  final bool showLiveTranscription;
  final Duration listenDuration;
  final Duration pauseDuration;

  const EnhancedSpeechTextField({
    Key? key,
    required this.label,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 5,
    this.minLines = 1,
    this.primaryColor,
    this.backgroundColor,
    this.textColor,
    this.fontSize = 14,
    this.contentPadding,
    this.showLiveTranscription = true,
    this.listenDuration = const Duration(seconds: 30),
    this.pauseDuration = const Duration(seconds: 5),
    required this.isRequired,
  }) : super(key: key);

  @override
  State<EnhancedSpeechTextField> createState() =>
      _EnhancedSpeechTextFieldState();
}

class _EnhancedSpeechTextFieldState extends State<EnhancedSpeechTextField>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  stt.SpeechToText? _speech;
  bool _isListening = false;
  bool _isInitialized = false;
  bool _speechAvailable = false;
  String _currentLocaleId = '';
  late AnimationController _waveController;
  Timer? _forceStopTimer;
  Timer? _stateCheckTimer;
  Timer? _engineSyncTimer;
  bool _isDisposing = false;
  bool _isProcessing = false;
  String? _lastError;

  Color get _primaryColor => widget.primaryColor ?? Colors.grey.shade800;
  Color get _errorColor => Colors.red;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    // _checkPermissionStatus();
    _initSpeechEngine();
    _forceAnimationSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isDisposing = true;
    _cancelAllTimers();
    _waveController.dispose();
    _killSpeechEngine();
    super.dispose();
  }

  void _cancelAllTimers() {
    _forceStopTimer?.cancel();
    _stateCheckTimer?.cancel();
    _engineSyncTimer?.cancel();
  }

  Future<void> _checkPermissionStatus() async {
    if (Platform.isIOS) {
      PermissionStatus micStatus = await Permission.microphone.status;
      PermissionStatus speechStatus = await Permission.speech.status;

      debugPrint('Microphone permission: $micStatus');
      debugPrint('Speech permission: $speechStatus');

      if (micStatus.isPermanentlyDenied || speechStatus.isPermanentlyDenied) {
        debugPrint('Permissions permanently denied - showing settings dialog');
        _showPermissionDialog();
        return;
      }
    } else {
      PermissionStatus micStatus = await Permission.microphone.status;
      debugPrint('Microphone permission: $micStatus');

      if (micStatus.isPermanentlyDenied) {
        debugPrint(
          'Microphone permission permanently denied - showing settings dialog',
        );
        _showPermissionDialog();
        return;
      }
    }
  }

  // === Always force UI to match engine ===
  void _forceAnimationSync() {
    _stateCheckTimer?.cancel();
    _stateCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || _isDisposing || _speech == null) return;
      final actuallyListening = _speech!.isListening;
      if (_isListening != actuallyListening) {
        setState(() => _isListening = actuallyListening);
        if (actuallyListening) {
          _waveController.repeat();
        } else {
          _waveController.stop();
          _waveController.reset();
        }
      }
      if (!actuallyListening) {
        _waveController.stop();
        _waveController.reset();
      }
    });
  }

  Future<void> _killSpeechEngine() async {
    try {
      if (_speech != null) {
        if (_speech!.isListening) {
          await _speech!.stop();
          await Future.delayed(const Duration(milliseconds: 100));
          await _speech!.cancel();
        }
      }
    } catch (_) {}
    _speech = null;
  }

  Future<void> _initSpeechEngine() async {
    _isProcessing = true;
    await _killSpeechEngine();
    _speech = stt.SpeechToText();
    try {
      bool hasPermission = await _checkMicrophonePermission();
      if (!mounted) return;
      if (!hasPermission) {
        setState(() {
          _isInitialized = true;
          _speechAvailable = false;
        });
        _showFeedback("Microphone permission not granted", isError: true);
        return;
      }

      // if (!hasPermission) {
      //   setState(() => _isInitialized = true);
      //   _isProcessing = false;
      //   return;
      // }
      _speechAvailable = await _speech!.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: false,
      );
      if (_speechAvailable) {
        final locales = await _speech!.locales();
        debugPrint('Available locales:');
        for (var locale in locales) {
          debugPrint('${locale.localeId} (${locale.name})');
        }
        // Pick your preferred locale or default to first
        List<String> englishLocaleIds = [
          'en_US',
          'en_GB',
          'en_IN',
          'en_AU',
          'en_CA',
          'en_IE',
          'en_SG',
        ];
        _currentLocaleId = locales
            .map((l) => l.localeId)
            .firstWhere(
              (id) => englishLocaleIds.contains(id),
              orElse: () => locales.first.localeId,
            );
        debugPrint('Speech will use locale: $_currentLocaleId');
      }
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Speech init error: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _speechAvailable = false;
        });
      }
    }
    _isProcessing = false;
  }

  Future<bool> _checkMicrophonePermission() async {
    try {
      // if (Platform.isIOS) {
      // This handles both microphone and speech recognition permissions
      // bool hasPermission = await _speech!.hasPermission;

      //   if (!hasPermission) {
      //     // Show dialog explaining what to do
      //     _showPermissionDialog();
      //     return false;
      //   }

      //   return true;
      // } else {
      if (Platform.isIOS) {
        // Double check: both permission_handler AND speech_to_text
        bool speechPermission = await _speech!.hasPermission;
        PermissionStatus micStatus = await Permission.microphone.status;

        // If speech_to_text says yes, trust it (handles iOS 17+ bug)
        if (speechPermission) {
          return true;
        }

        // If both are denied, show dialog
        if (!speechPermission && !micStatus.isGranted) {
          _showPermissionDialog();
          return false;
        }

        return speechPermission;
      } else {
        // Android - still use permission_handler for microphone
        PermissionStatus micStatus = await Permission.microphone.status;

        if (micStatus.isGranted) {
          return true;
        }

        if (micStatus.isPermanentlyDenied) {
          _showPermissionDialog();
          return false;
        }

        PermissionStatus requestResult = await Permission.microphone.request();
        if (!requestResult.isGranted) {
          _showPermissionDialog();
        }
        return requestResult.isGranted;
      }
    } catch (e) {
      debugPrint('Permission check error: $e');
      return false;
    }
  }

  // Also update the permission dialog for iOS
  void _showPermissionDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: Text(
          Platform.isIOS
              ? 'This app needs microphone and speech recognition permissions to work properly. Please enable them in Settings > Privacy & Security > Microphone and Speech Recognition.'
              : 'This app needs microphone permission to work properly. Please enable it in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    debugPrint('[onStatus] $status');
    if (status == 'notListening' || status == 'done') {
      _updateListeningUI(false);
      _forceStopTimer?.cancel();
      // Aggressive cleanup to prevent system sound popup
      Future.delayed(const Duration(milliseconds: 50), () async {
        if (mounted && _speech != null) {
          try {
            await _speech!.cancel();
            // Additional delay and reinit to ensure clean state
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted && !_isListening) {
              _initSpeechEngine();
            }
          } catch (_) {}
        }
      });
    } else if (status == 'listening') {
      _updateListeningUI(true);
      _startForceStopTimer();
    }
  }

  void _onSpeechError(dynamic error) {
    if (!mounted) return;
    debugPrint('[onError] $error');
    _updateListeningUI(false);
    _lastError = error.toString();
    _showFeedback(_getErrorMessage(_lastError!), isError: true);
    _forceStopTimer?.cancel();

    // Aggressive cleanup to prevent system sound popup after error
    Future.delayed(const Duration(milliseconds: 50), () async {
      if (mounted && _speech != null) {
        try {
          await _speech!.cancel();
          // Kill and reinitialize engine to prevent phantom mic sounds
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted && !_isListening) {
            await _killSpeechEngine();
            await Future.delayed(const Duration(milliseconds: 200));
            _initSpeechEngine();
          }
        } catch (_) {}
      }
    });

    // For Samsung bug: show help
    if (_lastError != null &&
        (_lastError!.contains('Speech recognition not available') ||
            _lastError!.contains('ERROR_CLIENT') ||
            _lastError!.contains('not available on device'))) {
      _showSamsungSpeechErrorDialog();
    }
  }

  void _showSamsungSpeechErrorDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Speech Input Not Working'),
        content: const Text(
          'Speech-to-text is not available on your device or requires Samsung Voice Input to be enabled. '
          '\n\nPlease:\n'
          '1. Go to Settings > General Management > Keyboard list and default\n'
          '2. Enable Google Voice Typing or your preferred Speech service\n'
          '3. Set it as default\n'
          'If problem persists, try updating Google App and Samsung Keyboard via Play Store.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _updateListeningUI(bool listening) {
    if (!mounted) return;
    if (_isListening != listening) {
      setState(() => _isListening = listening);
    }
    if (listening) {
      _waveController.repeat();
    } else {
      _waveController.stop();
      _waveController.reset();
    }
  }

  void _startForceStopTimer() {
    _forceStopTimer?.cancel();
    _forceStopTimer = Timer(const Duration(seconds: 10), () async {
      if (mounted && _isListening) {
        debugPrint('[SAFETY TIMEOUT] No speech or engine event - force stop.');
        // Immediate UI update
        _updateListeningUI(false);

        // Aggressive cleanup sequence to prevent system sound popup
        try {
          if (_speech != null && _speech!.isListening) {
            await _speech!.stop();
            await Future.delayed(const Duration(milliseconds: 300));
            await _speech!.cancel();
            await Future.delayed(const Duration(milliseconds: 200));
            // Kill and reinitialize engine to ensure clean state
            await _killSpeechEngine();
            await Future.delayed(const Duration(milliseconds: 300));
            _initSpeechEngine();
          }
        } catch (_) {}

        _showFeedback("Mic stopped due to inactivity.", isError: true);
      }
    });
  }

  Future<void> _startListening() async {
    if (!mounted || !_isInitialized || !_speechAvailable || _isProcessing)
      return;
    if (_speech == null) return;
    // Extra permission check for Android/Samsung
    if (!await _checkMicrophonePermission()) {
      _showFeedback("Please enable microphone permissions!", isError: true);
      return;
    }

    if (_speech!.isListening) {
      await _speech!.stop();
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _updateListeningUI(true);
    try {
      await _speech!.listen(
        onResult: _onSpeechResult,
        listenFor: widget.listenDuration,
        pauseFor: widget.pauseDuration,
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      );
      _startForceStopTimer();
    } catch (e) {
      _updateListeningUI(false);
      _showFeedback(_getErrorMessage(e.toString()), isError: true);
      _forceStopTimer?.cancel();

      // Samsung fix
      if (e.toString().contains('Speech recognition not available') ||
          e.toString().contains('ERROR_CLIENT') ||
          e.toString().contains('not available on device')) {
        _showSamsungSpeechErrorDialog();
      }
    }
  }

  Future<void> _stopListening() async {
    if (!mounted || _speech == null) return;
    _forceStopTimer?.cancel();

    // Set UI state immediately to prevent any new operations
    _updateListeningUI(false);

    try {
      if (_speech!.isListening) {
        // Stop first
        await _speech!.stop();
        // Wait longer to ensure stop is processed
        await Future.delayed(const Duration(milliseconds: 300));
        // Force cancel to ensure microphone is completely released
        await _speech!.cancel();
        // Additional delay to ensure system processes the cancel
        await Future.delayed(const Duration(milliseconds: 200));
      }
    } catch (_) {}

    // Force reinitialize speech engine to clean state
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_isListening) {
        _initSpeechEngine();
      }
    });
  }

  String _getErrorMessage(String error) {
    if (error.contains('speech timeout') || error.contains('e_4')) {
      return 'Listening timed out. Please speak sooner.';
    } else if (error.contains('no-speech') || error.contains('e_6')) {
      return 'No speech was detected.';
    } else if (error.contains('network') || error.contains('e_7')) {
      return 'A network error occurred.';
    } else if (error.contains('audio') || error.contains('e_3')) {
      return 'Microphone access error.';
    } else if (error.contains('Speech recognition not available') ||
        error.contains('ERROR_CLIENT')) {
      return 'Speech-to-text is not available on this device. Please check your keyboard or voice input settings.';
    }
    return 'No speech was detected.';
  }

  void _onSpeechResult(stt.SpeechRecognitionResult result) {
    if (!mounted) return;
    if (result.finalResult) {
      _addToTextField(result.recognizedWords);
      // Stop listening immediately after getting final result
      Future.delayed(const Duration(milliseconds: 200), () async {
        if (mounted && _isListening) {
          // Immediate UI update
          _updateListeningUI(false);

          // Aggressive cleanup to prevent system sound popup
          try {
            if (_speech != null && _speech!.isListening) {
              await _speech!.stop();
              await Future.delayed(const Duration(milliseconds: 300));
              await _speech!.cancel();
            }
          } catch (_) {}
        }
      });
    }
    if (_isListening) _startForceStopTimer();
  }

  void _addToTextField(String words) {
    if (words.trim().isEmpty) return;
    String currentText = widget.controller.text;
    String formattedWords = words.trim();
    if (formattedWords.isNotEmpty) {
      formattedWords =
          formattedWords[0].toUpperCase() + formattedWords.substring(1);
    }
    if (currentText.isEmpty || currentText.endsWith(' ')) {
      widget.controller.text += formattedWords;
    } else {
      widget.controller.text += ' $formattedWords';
    }
    if (!widget.controller.text.endsWith(' ')) {
      widget.controller.text += ' ';
    }
    widget.onChanged?.call(widget.controller.text);
  }

  void _showFeedback(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? _errorColor : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state.toString() == 'AppLifecycleState.hidden') {
      _stopListening();
      _waveController.stop();
      _waveController.reset();
    }
    if (state == AppLifecycleState.resumed) {
      _forceAnimationSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildLabel(), _buildInputContainer()],
    );
  }

  Widget _buildLabel() {
    return Padding(
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
    );
  }

  Widget _buildInputContainer() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: widget.backgroundColor ?? Colors.grey.shade100,
      ),
      child: Row(
        children: [
          Expanded(child: _buildTextField()),
          _buildSpeechButton(),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled && !_isListening,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      keyboardType: TextInputType.multiline,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: _isListening ? "Listening..." : widget.hint,
        hintStyle: GoogleFonts.poppins(
          color: _isListening ? _primaryColor : Colors.grey.shade600,
        ),
        contentPadding:
            widget.contentPadding ??
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: InputBorder.none,
      ),
      style: TextStyle(
        fontSize: widget.fontSize,
        color: widget.textColor ?? Colors.black,
      ),
    );
  }

  Widget _buildSpeechButton() {
    if (!_speechAvailable) {
      return IconButton(
        onPressed: null,
        icon: Icon(Icons.mic_off, color: Colors.grey),
        tooltip: 'Microphone not available',
      );
    }

    if (!_isInitialized) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return IconButton(
      onPressed: (_speechAvailable && !_isProcessing)
          ? () {
              if (_isListening) {
                _stopListening();
              } else {
                _startListening();
              }
            }
          : null,

      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _isListening ? FontAwesomeIcons.stop : FontAwesomeIcons.microphone,
          key: ValueKey(_isListening),
          color: _isListening
              ? Colors.red
              : (_speechAvailable ? _primaryColor : Colors.grey),
          size: 16,
        ),
      ),
      tooltip: _isListening ? 'Stop recording' : 'Start voice input',
      splashRadius: 24,
    );
  }
}