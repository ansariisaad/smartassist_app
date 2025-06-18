// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:smartassist/config/component/font/font.dart';
// import 'package:speech_to_text/speech_recognition_result.dart' as stt;
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:permission_handler/permission_handler.dart';

// class EnhancedSpeechTextField extends StatefulWidget {
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
//   final bool showLiveTranscription;
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
//     this.showLiveTranscription = true,
//     this.listenDuration = const Duration(seconds: 30),
//     this.pauseDuration = const Duration(
//       seconds: 5,
//     ), // Increased default for better timeout handling
//   }) : super(key: key);

//   @override
//   State<EnhancedSpeechTextField> createState() =>
//       _EnhancedSpeechTextFieldState();
// }

// class _EnhancedSpeechTextFieldState extends State<EnhancedSpeechTextField>
//     with TickerProviderStateMixin {
//   final stt.SpeechToText _speech = stt.SpeechToText();

//   // State variables
//   bool _isListening = false;
//   bool _isInitialized = false;
//   bool _speechAvailable = false;
//   String _currentWords = '';
//   String _currentLocaleId = '';
//   double _confidence = 0.0;

//   late AnimationController _waveController;
//   late Animation<double> _waveAnimation;

//   // Colors
//   Color get _primaryColor => widget.primaryColor ?? AppColors.iconGrey;
//   Color get _errorColor => Colors.red;

//   @override
//   void initState() {
//     super.initState();
//     _initializeAnimations();
//     _initializeSpeech();
//   }

//   @override
//   void dispose() {
//     _cleanupResources();
//     super.dispose();
//   }

//   void _initializeAnimations() {
//     _waveController = AnimationController(
//       duration: const Duration(milliseconds: 1200),
//       vsync: this,
//     );
//     _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
//     );
//   }

//   Future<void> _initializeSpeech() async {
//     try {
//       bool hasPermission = await _checkMicrophonePermission();
//       if (!mounted) return;

//       if (!hasPermission) {
//         if (mounted) setState(() => _isInitialized = true);
//         return;
//       }

//       _speechAvailable = await _speech.initialize(
//         onStatus: _onSpeechStatus,
//         onError: _onSpeechError,
//         debugLogging: false,
//       );

//       if (_speechAvailable) {
//         var locales = await _speech.locales();
//         var englishLocale = locales.firstWhere(
//           (locale) => locale.localeId.startsWith('en'),
//           orElse: () => stt.LocaleName('en_US', 'English'),
//         );
//         _currentLocaleId = englishLocale.localeId;
//       }
//       if (mounted) setState(() => _isInitialized = true);
//     } catch (e) {
//       debugPrint('Speech initialization error: $e');
//       if (mounted)
//         setState(() {
//           _isInitialized = true;
//           _speechAvailable = false;
//         });
//     }
//   }

//   Future<bool> _checkMicrophonePermission() async {
//     return await Permission.microphone.request().isGranted;
//   }

//   // --- THIS IS A KEY FIX ---
//   // This method now acts as a "watchdog" to keep the UI in sync.
//   void _onSpeechStatus(String status) {
//     if (!mounted) return;
//     debugPrint('Speech engine status: $status. UI is listening: $_isListening');

//     // If the native engine stops listening for any reason (timeout, end of speech, etc.)
//     if (status == 'notListening' || status == 'done') {
//       // And if our UI still thinks it's listening, we must force a synchronization.
//       if (_isListening) {
//         debugPrint('Engine stopped unexpectedly. Forcing UI to update.');
//         // We call our unified stop method to ensure everything resets correctly.
//         _stopListening();
//       }
//     }
//   }

//   void _onSpeechError(dynamic error) {
//     debugPrint('Speech error received: $error');
//     if (!mounted) return;
//     // Pass the error to the stop method so it can be displayed.
//     _stopListening(showError: true, error: error.toString());
//   }

//   String _getErrorMessage(String error) {
//     if (error.contains('speech timeout') || error.contains('e_4')) {
//       return 'Listening timed out. Please speak sooner.';
//     } else if (error.contains('no-speech') || error.contains('e_6')) {
//       return 'No speech was detected.';
//     } else if (error.contains('network') || error.contains('e_7')) {
//       return 'A network error occurred.';
//     } else if (error.contains('audio') || error.contains('e_3')) {
//       return 'Microphone access error.';
//     }
//     return 'An unknown error occurred.';
//   }

//   void _startAnimations() {
//     if (mounted && !_waveController.isAnimating) {
//       _waveController.repeat();
//     }
//   }

//   void _stopAnimations() {
//     if (mounted && _waveController.isAnimating) {
//       _waveController.stop();
//       _waveController.reset();
//     }
//   }

//   Future<void> _toggleSpeechRecognition() async {
//     if (!_isInitialized) return;
//     if (!_speechAvailable) {
//       _showFeedback('Speech recognition not available.', isError: true);
//       _initializeSpeech(); // Attempt to re-initialize
//       return;
//     }

//     if (_isListening) {
//       await _stopListening();
//     } else {
//       await _startListening();
//     }
//   }

//   Future<void> _startListening() async {
//     if (!mounted || _isListening) return;

//     setState(() {
//       _isListening = true;
//       _currentWords = '';
//     });
//     _startAnimations();

//     try {
//       // Use cancelOnError: true so errors are reliably sent to _onSpeechError
//       await _speech.listen(
//         onResult: _onSpeechResult,
//         listenFor: widget.listenDuration,
//         pauseFor: widget.pauseDuration,
//         partialResults: true,
//         cancelOnError: true,
//         listenMode: stt.ListenMode.dictation,
//         localeId: _currentLocaleId,
//       );
//     } catch (e) {
//       debugPrint('Error on starting listen: $e');
//       await _stopListening(showError: true, error: e.toString());
//     }
//   }

//   // --- THIS IS THE SECOND KEY FIX ---
//   // A single, reliable method to stop everything and update the UI.
//   Future<void> _stopListening({bool showError = false, String? error}) async {
//     // If we are already stopped, do nothing. This prevents redundant calls.
//     if (!_isListening) return;

//     if (!mounted) return;

//     debugPrint("Stop Listening Called. Error: $showError");

//     // Immediately update the UI state. This is the crucial step.
//     setState(() {
//       _isListening = false;
//     });

//     // Now, clean up the animations and the speech engine.
//     _stopAnimations();
//     if (_speech.isListening) {
//       await _speech.stop();
//     }

//     // Display an error message if one was provided.
//     if (showError && error != null) {
//       String errorMessage = _getErrorMessage(error);
//       _showFeedback(errorMessage, isError: true);
//     }
//   }

//   void _onSpeechResult(stt.SpeechRecognitionResult result) {
//     if (!mounted) return;

//     setState(() {
//       _currentWords = result.recognizedWords;
//       _confidence = result.confidence;
//     });

//     if (result.finalResult) {
//       _addToTextField(result.recognizedWords);
//       Future.delayed(const Duration(milliseconds: 400), () {
//         if (mounted && _isListening) {
//           _stopListening();
//         }
//       });
//     }
//   }

//   void _addToTextField(String words) {
//     if (words.trim().isEmpty) return;

//     String currentText = widget.controller.text;
//     // Simple capitalization for the new phrase
//     String formattedWords = words.trim();
//     if (formattedWords.isNotEmpty) {
//       formattedWords =
//           formattedWords[0].toUpperCase() + formattedWords.substring(1);
//     }

//     if (currentText.isEmpty || currentText.endsWith(' ')) {
//       widget.controller.text += formattedWords;
//     } else {
//       widget.controller.text += ' $formattedWords';
//     }

//     if (!widget.controller.text.endsWith(' ')) {
//       widget.controller.text += ' ';
//     }

//     widget.onChanged?.call(widget.controller.text);
//   }

//   void _cleanupResources() {
//     _waveController.dispose();
//     _speech.cancel();
//   }

