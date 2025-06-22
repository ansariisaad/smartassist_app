import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:smartassist/config/component/color/colors.dart'; // Adjust import based on your project

class GlobleSpeechtotext extends StatefulWidget {
  final Function(String) onSpeechResult; // Callback for final speech result
  final Function(bool)? onListeningStateChanged; // Callback for listening state
  final double iconSize; // Customizable icon size
  final Color activeColor; // Color when listening
  final Color inactiveColor; // Color when not listening

  const GlobleSpeechtotext({
    super.key,
    required this.onSpeechResult,
    this.onListeningStateChanged,
    this.iconSize = 16.0,
    this.activeColor = AppColors.iconGrey,
    this.inactiveColor = AppColors.fontColor,
  });

  @override
  State<GlobleSpeechtotext> createState() => _GlobleSpeechtotextState();
}

class _GlobleSpeechtotextState extends State<GlobleSpeechtotext>
    with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isInitialized = false;
  bool _speechAvailable = false;
  String _currentWords = '';
  double _confidence = 0.0;
  String _currentLocaleId = '';
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  Timer? _timeoutTimer;
  Color get _primaryColor => widget.activeColor ?? AppColors.iconGrey;
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeSpeech();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _timeoutTimer?.cancel();
    if (_speech.isListening) {
      _speech.cancel();
    }
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
  }

  Future<void> _initializeSpeech() async {
    try {
      bool hasPermission = await _checkMicrophonePermission();
      if (!mounted) return;

      if (!hasPermission) {
        setState(() => _isInitialized = true);
        _showFeedback('Microphone permission denied.', isError: true);
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
      }
    } catch (e) {
      debugPrint('Speech initialization error: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _speechAvailable = false;
        });
        _showFeedback(
          'Failed to initialize speech recognition.',
          isError: true,
        );
      }
    }
  }

  Future<bool> _checkMicrophonePermission() async {
    return await Permission.microphone.request().isGranted;
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    debugPrint('Speech status: $status');

    _timeoutTimer?.cancel();

    if (status == 'notListening' || status == 'done') {
      if (_isListening) {
        _forceStopListening();
      }
    } else if (status == 'listening') {
      if (!_isListening) {
        setState(() => _isListening = true);
        widget.onListeningStateChanged?.call(true);
        _startAnimations();
      }
      _timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (_isListening) {
          _forceStopListening(showError: true, error: 'Speech timeout');
        }
      });
    }
  }

  void _onSpeechError(dynamic error) {
    debugPrint('Speech error: $error');
    if (!mounted) return;
    _forceStopListening(showError: true, error: error.toString());
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
    if (!mounted) return;

    if (_speech.isListening) {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    setState(() {
      _isListening = true;
      _currentWords = '';
    });
    widget.onListeningStateChanged?.call(true);
    _startAnimations();

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
        localeId: _currentLocaleId,
      );
    } catch (e) {
      debugPrint('Error starting listen: $e');
      await _forceStopListening(showError: true, error: e.toString());
    }
  }

  Future<void> _stopListening({bool showError = false, String? error}) async {
    if (!mounted) return;

    setState(() {
      _isListening = false;
    });
    widget.onListeningStateChanged?.call(false);
    _stopAnimations();
    _timeoutTimer?.cancel();

    if (_speech.isListening) {
      try {
        await _speech.stop();
      } catch (e) {
        debugPrint('Error stopping speech: $e');
      }
    }

    if (showError && error != null) {
      _showFeedback(_getErrorMessage(error), isError: true);
    }
  }

  Future<void> _forceStopListening({
    bool showError = false,
    String? error,
  }) async {
    if (!mounted) return;

    setState(() {
      _isListening = false;
    });
    widget.onListeningStateChanged?.call(false);
    _stopAnimations();
    _timeoutTimer?.cancel();

    if (_speech.isListening) {
      try {
        await _speech.cancel();
      } catch (e) {
        debugPrint('Error canceling speech: $e');
      }
    }

    if (showError && error != null) {
      _showFeedback(_getErrorMessage(error), isError: true);
    }
  }

  void _onSpeechResult(stt.SpeechRecognitionResult result) {
    if (!mounted) return;

    setState(() {
      _currentWords = result.recognizedWords;
      _confidence = result.confidence;
    });

    if (result.recognizedWords.isNotEmpty) {
      widget.onSpeechResult(result.recognizedWords);
    }

    if (result.finalResult) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _isListening) {
          _stopListening();
        }
      });
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('speech timeout') || error.contains('e_4')) {
      return 'Listening timed out. Please speak sooner.';
    } else if (error.contains('no-speech') || error.contains('e_6')) {
      return 'No speech detected.';
    } else if (error.contains('network') || error.contains('e_7')) {
      return 'Network error occurred.';
    } else if (error.contains('audio') || error.contains('e_3')) {
      return 'Microphone access error.';
    }
    return 'Speech recognition error.';
  }

  void _showFeedback(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleSpeechRecognition,
      child: AnimatedBuilder(
        animation: _waveAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              if (_isListening)
                Container(
                  width: widget.iconSize * 1.5,
                  height: widget.iconSize * 1.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.activeColor.withOpacity(
                      0.2 * _waveAnimation.value,
                    ),
                  ),
                ),
              Icon(
                _isListening
                    ? FontAwesomeIcons.stop
                    : FontAwesomeIcons.microphone,
                color: _isListening
                    ? Colors.red
                    : (_speechAvailable ? _primaryColor : AppColors.iconGrey),
                size: widget.iconSize,
              ),
            ],
          );
        },
      ),
    );
  }
}
