import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smartassist/config/component/color/colors.dart';
import 'package:smartassist/config/component/font/font.dart';
import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;
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
    this.pauseDuration = const Duration(seconds: 3),
  }) : super(key: key);

  @override
  State<EnhancedSpeechTextField> createState() =>
      _EnhancedSpeechTextFieldState();
}

class _EnhancedSpeechTextFieldState extends State<EnhancedSpeechTextField>
    with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();

  // State variables
  bool _isListening = false;
  bool _isInitialized = false;
  bool _speechAvailable = false;
  String _currentWords = '';
  String _recognizedWords = '';
  String _currentLocaleId = '';
  double _confidence = 0.0;

  // Timers and animations
  Timer? _listeningTimer;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  // Colors
  Color get _primaryColor => widget.primaryColor ?? AppColors.iconGrey;
  Color get _backgroundColor => widget.backgroundColor ?? Colors.grey[100]!;
  Color get _textColor => widget.textColor ?? Colors.black;
  Color get _errorColor => Colors.red;
  Color get _successColor => Colors.green;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeSpeech();
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _waveController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeSpeech() async {
    try {
      bool hasPermission = await _checkMicrophonePermission();
      if (!hasPermission) {
        _updateState(speechAvailable: false, initialized: true);
        return;
      }

      bool available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: false,
      );

      if (available) {
        var locales = await _speech.locales();
        var englishLocale = locales.firstWhere(
          (locale) => locale.localeId.startsWith('en'),
          orElse: () => locales.isNotEmpty
              ? locales.first
              : stt.LocaleName('en_US', 'English'),
        );
        _currentLocaleId = englishLocale.localeId;
      }

      _updateState(speechAvailable: available, initialized: true);
    } catch (e) {
      debugPrint('Speech initialization error: $e');
      _updateState(speechAvailable: false, initialized: true);
    }
  }

  Future<bool> _checkMicrophonePermission() async {
    try {
      PermissionStatus permission = await Permission.microphone.status;
      if (permission != PermissionStatus.granted) {
        permission = await Permission.microphone.request();
      }
      return permission == PermissionStatus.granted;
    } catch (e) {
      debugPrint('Permission check error: $e');
      return false;
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;

    debugPrint('Speech status: $status');

    switch (status) {
      case 'listening':
        _updateState(listening: true);
        _startAnimations();
        _startListeningTimer();
        break;
      case 'notListening':
        // Don't immediately stop - keep trying to listen
        if (_isListening) {
          Future.delayed(Duration(milliseconds: 1000), () {
            if (mounted && !_speech.isListening && _isListening) {
              _restartListening();
            }
          });
        }
        break;
      case 'done':
        // Only stop if user manually stopped
        _updateState(listening: false);
        _stopAnimations();
        _listeningTimer?.cancel();
        _finalizeTranscription();
        break;
    }
  }

  // Add method to restart listening automatically
  Future<void> _restartListening() async {
    if (!_isListening || !_speechAvailable) return;

    try {
      debugPrint('Restarting speech recognition...');
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 2),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
        localeId: _currentLocaleId.isNotEmpty ? _currentLocaleId : 'en_US',
      );
    } catch (e) {
      debugPrint('Restart listening error: $e');
    }
  }

  void _onSpeechError(dynamic error) {
    debugPrint('Speech error: $error');

    if (!mounted) return;

    _updateState(listening: false);
    _stopAnimations();
    _listeningTimer?.cancel();

    String errorMessage = _getErrorMessage(error.toString());
    _showFeedback(errorMessage, isError: true);
  }

  String _getErrorMessage(String error) {
    if (error.contains('network')) {
      return 'Check your internet connection';
    } else if (error.contains('audio')) {
      return 'Check microphone permissions';
    } else if (error.contains('no-speech')) {
      return 'No speech detected. Speak clearly';
    } else if (error.contains('aborted')) {
      return 'Speech recognition cancelled';
    } else {
      return 'Speech recognition failed. Try again';
    }
  }

  void _startListeningTimer() {
    _listeningTimer?.cancel();
    _listeningTimer = Timer(widget.listenDuration, () {
      if (_isListening && mounted) {
        _stopListening();
      }
    });
  }

  void _startAnimations() {
    try {
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
    } catch (e) {
      debugPrint('Animation error: $e');
    }
  }

  void _stopAnimations() {
    _pulseController.stop();
    _waveController.stop();
    _pulseController.reset();
    _waveController.reset();
  }

  void _updateState({
    bool? listening,
    bool? initialized,
    bool? speechAvailable,
    String? currentWords,
    String? recognizedWords,
    double? confidence,
  }) {
    if (!mounted) return;

    setState(() {
      if (listening != null) _isListening = listening;
      if (initialized != null) _isInitialized = initialized;
      if (speechAvailable != null) _speechAvailable = speechAvailable;
      if (currentWords != null) _currentWords = currentWords;
      if (recognizedWords != null) _recognizedWords = recognizedWords;
      if (confidence != null) _confidence = confidence;
    });
  }

  Future<void> _toggleSpeechRecognition() async {
    if (!_speechAvailable) {
      _showFeedback('Speech recognition not available', isError: true);
      return;
    }

    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  // DateTime? _lastSoundLevelUpdate;
  // void _startListening() async {
  //   await _speech.listen(
  //     onSoundLevelChange: (level) {
  //       final now = DateTime.now();
  //       if (_lastSoundLevelUpdate == null ||
  //           now.difference(_lastSoundLevelUpdate!).inMilliseconds > 100) {
  //         debugPrint('Sound level: $level');
  //         _lastSoundLevelUpdate = now;
  //       }
  //     },

  //   );
  // }

  Future<void> _startListening() async {
    if (!_speechAvailable || _isListening) return;

    try {
      _updateState(currentWords: '', recognizedWords: '');

      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: Duration(minutes: 10), // Longer listening time
        pauseFor: Duration(seconds: 2), // Shorter pause
        partialResults: true,
        cancelOnError: false, // Don't cancel on errors
        listenMode: stt.ListenMode.dictation, // Better for continuous speech
        localeId: _currentLocaleId.isNotEmpty ? _currentLocaleId : 'en_US',
        onSoundLevelChange: (level) {
          // Optional: handle sound level for visual feedback
          debugPrint('Sound level: $level');
        },
      );
    } catch (e) {
      debugPrint('Start listening error: $e');
      _updateState(listening: false);
      _showFeedback('Failed to start speech recognition', isError: true);
    }
  }

  void _onSpeechResult(stt.SpeechRecognitionResult result) {
    if (!mounted) return;

    final words = result.recognizedWords;
    final confidence = result.confidence;

    debugPrint(
      'Speech result: $words (confidence: $confidence, final: ${result.finalResult})',
    );

    if (words.isNotEmpty) {
      // Always update current words for live display
      _updateState(currentWords: words, confidence: confidence);

      // For final results, add to the main text field
      if (result.finalResult) {
        _addToTextField(words);
        // Don't clear current words immediately - let them fade naturally
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted) {
            _updateState(currentWords: '');
          }
        });

        // Show confidence feedback for very low confidence
        if (confidence < 0.5) {
          _showFeedback('Low confidence - please speak clearly', isError: true);
        }
      }
    }
  }

  void _addToTextField(String words) {
    String currentText = widget.controller.text;
    String newText;
    // Capitalize first letter of words
    String formattedWords = words.isNotEmpty
        ? words[0].toUpperCase() + words.substring(1)
        : words;
    if (currentText.isEmpty) {
      newText = formattedWords;
    } else if (currentText.endsWith(' ') ||
        currentText.endsWith('.') ||
        currentText.endsWith(',') ||
        currentText.endsWith('!') ||
        currentText.endsWith('?')) {
      newText = '$currentText$formattedWords';
    } else {
      newText = '$currentText $formattedWords';
    }
    widget.controller.text = newText;
    widget.onChanged?.call(newText);
    if (!newText.endsWith(' ')) {
      widget.controller.text = '$newText ';
    }
  }

  void _finalizeTranscription() {
    if (_currentWords.isNotEmpty && _recognizedWords != _currentWords) {
      _addToTextField(_currentWords);
    }
    _updateState(currentWords: '', recognizedWords: '');
  }

  Future<void> _stopListening() async {
    if (!mounted) return;

    _listeningTimer?.cancel();

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (e) {
      debugPrint('Error stopping speech: $e');
    }

    _updateState(listening: false);
    _stopAnimations();
  }

  void _cleanupResources() {
    _listeningTimer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();

    if (_speech.isListening) {
      _speech.stop();
    }
  }

  void _showFeedback(String message, {required bool isError}) {
    if (!mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: isError ? _errorColor : _successColor,
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      debugPrint('Error showing feedback: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        _buildInputContainer(),
        _buildStatusIndicator(),
      ],
    );
  }

  Widget _buildLabel() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        children: [
          Text(widget.label, style: AppFont.dropDowmLabel(context)),
          // if (_confidence > 0.8) ...[
          //   SizedBox(width: 8),
          //   Icon(Icons.verified, size: 16, color: _successColor),
          // ],
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
      enabled:
          widget.enabled && !_isListening, // Disable typing while listening
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      keyboardType: TextInputType.multiline,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: _getHintText(),
        hintStyle: GoogleFonts.poppins(
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w400,
          color: _isListening ? _primaryColor : Colors.grey.shade600,
          fontStyle: _isListening ? FontStyle.italic : FontStyle.normal,
        ),
        contentPadding:
            widget.contentPadding ??
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: InputBorder.none,
        // Add prefix icon when listening
        prefixIcon: _isListening
            ? Padding(
                padding: const EdgeInsets.only(left: 8, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _waveAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(
                              0.3 + (0.7 * _waveAnimation.value),
                            ),
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                    SizedBox(width: 4),
                    Text(
                      'REC',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              )
            : null,
        // Show live transcription as suffix text
        suffixText: _isListening && _currentWords.isNotEmpty
            ? ' $_currentWords'
            : null,
        suffixStyle: GoogleFonts.poppins(
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w400,
          color: _primaryColor.withOpacity(0.7),
          fontStyle: FontStyle.italic,
        ),
      ),
      style: AppFont.dropDowmLabel(context),
    );
  }

  String _getHintText() {
    if (_isListening) {
      return _currentWords.isNotEmpty
          ? 'Speaking...'
          : 'Listening... Speak now or tap stop';
    }
    return widget.hint;
  }

  Widget _buildSpeechButton() {
    if (!_isInitialized) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(_primaryColor),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          // margin: EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isListening
                ? Colors.red.withOpacity(0.2)
                : Colors.transparent,
            border: _isListening
                ? Border.all(color: Colors.red, width: 2)
                : null,
          ),
          child: Transform.scale(
            scale: _isListening ? _pulseAnimation.value : 1.0,
            child: IconButton(
              onPressed: _speechAvailable ? _toggleSpeechRecognition : null,
              icon: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle for recording state
                  if (_isListening)
                    Container(
                      // width: 32,
                      // height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withOpacity(0.1),
                      ),
                    ),
                  // Main icon with proper colors
                  Icon(
                    _isListening
                        ? FontAwesomeIcons.stop
                        : FontAwesomeIcons.microphone,
                    color: _isListening
                        ? Colors.red
                        : (_speechAvailable ? _primaryColor : Colors.grey),
                    size: _isListening ? 16 : 18,
                  ),
                  // Recording indicator dot
                  if (_isListening)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: AnimatedBuilder(
                        animation: _waveAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(
                                0.5 + (0.5 * _waveAnimation.value),
                              ),
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
              tooltip: _getTooltipText(),
              splashRadius: 24,
            ),
          ),
        );
      },
    );
  }

  Color _getButtonColor() {
    if (!_speechAvailable) return Colors.grey;
    return _isListening ? _errorColor : _primaryColor;
  }

  String _getTooltipText() {
    if (!_speechAvailable) return 'Speech not available';
    return _isListening ? 'Stop recording' : 'Start voice input';
  }

  Widget _buildStatusIndicator() {
    if (!_isListening) return SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          // Animated recording indicator
          AnimatedBuilder(
            animation: _waveAnimation,
            builder: (context, child) {
              return Row(
                children: List.generate(3, (index) {
                  double delay = index * 0.3;
                  double animValue = (_waveAnimation.value + delay) % 1.0;
                  return Container(
                    margin: EdgeInsets.only(right: 2),
                    width: 3,
                    height: 8 + (6 * animValue),
                    decoration: BoxDecoration(
                      color: _errorColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              );
            },
          ),
          SizedBox(width: 8),
          Text('Recording... Tap', style: AppFont.smallText12(context)),
          Icon(FontAwesomeIcons.stop, size: 12, color: _errorColor),
          Text(' to stop', style: AppFont.smallText12(context)),
          Spacer(),
          if (_confidence > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _confidence > 0.8
                    ? _successColor.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _confidence > 0.8 ? _successColor : Colors.orange,
                  width: 1,
                ),
              ),
              child: Text(
                '${(_confidence * 100).toInt()}%',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: _confidence > 0.8 ? _successColor : Colors.orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveTranscription() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _primaryColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.hearing, size: 16, color: _primaryColor),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                _currentWords.isEmpty
                    ? 'Listening for speech...'
                    : _currentWords,
                style: AppFont.smallText12(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
//         listenFor: Duration(minutes: 10),
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
//     _pulseController.repeat(reverse: true);
//     _waveController.repeat();
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

//     if (currentText.isEmpty) {
//       newText = words;
//     } else if (currentText.endsWith(' ') ||
//         currentText.endsWith('.') ||
//         currentText.endsWith(',') ||
//         currentText.endsWith('!') ||
//         currentText.endsWith('?')) {
//       newText = '$currentText$words';
//     } else {
//       newText = '$currentText $words';
//     }

//     widget.controller.text = newText;
//     widget.onChanged?.call(newText);

//     // Add space after final result
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