//   void _showFeedback(String message, {required bool isError}) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).hideCurrentSnackBar();
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message, style: const TextStyle(color: Colors.white)),
//         backgroundColor: isError ? _errorColor : Colors.green,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [_buildLabel(), _buildInputContainer()],
//     );
//   }

//   Widget _buildLabel() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 5.0),
//       child: Text(widget.label, style: AppFont.dropDowmLabel(context)),
//     );
//   }

//   Widget _buildInputContainer() {
//     return Container(
//       width: double.infinity,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(5),
//         color: AppColors.containerBg,
//       ),
//       child: Row(
//         children: [
//           Expanded(child: _buildTextField()),
//           _buildSpeechButton(),
//         ],
//       ),
//     );
//   }

//   Widget _buildTextField() {
//     return TextField(
//       controller: widget.controller,
//       enabled: widget.enabled && !_isListening,
//       maxLines: widget.maxLines,
//       minLines: widget.minLines,
//       keyboardType: TextInputType.multiline,
//       onChanged: widget.onChanged,
//       decoration: InputDecoration(
//         hintText: _isListening ? "Listening..." : widget.hint,
//         hintStyle: GoogleFonts.poppins(
//           color: _isListening ? _primaryColor : Colors.grey.shade600,
//         ),
//         contentPadding:
//             widget.contentPadding ??
//             const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//         border: InputBorder.none,
//         // prefixIcon: _isListening
//         //     ? const Padding(
//         //         padding: EdgeInsets.only(left: 12, right: 8),
//         //         child: Icon(
//         //           FontAwesomeIcons.microphoneLines,
//         //           color: Colors.red,
//         //           size: 16,
//         //         ),
//         //       )
//         //     : null,
//       ),
//       style: AppFont.dropDowmLabel(context),
//     );
//   }

  
//   Widget _buildSpeechButton() {
//     if (!_isInitialized) {
//       return const Padding(
//         padding: EdgeInsets.all(12.0),
//         child: SizedBox(
//           width: 18,
//           height: 18,
//           child: CircularProgressIndicator(strokeWidth: 2),
//         ),
//       );
//     }

//     return IconButton(
//       onPressed: _speechAvailable ? _toggleSpeechRecognition : null,
//       icon: Icon(
//         _isListening ? FontAwesomeIcons.stop : FontAwesomeIcons.microphone,
//         color: _isListening
//             ? Colors.red
//             : (_speechAvailable ? _primaryColor : AppColors.iconGrey),
//         size: 16,
//       ),
//       tooltip: _isListening ? 'Stop recording' : 'Start voice input',
//       splashRadius: 24,
//     );
//   }
// }

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:smartassist/config/component/font/font.dart';
// import 'package:speech_to_text/speech_recognition_result.dart' as stt;
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:permission_handler/permission_handler.dart';

// class EnhancedSpeechTextField extends StatefulWidget {
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
//   final bool showLiveTranscription;
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
//     this.showLiveTranscription = true,
//     this.listenDuration = const Duration(seconds: 30),
//     this.pauseDuration = const Duration(seconds: 3),
//   }) : super(key: key);

//   @override
//   State<EnhancedSpeechTextField> createState() =>
//       _EnhancedSpeechTextFieldState();
// }

// class _EnhancedSpeechTextFieldState extends State<EnhancedSpeechTextField>
//     with TickerProviderStateMixin {
//   final stt.SpeechToText _speech = stt.SpeechToText();

//   // State variables
//   bool _isListening = false;
//   bool _isInitialized = false;
//   bool _speechAvailable = false;
//   String _currentWords = '';
//   String _recognizedWords = '';
//   String _currentLocaleId = '';
//   double _confidence = 0.0;

//   // Timers and animations
//   Timer? _listeningTimer;
//   late AnimationController _pulseController;
//   late AnimationController _waveController;
//   late Animation<double> _pulseAnimation;
//   late Animation<double> _waveAnimation;

//   // Colors
//   Color get _primaryColor => widget.primaryColor ?? AppColors.iconGrey;
//   Color get _backgroundColor => widget.backgroundColor ?? Colors.grey[100]!;
//   Color get _textColor => widget.textColor ?? Colors.black;
//   Color get _errorColor => Colors.red;
//   Color get _successColor => Colors.green;

//   @override
//   void initState() {
//     super.initState();
//     _initializeAnimations();
//     _initializeSpeech();
//   }

//   @override
//   void dispose() {
//     _cleanupResources();
//     super.dispose();
//   }

//   void _initializeAnimations() {
//     _pulseController = AnimationController(
//       duration: Duration(milliseconds: 800),
//       vsync: this,
//     );

//     _waveController = AnimationController(
//       duration: Duration(milliseconds: 1200),
//       vsync: this,
//     );

//     _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
//       CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
//     );

//     _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
//     );
//   }

//   Future<void> _initializeSpeech() async {
//     try {
//       bool hasPermission = await _checkMicrophonePermission();
//       if (!hasPermission) {
//         _updateState(speechAvailable: false, initialized: true);
//         return;
//       }

//       bool available = await _speech.initialize(
//         onStatus: _onSpeechStatus,
//         onError: _onSpeechError,
//         debugLogging: false,
//       );

//       if (available) {
//         var locales = await _speech.locales();
//         var englishLocale = locales.firstWhere(
//           (locale) => locale.localeId.startsWith('en'),
//           orElse: () => locales.isNotEmpty
//               ? locales.first
//               : stt.LocaleName('en_US', 'English'),
//         );
//         _currentLocaleId = englishLocale.localeId;
//       }

//       _updateState(speechAvailable: available, initialized: true);
//     } catch (e) {
//       debugPrint('Speech initialization error: $e');
//       _updateState(speechAvailable: false, initialized: true);
//     }
//   }

//   Future<bool> _checkMicrophonePermission() async {
//     try {
//       PermissionStatus permission = await Permission.microphone.status;
//       if (permission != PermissionStatus.granted) {
//         permission = await Permission.microphone.request();
//       }
//       return permission == PermissionStatus.granted;
//     } catch (e) {
//       debugPrint('Permission check error: $e');
//       return false;
//     }
//   }

//   void _onSpeechStatus(String status) {
//     if (!mounted) return;

//     debugPrint('Speech status: $status');

//     switch (status) {
//       case 'listening':
//         _updateState(listening: true);
//         _startAnimations();
//         _startListeningTimer();
//         break;
//       case 'notListening':
//         // Don't immediately stop - keep trying to listen
//         if (_isListening) {
//           Future.delayed(Duration(milliseconds: 1000), () {
//             if (mounted && !_speech.isListening && _isListening) {
//               _restartListening();
//             }
//           });
//         }
//         break;
//       case 'done':
//         // Only stop if user manually stopped
//         _updateState(listening: false);
//         _stopAnimations();
//         _listeningTimer?.cancel();
//         _finalizeTranscription();
//         break;
//     }
//   }

//   // Add method to restart listening automatically
//   Future<void> _restartListening() async {
//     if (!_isListening || !_speechAvailable) return;

//     try {
//       debugPrint('Restarting speech recognition...');
//       await _speech.listen(
//         onResult: _onSpeechResult,
//         listenFor: Duration(seconds: 30),
//         pauseFor: Duration(seconds: 2),
//         partialResults: true,
//         cancelOnError: false,
//         listenMode: stt.ListenMode.dictation,
//         localeId: _currentLocaleId.isNotEmpty ? _currentLocaleId : 'en_US',
//       );
//     } catch (e) {
//       debugPrint('Restart listening error: $e');
//     }
//   }

//   void _onSpeechError(dynamic error) {
//     debugPrint('Speech error: $error');

//     if (!mounted) return;

//     _updateState(listening: false);
//     _stopAnimations();
//     _listeningTimer?.cancel();

//     String errorMessage = _getErrorMessage(error.toString());
//     _showFeedback(errorMessage, isError: true);
//   }

