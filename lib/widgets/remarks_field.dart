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
  final stt.SpeechToText _speech = stt.SpeechToText();

  // State variables
  bool _isListening = false;
  bool _isInitialized = false;
  bool _speechAvailable = false;
  String _currentWords = '';
  String _currentLocaleId = '';
  double _confidence = 0.0;

  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  Timer? _stateCheckTimer;
  Timer? _timeoutTimer;

  // Colors
  Color get _primaryColor => widget.primaryColor ?? AppColors.iconGrey;
  Color get _errorColor => Colors.red;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializeSpeech();
    _startStateMonitoring();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupResources();
    super.dispose();
  }

  // Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // When app comes back to foreground, sync the state
      _syncSpeechState();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // When app goes to background, stop listening
      if (_isListening) {
        _forceStopListening();
      }
    }
  }

  void _initializeAnimations() {
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeInOut),
    );
  }

  // NEW: Start periodic state monitoring
  void _startStateMonitoring() {
    _stateCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _syncSpeechState();
      }
    });
  }

  // NEW: Sync UI state with actual speech engine state
  void _syncSpeechState() {
    if (!mounted || !_isInitialized) return;

    bool actuallyListening = _speech.isListening;

    // If there's a mismatch, fix it
    if (_isListening != actuallyListening) {
      debugPrint(
        'State mismatch detected! UI: $_isListening, Engine: $actuallyListening',
      );

      if (actuallyListening && !_isListening) {
        // Engine is listening but UI shows stopped
        setState(() {
          _isListening = true;
        });
        _startAnimations();
      } else if (!actuallyListening && _isListening) {
        // Engine stopped but UI shows listening
        _forceStopListening();
      }
    }
  }

  Future<void> _initializeSpeech() async {
    try {
      // First, ensure any previous instance is properly cleaned up
      if (_speech.isListening) {
        await _speech.cancel();
      }

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
        var englishLocale = locales.firstWhere(
          (locale) => locale.localeId.startsWith('en'),
          orElse: () => stt.LocaleName('en_US', 'English'),
        );
        _currentLocaleId = englishLocale.localeId;
      }

      if (mounted) {
        setState(() => _isInitialized = true);
        // Sync state immediately after initialization
        _syncSpeechState();
      }
    } catch (e) {
      debugPrint('Speech initialization error: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _speechAvailable = false;
        });
      }
    }
  }

  Future<bool> _checkMicrophonePermission() async {
    return await Permission.microphone.request().isGranted;
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    debugPrint('Speech engine status: $status. UI is listening: $_isListening');

    // Clear any existing timeout when status changes
    _timeoutTimer?.cancel();

    if (status == 'notListening' || status == 'done') {
      if (_isListening) {
        debugPrint('Engine stopped unexpectedly. Forcing UI to update.');
        _forceStopListening();
      }
    } else if (status == 'listening') {
      // Engine confirmed it's listening
      if (!_isListening) {
        setState(() {
          _isListening = true;
        });
        _startAnimations();
      }
      // Set a safety timeout
      _timeoutTimer = Timer(
        widget.listenDuration + const Duration(seconds: 5),
        () {
          if (_isListening) {
            debugPrint('Safety timeout triggered');
            _forceStopListening();
          }
        },
      );
    }
  }

  void _onSpeechError(dynamic error) {
    debugPrint('Speech error received: $error');
    if (!mounted) return;
    _forceStopListening(showError: true, error: error.toString());
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
    return 'No speech was detected.';
  }

  void _startAnimations() {
    if (mounted && !_waveController.isAnimating) {
      _waveController.repeat();
    }
  }

  void _stopAnimations() {
    if (mounted) {
      _waveController.stop();
      _waveController.reset();
    }
  }

  Future<void> _toggleSpeechRecognition() async {
    if (!_isInitialized) return;
    if (!_speechAvailable) {
      _showFeedback('Speech recognition not available.', isError: true);
      _initializeSpeech(); // Attempt to re-initialize
      return;
    }

    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!mounted) return;

    // Double-check the actual state before starting
    if (_speech.isListening) {
      debugPrint('Speech engine already listening, stopping first');
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 100));
    }

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
      await _forceStopListening(showError: true, error: e.toString());
    }
  }

  // UPDATED: More robust stop method
  Future<void> _stopListening({bool showError = false, String? error}) async {
    if (!mounted) return;

    debugPrint("Stop Listening Called. Error: $showError");

    setState(() {
      _isListening = false;
    });

    _stopAnimations();
    _timeoutTimer?.cancel();

    // Graceful stop
    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (e) {
        debugPrint('Error stopping speech: $e');
      }
    }

    if (showError && error != null) {
      String errorMessage = _getErrorMessage(error);
      _showFeedback(errorMessage, isError: true);
    }
  }

  // NEW: Force stop method for emergency situations
  Future<void> _forceStopListening({
    bool showError = false,
    String? error,
  }) async {
    if (!mounted) return;

    debugPrint("Force Stop Listening Called. Error: $showError");

    setState(() {
      _isListening = false;
    });

    _stopAnimations();
    _timeoutTimer?.cancel();

    // Force cancel instead of graceful stop
    if (_speech.isListening) {
      try {
        await _speech.cancel();
      } catch (e) {
        debugPrint('Error canceling speech: $e');
      }
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
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _isListening) {
          _stopListening();
        }
      });
    }
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

  void _cleanupResources() {
    _stateCheckTimer?.cancel();
    _timeoutTimer?.cancel();
    _waveController.dispose();

    // Force cleanup of speech resources
    if (_speech.isListening) {
      _speech.cancel();
    }
  }

  void _showFeedback(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? _errorColor : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildLabel(), _buildInputContainer()],
    );
  }

  Widget _buildLabel() {
    // return Padding(
    //   padding: const EdgeInsets.symmetric(vertical: 5.0),
    //   child: Text(widget.label, style: AppFont.dropDowmLabel(context)),
    // );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 5),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.fontBlack,
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
      style: AppFont.dropDowmLabel(context),
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

    return IconButton(
      onPressed: _speechAvailable ? _toggleSpeechRecognition : null,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _isListening ? FontAwesomeIcons.stop : FontAwesomeIcons.microphone,
          key: ValueKey(_isListening),
          color: _isListening
              ? Colors.red
              : (_speechAvailable ? _primaryColor : AppColors.iconGrey),
          size: 16,
        ),
      ),
      tooltip: _isListening ? 'Stop recording' : 'Start voice input',
      splashRadius: 24,
    );
  }
}