//   String _getErrorMessage(String error) {
//     if (error.contains('network')) {
//       return 'Check your internet connection';
//     } else if (error.contains('audio')) {
//       return 'Check microphone permissions';
//     } else if (error.contains('no-speech')) {
//       return 'No speech detected. Speak clearly';
//     } else if (error.contains('aborted')) {
//       return 'Speech recognition cancelled';
//     } else {
//       return 'Speech recognition failed. Try again';
//     }
//   }

//   void _startListeningTimer() {
//     _listeningTimer?.cancel();
//     _listeningTimer = Timer(widget.listenDuration, () {
//       if (_isListening && mounted) {
//         _stopListening();
//       }
//     });
//   }

//   void _startAnimations() {
//     try {
//       _pulseController.repeat(reverse: true);
//       _waveController.repeat();
//     } catch (e) {
//       debugPrint('Animation error: $e');
//     }
//   }

//   void _stopAnimations() {
//     _pulseController.stop();
//     _waveController.stop();
//     _pulseController.reset();
//     _waveController.reset();
//   }

//   void _updateState({
//     bool? listening,
//     bool? initialized,
//     bool? speechAvailable,
//     String? currentWords,
//     String? recognizedWords,
//     double? confidence,
//   }) {
//     if (!mounted) return;

//     setState(() {
//       if (listening != null) _isListening = listening;
//       if (initialized != null) _isInitialized = initialized;
//       if (speechAvailable != null) _speechAvailable = speechAvailable;
//       if (currentWords != null) _currentWords = currentWords;
//       if (recognizedWords != null) _recognizedWords = recognizedWords;
//       if (confidence != null) _confidence = confidence;
//     });
//   }

//   Future<void> _toggleSpeechRecognition() async {
//     if (!_speechAvailable) {
//       _showFeedback('Speech recognition not available', isError: true);
//       return;
//     }

//     if (_isListening) {
//       await _stopListening();
//     } else {
//       await _startListening();
//     }
//   }

//   // DateTime? _lastSoundLevelUpdate;
//   // void _startListening() async {
//   //   await _speech.listen(
//   //     onSoundLevelChange: (level) {
//   //       final now = DateTime.now();
//   //       if (_lastSoundLevelUpdate == null ||
//   //           now.difference(_lastSoundLevelUpdate!).inMilliseconds > 100) {
//   //         debugPrint('Sound level: $level');
//   //         _lastSoundLevelUpdate = now;
//   //       }
//   //     },

//   //   );
//   // }

//   Future<void> _startListening() async {
//     if (!_speechAvailable || _isListening) return;

//     try {
//       _updateState(currentWords: '', recognizedWords: '');

//       await _speech.listen(
//         onResult: _onSpeechResult,
//         listenFor: Duration(minutes: 10), // Longer listening time
//         pauseFor: Duration(seconds: 2), // Shorter pause
//         partialResults: true,
//         cancelOnError: false, // Don't cancel on errors
//         listenMode: stt.ListenMode.dictation, // Better for continuous speech
//         localeId: _currentLocaleId.isNotEmpty ? _currentLocaleId : 'en_US',
//         onSoundLevelChange: (level) {
//           // Optional: handle sound level for visual feedback
//           debugPrint('Sound level: $level');
//         },
//       );
//     } catch (e) {
//       debugPrint('Start listening error: $e');
//       _updateState(listening: false);
//       _showFeedback('Failed to start speech recognition', isError: true);
//     }
//   }

//   void _onSpeechResult(stt.SpeechRecognitionResult result) {
//     if (!mounted) return;

//     final words = result.recognizedWords;
//     final confidence = result.confidence;

//     debugPrint(
//       'Speech result: $words (confidence: $confidence, final: ${result.finalResult})',
//     );

//     if (words.isNotEmpty) {
//       // Always update current words for live display
//       _updateState(currentWords: words, confidence: confidence);

//       // For final results, add to the main text field
//       if (result.finalResult) {
//         _addToTextField(words);
//         // Don't clear current words immediately - let them fade naturally
//         Future.delayed(Duration(milliseconds: 500), () {
//           if (mounted) {
//             _updateState(currentWords: '');
//           }
//         });

//         // Show confidence feedback for very low confidence
//         if (confidence < 0.5) {
//           _showFeedback('Low confidence - please speak clearly', isError: true);
//         }
//       }
//     }
//   }

//   void _addToTextField(String words) {
//     String currentText = widget.controller.text;
//     String newText;
//     // Capitalize first letter of words
//     String formattedWords = words.isNotEmpty
//         ? words[0].toUpperCase() + words.substring(1)
//         : words;
//     if (currentText.isEmpty) {
//       newText = formattedWords;
//     } else if (currentText.endsWith(' ') ||
//         currentText.endsWith('.') ||
//         currentText.endsWith(',') ||
//         currentText.endsWith('!') ||
//         currentText.endsWith('?')) {
//       newText = '$currentText$formattedWords';
//     } else {
//       newText = '$currentText $formattedWords';
//     }
//     widget.controller.text = newText;
//     widget.onChanged?.call(newText);
//     if (!newText.endsWith(' ')) {
//       widget.controller.text = '$newText ';
//     }
//   }

//   void _finalizeTranscription() {
//     if (_currentWords.isNotEmpty && _recognizedWords != _currentWords) {
//       _addToTextField(_currentWords);
//     }
//     _updateState(currentWords: '', recognizedWords: '');
//   }

//   Future<void> _stopListening() async {
//     if (!mounted) return;

//     _listeningTimer?.cancel();

//     try {
//       if (_speech.isListening) {
//         await _speech.stop();
//       }
//     } catch (e) {
//       debugPrint('Error stopping speech: $e');
//     }

//     _updateState(listening: false);
//     _stopAnimations();
//   }

//   void _cleanupResources() {
//     _listeningTimer?.cancel();
//     _pulseController.dispose();
//     _waveController.dispose();

//     if (_speech.isListening) {
//       _speech.stop();
//     }
//   }

//   void _showFeedback(String message, {required bool isError}) {
//     if (!mounted) return;

//     try {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Row(
//             children: [
//               Icon(
//                 isError ? Icons.error_outline : Icons.check_circle_outline,
//                 color: Colors.white,
//                 size: 20,
//               ),
//               SizedBox(width: 8),
//               Expanded(child: Text(message)),
//             ],
//           ),
//           backgroundColor: isError ? _errorColor : _successColor,
//           duration: Duration(seconds: 2),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//         ),
//       );
//     } catch (e) {
//       debugPrint('Error showing feedback: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildLabel(),
//         _buildInputContainer(),
//         _buildStatusIndicator(),
//       ],
//     );
//   }

//   Widget _buildLabel() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 5.0),
//       child: Row(
//         children: [
//           Text(widget.label, style: AppFont.dropDowmLabel(context)),
//           // if (_confidence > 0.8) ...[
//           //   SizedBox(width: 8),
//           //   Icon(Icons.verified, size: 16, color: _successColor),
//           // ],
//         ],
//       ),
//     );
//   }

//   Widget _buildInputContainer() {
//     return Container(
//       width: double.infinity,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(5),
//         color: AppColors.containerBg,
//       ),
//       child: Row(
//         children: [
//           Expanded(child: _buildTextField()),
//           _buildSpeechButton(),
//         ],
//       ),
//     );
//   }

//   Widget _buildTextField() {
//     return TextField(
//       controller: widget.controller,
//       enabled:
//           widget.enabled && !_isListening, // Disable typing while listening
//       maxLines: widget.maxLines,
//       minLines: widget.minLines,
//       keyboardType: TextInputType.multiline,
//       onChanged: widget.onChanged,
//       decoration: InputDecoration(
//         hintText: _getHintText(),
//         hintStyle: GoogleFonts.poppins(
//           fontSize: widget.fontSize,
//           fontWeight: FontWeight.w400,
//           color: _isListening ? _primaryColor : Colors.grey.shade600,
//           fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
//         ),
//         contentPadding:
//             widget.contentPadding ??
//             const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//         border: InputBorder.none,
//         // Add prefix icon when listening
//         prefixIcon: _isListening
//             ? Padding(
//                 padding: const EdgeInsets.only(left: 8, right: 4),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     AnimatedBuilder(
//                       animation: _waveAnimation,
//                       builder: (context, child) {
//                         return Container(
//                           width: 8,
//                           height: 8,
//                           decoration: BoxDecoration(
//                             color: Colors.red.withOpacity(
//                               0.3 + (0.7 * _waveAnimation.value),
//                             ),
//                             shape: BoxShape.circle,
//                           ),
//                         );
//                       },
//                     ),
//                     SizedBox(width: 4),
//                     Text(
//                       'REC',
//                       style: GoogleFonts.poppins(
//                         fontSize: 10,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.red,
//                       ),
//                     ),
//                   ],
//                 ),
//               )
//             : null,
//         // Show live transcription as suffix text
//         suffixText: _isListening && _currentWords.isNotEmpty
//             ? ' $_currentWords'
//             : null,
//         suffixStyle: GoogleFonts.poppins(
//           fontSize: widget.fontSize,
//           fontWeight: FontWeight.w400,
//           color: _primaryColor.withOpacity(0.7),
//           fontStyle: FontStyle.italic,
//         ),
//       ),
//       style: AppFont.dropDowmLabel(context),
//     );
//   }

//   String _getHintText() {
//     if (_isListening) {
//       return _currentWords.isNotEmpty
//           ? 'Speaking...'
//           : 'Listening... Speak now or tap stop';
//     }
//     return widget.hint;
//   }

//   Widget _buildSpeechButton() {
//     if (!_isInitialized) {
//       return Padding(
//         padding: const EdgeInsets.all(12.0),
//         child: SizedBox(
//           width: 10,
//           height: 10,
//           child: CircularProgressIndicator(
//             strokeWidth: 2,
//             valueColor: AlwaysStoppedAnimation(_primaryColor),
//           ),
//         ),
//       );
//     }

//     return AnimatedBuilder(
//       animation: _pulseAnimation,
//       builder: (context, child) {
//         return Container(
//           // margin: EdgeInsets.all(4),
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             color: _isListening
//                 ? Colors.red.withOpacity(0.2)
//                 : Colors.transparent,
//             border: _isListening
//                 ? Border.all(color: Colors.red, width: 2)
//                 : null,
//           ),
//           child: Transform.scale(
//             scale: _isListening ? _pulseAnimation.value : 1.0,
//             child: IconButton(
//               onPressed: _speechAvailable ? _toggleSpeechRecognition : null,
//               icon: Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   // Background circle for recording state
//                   if (_isListening)
//                     Container(
//                       // width: 32,
//                       // height: 32,
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         color: Colors.red.withOpacity(0.1),
//                       ),
//                     ),
//                   // Main icon with proper colors
//                   Icon(
//                     _isListening
//                         ? FontAwesomeIcons.stop
//                         : FontAwesomeIcons.microphone,
//                     color: _isListening
//                         ? Colors.red
//                         : (_speechAvailable ? _primaryColor : Colors.grey),
//                     size: _isListening ? 16 : 18,
//                   ),
//                   // Recording indicator dot
//                   if (_isListening)
//                     Positioned(
//                       top: 0,
//                       right: 0,
//                       child: AnimatedBuilder(
//                         animation: _waveAnimation,
//                         builder: (context, child) {
//                           return Container(
//                             width: 8,
//                             height: 8,
//                             decoration: BoxDecoration(
//                               color: Colors.red.withOpacity(
//                                 0.5 + (0.5 * _waveAnimation.value),
//                               ),
//                               shape: BoxShape.circle,
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                 ],
//               ),
//               tooltip: _getTooltipText(),
//               splashRadius: 24,
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Color _getButtonColor() {
//     if (!_speechAvailable) return Colors.grey;
//     return _isListening ? _errorColor : _primaryColor;
//   }

//   String _getTooltipText() {
//     if (!_speechAvailable) return 'Speech not available';
//     return _isListening ? 'Stop recording' : 'Start voice input';
//   }

//   Widget _buildStatusIndicator() {
//     if (!_isListening) return SizedBox.shrink();

//     return Padding(
//       padding: const EdgeInsets.only(top: 8.0),
//       child: Row(
//         children: [
//           // Animated recording indicator
//           AnimatedBuilder(
//             animation: _waveAnimation,
//             builder: (context, child) {
//               return Row(
//                 children: List.generate(3, (index) {
//                   double delay = index * 0.3;
//                   double animValue = (_waveAnimation.value + delay) % 1.0;
//                   return Container(
//                     margin: EdgeInsets.only(right: 2),
//                     width: 3,
//                     height: 8 + (6 * animValue),
//                     decoration: BoxDecoration(
//                       color: _errorColor,
//                       borderRadius: BorderRadius.circular(2),
//                     ),
//                   );
//                 }),
//               );
//             },
//           ),
//           SizedBox(width: 8),
//           Text('Recording... Tap', style: AppFont.smallText12(context)),
//           Icon(FontAwesomeIcons.stop, size: 12, color: _errorColor),
//           Text(' to stop', style: AppFont.smallText12(context)),
//           Spacer(),
//           if (_confidence > 0)
//             Container(
//               padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//               decoration: BoxDecoration(
//                 color: _confidence > 0.8
//                     ? _successColor.withOpacity(0.1)
//                     : Colors.orange.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(
//                   color: _confidence > 0.8 ? _successColor : Colors.orange,
//                   width: 1,
//                 ),
//               ),
//               child: Text(
//                 '${(_confidence * 100).toInt()}%',
//                 style: GoogleFonts.poppins(
//                   fontSize: 10,
//                   color: _confidence > 0.8 ? _successColor : Colors.orange,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLiveTranscription() {
//     return Padding(
//       padding: const EdgeInsets.only(top: 8.0),
//       child: Container(
//         width: double.infinity,
//         padding: EdgeInsets.all(8),
//         decoration: BoxDecoration(
//           color: _primaryColor.withOpacity(0.1),
//           borderRadius: BorderRadius.circular(6),
//           border: Border.all(color: _primaryColor.withOpacity(0.3)),
//         ),
//         child: Row(
//           children: [
//             Icon(Icons.hearing, size: 16, color: _primaryColor),
//             SizedBox(width: 6),
//             Expanded(
//               child: Text(
//                 _currentWords.isEmpty
//                     ? 'Listening for speech...'
//                     : _currentWords,
//                 style: AppFont.smallText12(context),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


// msutafa final below this code 

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:smartassist/config/component/color/colors.dart';
// import 'package:smartassist/config/component/font/font.dart';
// import 'package:speech_to_text/speech_recognition_result.dart' as stt;
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:permission_handler/permission_handler.dart';

// class EnhancedSpeechTextField extends StatefulWidget {
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
//   final bool showLiveTranscription;
//   final Duration listenDuration;
//   final Duration pauseDuration;
//   final bool enableTTS;
//   final String preferredLanguage;
//   final bool autoReadBack; // New parameter to control auto read-back

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
//     this.showLiveTranscription = true,
//     this.listenDuration = const Duration(seconds: 30),
//     this.pauseDuration = const Duration(seconds: 5),
//     this.enableTTS = true,
//     this.preferredLanguage = 'en-IN', // Indian English by default
//     this.autoReadBack = true, // Auto read-back enabled by default
//   }) : super(key: key);

//   @override
//   State<EnhancedSpeechTextField> createState() =>
//       _EnhancedSpeechTextFieldState();
// }

// class _EnhancedSpeechTextFieldState extends State<EnhancedSpeechTextField>
//     with TickerProviderStateMixin {
//   final stt.SpeechToText _speech = stt.SpeechToText();
//   final FlutterTts _flutterTts = FlutterTts();

//   // State variables
//   bool _isListening = false;
//   bool _isInitialized = false;
//   bool _speechAvailable = false;
//   bool _isSpeaking = false;
//   bool _ttsInitialized = false;
//   String _currentWords = '';
//   String _currentLocaleId = '';
//   double _confidence = 0.0;
//   String _lastSpokenText = '';
//   Timer? _readBackTimer; // Timer for delayed read-back

//   late AnimationController _waveController;
//   late AnimationController _speakController;
//   late Animation<double> _waveAnimation;
//   late Animation<double> _speakAnimation;

//   // Colors
//   Color get _primaryColor => widget.primaryColor ?? AppColors.iconGrey;
//   Color get _errorColor => Colors.red;
//   Color get _speakingColor => const Color.fromARGB(255, 87, 87, 87);

//   @override
//   void initState() {
//     super.initState();
//     _initializeAnimations();
//     _initializeSpeech();
//     _initializeTTS();
//   }

//   @override
//   void dispose() {
//     _cleanupResources();
//     super.dispose();
//   }

//   void _initializeAnimations() {
//     _waveController = AnimationController(
//       duration: const Duration(milliseconds: 1200),
//       vsync: this,
//     );
//     _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
//     );

//     _speakController = AnimationController(
//       duration: const Duration(milliseconds: 800),
//       vsync: this,
//     );
//     _speakAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
//       CurvedAnimation(parent: _speakController, curve: Curves.easeInOut),
//     );
//   }

//   Future<void> _initializeSpeech() async {
//     try {
//       bool hasPermission = await _checkMicrophonePermission();
//       if (!mounted) return;

//       if (!hasPermission) {
//         if (mounted) setState(() => _isInitialized = true);
//         return;
//       }

//       _speechAvailable = await _speech.initialize(
//         onStatus: _onSpeechStatus,
//         onError: _onSpeechError,
//         debugLogging: false,
//       );

//       if (_speechAvailable) {
//         var locales = await _speech.locales();
//         // Try to find Indian English locale first
//         var indianLocale = locales.firstWhere(
//           (locale) => locale.localeId == 'en-IN',
//           orElse: () => locales.firstWhere(
//             (locale) => locale.localeId.startsWith('en'),
//             orElse: () => stt.LocaleName('en_US', 'English'),
//           ),
//         );
//         _currentLocaleId = indianLocale.localeId;
//       }
//       if (mounted) setState(() => _isInitialized = true);
//     } catch (e) {
//       debugPrint('Speech initialization error: $e');
//       if (mounted)
//         setState(() {
//           _isInitialized = true;
//           _speechAvailable = false;
//         });
//     }
//   }

//   Future<void> _initializeTTS() async {
//     try {
//       // Initialize TTS
//       await _flutterTts.setLanguage(widget.preferredLanguage);
//       await _flutterTts.setSpeechRate(0.6); // Slightly slower for better clarity
//       await _flutterTts.setPitch(1.0);
//       await _flutterTts.setVolume(0.9);
      
//       // Set up TTS handlers
//       _flutterTts.setStartHandler(() {
//         if (mounted) {
//           setState(() => _isSpeaking = true);
//           _startSpeakingAnimation();
//         }
//       });

//       _flutterTts.setCompletionHandler(() {
//         if (mounted) {
//           setState(() => _isSpeaking = false);
//           _stopSpeakingAnimation();
//         }
//       });

//       _flutterTts.setErrorHandler((msg) {
//         if (mounted) {
//           setState(() => _isSpeaking = false);
//           _stopSpeakingAnimation();
//           _showFeedback('Speech error: $msg', isError: true);
//         }
//       });

//       // Try to set Indian English voice if available
//       List<dynamic> voices = await _flutterTts.getVoices;
//       var indianVoice = voices.firstWhere(
//         (voice) => voice['locale'].toString().contains('en-IN') ||
//                    voice['name'].toString().toLowerCase().contains('indian'),
//         orElse: () => null,
//       );
      
//       if (indianVoice != null) {
//         await _flutterTts.setVoice({
//           "name": indianVoice['name'],
//           "locale": indianVoice['locale']
//         });
//       }

//       if (mounted) setState(() => _ttsInitialized = true);
//     } catch (e) {
//       debugPrint('TTS initialization error: $e');
//       if (mounted) setState(() => _ttsInitialized = false);
//     }
//   }

//   Future<bool> _checkMicrophonePermission() async {
//     return await Permission.microphone.request().isGranted;
//   }

//   void _onSpeechStatus(String status) {
//     if (!mounted) return;
//     debugPrint('Speech engine status: $status. UI is listening: $_isListening');

//     if (status == 'notListening' || status == 'done') {
//       if (_isListening) {
//         debugPrint('Engine stopped unexpectedly. Forcing UI to update.');
//         _stopListening();
//       }
//     }
//   }

//   void _onSpeechError(dynamic error) {
//     debugPrint('Speech error received: $error');
//     if (!mounted) return;
//     _stopListening(showError: true, error: error.toString());
//   }

//   String _getErrorMessage(String error) {
//     if (error.contains('speech timeout') || error.contains('e_4')) {
//       return 'Listening timed out. Please speak sooner.';
//     } else if (error.contains('no-speech') || error.contains('e_6')) {
//       return 'No speech was detected.';
//     } else if (error.contains('network') || error.contains('e_7')) {
//       return 'A network error occurred.';
//     } else if (error.contains('audio') || error.contains('e_3')) {
//       return 'Microphone access error.';
//     }
//     return 'An unknown error occurred.';
//   }

//   void _startAnimations() {
//     if (mounted && !_waveController.isAnimating) {
//       _waveController.repeat();
//     }
//   }

//   void _stopAnimations() {
//     if (mounted && _waveController.isAnimating) {
//       _waveController.stop();
//       _waveController.reset();
//     }
//   }

//   void _startSpeakingAnimation() {
//     if (mounted && !_speakController.isAnimating) {
//       _speakController.repeat(reverse: true);
//     }
//   }

//   void _stopSpeakingAnimation() {
//     if (mounted && _speakController.isAnimating) {
//       _speakController.stop();
//       _speakController.reset();
//     }
//   }

//   Future<void> _toggleSpeechRecognition() async {
//     if (!_isInitialized) return;
//     if (!_speechAvailable) {
//       _showFeedback('Speech recognition not available.', isError: true);
//       _initializeSpeech();
//       return;
//     }

//     if (_isListening) {
//       await _stopListening();
//     } else {
//       await _startListening();
//     }
//   }

//   Future<void> _startListening() async {
//     if (!mounted || _isListening) return;

//     // Stop any ongoing speech and cancel any pending read-back
//     if (_isSpeaking) {
//       await _flutterTts.stop();
//     }
//     _readBackTimer?.cancel();

//     setState(() {
//       _isListening = true;
//       _currentWords = '';
//     });
//     _startAnimations();

//     try {
//       await _speech.listen(
//         onResult: _onSpeechResult,
//         listenFor: widget.listenDuration,
//         pauseFor: widget.pauseDuration,
//         partialResults: true,
//         cancelOnError: true,
//         listenMode: stt.ListenMode.dictation,
//         localeId: _currentLocaleId,
//       );
//     } catch (e) {
//       debugPrint('Error on starting listen: $e');
//       await _stopListening(showError: true, error: e.toString());
//     }
//   }

//   Future<void> _stopListening({bool showError = false, String? error}) async {
//     if (!_isListening) return;
//     if (!mounted) return;

//     debugPrint("Stop Listening Called. Error: $showError");

//     setState(() {
//       _isListening = false;
//     });

//     _stopAnimations();
//     if (_speech.isListening) {
//       await _speech.stop();
//     }

//     if (showError && error != null) {
//       String errorMessage = _getErrorMessage(error);
//       _showFeedback(errorMessage, isError: true);
//     }
//   }

//   void _onSpeechResult(stt.SpeechRecognitionResult result) {
//     if (!mounted) return;

//     setState(() {
//       _currentWords = result.recognizedWords;
//       _confidence = result.confidence;
//     });

//     if (result.finalResult) {
//       _addToTextField(result.recognizedWords);
//       _lastSpokenText = result.recognizedWords;
      
//       // Stop listening after getting final result
//       Future.delayed(const Duration(milliseconds: 400), () {
//         if (mounted && _isListening) {
//           _stopListening();
//         }
//       });

//       // Schedule auto read-back if enabled
//       if (widget.enableTTS && widget.autoReadBack && result.recognizedWords.trim().isNotEmpty) {
//         _scheduleReadBack(result.recognizedWords);
//       }
//     }
//   }

//   void _scheduleReadBack(String text) {
//     // Cancel any existing timer
//     _readBackTimer?.cancel();
    
//     // Schedule read-back after a short delay
//     _readBackTimer = Timer(const Duration(milliseconds: 1000), () {
//       if (mounted && !_isListening) {
//         _speakText(text);
//       }
//     });
//   }

//   void _addToTextField(String words) {
//     if (words.trim().isEmpty) return;

//     String currentText = widget.controller.text;
//     String formattedWords = _formatTextForIndianStyle(words.trim());

//     if (currentText.isEmpty || currentText.endsWith(' ')) {
//       widget.controller.text += formattedWords;
//     } else {
//       widget.controller.text += ' $formattedWords';
//     }

//     if (!widget.controller.text.endsWith(' ')) {
//       widget.controller.text += ' ';
//     }

//     // Move cursor to end to allow editing
//     widget.controller.selection = TextSelection.fromPosition(
//       TextPosition(offset: widget.controller.text.length),
//     );

//     widget.onChanged?.call(widget.controller.text);
//   }

//   String _formatTextForIndianStyle(String text) {
//     if (text.isEmpty) return text;
    
//     // Capitalize first letter
//     String formatted = text[0].toUpperCase() + text.substring(1);
    
//     // Add common Indian English patterns and corrections
//     formatted = formatted
//         .replaceAll(' na ', ' nah ')
//         .replaceAll(' yaar ', ' yaar ')
//         .replaceAll(' bhai ', ' bhai ')
//         .replaceAll(' hai ', ' hai ')
//         .replaceAll(' kya ', ' kya ');
    
//     return formatted;
//   }

//   Future<void> _speakText(String text) async {
//     if (!_ttsInitialized || text.trim().isEmpty) return;
    
//     try {
//       // Stop any ongoing speech
//       await _flutterTts.stop();
      
//       // Speak the text with Indian accent and natural pauses
//       String processedText = _processTextForSpeech(text);
//       await _flutterTts.speak(processedText);
      
//       // Show feedback that text is being read back

//     } catch (e) {
//       debugPrint('TTS Error: $e');
//       _showFeedback('Unable to speak text', isError: true);
//     }
//   }

//   String _processTextForSpeech(String text) {
//     // Add natural pauses and emphasis for Indian speaking style
//     String processed = text
//         .replaceAll('.', '. ')
//         .replaceAll(',', ', ')
//         .replaceAll('!', '! ')
//         .replaceAll('?', '? ')
//         .replaceAll(';', '; ');
    
//     return processed;
//   }

//   Future<void> _speakCurrentText() async {
//     String currentText = widget.controller.text.trim();
//     if (currentText.isEmpty) {
//       _showFeedback('No text to speak', isError: false);
//       return;
//     }
    
//     await _speakText(currentText);
//   }

//   Future<void> _speakLastSpokenText() async {
//     if (_lastSpokenText.trim().isEmpty) {
//       _showFeedback('No recently spoken text to repeat', isError: false);
//       return;
//     }
    
//     await _speakText(_lastSpokenText);
//   }

//   Future<void> _stopSpeaking() async {
//     if (_isSpeaking) {
//       await _flutterTts.stop();
//     }
//     _readBackTimer?.cancel();
//   }

//   void _cleanupResources() {
//     _readBackTimer?.cancel();
//     _waveController.dispose();
//     _speakController.dispose();
//     _speech.cancel();
//     _flutterTts.stop();
//   }

//   void _showFeedback(String message, {required bool isError}) {
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).hideCurrentSnackBar();
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message, style: const TextStyle(color: Colors.white)),
//         backgroundColor: isError ? _errorColor : Colors.green,
//         duration: Duration(seconds: isError ? 4 : 2),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildLabel(),
//         _buildInputContainer(),
//         if (widget.showLiveTranscription && _isListening) _buildLiveTranscription(),
//         if (widget.enableTTS) _buildReadBackControls(),
//       ],
//     );
//   }

//   Widget _buildLabel() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 5.0),
//       child: Row(
//         children: [
//           Text(widget.label, style: AppFont.dropDowmLabel(context)),
//           if (_confidence > 0 && _isListening) ...[
//             const SizedBox(width: 8),
//             Text(
//               '${(_confidence * 100).toInt()}%',
//               style: TextStyle(
//                 fontSize: 12,
//                 color: _primaryColor,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ],
//           // Removed auto read-back icon and text from label
//         ],
//       ),
//     );
//   }

//   Widget _buildInputContainer() {
//     return Container(
//       width: double.infinity,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(5),
//         color: AppColors.containerBg,
//         border: _isListening 
//             ? Border.all(color: _primaryColor, width: 2)
//             : _isSpeaking 
//                 ? Border.all(color: _speakingColor, width: 2)
//                 : null,
//       ),
//       child: Row(
//         children: [
//           Expanded(child: _buildTextField()),
//           _buildActionButtons(),
//         ],
//       ),
//     );
//   }

//   Widget _buildTextField() {
//     return TextField(
//       controller: widget.controller,
//       enabled: widget.enabled, // Removed the && !_isListening condition to allow editing while listening
//       maxLines: widget.maxLines,
//       minLines: widget.minLines,
//       keyboardType: TextInputType.multiline,
//       onChanged: widget.onChanged,
//       decoration: InputDecoration(
//         hintText: _isListening 
//             ? "Listening... Speak now" 
//             : _isSpeaking 
//                 ? "Speaking..." 
//                 : widget.hint,
//         hintStyle: GoogleFonts.poppins(
//           color: _isListening 
//               ? _primaryColor 
//               : _isSpeaking 
//                   ? _speakingColor 
//                   : Colors.grey.shade600,
//         ),
//         contentPadding: widget.contentPadding ??
//             const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//         border: InputBorder.none,
//       ),
//       style: AppFont.dropDowmLabel(context),
//     );
//   }

//   Widget _buildActionButtons() {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         _buildSpeechButton(),
//         if (widget.enableTTS) _buildSpeakButton(),
//       ],
//     );
//   }

//   Widget _buildSpeechButton() {
//     if (!_isInitialized) {
//       return const Padding(
//         padding: EdgeInsets.all(12.0),
//         child: SizedBox(
//           width: 18,
//           height: 18,
//           child: CircularProgressIndicator(strokeWidth: 2),
//         ),
//       );
//     }

//     return AnimatedBuilder(
//       animation: _waveAnimation,
//       builder: (context, child) {
//         return Transform.scale(
//           scale: _isListening ? 1.0 + (_waveAnimation.value * 0.2) : 1.0,
//           child: IconButton(
//             onPressed: _speechAvailable ? _toggleSpeechRecognition : null,
//             icon: Icon(
//               _isListening ? FontAwesomeIcons.stop : FontAwesomeIcons.microphone,
//               color: _isListening
//                   ? Colors.red
//                   : (_speechAvailable ? _primaryColor : AppColors.iconGrey),
//               size: 16,
//             ),
//             tooltip: _isListening ? 'Stop recording' : 'Start voice input',
//             splashRadius: 24,
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildSpeakButton() {
//     if (!_ttsInitialized) {
//       return const Padding(
//         padding: EdgeInsets.all(12.0),
//         child: SizedBox(
//           width: 18,
//           height: 18,
//           child: CircularProgressIndicator(strokeWidth: 2),
//         ),
//       );
//     }

//     return AnimatedBuilder(
//       animation: _speakAnimation,
//       builder: (context, child) {
//         return Transform.scale(
//           scale: _isSpeaking ? _speakAnimation.value : 1.0,
//           child: IconButton(
//             onPressed: _isSpeaking ? _stopSpeaking : _speakCurrentText,
//             icon: Icon(
//               _isSpeaking ? FontAwesomeIcons.stop : FontAwesomeIcons.volumeHigh,
//               color: _isSpeaking ? Colors.red : _speakingColor,
//               size: 16,
//             ),
//             tooltip: _isSpeaking ? 'Stop speaking' : 'Speak text aloud',
//             splashRadius: 24,
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildReadBackControls() {
//     if (!_ttsInitialized) return const SizedBox.shrink();
    
//     return Padding(
//       padding: const EdgeInsets.only(top: 8.0),
//       child: Row(
//         children: [
//           if (_lastSpokenText.isNotEmpty) ...[
//             TextButton.icon(
//               onPressed: _isSpeaking ? null : _speakLastSpokenText,
//               icon: Icon(
//                 FontAwesomeIcons.repeat,
//                 size: 12,
//                 color: _isSpeaking ? Colors.grey : _speakingColor,
//               ),
//               label: Text(
//                 'Repeat last',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: _isSpeaking ? Colors.grey : _speakingColor,
//                 ),
//               ),
//             ),
//           ],
//           // Removed the Auto read-back toggle button
//         ],
//       ),
//     );
//   }

//   Widget _buildLiveTranscription() {
//     if (_currentWords.isEmpty) return const SizedBox.shrink();
    
//     return Container(
//       margin: const EdgeInsets.only(top: 8),
//       padding: const EdgeInsets.all(8),
//       decoration: BoxDecoration(
//         color: _primaryColor.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(5),
//         border: Border.all(color: _primaryColor.withOpacity(0.3)),
//       ),
//       child: Row(
//         children: [
//           Icon(
//             FontAwesomeIcons.microphoneLines,
//             size: 14,
//             color: _primaryColor,
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               _currentWords,
//               style: GoogleFonts.poppins(
//                 fontSize: 12,
//                 color: _primaryColor,
//                 fontStyle: FontStyle.italic,
//               ),
//             ),
//           ),
//           // Removed the audio icon from live transcription
//         ],
//       ),
//     );
//   }
// }


// SECOND LAST MUSTAFA 

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

class EnhancedSpeechTextField extends StatefulWidget {
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
  final bool enableTTS;
  final String preferredLanguage;
  final bool autoReadBack; // New parameter to control auto read-back

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
    this.enableTTS = true,
    this.preferredLanguage = 'en-IN', // Indian English by default
    this.autoReadBack = true, // Auto read-back enabled by default
  }) : super(key: key);

  @override
  State<EnhancedSpeechTextField> createState() =>
      _EnhancedSpeechTextFieldState();
}

class _EnhancedSpeechTextFieldState extends State<EnhancedSpeechTextField>
    with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  // State variables
  bool _isListening = false;
  bool _isInitialized = false;
  bool _speechAvailable = false;
  bool _isSpeaking = false;
  bool _ttsInitialized = false;
  String _currentWords = '';
  String _currentLocaleId = '';
  double _confidence = 0.0;
  String _lastSpokenText = '';
  Timer? _readBackTimer; // Timer for delayed read-back

  late AnimationController _waveController;
  late AnimationController _speakController;
  late Animation<double> _waveAnimation;
  late Animation<double> _speakAnimation;

  // Colors
  Color get _primaryColor => widget.primaryColor ?? AppColors.iconGrey;
  Color get _errorColor => Colors.red;
  Color get _speakingColor => const Color.fromARGB(255, 87, 87, 87);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeSpeech();
    _initializeTTS();
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }

  void _initializeAnimations() {
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );

    _speakController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _speakAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _speakController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeSpeech() async {
    try {
      bool hasPermission = await _checkMicrophonePermission();
      if (!mounted) return;

      if (!hasPermission) {
        if (mounted) setState(() => _isInitialized = true);
        return;
      }

      _speechAvailable = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: false,
      );

      if (_speechAvailable) {
        var locales = await _speech.locales();
        // Try to find Indian English locale first
        var indianLocale = locales.firstWhere(
          (locale) => locale.localeId == 'en-IN',
          orElse: () => locales.firstWhere(
            (locale) => locale.localeId.startsWith('en'),
            orElse: () => stt.LocaleName('en_US', 'English'),
          ),
        );
        _currentLocaleId = indianLocale.localeId;
      }
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Speech initialization error: $e');
      if (mounted)
        setState(() {
          _isInitialized = true;
          _speechAvailable = false;
        });
    }
  }

  Future<void> _initializeTTS() async {
    try {
      // Initialize TTS
      await _flutterTts.setLanguage(widget.preferredLanguage);
      await _flutterTts.setSpeechRate(0.6); // Slightly slower for better clarity
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(0.9);
      
      // Set up TTS handlers
      _flutterTts.setStartHandler(() {
        if (mounted) {
          setState(() => _isSpeaking = true);
          _startSpeakingAnimation();
        }
      });

      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _isSpeaking = false);
          _stopSpeakingAnimation();
        }
      });

      _flutterTts.setErrorHandler((msg) {
        if (mounted) {
          setState(() => _isSpeaking = false);
          _stopSpeakingAnimation();
          _showFeedback('Speech error: $msg', isError: true);
        }
      });

      // Try to set Indian English voice if available
      List<dynamic> voices = await _flutterTts.getVoices;
      var indianVoice = voices.firstWhere(
        (voice) => voice['locale'].toString().contains('en-IN') ||
                   voice['name'].toString().toLowerCase().contains('indian'),
        orElse: () => null,
      );
      
      if (indianVoice != null) {
        await _flutterTts.setVoice({
          "name": indianVoice['name'],
          "locale": indianVoice['locale']
        });
      }

      if (mounted) setState(() => _ttsInitialized = true);
    } catch (e) {
      debugPrint('TTS initialization error: $e');
      if (mounted) setState(() => _ttsInitialized = false);
    }
  }

  Future<bool> _checkMicrophonePermission() async {
    return await Permission.microphone.request().isGranted;
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    debugPrint('Speech engine status: $status. UI is listening: $_isListening');

    if (status == 'notListening' || status == 'done') {
      if (_isListening) {
        debugPrint('Engine stopped unexpectedly. Forcing UI to update.');
        _stopListening();
      }
    }
  }

  void _onSpeechError(dynamic error) {
    debugPrint('Speech error received: $error');
    if (!mounted) return;
    _stopListening(showError: true, error: error.toString());
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
    }
    return 'An unknown error occurred.';
  }

  void _startAnimations() {
    if (mounted && !_waveController.isAnimating) {
      _waveController.repeat();
    }
  }

  void _stopAnimations() {
    if (mounted && _waveController.isAnimating) {
      _waveController.stop();
      _waveController.reset();
    }
  }

  void _startSpeakingAnimation() {
    if (mounted && !_speakController.isAnimating) {
      _speakController.repeat(reverse: true);
    }
  }

  void _stopSpeakingAnimation() {
    if (mounted && _speakController.isAnimating) {
      _speakController.stop();
      _speakController.reset();
    }
  }

  Future<void> _toggleSpeechRecognition() async {
    if (!_isInitialized) return;
    if (!_speechAvailable) {
      _showFeedback('Speech recognition not available.', isError: true);
      _initializeSpeech();
      return;
    }

    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!mounted || _isListening) return;

    // Stop any ongoing speech and cancel any pending read-back
    if (_isSpeaking) {
      await _flutterTts.stop();
    }
    _readBackTimer?.cancel();

    setState(() {
      _isListening = true;
      _currentWords = '';
    });
    _startAnimations();

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: widget.listenDuration,
        pauseFor: widget.pauseDuration,
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
        localeId: _currentLocaleId,
      );
    } catch (e) {
      debugPrint('Error on starting listen: $e');
      await _stopListening(showError: true, error: e.toString());
    }
  }

  Future<void> _stopListening({bool showError = false, String? error}) async {
    if (!_isListening) return;
    if (!mounted) return;

    debugPrint("Stop Listening Called. Error: $showError");

    setState(() {
      _isListening = false;
    });

    _stopAnimations();
    if (_speech.isListening) {
      await _speech.stop();
    }

    if (showError && error != null) {
      String errorMessage = _getErrorMessage(error);
      _showFeedback(errorMessage, isError: true);
    }
  }

  void _onSpeechResult(stt.SpeechRecognitionResult result) {
    if (!mounted) return;

    setState(() {
      _currentWords = result.recognizedWords;
      _confidence = result.confidence;
    });

    if (result.finalResult) {
      _addToTextField(result.recognizedWords);
      _lastSpokenText = result.recognizedWords;
      
      // Stop listening after getting final result
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _isListening) {
          _stopListening();
        }
      });

      // Schedule auto read-back if enabled
      if (widget.enableTTS && widget.autoReadBack && result.recognizedWords.trim().isNotEmpty) {
        _scheduleReadBack(result.recognizedWords);
      }
    }
  }

  void _scheduleReadBack(String text) {
    // Cancel any existing timer
    _readBackTimer?.cancel();
    
    // Schedule read-back after a short delay
    _readBackTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted && !_isListening) {
        _speakText(text);
      }
    });
  }

  void _addToTextField(String words) {
    if (words.trim().isEmpty) return;

    String currentText = widget.controller.text;
    String formattedWords = _formatTextForIndianStyle(words.trim());

    if (currentText.isEmpty || currentText.endsWith(' ')) {
      widget.controller.text += formattedWords;
    } else {
      widget.controller.text += ' $formattedWords';
    }

    if (!widget.controller.text.endsWith(' ')) {
      widget.controller.text += ' ';
    }

    // Move cursor to end to allow editing
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );

    widget.onChanged?.call(widget.controller.text);
  }

  String _formatTextForIndianStyle(String text) {
    if (text.isEmpty) return text;
    
    // Capitalize first letter
    String formatted = text[0].toUpperCase() + text.substring(1);
    
    // Add common Indian English patterns and corrections
    formatted = formatted
        .replaceAll(' na ', ' nah ')
        .replaceAll(' yaar ', ' yaar ')
        .replaceAll(' bhai ', ' bhai ')
        .replaceAll(' hai ', ' hai ')
        .replaceAll(' kya ', ' kya ');
    
    return formatted;
  }

  Future<void> _speakText(String text) async {
    if (!_ttsInitialized || text.trim().isEmpty) return;
    
    try {
      // Stop any ongoing speech
      await _flutterTts.stop();
      
      // Speak the text with Indian accent and natural pauses
      String processedText = _processTextForSpeech(text);
      await _flutterTts.speak(processedText);
      
      // Show feedback that text is being read back

    } catch (e) {
      debugPrint('TTS Error: $e');
      _showFeedback('Unable to speak text', isError: true);
    }
  }

  String _processTextForSpeech(String text) {
    // Add natural pauses and emphasis for Indian speaking style
    String processed = text
        .replaceAll('.', '. ')
        .replaceAll(',', ', ')
        .replaceAll('!', '! ')
        .replaceAll('?', '? ')
        .replaceAll(';', '; ');
    
    return processed;
  }

  Future<void> _speakCurrentText() async {
    String currentText = widget.controller.text.trim();
    if (currentText.isEmpty) {
      _showFeedback('No text to speak', isError: false);
      return;
    }
    
    await _speakText(currentText);
  }

  Future<void> _speakLastSpokenText() async {
    if (_lastSpokenText.trim().isEmpty) {
      _showFeedback('No recently spoken text to repeat', isError: false);
      return;
    }
    
    await _speakText(_lastSpokenText);
  }

  Future<void> _stopSpeaking() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
    }
    _readBackTimer?.cancel();
  }

  void _cleanupResources() {
    _readBackTimer?.cancel();
    _waveController.dispose();
    _speakController.dispose();
    _speech.cancel();
    _flutterTts.stop();
  }

  void _showFeedback(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? _errorColor : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        _buildInputContainer(),
        if (widget.showLiveTranscription && _isListening) _buildLiveTranscription(),
        if (widget.enableTTS) _buildReadBackControls(),
      ],
    );
  }

  Widget _buildLabel() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        children: [
          Text(widget.label, style: AppFont.dropDowmLabel(context)),
          if (_confidence > 0 && _isListening) ...[
            const SizedBox(width: 8),
            Text(
              '${(_confidence * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: _primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          // Removed auto read-back icon and text from label
        ],
      ),
    );
  }

  Widget _buildInputContainer() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: AppColors.containerBg,
        border: _isListening 
            ? Border.all(color: _primaryColor, width: 2)
            : _isSpeaking 
                ? Border.all(color: _speakingColor, width: 2)
                : null,
      ),
      child: Row(
        children: [
          Expanded(child: _buildTextField()),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled, // Removed the && !_isListening condition to allow editing while listening
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      keyboardType: TextInputType.multiline,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: _isListening 
            ? "Listening... Speak now" 
            : _isSpeaking 
                ? "Speaking..." 
                : widget.hint,
        hintStyle: GoogleFonts.poppins(
          color: _isListening 
              ? _primaryColor 
              : _isSpeaking 
                  ? _speakingColor 
                  : Colors.grey.shade600,
        ),
        contentPadding: widget.contentPadding ??
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: InputBorder.none,
      ),
      style: AppFont.dropDowmLabel(context),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSpeechButton(),
        if (widget.enableTTS) _buildSpeakButton(),
      ],
    );
  }

  Widget _buildSpeechButton() {
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

    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isListening ? 1.0 + (_waveAnimation.value * 0.2) : 1.0,
          child: IconButton(
            onPressed: _speechAvailable ? _toggleSpeechRecognition : null,
            icon: Icon(
              _isListening ? FontAwesomeIcons.stop : FontAwesomeIcons.microphone,
              color: _isListening
                  ? Colors.red
                  : (_speechAvailable ? _primaryColor : AppColors.iconGrey),
              size: 16,
            ),
            tooltip: _isListening ? 'Stop recording' : 'Start voice input',
            splashRadius: 24,
          ),
        );
      },
    );
  }

  Widget _buildSpeakButton() {
    if (!_ttsInitialized) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _speakAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isSpeaking ? _speakAnimation.value : 1.0,
          child: IconButton(
            onPressed: _isSpeaking ? _stopSpeaking : _speakCurrentText,
            icon: Icon(
              _isSpeaking ? FontAwesomeIcons.stop : FontAwesomeIcons.volumeHigh,
              color: _isSpeaking ? Colors.red : _speakingColor,
              size: 16,
            ),
            tooltip: _isSpeaking ? 'Stop speaking' : 'Speak text aloud',
            splashRadius: 24,
          ),
        );
      },
    );
  }

  Widget _buildReadBackControls() {
    if (!_ttsInitialized) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          if (_lastSpokenText.isNotEmpty) ...[
            TextButton.icon(
              onPressed: _isSpeaking ? null : _speakLastSpokenText,
              icon: Icon(
                FontAwesomeIcons.repeat,
                size: 12,
                color: _isSpeaking ? Colors.grey : _speakingColor,
              ),
              label: Text(
                'Repeat last',
                style: TextStyle(
                  fontSize: 12,
                  color: _isSpeaking ? Colors.grey : _speakingColor,
                ),
              ),
            ),
          ],
          // Removed the Auto read-back toggle button
        ],
      ),
    );
  }

  Widget _buildLiveTranscription() {
    if (_currentWords.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            FontAwesomeIcons.microphoneLines,
            size: 14,
            color: _primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _currentWords,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _primaryColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          // Removed the audio icon from live transcription
        ],
      ),
    );
  }
}





